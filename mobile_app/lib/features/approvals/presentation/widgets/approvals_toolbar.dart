import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/approvals_providers.dart';

// ── Type tabs row (All / Leave / Expense / Attendance Correction) ──────────────
// The "Type" filter web exposes both as tabs AND a redundant dropdown inside
// the toolbar — mobile only implements the tabs (skips the duplicate).

class ApprovalsTypeTabsRow extends ConsumerWidget {
  const ApprovalsTypeTabsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(approvalsTypeTabProvider);
    final counts = ref.watch(approvalsTypeTabCountsProvider);

    const tabs = ApprovalsTypeTab.values;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 0, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          children: tabs
              .map((t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _TypeTabChip(
                      label: _labelFor(t),
                      count: counts[t] ?? 0,
                      selected: active == t,
                      onTap: () => ref.read(approvalsTypeTabProvider.notifier).state = t,
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  static String _labelFor(ApprovalsTypeTab t) => switch (t) {
        ApprovalsTypeTab.all => 'All',
        ApprovalsTypeTab.leave => 'Leave',
        ApprovalsTypeTab.expense => 'Expense',
        ApprovalsTypeTab.attendanceCorrection => 'Attendance Correction',
        ApprovalsTypeTab.wfh => 'WFH',
      };
}

class _TypeTabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _TypeTabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textSecondary)),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.25) : AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$count',
                    style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.primary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Toolbar — search / status filter / date range / refresh ────────────────────

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

  Future<void> _pickDate({required bool isFrom}) async {
    final current =
        isFrom ? ref.read(approvalsDateFromProvider) : ref.read(approvalsDateToProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    if (isFrom) {
      ref.read(approvalsDateFromProvider.notifier).state = picked;
    } else {
      ref.read(approvalsDateToProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFrom = ref.watch(approvalsDateFromProvider);
    final dateTo = ref.watch(approvalsDateToProvider);
    final isLoading = ref.watch(unifiedTeamApprovalsProvider).isLoading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => ref.read(approvalsSearchQueryProvider.notifier).state = v,
                  decoration: InputDecoration(
                    hintText: 'Search by name or employee code',
                    hintStyle: AppTextStyles.caption,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                  style: AppTextStyles.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              _RefreshButton(isLoading: isLoading),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: _StatusDropdown()),
              const SizedBox(width: 8),
              Expanded(
                child: _DateButton(
                  label: 'From',
                  date: dateFrom,
                  onTap: () => _pickDate(isFrom: true),
                  onClear: dateFrom == null
                      ? null
                      : () => ref.read(approvalsDateFromProvider.notifier).state = null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateButton(
                  label: 'To',
                  date: dateTo,
                  onTap: () => _pickDate(isFrom: false),
                  onClear: dateTo == null
                      ? null
                      : () => ref.read(approvalsDateToProvider.notifier).state = null,
                ),
              ),
            ],
          ),
        ],
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: IconButton(
        tooltip: 'Refresh',
        onPressed: isLoading
            ? null
            : () => ref.read(unifiedTeamApprovalsProvider.notifier).refresh(),
        icon: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              )
            : Icon(Icons.refresh, size: 20, color: AppColors.primary),
      ),
    );
  }
}

class _StatusDropdown extends ConsumerWidget {
  const _StatusDropdown();

  static const _options = [
    MapEntry('all', 'All Status'),
    MapEntry('pending', 'Pending'),
    MapEntry('l2_pending', 'Pending HR'),
    MapEntry('approved', 'Approved'),
    MapEntry('rejected', 'Rejected'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(approvalsStatusFilterProvider);
    final validValue = _options.any((o) => o.key == value) ? value : 'all';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
          isDense: true,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textHint),
          style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontSize: 11.5),
          items: _options
              .map((o) => DropdownMenuItem(
                    value: o.key,
                    child: Text(o.value, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) ref.read(approvalsStatusFilterProvider.notifier).state = v;
          },
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final text = date == null ? label : '${date!.day}/${date!.month}/${date!.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textHint),
            const SizedBox(width: 5),
            Expanded(
              child: Text(text,
                  style: AppTextStyles.caption.copyWith(fontSize: 10.5),
                  overflow: TextOverflow.ellipsis),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 12, color: AppColors.textHint),
              ),
          ],
        ),
      ),
    );
  }
}
