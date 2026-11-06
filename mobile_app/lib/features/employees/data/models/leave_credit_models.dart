// Employee Profile → Leave → Manage Leave Credits, as web LeaveCreditsSection.tsx
// reads GET /leave/credits/<employee_id>/?year=&leave_type= (backend
// LeaveCreditOverviewView; amounts are floats from services_leave_credit._f).

double _d(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _i(Object? v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String? _s(Object? v) => v is String && v.isNotEmpty ? v : null;

List<Map<String, dynamic>> _maps(Object? v) =>
    v is List ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];

/// Web `signed(n)`: `+2`, `-1.5`, `0`. Whole numbers drop the decimal, as JS does.
String signedDays(num n) => n > 0 ? '+${creditNum(n)}' : creditNum(n);

/// A number as JS `String(n)` prints it: `2`, `1.5`, `-0.5`.
String creditNum(num n) {
  final v = n.toDouble();
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

class LeaveCreditRow {
  const LeaveCreditRow({
    required this.leaveType,
    required this.label,
    required this.openingOrAllocated,
    required this.carriedForward,
    required this.manualAdjustments,
    required this.totalCredits,
    required this.used,
    required this.pending,
    required this.remaining,
    this.creditSchedule,
  });

  final String leaveType;
  final String label;
  final double openingOrAllocated;
  final double carriedForward;
  final double manualAdjustments;
  final double totalCredits;
  final double used;
  final double pending;
  final double remaining;
  final String? creditSchedule;

  factory LeaveCreditRow.fromJson(Map<String, dynamic> j) {
    final type = j['leave_type']?.toString() ?? '';
    return LeaveCreditRow(
      leaveType: type,
      label: _s(j['leave_type_label']) ?? type,
      openingOrAllocated: _d(j['opening_or_allocated']),
      carriedForward: _d(j['carried_forward']),
      manualAdjustments: _d(j['manual_adjustments']),
      totalCredits: _d(j['total_credits']),
      used: _d(j['used']),
      pending: _d(j['pending']),
      remaining: _d(j['remaining']),
      creditSchedule: _s(j['credit_schedule']),
    );
  }
}

class LeaveCreditTxn {
  const LeaveCreditTxn({
    required this.id,
    required this.leaveType,
    required this.txnType,
    required this.amount,
    required this.totalAfter,
    required this.reason,
    required this.createdAt,
    required this.canReverse,
    this.createdByName,
    this.reverses,
    this.reversedBy,
  });

  final String id;
  final String leaveType;
  final String txnType;
  final double amount;
  final double totalAfter;
  final String reason;
  final String createdAt;
  final String? createdByName;
  final String? reverses;
  final String? reversedBy;

  /// Exactly the server's flag (an un-reversed adjustment); web adds the
  /// year check on top, see [LeaveCreditOverview.canEditYear].
  final bool canReverse;

  bool get isReversal => txnType == 'reversal';

  factory LeaveCreditTxn.fromJson(Map<String, dynamic> j) => LeaveCreditTxn(
        id: j['id']?.toString() ?? '',
        leaveType: j['leave_type']?.toString() ?? '',
        txnType: j['txn_type']?.toString() ?? '',
        amount: _d(j['amount']),
        totalAfter: _d(j['total_after']),
        reason: j['reason']?.toString() ?? '',
        createdAt: j['created_at']?.toString() ?? '',
        createdByName: _s(j['created_by_name']),
        reverses: _s(j['reverses']?.toString()),
        reversedBy: _s(j['reversed_by']?.toString()),
        canReverse: j['can_reverse'] == true,
      );
}

class LeaveCreditMonth {
  const LeaveCreditMonth(
      {required this.month, required this.label, required this.creditAdjustments, required this.used});
  final int month;
  final String label;
  final double creditAdjustments;
  final double used;

  factory LeaveCreditMonth.fromJson(Map<String, dynamic> j) => LeaveCreditMonth(
        month: _i(j['month'], 0),
        label: j['label']?.toString() ?? '',
        creditAdjustments: _d(j['credit_adjustments']),
        used: _d(j['used']),
      );
}

class LeaveCreditMonthly {
  const LeaveCreditMonthly({
    required this.label,
    required this.months,
    required this.adjustmentsOutsideYear,
    required this.usedInNextYearMonths,
    required this.usedNotItemised,
    required this.totalCreditAdjustments,
    required this.totalUsed,
    required this.approximatedRequests,
  });

  final String label;
  final List<LeaveCreditMonth> months;
  final double adjustmentsOutsideYear;
  final double usedInNextYearMonths;
  final double usedNotItemised;
  final double totalCreditAdjustments;
  final double totalUsed;
  final int approximatedRequests;

  factory LeaveCreditMonthly.fromJson(Map<String, dynamic> j) => LeaveCreditMonthly(
        label: j['leave_type_label']?.toString() ?? '',
        months: _maps(j['months']).map(LeaveCreditMonth.fromJson).toList(),
        adjustmentsOutsideYear: _d(j['credit_adjustments_outside_year']),
        usedInNextYearMonths: _d(j['used_in_next_year_months']),
        usedNotItemised: _d(j['used_not_itemised']),
        totalCreditAdjustments: _d(j['total_credit_adjustments']),
        totalUsed: _d(j['total_used']),
        approximatedRequests: _i(j['approximated_requests'], 0),
      );
}

class LeaveCreditTypeOption {
  const LeaveCreditTypeOption({required this.value, required this.label, this.creditSchedule});
  final String value;
  final String label;
  final String? creditSchedule;

  factory LeaveCreditTypeOption.fromJson(Map<String, dynamic> j) {
    final value = j['value']?.toString() ?? '';
    return LeaveCreditTypeOption(
      value: value,
      label: _s(j['label']) ?? value,
      creditSchedule: _s(j['credit_schedule']),
    );
  }
}

class LeaveCreditOverview {
  const LeaveCreditOverview({
    required this.employeeId,
    required this.fullName,
    required this.year,
    required this.currentYear,
    required this.summaries,
    required this.transactions,
    required this.assignable,
    this.leaveType,
    this.monthly,
  });

  final String employeeId;
  final String fullName;
  final int year;
  final int currentYear;
  final List<LeaveCreditRow> summaries;
  final String? leaveType;
  final LeaveCreditMonthly? monthly;
  final List<LeaveCreditTxn> transactions;
  final List<LeaveCreditTypeOption> assignable;

  /// Web `canEditYear`: adjustments and reversals only for the current or a past year.
  bool get canEditYear => year <= currentYear;

  factory LeaveCreditOverview.fromJson(Map<String, dynamic> j, {required int requestedYear}) {
    final emp = j['employee'] is Map ? Map<String, dynamic>.from(j['employee'] as Map) : const <String, dynamic>{};
    final year = _i(j['year'], requestedYear);
    final monthly = j['monthly'];
    return LeaveCreditOverview(
      employeeId: emp['employee_id']?.toString() ?? '',
      fullName: emp['full_name']?.toString() ?? '',
      year: year,
      currentYear: _i(j['current_year'], year),
      summaries: _maps(j['summaries']).map(LeaveCreditRow.fromJson).toList(),
      leaveType: _s(j['leave_type']),
      monthly: monthly is Map ? LeaveCreditMonthly.fromJson(Map<String, dynamic>.from(monthly)) : null,
      transactions: _maps(j['transactions']).map(LeaveCreditTxn.fromJson).toList(),
      assignable: _maps(j['assignable_leave_types']).map(LeaveCreditTypeOption.fromJson).toList(),
    );
  }
}
