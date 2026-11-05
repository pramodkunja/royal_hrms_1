import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/payslip_model.dart';
import '../models/payslip_query_model.dart';

class PayrollRemoteDataSource {
  final Dio _dio;
  PayrollRemoteDataSource(this._dio);

  dynamic _unwrap(dynamic body) {
    if (body is Map && body['data'] != null) return body['data'];
    return body;
  }

  // Gated server-side on the 'payroll.view_own' permission (seeded for
  // every role) — no client-side permission check needed before calling
  // this. Always returns the full list in one page-1 request (matches
  // web's my-payslip page, which fetches everything and paginates
  // client-side rather than passing page params), ordered newest-first by
  // the backend (-cycle_start).
  Future<List<PayslipModel>> fetchMyPayslips() async {
    final res = await _dio.get(ApiConstants.myPayslips);
    final data = _unwrap(res.data);
    final List<dynamic> list = switch (data) {
      List d => d,
      Map<String, dynamic> d => (d['results'] as List<dynamic>? ?? []),
      _ => [],
    };
    return list
        .whereType<Map<String, dynamic>>()
        .map(PayslipModel.fromJson)
        .toList();
  }

  // Only valid while the payslip's status is 'sent' — the backend rejects
  // it otherwise (400). Returns no data payload on success.
  Future<void> acknowledgePayslip(String id) async {
    await _dio.post(ApiConstants.acknowledgePayslip(id));
  }

  /// The employee's own queries (mine=1 — see payslip_query_model.dart).
  Future<List<PayslipQueryModel>> fetchMyQueries() async {
    final res = await _dio.get(ApiConstants.payslipQueries, queryParameters: {'mine': 1});
    final data = _unwrap(res.data);
    return (data is List ? data : const [])
        .whereType<Map<String, dynamic>>()
        .map(PayslipQueryModel.fromJson)
        .toList();
  }

  /// HR queue: the open queries in the caller's scope. Only call this for a
  /// payroll.view holder — for anyone else the server returns their own
  /// queries instead (see payslip_query_model.dart).
  Future<List<PayslipQueryModel>> fetchTeamQueries() async {
    final res = await _dio.get(ApiConstants.payslipQueries);
    final data = _unwrap(res.data);
    return (data is List ? data : const [])
        .whereType<Map<String, dynamic>>()
        .map(PayslipQueryModel.fromJson)
        .toList();
  }

  /// Resolves an open query with [resolutionNote] (payroll.edit). Returns
  /// the resolved query as the server sends it.
  Future<PayslipQueryModel> resolveQuery(String id, {required String resolutionNote}) async {
    final res = await _dio.post(ApiConstants.resolvePayslipQuery(id),
        data: {'resolution_note': resolutionNote.trim()});
    final data = _unwrap(res.data);
    return PayslipQueryModel.fromJson(data is Map ? data.cast<String, dynamic>() : const <String, dynamic>{});
  }

  /// Raises a query on one of the employee's own payslips.
  Future<PayslipQueryModel> raiseQuery({required String payslipId, required String description}) async {
    final res = await _dio.post(ApiConstants.payslipQueries,
        data: {'payslip': payslipId, 'description': description.trim()});
    return PayslipQueryModel.fromJson((_unwrap(res.data) as Map).cast<String, dynamic>());
  }
}
