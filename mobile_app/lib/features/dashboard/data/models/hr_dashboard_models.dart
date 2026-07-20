import 'dashboard_common_models.dart';

/// `GET /dashboard/hr/kpis/` — `HRKPIView`. `employeesOnProbation` is always
/// 0 — hardcoded server-side, not implemented yet.
class HrKpis {
  final int totalWorkforce;
  final int pendingActions;
  final int activeInterviews;
  final int employeesOnProbation;
  final bool clockedIn;
  final TodayAttendanceSnapshot? todayAttendance;
  final int attendanceCorrectionPending;

  const HrKpis({
    required this.totalWorkforce,
    required this.pendingActions,
    required this.activeInterviews,
    required this.employeesOnProbation,
    required this.clockedIn,
    required this.todayAttendance,
    required this.attendanceCorrectionPending,
  });

  factory HrKpis.fromJson(Map<String, dynamic> json) {
    final today = json['today_attendance'];
    return HrKpis(
      totalWorkforce: (json['total_workforce'] as num? ?? 0).toInt(),
      pendingActions: (json['pending_actions'] as num? ?? 0).toInt(),
      activeInterviews: (json['active_interviews'] as num? ?? 0).toInt(),
      employeesOnProbation:
          (json['employees_on_probation'] as num? ?? 0).toInt(),
      clockedIn: json['clocked_in'] as bool? ?? false,
      todayAttendance: today is Map<String, dynamic>
          ? TodayAttendanceSnapshot.fromJson(today)
          : null,
      attendanceCorrectionPending:
          (json['attendance_correction_pending'] as num? ?? 0).toInt(),
    );
  }
}

/// `GET /dashboard/hr/attendance-summary/` — `HRAttendanceSummaryView`.
/// Today's org-wide snapshot counts — NOT the same shape as
/// `EmployeeAttendanceSummary` (a single employee's monthly rollup), despite
/// both being called "attendance summary".
class HrAttendanceSummary {
  final int present;
  final int absent;
  final int late;
  final int leave;
  final int weeklyOff;
  final int holiday;

  const HrAttendanceSummary({
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
    required this.weeklyOff,
    required this.holiday,
  });

  factory HrAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return HrAttendanceSummary(
      present: (json['present'] as num? ?? 0).toInt(),
      absent: (json['absent'] as num? ?? 0).toInt(),
      late: (json['late'] as num? ?? 0).toInt(),
      leave: (json['leave'] as num? ?? 0).toInt(),
      weeklyOff: (json['weekly_off'] as num? ?? 0).toInt(),
      holiday: (json['holiday'] as num? ?? 0).toInt(),
    );
  }
}

/// `GET /dashboard/hr/action-queue/` — `HRActionQueueView`.
/// `separationRequests` is always 0 (model not implemented).
class HrActionQueue {
  final int totalPending;
  final int candidateReviews;
  final int leaveApprovals;
  final int attendanceCorrections;
  final int expenseClaims;
  final int onboardingReviews;
  final int separationRequests;

  const HrActionQueue({
    required this.totalPending,
    required this.candidateReviews,
    required this.leaveApprovals,
    required this.attendanceCorrections,
    required this.expenseClaims,
    required this.onboardingReviews,
    required this.separationRequests,
  });

  factory HrActionQueue.fromJson(Map<String, dynamic> json) {
    return HrActionQueue(
      totalPending: (json['total_pending'] as num? ?? 0).toInt(),
      candidateReviews: (json['candidate_reviews'] as num? ?? 0).toInt(),
      leaveApprovals: (json['leave_approvals'] as num? ?? 0).toInt(),
      attendanceCorrections:
          (json['attendance_corrections'] as num? ?? 0).toInt(),
      expenseClaims: (json['expense_claims'] as num? ?? 0).toInt(),
      onboardingReviews: (json['onboarding_reviews'] as num? ?? 0).toInt(),
      separationRequests: (json['separation_requests'] as num? ?? 0).toInt(),
    );
  }
}

/// `GET /dashboard/hr/recruitment-funnel/` — `HRRecruitmentFunnelView`.
class HrRecruitmentFunnel {
  final int interviewsScheduled;
  final int interviewed;
  final int selected;
  final int detailsSubmitted;
  final int onboarded;

  const HrRecruitmentFunnel({
    required this.interviewsScheduled,
    required this.interviewed,
    required this.selected,
    required this.detailsSubmitted,
    required this.onboarded,
  });

  factory HrRecruitmentFunnel.fromJson(Map<String, dynamic> json) {
    return HrRecruitmentFunnel(
      interviewsScheduled: (json['interviews_scheduled'] as num? ?? 0).toInt(),
      interviewed: (json['interviewed'] as num? ?? 0).toInt(),
      selected: (json['selected'] as num? ?? 0).toInt(),
      detailsSubmitted: (json['details_submitted'] as num? ?? 0).toInt(),
      onboarded: (json['onboarded'] as num? ?? 0).toInt(),
    );
  }
}

/// One row of `HREmployeeLifecycleView`'s groups. Unlike the system-admin
/// variant, HR's `new_joiners` include `designation` (no `branch`), and
/// `work_anniversaries` use `years_completed`/`anniversary_date` instead of
/// `years`/`date_of_joining` — both sets of fields are nullable here since
/// which ones are populated depends on which group this row came from.
class HrLifecycleEmployee {
  final String employeeId;
  final String fullName;
  final String department;
  final String? designation;
  final String? dateOfJoining;
  final int? yearsCompleted;
  final String? anniversaryDate;

  const HrLifecycleEmployee({
    required this.employeeId,
    required this.fullName,
    required this.department,
    required this.designation,
    required this.dateOfJoining,
    required this.yearsCompleted,
    required this.anniversaryDate,
  });

  factory HrLifecycleEmployee.fromJson(Map<String, dynamic> json) {
    return HrLifecycleEmployee(
      employeeId: json['employee_id']?.toString() ?? '',
      fullName: json['full_name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      designation: json['designation'] as String?,
      dateOfJoining: json['date_of_joining'] as String?,
      yearsCompleted: (json['years_completed'] as num?)?.toInt(),
      anniversaryDate: json['anniversary_date'] as String?,
    );
  }
}

class HrLifecycleGroup {
  final int count;
  final List<HrLifecycleEmployee> employees;

  const HrLifecycleGroup({required this.count, required this.employees});

  factory HrLifecycleGroup.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const HrLifecycleGroup(count: 0, employees: []);
    }
    final list = json['employees'] as List<dynamic>? ?? [];
    return HrLifecycleGroup(
      count: (json['count'] as num? ?? 0).toInt(),
      employees: list
          .whereType<Map<String, dynamic>>()
          .map(HrLifecycleEmployee.fromJson)
          .toList(),
    );
  }
}

class HrEmployeeLifecycle {
  final HrLifecycleGroup newJoiners;
  final HrLifecycleGroup noticePeriod;
  final HrLifecycleGroup workAnniversaries;

  const HrEmployeeLifecycle({
    required this.newJoiners,
    required this.noticePeriod,
    required this.workAnniversaries,
  });

  factory HrEmployeeLifecycle.fromJson(Map<String, dynamic> json) {
    return HrEmployeeLifecycle(
      newJoiners: HrLifecycleGroup.fromJson(json['new_joiners']),
      noticePeriod: HrLifecycleGroup.fromJson(json['notice_period']),
      workAnniversaries: HrLifecycleGroup.fromJson(json['work_anniversaries']),
    );
  }
}
