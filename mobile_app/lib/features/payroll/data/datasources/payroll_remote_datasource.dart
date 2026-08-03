import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/payslip_model.dart';

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
}
