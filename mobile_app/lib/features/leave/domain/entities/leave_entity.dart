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
  });
}

class LeaveBalanceEntity {
  final String typeCode;  // 'CL', 'EL', etc. — used as the key
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
  final String id;  // UUID string
  final String employee;
  final String branch;
  final String department;
  final String leaveType;
  final String leaveTypeCode;
  final String durationDisplay;
  final String from;   // ISO date string 'YYYY-MM-DD'
  final String to;     // ISO date string 'YYYY-MM-DD'
  final int days;
  final String status;
  final String reason;
  final String appliedOn;
  final String? rejectReason;
  final String l1ApproverName;
  final String l2ApproverName;
  final String? documentUrl;

  const LeaveRequestEntity({
    required this.id,
    required this.employee,
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
  });

  bool get isPending   => status == 'pending' || status == 'l2_pending';
  bool get isApproved  => status == 'approved';
  bool get isRejected  => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
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
    'casual':    0xFF1E4E8C, // primary
    'earned':    0xFF1B8A6B, // success
    'sick':      0xFF0E7C86, // info/teal
    'lwp':       0xFFB5651D, // warning/amber
    'maternity': 0xFFAD95CF, // purple
    'paternity': 0xFF5B86C9, // primaryLight
  };

  static const Map<String, String> _shortLabel = {
    'casual':    'CL',
    'earned':    'EL',
    'sick':      'SL',
    'lwp':       'LWP',
    'maternity': 'ML',
    'paternity': 'PL',
  };

  static const Map<String, String> _label = {
    'casual':    'Casual Leave',
    'earned':    'Earned Leave',
    'sick':      'Sick Leave',
    'lwp':       'Leave Without Pay',
    'maternity': 'Maternity Leave',
    'paternity': 'Paternity Leave',
  };

  // Default policy note shown when the backend's LeavePolicy.policy_note is
  // blank, so the disclaimer box always has real text instead of being empty.
  static const Map<String, String> _defaultPolicyNote = {
    'casual':    'Casual leave is for personal errands and short breaks. Apply at least 1 day in advance where possible.',
    'earned':    'Earned leave accrues monthly and may be carried forward as per company policy.',
    'sick':      'A medical certificate may be required for sick leave exceeding 2 consecutive days.',
    'lwp':       'Unpaid leave, used once all other paid leave balances are exhausted.',
    'maternity': 'Granted as per the Maternity Benefit Act provisions.',
    'paternity': 'Applicable for new fathers, to be availed within 3 months of childbirth.',
  };

  // Matches web's LEAVE_TYPES_LIST — a fixed, always-shown set of 6 leave
  // types. The web frontend never derives this list from the backend's
  // policy API; it only uses that API for supplementary balance/policy-note
  // data, defaulting to 0/blank when a type has no policy record yet.
  static const List<String> allCodes = [
    'casual', 'earned', 'sick', 'lwp', 'maternity', 'paternity',
  ];

  static int colorValueForCode(String code) =>
      _hex[code.toLowerCase()] ?? _hex['casual']!;

  /// Short 2-3 letter badge label for a raw backend leave type code.
  static String shortLabelForCode(String code) =>
      _shortLabel[code.toLowerCase()] ?? code.toUpperCase();

  /// Full display label for a raw backend leave type code (fallback when the
  /// backend hasn't returned a `leave_type_display`/policy record for it).
  static String labelForCode(String code) =>
      _label[code.toLowerCase()] ?? code;

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

class LeaveCalendarEventEntity {
  final String id;
  final String employeeName;
  final String employeeCode;
  final String leaveTypeCode;
  final String leaveTypeName;
  final String startDate; // ISO 'YYYY-MM-DD'
  final String endDate;   // ISO 'YYYY-MM-DD'
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

  const LeaveStatsEntity({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
    this.cancelled = 0,
    this.year = 0,
    this.balances = const [],
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

  double get pct => totalDays > 0 ? (usedDays / totalDays).clamp(0.0, 1.0) : 0.0;
}
