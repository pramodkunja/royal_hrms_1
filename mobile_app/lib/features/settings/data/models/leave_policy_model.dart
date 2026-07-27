import 'package:flutter/foundation.dart';

// annual_days is a Django DecimalField, serialized by DRF as a string
// (e.g. "12.0"), not a JSON number.
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

// The full LeavePolicy rule-field set shared by LeavePolicySerializer,
// LeavePolicyCreateSerializer and LeavePolicyUpdateSerializer — see
// apps/hrms/serializers.py `_POLICY_RULE_FIELDS`.
@immutable
class LeavePolicyModel {
  final int id;
  final String
      leaveType; // raw code: casual/earned/sick/lwp/maternity/paternity/<custom>
  final String leaveTypeDisplay;
  final double annualDays;
  final bool canCarryForward;
  final int maxCarryForwardDays;
  final String policyNote;
  final bool isActive;
  final String updatedAt;
  // True for a locally-added custom type (see LeavePolicyScreen doc comment)
  // — kept for backward compatibility with any still-local preview flow.
  final bool isPreview;

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
  final int cancellationAllowedUntil; // cancellation_allowed_until (days before start)

  // ── Additional Rules ──
  final bool allowProbationLeave; // allow_probation_leave
  final bool allowNoticePeriodLeave; // allow_notice_period_leave
  final bool allowLeaveExtension; // allow_leave_extension
  final bool allowLeaveCombination; // allow_leave_combination

  const LeavePolicyModel({
    required this.id,
    required this.leaveType,
    required this.leaveTypeDisplay,
    required this.annualDays,
    required this.canCarryForward,
    required this.maxCarryForwardDays,
    required this.policyNote,
    required this.isActive,
    required this.updatedAt,
    this.isPreview = false,
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

  // Matches backend's LeavePolicySerializer exactly — see
  // apps/hrms/serializers.py LeavePolicySerializer.Meta.fields
  // (id, leave_type, leave_type_display, annual_days, can_carry_forward,
  // max_carry_forward_days, policy_note, is_active, + _POLICY_RULE_FIELDS,
  // updated_at). Note: the raw 'leave_type_label' field is NOT returned by
  // this serializer — only the computed 'leave_type_display' is.
  factory LeavePolicyModel.fromJson(Map<String, dynamic> json) {
    final code = json['leave_type'] as String? ?? '';
    return LeavePolicyModel(
      id: (json['id'] as num? ?? 0).toInt(),
      leaveType: code,
      leaveTypeDisplay: json['leave_type_display'] as String? ?? code,
      annualDays: _toDouble(json['annual_days']),
      canCarryForward: json['can_carry_forward'] as bool? ?? false,
      maxCarryForwardDays:
          (json['max_carry_forward_days'] as num? ?? 0).toInt(),
      policyNote: json['policy_note'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      updatedAt: json['updated_at'] as String? ?? '',
      minimumLeaveDuration: json.containsKey('minimum_leave_duration')
          ? _toDouble(json['minimum_leave_duration'])
          : 0.5,
      maximumLeaveDuration: (json['maximum_leave_duration'] as num? ?? 0).toInt(),
      maximumConsecutiveDays: (json['maximum_consecutive_days'] as num? ?? 0).toInt(),
      minimumNoticePeriod: (json['minimum_notice_period'] as num? ?? 0).toInt(),
      allowHalfDay: json['allow_half_day'] as bool? ?? true,
      allowBackdatedLeave: json['allow_backdated_leave'] as bool? ?? false,
      maximumBackdatedDays: (json['maximum_backdated_days'] as num? ?? 0).toInt(),
      allowFutureLeave: json['allow_future_leave'] as bool? ?? true,
      maximumFutureDays: (json['maximum_future_days'] as num? ?? 0).toInt(),
      sandwichLeaveEnabled: json['sandwich_leave_enabled'] as bool? ?? false,
      countHolidaysAsLeave: json['count_holidays_as_leave'] as bool? ?? false,
      countWeekoffsAsLeave: json['count_weekoffs_as_leave'] as bool? ?? false,
      applicableBranches: _toStringList(json['applicable_branches']),
      applicableDepartments: _toStringList(json['applicable_departments']),
      applicableDesignations: _toStringList(json['applicable_designations']),
      applicableEmploymentTypes: _toStringList(json['applicable_employment_types']),
      applicableGender: json['applicable_gender'] as String? ?? 'all',
      minimumServicePeriod: (json['minimum_service_period'] as num? ?? 0).toInt(),
      attachmentRequired: json['attachment_required'] as bool? ?? false,
      medicalCertificateRequired: json['medical_certificate_required'] as bool? ?? false,
      medicalCertificateAfterDays: (json['medical_certificate_after_days'] as num? ?? 3).toInt(),
      allowNegativeBalance: json['allow_negative_balance'] as bool? ?? false,
      convertToLop: json['convert_to_lop'] as bool? ?? false,
      allowLeaveCancellation: json['allow_leave_cancellation'] as bool? ?? true,
      cancellationAllowedUntil: (json['cancellation_allowed_until'] as num? ?? 0).toInt(),
      allowProbationLeave: json['allow_probation_leave'] as bool? ?? false,
      allowNoticePeriodLeave: json['allow_notice_period_leave'] as bool? ?? false,
      allowLeaveExtension: json['allow_leave_extension'] as bool? ?? false,
      allowLeaveCombination: json['allow_leave_combination'] as bool? ?? false,
    );
  }
}

// Matches backend's LeavePolicyUpdateSerializer exactly (PUT/PATCH
// /api/leave/policy/<leave_type>/) — annual_days, can_carry_forward,
// max_carry_forward_days, policy_note, is_active + the full
// _POLICY_RULE_FIELDS set. leave_type itself is fixed and not sent here.
class LeavePolicyFormData {
  double annualDays;
  bool canCarryForward;
  int maxCarryForwardDays;
  String policyNote;
  bool isActive;

  // ── Leave Application Rules ──
  double minimumLeaveDuration;
  int maximumLeaveDuration;
  int maximumConsecutiveDays;
  int minimumNoticePeriod;
  bool allowHalfDay;
  bool allowBackdatedLeave;
  int maximumBackdatedDays;
  bool allowFutureLeave;
  int maximumFutureDays;

  // ── Holiday & Week-off Rules ──
  bool sandwichLeaveEnabled;
  bool countHolidaysAsLeave;
  bool countWeekoffsAsLeave;

  // ── Eligibility Rules ──
  List<String> applicableBranches;
  List<String> applicableDepartments;
  List<String> applicableDesignations;
  List<String> applicableEmploymentTypes;
  String applicableGender;
  int minimumServicePeriod;

  // ── Documentation Rules ──
  bool attachmentRequired;
  bool medicalCertificateRequired;
  int medicalCertificateAfterDays;

  // ── Leave Restrictions ──
  bool allowNegativeBalance;
  bool convertToLop;
  bool allowLeaveCancellation;
  int cancellationAllowedUntil;

  // ── Additional Rules ──
  bool allowProbationLeave;
  bool allowNoticePeriodLeave;
  bool allowLeaveExtension;
  bool allowLeaveCombination;

  LeavePolicyFormData({
    this.annualDays = 0,
    this.canCarryForward = false,
    this.maxCarryForwardDays = 0,
    this.policyNote = '',
    this.isActive = true,
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
    List<String>? applicableBranches,
    List<String>? applicableDepartments,
    List<String>? applicableDesignations,
    List<String>? applicableEmploymentTypes,
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
  })  : applicableBranches = applicableBranches ?? [],
        applicableDepartments = applicableDepartments ?? [],
        applicableDesignations = applicableDesignations ?? [],
        applicableEmploymentTypes = applicableEmploymentTypes ?? [];

  factory LeavePolicyFormData.fromModel(LeavePolicyModel model) =>
      LeavePolicyFormData(
        annualDays: model.annualDays,
        canCarryForward: model.canCarryForward,
        maxCarryForwardDays: model.maxCarryForwardDays,
        policyNote: model.policyNote,
        isActive: model.isActive,
        minimumLeaveDuration: model.minimumLeaveDuration,
        maximumLeaveDuration: model.maximumLeaveDuration,
        maximumConsecutiveDays: model.maximumConsecutiveDays,
        minimumNoticePeriod: model.minimumNoticePeriod,
        allowHalfDay: model.allowHalfDay,
        allowBackdatedLeave: model.allowBackdatedLeave,
        maximumBackdatedDays: model.maximumBackdatedDays,
        allowFutureLeave: model.allowFutureLeave,
        maximumFutureDays: model.maximumFutureDays,
        sandwichLeaveEnabled: model.sandwichLeaveEnabled,
        countHolidaysAsLeave: model.countHolidaysAsLeave,
        countWeekoffsAsLeave: model.countWeekoffsAsLeave,
        applicableBranches: List.of(model.applicableBranches),
        applicableDepartments: List.of(model.applicableDepartments),
        applicableDesignations: List.of(model.applicableDesignations),
        applicableEmploymentTypes: List.of(model.applicableEmploymentTypes),
        applicableGender: model.applicableGender,
        minimumServicePeriod: model.minimumServicePeriod,
        attachmentRequired: model.attachmentRequired,
        medicalCertificateRequired: model.medicalCertificateRequired,
        medicalCertificateAfterDays: model.medicalCertificateAfterDays,
        allowNegativeBalance: model.allowNegativeBalance,
        convertToLop: model.convertToLop,
        allowLeaveCancellation: model.allowLeaveCancellation,
        cancellationAllowedUntil: model.cancellationAllowedUntil,
        allowProbationLeave: model.allowProbationLeave,
        allowNoticePeriodLeave: model.allowNoticePeriodLeave,
        allowLeaveExtension: model.allowLeaveExtension,
        allowLeaveCombination: model.allowLeaveCombination,
      );

  Map<String, dynamic> toJson() => {
        'annual_days': annualDays,
        'can_carry_forward': canCarryForward,
        'max_carry_forward_days': maxCarryForwardDays,
        'policy_note': policyNote,
        'is_active': isActive,
        'minimum_leave_duration': minimumLeaveDuration,
        'maximum_leave_duration': maximumLeaveDuration,
        'maximum_consecutive_days': maximumConsecutiveDays,
        'minimum_notice_period': minimumNoticePeriod,
        'allow_half_day': allowHalfDay,
        'allow_backdated_leave': allowBackdatedLeave,
        'maximum_backdated_days': maximumBackdatedDays,
        'allow_future_leave': allowFutureLeave,
        'maximum_future_days': maximumFutureDays,
        'sandwich_leave_enabled': sandwichLeaveEnabled,
        'count_holidays_as_leave': countHolidaysAsLeave,
        'count_weekoffs_as_leave': countWeekoffsAsLeave,
        'applicable_branches': applicableBranches,
        'applicable_departments': applicableDepartments,
        'applicable_designations': applicableDesignations,
        'applicable_employment_types': applicableEmploymentTypes,
        'applicable_gender': applicableGender,
        'minimum_service_period': minimumServicePeriod,
        'attachment_required': attachmentRequired,
        'medical_certificate_required': medicalCertificateRequired,
        'medical_certificate_after_days': medicalCertificateAfterDays,
        'allow_negative_balance': allowNegativeBalance,
        'convert_to_lop': convertToLop,
        'allow_leave_cancellation': allowLeaveCancellation,
        'cancellation_allowed_until': cancellationAllowedUntil,
        'allow_probation_leave': allowProbationLeave,
        'allow_notice_period_leave': allowNoticePeriodLeave,
        'allow_leave_extension': allowLeaveExtension,
        'allow_leave_combination': allowLeaveCombination,
      };

  // Matches LeavePolicyUpdateSerializer.validate_annual_days /
  // validate() unconditional field checks, plus the maximum >= minimum
  // duration cross-check and the medical-certificate-after-days requirement.
  Map<String, String?> validate() {
    final errors = <String, String?>{};
    if (annualDays < 0) {
      errors['annualDays'] = 'Annual days cannot be negative.';
    }
    if (maxCarryForwardDays < 0) {
      errors['maxCarryForwardDays'] =
          'Max carry forward days cannot be negative.';
    }
    if (maximumLeaveDuration > 0 &&
        maximumLeaveDuration < minimumLeaveDuration) {
      errors['maximumLeaveDuration'] =
          'Maximum duration must be ≥ minimum duration.';
    }
    if (medicalCertificateRequired && medicalCertificateAfterDays <= 0) {
      errors['medicalCertificateAfterDays'] =
          'Required when medical certificate is enabled.';
    }
    return errors;
  }
}

// Result of POST /leave/balance/credit/ (LeaveBalanceView.post) — a real,
// working backend action that credits every active employee's annual leave
// balance for a year, based on each policy's annual_days.
@immutable
class CreditBalancesResult {
  final int year;
  final int credited;

  const CreditBalancesResult({required this.year, required this.credited});

  factory CreditBalancesResult.fromJson(Map<String, dynamic> json) =>
      CreditBalancesResult(
        year: (json['year'] as num? ?? 0).toInt(),
        credited: (json['credited'] as num? ?? 0).toInt(),
      );
}

// ─── Carry Forward execution (year-range batch job) ───────────────────────────
// Matches web's types/leave.ts CarryForward* interfaces exactly — see the
// doc comment on ApiConstants.carryForward* for why these currently 404.

@immutable
class CarryForwardYearPair {
  final int fromYear;
  final int toYear;
  const CarryForwardYearPair({required this.fromYear, required this.toYear});

  factory CarryForwardYearPair.fromJson(Map<String, dynamic> json) =>
      CarryForwardYearPair(
        fromYear: (json['from_year'] as num? ?? 0).toInt(),
        toYear: (json['to_year'] as num? ?? 0).toInt(),
      );
}

@immutable
class CarryForwardYearsModel {
  final List<CarryForwardYearPair> years;
  final int defaultFrom;
  final int defaultTo;
  const CarryForwardYearsModel({
    required this.years,
    required this.defaultFrom,
    required this.defaultTo,
  });

  factory CarryForwardYearsModel.fromJson(Map<String, dynamic> json) =>
      CarryForwardYearsModel(
        years: (json['years'] as List<dynamic>? ?? [])
            .map((e) => CarryForwardYearPair.fromJson(e as Map<String, dynamic>))
            .toList(),
        defaultFrom: (json['default_from'] as num? ?? 0).toInt(),
        defaultTo: (json['default_to'] as num? ?? 0).toInt(),
      );
}

@immutable
class CarryForwardPreviewRow {
  final String employeeId;
  final String employeeName;
  final String leaveType;
  final String leaveTypeDisplay;
  final double unusedDays;
  final double carryForwardAmount;
  final String? expiryDate;
  final bool alreadyProcessed;

  const CarryForwardPreviewRow({
    required this.employeeId,
    required this.employeeName,
    required this.leaveType,
    required this.leaveTypeDisplay,
    required this.unusedDays,
    required this.carryForwardAmount,
    this.expiryDate,
    required this.alreadyProcessed,
  });

  factory CarryForwardPreviewRow.fromJson(Map<String, dynamic> json) =>
      CarryForwardPreviewRow(
        employeeId: json['employee_id'] as String? ?? '',
        employeeName: json['employee_name'] as String? ?? '',
        leaveType: json['leave_type'] as String? ?? '',
        leaveTypeDisplay: json['leave_type_display'] as String? ?? '',
        unusedDays: _toDouble(json['unused_days']),
        carryForwardAmount: _toDouble(json['carry_forward_amount']),
        expiryDate: json['expiry_date'] as String?,
        alreadyProcessed: json['already_processed'] as bool? ?? false,
      );
}

@immutable
class CarryForwardPreviewModel {
  final int fromYear;
  final int toYear;
  final int totalRows;
  final int pendingCount;
  final int alreadyProcessedCount;
  final List<CarryForwardPreviewRow> previewRows;

  const CarryForwardPreviewModel({
    required this.fromYear,
    required this.toYear,
    required this.totalRows,
    required this.pendingCount,
    required this.alreadyProcessedCount,
    required this.previewRows,
  });

  factory CarryForwardPreviewModel.fromJson(Map<String, dynamic> json) =>
      CarryForwardPreviewModel(
        fromYear: (json['from_year'] as num? ?? 0).toInt(),
        toYear: (json['to_year'] as num? ?? 0).toInt(),
        totalRows: (json['total_rows'] as num? ?? 0).toInt(),
        pendingCount: (json['pending_count'] as num? ?? 0).toInt(),
        alreadyProcessedCount:
            (json['already_processed_count'] as num? ?? 0).toInt(),
        previewRows: (json['preview_rows'] as List<dynamic>? ?? [])
            .map((e) =>
                CarryForwardPreviewRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

@immutable
class CarryForwardLogModel {
  final String id;
  final int fromYear;
  final int toYear;
  final String executedByName;
  final int totalProcessed;
  final int totalSkipped;
  final int totalFailed;
  final bool isCompleted;
  final String createdAt;

  const CarryForwardLogModel({
    required this.id,
    required this.fromYear,
    required this.toYear,
    required this.executedByName,
    required this.totalProcessed,
    required this.totalSkipped,
    required this.totalFailed,
    required this.isCompleted,
    required this.createdAt,
  });

  factory CarryForwardLogModel.fromJson(Map<String, dynamic> json) =>
      CarryForwardLogModel(
        id: json['id']?.toString() ?? '',
        fromYear: (json['from_year'] as num? ?? 0).toInt(),
        toYear: (json['to_year'] as num? ?? 0).toInt(),
        executedByName: json['executed_by_name'] as String? ?? '',
        totalProcessed: (json['total_processed'] as num? ?? 0).toInt(),
        totalSkipped: (json['total_skipped'] as num? ?? 0).toInt(),
        totalFailed: (json['total_failed'] as num? ?? 0).toInt(),
        isCompleted: json['is_completed'] as bool? ?? false,
        createdAt: json['created_at'] as String? ?? '',
      );
}

@immutable
class CarryForwardHistoryModel {
  final int count;
  final int page;
  final int totalPages;
  final List<CarryForwardLogModel> results;

  const CarryForwardHistoryModel({
    required this.count,
    required this.page,
    required this.totalPages,
    required this.results,
  });

  factory CarryForwardHistoryModel.fromJson(Map<String, dynamic> json) =>
      CarryForwardHistoryModel(
        count: (json['count'] as num? ?? 0).toInt(),
        page: (json['page'] as num? ?? 1).toInt(),
        totalPages: (json['total_pages'] as num? ?? 1).toInt(),
        results: (json['results'] as List<dynamic>? ?? [])
            .map((e) => CarryForwardLogModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static const empty = CarryForwardHistoryModel(
      count: 0, page: 1, totalPages: 1, results: []);
}
