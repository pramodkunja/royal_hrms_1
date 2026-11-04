import 'dashboard_common_models.dart';

// GET /dashboard/manager/ — production ManagerDashboardView
// (apps/dashboard/views/manager.py), one response with every widget, scoped
// to the manager's active direct reports. Refused (403) unless the user has
// a team-managing role, employees.view, or direct reports. Field names are
// the backend's; nothing here is computed client-side.

String _s(Object? v) => v == null ? '' : '$v';
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
List<Map<String, dynamic>> _rows(Object? v) =>
    (v is List ? v : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

class ManagerTeamOverview {
  final String greeting;
  final String managerName;
  final String currentDate;
  final int teamSize;
  final int pendingApprovals; // leave requests where this manager is L1/L2
  final int employeesOnLeaveToday;
  final double teamAttendancePercentage;

  const ManagerTeamOverview({
    this.greeting = '',
    this.managerName = '',
    this.currentDate = '',
    this.teamSize = 0,
    this.pendingApprovals = 0,
    this.employeesOnLeaveToday = 0,
    this.teamAttendancePercentage = 0,
  });

  factory ManagerTeamOverview.fromJson(Map<String, dynamic> j) => ManagerTeamOverview(
        greeting: _s(j['greeting']),
        managerName: _s(j['manager_name']),
        currentDate: _s(j['current_date']),
        teamSize: _i(j['team_size']),
        pendingApprovals: _i(j['pending_approvals']),
        employeesOnLeaveToday: _i(j['employees_on_leave_today']),
        teamAttendancePercentage: _d(j['team_attendance_percentage']),
      );
}

/// One of the server's quick actions (id, label, a web URL, optional count).
class ManagerQuickAction {
  final String id;
  final String label;
  final int? count;
  const ManagerQuickAction({required this.id, required this.label, this.count});

  factory ManagerQuickAction.fromJson(Map<String, dynamic> j) => ManagerQuickAction(
        id: _s(j['id']),
        label: _s(j['label']),
        count: j['count'] is num ? (j['count'] as num).toInt() : null,
      );
}

class ManagerPendingApproval {
  final String id;
  final String approvalType; // leave | expense | attendance_correction
  final String employeeName;
  final String employeeId;
  final String summary;
  final String dateFrom;
  final String dateTo;
  final String appliedOn;
  final String status;

  const ManagerPendingApproval({
    required this.id,
    required this.approvalType,
    required this.employeeName,
    this.employeeId = '',
    this.summary = '',
    this.dateFrom = '',
    this.dateTo = '',
    this.appliedOn = '',
    this.status = '',
  });

  factory ManagerPendingApproval.fromJson(Map<String, dynamic> j) => ManagerPendingApproval(
        id: _s(j['id']),
        approvalType: _s(j['approval_type']),
        employeeName: _s(j['employee_name']),
        employeeId: _s(j['employee_id']),
        summary: _s(j['summary']),
        dateFrom: _s(j['date_from']),
        dateTo: _s(j['date_to']),
        appliedOn: _s(j['applied_on']),
        status: _s(j['status']),
      );
}

class ManagerTeamActivity {
  final String employeeName;
  final String action;
  final String description;
  final String createdAt;
  const ManagerTeamActivity(
      {required this.employeeName, required this.action, required this.description, required this.createdAt});

  factory ManagerTeamActivity.fromJson(Map<String, dynamic> j) => ManagerTeamActivity(
        employeeName: _s(j['employee_name']),
        action: _s(j['action']),
        description: _s(j['description']),
        createdAt: _s(j['created_at']),
      );
}

class ManagerTeamAttendance {
  final String employeeId;
  final String employeeName;
  final String designation;
  final String? clockIn;
  final String? clockOut;
  final String status; // present | late | half_day | incomplete | on_leave | absent …

  const ManagerTeamAttendance({
    required this.employeeId,
    required this.employeeName,
    this.designation = '',
    this.clockIn,
    this.clockOut,
    required this.status,
  });

  factory ManagerTeamAttendance.fromJson(Map<String, dynamic> j) => ManagerTeamAttendance(
        employeeId: _s(j['employee_id']),
        employeeName: _s(j['employee_name']),
        designation: _s(j['designation']),
        clockIn: j['clock_in'] as String?,
        clockOut: j['clock_out'] as String?,
        status: _s(j['status']),
      );
}

class ManagerUpcomingLeave {
  final String id;
  final String employeeName;
  final String leaveType;
  final String dateFrom;
  final String dateTo;
  final double totalDays;
  final String status;

  const ManagerUpcomingLeave({
    required this.id,
    required this.employeeName,
    required this.leaveType,
    required this.dateFrom,
    required this.dateTo,
    required this.totalDays,
    required this.status,
  });

  factory ManagerUpcomingLeave.fromJson(Map<String, dynamic> j) => ManagerUpcomingLeave(
        id: _s(j['id']),
        employeeName: _s(j['employee_name']),
        leaveType: _s(j['leave_type']),
        dateFrom: _s(j['date_from']),
        dateTo: _s(j['date_to']),
        totalDays: _d(j['total_days']),
        status: _s(j['status']),
      );
}

class ManagerDashboardData {
  final ManagerTeamOverview overview;
  final List<ManagerQuickAction> quickActions;
  final List<ManagerPendingApproval> pendingApprovals;
  final List<DashboardBirthdayEmployee> todaysBirthdays;
  final List<DashboardBirthdayEmployee> upcomingBirthdays;
  final List<ManagerTeamActivity> recentActivity;
  final List<ManagerTeamAttendance> teamAttendance;
  final List<ManagerUpcomingLeave> upcomingLeaves;

  const ManagerDashboardData({
    this.overview = const ManagerTeamOverview(),
    this.quickActions = const [],
    this.pendingApprovals = const [],
    this.todaysBirthdays = const [],
    this.upcomingBirthdays = const [],
    this.recentActivity = const [],
    this.teamAttendance = const [],
    this.upcomingLeaves = const [],
  });

  factory ManagerDashboardData.fromJson(Map<String, dynamic> j) => ManagerDashboardData(
        overview: ManagerTeamOverview.fromJson(
            j['team_overview'] is Map ? (j['team_overview'] as Map).cast<String, dynamic>() : const {}),
        quickActions: _rows(j['quick_actions']).map(ManagerQuickAction.fromJson).toList(),
        pendingApprovals: _rows(j['pending_approvals']).map(ManagerPendingApproval.fromJson).toList(),
        todaysBirthdays: _rows(j['todays_birthdays']).map(DashboardBirthdayEmployee.fromJson).toList(),
        upcomingBirthdays: _rows(j['upcoming_birthdays']).map(DashboardBirthdayEmployee.fromJson).toList(),
        recentActivity: _rows(j['recent_team_activity']).map(ManagerTeamActivity.fromJson).toList(),
        teamAttendance: _rows(j['team_attendance']).map(ManagerTeamAttendance.fromJson).toList(),
        upcomingLeaves: _rows(j['upcoming_leaves']).map(ManagerUpcomingLeave.fromJson).toList(),
      );
}
