import '../data/models/company_plan_model.dart';

// Presentation helpers for Company Settings → Plan Details — a port of web
// lib/planDetails.ts. Nothing here decides access: every state comes from the
// server (apps/tenants/customer_plan.py).

const kSourceLabel = {
  'plan': 'Included',
  'dependency': 'Included',
  'added': 'Added for your company',
  'removed': 'Removed for your company',
  'not_included': 'Not included',
};

const kAccessLabel = {
  'enabled': 'Enabled',
  'pending': 'Activates when payment is confirmed',
  'off': 'Not enabled',
};

const kPaymentLabel = {
  'pending': 'Pending',
  'paid': 'Paid',
  'partially_paid': 'Partially paid',
  'failed': 'Failed',
  'waived': 'Waived',
};

const kActivationLabel = {
  'active': 'Modules active',
  'awaiting_payment': 'Activates when payment is confirmed',
  'setting_up': 'Being set up',
};

/// Explanation under the "In your plan" badge, e.g. "Required by Payroll".
String sourceNote(PlanModuleRow row) =>
    (row.source == 'dependency' && row.requiredBy.isNotEmpty) ? 'Required by ${row.requiredBy.join(', ')}' : '';

/// A module that is on although the subscription doesn't include it.
bool enabledOutsidePlan(PlanModuleRow row, bool hasPlan) => hasPlan && row.enabled && !row.included;

class ModuleSummary {
  const ModuleSummary(
      {required this.included, required this.enabled, required this.pending, required this.notIncluded});
  final int included;
  final int enabled;
  final int pending;
  final int notIncluded;
}

ModuleSummary moduleSummary(List<PlanModuleRow> rows) => ModuleSummary(
      included: rows.where((r) => r.included).length,
      enabled: rows.where((r) => r.enabled).length,
      pending: rows.where((r) => r.access == 'pending').length,
      notIncluded: rows.where((r) => !r.included).length,
    );

/// The summary line above the module list, as web writes it.
String moduleSummaryLine(ModuleSummary s) =>
    '${s.included} included · ${s.enabled} enabled${s.pending > 0 ? ' · ${s.pending} activate after payment' : ''}'
    ' · ${s.notIncluded} not included';

/// Included modules first, then alphabetical (web's row order).
List<PlanModuleRow> sortedModules(List<PlanModuleRow> rows) {
  final copy = [...rows];
  copy.sort((a, b) {
    final byIncluded = (b.included ? 1 : 0) - (a.included ? 1 : 0);
    return byIncluded != 0 ? byIncluded : a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });
  return copy;
}

class ComparisonRow {
  const ComparisonRow({required this.key, required this.label, required this.current, required this.plans});
  final String key;
  final String label;
  final bool current;

  /// plan code → included
  final Map<String, bool> plans;
}

/// Module × (current plan, other plans) matrix: rows any plan includes.
List<ComparisonRow> comparisonRows(PlanDetails d) {
  final current = {
    for (final r in d.modules)
      if (r.included) r.key
  };
  if (!d.hasPlan) current.addAll(d.enabledModules);
  return [
    for (final r in d.modules)
      if (current.contains(r.key) || d.otherPlans.any((p) => p.modules.contains(r.key)))
        ComparisonRow(
          key: r.key,
          label: r.label,
          current: current.contains(r.key),
          plans: {for (final p in d.otherPlans) p.code: p.modules.contains(r.key)},
        ),
  ];
}

/// Labels for module keys, from the rows the server sent.
List<String> moduleLabels(PlanDetails d, List<String> keys) {
  final byKey = {for (final r in d.modules) r.key: r.label};
  return [for (final k in keys) byKey[k] ?? k];
}

String periodLabel(String period) => period == 'yearly' ? 'Yearly' : (period == 'monthly' ? 'Monthly' : 'Not set');

/// GST text web appends to a price: "(GST incl.)" or "+ 18% GST".
String gstSuffix(bool inclusive, String rate) {
  if (inclusive) return ' (GST incl.)';
  final n = double.tryParse(rate);
  final shown = n == null ? rate : (n == n.truncateToDouble() ? n.toInt().toString() : '$n');
  return ' + $shown% GST';
}
