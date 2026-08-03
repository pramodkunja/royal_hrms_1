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

List<String> _toStringList(dynamic value) {
  if (value is List) return value.map((e) => e.toString()).toList();
  return const [];
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
    super.maxCarryForwardDays,
    super.minimumLeaveDuration,
    super.maximumLeaveDuration,
    super.maximumConsecutiveDays,
    super.minimumNoticePeriod,
    super.allowHalfDay,
    super.allowBackdatedLeave,
    super.maximumBackdatedDays,
    super.allowFutureLeave,
    super.maximumFutureDays,
    super.sandwichLeaveEnabled,
    super.countHolidaysAsLeave,
    super.countWeekoffsAsLeave,
    super.applicableBranches,
    super.applicableDepartments,
    super.applicableDesignations,
    super.applicableEmploymentTypes,
    super.applicableGender,
    super.minimumServicePeriod,
    super.attachmentRequired,
    super.medicalCertificateRequired,
    super.medicalCertificateAfterDays,
    super.allowNegativeBalance,
    super.convertToLop,
    super.allowLeaveCancellation,
    super.cancellationAllowedUntil,
    super.allowProbationLeave,
    super.allowNoticePeriodLeave,
    super.allowLeaveExtension,
    super.allowLeaveCombination,
  });

  // Backend returns LeavePolicy objects — see apps/hrms/serializers.py
  // LeavePolicySerializer.Meta.fields ('leave_type', 'leave_type_display' +
  // the full rule-field set). isPaid/genderEligibility have no direct backend
  // field and are derived from the code; docRequired/attachmentRequired now
  // read the real 'attachment_required' policy field (falling back to the
  // legacy hardcoded set only if the key is ever absent).
  factory LeaveTypeModel.fromJson(Map<String, dynamic> json) {
    final code = json['leave_type'] as String? ?? '';
    final attachmentRequired = json['attachment_required'] as bool? ??
        LeaveTypeColors.docRequiredForCode(code);
    return LeaveTypeModel(
      id: (json['id'] as num? ?? 0).toInt(),
      name: json['leave_type_display'] as String? ?? code,
      code: code,
      maxDays: _toDouble(json['annual_days']).toInt(),
      isPaid: !LeaveTypeColors.isLwp(code),
      carryForward: json['can_carry_forward'] as bool? ?? false,
      docRequired: attachmentRequired,
      genderEligibility: 'All',
      isActive: json['is_active'] as bool? ?? true,
      description: json['policy_note'] as String? ?? '',
      policy: json['policy_note'] as String? ?? '',
      maxCarryForwardDays:
          (json['max_carry_forward_days'] as num? ?? 0).toInt(),
      minimumLeaveDuration: json.containsKey('minimum_leave_duration')
          ? _toDouble(json['minimum_leave_duration'])
          : 0.5,
      maximumLeaveDuration:
          (json['maximum_leave_duration'] as num? ?? 0).toInt(),
      maximumConsecutiveDays:
          (json['maximum_consecutive_days'] as num? ?? 0).toInt(),
      minimumNoticePeriod: (json['minimum_notice_period'] as num? ?? 0).toInt(),
      allowHalfDay: json['allow_half_day'] as bool? ?? true,
      allowBackdatedLeave: json['allow_backdated_leave'] as bool? ?? false,
      maximumBackdatedDays:
          (json['maximum_backdated_days'] as num? ?? 0).toInt(),
      allowFutureLeave: json['allow_future_leave'] as bool? ?? true,
      maximumFutureDays: (json['maximum_future_days'] as num? ?? 0).toInt(),
      sandwichLeaveEnabled: json['sandwich_leave_enabled'] as bool? ?? false,
      countHolidaysAsLeave: json['count_holidays_as_leave'] as bool? ?? false,
      countWeekoffsAsLeave: json['count_weekoffs_as_leave'] as bool? ?? false,
      applicableBranches: _toStringList(json['applicable_branches']),
      applicableDepartments: _toStringList(json['applicable_departments']),
      applicableDesignations: _toStringList(json['applicable_designations']),
      applicableEmploymentTypes:
          _toStringList(json['applicable_employment_types']),
      applicableGender: json['applicable_gender'] as String? ?? 'all',
      minimumServicePeriod:
          (json['minimum_service_period'] as num? ?? 0).toInt(),
      attachmentRequired: attachmentRequired,
      medicalCertificateRequired:
          json['medical_certificate_required'] as bool? ?? false,
      medicalCertificateAfterDays:
          (json['medical_certificate_after_days'] as num? ?? 3).toInt(),
      allowNegativeBalance: json['allow_negative_balance'] as bool? ?? false,
      convertToLop: json['convert_to_lop'] as bool? ?? false,
      allowLeaveCancellation: json['allow_leave_cancellation'] as bool? ?? true,
      cancellationAllowedUntil:
          (json['cancellation_allowed_until'] as num? ?? 0).toInt(),
      allowProbationLeave: json['allow_probation_leave'] as bool? ?? false,
      allowNoticePeriodLeave:
          json['allow_notice_period_leave'] as bool? ?? false,
      allowLeaveExtension: json['allow_leave_extension'] as bool? ?? false,
      allowLeaveCombination: json['allow_leave_combination'] as bool? ?? false,
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
      used: _toDouble(json['used_days']),
      total: _toDouble(json['total_days']),
    );
  }
}

class LeaveRequestModel extends LeaveRequestEntity {
  const LeaveRequestModel({
    required super.id,
    required super.employee,
    super.employeeCode,
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
    super.lopDays,
    super.l1Status,
    super.l2Status,
    super.l1ActionedAt,
    super.l2ActionedAt,
    super.l1Remarks,
    super.l2Remarks,
    super.handoverTo,
    super.contactDuringLeave,
    super.handoverNotes,
    super.canApprove,
    super.canCancel,
    super.approvedBy,
    super.approvedAt,
  });

  // Backend returns: start_date, end_date, total_days, lop_days, employee_name,
  // employee_branch, employee_dept, leave_type (code), leave_type_display,
  // duration_display, status, reason, created_at, l1_remarks/l2_remarks
  // (rejection reasons), l1_approver_name, l1_status, l1_actioned_at,
  // l2_approver_name, l2_status, l2_actioned_at, document_url, can_approve,
  // can_cancel, approved_by, approved_at.
  // total_days/lop_days are DecimalFields, so they arrive as strings — see _toDouble.
  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    final l1Remarks = json['l1_remarks'] as String?;
    final l2Remarks = json['l2_remarks'] as String?;
    final rejectReason = (l1Remarks != null && l1Remarks.isNotEmpty)
        ? l1Remarks
        : (l2Remarks != null && l2Remarks.isNotEmpty ? l2Remarks : null);
    return LeaveRequestModel(
      id: json['id']?.toString() ?? '',
      employee: json['employee_name'] as String? ?? '',
      employeeCode: json['employee_code'] as String? ?? '',
      branch: json['employee_branch'] as String? ?? '',
      department: json['employee_dept'] as String? ?? '',
      leaveType: json['leave_type_display'] as String? ?? '',
      leaveTypeCode: json['leave_type'] as String? ?? '',
      durationDisplay: json['duration_display'] as String? ?? '',
      from: json['start_date'] as String? ?? '',
      to: json['end_date'] as String? ?? '',
      days: _toDouble(json['total_days']).round(),
      status: json['status'] as String? ?? 'pending',
      reason: json['reason'] as String? ?? '',
      appliedOn: json['created_at'] as String? ?? '',
      rejectReason: rejectReason,
      l1ApproverName: json['l1_approver_name'] as String? ?? '',
      l2ApproverName: json['l2_approver_name'] as String? ?? '',
      documentUrl: json['document_url'] as String?,
      lopDays: _toDouble(json['lop_days']),
      l1Status: json['l1_status'] as String?,
      l2Status: json['l2_status'] as String?,
      l1ActionedAt: json['l1_actioned_at'] as String?,
      l2ActionedAt: json['l2_actioned_at'] as String?,
      l1Remarks: l1Remarks,
      l2Remarks: l2Remarks,
      handoverTo: json['handover_to'] as String?,
      contactDuringLeave: json['contact_during_leave'] as String?,
      handoverNotes: json['handover_notes'] as String?,
      canApprove: json['can_approve'] as bool? ?? false,
      canCancel: json['can_cancel'] as bool? ?? false,
      approvedBy: json['approved_by'] as String? ?? '',
      approvedAt: json['approved_at'] as String?,
    );
  }
}

class LeaveRequestPageModel extends LeaveRequestPageEntity {
  const LeaveRequestPageModel({
    required super.results,
    required super.count,
    required super.page,
    required super.pageSize,
    required super.totalPages,
  });

  // Backend returns paginated {count, page, page_size, total_pages, results}
  // for GET /leave/requests/ (core/pagination.py paginated_data) — but also
  // tolerate a plain list, in case pagination is ever bypassed.
  factory LeaveRequestPageModel.fromJson(dynamic data) {
    if (data is List) {
      final results = data
          .whereType<Map<String, dynamic>>()
          .map(LeaveRequestModel.fromJson)
          .toList();
      return LeaveRequestPageModel(
        results: results,
        count: results.length,
        page: 1,
        pageSize: results.isEmpty ? 20 : results.length,
        totalPages: 1,
      );
    }
    if (data is Map<String, dynamic>) {
      final rawResults = data['results'] as List<dynamic>? ?? [];
      final results = rawResults
          .whereType<Map<String, dynamic>>()
          .map(LeaveRequestModel.fromJson)
          .toList();
      final totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;
      return LeaveRequestPageModel(
        results: results,
        count: (data['count'] as num?)?.toInt() ?? results.length,
        page: (data['page'] as num?)?.toInt() ?? 1,
        pageSize: (data['page_size'] as num?)?.toInt() ?? 20,
        totalPages: totalPages == 0 ? 1 : totalPages,
      );
    }
    return const LeaveRequestPageModel(
        results: [], count: 0, page: 1, pageSize: 20, totalPages: 1);
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
      id: json['id']?.toString() ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      employeeCode: json['employee_code'] as String? ?? '',
      leaveTypeCode: json['leave_type'] as String? ?? '',
      leaveTypeName: json['leave_type_display'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      totalDays: _toDouble(json['total_days']),
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
    super.lopDays,
    super.lopRequests,
  });

  // Backend returns: total, pending, approved, rejected, cancelled, year,
  // lop_days, lop_requests,
  // balances: [{leave_type, leave_type_display, total_days, used_days, available}]
  factory LeaveStatsModel.fromJson(Map<String, dynamic> json) {
    final rawBalances = json['balances'] as List<dynamic>? ?? [];
    return LeaveStatsModel(
      total: (json['total'] as num? ?? 0).toInt(),
      pending: (json['pending'] as num? ?? 0).toInt(),
      approved: (json['approved'] as num? ?? 0).toInt(),
      rejected: (json['rejected'] as num? ?? 0).toInt(),
      cancelled: (json['cancelled'] as num? ?? 0).toInt(),
      year: (json['year'] as num? ?? 0).toInt(),
      balances: rawBalances
          .whereType<Map<String, dynamic>>()
          .map(BalanceSummaryModel.fromJson)
          .toList(),
      lopDays: _toDouble(json['lop_days']),
      lopRequests: (json['lop_requests'] as num? ?? 0).toInt(),
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
      leaveTypeCode: json['leave_type'] as String? ?? '',
      leaveTypeDisplay: json['leave_type_display'] as String? ?? '',
      totalDays: _toDouble(json['total_days']),
      usedDays: _toDouble(json['used_days']),
      available: _toDouble(json['available']),
    );
  }
}

// ── Leave Preview ─────────────────────────────────────────────────────────────

List<NamedDateEntity> _namedDates(dynamic raw, String labelKey) {
  final list = raw is List ? raw : const [];
  return list
      .whereType<Map<String, dynamic>>()
      .map((j) => NamedDateEntity(
            date: j['date'] as String? ?? '',
            label: j[labelKey] as String? ?? '',
          ))
      .toList();
}

class LeavePreviewModel extends LeavePreviewEntity {
  const LeavePreviewModel({
    required super.leaveType,
    required super.calendarDays,
    required super.companyHolidays,
    required super.companyHolidayCount,
    required super.weekOffs,
    required super.weekOffCount,
    required super.sandwichLeaveEnabled,
    required super.actualLeaveDays,
    required super.availableBalance,
    required super.earnedLeaveUsed,
    required super.lopDays,
    required super.lopEnabled,
    required super.sufficientBalance,
    required super.warning,
  });

  factory LeavePreviewModel.fromJson(Map<String, dynamic> json) {
    return LeavePreviewModel(
      leaveType: json['leave_type'] as String? ?? '',
      calendarDays: (json['calendar_days'] as num? ?? 0).toInt(),
      companyHolidays: _namedDates(json['company_holidays'], 'name'),
      companyHolidayCount: (json['company_holiday_count'] as num? ?? 0).toInt(),
      weekOffs: _namedDates(json['week_offs'], 'day'),
      weekOffCount: (json['week_off_count'] as num? ?? 0).toInt(),
      sandwichLeaveEnabled: json['sandwich_leave_enabled'] as bool? ?? false,
      actualLeaveDays: _toDouble(json['actual_leave_days']),
      availableBalance: _toDouble(json['available_balance']),
      earnedLeaveUsed: _toDouble(json['earned_leave_used']),
      lopDays: _toDouble(json['lop_days']),
      lopEnabled: json['lop_enabled'] as bool? ?? false,
      sufficientBalance: json['sufficient_balance'] as bool? ?? true,
      warning: json['warning'] as String? ?? '',
    );
  }
}
