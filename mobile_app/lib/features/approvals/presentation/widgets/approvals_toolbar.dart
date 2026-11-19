import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/access_control.dart' show userHasModule;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/formatters/en_in_format.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/approvals_providers.dart';
import 'approvals_ui.dart' show approvalsTextButtonStyle;

// ── Type tabs row (web TYPE_TABS) ─────────────────────────────────────────────
// Web shows the type as tabs AND a duplicate dropdown on "All Requests"; mobile
// keeps the tabs (they carry the counts) and skips the duplicate.

class ApprovalsTypeTabsRow extends ConsumerWidget {
  const ApprovalsTypeTabsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(approvalsTypeTabProvider);
    final counts = ref.watch(approvalsTypeTabCountsProvider);

    // Web: type tabs only for the company's modules (unknown list → all).
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final tabs = ApprovalsTypeTab.values.where((t) => userHasModule(user, moduleForApprovalsTab(t))).toList();
    if (!tabs.contains(active)) {
      // The selected type's module went away — back to All.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(approvalsTypeTabProvider.notifier).state = ApprovalsTypeTab.all;
      });
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          for (final t in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TypeTabChip(
                key: ValueKey('approvals-type-${t.name}'),
                icon: iconForApprovalsTab(t),
                label: labelForApprovalsTab(t),
                count: counts[t] ?? 0,
                selected: active == t,
                onTap: () => ref.read(approvalsTypeTabProvider.notifier).state = t,
              ),
            ),
        ],
      ),
    );
  }
}

/// The icon web gives each type tab (tabler → Material equivalent).
IconData iconForApprovalsTab(ApprovalsTypeTab t) => switch (t) {
      ApprovalsTypeTab.all => Icons.list_alt_outlined,
      ApprovalsTypeTab.leave => Icons.beach_access_outlined,
      ApprovalsTypeTab.wfh => Icons.home_work_outlined,
      ApprovalsTypeTab.expense => Icons.receipt_long_outlined,
      ApprovalsTypeTab.attendanceCorrection => Icons.edit_calendar_outlined,
      ApprovalsTypeTab.payslip => Icons.chat_bubble_outline,
      ApprovalsTypeTab.separation => Icons.logout,
    };

/// Web TYPE_TABS labels.
String labelForApprovalsTab(ApprovalsTypeTab t) => switch (t) {
      ApprovalsTypeTab.all => 'All Requests',
      ApprovalsTypeTab.leave => 'Leave',
      ApprovalsTypeTab.wfh => 'Work From Home',
      ApprovalsTypeTab.expense => 'Expense',
      ApprovalsTypeTab.attendanceCorrection => 'Attendance Correction',
      ApprovalsTypeTab.payslip => 'Payslip Requests',
      ApprovalsTypeTab.separation => 'Separation',
    };

class _TypeTabChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _TypeTabChip({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count pending',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.bodySmall.copyWith(color: fg, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.22) : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: AppTextStyles.caption.copyWith(
                        color: selected ? Colors.white : AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Toolbar (web ApprovalsToolbar) ────────────────────────────────────────────
// Compact on a phone: search, a Filters button (with a count of what is changed)
// and Refresh. Status, sort and the submitted-date range live in a bottom sheet;
// what is selected stays visible as chips and clears with one tap.

/// Web STATUS_FILTERS.
const _statusOptions = [
  MapEntry('all', 'All Statuses'),
  MapEntry('pending', 'Pending'),
  MapEntry('approved', 'Approved'),
  MapEntry('rejected', 'Rejected'),
];

String _statusLabel(String v) => _statusOptions.firstWhere((o) => o.key == v, orElse: () => _statusOptions.first).value;

String _sortLabel(ApprovalsSortKey k) => switch (k) {
      ApprovalsSortKey.employee => 'Employee',
      ApprovalsSortKey.submitted => 'Submitted Date',
      ApprovalsSortKey.status => 'Status',
    };

class ApprovalsToolbar extends ConsumerStatefulWidget {
  const ApprovalsToolbar({super.key});

  @override
  ConsumerState<ApprovalsToolbar> createState() => _ApprovalsToolbarState();
}

class _ApprovalsToolbarState extends ConsumerState<ApprovalsToolbar> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: ref.read(approvalsSearchQueryProvider));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  OutlineInputBorder _border() =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: AppColors.border));

  @override
  Widget build(BuildContext context) {
    // Clearing the filters elsewhere (the "no match" state) also empties the box.
    ref.listen(approvalsSearchQueryProvider, (_, next) {
      if (_searchCtrl.text != next) _searchCtrl.text = next;
    });
    final status = ref.watch(approvalsStatusFilterProvider);
    final sortKey = ref.watch(approvalsSortKeyProvider);
    final desc = ref.watch(approvalsSortDescProvider);
    final from = ref.watch(approvalsDateFromProvider);
    final to = ref.watch(approvalsDateToProvider);
    final isLoading = ref.watch(unifiedTeamApprovalsProvider).isLoading;

    final changedSort = sortKey != ApprovalsSortKey.submitted || !desc;
    final active =
        (status != 'pending' ? 1 : 0) + (changedSort ? 1 : 0) + (from != null ? 1 : 0) + (to != null ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('approvals-search'),
                  controller: _searchCtrl,
                  onChanged: (v) => ref.read(approvalsSearchQueryProvider.notifier).state = v,
                  decoration: InputDecoration(
                    hintText: 'Search employee name or ID…',
                    hintStyle: AppTextStyles.caption,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    border: _border(),
                    enabledBorder: _border(),
                  ),
                  style: AppTextStyles.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              _FiltersButton(count: active, onTap: () => showApprovalsFilterSheet(context)),
              const SizedBox(width: 8),
              _RefreshButton(isLoading: isLoading),
            ],
          ),
          const SizedBox(height: 8),
          // What is applied, always visible: the status, then anything changed.
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _FilterChip(
                key: const Key('approvals-chip-status'),
                icon: Icons.flag_outlined,
                label: _statusLabel(status),
                onTap: () => showApprovalsFilterSheet(context),
                onClear: status == 'pending'
                    ? null
                    : () => ref.read(approvalsStatusFilterProvider.notifier).state = 'pending',
              ),
              if (changedSort)
                _FilterChip(
                  key: const Key('approvals-chip-sort'),
                  icon: desc ? Icons.arrow_downward : Icons.arrow_upward,
                  label: _sortLabel(sortKey),
                  onTap: () => showApprovalsFilterSheet(context),
                  onClear: () {
                    ref.read(approvalsSortKeyProvider.notifier).state = ApprovalsSortKey.submitted;
                    ref.read(approvalsSortDescProvider.notifier).state = true;
                  },
                ),
              if (from != null)
                _FilterChip(
                  key: const Key('approvals-chip-from'),
                  icon: Icons.calendar_today_outlined,
                  label: 'From ${formatEnInDate(from, padDay: true)}',
                  onTap: () => showApprovalsFilterSheet(context),
                  onClear: () => ref.read(approvalsDateFromProvider.notifier).state = null,
                ),
              if (to != null)
                _FilterChip(
                  key: const Key('approvals-chip-to'),
                  icon: Icons.calendar_today_outlined,
                  label: 'To ${formatEnInDate(to, padDay: true)}',
                  onTap: () => showApprovalsFilterSheet(context),
                  onClear: () => ref.read(approvalsDateToProvider.notifier).state = null,
                ),
              if (active > 0 || _searchCtrl.text.isNotEmpty)
                TextButton(
                  key: const Key('approvals-clear-filters'),
                  onPressed: () => clearApprovalsFilters(ref),
                  style: approvalsTextButtonStyle(minHeight: 36),
                  child: const Text('Clear all'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count == 0 ? 'Filters' : 'Filters, $count changed',
      child: InkWell(
        key: const Key('approvals-filters'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: count > 0 ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: count > 0 ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, size: 18, color: count > 0 ? AppColors.primary : AppColors.textSecondary),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text('$count',
                    style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RefreshButton extends ConsumerWidget {
  final bool isLoading;
  const _RefreshButton({required this.isLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: IconButton(
        key: const Key('approvals-refresh'),
        tooltip: 'Refresh',
        onPressed: isLoading ? null : () => ref.read(unifiedTeamApprovalsProvider.notifier).refresh(),
        icon: isLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh, size: 18),
      ),
    );
  }
}

/// A selected filter, tappable to change and (when it differs from the default) clearable.
class _FilterChip extends StatelessWidget {
  const _FilterChip({super.key, required this.icon, required this.label, required this.onTap, this.onClear});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final changed = onClear != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36, maxWidth: 260),
        padding: EdgeInsets.fromLTRB(10, 0, changed ? 2 : 10, 0),
        decoration: BoxDecoration(
          color: changed ? AppColors.primary.withValues(alpha: 0.08) : AppColors.backgroundLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: changed ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600, color: changed ? AppColors.primary : AppColors.textPrimary)),
            ),
            if (changed)
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(18),
                child: const Padding(padding: EdgeInsets.all(9), child: Icon(Icons.close, size: 14)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Status, sort and submitted-date range — every filter web's toolbar offers.
Future<void> showApprovalsFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  Future<void> _pick(BuildContext context, WidgetRef ref, {required bool isFrom}) async {
    final current = isFrom ? ref.read(approvalsDateFromProvider) : ref.read(approvalsDateToProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    (isFrom ? ref.read(approvalsDateFromProvider.notifier) : ref.read(approvalsDateToProvider.notifier)).state = picked;
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(approvalsStatusFilterProvider);
    final sortKey = ref.watch(approvalsSortKeyProvider);
    final desc = ref.watch(approvalsSortDescProvider);
    final from = ref.watch(approvalsDateFromProvider);
    final to = ref.watch(approvalsDateToProvider);

    Widget choice(String label, bool selected, VoidCallback onTap, {Key? key, IconData? icon}) => ChoiceChip(
          key: key,
          avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textSecondary),
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
          labelStyle: AppTextStyles.bodySmall
              .copyWith(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onSelected: (_) => onTap(),
        );

    Widget dateTile(String label, DateTime? value, bool isFrom, String keyName) => Expanded(
          child: InkWell(
            key: Key(keyName),
            onTap: () => _pick(context, ref, isFrom: isFrom),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: value == null ? AppColors.border : AppColors.primary),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(value == null ? label : formatEnInDate(value, padDay: true),
                        style: AppTextStyles.bodySmall.copyWith(
                            color: value == null ? AppColors.textHint : AppColors.textPrimary,
                            fontWeight: value == null ? FontWeight.w400 : FontWeight.w600)),
                  ),
                  if (value != null)
                    InkWell(
                      onTap: () => (isFrom
                              ? ref.read(approvalsDateFromProvider.notifier)
                              : ref.read(approvalsDateToProvider.notifier))
                          .state = null,
                      child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close, size: 16)),
                    ),
                ],
              ),
            ),
          ),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Filters', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700))),
                TextButton(
                  key: const Key('approvals-sheet-clear'),
                  onPressed: () => clearApprovalsFilters(ref),
                  style: approvalsTextButtonStyle(),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _section(
              'Status',
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final o in _statusOptions)
                  choice(o.value, status == o.key, () => ref.read(approvalsStatusFilterProvider.notifier).state = o.key,
                      key: Key('approvals-status-${o.key}')),
              ]),
            ),
            _section(
              'Sort by',
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in ApprovalsSortKey.values)
                  choice(_sortLabel(k), sortKey == k, () => approvalsSortBy(ref, k),
                      key: Key('approvals-sort-${k.name}'),
                      icon: sortKey == k ? (desc ? Icons.arrow_downward : Icons.arrow_upward) : null),
              ]),
            ),
            _section(
              'Submitted date',
              Row(children: [
                dateTile('Submitted from', from, true, 'approvals-date-from'),
                const SizedBox(width: 10),
                dateTile('Submitted to', to, false, 'approvals-date-to'),
              ]),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('approvals-sheet-done'),
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(0, 48)),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
