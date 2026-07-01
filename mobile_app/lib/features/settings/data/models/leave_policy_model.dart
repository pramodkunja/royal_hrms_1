import 'package:flutter/foundation.dart';

// annual_days is a Django DecimalField, serialized by DRF as a string
// (e.g. "12.0"), not a JSON number.
double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

@immutable
class LeavePolicyModel {
  final int id;
  final String
      leaveType; // raw code: casual/earned/sick/lwp/maternity/paternity
  final String leaveTypeDisplay;
  final double annualDays;
  final bool canCarryForward;
  final int maxCarryForwardDays;
  final String policyNote;
  final bool isActive;
  final String updatedAt;
  // True for a locally-added custom type (see LeavePolicyScreen doc comment)
  // — the backend's leave_type is a fixed 6-item enum with no create
  // endpoint, so these never leave the device until real backend support exists.
  final bool isPreview;

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
  });

  // Matches backend's LeavePolicySerializer exactly — see
  // apps/hrms/serializers.py LeavePolicySerializer.Meta.fields.
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
    );
  }
}

// Matches backend's LeavePolicyUpdateSerializer exactly — these are the only
// 5 fields the PUT/PATCH endpoint accepts (leave_type itself is fixed and
// cannot be created/renamed/deleted; there are always exactly 6 policies).
class LeavePolicyFormData {
  double annualDays;
  bool canCarryForward;
  int maxCarryForwardDays;
  String policyNote;
  bool isActive;

  LeavePolicyFormData({
    this.annualDays = 0,
    this.canCarryForward = false,
    this.maxCarryForwardDays = 0,
    this.policyNote = '',
    this.isActive = true,
  });

  factory LeavePolicyFormData.fromModel(LeavePolicyModel model) =>
      LeavePolicyFormData(
        annualDays: model.annualDays,
        canCarryForward: model.canCarryForward,
        maxCarryForwardDays: model.maxCarryForwardDays,
        policyNote: model.policyNote,
        isActive: model.isActive,
      );

  Map<String, dynamic> toJson() => {
        'annual_days': annualDays,
        'can_carry_forward': canCarryForward,
        'max_carry_forward_days': maxCarryForwardDays,
        'policy_note': policyNote,
        'is_active': isActive,
      };

  // Matches LeavePolicyUpdateSerializer.validate_annual_days /
  // validate_max_carry_forward_days — both checked unconditionally, same as
  // the backend's per-field validators.
  Map<String, String?> validate() {
    final errors = <String, String?>{};
    if (annualDays < 0) {
      errors['annualDays'] = 'Annual days cannot be negative.';
    }
    if (maxCarryForwardDays < 0) {
      errors['maxCarryForwardDays'] =
          'Max carry forward days cannot be negative.';
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
