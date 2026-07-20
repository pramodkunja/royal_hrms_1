import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/admin_dashboard_models.dart';
import '../models/dashboard_common_models.dart';
import '../models/employee_dashboard_models.dart';
import '../models/hr_dashboard_models.dart';

/// All `apps/dashboard` endpoints in one datasource — mirrors how the web
/// frontend's dashboard widgets are all thin wrappers over the same
/// `apps/dashboard` Django app. System-admin/HR calls 403 server-side if the
/// signed-in user's role doesn't match; callers should only invoke the
/// methods for the dashboard the current user's role resolves to.
class DashboardRemoteDataSource {
  final Dio _dio;
  DashboardRemoteDataSource(this._dio);

  dynamic _unwrap(dynamic body) {
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  Map<String, dynamic> _asMap(dynamic body) {
    final data = _unwrap(body);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  List<T> _asList<T>(
    dynamic body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final data = _unwrap(body);
    final list = data is List<dynamic> ? data : <dynamic>[];
    return list.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }

  // ── System Admin ───────────────────────────────────────────────────────────

  Future<SystemAdminKpis> fetchSystemAdminKpis() async {
    final res = await _dio.get(ApiConstants.dashboardSystemAdminKpis);
    return SystemAdminKpis.fromJson(_asMap(res.data));
  }

  Future<DashboardAnnouncement?> fetchSystemAdminAnnouncement() async {
    final res = await _dio.get(ApiConstants.dashboardSystemAdminAnnouncement);
    final data = _unwrap(res.data);
    return data is Map<String, dynamic>
        ? DashboardAnnouncement.fromJson(data)
        : null;
  }

  Future<PendingApprovals> fetchPendingApprovals() async {
    final res =
        await _dio.get(ApiConstants.dashboardSystemAdminPendingApprovals);
    return PendingApprovals.fromJson(_asMap(res.data));
  }

  Future<List<DeptHeadcount>> fetchSystemAdminDepartmentHeadcount() async {
    final res =
        await _dio.get(ApiConstants.dashboardSystemAdminDepartmentHeadcount);
    return _asList(res.data, DeptHeadcount.fromJson);
  }

  Future<AdminEmployeeLifecycle> fetchSystemAdminEmployeeLifecycle() async {
    final res =
        await _dio.get(ApiConstants.dashboardSystemAdminEmployeeLifecycle);
    return AdminEmployeeLifecycle.fromJson(_asMap(res.data));
  }

  Future<List<DashboardBirthdayEmployee>>
      fetchSystemAdminBirthdaysToday() async {
    final res =
        await _dio.get(ApiConstants.dashboardSystemAdminBirthdaysToday);
    return _asList(res.data, DashboardBirthdayEmployee.fromJson);
  }

  Future<List<DashboardBirthdayEmployee>>
      fetchSystemAdminBirthdaysUpcoming() async {
    final res =
        await _dio.get(ApiConstants.dashboardSystemAdminBirthdaysUpcoming);
    return _asList(res.data, DashboardBirthdayEmployee.fromJson);
  }

  Future<AuditLogsResponse> fetchAuditLogs({
    int limit = 20,
    int offset = 0,
    String? module,
  }) async {
    final res = await _dio.get(
      ApiConstants.dashboardSystemAdminAuditLogs,
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (module != null && module.isNotEmpty) 'module': module,
      },
    );
    return AuditLogsResponse.fromJson(_asMap(res.data));
  }

  // ── HR ──────────────────────────────────────────────────────────────────────

  Future<HrKpis> fetchHrKpis() async {
    final res = await _dio.get(ApiConstants.dashboardHrKpis);
    return HrKpis.fromJson(_asMap(res.data));
  }

  Future<HrAttendanceSummary> fetchHrAttendanceSummary() async {
    final res = await _dio.get(ApiConstants.dashboardHrAttendanceSummary);
    return HrAttendanceSummary.fromJson(_asMap(res.data));
  }

  Future<HrActionQueue> fetchHrActionQueue() async {
    final res = await _dio.get(ApiConstants.dashboardHrActionQueue);
    return HrActionQueue.fromJson(_asMap(res.data));
  }

  Future<HrRecruitmentFunnel> fetchHrRecruitmentFunnel() async {
    final res = await _dio.get(ApiConstants.dashboardHrRecruitmentFunnel);
    return HrRecruitmentFunnel.fromJson(_asMap(res.data));
  }

  Future<HrEmployeeLifecycle> fetchHrEmployeeLifecycle() async {
    final res = await _dio.get(ApiConstants.dashboardHrEmployeeLifecycle);
    return HrEmployeeLifecycle.fromJson(_asMap(res.data));
  }

  Future<List<DashboardBirthdayEmployee>> fetchHrBirthdaysToday() async {
    final res = await _dio.get(ApiConstants.dashboardHrBirthdaysToday);
    return _asList(res.data, DashboardBirthdayEmployee.fromJson);
  }

  Future<List<DashboardBirthdayEmployee>> fetchHrBirthdaysUpcoming() async {
    final res = await _dio.get(ApiConstants.dashboardHrBirthdaysUpcoming);
    return _asList(res.data, DashboardBirthdayEmployee.fromJson);
  }

  Future<List<DeptHeadcount>> fetchHrDepartmentHeadcount() async {
    final res = await _dio.get(ApiConstants.dashboardHrDepartmentHeadcount);
    return _asList(res.data, DeptHeadcount.fromJson);
  }

  // ── Employee ────────────────────────────────────────────────────────────────

  Future<EmployeeKpis> fetchEmployeeKpis() async {
    final res = await _dio.get(ApiConstants.dashboardEmployeeKpis);
    return EmployeeKpis.fromJson(_asMap(res.data));
  }

  Future<EmployeeLeaveBalanceSummary> fetchEmployeeLeaveBalances(
      {int? year}) async {
    final res = await _dio.get(
      ApiConstants.dashboardEmployeeLeaveBalances,
      queryParameters: year != null ? {'year': year} : null,
    );
    return EmployeeLeaveBalanceSummary.fromJson(_asMap(res.data));
  }

  Future<ActionItemsResponse> fetchEmployeeActionItems() async {
    final res = await _dio.get(ApiConstants.dashboardEmployeeActionItems);
    return ActionItemsResponse.fromJson(_asMap(res.data));
  }

  Future<RecentRequestsResponse> fetchEmployeeRecentRequests() async {
    final res = await _dio.get(ApiConstants.dashboardEmployeeRecentRequests);
    return RecentRequestsResponse.fromJson(_asMap(res.data));
  }

  Future<EmployeeAttendanceSummary> fetchEmployeeAttendanceSummary({
    int? month,
    int? year,
  }) async {
    final res = await _dio.get(
      ApiConstants.dashboardEmployeeAttendanceSummary,
      queryParameters: {
        if (month != null) 'month': month,
        if (year != null) 'year': year,
      },
    );
    return EmployeeAttendanceSummary.fromJson(_asMap(res.data));
  }

  Future<EmployeeAttendanceStatus> fetchEmployeeAttendanceStatus() async {
    final res = await _dio.get(ApiConstants.dashboardEmployeeAttendanceStatus);
    return EmployeeAttendanceStatus.fromJson(_asMap(res.data));
  }

  // ── Shared ──────────────────────────────────────────────────────────────────

  Future<DashboardAnnouncement?> fetchSharedAnnouncement() async {
    final res = await _dio.get(ApiConstants.dashboardAnnouncement);
    final data = _unwrap(res.data);
    return data is Map<String, dynamic>
        ? DashboardAnnouncement.fromJson(data)
        : null;
  }
}
