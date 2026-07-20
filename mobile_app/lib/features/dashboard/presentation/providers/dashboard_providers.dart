import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../data/models/admin_dashboard_models.dart';
import '../../data/models/dashboard_common_models.dart';
import '../../data/models/employee_dashboard_models.dart';
import '../../data/models/hr_dashboard_models.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final dashboardDataSourceProvider = Provider<DashboardRemoteDataSource>((ref) {
  return DashboardRemoteDataSource(ref.watch(dioProvider));
});

// ── System Admin ──────────────────────────────────────────────────────────────

final systemAdminKpisProvider = FutureProvider.autoDispose<SystemAdminKpis>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchSystemAdminKpis(),
);

final systemAdminAnnouncementProvider =
    FutureProvider.autoDispose<DashboardAnnouncement?>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchSystemAdminAnnouncement(),
);

final pendingApprovalsProvider = FutureProvider.autoDispose<PendingApprovals>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchPendingApprovals(),
);

final systemAdminDepartmentHeadcountProvider =
    FutureProvider.autoDispose<List<DeptHeadcount>>(
  (ref) => ref
      .read(dashboardDataSourceProvider)
      .fetchSystemAdminDepartmentHeadcount(),
);

final systemAdminEmployeeLifecycleProvider =
    FutureProvider.autoDispose<AdminEmployeeLifecycle>(
  (ref) => ref
      .read(dashboardDataSourceProvider)
      .fetchSystemAdminEmployeeLifecycle(),
);

final systemAdminBirthdaysTodayProvider =
    FutureProvider.autoDispose<List<DashboardBirthdayEmployee>>(
  (ref) =>
      ref.read(dashboardDataSourceProvider).fetchSystemAdminBirthdaysToday(),
);

final systemAdminBirthdaysUpcomingProvider =
    FutureProvider.autoDispose<List<DashboardBirthdayEmployee>>(
  (ref) => ref
      .read(dashboardDataSourceProvider)
      .fetchSystemAdminBirthdaysUpcoming(),
);

/// Keyed by (offset, module) so the "Load more" pagination and module
/// filter dropdown on the Admin dashboard's Audit Logs card can each be
/// backed by a distinct, independently-cached page — `ref.invalidate(
/// auditLogsPageProvider)` (no params) clears every cached page/module
/// combination at once, which is what pull-to-refresh does.
final auditLogsPageProvider = FutureProvider.autoDispose
    .family<AuditLogsResponse, ({int offset, String module})>(
  (ref, params) => ref.read(dashboardDataSourceProvider).fetchAuditLogs(
        limit: 20,
        offset: params.offset,
        module: params.module,
      ),
);

// ── HR ─────────────────────────────────────────────────────────────────────

final hrKpisProvider = FutureProvider.autoDispose<HrKpis>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchHrKpis(),
);

final hrAttendanceSummaryProvider =
    FutureProvider.autoDispose<HrAttendanceSummary>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchHrAttendanceSummary(),
);

final hrActionQueueProvider = FutureProvider.autoDispose<HrActionQueue>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchHrActionQueue(),
);

final hrRecruitmentFunnelProvider =
    FutureProvider.autoDispose<HrRecruitmentFunnel>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchHrRecruitmentFunnel(),
);

final hrEmployeeLifecycleProvider =
    FutureProvider.autoDispose<HrEmployeeLifecycle>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchHrEmployeeLifecycle(),
);

final hrBirthdaysTodayProvider =
    FutureProvider.autoDispose<List<DashboardBirthdayEmployee>>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchHrBirthdaysToday(),
);

final hrBirthdaysUpcomingProvider =
    FutureProvider.autoDispose<List<DashboardBirthdayEmployee>>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchHrBirthdaysUpcoming(),
);

final hrDepartmentHeadcountProvider =
    FutureProvider.autoDispose<List<DeptHeadcount>>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchHrDepartmentHeadcount(),
);

// ── Employee ───────────────────────────────────────────────────────────────

final employeeKpisProvider = FutureProvider.autoDispose<EmployeeKpis>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchEmployeeKpis(),
);

final employeeLeaveBalancesProvider =
    FutureProvider.autoDispose<EmployeeLeaveBalanceSummary>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchEmployeeLeaveBalances(),
);

final employeeActionItemsProvider =
    FutureProvider.autoDispose<ActionItemsResponse>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchEmployeeActionItems(),
);

final employeeRecentRequestsProvider =
    FutureProvider.autoDispose<RecentRequestsResponse>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchEmployeeRecentRequests(),
);

final employeeAttendanceSummaryProvider =
    FutureProvider.autoDispose<EmployeeAttendanceSummary>(
  (ref) =>
      ref.read(dashboardDataSourceProvider).fetchEmployeeAttendanceSummary(),
);

/// Keyed by (month, year) so the Employee dashboard's month picker (mirrors
/// web's `EmpAttendanceSummary` month `<select>`) can switch periods without
/// losing the previously-fetched month's cached data.
final employeeAttendanceSummaryForProvider = FutureProvider.autoDispose
    .family<EmployeeAttendanceSummary, ({int month, int year})>(
  (ref, params) => ref.read(dashboardDataSourceProvider).fetchEmployeeAttendanceSummary(
        month: params.month,
        year: params.year,
      ),
);

final employeeAttendanceStatusProvider =
    FutureProvider.autoDispose<EmployeeAttendanceStatus>(
  (ref) =>
      ref.read(dashboardDataSourceProvider).fetchEmployeeAttendanceStatus(),
);

// ── Shared ─────────────────────────────────────────────────────────────────

final sharedAnnouncementProvider =
    FutureProvider.autoDispose<DashboardAnnouncement?>(
  (ref) => ref.read(dashboardDataSourceProvider).fetchSharedAnnouncement(),
);

// ── Error helper ───────────────────────────────────────────────────────────

String friendlyDashboardError(Object e) {
  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('connection')) {
    return 'Cannot reach server. Check your connection.';
  }
  if (msg.contains('403')) return 'You do not have permission to view this.';
  if (msg.contains('401')) return 'Session expired. Please log in again.';
  if (msg.contains('404')) return 'This could not be loaded right now.';
  if (msg.contains('500')) return 'Server error. Please try again later.';
  return 'Something went wrong loading this. Please try again.';
}
