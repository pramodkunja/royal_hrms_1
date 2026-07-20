import 'dashboard_common_models.dart';

/// `GET /dashboard/employee/kpis/` — `EmployeeKPIView`.
class EmployeeKpis {
  final int daysPresent;
  final int workingDays;
  final int absentDays;
  final int pendingActionItems;
  final int pendingExpenseClaims;
  final int pendingDocuments;
  final bool clockedIn;
  final TodayAttendanceSnapshot? todayAttendance;

  const EmployeeKpis({
    required this.daysPresent,
    required this.workingDays,
    required this.absentDays,
    required this.pendingActionItems,
    required this.pendingExpenseClaims,
    required this.pendingDocuments,
    required this.clockedIn,
    required this.todayAttendance,
  });

  factory EmployeeKpis.fromJson(Map<String, dynamic> json) {
    final today = json['today_attendance'];
    return EmployeeKpis(
      daysPresent: (json['days_present'] as num? ?? 0).toInt(),
      workingDays: (json['working_days'] as num? ?? 0).toInt(),
      absentDays: (json['absent_days'] as num? ?? 0).toInt(),
      pendingActionItems: (json['pending_action_items'] as num? ?? 0).toInt(),
      pendingExpenseClaims:
          (json['pending_expense_claims'] as num? ?? 0).toInt(),
      pendingDocuments: (json['pending_documents'] as num? ?? 0).toInt(),
      clockedIn: json['clocked_in'] as bool? ?? false,
      todayAttendance: today is Map<String, dynamic>
          ? TodayAttendanceSnapshot.fromJson(today)
          : null,
    );
  }
}

/// `GET /dashboard/employee/leave-balances/?year=` — `EmployeeLeaveBalanceView`.
class EmployeeLeaveBalanceSummary {
  final int year;
  final List<EmployeeLeaveBalance> balances;
  final double lopDays;

  const EmployeeLeaveBalanceSummary({
    required this.year,
    required this.balances,
    required this.lopDays,
  });

  factory EmployeeLeaveBalanceSummary.fromJson(Map<String, dynamic> json) {
    final list = json['balances'] as List<dynamic>? ?? [];
    return EmployeeLeaveBalanceSummary(
      year: (json['year'] as num? ?? 0).toInt(),
      balances: list
          .whereType<Map<String, dynamic>>()
          .map(EmployeeLeaveBalance.fromJson)
          .toList(),
      lopDays: (json['lop_days'] as num? ?? 0).toDouble(),
    );
  }
}

class EmployeeLeaveBalance {
  final String leaveType;
  final double totalDays;
  final double usedDays;
  final double remaining;
  final double carriedForward;

  const EmployeeLeaveBalance({
    required this.leaveType,
    required this.totalDays,
    required this.usedDays,
    required this.remaining,
    required this.carriedForward,
  });

  factory EmployeeLeaveBalance.fromJson(Map<String, dynamic> json) {
    return EmployeeLeaveBalance(
      leaveType: json['leave_type'] as String? ?? '',
      totalDays: (json['total_days'] as num? ?? 0).toDouble(),
      usedDays: (json['used_days'] as num? ?? 0).toDouble(),
      remaining: (json['remaining'] as num? ?? 0).toDouble(),
      carriedForward: (json['carried_forward'] as num? ?? 0).toDouble(),
    );
  }
}

/// `GET /dashboard/employee/attendance-summary/?month=&year=` —
/// `EmployeeAttendanceSummaryView`. Distinct shape from the HR/admin
/// "today's snapshot" `HrAttendanceSummary` of the same conceptual name —
/// this one is a monthly rollup for a single employee.
class EmployeeAttendanceSummary {
  final int year;
  final int month;
  final int presentDays;
  final int absentDays;
  final int lateMarks;
  final int lopPending;
  final int halfDays;
  final int leaveDays;
  final int workingDays;
  final double avgHoursPerDay;
  final double attendancePercentage;
  final String otHours;

  const EmployeeAttendanceSummary({
    required this.year,
    required this.month,
    required this.presentDays,
    required this.absentDays,
    required this.lateMarks,
    required this.lopPending,
    required this.halfDays,
    required this.leaveDays,
    required this.workingDays,
    required this.avgHoursPerDay,
    required this.attendancePercentage,
    required this.otHours,
  });

  factory EmployeeAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return EmployeeAttendanceSummary(
      year: (json['year'] as num? ?? 0).toInt(),
      month: (json['month'] as num? ?? 0).toInt(),
      presentDays: (json['present_days'] as num? ?? 0).toInt(),
      absentDays: (json['absent_days'] as num? ?? 0).toInt(),
      lateMarks: (json['late_marks'] as num? ?? 0).toInt(),
      lopPending: (json['lop_pending'] as num? ?? 0).toInt(),
      halfDays: (json['half_days'] as num? ?? 0).toInt(),
      leaveDays: (json['leave_days'] as num? ?? 0).toInt(),
      workingDays: (json['working_days'] as num? ?? 0).toInt(),
      avgHoursPerDay: (json['avg_hours_per_day'] as num? ?? 0).toDouble(),
      attendancePercentage:
          (json['attendance_percentage'] as num? ?? 0).toDouble(),
      otHours: json['ot_hours']?.toString() ?? '0h',
    );
  }
}

/// `GET /dashboard/employee/attendance-status/` — `EmployeeAttendanceStatusView`.
class EmployeeAttendanceStatus {
  final bool clockedIn;
  final String? clockInTime;
  final String? clockOutTime;
  final String workingHours;
  final bool canClockIn;
  final bool canClockOut;

  const EmployeeAttendanceStatus({
    required this.clockedIn,
    required this.clockInTime,
    required this.clockOutTime,
    required this.workingHours,
    required this.canClockIn,
    required this.canClockOut,
  });

  factory EmployeeAttendanceStatus.fromJson(Map<String, dynamic> json) {
    return EmployeeAttendanceStatus(
      clockedIn: json['clocked_in'] as bool? ?? false,
      clockInTime: json['clock_in_time'] as String?,
      clockOutTime: json['clock_out_time'] as String?,
      workingHours: json['working_hours'] as String? ?? '00:00',
      canClockIn: json['can_clock_in'] as bool? ?? true,
      canClockOut: json['can_clock_out'] as bool? ?? false,
    );
  }
}

/// `GET /dashboard/employee/action-items/` — `EmployeeActionItemsView`.
/// `actionType` values seen from backend: profile_incomplete,
/// missing_document, attendance_correction, and dynamically leave_{status}
/// (e.g. leave_approved, leave_rejected).
class ActionItem {
  final String actionType;
  final String title;
  final String description;
  final String status;
  final String navigationUrl;

  const ActionItem({
    required this.actionType,
    required this.title,
    required this.description,
    required this.status,
    required this.navigationUrl,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      actionType: json['action_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? '',
      navigationUrl: json['navigation_url'] as String? ?? '',
    );
  }
}

class ActionItemsResponse {
  final int total;
  final List<ActionItem> actionItems;

  const ActionItemsResponse({required this.total, required this.actionItems});

  factory ActionItemsResponse.fromJson(Map<String, dynamic> json) {
    final list = json['action_items'] as List<dynamic>? ?? [];
    return ActionItemsResponse(
      total: (json['total'] as num? ?? 0).toInt(),
      actionItems:
          list.whereType<Map<String, dynamic>>().map(ActionItem.fromJson).toList(),
    );
  }
}

/// `GET /dashboard/employee/recent-requests/` — `EmployeeRecentRequestsView`.
/// `requestType` is one of "leave" | "expense" | "attendance_correction";
/// `details` holds type-specific keys (leave: start_date/end_date/days;
/// expense: amount/category; attendance_correction: date/punch_type) — kept
/// as a raw map since the shape genuinely varies by requestType.
class RecentRequest {
  final String requestType;
  final String title;
  final String appliedDate;
  final String status;
  final String remarks;
  final Map<String, dynamic> details;

  const RecentRequest({
    required this.requestType,
    required this.title,
    required this.appliedDate,
    required this.status,
    required this.remarks,
    required this.details,
  });

  factory RecentRequest.fromJson(Map<String, dynamic> json) {
    final details = json['details'];
    return RecentRequest(
      requestType: json['request_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      appliedDate: json['applied_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      details: details is Map<String, dynamic> ? details : const {},
    );
  }
}

class RecentRequestsResponse {
  final int total;
  final List<RecentRequest> requests;

  const RecentRequestsResponse({required this.total, required this.requests});

  factory RecentRequestsResponse.fromJson(Map<String, dynamic> json) {
    final list = json['requests'] as List<dynamic>? ?? [];
    return RecentRequestsResponse(
      total: (json['total'] as num? ?? 0).toInt(),
      requests: list
          .whereType<Map<String, dynamic>>()
          .map(RecentRequest.fromJson)
          .toList(),
    );
  }
}
