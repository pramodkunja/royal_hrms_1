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
    return LeaveStatsModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // scope: without it, the backend ALWAYS returns the requesting user's own
  // requests, regardless of role. Pass 'team' to get the real approval queue
  // instead — that only works when the viewer also has the leave.approve
  // permission, and is scoped by role: manager -> direct reports' pending (L1),
  // hr_admin -> same-branch l2_pending (L2), system_admin -> everyone but self
  // (see apps/hrms/views/leave.py LeaveRequestListCreateView.get /
  // _approval_scope_filter). There is no 'own' scope value — omit scope for that.
  Future<List<LeaveRequestModel>> fetchLeaveRequests({
    String? status,
    String? scope,
    int? pageSize,
  }) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (scope != null) params['scope'] = scope;
    if (pageSize != null) params['page_size'] = pageSize;
    final res = await _dio.get(ApiConstants.leaves, queryParameters: params);
    final data = _unwrap(res.data);
    // Handle both plain list and paginated {count, results}
    final List<dynamic> list = switch (data) {
      List d => d,
      Map<String, dynamic> d => (d['results'] as List<dynamic>? ?? []),
      _ => [],
    };
    return list
        .whereType<Map<String, dynamic>>()
        .map(LeaveRequestModel.fromJson)
        .toList();
  }

  // Paginated variant that preserves the count/page/total_pages envelope —
  // used by the approver Dashboard's "Pending Approvals" sub-tab (scope=team),
  // which needs real Prev/Next pagination instead of a client-truncated list.
  // branch is system_admin-only server-side (silently ignored for other
  // roles); department just requires leave.approve (any approver role) —
  // see LeaveRequestListCreateView.get.
  Future<LeaveRequestPageModel> fetchLeaveRequestsPage({
    String? status,
    String? scope,
    String? branch,
    String? department,
    int page = 1,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (status != null) params['status'] = status;
    if (scope != null) params['scope'] = scope;
    if (branch != null && branch.isNotEmpty) params['branch'] = branch;
    if (department != null && department.isNotEmpty) {
      params['department'] = department;
    }
    final res = await _dio.get(ApiConstants.leaves, queryParameters: params);
    return LeaveRequestPageModel.fromJson(_unwrap(res.data));
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
      'end_date': toDate,
      'reason': reason,
      'duration': duration,
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

  // Single-fetch used to refresh a request's detail view in the background
  // (e.g. the leave request detail sheet) — GET .../leave/requests/<id>/.
  Future<LeaveRequestModel> fetchLeaveRequestById(String id) async {
    final res = await _dio.get(ApiConstants.leaveDetail(id));
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

  // Employee-scoped variants used by the admin Employee Profile "Leave" tab —
  // employeeId here is the human-readable code (e.g. 'RSS00001'), not a
  // numeric pk (see LeaveRequestListCreateView.get / LeaveRequestStatsView:
  // ?employee_id=<code> is resolved server-side and gated on the viewer
  // having employees.view or leave.approve; 403/404 otherwise).
  Future<LeaveRequestPageModel> fetchEmployeeLeaveRequestsPage({
    required String employeeId,
    required int year,
    int page = 1,
  }) async {
    final params = <String, dynamic>{
      'employee_id': employeeId,
      'year': year,
      'page': page,
    };
    final res = await _dio.get(ApiConstants.leaves, queryParameters: params);
    return LeaveRequestPageModel.fromJson(_unwrap(res.data));
  }

  Future<LeaveStatsModel> fetchEmployeeLeaveStats({
    required String employeeId,
    required int year,
  }) async {
    final res = await _dio.get(
      ApiConstants.leaveStats,
      queryParameters: {'employee_id': employeeId, 'year': year},
    );
    return LeaveStatsModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // Authoritative day-count/LOP breakdown for a candidate leave request —
  // GET /leave/requests/?action=preview (no dedicated URL; a read-only
  // branch on the same list endpoint). leaveType is the short code ('EL',
  // 'CL', ...); dates are 'YYYY-MM-DD'; duration matches DURATION_CHOICES.
  Future<LeavePreviewModel> fetchLeavePreview({
    required String leaveType,
    required String startDate,
    required String endDate,
    String? duration,
  }) async {
    final res = await _dio.get(ApiConstants.leaves, queryParameters: {
      'action': 'preview',
      'leave_type': leaveType,
      'start_date': startDate,
      'end_date': endDate,
      if (duration != null) 'duration': duration,
    });
    return LeavePreviewModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
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
