import 'dart:convert';
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

  /// GET /recruitment/candidates/ exactly as web's RECRUITMENT_API.list:
  /// `search`, `status`, `page` (no `page_size`, so the server's default of
  /// 10). The server matches `search` against name, email and position
  /// applied, honours `status` for pending / selected / rejected only, and
  /// scopes non-admins to their own branch.
  Future<CandidatePage> fetchCandidatePage({String search = '', String? status, int page = 1, int? branchId}) async {
    final params = <String, dynamic>{
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status != 'all') 'status': status,
      if (branchId != null) 'branch': branchId,
      'page': page,
    };
    final res = await _dio.get(ApiConstants.candidates, queryParameters: params);
    return CandidatePage.fromData(_unwrap(res.data), requestedPage: page);
  }

  /// Page 1 only (kept for callers that just need a list).
  Future<List<CandidateModel>> fetchCandidates({String? status, int? branchId}) async =>
      (await fetchCandidatePage(status: status, branchId: branchId)).results;

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

  /// PATCH /recruitment/candidates/<id>/status/. For `selected` / `rejected`
  /// the backend itself sends the candidate_selected / candidate_rejected
  /// email and reports the outcome only in the envelope `message` (e.g.
  /// "… Email could not be sent — check SMTP settings."), so the message is
  /// returned alongside the updated candidate. Clients must NOT also call
  /// /send-email/ — that would email the candidate twice.
  Future<({CandidateModel candidate, String message})> updateStatus(
      int id, String status,
      {String? remarks}) async {
    final res = await _dio.patch(
      ApiConstants.candidateStatus(id),
      data: {
        'status': status,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      },
    );
    final body = res.data;
    final message =
        body is Map && body['message'] is String ? body['message'] as String : '';
    return (
      candidate: CandidateModel.fromJson(_unwrap(res.data) as Map<String, dynamic>),
      message: message,
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

  /// The import template, built by the server exactly as web downloads it:
  /// GET /recruitment/candidates/bulk-import/sample/?format=csv|xlsx
  /// (CandidateBulkImportSampleView, recruitment.view) → the file bytes
  /// (header row "Candidate Name, Email, Mobile Number, Position Applied,
  /// Branch, Interview Date, Interview Mode, Notes" + two example rows).
  /// A refusal arrives as bytes too; it is decoded so its message is shown.
  Future<List<int>> fetchBulkImportSample(String format) async {
    try {
      final res = await _dio.get(ApiConstants.candidateBulkImportSample,
          queryParameters: {'format': format}, options: Options(responseType: ResponseType.bytes));
      return res.data as List<int>;
    } on DioException catch (e) {
      final res = e.response;
      final data = res?.data;
      if (res != null && data is List<int>) {
        Object? decoded;
        try {
          decoded = jsonDecode(utf8.decode(data, allowMalformed: true));
        } catch (_) {}
        if (decoded is Map) {
          throw DioException(
            requestOptions: e.requestOptions,
            response: Response(requestOptions: res.requestOptions, statusCode: res.statusCode, data: decoded),
            type: e.type,
            error: e.error,
          );
        }
      }
      rethrow;
    }
  }

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

/// One page of GET /recruitment/candidates/:
/// `{count, page, page_size, total_pages, status_choices, results}`.
class CandidatePage {
  const CandidatePage({required this.results, required this.page, required this.totalPages, required this.count});

  final List<CandidateModel> results;
  final int page;
  final int totalPages;
  final int count;

  bool get hasMore => page < totalPages;

  factory CandidatePage.fromData(Object? data, {int requestedPage = 1}) {
    int n(Object? v, int f) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? f;
    final list = data is Map ? data['results'] : data;
    final results = list is List
        ? list.whereType<Map>().map((e) => CandidateModel.fromJson(Map<String, dynamic>.from(e))).toList()
        : <CandidateModel>[];
    if (data is! Map) {
      return CandidatePage(results: results, page: 1, totalPages: 1, count: results.length);
    }
    return CandidatePage(
      results: results,
      page: n(data['page'], requestedPage),
      totalPages: n(data['total_pages'], 1),
      count: n(data['count'], results.length),
    );
  }
}
