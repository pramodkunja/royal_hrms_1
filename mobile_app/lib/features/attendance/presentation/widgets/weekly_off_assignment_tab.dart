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
import 'weekly_off_sections.dart';

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
        constraints: const BoxConstraints(maxWidth: 560),
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
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (_) => const BulkAssignWeeklyOffSheet(),
      );
      if (count != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Weekly off pattern assigned to $count employee(s).'), backgroundColor: AppColors.success));
      }
    }

    final media = MediaQuery.of(context);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final compact = weeklyOffCompact(context, w);
      // 1 column on phones, 2 from 600dp; a centred column on big tablets.
      final cols = w >= 600 ? 2 : 1;
      final side = w >= 1160 ? (w - 1160) / 2 + 12 : 12.0;
      final inner = w - side * 2;
      final filterCols = compact ? 1 : weeklyOffColumns(inner - 28, 170);
      final page = pageAsync.valueOrNull;

      final filters = <Widget>[
        AssignmentPicker(
          key: const Key('wo-filter-branch'),
          label: 'Branch',
          value: unrestricted ? q.branch : effectiveBranch(user),
          options: unrestricted
              ? [('', 'All Branches'), for (final b in branches) (b, b)]
              : [(effectiveBranch(user), effectiveBranch(user).isEmpty ? 'All Branches' : effectiveBranch(user))],
          onChanged: unrestricted ? (v) => setQuery(q.copyWith(branch: v)) : null,
        ),
        AssignmentPicker(
          key: const Key('wo-filter-department'),
          label: 'Department',
          value: q.department,
          options: [('', 'All Departments'), for (final d in departments) (d, d)],
          onChanged: (v) => setQuery(q.copyWith(department: v)),
        ),
        AssignmentPicker(
          key: const Key('wo-filter-pattern'),
          label: 'Weekly Off Pattern',
          value: q.pattern,
          options: [('', 'All Patterns'), for (final p in patterns) (p.id, p.name)],
          onChanged: (v) => setQuery(q.copyWith(pattern: v)),
        ),
        AssignmentPicker(
          key: const Key('wo-filter-status'),
          label: 'Status',
          value: q.status,
          options: [for (final o in kWeeklyOffStatusOptions) (o.value, o.label)],
          onChanged: (v) => setQuery(q.copyWith(status: v)),
        ),
      ];

      final bulkButton = FilledButton.icon(
        key: const Key('wo-bulk-open'),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 20)),
        onPressed: openBulk,
        icon: const Icon(Icons.groups_outlined, size: 18),
        label: const Text('Bulk Assign'),
      );
      final overviewText = Text(
        canAssign
            ? 'Assign a weekly off pattern to one employee from the list below, or to every active employee of a '
                'branch or department at once.'
            : 'View each employee\u2019s weekly off pattern. Assigning needs additional access.',
        style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary),
      );

      Widget rows(WeeklyOffAssignmentPage pg) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (pg.rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No employees found.', key: Key('wo-empty'))),
              ),
            WeeklyOffGrid(columns: cols, children: [
              for (final r in pg.rows)
                KeyedSubtree(
                  key: Key('wo-row-${r.employeeId}'),
                  child: WeeklyOffAssignmentCard(row: r, canAssign: canAssign, onAssign: () => openAssign(r)),
                ),
            ]),
            if (pg.totalPages > 1) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Page ${pg.page} of ${pg.totalPages} \u00b7 ${pg.count} employees',
                      key: const Key('wo-page-info'), style: AppTextStyles.caption.copyWith(fontSize: 12)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton(
                      key: const Key('wo-prev'),
                      style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                      onPressed: q.page <= 1 ? null : () => setQuery(q.copyWith(page: q.page - 1)),
                      child: const Text('Prev'),
                    ),
                    TextButton(
                      key: const Key('wo-next'),
                      style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                      onPressed: q.page >= pg.totalPages ? null : () => setQuery(q.copyWith(page: q.page + 1)),
                      child: const Text('Next'),
                    ),
                  ]),
                ],
              ),
            ],
          ]);

      return ListView(
        key: const Key('weekly-off-tab'),
        primary: false,
        // The explicit padding replaces ListView's automatic safe-area padding,
        // so the real bottom inset is added back: the end of the list can always
        // be scrolled clear of the Android navigation bar. The extra clearance
        // lets the last card scroll above the floating voice assistant.
        padding: EdgeInsets.fromLTRB(
            side, 12, side, 12 + media.padding.bottom + (media.viewInsets.bottom > 0 ? 0 : kWeeklyOffAssistantClearance)),
        children: [
          WeeklyOffSection(
            icon: Icons.event_repeat_outlined,
            title: 'Assignment overview',
            subtitle: page == null ? null : '${page.count} employee(s) match the current filters',
            child: compact || w < 600
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    overviewText,
                    if (canAssign) ...[const SizedBox(height: 12), bulkButton],
                  ])
                : Row(children: [
                    Expanded(child: overviewText),
                    if (canAssign) ...[const SizedBox(width: 16), bulkButton],
                  ]),
          ),
          const SizedBox(height: 12),
          WeeklyOffSection(
            icon: Icons.filter_alt_outlined,
            title: 'Select employees',
            subtitle: 'Filter by branch, department, pattern or status.',
            child: WeeklyOffGrid(columns: filterCols, children: filters),
          ),
          const SizedBox(height: 12),
          WeeklyOffSection(
            icon: Icons.people_alt_outlined,
            title: 'Existing assignments',
            subtitle: canAssign ? 'Use Assign or Change on a card to set one employee\u2019s pattern.' : null,
            child: pageAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Loading\u2026', key: Key('wo-loading'))),
              ),
              error: (e, _) => Column(children: [
                AssignmentErrorBox(
                    key: const Key('wo-list-error'),
                    text: weeklyOffError(e, 'Failed to load weekly off assignments.')),
                TextButton(
                  key: const Key('wo-retry'),
                  style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                  onPressed: () => ref.invalidate(weeklyOffAssignmentsProvider),
                  child: const Text('Retry'),
                ),
              ]),
              data: rows,
            ),
          ),
        ],
      );
    });
  }
}

/// Scroll-end room so the last card clears the floating voice assistant (a
/// 96dp bubble drawn above the whole app) — content space, not a fixed bar.
const double kWeeklyOffAssistantClearance = 96;

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
        const SizedBox(height: 14),
        Text('Who', style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
        const SizedBox(height: 8),
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
        if (unrestricted && _branch.isEmpty && _department.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Choose a branch or a department to enable assignment.',
                key: const Key('wo-bulk-hint'),
                style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary)),
          ),
        const SizedBox(height: 16),
        Text('Weekly off', style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
        const SizedBox(height: 8),
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
