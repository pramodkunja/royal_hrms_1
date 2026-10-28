import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../domain/entities/face_registration_entity.dart';
import '../models/face_employee_model.dart';
import '../models/face_registration_model.dart';
import '../models/face_verification_status_model.dart';

/// Talks to the real apps/attendance face-registration/face-verification
/// endpoints (see api_constants.dart) — the backend only ever accepts an
/// already-computed embedding (never an image); mobile computes that
/// embedding entirely on-device (see presentation/capture/), so this class
/// never uploads a photo anywhere.
class FacialRecognitionRemoteDataSource {
  final Dio _dio;
  FacialRecognitionRemoteDataSource(this._dio);

  dynamic _unwrap(dynamic body) {
    if (body is Map && body['data'] != null) return body['data'];
    return body;
  }

  List<Map<String, dynamic>> _unwrapList(dynamic body) {
    final data = _unwrap(body);
    final List<dynamic> list = switch (data) {
      List d => d,
      Map<String, dynamic> d => (d['results'] as List<dynamic>? ?? []),
      _ => [],
    };
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<FaceVerificationStatusModel> getVerificationStatus() async {
    final res = await _dio.get(ApiConstants.faceVerificationStatus);
    return FaceVerificationStatusModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<FaceRegistrationModel?> getMyRegistrationStatus() async {
    final res = await _dio.get(ApiConstants.faceRegistrationMe);
    final data = _unwrap(res.data);
    if (data is! Map<String, dynamic> || data.isEmpty) return null;
    return FaceRegistrationModel.fromJson(data);
  }

  Future<FaceRegistrationModel> submitRegistration({
    required List<double> faceEmbedding,
    required bool livenessPassed,
    double? livenessScore,
    required bool consentAcknowledged,
  }) async {
    final res = await _dio.post(ApiConstants.faceRegistrationSubmit, data: {
      'face_embedding': faceEmbedding,
      'liveness_passed': livenessPassed,
      if (livenessScore != null) 'liveness_score': livenessScore,
      'consent_acknowledged': consentAcknowledged,
      // Mobile always captures exactly one still photo (see
      // face_capture_controller.dart — no multi-frame averaging loop like
      // web's lib/faceApi/multiFrameCapture.ts), so this is a plain fact,
      // not an approximation. capture_variance is deliberately NOT sent —
      // it's a pairwise-distance-between-frames measurement that has no
      // meaning for a single frame; sending 0 would misleadingly read as
      // "measured and found identical" rather than "never measured".
      'capture_frame_count': 1,
    });
    return FaceRegistrationModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  /// Matches web's page-based pagination for this list exactly (page /
  /// page_size=20, backed by the `{count, page, page_size, total_pages,
  /// results}` envelope from core/pagination.py — see
  /// FaceRegistrationPendingListView, apps/attendance/views/face_registration.py).
  Future<PaginatedFaceRegistrations> getPendingRegistrations({int page = 1, int pageSize = 20}) async {
    final res = await _dio.get(ApiConstants.faceRegistrationPending, queryParameters: {
      'page': page,
      'page_size': pageSize,
    });
    final data = _unwrap(res.data);
    if (data is Map<String, dynamic> && data.containsKey('results')) {
      final results = ((data['results'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(FaceRegistrationModel.fromJson)
          .toList();
      return PaginatedFaceRegistrations(
        results: results,
        count: (data['count'] as num?)?.toInt() ?? results.length,
        page: (data['page'] as num?)?.toInt() ?? page,
        pageSize: (data['page_size'] as num?)?.toInt() ?? pageSize,
        totalPages: (data['total_pages'] as num?)?.toInt() ?? 1,
      );
    }
    // Defensive fallback if the backend ever returns a plain (unpaginated) list.
    final results = _unwrapList(res.data).map(FaceRegistrationModel.fromJson).toList();
    return PaginatedFaceRegistrations(
      results: results,
      count: results.length,
      page: 1,
      pageSize: pageSize,
      totalPages: 1,
    );
  }

  Future<FaceRegistrationModel> reviewRegistration({
    required String id,
    required bool approve,
    String notes = '',
  }) async {
    final res = await _dio.patch(ApiConstants.faceRegistrationReview(id), data: {
      'status': approve ? 'approved' : 'rejected',
      if (notes.isNotEmpty) 'notes': notes,
    });
    return FaceRegistrationModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<List<FaceEmployeeModel>> searchEmployees(String query) async {
    final res = await _dio.get(
      ApiConstants.faceRegistrationEmployees,
      queryParameters: {if (query.isNotEmpty) 'search': query},
    );
    return _unwrapList(res.data).map(FaceEmployeeModel.fromJson).toList();
  }

  Future<FaceRegistrationModel?> getEmployeeStatus(String employeeUuid) async {
    final res = await _dio.get(ApiConstants.faceRegistrationEmployeeStatus(employeeUuid));
    final data = _unwrap(res.data);
    if (data is! Map<String, dynamic> || data.isEmpty) return null;
    return FaceRegistrationModel.fromJson(data);
  }

  Future<FaceRegistrationModel> hrRegister({
    required String employeeUuid,
    required List<double> faceEmbedding,
    required bool livenessPassed,
    double? livenessScore,
    required bool consentAcknowledged,
  }) async {
    final res = await _dio.post(ApiConstants.faceRegistrationHrRegister, data: {
      'employee_uuid': employeeUuid,
      'face_embedding': faceEmbedding,
      'liveness_passed': livenessPassed,
      if (livenessScore != null) 'liveness_score': livenessScore,
      'consent_acknowledged': consentAcknowledged,
      // See submitRegistration's own comment — same single-photo capture,
      // same reason capture_variance is omitted rather than sent as 0.
      'capture_frame_count': 1,
    });
    return FaceRegistrationModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }
}
