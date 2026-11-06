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
          Wrap(spacing: 8, runSpacing: 8, children: [
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
              Row(children: [monthlySpinner(), const SizedBox(width: 8), Text('Loading assignments…', style: muted)]),
          error: (e, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MonthlyAlert(
                key: const Key('assign-error'),
                kind: MonthlyAlertKind.error,
                text: monthlyLeaveError(e, 'Could not load monthly leave assignments.')),
            TextButton(
              key: const Key('assign-retry'),
              onPressed: () => ref.invalidate(monthlyAssignmentsProvider(key)),
              child: const Text('Retry'),
            ),
          ]),
          data: (data) => data.assignments.isEmpty
              ? Text(
                  'No monthly leave assignments found for $monthName $_year. Use the import or manual entry above to add them.',
                  key: const Key('assign-empty'),
                  style: muted)
              : Column(children: [for (final a in data.assignments) _AssignmentCard(a, onEdit: () => _edit(a))]),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.hint);
  final String label, value, hint;

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: AppColors.backgroundLow,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8)),
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
    final muted = AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary);
    return Container(
      key: Key('assignment-${a.employeeId}-${a.leaveType}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a.employeeName}${a.isActive ? '' : ' (inactive)'}',
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            Text('${a.employeeId} · ${a.branch.isEmpty ? '—' : a.branch}', style: muted),
            Text('${a.leaveTypeLabel} · ${kMonthNames[(a.month - 1).clamp(0, 11)]} ${a.year}', style: muted),
            Text('Last updated ${formatMonthlyWhen(a.lastUpdated)}', style: muted),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${fmtNum(a.credit)} day(s)', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          if (a.isActive)
            TextButton.icon(
              key: Key('assignment-edit-${a.employeeId}-${a.leaveType}'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Edit'),
            )
          else
            Text('—', style: muted),
        ]),
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
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
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
              TextField(
                key: const Key('edit-credit'),
                controller: _ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  labelText: 'New monthly leave credit (days)',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  errorText: validation,
                  helperText: validation == null ? "0–31, one decimal place. 0 removes this month's credit." : null,
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
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                key: const Key('edit-back'),
                onPressed: _saving
                    ? null
                    : () => _confirming ? setState(() => _confirming = false) : Navigator.of(context).pop(),
                child: Text(_confirming ? 'Back' : 'Cancel'),
              ),
              const SizedBox(width: 8),
              if (_confirming)
                FilledButton.icon(
                  key: const Key('edit-confirm'),
                  onPressed: _saving || next == null ? null : () => _save(next),
                  icon: _saving ? monthlySpinner() : const Icon(Icons.check, size: 16),
                  label: Text(_saving ? 'Saving…' : 'Confirm'),
                )
              else
                FilledButton(
                  key: const Key('edit-review'),
                  onPressed: validation != null || unchanged ? null : () => setState(() => _confirming = true),
                  child: const Text('Review change'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
