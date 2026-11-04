import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../domain/entities/wfh_daily_report_entity.dart';
import '../models/wfh_daily_report_model.dart';

/// GET/POST /api/wfh/reports/ and POST /api/wfh/reports/<id>/review/.
///
/// The list endpoint has no pagination and no date filter: it returns a plain
/// list, newest date first, capped at 200 rows server-side. `mine=1` gives the
/// caller's own reports; without it, the reports the caller may review.
class WfhReportRemoteDataSource {
  final Dio _dio;
  WfhReportRemoteDataSource(this._dio);

  dynamic _unwrap(dynamic body) =>
      body is Map && body.containsKey('data') ? body['data'] : body;

  String _message(dynamic body, String fallback) {
    final m = body is Map ? body['message'] : null;
    return m is String && m.trim().isNotEmpty ? m : fallback;
  }

  Future<List<WfhDailyReportModel>> fetchReports({required bool mine}) async {
    final res = await _dio.get(
      ApiConstants.wfhReports,
      queryParameters: mine ? const {'mine': '1'} : null,
    );
    final data = _unwrap(res.data);
    final list = data is List ? data : const [];
    return list.whereType<Map<String, dynamic>>().map(WfhDailyReportModel.fromJson).toList();
  }

  Future<WfhReportSaveResult> submitReport({
    required String date,
    required String completedWork,
    required String pendingWork,
    required String updates,
  }) async {
    final res = await _dio.post(ApiConstants.wfhReports, data: {
      'date': date,
      'completed_work': completedWork,
      'pending_work': pendingWork,
      'updates': updates,
    });
    return (
      message: _message(res.data, 'Report submitted.'),
      report: WfhDailyReportModel.fromJson(_unwrap(res.data) as Map<String, dynamic>),
    );
  }

  Future<WfhReportSaveResult> reviewReport({
    required int id,
    required String outcome,
    required String remarks,
  }) async {
    final res = await _dio.post(
      ApiConstants.wfhReportReview(id),
      data: {'outcome': outcome, 'remarks': remarks},
    );
    return (
      message: _message(res.data, 'Report reviewed.'),
      report: WfhDailyReportModel.fromJson(_unwrap(res.data) as Map<String, dynamic>),
    );
  }
}
