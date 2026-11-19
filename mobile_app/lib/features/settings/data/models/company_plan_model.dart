import 'package:flutter/foundation.dart';

// GET /settings/company/plan/ — Company Settings → Plan Details (read-only,
// settings.edit only). Mirrors web types/planDetails.ts; built by the
// backend's apps/tenants/customer_plan.py. Nothing here is computed on the
// device: every state, amount and label comes from the server.

String _str(Object? v, [String fallback = '']) => v == null ? fallback : '$v';
String? _strOrNull(Object? v) => v == null ? null : '$v';
List<String> _strList(Object? v) => v is List ? [for (final e in v) '$e'] : const [];
List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e)
      ]
    : const [];
int? _intOrNull(Object? v) => v is num ? v.toInt() : (v == null ? null : int.tryParse('$v'));

@immutable
class PlanFeatureLabel {
  const PlanFeatureLabel({required this.key, required this.label, required this.description});
  final String key;
  final String label;
  final String description;

  factory PlanFeatureLabel.fromJson(Map<String, dynamic> j) =>
      PlanFeatureLabel(key: _str(j['key']), label: _str(j['label']), description: _str(j['description']));
}

/// One module row: what the plan entitles (`included`) and what the
/// company's users can use right now (`enabled`).
@immutable
class PlanModuleRow {
  const PlanModuleRow({
    required this.key,
    required this.label,
    required this.description,
    required this.category,
    required this.included,
    required this.enabled,
    required this.source,
    required this.access,
    required this.requiredBy,
  });

  final String key;
  final String label;
  final String description;
  final String category;
  final bool included;
  final bool enabled;

  /// plan | dependency | added | removed | not_included
  final String source;

  /// enabled | pending | off
  final String access;
  final List<String> requiredBy;

  factory PlanModuleRow.fromJson(Map<String, dynamic> j) => PlanModuleRow(
        key: _str(j['key']),
        label: _str(j['label']),
        description: _str(j['description']),
        category: _str(j['category']),
        included: j['included'] == true,
        enabled: j['enabled'] == true,
        source: _str(j['source'], 'not_included'),
        access: _str(j['access'], 'off'),
        requiredBy: _strList(j['required_by']),
      );
}

@immutable
class CurrentPlan {
  const CurrentPlan({
    required this.planName,
    required this.planCode,
    required this.description,
    required this.billingPeriod,
    required this.startsOn,
    required this.endsOn,
    required this.periodEnded,
    required this.daysLeft,
    required this.status,
    required this.activation,
    required this.paymentStatus,
    required this.employeeCount,
    required this.pricePerEmployee,
    required this.currency,
    required this.gstRate,
    required this.gstInclusive,
    required this.totalAmount,
    required this.amountPaid,
    required this.amountPendingConfirmation,
    required this.amountOutstanding,
    required this.features,
  });

  final String planName;
  final String planCode;
  final String description;
  final String billingPeriod;
  final String? startsOn;
  final String? endsOn;
  final bool periodEnded;
  final int? daysLeft;

  /// active | inactive
  final String status;

  /// active | awaiting_payment | setting_up
  final String activation;

  /// pending | paid | partially_paid | failed | waived
  final String paymentStatus;
  final int? employeeCount;
  final String pricePerEmployee;
  final String currency;
  final String gstRate;
  final bool gstInclusive;
  final String? totalAmount;
  final String amountPaid;
  final String amountPendingConfirmation;
  final String? amountOutstanding;
  final List<PlanFeatureLabel> features;

  factory CurrentPlan.fromJson(Map<String, dynamic> j) => CurrentPlan(
        planName: _str(j['plan_name']),
        planCode: _str(j['plan_code']),
        description: _str(j['description']),
        billingPeriod: _str(j['billing_period']),
        startsOn: _strOrNull(j['starts_on']),
        endsOn: _strOrNull(j['ends_on']),
        periodEnded: j['period_ended'] == true,
        daysLeft: _intOrNull(j['days_left']),
        status: _str(j['status'], 'inactive'),
        activation: _str(j['activation'], 'setting_up'),
        paymentStatus: _str(j['payment_status'], 'pending'),
        employeeCount: _intOrNull(j['employee_count']),
        pricePerEmployee: _str(j['price_per_employee'], '0'),
        currency: _str(j['currency'], 'INR'),
        gstRate: _str(j['gst_rate'], '0'),
        gstInclusive: j['gst_inclusive'] == true,
        totalAmount: _strOrNull(j['total_amount']),
        amountPaid: _str(j['amount_paid'], '0'),
        amountPendingConfirmation: _str(j['amount_pending_confirmation'], '0'),
        amountOutstanding: _strOrNull(j['amount_outstanding']),
        features: [for (final f in _maps(j['features'])) PlanFeatureLabel.fromJson(f)],
      );
}

@immutable
class PlanPayment {
  const PlanPayment({
    required this.paidOn,
    required this.amount,
    required this.currency,
    required this.method,
    required this.reference,
    required this.status,
  });

  final String paidOn;
  final String amount;
  final String currency;
  final String method;
  final String reference;

  /// confirmed | awaiting_confirmation
  final String status;

  factory PlanPayment.fromJson(Map<String, dynamic> j) => PlanPayment(
        paidOn: _str(j['paid_on']),
        amount: _str(j['amount'], '0'),
        currency: _str(j['currency'], 'INR'),
        method: _str(j['method']),
        reference: _str(j['reference']),
        status: _str(j['status'], 'awaiting_confirmation'),
      );
}

@immutable
class PlanEstimate {
  const PlanEstimate({required this.billingPeriod, required this.total});
  final String billingPeriod;
  final String total;

  factory PlanEstimate.fromJson(Map<String, dynamic> j) =>
      PlanEstimate(billingPeriod: _str(j['billing_period']), total: _str(j['total'], '0'));
}

@immutable
class OtherPlan {
  const OtherPlan({
    required this.name,
    required this.code,
    required this.description,
    required this.pricePerEmployee,
    required this.currency,
    required this.gstRate,
    required this.gstInclusive,
    required this.billingPeriods,
    required this.minEmployees,
    required this.maxEmployees,
    required this.modules,
    required this.additionalModules,
    required this.modulesNotIncluded,
    required this.features,
    required this.estimateEmployeeCount,
    required this.fitsEmployeeCount,
    required this.estimates,
  });

  final String name;
  final String code;
  final String description;
  final String pricePerEmployee;
  final String currency;
  final String gstRate;
  final bool gstInclusive;
  final List<String> billingPeriods;
  final int? minEmployees;
  final int? maxEmployees;
  final List<String> modules;
  final List<String> additionalModules;
  final List<String> modulesNotIncluded;
  final List<PlanFeatureLabel> features;
  final int? estimateEmployeeCount;
  final bool fitsEmployeeCount;
  final List<PlanEstimate> estimates;

  factory OtherPlan.fromJson(Map<String, dynamic> j) => OtherPlan(
        name: _str(j['name']),
        code: _str(j['code']),
        description: _str(j['description']),
        pricePerEmployee: _str(j['price_per_employee'], '0'),
        currency: _str(j['currency'], 'INR'),
        gstRate: _str(j['gst_rate'], '0'),
        gstInclusive: j['gst_inclusive'] == true,
        billingPeriods: _strList(j['billing_periods']),
        minEmployees: _intOrNull(j['min_employees']),
        maxEmployees: _intOrNull(j['max_employees']),
        modules: _strList(j['modules']),
        additionalModules: _strList(j['additional_modules']),
        modulesNotIncluded: _strList(j['modules_not_included']),
        features: [for (final f in _maps(j['features'])) PlanFeatureLabel.fromJson(f)],
        estimateEmployeeCount: _intOrNull(j['estimate_employee_count']),
        fitsEmployeeCount: j['fits_employee_count'] != false,
        estimates: [for (final e in _maps(j['estimates'])) PlanEstimate.fromJson(e)],
      );
}

@immutable
class PlanDetails {
  const PlanDetails({
    required this.hasPlan,
    required this.current,
    required this.modules,
    required this.enabledModules,
    required this.alwaysIncluded,
    required this.comingSoon,
    required this.payments,
    required this.otherPlans,
  });

  final bool hasPlan;
  final CurrentPlan? current;
  final List<PlanModuleRow> modules;
  final List<String> enabledModules;
  final List<PlanFeatureLabel> alwaysIncluded;
  final List<PlanFeatureLabel> comingSoon;
  final List<PlanPayment> payments;
  final List<OtherPlan> otherPlans;

  factory PlanDetails.fromJson(Map<String, dynamic> j) => PlanDetails(
        hasPlan: j['has_plan'] == true,
        current: j['current'] is Map ? CurrentPlan.fromJson(Map<String, dynamic>.from(j['current'] as Map)) : null,
        modules: [for (final m in _maps(j['modules'])) PlanModuleRow.fromJson(m)],
        enabledModules: _strList(j['enabled_modules']),
        alwaysIncluded: [for (final f in _maps(j['always_included'])) PlanFeatureLabel.fromJson(f)],
        comingSoon: [for (final f in _maps(j['coming_soon'])) PlanFeatureLabel.fromJson(f)],
        payments: [for (final p in _maps(j['payments'])) PlanPayment.fromJson(p)],
        otherPlans: [for (final p in _maps(j['other_plans'])) OtherPlan.fromJson(p)],
      );
}
