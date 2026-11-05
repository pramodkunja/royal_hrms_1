// Month-by-month leave breakdown on the Employee dashboard — web
// components/dashboard/employee/EmpLeaveBalances.tsx (MonthlyBreakdown,
// StatementTable) and lib/leaveBreakdown.ts, from the fields production
// EmployeeLeaveBalanceView (apps/dashboard/views/overview.py) adds to each
// balance of GET /dashboard/employee/leave-balances/:
//
//   leave_type_label, credit_schedule ("annual" | "monthly"),
//   monthly_carry_forward (bool),
//   monthly:   {months: [{month, label, monthly_credit, other_adjustments,
//               used}], used_not_itemised}  — recorded movements per month
//               (_monthly_breakdown; empty for LWP),
//   statement: null, or for monthly-credited types the full statement
//               (services_monthly_statement.statement_payload): opening,
//               adjustments, used_not_itemised, months [{month, label,
//               carry_off, closed, carried_in, credit, used, pending,
//               expired, credit_left, closing}], total_pending, reconciled,
//               total_credited, total_expired, monthly_carry_forward,
//               monthly_rules_from.
//
// Month labels ("Oct 2026") and the order of months come from the server and
// are shown as sent, as on web. Every figure is the server's; the only
// arithmetic here is web's own (monthTotals, rounded to one decimal).

double _d(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0;
  return 0;
}

int _i(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? 0;
  return 0;
}

bool _b(Object? v) => v == true;

List<Map<String, dynamic>> _rows(Object? v) =>
    (v is List ? v : const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

/// One month of recorded movements (`monthly.months[]`).
class LeaveMonthRow {
  final int month;
  final String label;
  final double monthlyCredit;
  final double otherAdjustments;
  final double used;

  const LeaveMonthRow({
    required this.month,
    required this.label,
    required this.monthlyCredit,
    required this.otherAdjustments,
    required this.used,
  });

  factory LeaveMonthRow.fromJson(Map<String, dynamic> json) => LeaveMonthRow(
        month: _i(json['month']),
        label: '${json['label'] ?? ''}',
        monthlyCredit: _d(json['monthly_credit']),
        otherAdjustments: _d(json['other_adjustments']),
        used: _d(json['used']),
      );
}

/// `monthly`: recorded movements by month, plus leave used that isn't tied
/// to a month (e.g. inside an imported opening balance).
class LeaveMonthlyBreakdown {
  final List<LeaveMonthRow> months;
  final double usedNotItemised;

  const LeaveMonthlyBreakdown({this.months = const [], this.usedNotItemised = 0});

  /// Null when absent or not an object (older cached payloads).
  static LeaveMonthlyBreakdown? fromJson(Object? json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    return LeaveMonthlyBreakdown(
      months: _rows(m['months']).map(LeaveMonthRow.fromJson).toList(),
      usedNotItemised: _d(m['used_not_itemised']),
    );
  }
}

/// One month of a monthly-credited type's statement (`statement.months[]`).
class LeaveStatementMonth {
  final int month;
  final String label;

  /// This month's credit expires if unused (no carry forward).
  final bool carryOff;
  final bool closed;
  final double carriedIn;
  final double credit;
  final double used;
  final double pending;
  final double expired;

  /// This month's credit still usable (open no-carry months).
  final double creditLeft;
  final double closing;

  const LeaveStatementMonth({
    required this.month,
    required this.label,
    required this.carryOff,
    required this.closed,
    required this.carriedIn,
    required this.credit,
    required this.used,
    required this.pending,
    required this.expired,
    required this.creditLeft,
    required this.closing,
  });

  factory LeaveStatementMonth.fromJson(Map<String, dynamic> json) => LeaveStatementMonth(
        month: _i(json['month']),
        label: '${json['label'] ?? ''}',
        carryOff: _b(json['carry_off']),
        closed: _b(json['closed']),
        carriedIn: _d(json['carried_in']),
        credit: _d(json['credit']),
        used: _d(json['used']),
        pending: _d(json['pending']),
        expired: _d(json['expired']),
        creditLeft: _d(json['credit_left']),
        closing: _d(json['closing']),
      );

  /// Web: "<credit_left> usable this month only".
  bool get showUsableThisMonthOnly => carryOff && !closed && creditLeft > 0;
}

/// `statement` for monthly-credited leave types (null otherwise).
class LeaveStatement {
  /// Opening balance, carried forward and adjustments — never expire.
  final double opening;
  final double adjustments;
  final double usedNotItemised;
  final List<LeaveStatementMonth> months;
  final double totalPending;
  final bool reconciled;
  final double? totalCredited;
  final double? totalExpired;
  final bool? monthlyCarryForward;
  final String? monthlyRulesFrom;

  const LeaveStatement({
    required this.opening,
    required this.adjustments,
    required this.usedNotItemised,
    required this.months,
    required this.totalPending,
    required this.reconciled,
    this.totalCredited,
    this.totalExpired,
    this.monthlyCarryForward,
    this.monthlyRulesFrom,
  });

  /// Null when absent, null or not an object.
  static LeaveStatement? fromJson(Object? json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    return LeaveStatement(
      opening: _d(m['opening']),
      adjustments: _d(m['adjustments']),
      usedNotItemised: _d(m['used_not_itemised']),
      months: _rows(m['months']).map(LeaveStatementMonth.fromJson).toList(),
      totalPending: _d(m['total_pending']),
      reconciled: _b(m['reconciled']),
      totalCredited: m['total_credited'] is num ? (m['total_credited'] as num).toDouble() : null,
      totalExpired: m['total_expired'] is num ? (m['total_expired'] as num).toDouble() : null,
      monthlyCarryForward: m['monthly_carry_forward'] is bool ? m['monthly_carry_forward'] as bool : null,
      monthlyRulesFrom: m['monthly_rules_from'] as String?,
    );
  }
}

// ── Helpers ported from web lib/leaveBreakdown.ts ───────────────────────────

double _round1(double n) => (n * 10).roundToDouble() / 10;

/// Web monthTotals: column totals of the recorded months, one decimal.
({double monthlyCredit, double otherAdjustments, double used}) leaveMonthTotals(List<LeaveMonthRow> months) {
  var credit = 0.0, adj = 0.0, used = 0.0;
  for (final m in months) {
    credit = _round1(credit + m.monthlyCredit);
    adj = _round1(adj + m.otherAdjustments);
    used = _round1(used + m.used);
  }
  return (monthlyCredit: credit, otherAdjustments: adj, used: used);
}

/// A number as web prints it: "2", "1.5", "-0.5" (no trailing zeros).
String formatLeaveNumber(double n) {
  final r = (n * 100).roundToDouble() / 100;
  if (r == r.roundToDouble()) return r.toInt().toString();
  var s = r.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Web signed: "+1.5", "-2", "0".
String signedLeaveNumber(double n) => n > 0 ? '+${formatLeaveNumber(n)}' : formatLeaveNumber(n);

/// Web's table cells show "—" for zero.
String leaveCell(double n) => n == 0 ? '—' : formatLeaveNumber(n);
