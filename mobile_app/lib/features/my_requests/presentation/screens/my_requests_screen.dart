import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_loading_widget.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../../expenses/presentation/widgets/expense_detail_dialog.dart';
import '../../../leave/presentation/widgets/leave_request_detail_sheet.dart';
import '../../../wfh/presentation/widgets/wfh_request_detail_sheet.dart';
import '../providers/my_requests_providers.dart';
import '../widgets/my_correction_detail_sheet.dart';

/// Ports web's app/dashboard/my-requests — a self-service view of the
/// employee's OWN Leave / WFH / Expense / Attendance Correction requests,
/// merged into one list (see my_requests_providers.dart for why there is no
/// single backend endpoint for this). Every request type keeps opening its
/// existing detail widget (leave/WFH sheets, expense dialog) rather than a
/// duplicated generic one — including Cancel, which already works in those
/// widgets and needs no extra wiring here. Unlike web (which has no `wfh`
/// branch in its detail-modal switch and silently no-ops on tap), WFH rows
/// here open correctly.
class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  void _openDetail(BuildContext context, MyRequestItem item) {
    switch (item.kind) {
      case MyRequestKind.leave:
        showLeaveRequestDetailSheet(context, initial: item.leave!);
        break;
      case MyRequestKind.wfh:
        showWfhRequestDetailSheet(context, initial: item.wfh!);
        break;
      case MyRequestKind.expense:
        ExpenseDetailDialog.show(context, item.expense!);
        break;
      case MyRequestKind.attendanceCorrection:
        showMyCorrectionDetailSheet(context, item.correction!);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlueHeroBanner(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Requests', style: AppTextStyles.h4.copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    'Track the status of your leave, WFH, expense and attendance requests',
                    style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            const _MyRequestsTypeTabsRow(),
            const _MyRequestsToolbar(),
            Expanded(
              child: _MyRequestsList(onOpenDetail: (item) => _openDetail(context, item)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Type tabs row (All / Leave / WFH / Expense / Attendance Correction) ────────

class _MyRequestsTypeTabsRow extends ConsumerWidget {
  const _MyRequestsTypeTabsRow();

  static String _labelFor(MyRequestsTypeTab t) => switch (t) {
        MyRequestsTypeTab.all => 'All',
        MyRequestsTypeTab.leave => 'Leave',
        MyRequestsTypeTab.wfh => 'Work From Home',
        MyRequestsTypeTab.expense => 'Expense',
        MyRequestsTypeTab.attendanceCorrection => 'Attendance Correction',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(myRequestsTypeTabProvider);
    final counts = ref.watch(myRequestsTypeTabCountsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 0, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          children: MyRequestsTypeTab.values
              .map((t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _TypeTabChip(
                      label: _labelFor(t),
                      count: counts[t] ?? 0,
                      selected: active == t,
                      onTap: () => ref.read(myRequestsTypeTabProvider.notifier).state = t,
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
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

// ── Toolbar — search / status filter / date range ───────────────────────────────

class _MyRequestsToolbar extends ConsumerStatefulWidget {
  const _MyRequestsToolbar();

  @override
  ConsumerState<_MyRequestsToolbar> createState() => _MyRequestsToolbarState();
}

class _MyRequestsToolbarState extends ConsumerState<_MyRequestsToolbar> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: ref.read(myRequestsSearchQueryProvider));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final current = isFrom ? ref.read(myRequestsDateFromProvider) : ref.read(myRequestsDateToProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    if (isFrom) {
      ref.read(myRequestsDateFromProvider.notifier).state = picked;
    } else {
      ref.read(myRequestsDateToProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFrom = ref.watch(myRequestsDateFromProvider);
    final dateTo = ref.watch(myRequestsDateToProvider);
    final isLoading = ref.watch(myRequestsProvider).isLoading;

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
                  onChanged: (v) => ref.read(myRequestsSearchQueryProvider.notifier).state = v,
                  decoration: InputDecoration(
                    hintText: 'Search by title or request ID',
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
                  onClear:
                      dateFrom == null ? null : () => ref.read(myRequestsDateFromProvider.notifier).state = null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateButton(
                  label: 'To',
                  date: dateTo,
                  onTap: () => _pickDate(isFrom: false),
                  onClear: dateTo == null ? null : () => ref.read(myRequestsDateToProvider.notifier).state = null,
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
        onPressed: isLoading ? null : () => ref.read(myRequestsProvider.notifier).refresh(),
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
    MapEntry('all', 'All Statuses'),
    MapEntry('pending', 'Pending'),
    MapEntry('approved', 'Approved'),
    MapEntry('rejected', 'Rejected'),
    MapEntry('cancelled', 'Cancelled'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myRequestsStatusFilterProvider);
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
              .map((o) => DropdownMenuItem(value: o.key, child: Text(o.value, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) {
            if (v != null) ref.read(myRequestsStatusFilterProvider.notifier).state = v;
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
  const _DateButton({required this.label, required this.date, required this.onTap, this.onClear});

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
            Expanded(child: Text(text, style: AppTextStyles.caption.copyWith(fontSize: 10.5), overflow: TextOverflow.ellipsis)),
            if (onClear != null)
              GestureDetector(onTap: onClear, child: Icon(Icons.close, size: 12, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

// ── List ──────────────────────────────────────────────────────────────────────

Color _statusColorFor(MyRequestDisplayStatus s) => switch (s) {
      MyRequestDisplayStatus.approved => AppColors.success,
      MyRequestDisplayStatus.rejected => AppColors.error,
      MyRequestDisplayStatus.cancelled => AppColors.textSecondary,
      MyRequestDisplayStatus.pending => AppColors.warning,
    };

String _statusLabelFor(MyRequestDisplayStatus s) => switch (s) {
      MyRequestDisplayStatus.approved => 'Approved',
      MyRequestDisplayStatus.rejected => 'Rejected',
      MyRequestDisplayStatus.cancelled => 'Cancelled',
      MyRequestDisplayStatus.pending => 'Pending',
    };

IconData _iconFor(MyRequestKind k) => switch (k) {
      MyRequestKind.leave => Icons.beach_access_outlined,
      MyRequestKind.wfh => Icons.home_work_outlined,
      MyRequestKind.expense => Icons.receipt_long_outlined,
      MyRequestKind.attendanceCorrection => Icons.edit_calendar_outlined,
    };

class _MyRequestsList extends ConsumerWidget {
  final ValueChanged<MyRequestItem> onOpenDetail;
  const _MyRequestsList({required this.onOpenDetail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(filteredMyRequestItemsProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(myRequestsProvider.notifier).refresh(),
      child: itemsAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: AppErrorState(
              message: userFriendlyMessage(e),
              onRetry: () => ref.read(myRequestsProvider.notifier).refresh(),
            ),
          ),
        ),
        data: (items) => items.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: const AppEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No requests found',
                    message: 'No requests match the current filters.',
                  ),
                ),
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = items[i];
                  return _MyRequestCard(item: item, onTap: () => onOpenDetail(item));
                },
              ),
      ),
    );
  }
}

class _MyRequestCard extends StatelessWidget {
  final MyRequestItem item;
  final VoidCallback onTap;
  const _MyRequestCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sc = _statusColorFor(item.displayStatus);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 3, color: sc),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(_iconFor(item.kind), size: 17, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(item.title,
                                  style: AppTextStyles.label.copyWith(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: sc.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_statusLabelFor(item.displayStatus),
                                  style: AppTextStyles.caption
                                      .copyWith(fontSize: 9.5, fontWeight: FontWeight.w700, color: sc)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(item.requestCode,
                            style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: AppColors.textHint)),
                        const SizedBox(height: 3),
                        Text(item.detailSecondary,
                            style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Text(_fmtShortDate(item.submittedAt),
                                style: AppTextStyles.caption.copyWith(fontSize: 10.5)),
                            if (item.approver.isNotEmpty && item.approver != '—') ...[
                              const SizedBox(width: 10),
                              Icon(Icons.person_outline, size: 11, color: AppColors.textHint),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(item.approver,
                                    style: AppTextStyles.caption.copyWith(fontSize: 10.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtShortDate(DateTime d) {
  if (d.millisecondsSinceEpoch == 0) return '—';
  const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month]} ${d.year}';
}
