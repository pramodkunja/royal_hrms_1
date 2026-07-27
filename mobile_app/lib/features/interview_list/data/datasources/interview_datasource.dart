import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/models/bulk_import_result.dart';
import '../models/candidate_model.dart';

class InterviewDataSource {
  final Dio _dio;
  InterviewDataSource(this._dio);

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      return body['data'] ?? body;
    }
    return body;
  }

  Future<CandidateStatsModel> fetchStats() async {
    final res = await _dio.get(ApiConstants.candidateStats);
    return CandidateStatsModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<List<CandidateModel>> fetchCandidates({
    String? status,
    int? branchId,
  }) async {
    final params = <String, dynamic>{'page_size': 100};
    if (status != null && status != 'all') params['status'] = status;
    if (branchId != null) params['branch'] = branchId;

    final res = await _dio.get(ApiConstants.candidates,
        queryParameters: params);
    final data = _unwrap(res.data);
    final results = (data is Map<String, dynamic>
            ? data['results']
            : data) as List<dynamic>;
    return results
        .map((e) => CandidateModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CandidateModel> fetchCandidate(int id) async {
    final res = await _dio.get(ApiConstants.candidateDetail(id));
    return CandidateModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<CandidateModel> createCandidate(
      Map<String, dynamic> data) async {
    final res = await _dio.post(ApiConstants.candidates, data: data);
    return CandidateModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<CandidateModel> updateCandidate(
      int id, Map<String, dynamic> data) async {
    final res = await _dio.put(ApiConstants.candidateDetail(id), data: data);
    return CandidateModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<CandidateModel> updateStatus(int id, String status,
      {String? remarks}) async {
    final res = await _dio.patch(
      ApiConstants.candidateStatus(id),
      data: {
        'status': status,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      },
    );
    return CandidateModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  // Mirrors web's MarkCandidateModal/EditCandidateModal — POST
  // /recruitment/candidates/<id>/send-email/ with a fixed template name and
  // rendered placeholder context. Fire-and-forget from the caller's point of
  // view: a failure here should never be treated as the status/edit action
  // itself having failed, since that already succeeded server-side.
  Future<void> sendEmail(
    int id, {
    required String templateName,
    required Map<String, String> extraContext,
  }) async {
    await _dio.post(
      ApiConstants.candidateSendEmail(id.toString()),
      data: {
        'template_name': templateName,
        'extra_context': extraContext,
      },
    );
  }

  Future<void> sendPortalLogin(int id) async {
    await _dio.post(ApiConstants.candidateSendLogin(id));
  }

  Future<void> resendPortalLogin(int id) async {
    await _dio.post(ApiConstants.candidateResendLogin(id));
  }

  // ── Bulk Import (CSV/XLSX, max 1000 rows / 5MB — HR/system_admin only) ──────
  //
  // Required columns: name, email, position_applied, branch_name. Optional:
  // phone, interview_date, interview_mode, notes. See
  // CandidateBulkImportRowSerializer in the backend for exact validation.

  Future<BulkImportResult> bulkImport({
    required Uint8List bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post(
      ApiConstants.candidateBulkImport,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return BulkImportResult.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }
}
