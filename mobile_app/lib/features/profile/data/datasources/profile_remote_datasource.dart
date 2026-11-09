import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../onboarding/data/models/onboarding_config_models.dart';
import '../../../settings/data/models/onboarding_field_config_model.dart';
import '../models/my_profile_model.dart';
import '../models/profile_document_model.dart';
import '../services/profile_document_viewer.dart' show kDocumentEmptyMessage;

/// The file name from a `Content-Disposition` header (`inline;
/// filename="x.pdf"`), or null. Only the base name is kept.
String? fileNameFromContentDisposition(String? header) {
  if (header == null) return null;
  final match = RegExp(r'''filename\*?=(?:UTF-8'')?"?([^";]+)"?''', caseSensitive: false).firstMatch(header);
  final raw = match?.group(1)?.trim();
  if (raw == null || raw.isEmpty) return null;
  String decoded;
  try {
    decoded = Uri.decodeComponent(raw);
  } on ArgumentError {
    decoded = raw; // malformed %-escape: keep the name as sent
  }
  final name = decoded.split(RegExp(r'[/\\]')).last.trim();
  return name.isEmpty ? null : name;
}

class ProfileRemoteDataSource {
  final Dio _dio;
  ProfileRemoteDataSource(this._dio);

  // ── My profile ────────────────────────────────────────────────────────────

  Future<MyProfileModel> fetchMyProfile() async {
    final res = await _dio.get(ApiConstants.myProfile);
    return MyProfileModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> updateMyProfile(MyProfileUpdateData data) async {
    await _dio.patch(ApiConstants.myProfile, data: data.toJson());
  }

  /// PATCH /employees/me/ {custom_field_values} (web ProfileClient). The
  /// backend keeps only Emergency-step custom keys and merges them in.
  Future<void> updateMyCustomFields(Map<String, String> values) async {
    await _dio.patch(ApiConstants.myProfile, data: {'custom_field_values': values});
  }

  // ── Profile photo ─────────────────────────────────────────────────────────

  /// Returns the new `profile_photo_url` (or null if the backend somehow
  /// omits it) — matches `ProfilePhotoView.post`'s response shape.
  Future<String?> uploadPhoto(File file) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });
    final res = await _dio.post(ApiConstants.myProfilePhoto, data: formData);
    final data = _unwrap(res.data) as Map<String, dynamic>;
    return data['profile_photo_url'] as String?;
  }

  Future<void> removePhoto() async {
    await _dio.delete(ApiConstants.myProfilePhoto);
  }

  // ── Change password ───────────────────────────────────────────────────────
  //
  // NOTE: on success the backend blacklists the current refresh token and
  // deletes the access/refresh cookies — this is a forced logout by design.
  // Callers must log the user out and navigate to login after this succeeds.

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _dio.post(ApiConstants.changePassword, data: {
      'old_password': oldPassword,
      'new_password': newPassword,
      'confirm_password': confirmPassword,
    });
  }

  // ── Documents (read-only list) ────────────────────────────────────────────

  Future<List<ProfileDocumentModel>> fetchMyDocuments() async {
    final res = await _dio.get(ApiConstants.onboardingDocuments);
    final raw = _unwrap(res.data);
    final list = raw is List ? raw : <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ProfileDocumentModel.fromJson)
        .toList();
  }

  // ── Documents (self-service upload / replace / view) ─────────────────────
  //
  // Web My Profile → Documents (ProfileClient.tsx). Production backend:
  //  - GET  /onboarding/document-type-config/ — every type, visible or not
  //    (DocumentTypeConfigPublicView); callers filter to `visible`.
  //  - POST /employees/<employee_id>/documents/ — EmployeeProfileDocumentView.
  //    The caller may always upload for themselves, after onboarding too. A
  //    new file for a type replaces the older one(s) unless the type allows
  //    multiple; the old file is only removed once the new one is saved.
  //  - GET  /onboarding/documents/<id>/ — streams the file to its owner. It
  //    needs the login header, so it can't be opened in an outside browser.

  Future<List<DocumentTypeConfigModel>> fetchDocumentTypes() async {
    final res = await _dio.get(ApiConstants.onboardingDocumentTypeConfig);
    return OnboardingConfig.parseDocumentTypes(_unwrap(res.data));
  }

  /// Uploads [file] as [documentType] to the signed-in employee's own profile
  /// ([employeeId] must be their own code from `/employees/me/`). Checked
  /// first with the backend's own rules and messages; nothing is sent when
  /// the file would be refused. Throws an [AppException] carrying the
  /// server's message on failure — success is only returned for a 2xx.
  Future<ProfileDocumentModel> uploadMyDocument(
    String employeeId,
    String documentType,
    ProfileUploadFile file,
  ) async {
    final id = employeeId.trim();
    if (id.isEmpty) {
      throw const ValidationException('Your employee ID is not available yet. Please try again later.', 400);
    }
    if (documentType.trim().isEmpty) throw const ValidationException('Invalid document type.', 400);
    final problem = onboardingUploadError(file.name, file.bytes.length);
    if (problem != null) throw ValidationException(problem, 400);
    // The server checks the part's own content type, so it must be set
    // (Dio would otherwise send application/octet-stream and be refused).
    final mime = onboardingUploadMime(file.name)!;
    final form = FormData.fromMap({
      'document_type': documentType,
      'file': MultipartFile.fromBytes(file.bytes, filename: file.name, contentType: DioMediaType.parse(mime)),
    });
    try {
      final res = await _dio.post(ApiConstants.employeeDocuments(Uri.encodeComponent(id)), data: form);
      final data = _unwrap(res.data);
      if (data is! Map<String, dynamic>) throw const ServerException();
      return ProfileDocumentModel.fromJson(data);
    } on DioException catch (e) {
      throw parseDioException(e);
    }
  }

  /// The contents of the signed-in user's document [documentId], fetched
  /// with their login. Throws an [AppException] on failure.
  Future<ProfileDocumentFile> downloadMyDocument(int documentId) async {
    try {
      final res = await _dio.get<List<int>>(
        ApiConstants.onboardingDocumentDetail(documentId),
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) throw const ServerException(kDocumentEmptyMessage);
      return ProfileDocumentFile(
        bytes: Uint8List.fromList(bytes),
        contentType: res.headers.value(Headers.contentTypeHeader) ?? 'application/octet-stream',
        fileName: fileNameFromContentDisposition(res.headers.value('content-disposition')) ?? 'document-$documentId',
      );
    } on DioException catch (e) {
      throw parseDioException(_withDecodedBody(e));
    }
  }

  // ── Helper ─────────────────────────────────────────────────────────────────

  /// A bytes request's error body is raw bytes; decode the usual JSON
  /// envelope so the server's message reaches the user.
  DioException _withDecodedBody(DioException e) {
    final response = e.response;
    final data = response?.data;
    if (response == null || data is! List<int>) return e;
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(data));
    } catch (_) {
      decoded = null;
    }
    return e.copyWith(
      response: Response(
        requestOptions: response.requestOptions,
        statusCode: response.statusCode,
        headers: response.headers,
        data: decoded,
      ),
    );
  }

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }
}
