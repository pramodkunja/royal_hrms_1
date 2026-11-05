import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/employee_dashboard_models.dart';

// Web: EmpLeaveBalances.tsx → MonthlyBreakdown / StatementTable. A collapsed
// "Month-by-month — <year>" section under the leave balances, for leave types
// that have something to show month by month. The months are recorded
// movements, not month-end balances (except for a monthly-credited type's
// statement); the yearly available balance stays the figure leave
// applications use. Labels, order and figures are the server's; nothing is
// shown for types without monthly data.

class LeaveMonthlyBreakdownSection extends StatefulWidget {
  const LeaveMonthlyBreakdownSection({
    super.key,
    required this.balances,
    required this.year,
    required this.labelFor,
  });

  final List<EmployeeLeaveBalance> balances;
  final int year;
  final String Function(EmployeeLeaveBalance) labelFor;

  @override
  State<LeaveMonthlyBreakdownSection> createState() => _LeaveMonthlyBreakdownSectionState();
}

class _LeaveMonthlyBreakdownSectionState extends State<LeaveMonthlyBreakdownSection> {
  bool _open = false;
  String _selected = '';

  @override
  Widget build(BuildContext context) {
    final types = widget.balances.where((b) => b.hasMonthlyBreakdown).toList();
    if (types.isEmpty) return const SizedBox.shrink();
    final current = types.firstWhere((t) => t.leaveType == _selected, orElse: () => types.first);
    final notItemised = current.monthly?.usedNotItemised ?? 0;
    final stmt = current.statement;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Divider(height: 1, color: AppColors.border),
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            key: const Key('leave-breakdown-toggle'),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Month-by-month — ${widget.year}',
                        style: AppTextStyles.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                  Icon(_open ? Icons.expand_more : Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
        if (_open) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in types)
                ChoiceChip(
                  key: Key('leave-breakdown-type-${t.leaveType}'),
                  label: Text(widget.labelFor(t), style: const TextStyle(fontSize: 11.5)),
                  selected: t.leaveType == current.leaveType,
                  onSelected: (_) => setState(() => _selected = t.leaveType),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          _Note(current.scheduleLabel, key: const Key('leave-schedule-label')),
          const SizedBox(height: 8),
          if (stmt != null) ...[
            if (stmt.opening != 0) ...[
              _Note(
                'Opening ${formatLeaveNumber(stmt.opening)} day(s) (opening balance, carried forward and '
                'adjustments) never expire.',
                key: const Key('leave-opening-note'),
              ),
              const SizedBox(height: 8),
            ],
            _StatementTable(stmt: stmt),
          ] else
            _MonthlyTable(months: current.monthly?.months ?? const []),
          if (notItemised > 0) ...[
            const SizedBox(height: 8),
            _Note(
              "${formatLeaveNumber(notItemised)} day(s) used aren't linked to a specific month (for example, leave "
              'included in an imported opening balance).',
              key: const Key('leave-not-itemised-note'),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            key: const Key('leave-yearly-balance'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.backgroundLow, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5), children: [
                    TextSpan(
                        text: 'Yearly balance ${widget.year}:', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: ' total ${formatLeaveNumber(current.totalDays)}, '
                            'used ${formatLeaveNumber(current.usedDays)}, '),
                    TextSpan(
                        text: 'available ${formatLeaveNumber(current.remaining)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: '.'),
                  ]),
                ),
                const SizedBox(height: 2),
                Text(
                  stmt != null
                      ? (stmt.reconciled
                          ? 'The month-end figures add up to this yearly balance (after pending leave).'
                          : 'Month-end processing for a past month is still due; the yearly figure is current.')
                      : "The months show what was recorded each month. Month-end balances aren't calculated for this "
                          'leave type, so your available leave is the yearly figure.',
                  style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary));
}

TextStyle get _head => AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary);
TextStyle get _body => AppTextStyles.bodySmall.copyWith(fontSize: 12, color: AppColors.textPrimary);

Widget _cell(String text, {TextStyle? style, bool left = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(text, textAlign: left ? TextAlign.left : TextAlign.right, style: style ?? _body),
    );

/// Bordered, horizontally scrollable table (web: overflowX auto).
Widget _frame({required Key key, required List<TableRow> rows}) => Container(
      key: key,
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: rows,
        ),
      ),
    );

BoxDecoration get _headDeco => BoxDecoration(color: AppColors.backgroundLow);
BoxDecoration get _rowDeco => BoxDecoration(border: Border(top: BorderSide(color: AppColors.border)));

/// Monthly-credited types: carried in, credit, used, pending, expired and
/// available at month end, as the server computed them.
class _StatementTable extends StatelessWidget {
  const _StatementTable({required this.stmt});
  final LeaveStatement stmt;

  @override
  Widget build(BuildContext context) {
    return _frame(
      key: const Key('leave-statement-table'),
      rows: [
        TableRow(decoration: _headDeco, children: [
          _cell('Month', style: _head, left: true),
          _cell('Carried in', style: _head),
          _cell('Credit', style: _head),
          _cell('Used', style: _head),
          _cell('Pending', style: _head),
          _cell('Expired', style: _head),
          _cell('Available at month end', style: _head),
        ]),
        for (final m in stmt.months)
          TableRow(key: ValueKey('leave-statement-month-${m.month}'), decoration: _rowDeco, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.label, style: _body),
                  if (m.showUsableThisMonthOnly)
                    Text('${formatLeaveNumber(m.creditLeft)} usable this month only',
                        style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: AppColors.warning)),
                ],
              ),
            ),
            _cell(leaveCell(m.carriedIn)),
            _cell(leaveCell(m.credit)),
            _cell(leaveCell(m.used)),
            _cell(leaveCell(m.pending)),
            _cell(leaveCell(m.expired), style: m.expired != 0 ? _body.copyWith(color: AppColors.error) : null),
            _cell(formatLeaveNumber(m.closing), style: _body.copyWith(fontWeight: FontWeight.w600)),
          ]),
      ],
    );
  }
}

/// Other types: what was recorded each month, with a total row.
class _MonthlyTable extends StatelessWidget {
  const _MonthlyTable({required this.months});
  final List<LeaveMonthRow> months;

  @override
  Widget build(BuildContext context) {
    final totals = leaveMonthTotals(months);
    final bold = _body.copyWith(fontWeight: FontWeight.w700);
    return _frame(
      key: const Key('leave-monthly-table'),
      rows: [
        TableRow(decoration: _headDeco, children: [
          _cell('Month', style: _head, left: true),
          _cell('Monthly credit', style: _head),
          _cell('Other adjustments', style: _head),
          _cell('Leave used', style: _head),
        ]),
        for (final m in months)
          TableRow(key: ValueKey('leave-monthly-month-${m.month}'), decoration: _rowDeco, children: [
            _cell(m.label, left: true),
            _cell(leaveCell(m.monthlyCredit)),
            _cell(m.otherAdjustments != 0 ? signedLeaveNumber(m.otherAdjustments) : '—'),
            _cell(leaveCell(m.used)),
          ]),
        TableRow(key: const ValueKey('leave-monthly-total'), decoration: _rowDeco, children: [
          _cell('Total recorded', style: bold, left: true),
          _cell(formatLeaveNumber(totals.monthlyCredit), style: bold),
          _cell(signedLeaveNumber(totals.otherAdjustments), style: bold),
          _cell(formatLeaveNumber(totals.used), style: bold),
        ]),
      ],
    );
  }
}
