// Shapes shared across two or more dashboard-app endpoints (system-admin,
// HR, and employee views all reuse these same backend serializations).

/// Today's attendance snapshot, shared by `EmployeeKPIView` and `HRKPIView`
/// (`today_attendance` — HR's is the requesting HR user's own attendance).
class TodayAttendanceSnapshot {
  final String status;
  final String? firstPunchIn;
  final String? lastPunchOut;
  final int totalWorkingMinutes;

  const TodayAttendanceSnapshot({
    required this.status,
    required this.firstPunchIn,
    required this.lastPunchOut,
    required this.totalWorkingMinutes,
  });

  factory TodayAttendanceSnapshot.fromJson(Map<String, dynamic> json) {
    return TodayAttendanceSnapshot(
      status: json['status'] as String? ?? '',
      firstPunchIn: json['first_punch_in'] as String?,
      lastPunchOut: json['last_punch_out'] as String?,
      totalWorkingMinutes: (json['total_working_minutes'] as num? ?? 0).toInt(),
    );
  }
}

/// `SystemAdminAnnouncementView` / `HRDashboard`'s AnnouncementCard / shared
/// `SharedAnnouncementView` all return this same shape — `data` is null when
/// no announcement exists yet.
class DashboardAnnouncement {
  final String id;
  final String title;
  final String body;
  final String category;
  final String visibility;
  final bool isPinned;
  final String? postedBy;
  final String createdAt;

  const DashboardAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.visibility,
    required this.isPinned,
    required this.postedBy,
    required this.createdAt,
  });

  factory DashboardAnnouncement.fromJson(Map<String, dynamic> json) {
    return DashboardAnnouncement(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      category: json['category'] as String? ?? '',
      visibility: json['visibility'] as String? ?? '',
      isPinned: json['is_pinned'] as bool? ?? false,
      postedBy: json['posted_by'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

/// Shared birthday shape returned by the dashboard-app's system-admin and HR
/// birthday endpoints (`/dashboard/{system-admin,hr}/birthdays/{today,upcoming}/`)
/// — distinct from `apps/hrms`'s `/birthdays/` shape (`name` not `full_name`,
/// no `branch`/`email`, has `designation`/`wish_sent`) already consumed
/// elsewhere in this app via `BirthdayModel`. Do not conflate the two.
class DashboardBirthdayEmployee {
  final String employeeId;
  final String fullName;
  final String email;
  final String department;
  final String branch;
  final String dateOfBirth;
  final int daysUntil;

  const DashboardBirthdayEmployee({
    required this.employeeId,
    required this.fullName,
    required this.email,
    required this.department,
    required this.branch,
    required this.dateOfBirth,
    required this.daysUntil,
  });

  factory DashboardBirthdayEmployee.fromJson(Map<String, dynamic> json) {
    return DashboardBirthdayEmployee(
      employeeId: json['employee_id']?.toString() ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      department: json['department'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      dateOfBirth: json['date_of_birth'] as String? ?? '',
      daysUntil: (json['days_until'] as num? ?? 0).toInt(),
    );
  }
}

/// Department headcount bar — shared by the admin and HR dashboards (same
/// response shape from both `system-admin/department-headcount/` and the
/// generic `department-headcount/` endpoint).
class DeptHeadcount {
  final String department;
  final int count;

  const DeptHeadcount({required this.department, required this.count});

  factory DeptHeadcount.fromJson(Map<String, dynamic> json) {
    return DeptHeadcount(
      department: json['department'] as String? ?? '',
      count: (json['count'] as num? ?? 0).toInt(),
    );
  }
}
