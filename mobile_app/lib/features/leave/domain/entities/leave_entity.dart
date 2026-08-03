class LeaveTypeEntity {
  final int id;
  final String name;
  final String code;
  final int maxDays;
  final bool isPaid;
  final bool carryForward;
  final bool docRequired;
  final String genderEligibility;
  final bool isActive;
  final String description;
  final String policy;

  // ── Type & Credit (LeavePolicy) ──
  final int maxCarryForwardDays; // max_carry_forward_days

  // ── Leave Application Rules ──
  final double minimumLeaveDuration; // minimum_leave_duration
  final int maximumLeaveDuration; // maximum_leave_duration, 0 = unlimited
  final int maximumConsecutiveDays; // maximum_consecutive_days, 0 = unlimited
  final int minimumNoticePeriod; // minimum_notice_period (days)
  final bool allowHalfDay; // allow_half_day
  final bool allowBackdatedLeave; // allow_backdated_leave
  final int maximumBackdatedDays; // maximum_backdated_days, 0 = unlimited
  final bool allowFutureLeave; // allow_future_leave
  final int maximumFutureDays; // maximum_future_days, 0 = unlimited

  // ── Holiday & Week-off Rules ──
  final bool sandwichLeaveEnabled; // sandwich_leave_enabled
  final bool countHolidaysAsLeave; // count_holidays_as_leave
  final bool countWeekoffsAsLeave; // count_weekoffs_as_leave

  // ── Eligibility Rules ──
  final List<String> applicableBranches; // applicable_branches
  final List<String> applicableDepartments; // applicable_departments
  final List<String> applicableDesignations; // applicable_designations
  final List<String> applicableEmploymentTypes; // applicable_employment_types
  final String applicableGender; // applicable_gender: all|male|female
  final int minimumServicePeriod; // minimum_service_period (months)

  // ── Documentation Rules ──
  final bool attachmentRequired; // attachment_required
  final bool medicalCertificateRequired; // medical_certificate_required
  final int medicalCertificateAfterDays; // medical_certificate_after_days

  // ── Leave Restrictions ──
  final bool allowNegativeBalance; // allow_negative_balance
  final bool convertToLop; // convert_to_lop
  final bool allowLeaveCancellation; // allow_leave_cancellation
  final int
      cancellationAllowedUntil; // cancellation_allowed_until (days before start)

  // ── Additional Rules ──
  final bool allowProbationLeave; // allow_probation_leave
  final bool allowNoticePeriodLeave; // allow_notice_period_leave
  final bool allowLeaveExtension; // allow_leave_extension
  final bool allowLeaveCombination; // allow_leave_combination

  const LeaveTypeEntity({
    required this.id,
    required this.name,
    required this.code,
    required this.maxDays,
    required this.isPaid,
    required this.carryForward,
    required this.docRequired,
    required this.genderEligibility,
    required this.isActive,
    required this.description,
    required this.policy,
    this.maxCarryForwardDays = 0,
    this.minimumLeaveDuration = 0.5,
    this.maximumLeaveDuration = 0,
    this.maximumConsecutiveDays = 0,
    this.minimumNoticePeriod = 0,
    this.allowHalfDay = true,
    this.allowBackdatedLeave = false,
    this.maximumBackdatedDays = 0,
    this.allowFutureLeave = true,
    this.maximumFutureDays = 0,
    this.sandwichLeaveEnabled = false,
    this.countHolidaysAsLeave = false,
    this.countWeekoffsAsLeave = false,
    this.applicableBranches = const [],
    this.applicableDepartments = const [],
    this.applicableDesignations = const [],
    this.applicableEmploymentTypes = const [],
    this.applicableGender = 'all',
    this.minimumServicePeriod = 0,
    this.attachmentRequired = false,
    this.medicalCertificateRequired = false,
    this.medicalCertificateAfterDays = 3,
    this.allowNegativeBalance = false,
    this.convertToLop = false,
    this.allowLeaveCancellation = true,
    this.cancellationAllowedUntil = 0,
    this.allowProbationLeave = false,
    this.allowNoticePeriodLeave = false,
    this.allowLeaveExtension = false,
    this.allowLeaveCombination = false,
  });
}

class LeaveBalanceEntity {
  final String typeCode; // 'CL', 'EL', etc. — used as the key
  final String typeName;
  final double used;
  final double total;

  const LeaveBalanceEntity({
    required this.typeCode,
    required this.typeName,
    required this.used,
    required this.total,
  });

  double get available => total - used;
  double get pct => total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
}

class LeaveRequestEntity {
  final String id; // UUID string
  final String employee;
  final String employeeCode; // employee_code — e.g. "RSS00138"
  final String branch;
  final String department;
  final String leaveType;
  final String leaveTypeCode;
  final String durationDisplay;
  final String from; // ISO date string 'YYYY-MM-DD'
  final String to; // ISO date string 'YYYY-MM-DD'
  final int days;
  final String status;
  final String reason;
  final String appliedOn;
  final String? rejectReason;
  final String l1ApproverName;
  final String l2ApproverName;
  final String? documentUrl;
  final double
      lopDays; // lop_days — partial LOP conversion, separate from the 'lwp' leave type
  final String? l1Status; // l1_status: pending|approved|rejected
  final String? l2Status; // l2_status: pending|approved|rejected
  final String? l1ActionedAt; // l1_actioned_at (ISO datetime)
  final String? l2ActionedAt; // l2_actioned_at (ISO datetime)
  final String?
      l1Remarks; // l1_remarks — raw manager-level remarks (approval or rejection note)
  final String? l2Remarks; // l2_remarks — raw HR-level remarks
  final String? handoverTo; // handover_to
  final String? contactDuringLeave; // contact_during_leave
  final String? handoverNotes; // handover_notes
  final bool
      canApprove; // can_approve — backend-computed: true only if the viewing user can approve/reject at the current stage
  final bool
      canCancel; // can_cancel — backend-computed: true only if the viewing user owns this request AND it's still cancellable
  final String
      approvedBy; // approved_by — name of whoever gave the FINAL approval/rejection
  final String? approvedAt; // approved_at — timestamp of that final action

  const LeaveRequestEntity({
    required this.id,
    required this.employee,
    this.employeeCode = '',
    required this.branch,
    required this.department,
    required this.leaveType,
    required this.leaveTypeCode,
    this.durationDisplay = '',
    required this.from,
    required this.to,
    required this.days,
    required this.status,
    required this.reason,
    required this.appliedOn,
    this.rejectReason,
    this.l1ApproverName = '',
    this.l2ApproverName = '',
    this.documentUrl,
    this.lopDays = 0.0,
    this.l1Status,
    this.l2Status,
    this.l1ActionedAt,
    this.l2ActionedAt,
    this.l1Remarks,
    this.l2Remarks,
    this.handoverTo,
    this.contactDuringLeave,
    this.handoverNotes,
    this.canApprove = false,
    this.canCancel = false,
    this.approvedBy = '',
    this.approvedAt,
  });

  bool get isPending => status == 'pending' || status == 'l2_pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
  bool get hasLopDays => lopDays > 0;
}

// ── Leave type color — single source of truth, matches web frontend theme ─────

// The backend's `leave_type` field is a lowercase full word ('casual', 'earned',
// 'sick', 'lwp', 'maternity', 'paternity') — NOT a 'CL'/'EL'/'SL' abbreviation.
// Keys here must match those raw codes exactly (see
// web_frontend_backend/Royal-HRMS/frontend/app/dashboard/leave/_data.ts LEAVE_TYPE_CONFIG).
// ignore: avoid_classes_with_only_static_members
class LeaveTypeColors {
  LeaveTypeColors._();

  static const Map<String, int> _hex = {
    'casual': 0xFF1E4E8C, // primary
    'earned': 0xFF1B8A6B, // success
    'sick': 0xFF0E7C86, // info/teal
    'lwp': 0xFFB5651D, // warning/amber
    'maternity': 0xFFAD95CF, // purple
    'paternity': 0xFF5B86C9, // primaryLight
  };

  static const Map<String, String> _shortLabel = {
    'casual': 'CL',
    'earned': 'EL',
    'sick': 'SL',
    'lwp': 'LWP',
    'maternity': 'ML',
    'paternity': 'PL',
  };

  static const Map<String, String> _label = {
    'casual': 'Casual Leave',
    'earned': 'Earned Leave',
    'sick': 'Sick Leave',
    'lwp': 'Leave Without Pay',
    'maternity': 'Maternity Leave',
    'paternity': 'Paternity Leave',
  };

  // Default policy note shown when the backend's LeavePolicy.policy_note is
  // blank, so the disclaimer box always has real text instead of being empty.
  static const Map<String, String> _defaultPolicyNote = {
    'casual':
        'Casual leave is for personal errands and short breaks. Apply at least 1 day in advance where possible.',
    'earned':
        'Earned leave accrues monthly and may be carried forward as per company policy.',
    'sick':
        'A medical certificate may be required for sick leave exceeding 2 consecutive days.',
    'lwp':
        'Unpaid leave, used once all other paid leave balances are exhausted.',
    'maternity': 'Granted as per the Maternity Benefit Act provisions.',
    'paternity':
        'Applicable for new fathers, to be availed within 3 months of childbirth.',
  };

  // Matches web's LEAVE_TYPES_LIST — a fixed, always-shown set of 6 leave
  // types. The web frontend never derives this list from the backend's
  // policy API; it only uses that API for supplementary balance/policy-note
  // data, defaulting to 0/blank when a type has no policy record yet.
  static const List<String> allCodes = [
    'casual',
    'earned',
    'sick',
    'lwp',
    'maternity',
    'paternity',
  ];

  static int colorValueForCode(String code) =>
      _hex[code.toLowerCase()] ?? _hex['casual']!;

  /// Short 2-3 letter badge label for a raw backend leave type code.
  static String shortLabelForCode(String code) =>
      _shortLabel[code.toLowerCase()] ?? code.toUpperCase();

  /// Full display label for a raw backend leave type code (fallback when the
  /// backend hasn't returned a `leave_type_display`/policy record for it).
  static String labelForCode(String code) => _label[code.toLowerCase()] ?? code;

  /// Policy note to show for a code, falling back to a sensible default when
  /// the backend hasn't set one — the disclaimer box should never be blank.
  static String policyNoteForCode(String code, String? backendNote) {
    if (backendNote != null && backendNote.isNotEmpty) return backendNote;
    return _defaultPolicyNote[code.toLowerCase()] ?? '';
  }

  static bool isLwp(String code) => code.toLowerCase() == 'lwp';

  /// Matches backend's rule (sick/maternity/paternity require a supporting document).
  static bool docRequiredForCode(String code) =>
      const {'sick', 'maternity', 'paternity'}.contains(code.toLowerCase());
}

// Page envelope for GET /leave/requests/?scope=team — matches the backend's
// `{count, page, page_size, total_pages, results}` pagination shape (see
// apps/hrms/views/leave.py LeaveRequestListCreateView.get / core/pagination.py).
// Kept local to the leave feature rather than reusing attendance's generic
// PaginatedListEntity<T>, matching this codebase's per-feature pagination
// type convention (see settings/data/models/audit_model.dart AuditLogPage).
class LeaveRequestPageEntity {
  final List<LeaveRequestEntity> results;
  final int count;
  final int page;
  final int pageSize;
  final int totalPages;

  const LeaveRequestPageEntity({
    required this.results,
    required this.count,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory LeaveRequestPageEntity.empty() => const LeaveRequestPageEntity(
        results: [],
        count: 0,
        page: 1,
        pageSize: 20,
        totalPages: 1,
      );
}

// Accumulating "load more" state for the approver's team lists (Dashboard's
// Pending Approvals, Approvals tab's Pending/History) — unlike
// [LeaveRequestPageEntity] (one API page), this keeps every item loaded so
// far plus whether a background loadMore() fetch is in flight, so the list
// grows in place instead of being replaced page-by-page.
class LeaveLoadMoreState {
  final List<LeaveRequestEntity> items;
  final int page;
  final int totalPages;
  final int count;
  final bool loadingMore;

  const LeaveLoadMoreState({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.count,
    this.loadingMore = false,
  });

  bool get hasMore => page < totalPages;

  LeaveLoadMoreState copyWith({
    List<LeaveRequestEntity>? items,
    int? page,
    int? totalPages,
    int? count,
    bool? loadingMore,
  }) =>
      LeaveLoadMoreState(
        items: items ?? this.items,
        page: page ?? this.page,
        totalPages: totalPages ?? this.totalPages,
        count: count ?? this.count,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class LeaveCalendarEventEntity {
  final String id;
  final String employeeName;
  final String employeeCode;
  final String leaveTypeCode;
  final String leaveTypeName;
  final String startDate; // ISO 'YYYY-MM-DD'
  final String endDate; // ISO 'YYYY-MM-DD'
  final double totalDays;

  const LeaveCalendarEventEntity({
    required this.id,
    required this.employeeName,
    required this.employeeCode,
    required this.leaveTypeCode,
    required this.leaveTypeName,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
  });
}

class LeaveStatsEntity {
  final int total;
  final int pending;
  final int approved;
  final int rejected;
  final int cancelled;
  final int year;
  final List<BalanceSummaryEntity> balances;
  final double lopDays; // lop_days — total Loss-of-Pay days, approved this year
  final int
      lopRequests; // lop_requests — count of approved requests with any LOP days

  const LeaveStatsEntity({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
    this.cancelled = 0,
    this.year = 0,
    this.balances = const [],
    this.lopDays = 0.0,
    this.lopRequests = 0,
  });
}

class BalanceSummaryEntity {
  final String leaveTypeCode;
  final String leaveTypeDisplay;
  final double totalDays;
  final double usedDays;
  final double available;

  const BalanceSummaryEntity({
    required this.leaveTypeCode,
    required this.leaveTypeDisplay,
    required this.totalDays,
    required this.usedDays,
    required this.available,
  });

  double get pct =>
      totalDays > 0 ? (usedDays / totalDays).clamp(0.0, 1.0) : 0.0;
}

// ── Leave Preview (GET /leave/requests/?action=preview) ─────────────────────
//
// Authoritative server-side day-count/LOP breakdown for a candidate leave
// request — mirrors exactly what LeaveRequestListCreateView.post() will do
// on submit (sandwich/holiday/week-off exclusion, LOP split, balance check),
// so the Apply Leave screen doesn't have to re-derive this logic (and risk
// drifting from it — the client-side estimate doesn't know about holidays).

class NamedDateEntity {
  final String date; // "15 Aug" (holiday) or "2026-08-09" (week-off)
  final String label; // holiday name, or weekday name for week-offs
  const NamedDateEntity({required this.date, required this.label});
}

class LeavePreviewEntity {
  final String leaveType;
  final int calendarDays;
  final List<NamedDateEntity> companyHolidays;
  final int companyHolidayCount;
  final List<NamedDateEntity> weekOffs;
  final int weekOffCount;
  final bool sandwichLeaveEnabled;
  final double actualLeaveDays;
  final double availableBalance;
  final double earnedLeaveUsed;
  final double lopDays;
  final bool lopEnabled;
  final bool sufficientBalance;
  final String warning;

  const LeavePreviewEntity({
    required this.leaveType,
    required this.calendarDays,
    required this.companyHolidays,
    required this.companyHolidayCount,
    required this.weekOffs,
    required this.weekOffCount,
    required this.sandwichLeaveEnabled,
    required this.actualLeaveDays,
    required this.availableBalance,
    required this.earnedLeaveUsed,
    required this.lopDays,
    required this.lopEnabled,
    required this.sufficientBalance,
    required this.warning,
  });
}
