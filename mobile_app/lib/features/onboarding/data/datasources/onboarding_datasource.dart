import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/onboarding_config_models.dart';
import '../models/onboarding_model.dart';

/// A refused step save: the server's message plus, for validation errors
/// (422 with the serializer's errors in `data`), one message per field_key.
class OnboardingSaveException implements Exception {
  OnboardingSaveException(this.message, [this.fieldErrors = const {}]);
  final String message;
  final Map<String, String> fieldErrors;
  @override
  String toString() => message;
}

class OnboardingDatasource {
  const OnboardingDatasource(this._dio);

  final Dio _dio;

  Future<OnboardingProfileModel> fetchProfile({String status = 'pending'}) async {
    final results = await Future.wait([
      _dio.get(ApiConstants.onboardingProfile),
      fetchDocuments(),
    ]);
    final response = results[0] as Response;
    final documents = results[1] as List<OnboardingDocModel>;
    return OnboardingProfileModel.fromJson(
      response.data as Map<String, dynamic>,
      status: status,
      documents: documents,
    );
  }

  Future<void> saveStep(int step, Map<String, dynamic> data) async {
    try {
      await _dio.patch(ApiConstants.onboardingStep(step), data: data);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] is String) {
        final fieldErrors = <String, String>{};
        final errs = responseData['data'];
        if (errs is Map) {
          errs.forEach((k, v) {
            final msg = v is List && v.isNotEmpty ? '${v.first}' : (v is String ? v : null);
            if (msg != null) fieldErrors['$k'] = msg;
          });
        }
        throw OnboardingSaveException(responseData['message'] as String, fieldErrors);
      }
      rethrow;
    }
  }

  dynamic _unwrap(dynamic body) => body is Map && body.containsKey('data') ? body['data'] : body;

  String? _message(DioException e) {
    final d = e.response?.data;
    return d is Map && d['message'] is String ? d['message'] as String : null;
  }

  // ── Step 4 (Documents) ────────────────────────────────────────────────────
  // PATCH /onboarding/step/4/ has two production behaviours
  // (_save_profile_step, step == 4):
  //  - a body carrying pan_number validates (format, then uniqueness across
  //    every employee) and saves the PAN only: 200 {pan_number}, or 400
  //    "PAN number is required." / the format message, or 409 for a PAN
  //    already registered to someone else;
  //  - any other body saves nothing and only checks the required documents:
  //    200 "Documents verified. You can proceed to submit." or 422 "Please
  //    upload the following required documents: …" (500 if the check fails).

  /// Saves the PAN number; returns the server's normalised value.
  Future<String> savePanNumber(String pan) async {
    try {
      final res = await _dio.patch(ApiConstants.onboardingStep(4), data: {'pan_number': pan});
      final data = _unwrap(res.data);
      return data is Map && data['pan_number'] is String ? data['pan_number'] as String : pan;
    } on DioException catch (e) {
      throw OnboardingSaveException(_message(e) ?? parseDioException(e).message);
    }
  }

  /// Save Draft on the Documents step; returns the server's confirmation.
  Future<String> verifyDocuments() async {
    try {
      final res = await _dio.patch(ApiConstants.onboardingStep(4), data: const <String, dynamic>{});
      final body = res.data;
      return body is Map && body['message'] is String ? body['message'] as String : 'Documents verified.';
    } on DioException catch (e) {
      throw OnboardingSaveException(_message(e) ?? parseDioException(e).message);
    }
  }

  // ── Admin-configured onboarding ───────────────────────────────────────────

  Future<OnboardingConfig> fetchConfig() async {
    final results = await Future.wait([
      _dio.get(ApiConstants.onboardingFieldConfig),
      _dio.get(ApiConstants.onboardingDocumentTypeConfig),
    ]);
    return OnboardingConfig(
      fieldsByStep: OnboardingConfig.parseFields(_unwrap(results[0].data)),
      documentTypes: OnboardingConfig.parseDocumentTypes(_unwrap(results[1].data)),
    );
  }

  Future<List<CustomFileValue>> fetchCustomFiles() async {
    final res = await _dio.get(ApiConstants.onboardingCustomFileFields);
    final data = _unwrap(res.data);
    return (data is List ? data : const []).whereType<Map<String, dynamic>>().map(CustomFileValue.fromJson).toList();
  }

  /// POST multipart {field_key, file}; the content type comes from the
  /// allowlist (the server checks it).
  Future<CustomFileValue> uploadCustomFile(String fieldKey, String fileName, List<int> bytes) async {
    final mime = onboardingUploadMime(fileName);
    if (mime == null) throw Exception('Only PDF, JPG, and PNG files are allowed.');
    try {
      final res = await _dio.post(
        ApiConstants.onboardingCustomFileFields,
        data: FormData.fromMap({
          'field_key': fieldKey,
          'file': MultipartFile.fromBytes(bytes, filename: fileName, contentType: DioMediaType.parse(mime)),
        }),
      );
      return CustomFileValue.fromJson(_unwrap(res.data) as Map<String, dynamic>);
    } on DioException catch (e) {
      final m = _message(e);
      if (m != null) throw Exception(m);
      rethrow;
    }
  }

  Future<void> deleteCustomFile(int id) async {
    try {
      await _dio.delete(ApiConstants.onboardingCustomFileFieldDetail(id));
    } on DioException catch (e) {
      final m = _message(e);
      if (m != null) throw Exception(m);
      rethrow;
    }
  }

  Future<List<OnboardingDocModel>> fetchDocuments() async {
    final response = await _dio.get(ApiConstants.onboardingDocuments);
    final body = response.data;
    final data = body is Map && body.containsKey('data') ? body['data'] : body;
    return (data as List<dynamic>? ?? [])
        .map((d) => OnboardingDocModel.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<OnboardingDocModel> uploadDocument(
      String docType, MultipartFile file) async {
    try {
      final formData = FormData.fromMap({
        'document_type': docType,
        'file': file,
      });
      final response = await _dio.post(
        ApiConstants.onboardingDocuments,
        data: formData,
      );
      final data = response.data is Map &&
              (response.data as Map).containsKey('data')
          ? response.data['data'] as Map<String, dynamic>
          : response.data as Map<String, dynamic>;
      return OnboardingDocModel.fromJson(data);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        throw Exception(data['message'] as String);
      }
      rethrow;
    }
  }

  Future<void> deleteDocument(int id) async {
    await _dio.delete(ApiConstants.onboardingDocumentDetail(id));
  }

  Future<void> submitProfile() async {
    try {
      await _dio.post(ApiConstants.onboardingProfile);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        throw Exception(data['message'] as String);
      }
      rethrow;
    }
  }
}
