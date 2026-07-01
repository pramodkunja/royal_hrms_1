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
  final String from;   // ISO date string 'YYYY-MM-DD'
  final String to;     // ISO date string 'YYYY-MM-DD'
  final int days;
  final String status;
  final String reason;
  final String appliedOn;
  final String? rejectReason;

  const LeaveRequestEntity({
    required this.id,
    required this.employee,
    required this.branch,
    required this.department,
    required this.leaveType,
    required this.leaveTypeCode,
    required this.from,
    required this.to,
    required this.days,
    required this.status,
    required this.reason,
    required this.appliedOn,
    this.rejectReason,
  });

  bool get isPending   => status == 'pending';
  bool get isApproved  => status == 'approved';
  bool get isRejected  => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
}

class LeaveStatsEntity {
  final int total;
  final int pending;
  final int approved;
  final int rejected;

  const LeaveStatsEntity({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });
}
