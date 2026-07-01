import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/leave_models.dart';

class LeaveRemoteDataSource {
  final Dio _dio;
  LeaveRemoteDataSource(this._dio);

  dynamic _unwrap(dynamic body) {
    if (body is Map && body['data'] != null) return body['data'];
    return body;
  }

  Future<List<LeaveTypeModel>> fetchLeaveTypes() async {
    final res = await _dio.get(ApiConstants.leaveTypes);
    final data = _unwrap(res.data);
    final List<dynamic> list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(LeaveTypeModel.fromJson)
        .toList();
  }

  Future<List<LeaveBalanceModel>> fetchLeaveBalances() async {
    final res = await _dio.get(ApiConstants.leaveBalances);
    final data = _unwrap(res.data);
    final List<dynamic> list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(LeaveBalanceModel.fromJson)
        .toList();
  }

  Future<LeaveStatsModel> fetchLeaveStats() async {
    final res = await _dio.get(ApiConstants.leaveStats);
    return LeaveStatsModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<List<LeaveRequestModel>> fetchLeaveRequests({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final res =
        await _dio.get(ApiConstants.leaves, queryParameters: params);
    final data = _unwrap(res.data);
    // Handle both plain list and paginated {count, results}
    final List<dynamic> list = switch (data) {
      List d                   => d,
      Map<String, dynamic> d   => (d['results'] as List<dynamic>? ?? []),
      _                        => [],
    };
    return list
        .whereType<Map<String, dynamic>>()
        .map(LeaveRequestModel.fromJson)
        .toList();
  }

  // leaveTypeCode: 'CL', 'EL', 'SL', etc.
  // fromDate/toDate: 'YYYY-MM-DD'
  // duration: 'full_day' | 'half_day_morning' | 'half_day_afternoon'
  Future<LeaveRequestModel> applyLeave({
    required String leaveTypeCode,
    required String fromDate,
    required String toDate,
    required String reason,
    required String duration,
  }) async {
    final res = await _dio.post(ApiConstants.leaves, data: {
      'leave_type':  leaveTypeCode,
      'start_date':  fromDate,
      'end_date':    toDate,
      'reason':      reason,
      'duration':    duration,
    });
    return LeaveRequestModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> cancelLeave(String id) async {
    await _dio.post(
      ApiConstants.leaveAction(id),
      data: {'action': 'cancel'},
    );
  }

  Future<void> approveLeave(String id) async {
    await _dio.post(
      ApiConstants.leaveAction(id),
      data: {'action': 'approve'},
    );
  }

  Future<void> rejectLeave(String id, String rejectReason) async {
    await _dio.post(
      ApiConstants.leaveAction(id),
      data: {'action': 'reject', 'reason': rejectReason},
    );
  }
}
