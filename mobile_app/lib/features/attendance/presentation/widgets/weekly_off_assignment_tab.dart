import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../employees/presentation/providers/employee_providers.dart';
import '../../data/models/shift_assignment_models.dart' show canAssignShifts, effectiveBranch, isUnrestrictedBranchUser;
import '../../data/models/weekly_off_assignment_models.dart';
import '../providers/weekly_off_assignment_providers.dart';
import 'assignment_form_widgets.dart';

// HR Attendance → "Weekly Off Assignment" tab — web WeeklyOffAssignmentTab.tsx:
// every in-scope employee with their current weekly-off pattern (branch /
// department / pattern / status filters, 20 per page), "Assign"/"Change" for
// one employee and "Bulk Assign" by branch/department, both with an
// Effective From date. Assigning needs attendance.create; the server scopes
// every list and assignment.

class WeeklyOffAssignmentTab extends ConsumerWidget {
  const WeeklyOffAssignmentTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final canAssign = canAssignShifts(user);
    final unrestricted = isUnrestrictedBranchUser(user);
    final q = ref.watch(weeklyOffQueryProvider);
    final patterns = ref.watch(weeklyOffPatternsProvider).valueOrNull ?? const <WeeklyOffPattern>[];
    final branches = ref.watch(employeeBranchNameListProvider);
    final departments = ref.watch(employeeDepartmentListProvider);
    final pageAsync = ref.watch(weeklyOffAssignmentsProvider);
    void setQuery(WeeklyOffQuery next) => ref.read(weeklyOffQueryProvider.notifier).state = next;

    Future<void> openAssign(WeeklyOffAssignmentRow row) async {
      final name = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        builder: (_) => AssignWeeklyOffSheet(row: row),
      );
      if (name != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Weekly off pattern assigned to $name.'), backgroundColor: AppColors.success));
      }
    }

    Future<void> openBulk() async {
      final count = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        builder: (_) => const BulkAssignWeeklyOffSheet(),
      );
      if (count != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Weekly off pattern assigned to $count employee(s).'), backgroundColor: AppColors.success));
      }
    }

    return ListView(
      key: const Key('weekly-off-tab'),
      primary: false,
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          SizedBox(
            width: 170,
            child: AssignmentPicker(
              key: const Key('wo-filter-branch'),
              label: 'Branch',
              value: unrestricted ? q.branch : effectiveBranch(user),
              options: unrestricted
                  ? [('', 'All Branches'), for (final b in branches) (b, b)]
                  : [(effectiveBranch(user), effectiveBranch(user).isEmpty ? 'All Branches' : effectiveBranch(user))],
              onChanged: unrestricted ? (v) => setQuery(q.copyWith(branch: v)) : null,
            ),
          ),
          SizedBox(
            width: 170,
            child: AssignmentPicker(
              key: const Key('wo-filter-department'),
              label: 'Department',
              value: q.department,
              options: [('', 'All Departments'), for (final d in departments) (d, d)],
              onChanged: (v) => setQuery(q.copyWith(department: v)),
            ),
          ),
          SizedBox(
            width: 170,
            child: AssignmentPicker(
              key: const Key('wo-filter-pattern'),
              label: 'Weekly Off Pattern',
              value: q.pattern,
              options: [('', 'All Patterns'), for (final p in patterns) (p.id, p.name)],
              onChanged: (v) => setQuery(q.copyWith(pattern: v)),
            ),
          ),
          SizedBox(
            width: 170,
            child: AssignmentPicker(
              key: const Key('wo-filter-status'),
              label: 'Status',
              value: q.status,
              options: [for (final o in kWeeklyOffStatusOptions) (o.value, o.label)],
              onChanged: (v) => setQuery(q.copyWith(status: v)),
            ),
          ),
        ]),
        if (canAssign) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('wo-bulk-open'),
              onPressed: openBulk,
              icon: const Icon(Icons.groups_outlined, size: 16),
              label: const Text('Bulk Assign'),
            ),
          ),
        ],
        const SizedBox(height: 10),
        pageAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Loading…', key: Key('wo-loading'))),
          ),
          error: (e, _) => Column(children: [
            AssignmentErrorBox(
                key: const Key('wo-list-error'), text: weeklyOffError(e, 'Failed to load weekly off assignments.')),
            TextButton(
              key: const Key('wo-retry'),
              onPressed: () => ref.invalidate(weeklyOffAssignmentsProvider),
              child: const Text('Retry'),
            ),
          ]),
          data: (page) => Column(children: [
            if (page.rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No employees found.', key: Key('wo-empty'))),
              ),
            for (final r in page.rows) _RowCard(row: r, canAssign: canAssign, onAssign: () => openAssign(r)),
            if (page.totalPages > 1)
              Row(children: [
                Expanded(
                  child: Text('Page ${page.page} of ${page.totalPages} · ${page.count} employees',
                      key: const Key('wo-page-info'), style: AppTextStyles.caption.copyWith(fontSize: 12)),
                ),
                TextButton(
                  key: const Key('wo-prev'),
                  onPressed: q.page <= 1 ? null : () => setQuery(q.copyWith(page: q.page - 1)),
                  child: const Text('Prev'),
                ),
                TextButton(
                  key: const Key('wo-next'),
                  onPressed: q.page >= page.totalPages ? null : () => setQuery(q.copyWith(page: q.page + 1)),
                  child: const Text('Next'),
                ),
              ]),
          ]),
        ),
      ],
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.row, required this.canAssign, required this.onAssign});
  final WeeklyOffAssignmentRow row;
  final bool canAssign;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final muted = AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary);
    final badge = row.isAssigned ? AppColors.success : AppColors.textSecondary;
    return Container(
      key: Key('wo-row-${row.employeeId}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.employeeName, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            Text([row.employeeId, row.department, row.branch].where((s) => s.isNotEmpty).join(' · '), style: muted),
            const SizedBox(height: 4),
            // Web: pattern_name ?? "—"
            Text(row.patternName ?? '—', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            Text('Effective From ${row.effectiveFrom ?? '—'} · Effective To ${row.effectiveTo ?? '-'}', style: muted),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: badge.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(row.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badge)),
          ),
          if (canAssign)
            TextButton.icon(
              key: Key('wo-assign-${row.employeeId}'),
              onPressed: onAssign,
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: Text(row.isAssigned ? 'Change' : 'Assign'),
            ),
        ]),
      ]),
    );
  }
}

/// Web "Assign Weekly Off Pattern" modal: pattern (pre-selected to the
/// current one) and Effective From (today); pops with the employee's name
/// once the server confirms.
class AssignWeeklyOffSheet extends ConsumerStatefulWidget {
  const AssignWeeklyOffSheet({super.key, required this.row});
  final WeeklyOffAssignmentRow row;

  @override
  ConsumerState<AssignWeeklyOffSheet> createState() => _AssignWeeklyOffSheetState();
}

class _AssignWeeklyOffSheetState extends ConsumerState<AssignWeeklyOffSheet> {
  late String _pattern = widget.row.patternId ?? '';
  late DateTime _date = ref.read(weeklyOffClockProvider)();
  bool _saving = false;
  String? _error;

  Future<void> _assign() async {
    if (_saving || _pattern.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(weeklyOffServiceProvider).assign(widget.row, _pattern, _date);
      if (mounted) Navigator.of(context).pop(widget.row.employeeName);
    } on WeeklyOffAssignBusy {
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = weeklyOffError(e, 'Failed to assign pattern.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final patterns = ref.watch(weeklyOffPatternsProvider).valueOrNull ?? const <WeeklyOffPattern>[];
    final valid = patterns.any((p) => p.id == _pattern);
    return AssignmentSheet(
      key: const Key('wo-assign-sheet'),
      title: 'Assign Weekly Off Pattern',
      saving: _saving,
      content: [
        if (_error != null) AssignmentErrorBox(key: const Key('wo-assign-error'), text: _error!),
        Text(
          '${r.employeeName} (${r.employeeId})'
          '${r.isAssigned ? ' — currently ${r.patternName ?? ''}, effective ${r.effectiveFrom ?? '—'}' : ''}',
          style: AppTextStyles.bodySmall.copyWith(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        AssignmentPicker(
          key: const Key('wo-assign-pattern'),
          label: 'Weekly Off Pattern',
          value: valid ? _pattern : '',
          options: [('', 'Select pattern…'), for (final p in patterns) (p.id, p.name)],
          onChanged: _saving ? null : (v) => setState(() => _pattern = v),
        ),
        const SizedBox(height: 12),
        AssignmentDateField(
          key: const Key('wo-assign-date'),
          value: _date,
          enabled: !_saving,
          onChanged: (d) => setState(() => _date = d),
        ),
        const SizedBox(height: 8),
        Text('Past attendance is never affected — this pattern applies from the effective date forward only.',
            style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
      action: FilledButton(
        key: const Key('wo-assign-submit'),
        onPressed: _saving || !valid ? null : _assign,
        child: Text(_saving ? 'Assigning…' : 'Assign'),
      ),
    );
  }
}

/// Web "Bulk Assign Weekly Off Pattern" modal: every active employee matching
/// the branch and/or department (resolved and scoped by the server).
class BulkAssignWeeklyOffSheet extends ConsumerStatefulWidget {
  const BulkAssignWeeklyOffSheet({super.key});

  @override
  ConsumerState<BulkAssignWeeklyOffSheet> createState() => _BulkAssignWeeklyOffSheetState();
}

class _BulkAssignWeeklyOffSheetState extends ConsumerState<BulkAssignWeeklyOffSheet> {
  String _branch = '';
  String _department = '';
  String _pattern = '';
  late DateTime _date = ref.read(weeklyOffClockProvider)();
  bool _saving = false;
  String? _error;

  Future<void> _assign(bool unrestricted, String ownBranch) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final count = await ref.read(weeklyOffServiceProvider).bulkAssign(
            patternId: _pattern,
            from: _date,
            // A branch-restricted user's branch is their own (shown locked).
            branch: unrestricted ? _branch : ownBranch,
            department: _department,
          );
      if (mounted) Navigator.of(context).pop(count);
    } on WeeklyOffAssignBusy {
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = weeklyOffError(e, 'Bulk assignment failed.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final unrestricted = isUnrestrictedBranchUser(user);
    final own = effectiveBranch(user);
    final patterns = ref.watch(weeklyOffPatternsProvider).valueOrNull ?? const <WeeklyOffPattern>[];
    final branches = ref.watch(employeeBranchNameListProvider);
    final departments = ref.watch(employeeDepartmentListProvider);
    // Web: pattern and date required; an unrestricted user must also narrow
    // by branch or department.
    final canSubmit =
        !_saving && _pattern.isNotEmpty && (_branch.isNotEmpty || _department.isNotEmpty || !unrestricted);
    return AssignmentSheet(
      key: const Key('wo-bulk-sheet'),
      title: 'Bulk Assign Weekly Off Pattern',
      saving: _saving,
      content: [
        if (_error != null) AssignmentErrorBox(key: const Key('wo-bulk-error'), text: _error!),
        Text(
          'Applies to every active employee matching the filters below — resolved on the server, so no employee '
          'list needs to load first.',
          style: AppTextStyles.bodySmall.copyWith(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        AssignmentPicker(
          key: const Key('wo-bulk-branch'),
          label: 'Branch',
          value: unrestricted ? _branch : own,
          options: unrestricted
              ? [('', 'All Branches'), for (final b in branches) (b, b)]
              : [(own, own.isEmpty ? 'All Branches' : own)],
          onChanged: unrestricted && !_saving ? (v) => setState(() => _branch = v) : null,
        ),
        const SizedBox(height: 12),
        AssignmentPicker(
          key: const Key('wo-bulk-department'),
          label: 'Department',
          value: _department,
          options: [('', 'All Departments'), for (final d in departments) (d, d)],
          onChanged: _saving ? null : (v) => setState(() => _department = v),
        ),
        const SizedBox(height: 12),
        AssignmentPicker(
          key: const Key('wo-bulk-pattern'),
          label: 'Weekly Off Pattern',
          value: _pattern,
          options: [('', 'Select pattern…'), for (final p in patterns) (p.id, p.name)],
          onChanged: _saving ? null : (v) => setState(() => _pattern = v),
        ),
        const SizedBox(height: 12),
        AssignmentDateField(
          key: const Key('wo-bulk-date'),
          value: _date,
          enabled: !_saving,
          onChanged: (d) => setState(() => _date = d),
        ),
      ],
      action: FilledButton(
        key: const Key('wo-bulk-submit'),
        onPressed: canSubmit ? () => _assign(unrestricted, own) : null,
        child: Text(_saving ? 'Assigning…' : 'Assign to Matching Employees'),
      ),
    );
  }
}
