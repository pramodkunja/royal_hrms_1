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
  // duration: 'full_day' | 'half_morning' | 'half_afternoon' (must match backend DURATION_CHOICES)
  // document: optional supporting file, sent as multipart field 'document'
  // (backend LeaveRequestCreateSerializer.validate_document — max 5MB, PDF/JPG/PNG only)
  Future<LeaveRequestModel> applyLeave({
    required String leaveTypeCode,
    required String fromDate,
    required String toDate,
    required String reason,
    required String duration,
    String? handoverTo,
    String? contactDuringLeave,
    String? handoverNotes,
    MultipartFile? document,
  }) async {
    final formData = FormData.fromMap({
      'leave_type': leaveTypeCode,
      'start_date': fromDate,
      'end_date':   toDate,
      'reason':     reason,
      'duration':   duration,
      if (handoverTo != null && handoverTo.isNotEmpty)
        'handover_to': handoverTo,
      if (contactDuringLeave != null && contactDuringLeave.isNotEmpty)
        'contact_during_leave': contactDuringLeave,
      if (handoverNotes != null && handoverNotes.isNotEmpty)
        'handover_notes': handoverNotes,
      if (document != null) 'document': document,
    });
    final res = await _dio.post(ApiConstants.leaves, data: formData);
    return LeaveRequestModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> cancelLeave(String id) async {
    // Cancel goes to the detail endpoint (PATCH), not the approve endpoint
    await _dio.patch(ApiConstants.leaveDetail(id));
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
      data: {'action': 'reject', 'remarks': rejectReason},
    );
  }

  Future<List<LeaveCalendarEventModel>> fetchCalendar({
    int? year,
    int? month,
  }) async {
    final params = <String, dynamic>{};
    if (year != null) params['year'] = year;
    if (month != null) params['month'] = month;
    final res = await _dio.get(
      ApiConstants.leaveCalendar,
      queryParameters: params,
    );
    final data = _unwrap(res.data);
    final List<dynamic> list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(LeaveCalendarEventModel.fromJson)
        .toList();
  }
}
