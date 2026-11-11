import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../dashboard/data/models/employee_leave_breakdown.dart';
import '../../../leave/domain/entities/leave_entity.dart';

// Employee Profile → Leave → Monthly view. Ports the web's
// components/leave/MonthlyLeaveStatement.tsx (MonthlyLeaveStatement,
// MonthlyCreditsTable) and the display helpers in lib/leaveStatement.ts.
// Every figure is the backend's (GET /leave/stats/?employee_id=&year= →
// balances[].statement, built by services_monthly_statement.statement_payload);
// these helpers only choose what to show. Nothing is calculated here: no
// expiry, carry-forward or balances.

// ── Display helpers (web lib/leaveStatement.ts) ─────────────────────────────

enum StatementTone { normal, error, strong }

class StatementLine {
  const StatementLine(this.key, this.label, this.value, [this.tone = StatementTone.normal]);
  final String key;
  final String label;
  final double value;
  final StatementTone tone;
}

/// Web monthLines: the lines a month card shows. Expiry only exists for
/// no-carry months; "Carried in" and "Pending" only when non-zero.
List<StatementLine> statementMonthLines(LeaveStatementMonth m) => [
      if (m.carriedIn != 0) StatementLine('carried_in', 'Carried in', m.carriedIn),
      StatementLine('credit', 'Credited', m.credit),
      StatementLine('used', 'Used', m.used),
      if (m.pending != 0) StatementLine('pending', 'Pending', m.pending),
      if (m.carryOff)
        StatementLine('expired', 'Expired', m.expired, m.expired != 0 ? StatementTone.error : StatementTone.normal),
      StatementLine('closing', 'Balance', m.closing, StatementTone.strong),
    ];

/// Web scheduleChip.
String statementScheduleChip(LeaveStatement stmt) => stmt.monthlyCarryForward == false
    ? 'Monthly · unused credit expires at month end'
    : 'Monthly · unused credit carries forward';

// en-IN short month names, as web's toLocaleDateString("en-IN") prints them.
const _kShortMonthsEnIn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];
const _kLongMonths = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Web statementNotes: what the statement does and doesn't contain for [year].
List<String> statementNotes(LeaveStatement stmt, int year) {
  final notes = <String>[];
  if (!stmt.months.any((m) => m.credit != 0)) notes.add('No monthly credits are recorded for $year.');
  if (stmt.opening != 0) {
    notes.add('${formatLeaveNumber(stmt.opening)} day(s) from opening balance, carry forward or adjustments are '
        'included and never expire.');
  }
  final rulesFrom = stmt.monthlyRulesFrom == null ? null : DateTime.tryParse(stmt.monthlyRulesFrom!);
  if (rulesFrom != null) {
    if (rulesFrom.year == year && rulesFrom.month > 1) {
      notes.add('The current monthly rules apply from ${rulesFrom.day} ${_kShortMonthsEnIn[rulesFrom.month - 1]} '
          "${rulesFrom.year}; earlier months aren't recalculated.");
    } else if (rulesFrom.year > year) {
      notes.add('Monthly rules apply from ${rulesFrom.year}; this year follows the balance as it was recorded.');
    }
  }
  if (stmt.usedNotItemised != 0) {
    notes.add("${formatLeaveNumber(stmt.usedNotItemised)} day(s) used aren't linked to a month (for example, an "
        'imported opening balance).');
  }
  if (!stmt.reconciled) notes.add('Month-end processing for a past month is still due; the yearly balance is current.');
  return notes;
}

/// Web splitBySchedule: rows by their policy's credit schedule. Rows whose
/// schedule is unknown (no policy) are kept apart, never guessed into a view.
({List<BalanceSummaryEntity> annual, List<BalanceSummaryEntity> monthly, List<BalanceSummaryEntity> unclassified})
    splitBySchedule(List<BalanceSummaryEntity> rows) => (
          annual: rows.where((r) => r.creditSchedule == 'annual').toList(),
          monthly: rows.where((r) => r.creditSchedule == 'monthly').toList(),
          unclassified: rows.where((r) => r.creditSchedule != 'annual' && r.creditSchedule != 'monthly').toList(),
        );

/// Web defaultMonth: the current month for this year, December for a past
/// year, January for a future one.
int defaultStatementMonth(int year, [DateTime? today]) {
  final now = today ?? DateTime.now();
  if (year < now.year) return 12;
  if (year > now.year) return 1;
  return now.month;
}

/// Web monthOf.
LeaveStatementMonth? statementMonthOf(LeaveStatement? stmt, int month) =>
    stmt?.months.where((m) => m.month == month).firstOrNull;

/// Web monthOptions label: en-IN "month: long, year: numeric" ("October 2026").
String statementMonthOptionLabel(int year, int month) => '${_kLongMonths[month - 1]} $year';

/// Web's `num(v)` in MonthlyCreditsTable: "—" for zero.
String _num(double v) => v != 0 ? formatLeaveNumber(v) : '—';

// ── Monthly Leave Credits table (web MonthlyCreditsTable) ───────────────────

class MonthlyCreditsRow {
  const MonthlyCreditsRow(
      {required this.leaveType, required this.label, required this.month, required this.hasStatement});
  final String leaveType;
  final String label;
  final LeaveStatementMonth? month;
  final bool hasStatement;
}

class MonthlyCreditsTable extends StatelessWidget {
  const MonthlyCreditsTable({
    super.key,
    required this.rows,
    required this.year,
    required this.month,
    required this.onMonth,
  });

  final List<MonthlyCreditsRow> rows;
  final int year;
  final int month;
  final ValueChanged<int> onMonth;

  @override
  Widget build(BuildContext context) {
    final head =
        AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600);
    final body = AppTextStyles.bodySmall.copyWith(fontSize: 12, color: AppColors.textPrimary);
    final muted = body.copyWith(color: AppColors.textSecondary);
    Widget cell(String t, {TextStyle? style, bool left = false, double width = _kFigureW, Key? key}) => SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(t, key: key, textAlign: left ? TextAlign.left : TextAlign.right, style: style ?? body),
          ),
        );

    return _Card(
      key: const Key('monthly-credits-table'),
      header: Row(
        children: [
          Icon(Icons.tune, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text('Monthly Leave Credits', style: AppTextStyles.label)),
          Semantics(
            label: 'Month',
            child: DropdownButton<int>(
              key: const Key('monthly-credits-month'),
              value: month,
              isDense: true,
              underline: const SizedBox.shrink(),
              style: body,
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(value: m, child: Text(statementMonthOptionLabel(year, m))),
              ],
              onChanged: (v) {
                if (v != null) onMonth(v);
              },
            ),
          ),
        ],
      ),
      // Web: a horizontally scrolling table. A message row spans the six
      // figure columns there; here it is kept within the visible width so it
      // wraps instead of running off-screen.
      child: LayoutBuilder(builder: (context, c) {
        final messageW = (c.maxWidth - _kLabelW).clamp(120.0, _kFigureW * 6);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: AppColors.backgroundLow,
                  child: Row(children: [
                    cell('Leave Type', style: head, left: true, width: _kLabelW),
                    cell('Carried in', style: head),
                    cell('Credited', style: head),
                    cell('Used', style: head),
                    cell('Pending', style: head),
                    cell('Expired', style: head),
                    cell('Balance', style: head),
                  ]),
                ),
                for (final r in rows)
                  Container(
                    key: ValueKey('monthly-credits-row-${r.leaveType}'),
                    decoration: _rowDeco,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      cell(r.label, style: body.copyWith(fontWeight: FontWeight.w600), left: true, width: _kLabelW),
                      if (!r.hasStatement || r.month == null)
                        // Web: one cell spanning the six figure columns.
                        cell(
                          !r.hasStatement
                              ? "Monthly breakdown isn't available to you for this employee."
                              : 'Nothing recorded for this month in $year.',
                          style: muted,
                          left: true,
                          width: messageW,
                          key: Key('monthly-credits-message-${r.leaveType}'),
                        )
                      else ...[
                        cell(_num(r.month!.carriedIn)),
                        cell(_num(r.month!.credit)),
                        cell(_num(r.month!.used)),
                        cell(_num(r.month!.pending)),
                        cell(r.month!.carryOff ? _num(r.month!.expired) : 'n/a',
                            style: r.month!.expired != 0 ? body.copyWith(color: AppColors.error) : null),
                        cell(formatLeaveNumber(r.month!.closing), style: body.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ]),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

const _kLabelW = 130.0;
const _kFigureW = 76.0;

BoxDecoration get _rowDeco => BoxDecoration(border: Border(top: BorderSide(color: AppColors.border)));

// ── Statement card (web MonthlyLeaveStatement) ──────────────────────────────

class MonthlyLeaveStatementCard extends StatefulWidget {
  const MonthlyLeaveStatementCard({
    super.key,
    required this.leaveType,
    required this.label,
    required this.year,
    required this.stmt,
    required this.total,
    required this.used,
    required this.available,
    this.defaultOpen = true,
  });

  final String leaveType;
  final String label;
  final int year;
  final LeaveStatement stmt;
  final double total;
  final double used;
  final double available;
  final bool defaultOpen;

  @override
  State<MonthlyLeaveStatementCard> createState() => _MonthlyLeaveStatementCardState();
}

class _MonthlyLeaveStatementCardState extends State<MonthlyLeaveStatementCard> {
  late bool _open = widget.defaultOpen;

  @override
  Widget build(BuildContext context) {
    final stmt = widget.stmt;
    final notes = statementNotes(stmt, widget.year);
    final variant = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary);
    final t = widget.leaveType;

    return _Card(
      key: Key('leave-statement-$t'),
      header: Semantics(
        button: true,
        expanded: _open,
        child: InkWell(
          key: Key('leave-statement-toggle-$t'),
          onTap: () => setState(() => _open = !_open),
          child: Row(
            children: [
              Icon(Icons.event_note_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.label} — ${widget.year}', style: AppTextStyles.label),
                    const SizedBox(height: 2),
                    Text(statementScheduleChip(stmt), style: variant),
                  ],
                ),
              ),
              Icon(_open ? Icons.expand_more : Icons.chevron_right, size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
      child: !_open
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final n in notes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(Icons.info_outline, size: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 4),
                          Expanded(child: Text(n, style: variant)),
                        ],
                      ),
                    ),
                  if (stmt.months.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('No months to show for ${widget.year} yet.',
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 13, color: AppColors.textSecondary)),
                    )
                  else
                    LayoutBuilder(builder: (context, c) {
                      // Web: grid repeat(auto-fill, minmax(150px, 1fr)), gap 10.
                      final cols = ((c.maxWidth + 10) / 160).floor().clamp(1, 12);
                      final w = (c.maxWidth - 10 * (cols - 1)) / cols;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [for (final m in stmt.months) SizedBox(width: w, child: _MonthCard(m: m))],
                      );
                    }),
                  const SizedBox(height: 12),
                  _YearlyFooter(
                    year: widget.year,
                    stmt: stmt,
                    total: widget.total,
                    used: widget.used,
                    available: widget.available,
                  ),
                ],
              ),
            ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.m});
  final LeaveStatementMonth m;

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.caption.copyWith(fontSize: 12, height: 1.7, color: AppColors.textSecondary);
    return Container(
      key: ValueKey('leave-statement-month-${m.month}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(TextSpan(
            style: AppTextStyles.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700),
            children: [
              TextSpan(text: m.label),
              if (!m.closed)
                TextSpan(
                  text: '  open',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.primary),
                ),
            ],
          )),
          const SizedBox(height: 6),
          for (final line in statementMonthLines(m))
            Container(
              key: ValueKey('leave-statement-line-${m.month}-${line.key}'),
              margin: EdgeInsets.only(top: line.key == 'closing' ? 4 : 0),
              padding: EdgeInsets.only(top: line.key == 'closing' ? 4 : 0),
              decoration: line.key == 'closing'
                  ? BoxDecoration(border: Border(top: BorderSide(color: AppColors.border)))
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Text(line.label,
                        style: base.copyWith(
                          color: line.tone == StatementTone.error ? AppColors.error : null,
                          fontWeight: line.tone == StatementTone.strong ? FontWeight.w700 : null,
                        )),
                  ),
                  Text(formatLeaveNumber(line.value),
                      style: base.copyWith(
                        color: line.tone == StatementTone.error
                            ? AppColors.error
                            : line.tone == StatementTone.strong
                                ? AppColors.textPrimary
                                : null,
                        fontWeight: line.tone == StatementTone.strong ? FontWeight.w700 : null,
                      )),
                ],
              ),
            ),
          if (m.showUsableThisMonthOnly)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${formatLeaveNumber(m.creditLeft)} usable this month only',
                  style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: AppColors.warning)),
            ),
        ],
      ),
    );
  }
}

class _YearlyFooter extends StatelessWidget {
  const _YearlyFooter({
    required this.year,
    required this.stmt,
    required this.total,
    required this.used,
    required this.available,
  });
  final int year;
  final LeaveStatement stmt;
  final double total;
  final double used;
  final double available;

  @override
  Widget build(BuildContext context) {
    const bold = TextStyle(fontWeight: FontWeight.w700);
    final expired = stmt.totalExpired ?? 0;
    return Container(
      key: const Key('leave-statement-footer'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.backgroundLow, borderRadius: BorderRadius.circular(8)),
      child: Text.rich(TextSpan(
        style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5, color: AppColors.textPrimary),
        children: [
          TextSpan(text: 'Yearly balance $year:', style: bold),
          TextSpan(
            text: ' credited ${formatLeaveNumber(stmt.totalCredited ?? total)}'
                '${expired != 0 ? ', expired ${formatLeaveNumber(expired)}' : ''}'
                ', total ${formatLeaveNumber(total)}, used ${formatLeaveNumber(used)}, ',
          ),
          TextSpan(text: 'available ${formatLeaveNumber(available)}', style: bold),
          TextSpan(text: '${stmt.totalPending != 0 ? ' (${formatLeaveNumber(stmt.totalPending)} pending)' : ''}.'),
        ],
      )),
    );
  }
}

/// Web "card" + "card-header": a bordered surface with a header row and an
/// optional body under a divider.
class _Card extends StatelessWidget {
  const _Card({super.key, required this.header, this.child});
  final Widget header;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 10, 10, 10), child: header),
          if (child != null) ...[Divider(height: 1, color: AppColors.border), child!],
        ],
      ),
    );
  }
}
