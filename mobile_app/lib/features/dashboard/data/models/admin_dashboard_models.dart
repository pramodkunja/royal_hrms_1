/// `GET /dashboard/system-admin/kpis/` — `SystemAdminKPIView`.
class SystemAdminKpis {
  final int totalEmployees;
  final int pendingApprovals;
  final int employeesOnboarding;
  final int activeBranches;
  final bool apiStatus;
  final bool databaseStatus;
  final bool mailStatus;
  final bool storageStatus;

  const SystemAdminKpis({
    required this.totalEmployees,
    required this.pendingApprovals,
    required this.employeesOnboarding,
    required this.activeBranches,
    required this.apiStatus,
    required this.databaseStatus,
    required this.mailStatus,
    required this.storageStatus,
  });

  factory SystemAdminKpis.fromJson(Map<String, dynamic> json) {
    return SystemAdminKpis(
      totalEmployees: (json['total_employees'] as num? ?? 0).toInt(),
      pendingApprovals: (json['pending_approvals'] as num? ?? 0).toInt(),
      employeesOnboarding:
          (json['employees_onboarding'] as num? ?? 0).toInt(),
      activeBranches: (json['active_branches'] as num? ?? 0).toInt(),
      apiStatus: json['api_status'] as bool? ?? false,
      databaseStatus: json['database_status'] as bool? ?? false,
      mailStatus: json['mail_status'] as bool? ?? false,
      storageStatus: json['storage_status'] as bool? ?? false,
    );
  }
}

/// `GET /dashboard/system-admin/pending-approvals/` —
/// `SystemAdminPendingApprovalsView`. `separationRequests` is always 0 —
/// the backend model for it doesn't exist yet.
class PendingApprovals {
  final int leaveRequests;
  final int expenseClaims;
  final int onboardingReviews;
  final int separationRequests;
  final int totalPending;

  const PendingApprovals({
    required this.leaveRequests,
    required this.expenseClaims,
    required this.onboardingReviews,
    required this.separationRequests,
    required this.totalPending,
  });

  factory PendingApprovals.fromJson(Map<String, dynamic> json) {
    return PendingApprovals(
      leaveRequests: (json['leave_requests'] as num? ?? 0).toInt(),
      expenseClaims: (json['expense_claims'] as num? ?? 0).toInt(),
      onboardingReviews: (json['onboarding_reviews'] as num? ?? 0).toInt(),
      separationRequests: (json['separation_requests'] as num? ?? 0).toInt(),
      totalPending: (json['total_pending'] as num? ?? 0).toInt(),
    );
  }
}

/// One row of `SystemAdminEmployeeLifecycleView`'s `new_joiners` /
/// `work_anniversaries` groups. `years` is only present for anniversaries.
/// `noticePeriod` is always `{count: 0, employees: []}` — not implemented
/// server-side yet; don't expect real data there.
class AdminLifecycleEmployee {
  final String employeeId;
  final String fullName;
  final String department;
  final String branch;
  final String? dateOfJoining;
  final int? years;

  const AdminLifecycleEmployee({
    required this.employeeId,
    required this.fullName,
    required this.department,
    required this.branch,
    required this.dateOfJoining,
    required this.years,
  });

  factory AdminLifecycleEmployee.fromJson(Map<String, dynamic> json) {
    return AdminLifecycleEmployee(
      employeeId: json['employee_id']?.toString() ?? '',
      fullName: json['full_name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      dateOfJoining: json['date_of_joining'] as String?,
      years: (json['years'] as num?)?.toInt(),
    );
  }
}

class AdminLifecycleGroup {
  final int count;
  final List<AdminLifecycleEmployee> employees;

  const AdminLifecycleGroup({required this.count, required this.employees});

  factory AdminLifecycleGroup.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const AdminLifecycleGroup(count: 0, employees: []);
    }
    final list = json['employees'] as List<dynamic>? ?? [];
    return AdminLifecycleGroup(
      count: (json['count'] as num? ?? 0).toInt(),
      employees: list
          .whereType<Map<String, dynamic>>()
          .map(AdminLifecycleEmployee.fromJson)
          .toList(),
    );
  }
}

class AdminEmployeeLifecycle {
  final AdminLifecycleGroup newJoiners;
  final AdminLifecycleGroup noticePeriod;
  final AdminLifecycleGroup workAnniversaries;

  const AdminEmployeeLifecycle({
    required this.newJoiners,
    required this.noticePeriod,
    required this.workAnniversaries,
  });

  factory AdminEmployeeLifecycle.fromJson(Map<String, dynamic> json) {
    return AdminEmployeeLifecycle(
      newJoiners: AdminLifecycleGroup.fromJson(json['new_joiners']),
      noticePeriod: AdminLifecycleGroup.fromJson(json['notice_period']),
      workAnniversaries:
          AdminLifecycleGroup.fromJson(json['work_anniversaries']),
    );
  }
}

/// `GET /dashboard/system-admin/audit-logs/?module=&limit=&offset=` —
/// `SystemAdminAuditLogsView`. Backend field is `user` (the actor's full
/// name, nullable), NOT `actor`/`actor_name` — and `ip_address`, not `ip`.
class AuditLogEntry {
  final int id;
  final String? user;
  final String action;
  final String module;
  final String? objectId;
  final String? ipAddress;
  final String createdAt;

  const AuditLogEntry({
    required this.id,
    required this.user,
    required this.action,
    required this.module,
    required this.objectId,
    required this.ipAddress,
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: (json['id'] as num? ?? 0).toInt(),
      user: json['user'] as String?,
      action: json['action'] as String? ?? '',
      module: json['module'] as String? ?? '',
      objectId: json['object_id']?.toString(),
      ipAddress: json['ip_address'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class AuditLogsResponse {
  final int count;
  final int limit;
  final int offset;
  final List<AuditLogEntry> results;

  const AuditLogsResponse({
    required this.count,
    required this.limit,
    required this.offset,
    required this.results,
  });

  factory AuditLogsResponse.fromJson(Map<String, dynamic> json) {
    final list = json['results'] as List<dynamic>? ?? [];
    return AuditLogsResponse(
      count: (json['count'] as num? ?? 0).toInt(),
      limit: (json['limit'] as num? ?? 20).toInt(),
      offset: (json['offset'] as num? ?? 0).toInt(),
      results: list
          .whereType<Map<String, dynamic>>()
          .map(AuditLogEntry.fromJson)
          .toList(),
    );
  }
}
