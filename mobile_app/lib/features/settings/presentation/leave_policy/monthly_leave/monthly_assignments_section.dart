import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/monthly_leave_models.dart';
import 'monthly_leave_providers.dart';
import 'monthly_leave_widgets.dart';

/// Web MonthlyAssignmentsSection: the month's current credits (loaded only
/// while open, refreshed after any save), a three-figure summary and an Edit
/// action for active employees that saves through POST /leave/monthly-credits/.
class MonthlyAssignmentsSection extends ConsumerStatefulWidget {
  const MonthlyAssignmentsSection({super.key, required this.open});
  final bool open;

  @override
  ConsumerState<MonthlyAssignmentsSection> createState() => _MonthlyAssignmentsSectionState();
}

class _MonthlyAssignmentsSectionState extends ConsumerState<MonthlyAssignmentsSection> {
  late final DateTime _today = ref.read(monthlyLeaveClockProvider)();
  late int _month = _today.month;
  late int _year = _today.year;
  String? _ok;

  Future<void> _edit(MonthlyAssignment row) async {
    setState(() => _ok = null);
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      useSafeArea: true,
      builder: (_) => EditMonthlyCreditSheet(row: row),
    );
    if (message != null && mounted) setState(() => _ok = message);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink(key: Key('monthly-assignments-closed'));
    final key = (year: _year, month: _month);
    final async = ref.watch(monthlyAssignmentsProvider(key));
    final muted = AppTextStyles.bodySmall.copyWith(fontSize: 13, color: AppColors.textSecondary);
    final monthName = kMonthNames[_month - 1];

    return Column(
      key: const Key('monthly-assignments'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonthYearFields(
          keyPrefix: 'assign-',
          month: _month,
          year: _year,
          years: creditYears(_today),
          onMonth: (m) => setState(() {
            _month = m;
            _ok = null;
          }),
          onYear: (y) => setState(() {
            _year = y;
            _ok = null;
          }),
        ),
        const SizedBox(height: 12),
        if (async.valueOrNull case final data?) ...[
          _Stats(children: [
            _Stat('Employees assigned', '${data.employees}', 'unique employees'),
            _Stat('Credit entries', '${data.entries}', 'employee + leave type'),
            _Stat('Total days credited', fmtNum(data.totalDays), '$monthName $_year'),
          ]),
          const SizedBox(height: 12),
        ],
        if (_ok != null) ...[
          MonthlyAlert(key: const Key('assign-ok'), kind: MonthlyAlertKind.success, text: _ok!),
          const SizedBox(height: 8),
        ],
        async.when(
          loading: () =>
              Row(children: [monthlySpinner(), const SizedBox(width: 8), Expanded(child: Text('Loading assignments…', style: muted))]),
          error: (e, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MonthlyAlert(
                key: const Key('assign-error'),
                kind: MonthlyAlertKind.error,
                text: monthlyLeaveError(e, 'Could not load monthly leave assignments.')),
            TextButton(
              key: const Key('assign-retry'),
              style: monthlyTextStyle,
              onPressed: () => ref.invalidate(monthlyAssignmentsProvider(key)),
              child: const Text('Retry'),
            ),
          ]),
          data: (data) => data.assignments.isEmpty
              ? Text(
                  'No monthly leave assignments found for $monthName $_year. Use the import or manual entry above to add them.',
                  key: const Key('assign-empty'),
                  style: muted)
              : MonthlyCardGrid(children: [for (final a in data.assignments) _AssignmentCard(a, onEdit: () => _edit(a))]),
        ),
      ],
    );
  }
}

/// Summary figures: three across when there is room, two, or one per line;
/// widths come from the slot, never fixed.
class _Stats extends StatelessWidget {
  const _Stats({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        const gap = 8.0;
        final big = monthlyTextScale(context) > 1.3;
        final cols = c.maxWidth >= 480 && !big ? 3 : (c.maxWidth >= 290 && !big ? 2 : 1);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final child in children) SizedBox(width: w, child: child),
        ]);
      });
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.hint);
  final String label, value, hint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: AppColors.backgroundLow,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
          Text(value, key: Key('assign-stat-$label'), style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700)),
          Text(hint, style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ]),
      );
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard(this.a, {required this.onEdit});
  final MonthlyAssignment a;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final muted = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary);
    final month = kMonthNames[(a.month - 1).clamp(0, 11)];
    final edit = a.isActive
        ? OutlinedButton.icon(
            key: Key('assignment-edit-${a.employeeId}-${a.leaveType}'),
            style: monthlyOutlinedStyle,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          )
        : null;
    return Container(
      key: Key('assignment-${a.employeeId}-${a.leaveType}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${a.employeeName}${a.isActive ? '' : ' (inactive)'}',
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        Text('${a.employeeId} · ${a.branch.isEmpty ? '—' : a.branch}', style: muted),
        const SizedBox(height: 4),
        Text('${a.leaveTypeLabel} · $month ${a.year}', style: muted),
        const SizedBox(height: 8),
        Wrap(spacing: 20, runSpacing: 8, children: [
          MonthlyFigure('$month credit', '${fmtNum(a.credit)} day(s)'),
          MonthlyFigure('Last updated', formatMonthlyWhen(a.lastUpdated)),
        ]),
        if (edit != null) ...[
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) => monthlyCompact(context, c.maxWidth, narrow: 300, scale: 1.3)
                ? SizedBox(width: double.infinity, child: edit)
                : Align(alignment: Alignment.centerRight, child: edit),
          ),
        ],
      ]),
    );
  }
}

/// Web EditAssignmentModal: new value → "Review change" → Confirm. A failed
/// save returns to editing with the value kept; success closes with the
/// server's message.
class EditMonthlyCreditSheet extends ConsumerStatefulWidget {
  const EditMonthlyCreditSheet({super.key, required this.row});
  final MonthlyAssignment row;

  @override
  ConsumerState<EditMonthlyCreditSheet> createState() => _EditMonthlyCreditSheetState();
}

class _EditMonthlyCreditSheetState extends ConsumerState<EditMonthlyCreditSheet> {
  late final _ctrl = TextEditingController(text: fmtNum(widget.row.credit));
  bool _confirming = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save(num next) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final message = await ref.read(monthlyLeaveServiceProvider).setCredit(widget.row, _ctrl.text);
      if (mounted) Navigator.of(context).pop(message);
    } on MonthlyLeaveBusy {
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _confirming = false;
          _error = monthlyLeaveError(e, 'Could not save the monthly credit.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final validation = validateMonthlyCredit(_ctrl.text);
    final next = validation == null ? num.parse(_ctrl.text.trim()) : null;
    final unchanged = next == row.credit;
    final muted = AppTextStyles.bodySmall.copyWith(fontSize: 12.5, color: AppColors.textSecondary);

    return PopScope(
      canPop: !_saving,
      child: Padding(
        // Keyboard-safe: the sheet sits above the keyboard and its content scrolls.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
          key: const Key('edit-monthly-credit'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit monthly leave credit', style: AppTextStyles.h4.copyWith(fontSize: 16)),
            const SizedBox(height: 10),
            Text('${row.employeeName} · ${row.employeeId}${row.branch.isNotEmpty ? ' · ${row.branch}' : ''}',
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            Text('${row.leaveTypeLabel} · ${kMonthNames[(row.month - 1).clamp(0, 11)]} ${row.year}', style: muted),
            Text('Current monthly credit: ${fmtNum(row.credit)} day(s)', style: muted),
            if (_error != null) ...[
              const SizedBox(height: 10),
              MonthlyAlert(key: const Key('edit-error'), kind: MonthlyAlertKind.error, text: _error!),
            ],
            const SizedBox(height: 12),
            if (!_confirming)
              MonthlyField(
                label: 'New monthly leave credit (days)',
                child: TextField(
                  key: const Key('edit-credit'),
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    errorText: validation,
                    errorMaxLines: 3,
                    helperMaxLines: 3,
                    helperText: validation == null ? "0–31, one decimal place. 0 removes this month's credit." : null,
                  ),
                ),
              )
            else
              MonthlyAlert(
                key: const Key('edit-confirm-text'),
                kind: MonthlyAlertKind.info,
                text: 'Previous: ${fmtNum(row.credit)} day(s) → New: ${fmtNum(next ?? 0)} day(s)\n'
                    '${describeChange(row.credit, next ?? 0)}\n'
                    "The change is recorded in the employee's leave credit history. A reduction is refused if it "
                    'would leave less than their used plus pending leave.',
              ),
            const SizedBox(height: 14),
            MonthlyActionBar(
              secondary: TextButton(
                key: const Key('edit-back'),
                style: monthlyTextStyle,
                onPressed: _saving
                    ? null
                    : () => _confirming ? setState(() => _confirming = false) : Navigator.of(context).pop(),
                child: Text(_confirming ? 'Back' : 'Cancel'),
              ),
              primary: _confirming
                  ? FilledButton.icon(
                      key: const Key('edit-confirm'),
                      style: monthlyFilledStyle,
                      onPressed: _saving || next == null ? null : () => _save(next),
                      icon: _saving ? monthlySpinner() : const Icon(Icons.check, size: 16),
                      label: Text(_saving ? 'Saving…' : 'Confirm'),
                    )
                  : FilledButton(
                      key: const Key('edit-review'),
                      style: monthlyFilledStyle,
                      onPressed: validation != null || unchanged ? null : () => setState(() => _confirming = true),
                      child: const Text('Review change'),
                    ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
