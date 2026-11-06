// Settings → Leave Policy → Monthly Leave Management — web
// frontend/lib/monthlyLeave.ts, over the /leave/monthly-credits/ endpoints
// (apps/hrms/views/leave_credits.py, services_monthly_leave.py). The backend
// (set_monthly_credit) is the source of truth for every rule; the helpers
// here only give the same early feedback web does.

import '../../../auth/domain/entities/user_entity.dart';

const kMaxMonthlyCredit = 31;

/// Import file limit (web MAX_FILE_BYTES, server _LEAVE_IMPORT_MAX_BYTES).
const kMonthlyImportMaxBytes = 5 * 1024 * 1024;

/// Employees per checklist page (web PAGE_SIZE).
const kMonthlyEmployeePageSize = 50;

const kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Web usePermission("leave.approve"): superuser, or the permission itself.
bool canManageMonthlyCredits(UserEntity? user) =>
    user != null && (user.isSuperuser || user.permissions.contains('leave.approve'));

/// Years HR can credit: the current calendar year and the two before it.
List<int> creditYears(DateTime today) => [today.year, today.year - 1, today.year - 2];

final _creditPattern = RegExp(r'^\d+(\.\d)?$');

/// Web validateMonthlyCredit: an error message, or null when acceptable.
String? validateMonthlyCredit(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return "Enter a monthly leave credit (0 removes the month's credit).";
  if (!_creditPattern.hasMatch(text)) {
    return text.startsWith('-')
        ? 'Monthly leave credit cannot be negative.'
        : 'Use a number with at most one decimal place, e.g. 1 or 1.5.';
  }
  if (double.parse(text) > kMaxMonthlyCredit) return 'Monthly leave credit cannot exceed $kMaxMonthlyCredit days.';
  return null;
}

double _round1(num n) => (n * 10).roundToDouble() / 10;

/// A number as JavaScript prints it: 1 → "1", 1.5 → "1.5", -2 → "-2".
String fmtNum(num n) {
  if (n == n.roundToDouble()) return n.toInt().toString();
  return n.toString();
}

/// Web describeChange: confirmation text for previous → next days.
String describeChange(num previous, num next) {
  final delta = _round1(next - previous);
  if (delta == 0) return 'No change.';
  if (next == 0) {
    return "Removes this month's credit: ${fmtNum(previous)} day(s) will be taken off the employee's balance.";
  }
  return delta > 0
      ? "Changes ${fmtNum(previous)} → ${fmtNum(next)} day(s): ${fmtNum(delta)} day(s) will be added to the employee's balance."
      : "Changes ${fmtNum(previous)} → ${fmtNum(next)} day(s): ${fmtNum(-delta)} day(s) will be taken off the employee's balance.";
}

const kMonthlyStatusLabel = {
  'new': 'New',
  'update': 'Update',
  'unchanged': 'Unchanged',
  'duplicate': 'Duplicate',
  'error': 'Error',
};

num? _num(Object? v) => v is num ? v : (v is String ? num.tryParse(v.trim()) : null);
int _int(Object? v) => _num(v)?.toInt() ?? 0;
String _str(Object? v) => v == null ? '' : '$v';
String? _optStr(Object? v) => v is String && v.isNotEmpty ? v : null;
List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e)
      ]
    : const [];

/// One row of an import / bulk preview or result.
class MonthlyImportRow {
  const MonthlyImportRow({
    required this.row,
    required this.employeeCode,
    required this.employeeName,
    required this.leaveType,
    required this.leaveTypeLabel,
    required this.credit,
    required this.previous,
    required this.delta,
    required this.status,
    required this.message,
  });

  final int row;
  final String employeeCode;
  final String? employeeName;
  final String leaveType;
  final String? leaveTypeLabel;

  /// As sent (number or text), shown as web prints it.
  final String credit;
  final num? previous;
  final num? delta;

  /// new | update | unchanged | duplicate | error (shown as sent if other).
  final String status;
  final String message;

  String get statusLabel => kMonthlyStatusLabel[status] ?? status;
  String get typeLabel => leaveTypeLabel ?? leaveType;
  String get previousText => previous == null ? '—' : fmtNum(previous!);
  String get deltaText => delta == null ? '—' : '${delta! > 0 ? '+' : ''}${fmtNum(delta!)}';

  factory MonthlyImportRow.fromJson(Map<String, dynamic> j) {
    final credit = j['credit'];
    return MonthlyImportRow(
      row: _int(j['row']),
      employeeCode: _str(j['employee_code']),
      employeeName: _optStr(j['employee_name']),
      leaveType: _str(j['leave_type']),
      leaveTypeLabel: _optStr(j['leave_type_label']),
      credit: credit is num ? fmtNum(credit) : _str(credit),
      previous: _num(j['previous']),
      delta: _num(j['delta']),
      status: _str(j['status']),
      message: _str(j['message']),
    );
  }
}

Map<String, num> _numMap(Object? v) => v is Map
    ? {
        for (final e in v.entries)
          if (_num(e.value) != null) '${e.key}': _num(e.value)!
      }
    : const {};

/// Preview (import) or review (bulk): nothing saved yet.
class MonthlyPlan {
  const MonthlyPlan({
    required this.year,
    required this.month,
    required this.rows,
    required this.counts,
    required this.annualEntitlements,
  });

  final int year;
  final int month;
  final List<MonthlyImportRow> rows;
  final Map<String, int> counts;
  final Map<String, num> annualEntitlements;

  int count(String status) => counts[status] ?? 0;

  /// Rows that would actually change something (web: new + update).
  int get applicable => count('new') + count('update');

  factory MonthlyPlan.fromJson(Map<String, dynamic> j) => MonthlyPlan(
        year: _int(j['year']),
        month: _int(j['month']),
        rows: _maps(j['rows']).map(MonthlyImportRow.fromJson).toList(),
        counts: {for (final e in _numMap(j['counts']).entries) e.key: e.value.toInt()},
        annualEntitlements: _numMap(j['annual_entitlements']),
      );
}

/// Applied import / bulk save.
class MonthlyApplyResult {
  const MonthlyApplyResult({
    required this.year,
    required this.month,
    required this.rows,
    required this.created,
    required this.updated,
    required this.skipped,
    required this.failed,
    required this.total,
  });

  final int year;
  final int month;
  final List<MonthlyImportRow> rows;
  final int created;
  final int updated;
  final int skipped;
  final int failed;
  final int total;

  factory MonthlyApplyResult.fromJson(Map<String, dynamic> j) {
    final s = j['summary'] is Map ? Map<String, dynamic>.from(j['summary'] as Map) : const <String, dynamic>{};
    return MonthlyApplyResult(
      year: _int(j['year']),
      month: _int(j['month']),
      rows: _maps(j['rows']).map(MonthlyImportRow.fromJson).toList(),
      created: _int(s['created']),
      updated: _int(s['updated']),
      skipped: _int(s['skipped']),
      failed: _int(s['failed']),
      total: _int(s['total']),
    );
  }
}

/// Web annualWarningTypes: new/update rows whose leave type also has an
/// annual entitlement ("Casual Leave (12 days/year)").
List<String> annualWarningTypes(List<MonthlyImportRow> rows, Map<String, num> annual) {
  final labels = <String>{};
  for (final r in rows) {
    final days = annual[r.leaveType];
    if ((r.status == 'new' || r.status == 'update') && days != null && days != 0) {
      labels.add('${r.typeLabel} (${fmtNum(days)} days/year)');
    }
  }
  return labels.toList();
}

/// One current monthly credit (assignments list).
class MonthlyAssignment {
  const MonthlyAssignment({
    required this.employeeId,
    required this.employeeName,
    required this.branch,
    required this.isActive,
    required this.leaveType,
    required this.leaveTypeLabel,
    required this.year,
    required this.month,
    required this.credit,
    required this.lastUpdated,
  });

  final String employeeId;
  final String employeeName;
  final String branch;
  final bool isActive;
  final String leaveType;
  final String leaveTypeLabel;
  final int year;
  final int month;
  final num credit;
  final String lastUpdated;

  factory MonthlyAssignment.fromJson(Map<String, dynamic> j) => MonthlyAssignment(
        employeeId: _str(j['employee_id']),
        employeeName: _str(j['employee_name']),
        branch: _str(j['branch']),
        isActive: j['is_active'] != false,
        leaveType: _str(j['leave_type']),
        leaveTypeLabel: _optStr(j['leave_type_label']) ?? _str(j['leave_type']),
        year: _int(j['year']),
        month: _int(j['month']),
        credit: _num(j['credit']) ?? 0,
        lastUpdated: _str(j['last_updated']),
      );
}

class MonthlyAssignments {
  const MonthlyAssignments({
    required this.year,
    required this.month,
    required this.assignments,
    required this.employees,
    required this.entries,
    required this.totalDays,
  });

  final int year;
  final int month;
  final List<MonthlyAssignment> assignments;
  final int employees;
  final int entries;
  final num totalDays;

  factory MonthlyAssignments.fromJson(Map<String, dynamic> j) {
    final s = j['summary'] is Map ? Map<String, dynamic>.from(j['summary'] as Map) : const <String, dynamic>{};
    return MonthlyAssignments(
      year: _int(j['year']),
      month: _int(j['month']),
      assignments: _maps(j['assignments']).map(MonthlyAssignment.fromJson).toList(),
      employees: _int(s['employees']),
      entries: _int(s['entries']),
      totalDays: _num(s['total_days']) ?? 0,
    );
  }
}

const _enInMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];

/// Web formatWhen (en-IN): "05 Nov 2026, 05:54 pm" in the viewer's zone;
/// "—" when unreadable.
String formatMonthlyWhen(String iso, {Duration? viewerOffset}) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '—';
  final t = parsed.isUtc ? (viewerOffset != null ? parsed.add(viewerOffset) : parsed.toLocal()) : parsed;
  String two(int n) => n.toString().padLeft(2, '0');
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${two(t.day)} ${_enInMonths[t.month - 1]} ${t.year}, ${two(h12)}:${two(t.minute)} ${t.hour < 12 ? 'am' : 'pm'}';
}
