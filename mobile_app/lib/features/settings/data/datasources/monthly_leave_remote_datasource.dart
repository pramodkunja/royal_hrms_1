import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/monthly_leave_models.dart';

/// The Monthly Leave Management endpoints, exactly as web calls them
/// (MonthlyLeaveTab.tsx / MonthlyAssignmentsSection.tsx).
class MonthlyLeaveRemoteDataSource {
  MonthlyLeaveRemoteDataSource(this._dio);
  final Dio _dio;

  Map<String, dynamic> _data(Object? body) {
    final d = body is Map ? body['data'] : null;
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  /// GET /leave/monthly-credits/assignments/?year=&month=
  Future<MonthlyAssignments> fetchAssignments({required int year, required int month}) async {
    final res = await _dio.get(ApiConstants.leaveMonthlyAssignments, queryParameters: {'year': year, 'month': month});
    return MonthlyAssignments.fromJson(_data(res.data));
  }

  /// POST /leave/monthly-credits/ — set one employee's credit for a month.
  /// Returns the server's message ("Monthly leave credit updated." …).
  Future<String> setCredit({
    required String employeeId,
    required String leaveType,
    required int year,
    required int month,
    required String credit,
  }) async {
    final res = await _dio.post(ApiConstants.leaveMonthlyCredits, data: {
      'employee_id': employeeId,
      'leave_type': leaveType,
      'year': year,
      'month': month,
      'credit': credit.trim(),
    });
    final body = res.data;
    return body is Map && body['message'] is String ? body['message'] as String : 'Monthly leave credit saved.';
  }

  Map<String, dynamic> _bulkBody(List<String> employeeIds, String leaveType, int year, int month, String credit,
          {required bool dryRun}) =>
      {
        'employee_ids': employeeIds,
        'leave_type': leaveType,
        'year': year,
        'month': month,
        'credit': credit.trim(),
        if (dryRun) 'dry_run': true,
      };

  /// POST /leave/monthly-credits/bulk/ with dry_run — nothing is saved.
  Future<MonthlyPlan> bulkReview({
    required List<String> employeeIds,
    required String leaveType,
    required int year,
    required int month,
    required String credit,
  }) async {
    final res = await _dio.post(ApiConstants.leaveMonthlyCreditsBulk,
        data: _bulkBody(employeeIds, leaveType, year, month, credit, dryRun: true));
    return MonthlyPlan.fromJson(_data(res.data));
  }

  /// POST /leave/monthly-credits/bulk/ — saves.
  Future<MonthlyApplyResult> bulkApply({
    required List<String> employeeIds,
    required String leaveType,
    required int year,
    required int month,
    required String credit,
  }) async {
    final res = await _dio.post(ApiConstants.leaveMonthlyCreditsBulk,
        data: _bulkBody(employeeIds, leaveType, year, month, credit, dryRun: false));
    return MonthlyApplyResult.fromJson(_data(res.data));
  }

  FormData _importForm(List<int> bytes, String fileName, int year, int month, {required bool dryRun}) =>
      FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
        'year': '$year',
        'month': '$month',
        if (dryRun) 'dry_run': 'true',
      });

  /// POST /leave/monthly-credits/import/ (multipart) with dry_run=true.
  Future<MonthlyPlan> importPreview(
      {required List<int> bytes, required String fileName, required int year, required int month}) async {
    final res = await _dio.post(ApiConstants.leaveMonthlyCreditsImport,
        data: _importForm(bytes, fileName, year, month, dryRun: true));
    return MonthlyPlan.fromJson(_data(res.data));
  }

  /// POST /leave/monthly-credits/import/ (multipart) — saves.
  Future<MonthlyApplyResult> importApply(
      {required List<int> bytes, required String fileName, required int year, required int month}) async {
    final res = await _dio.post(ApiConstants.leaveMonthlyCreditsImport,
        data: _importForm(bytes, fileName, year, month, dryRun: false));
    return MonthlyApplyResult.fromJson(_data(res.data));
  }

  /// GET /leave/monthly-credits/import/sample/?format=csv|xlsx — file bytes.
  Future<List<int>> sample(String format) async {
    try {
      final res = await _dio.get(ApiConstants.leaveMonthlyCreditsSample,
          queryParameters: {'format': format}, options: Options(responseType: ResponseType.bytes));
      return res.data as List<int>;
    } on DioException catch (e) {
      // A refusal arrives as bytes here; decode it so its message can be shown.
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
}
