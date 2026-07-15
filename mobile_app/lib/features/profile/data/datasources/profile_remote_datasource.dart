import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/my_profile_model.dart';
import '../models/profile_document_model.dart';

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

  // ── Helper ─────────────────────────────────────────────────────────────────

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }
}
