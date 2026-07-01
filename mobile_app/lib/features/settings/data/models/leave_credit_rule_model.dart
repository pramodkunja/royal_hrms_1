import 'package:flutter/foundation.dart';

// NOTE: There is no backend for Leave Credit Rules yet (no model, serializer,
// or endpoint on the Django side — confirmed against
// web_frontend_backend/Royal-HRMS/backend/apps/hrms/). This mirrors the web
// frontend's own leave-credit-rules/page.tsx, which is also local-only seed
// data with a fake save. State here lives only in LeaveCreditRulesScreen and
// resets on app restart. toJson()/field names already match what the web
// mockup would send, so wiring this to a real API later is a drop-in swap.

enum AccrualFrequency { monthly, quarterly, annually, onJoining }

extension AccrualFrequencyX on AccrualFrequency {
  String get label => switch (this) {
        AccrualFrequency.monthly => 'Monthly',
        AccrualFrequency.quarterly => 'Quarterly',
        AccrualFrequency.annually => 'Annually',
        AccrualFrequency.onJoining => 'On Joining',
      };

  String get apiValue => switch (this) {
        AccrualFrequency.monthly => 'monthly',
        AccrualFrequency.quarterly => 'quarterly',
        AccrualFrequency.annually => 'annually',
        AccrualFrequency.onJoining => 'on_joining',
      };
}

@immutable
class LeaveCreditRuleModel {
  final int id;
  final String
      leaveType; // free text on the web mockup — not tied to the 6 fixed LeavePolicy codes
  final double accrualDays;
  final AccrualFrequency frequency;
  final int maxBalance;
  final bool encashable;
  final int encashLimit;
  final int minServiceMonths;
  final bool isActive;

  const LeaveCreditRuleModel({
    required this.id,
    required this.leaveType,
    required this.accrualDays,
    required this.frequency,
    required this.maxBalance,
    required this.encashable,
    required this.encashLimit,
    required this.minServiceMonths,
    required this.isActive,
  });

  LeaveCreditRuleModel copyWith({int? id}) => LeaveCreditRuleModel(
        id: id ?? this.id,
        leaveType: leaveType,
        accrualDays: accrualDays,
        frequency: frequency,
        maxBalance: maxBalance,
        encashable: encashable,
        encashLimit: encashLimit,
        minServiceMonths: minServiceMonths,
        isActive: isActive,
      );
}

// Matches the web's SEED constant exactly (leave-credit-rules/page.tsx).
final List<LeaveCreditRuleModel> kSeedCreditRules = [
  const LeaveCreditRuleModel(
      id: 1,
      leaveType: 'Earned Leave',
      accrualDays: 1.5,
      frequency: AccrualFrequency.monthly,
      maxBalance: 45,
      encashable: true,
      encashLimit: 15,
      minServiceMonths: 6,
      isActive: true),
  const LeaveCreditRuleModel(
      id: 2,
      leaveType: 'Casual Leave',
      accrualDays: 1,
      frequency: AccrualFrequency.monthly,
      maxBalance: 12,
      encashable: false,
      encashLimit: 0,
      minServiceMonths: 0,
      isActive: true),
  const LeaveCreditRuleModel(
      id: 3,
      leaveType: 'Sick Leave',
      accrualDays: 0.5,
      frequency: AccrualFrequency.monthly,
      maxBalance: 6,
      encashable: false,
      encashLimit: 0,
      minServiceMonths: 0,
      isActive: true),
  const LeaveCreditRuleModel(
      id: 4,
      leaveType: 'Annual Leave',
      accrualDays: 21,
      frequency: AccrualFrequency.annually,
      maxBalance: 21,
      encashable: true,
      encashLimit: 10,
      minServiceMonths: 12,
      isActive: false),
];

// Form state + validation — matches page.tsx's BLANK + validate() exactly.
class CreditRuleFormData {
  String leaveType;
  double accrualDays;
  AccrualFrequency frequency;
  int maxBalance;
  bool encashable;
  int encashLimit;
  int minServiceMonths;
  bool isActive;

  CreditRuleFormData({
    this.leaveType = '',
    this.accrualDays = 1,
    this.frequency = AccrualFrequency.monthly,
    this.maxBalance = 12,
    this.encashable = false,
    this.encashLimit = 0,
    this.minServiceMonths = 0,
    this.isActive = true,
  });

  factory CreditRuleFormData.fromModel(LeaveCreditRuleModel m) =>
      CreditRuleFormData(
        leaveType: m.leaveType,
        accrualDays: m.accrualDays,
        frequency: m.frequency,
        maxBalance: m.maxBalance,
        encashable: m.encashable,
        encashLimit: m.encashLimit,
        minServiceMonths: m.minServiceMonths,
        isActive: m.isActive,
      );

  Map<String, dynamic> toJson() => {
        'leave_type': leaveType,
        'accrual_days': accrualDays,
        'frequency': frequency.apiValue,
        'max_balance': maxBalance,
        'encashable': encashable,
        'encash_limit': encashLimit,
        'min_service_months': minServiceMonths,
        'is_active': isActive,
      };

  Map<String, String?> validate() {
    final errors = <String, String?>{};
    if (leaveType.trim().isEmpty) {
      errors['leaveType'] = 'Leave type is required.';
    }
    if (accrualDays <= 0) errors['accrualDays'] = 'Must be greater than 0.';
    if (maxBalance < 1) {
      errors['maxBalance'] = 'Max balance must be at least 1.';
    }
    if (encashable && encashLimit < 1) {
      errors['encashLimit'] = 'Encash limit must be at least 1.';
    }
    return errors;
  }
}
