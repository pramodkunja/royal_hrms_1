import '../../domain/entities/leave_entity.dart';

// Several backend leave fields (annual_days, total_days, used_days,
// carried_forward, etc.) are Django DecimalFields, which DRF serializes as
// JSON strings (e.g. "12.0"), not numbers. `as num?` throws on a String, so
// every numeric field coming from a DecimalField must go through this.
double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class LeaveTypeModel extends LeaveTypeEntity {
  const LeaveTypeModel({
    required super.id,
    required super.name,
    required super.code,
    required super.maxDays,
    required super.isPaid,
    required super.carryForward,
    required super.docRequired,
    required super.genderEligibility,
    required super.isActive,
    required super.description,
    required super.policy,
  });

  // Backend returns LeavePolicy objects with 'leave_type' (code) and 'leave_type_display' (name).
  // Fields not in backend (isPaid, docRequired, genderEligibility) are derived from the code.
  factory LeaveTypeModel.fromJson(Map<String, dynamic> json) {
    final code = json['leave_type'] as String? ?? '';
    return LeaveTypeModel(
      id:                (json['id'] as num? ?? 0).toInt(),
      name:              json['leave_type_display'] as String? ?? code,
      code:              code,
      maxDays:           _toDouble(json['annual_days']).toInt(),
      isPaid:            !LeaveTypeColors.isLwp(code),
      carryForward:      json['can_carry_forward'] as bool? ?? false,
      docRequired:       LeaveTypeColors.docRequiredForCode(code),
      genderEligibility: 'All',
      isActive:          json['is_active'] as bool? ?? true,
      description:       json['policy_note'] as String? ?? '',
      policy:            json['policy_note'] as String? ?? '',
    );
  }
}

class LeaveBalanceModel extends LeaveBalanceEntity {
  const LeaveBalanceModel({
    required super.typeCode,
    required super.typeName,
    required super.used,
    required super.total,
  });

  // Backend returns: leave_type (code), leave_type_display (name), used_days, total_days
  factory LeaveBalanceModel.fromJson(Map<String, dynamic> json) {
    final code = json['leave_type'] as String? ?? '';
    return LeaveBalanceModel(
      typeCode: code,
      typeName: json['leave_type_display'] as String? ?? code,
      used:     _toDouble(json['used_days']),
      total:    _toDouble(json['total_days']),
    );
  }
}

class LeaveRequestModel extends LeaveRequestEntity {
  const LeaveRequestModel({
    required super.id,
    required super.employee,
    required super.branch,
    required super.department,
    required super.leaveType,
    required super.leaveTypeCode,
    super.durationDisplay,
    required super.from,
    required super.to,
    required super.days,
    required super.status,
    required super.reason,
    required super.appliedOn,
    super.rejectReason,
    super.l1ApproverName,
    super.l2ApproverName,
    super.documentUrl,
  });

  // Backend returns: start_date, end_date, total_days, employee_name,
  // employee_branch, employee_dept, leave_type (code), leave_type_display,
  // duration_display, status, reason, created_at, l1_remarks/l2_remarks
  // (rejection reasons), l1_approver_name, l2_approver_name, document_url.
  // total_days is a DecimalField, so it arrives as a string — see _toDouble.
  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    final l1Remarks = json['l1_remarks'] as String?;
    final l2Remarks = json['l2_remarks'] as String?;
    final rejectReason = (l1Remarks != null && l1Remarks.isNotEmpty)
        ? l1Remarks
        : (l2Remarks != null && l2Remarks.isNotEmpty ? l2Remarks : null);
    return LeaveRequestModel(
      id:           json['id']?.toString() ?? '',
      employee:     json['employee_name'] as String? ?? '',
      branch:       json['employee_branch'] as String? ?? '',
      department:   json['employee_dept'] as String? ?? '',
      leaveType:    json['leave_type_display'] as String? ?? '',
      leaveTypeCode: json['leave_type'] as String? ?? '',
      durationDisplay: json['duration_display'] as String? ?? '',
      from:         json['start_date'] as String? ?? '',
      to:           json['end_date'] as String? ?? '',
      days:         _toDouble(json['total_days']).round(),
      status:       json['status'] as String? ?? 'pending',
      reason:       json['reason'] as String? ?? '',
      appliedOn:    json['created_at'] as String? ?? '',
      rejectReason: rejectReason,
      l1ApproverName: json['l1_approver_name'] as String? ?? '',
      l2ApproverName: json['l2_approver_name'] as String? ?? '',
      documentUrl:  json['document_url'] as String?,
    );
  }
}

class LeaveCalendarEventModel extends LeaveCalendarEventEntity {
  const LeaveCalendarEventModel({
    required super.id,
    required super.employeeName,
    required super.employeeCode,
    required super.leaveTypeCode,
    required super.leaveTypeName,
    required super.startDate,
    required super.endDate,
    required super.totalDays,
  });

  // Backend returns: id, employee_name, employee_code, leave_type (code),
  // leave_type_display, start_date, end_date, total_days
  factory LeaveCalendarEventModel.fromJson(Map<String, dynamic> json) {
    return LeaveCalendarEventModel(
      id:            json['id']?.toString() ?? '',
      employeeName:  json['employee_name'] as String? ?? '',
      employeeCode:  json['employee_code'] as String? ?? '',
      leaveTypeCode: json['leave_type'] as String? ?? '',
      leaveTypeName: json['leave_type_display'] as String? ?? '',
      startDate:     json['start_date'] as String? ?? '',
      endDate:       json['end_date'] as String? ?? '',
      totalDays:     _toDouble(json['total_days']),
    );
  }
}

class LeaveStatsModel extends LeaveStatsEntity {
  const LeaveStatsModel({
    required super.total,
    required super.pending,
    required super.approved,
    required super.rejected,
    super.cancelled,
    super.year,
    super.balances,
  });

  // Backend returns: total, pending, approved, rejected, cancelled, year,
  // balances: [{leave_type, leave_type_display, total_days, used_days, available}]
  factory LeaveStatsModel.fromJson(Map<String, dynamic> json) {
    final rawBalances = json['balances'] as List<dynamic>? ?? [];
    return LeaveStatsModel(
      total:     (json['total'] as num? ?? 0).toInt(),
      pending:   (json['pending'] as num? ?? 0).toInt(),
      approved:  (json['approved'] as num? ?? 0).toInt(),
      rejected:  (json['rejected'] as num? ?? 0).toInt(),
      cancelled: (json['cancelled'] as num? ?? 0).toInt(),
      year:      (json['year'] as num? ?? 0).toInt(),
      balances:  rawBalances
          .whereType<Map<String, dynamic>>()
          .map(BalanceSummaryModel.fromJson)
          .toList(),
    );
  }
}

class BalanceSummaryModel extends BalanceSummaryEntity {
  const BalanceSummaryModel({
    required super.leaveTypeCode,
    required super.leaveTypeDisplay,
    required super.totalDays,
    required super.usedDays,
    required super.available,
  });

  factory BalanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return BalanceSummaryModel(
      leaveTypeCode:    json['leave_type'] as String? ?? '',
      leaveTypeDisplay: json['leave_type_display'] as String? ?? '',
      totalDays:        _toDouble(json['total_days']),
      usedDays:         _toDouble(json['used_days']),
      available:        _toDouble(json['available']),
    );
  }
}
