import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart';
import '../../domain/entities/attendance_entity.dart';
import '../providers/unpunch_providers.dart';

// Web UnpunchesTab (frontend/app/dashboard/attendance/_components/UnpunchesTab.tsx):
// a read-only list of employees who clocked in but never clocked out for the
// selected date. Fields, labels, filters, paging and states follow the web;
// only the layout (cards instead of a table) is adapted to a phone.

const unpunchBanner = 'Employees who clocked in but never clocked out (past shift end + grace period) for the selected date.';
const unpunchEmpty = 'No un-punches found for this date.';
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];

String unpunchDateLabel(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

bool _bigText(BuildContext c) => MediaQuery.textScalerOf(c).scale(10) / 10 > 1.3;

class UnpunchesTab extends ConsumerWidget {
  const UnpunchesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(unpunchPageProvider);
    final hasFilter = ref.watch(unpunchQueryBranchProvider).isNotEmpty && ref.watch(unpunchUnrestrictedProvider) ||
        ref.watch(unpunchDepartmentProvider).isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(unpunchPageProvider);
        try {
          await ref.read(unpunchPageProvider.future);
        } catch (_) {}
      },
      child: ListView(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Banner(),
                  const SizedBox(height: 12),
                  const UnpunchFilterBar(),
                  const SizedBox(height: 12),
                  async.when(
                    loading: () => const ApprovalsLoading(label: 'Loading…'),
                    error: (e, _) => ApprovalsEmptyState.forError(
                      e,
                      what: 'un-punches',
                      onRetry: () => ref.invalidate(unpunchPageProvider),
                    ),
                    data: (page) {
                      if (page.rows.isEmpty) {
                        return hasFilter
                            ? ApprovalsEmptyState(
                                key: const Key('unpunch-no-match'),
                                kind: ApprovalsStateKind.noMatch,
                                title: unpunchEmpty,
                                message: 'No un-punches match the selected branch or department.',
                                actionLabel: 'Clear filters',
                                onAction: () {
                                  ref.read(unpunchBranchProvider.notifier).state = '';
                                  ref.read(unpunchDepartmentProvider.notifier).state = '';
                                  ref.read(unpunchPageNumberProvider.notifier).state = 1;
                                },
                              )
                            : const ApprovalsEmptyState(
                                key: Key('unpunch-empty'),
                                kind: ApprovalsStateKind.empty,
                                title: unpunchEmpty,
                              );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CardGrid(rows: page.rows),
                          if (page.totalPages > 1) UnpunchPager(page: page),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('unpunch-banner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.warningContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.warning_amber_outlined, size: 16, color: AppColors.warning),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(unpunchBanner, style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning))),
        ]),
      );
}

/// Web filter bar: date, branch (locked to the user's own for scoped users),
/// department. Any change returns to page 1.
class UnpunchFilterBar extends ConsumerWidget {
  const UnpunchFilterBar({super.key});

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final current = ref.read(unpunchDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    ref.read(unpunchDateProvider.notifier).state = picked;
    ref.read(unpunchPageNumberProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(unpunchDateProvider);
    final unrestricted = ref.watch(unpunchUnrestrictedProvider);
    final lockedBranch = ref.watch(unpunchEffectiveBranchProvider);
    final branch = ref.watch(unpunchBranchProvider);
    final department = ref.watch(unpunchDepartmentProvider);
    final branches = ref.watch(unpunchBranchOptionsProvider).valueOrNull ?? const <String>[];
    final departments = ref.watch(unpunchDepartmentOptionsProvider).valueOrNull ?? const <String>[];

    final dateField = _Labeled(
      'Date',
      InkWell(
        key: const Key('unpunch-date'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => _pickDate(context, ref),
        child: _FieldBox(
          child: Row(children: [
            Expanded(child: Text(unpunchDateLabel(date), style: AppTextStyles.label)),
            Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
          ]),
        ),
      ),
    );

    final branchField = _Labeled(
      'Branch',
      unrestricted
          ? _Select(
              fieldKey: const Key('unpunch-branch'),
              value: branch,
              allLabel: 'All Branches',
              options: branches,
              onChanged: (v) {
                ref.read(unpunchBranchProvider.notifier).state = v;
                ref.read(unpunchPageNumberProvider.notifier).state = 1;
              },
            )
          : Tooltip(
              message: 'Scoped to your branch',
              child: _FieldBox(
                key: const Key('unpunch-branch-locked'),
                fill: AppColors.backgroundLow,
                child: Row(children: [
                  Expanded(child: Text(lockedBranch.isEmpty ? '—' : lockedBranch, style: AppTextStyles.label)),
                  Icon(Icons.lock_outline, size: 15, color: AppColors.textSecondary),
                ]),
              ),
            ),
    );

    final departmentField = _Labeled(
      'Department',
      _Select(
        fieldKey: const Key('unpunch-department'),
        value: department,
        allLabel: 'All Departments',
        options: departments,
        onChanged: (v) {
          ref.read(unpunchDepartmentProvider.notifier).state = v;
          ref.read(unpunchPageNumberProvider.notifier).state = 1;
        },
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 560 && !_bigText(context);
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: dateField),
            const SizedBox(width: 10),
            Expanded(child: branchField),
            const SizedBox(width: 10),
            Expanded(child: departmentField),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          dateField,
          const SizedBox(height: 10),
          branchField,
          const SizedBox(height: 10),
          departmentField,
        ]);
      }),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child);
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label,
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          child,
        ],
      );
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({super.key, required this.child, this.fill});
  final Widget child;
  final Color? fill;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: fill ?? AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

/// "All …" + options; '' is the all-value (web `<option value="">`).
class _Select extends StatelessWidget {
  const _Select({
    required this.fieldKey,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
  });
  final Key fieldKey;
  final String value;
  final String allLabel;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <String>{...options, if (value.isNotEmpty) value}.toList();
    return _FieldBox(
      key: fieldKey,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.expand_more, size: 20, color: AppColors.textSecondary),
          dropdownColor: AppColors.surface,
          style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
          items: [
            DropdownMenuItem(value: '', child: Text(allLabel, overflow: TextOverflow.ellipsis)),
            for (final o in items) DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => onChanged(v ?? ''),
        ),
      ),
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.rows});
  final List<UnpunchRowEntity> rows;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        const gap = 10.0;
        final two = c.maxWidth >= 600;
        final w = two ? (c.maxWidth - gap) / 2 : c.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final r in rows) SizedBox(width: w, child: UnpunchCard(record: r))],
        );
      });
}

/// One un-punch record. Web columns, in web order and with web labels:
/// Employee ID, Name, Branch, Date, Clock In, Expected Out, Correction Status.
class UnpunchCard extends StatelessWidget {
  const UnpunchCard({super.key, required this.record});
  final UnpunchRowEntity record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final pending = r.correctionPending;
    final big = _bigText(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ApprovalsAvatar(r.name, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name.isEmpty ? '—' : r.name,
                  style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Employee ID', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
              Text(r.employeeId.isEmpty ? '—' : r.employeeId,
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final cols = (c.maxWidth >= 260 && !big) ? 2 : 1;
          final w = cols == 2 ? (c.maxWidth - 12) / 2 : c.maxWidth;
          Widget f(String l, String v, {Color? color}) =>
              SizedBox(width: w, child: UnpunchField(label: l, value: v, valueColor: color));
          return Wrap(spacing: 12, runSpacing: 10, children: [
            f('Date', r.date),
            f('Clock In', r.clockIn, color: AppColors.primary),
            f('Expected Out', r.expectedOut),
            f('Branch', r.branch),
          ]);
        }),
        const SizedBox(height: 10),
        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Correction Status', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
            // Web: badge-warn "Correction Submitted" / badge-neutral "No Correction Filed".
            pending
                ? const ApprovalsBadge('Correction Submitted', ApprovalsTone.warning, icon: Icons.schedule)
                : const ApprovalsBadge('No Correction Filed', ApprovalsTone.neutral),
          ],
        ),
      ]),
    );
  }
}

class UnpunchField extends StatelessWidget {
  const UnpunchField({super.key, required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
          const SizedBox(height: 1),
          Text(value.isEmpty ? '—' : value,
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textPrimary)),
        ],
      );
}

/// Web footer: "Page X of Y" with Prev / Next (shown only when total_pages > 1).
class UnpunchPager extends ConsumerWidget {
  const UnpunchPager({super.key, required this.page});
  final UnpunchPageEntity page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(unpunchPageNumberProvider);
    void go(int p) => ref.read(unpunchPageNumberProvider.notifier).state = p;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        spacing: 12,
        children: [
          Text('Page ${page.page} of ${page.totalPages}',
              key: const Key('unpunch-page-label'), style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton.icon(
              key: const Key('unpunch-prev'),
              onPressed: current <= 1 ? null : () => go(current - 1),
              icon: const Icon(Icons.chevron_left, size: 18),
              label: const Text('Prev'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const Key('unpunch-next'),
              onPressed: current >= page.totalPages ? null : () => go(current + 1),
              icon: const Icon(Icons.chevron_right, size: 18),
              label: const Text('Next'),
              iconAlignment: IconAlignment.end,
              style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
            ),
          ]),
        ],
      ),
    );
  }
}
