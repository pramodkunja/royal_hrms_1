import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../employees/presentation/providers/employee_providers.dart';
import '../../data/models/shift_assignment_models.dart';
import '../providers/shift_assignment_providers.dart';
import 'assignment_form_widgets.dart';
import 'shift_card.dart';
import 'shift_master_card.dart';

// HR Attendance → "Shift Assignment" tab — web ShiftAssignmentTab.tsx: every
// in-scope employee with their current shift (branch / department / shift /
// status filters, 20 per page), "Assign"/"Change" for one employee and "Bulk
// Assign" by branch/department, both with an Effective From date. Assigning
// needs attendance.create; the server scopes every list and assignment.

class ShiftAssignmentTab extends ConsumerWidget {
  const ShiftAssignmentTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final canAssign = canAssignShifts(user);
    final unrestricted = isUnrestrictedBranchUser(user);
    final q = ref.watch(shiftAssignmentQueryProvider);
    final shifts = ref.watch(shiftOptionsProvider).valueOrNull ?? const <ShiftOption>[];
    final branches = ref.watch(employeeBranchNameListProvider);
    final departments = ref.watch(employeeDepartmentListProvider);
    final pageAsync = ref.watch(shiftAssignmentsProvider);
    void setQuery(ShiftAssignmentQuery next) => ref.read(shiftAssignmentQueryProvider.notifier).state = next;

    Future<void> openAssign(ShiftAssignmentRow row) async {
      final name = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        builder: (_) => AssignShiftSheet(row: row),
      );
      if (name != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Shift assigned to $name.'), backgroundColor: AppColors.success));
      }
    }

    Future<void> openBulk() async {
      final count = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        builder: (_) => const BulkAssignShiftSheet(),
      );
      if (count != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Shift assigned to $count employee(s).'), backgroundColor: AppColors.success));
      }
    }

    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    Widget filter(String key, String label, String value, List<(String, String)> options, ValueChanged<String>? on) =>
        AssignmentPicker(key: Key(key), label: label, value: value, options: options, onChanged: on);

    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth;
      // Centred reading column on large tablets.
      final side = width > 984 ? (width - 960) / 2 : 12.0;
      final content = width > 984 ? 960.0 : width - 24;
      final cols = scale > 1.3 || content < 520 ? 1 : (content < 900 ? 2 : 4);
      final fw = cols == 1 ? content : (content - 8.0 * (cols - 1)) / cols;
      final filters = <Widget>[
        filter(
            'shift-filter-branch',
            'Branch',
            unrestricted ? q.branch : effectiveBranch(user),
            unrestricted
                ? [('', 'All Branches'), for (final b in branches) (b, b)]
                : [(effectiveBranch(user), effectiveBranch(user).isEmpty ? 'All Branches' : effectiveBranch(user))],
            unrestricted ? (v) => setQuery(q.copyWith(branch: v)) : null),
        filter('shift-filter-department', 'Department', q.department,
            [('', 'All Departments'), for (final d in departments) (d, d)], (v) => setQuery(q.copyWith(department: v))),
        filter('shift-filter-shift', 'Shift', q.shift, [('', 'All Shifts'), for (final s in shifts) (s.id, s.name)],
            (v) => setQuery(q.copyWith(shift: v))),
        filter('shift-filter-status', 'Status', q.status, [for (final o in kShiftStatusOptions) (o.value, o.label)],
            (v) => setQuery(q.copyWith(status: v))),
      ];
      return ListView(
        key: const Key('shift-assignment-tab'),
        primary: false,
        padding: EdgeInsets.fromLTRB(side, 12, side, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          // Web: ShiftMasterCard above the filters, for users who can assign.
          if (canAssign) const ShiftMasterCard(),
          ShiftSectionHeader(
            icon: Icons.groups_outlined,
            title: 'Employee shift assignment',
            subtitle: 'See which shift each employee follows, and assign or change it from a chosen date. '
                'Past attendance is never affected.',
            trailing: canAssign
                ? FilledButton.icon(
                    key: const Key('shift-bulk-open'),
                    onPressed: openBulk,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: const Text('Bulk Assign'),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 12, children: [for (final f in filters) SizedBox(width: fw, child: f)]),
          const SizedBox(height: 14),
          pageAsync.when(
            loading: () => const ApprovalsLoading(key: Key('shift-loading'), label: 'Loading employees…'),
            error: (e, _) => Column(children: [
              ApprovalsEmptyState.forError(e,
                  key: const Key('shift-list-error'), compact: true, what: 'shift assignments'),
              OutlinedButton.icon(
                key: const Key('shift-retry'),
                onPressed: () => ref.invalidate(shiftAssignmentsProvider),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ]),
            data: (page) => Column(children: [
              if (page.rows.isEmpty)
                const ApprovalsEmptyState(
                  key: Key('shift-empty'),
                  kind: ApprovalsStateKind.noMatch,
                  title: 'No employees found.',
                  message: 'Change the branch, department, shift or status filters to see more employees.',
                  icon: Icons.groups_outlined,
                  compact: true,
                ),
              LayoutBuilder(builder: (context, c) {
                final two = c.maxWidth >= 600;
                final w = two ? (c.maxWidth - 12) / 2 : c.maxWidth;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final r in page.rows)
                    SizedBox(width: w, child: _RowCard(row: r, canAssign: canAssign, onAssign: () => openAssign(r))),
                ]);
              }),
              if (page.totalPages > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Page ${page.page} of ${page.totalPages} · ${page.count} employees',
                          key: const Key('shift-page-info'), style: AppTextStyles.caption.copyWith(fontSize: 12)),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        TextButton(
                          key: const Key('shift-prev'),
                          onPressed: q.page <= 1 ? null : () => setQuery(q.copyWith(page: q.page - 1)),
                          child: const Text('Prev'),
                        ),
                        TextButton(
                          key: const Key('shift-next'),
                          onPressed: q.page >= page.totalPages ? null : () => setQuery(q.copyWith(page: q.page + 1)),
                          child: const Text('Next'),
                        ),
                      ]),
                    ],
                  ),
                ),
            ]),
          ),
        ],
      );
    });
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.row, required this.canAssign, required this.onAssign});
  final ShiftAssignmentRow row;
  final bool canAssign;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final muted = AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary);
    return Container(
      key: Key('shift-row-${row.employeeId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(row.employeeName, style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text([row.employeeId, row.department, row.branch].where((s) => s.isNotEmpty).join(' · '), style: muted),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(row.shiftName ?? 'General / Default',
              style: AppTextStyles.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
          ApprovalsChip(row.status,
              key: Key('shift-status-${row.employeeId}'),
              tone: row.isAssigned ? ApprovalsTone.success : ApprovalsTone.neutral),
        ]),
        const SizedBox(height: 4),
        Text('Effective From ${row.effectiveFrom ?? '—'} · Effective To ${row.effectiveTo ?? '-'}', style: muted),
        if (canAssign) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: Key('shift-assign-${row.employeeId}'),
              onPressed: onAssign,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: Text(row.isAssigned ? 'Change shift' : 'Assign shift'),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Web "Assign Shift" modal: shift (pre-selected to the current one) and
/// Effective From (today); pops with the employee's name once the server
/// confirms.
class AssignShiftSheet extends ConsumerStatefulWidget {
  const AssignShiftSheet({super.key, required this.row});
  final ShiftAssignmentRow row;

  @override
  ConsumerState<AssignShiftSheet> createState() => _AssignShiftSheetState();
}

class _AssignShiftSheetState extends ConsumerState<AssignShiftSheet> {
  late String _shift = widget.row.shiftId ?? '';
  late DateTime _date = ref.read(shiftAssignmentClockProvider)();
  bool _saving = false;
  String? _error;

  Future<void> _assign() async {
    if (_saving || _shift.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(shiftAssignmentServiceProvider).assign(widget.row, _shift, _date);
      if (mounted) Navigator.of(context).pop(widget.row.employeeName);
    } on ShiftAssignBusy {
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = shiftAssignmentError(e, 'Failed to assign shift.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final shifts = ref.watch(shiftOptionsProvider).valueOrNull ?? const <ShiftOption>[];
    final muted = AppTextStyles.bodySmall.copyWith(fontSize: 13, color: AppColors.textSecondary);
    return AssignmentSheet(
      key: const Key('assign-shift-sheet'),
      title: 'Assign Shift',
      saving: _saving,
      content: [
        if (_error != null) AssignmentErrorBox(key: const Key('assign-shift-error'), text: _error!),
        Text(
          '${r.employeeName} (${r.employeeId})'
          '${r.isAssigned ? ' — currently ${r.shiftName ?? ''}, effective ${r.effectiveFrom ?? '—'}' : ''}'
          '${r.status == 'Not Assigned' ? ' — currently on the global default schedule' : ''}',
          style: muted,
        ),
        const SizedBox(height: 12),
        AssignmentPicker(
          key: const Key('assign-shift-shift'),
          label: 'Shift',
          value: shifts.any((s) => s.id == _shift) ? _shift : '',
          options: [('', 'Select shift…'), for (final s in shifts) (s.id, s.name)],
          onChanged: _saving ? null : (v) => setState(() => _shift = v),
        ),
        const SizedBox(height: 12),
        AssignmentDateField(
          key: const Key('assign-shift-date'),
          value: _date,
          enabled: !_saving,
          onChanged: (d) => setState(() => _date = d),
        ),
        const SizedBox(height: 8),
        Text('Past attendance is never affected — this shift applies from the effective date forward only.',
            style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
      action: FilledButton(
        key: const Key('assign-shift-submit'),
        onPressed: _saving || _shift.isEmpty || !shifts.any((s) => s.id == _shift) ? null : _assign,
        child: Text(_saving ? 'Assigning…' : 'Assign'),
      ),
    );
  }
}

/// Web "Bulk Assign Shift" modal: every active employee matching the branch
/// and/or department (resolved and scoped by the server).
class BulkAssignShiftSheet extends ConsumerStatefulWidget {
  const BulkAssignShiftSheet({super.key});

  @override
  ConsumerState<BulkAssignShiftSheet> createState() => _BulkAssignShiftSheetState();
}

class _BulkAssignShiftSheetState extends ConsumerState<BulkAssignShiftSheet> {
  String _branch = '';
  String _department = '';
  String _shift = '';
  late DateTime _date = ref.read(shiftAssignmentClockProvider)();
  bool _saving = false;
  String? _error;

  Future<void> _assign(bool unrestricted, String ownBranch) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final count = await ref.read(shiftAssignmentServiceProvider).bulkAssign(
            shiftId: _shift,
            from: _date,
            // A branch-restricted user's branch is their own (shown locked).
            branch: unrestricted ? _branch : ownBranch,
            department: _department,
          );
      if (mounted) Navigator.of(context).pop(count);
    } on ShiftAssignBusy {
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = shiftAssignmentError(e, 'Bulk assignment failed.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final unrestricted = isUnrestrictedBranchUser(user);
    final own = effectiveBranch(user);
    final shifts = ref.watch(shiftOptionsProvider).valueOrNull ?? const <ShiftOption>[];
    final branches = ref.watch(employeeBranchNameListProvider);
    final departments = ref.watch(employeeDepartmentListProvider);
    // Web: shift and date required; an unrestricted user must also narrow by
    // branch or department.
    final canSubmit = !_saving && _shift.isNotEmpty && (_branch.isNotEmpty || _department.isNotEmpty || !unrestricted);
    return AssignmentSheet(
      key: const Key('bulk-shift-sheet'),
      title: 'Bulk Assign Shift',
      saving: _saving,
      content: [
        if (_error != null) AssignmentErrorBox(key: const Key('bulk-shift-error'), text: _error!),
        Text(
          'Applies to every active employee matching the filters below — resolved on the server, so no employee '
          'list needs to load first. No business rule auto-selects employees by branch/department/role — you '
          'choose exactly who this applies to.',
          style: AppTextStyles.bodySmall.copyWith(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        AssignmentPicker(
          key: const Key('bulk-shift-branch'),
          label: 'Branch',
          value: unrestricted ? _branch : own,
          options: unrestricted
              ? [('', 'All Branches'), for (final b in branches) (b, b)]
              : [(own, own.isEmpty ? 'All Branches' : own)],
          onChanged: unrestricted && !_saving ? (v) => setState(() => _branch = v) : null,
        ),
        const SizedBox(height: 12),
        AssignmentPicker(
          key: const Key('bulk-shift-department'),
          label: 'Department',
          value: _department,
          options: [('', 'All Departments'), for (final d in departments) (d, d)],
          onChanged: _saving ? null : (v) => setState(() => _department = v),
        ),
        const SizedBox(height: 12),
        AssignmentPicker(
          key: const Key('bulk-shift-shift'),
          label: 'Shift',
          value: _shift,
          options: [('', 'Select shift…'), for (final s in shifts) (s.id, s.name)],
          onChanged: _saving ? null : (v) => setState(() => _shift = v),
        ),
        const SizedBox(height: 12),
        AssignmentDateField(
          key: const Key('bulk-shift-date'),
          value: _date,
          enabled: !_saving,
          onChanged: (d) => setState(() => _date = d),
        ),
      ],
      action: FilledButton(
        key: const Key('bulk-shift-submit'),
        onPressed: canSubmit ? () => _assign(unrestricted, own) : null,
        child: Text(_saving ? 'Assigning…' : 'Assign to Matching Employees'),
      ),
    );
  }
}
