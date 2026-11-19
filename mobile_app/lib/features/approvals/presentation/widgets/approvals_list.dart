import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../attendance/presentation/widgets/late_justification_review.dart' show showLateJustificationReview;
import '../providers/approvals_providers.dart';
import 'approval_detail_sheet.dart';
import 'approvals_kit.dart';
import 'approvals_ui.dart';
import 'approve_reject_dialog.dart';
import 'resolve_payslip_query_dialog.dart';

ApprovalsTone _statusToneFor(String status) => switch (approvalDisplayStatus(status)) {
      'approved' => ApprovalsTone.success,
      'rejected' => ApprovalsTone.error,
      'cancelled' => ApprovalsTone.neutral,
      _ => ApprovalsTone.warning,
    };

String _statusLabelFor(String status) => switch (status) {
      'pending' => 'Pending',
      'l2_pending' || 'stage2_pending' => 'Pending HR',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'cancelled' => 'Cancelled',
      _ => status,
    };

void _snack(BuildContext context, String message, {required bool error}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? AppColors.error : AppColors.success,
    behavior: SnackBarBehavior.floating,
  ));
}

/// Opens [item]: a separation goes to its own detail screen (where each
/// stage is decided — web routes it the same way), and the inbox is
/// reloaded on return so its status reflects what was decided there.
/// Everything else opens the detail sheet.
Future<void> openApprovalItem(BuildContext context, WidgetRef ref, UnifiedApprovalItem item) async {
  if (item.opensDetailScreen) {
    await context.push(AppRoutes.separationDetailPath(item.sourceId));
    await ref.read(unifiedTeamApprovalsProvider.notifier).refresh();
    return;
  }
  if (item.isLateJustification) {
    // Web: a late justification opens LateJustificationReviewModal.
    final msg = await showLateJustificationReview(context, item.correction!);
    if (msg == null) return;
    await ref.read(unifiedTeamApprovalsProvider.notifier).refresh();
    if (!context.mounted) return;
    _snack(context, msg, error: false);
    return;
  }
  showApprovalDetailSheet(context, item);
}

class ApprovalsList extends ConsumerWidget {
  /// Summary cards, type tabs and filters: they scroll with the list (one
  /// scroll view, no nested scrolling, nothing pinned that could crowd a small
  /// screen or large text).
  const ApprovalsList({super.key, this.header = const []});

  final List<Widget> header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(filteredApprovalItemsProvider);
    final selected = ref.watch(approvalsSelectedIdsProvider);
    final status = ref.watch(approvalsStatusFilterProvider);
    final search = ref.watch(approvalsSearchQueryProvider).trim();
    final from = ref.watch(approvalsDateFromProvider);
    final to = ref.watch(approvalsDateToProvider);
    final requestedPage = ref.watch(approvalsPageProvider);
    final selectionMode = ref.watch(approvalsSelectionModeProvider);

    final items = itemsAsync.valueOrNull;
    Widget body;
    if (items == null) {
      body = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...header,
            if (itemsAsync.hasError)
              ApprovalsEmptyState.forError(itemsAsync.error!,
                  onRetry: () => ref.read(unifiedTeamApprovalsProvider.notifier).refresh())
            else
              const ApprovalsLoading(),
          ],
        ),
      );
    } else {
      final pages = ApprovalsPager.pagesFor(items.length);
      final page = requestedPage.clamp(1, pages);
      final pageItems = items.skip((page - 1) * kApprovalsPageSize).take(kApprovalsPageSize).toList();
      final pageKeys = [
        for (final i in pageItems)
          if (i.canAction && i.selectable) approvalsItemKey(i)
      ];
      final allPageSelected = pageKeys.isNotEmpty && pageKeys.every(selected.contains);
      final plainDefault = status == 'pending' && search.isEmpty && from == null && to == null;

      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ...header,
          if (itemsAsync.hasError)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(friendlyApprovalsError(itemsAsync.error!),
                  key: const Key('approvals-refresh-error'),
                  style: AppTextStyles.caption.copyWith(color: AppColors.error)),
            ),
          if (items.isEmpty)
            plainDefault
                // Web's own empty state (ta-empty): nothing is waiting.
                ? const ApprovalsEmptyState(
                    kind: ApprovalsStateKind.empty,
                    title: 'You’re all caught up!',
                    message: 'No approval requests are waiting for your action.',
                  )
                : ApprovalsEmptyState(
                    kind: ApprovalsStateKind.noMatch,
                    title: 'No requests match the current filters.',
                    message: 'Try another status, a wider date range or a different search.',
                    actionLabel: 'Clear filters',
                    onAction: () => clearApprovalsFilters(ref),
                  )
          else ...[
            _ResultsBar(
              count: items.length,
              selectionMode: selectionMode,
              canSelect: pageKeys.isNotEmpty,
              allPageSelected: allPageSelected,
              onEnter: () => ref.read(approvalsSelectionModeProvider.notifier).state = true,
              onDone: () {
                ref.read(approvalsSelectionModeProvider.notifier).state = false;
                ref.read(approvalsSelectedIdsProvider.notifier).state = {};
              },
              onTogglePage: (on) {
                final next = {...selected};
                if (on) {
                  next.addAll(pageKeys);
                } else {
                  next.removeAll(pageKeys);
                }
                ref.read(approvalsSelectedIdsProvider.notifier).state = next;
              },
            ),
            for (final item in pageItems) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ApprovalCard(
                  key: ValueKey(approvalsItemKey(item)),
                  item: item,
                  selected: selected.contains(approvalsItemKey(item)),
                  selectionMode: selectionMode,
                  onLongPress: () {
                    if (!(item.canAction && item.selectable)) return;
                    ref.read(approvalsSelectionModeProvider.notifier).state = true;
                    ref.read(approvalsSelectedIdsProvider.notifier).state = {...selected, approvalsItemKey(item)};
                  },
                  onSelectChanged: (v) {
                    final key = approvalsItemKey(item);
                    final next = {...selected};
                    if (v) {
                      next.add(key);
                    } else {
                      next.remove(key);
                    }
                    ref.read(approvalsSelectedIdsProvider.notifier).state = next;
                  },
                  onTap: () => openApprovalItem(context, ref, item),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ApprovalsPager(
                page: page,
                total: items.length,
                onPage: (p) => ref.read(approvalsPageProvider.notifier).state = p,
              ),
            ),
          ],
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(unifiedTeamApprovalsProvider.notifier).refresh(),
      child: body,
    );
  }
}

// ── Bulk action bar ──────────────────────────────────────────────────────────

class ApprovalsBulkActionBar extends ConsumerStatefulWidget {
  const ApprovalsBulkActionBar({super.key});

  @override
  ConsumerState<ApprovalsBulkActionBar> createState() => _ApprovalsBulkActionBarState();
}

class _ApprovalsBulkActionBarState extends ConsumerState<ApprovalsBulkActionBar> {
  /// Guard against a second batch: set before any await.
  bool _busy = false;

  /// The batch is actually running (spinner), as opposed to the dialog being open.
  bool _working = false;

  List<UnifiedApprovalItem> _resolveSelected() {
    final selectedKeys = ref.read(approvalsSelectedIdsProvider);
    final all = ref.read(unifiedTeamApprovalsProvider).valueOrNull ?? const <UnifiedApprovalItem>[];
    return all.where((i) => selectedKeys.contains(approvalsItemKey(i))).toList();
  }

  Future<void> _run({required bool approve}) async {
    if (_busy) return;
    _busy = true; // before any await: a second tap cannot start a second batch
    setState(() {});
    try {
      final items = _resolveSelected();
      if (items.isEmpty) return;
      final remarks = await showBulkConfirmDialog(context, approve: approve, count: items.length);
      if (remarks == null || !mounted) return;
      setState(() => _working = true);
      final outcome =
          await ref.read(unifiedTeamApprovalsProvider.notifier).bulkAction(items, approve: approve, remarks: remarks);
      if (!mounted) return;
      ref.read(approvalsSelectedIdsProvider.notifier).state = {};
      _snack(
        context,
        approvalsBulkMessage(succeeded: outcome.succeeded, failed: outcome.failed, approve: approve),
        error: outcome.failed > 0,
      );
    } finally {
      _busy = false;
      if (mounted) setState(() => _working = false);
    }
  }

  void _selectAll() {
    final all = ref.read(filteredApprovalItemsProvider).valueOrNull ?? const <UnifiedApprovalItem>[];
    ref.read(approvalsSelectedIdsProvider.notifier).state = {
      ...ref.read(approvalsSelectedIdsProvider),
      for (final i in all)
        if (i.canAction && i.selectable) approvalsItemKey(i),
    };
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(approvalsSelectedIdsProvider);
    if (selected.isEmpty) return const SizedBox.shrink();
    final filtered = ref.watch(filteredApprovalItemsProvider).valueOrNull ?? const <UnifiedApprovalItem>[];
    final selectable = filtered.where((i) => i.canAction && i.selectable).length;
    final allSelected = selectable > 0 && selected.length >= selectable;

    // Pinned like My Profile's Save bar: an elevated surface, the count and the
    // shortcuts on top, the two decisions below (stacked when the screen is tight).
    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${selected.length} selected',
                    style: AppTextStyles.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
                if (!allSelected && selectable > 0)
                  TextButton(
                    key: const Key('approvals-select-all'),
                    style: approvalsTextButtonStyle(minHeight: 40),
                    onPressed: _busy ? null : _selectAll,
                    child: Text('Select all $selectable'),
                  ),
                TextButton(
                  key: const Key('approvals-clear'),
                  style: approvalsTextButtonStyle(minHeight: 40),
                  onPressed: _busy ? null : () => ref.read(approvalsSelectedIdsProvider.notifier).state = {},
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ApprovalsDecisionButtons(
              approveKey: const Key('approvals-bulk-approve'),
              rejectKey: const Key('approvals-bulk-reject'),
              approveLabel: 'Approve Selected',
              rejectLabel: 'Reject Selected',
              busy: _working,
              onApprove: () => _busy ? null : _run(approve: true),
              onReject: () => _busy ? null : _run(approve: false),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Results bar ────────────────────────────────────────────────────────────────

/// "12 requests" + Select / Done, and in selection mode a select-all-on-page row.
class _ResultsBar extends StatelessWidget {
  const _ResultsBar({
    required this.count,
    required this.selectionMode,
    required this.canSelect,
    required this.allPageSelected,
    required this.onEnter,
    required this.onDone,
    required this.onTogglePage,
  });

  final int count;
  final bool selectionMode;
  final bool canSelect;
  final bool allPageSelected;
  final VoidCallback onEnter;
  final VoidCallback onDone;
  final ValueChanged<bool> onTogglePage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$count request${count == 1 ? '' : 's'}',
                    key: const Key('approvals-count'),
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              if (selectionMode)
                TextButton(
                  key: const Key('approvals-select-done'),
                  onPressed: onDone,
                  style: approvalsTextButtonStyle(),
                  child: const Text('Done'),
                )
              else if (canSelect)
                OutlinedButton.icon(
                  key: const Key('approvals-select-mode'),
                  onPressed: onEnter,
                  icon: const Icon(Icons.checklist_rtl, size: 16),
                  label: const Text('Select'),
                  style: approvalsOutlinedButtonStyle(minHeight: 40),
                ),
            ],
          ),
          if (selectionMode && canSelect)
            InkWell(
              key: const Key('approvals-select-page'),
              onTap: () => onTogglePage(!allPageSelected),
              child: Row(
                children: [
                  Checkbox(
                    activeColor: AppColors.primary,
                    value: allPageSelected,
                    onChanged: (v) => onTogglePage(v ?? false),
                    visualDensity: VisualDensity.compact,
                  ),
                  Flexible(
                    child: Text('Select all on this page',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _ApprovalCard extends ConsumerStatefulWidget {
  final UnifiedApprovalItem item;
  final bool selected;
  final bool selectionMode;
  final ValueChanged<bool> onSelectChanged;
  final VoidCallback onLongPress;
  final VoidCallback onTap;
  const _ApprovalCard({
    super.key,
    required this.item,
    required this.selected,
    required this.selectionMode,
    required this.onSelectChanged,
    required this.onLongPress,
    required this.onTap,
  });

  @override
  ConsumerState<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends ConsumerState<_ApprovalCard> {
  /// Set synchronously on the first tap (before the dialog opens), so a second
  /// tap can neither open a second dialog nor send a second request.
  bool _busy = false;

  Future<void> _decide({required bool approve}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final item = widget.item;
      String remarks = '';
      if (item.kind == UnifiedApprovalKind.expense) {
        // The backend stores no remarks for an expense decision (ExpenseDetailView
        // saves status only), so a note field would be fake — confirm only.
        final confirmed = await showConfirmDialog(context, forReject: !approve);
        if (!confirmed || !mounted) return;
      } else {
        final result = await showRemarksDialog(
          context,
          forReject: !approve,
          title: '${approve ? 'Approve' : 'Reject'} — ${item.employeeName}’s ${_noun(item)}',
        );
        if (result == null || !mounted) return;
        remarks = result;
      }
      final notifier = ref.read(unifiedTeamApprovalsProvider.notifier);
      final err =
          approve ? await notifier.approve(item, remarks: remarks) : await notifier.reject(item, remarks: remarks);
      if (!mounted) return;
      _snack(context, err ?? approvalSuccessMessage(item, approve: approve), error: err != null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _noun(UnifiedApprovalItem item) => switch (item.kind) {
        UnifiedApprovalKind.leave => 'leave',
        UnifiedApprovalKind.wfh => 'work from home request',
        UnifiedApprovalKind.attendanceCorrection => 'correction',
        _ => 'request',
      };

  Future<void> _resolve() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final resolved = await showResolvePayslipQueryDialog(context, widget.item);
      if (!resolved || !mounted) return;
      _snack(context, 'Payslip query resolved.', error: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// What this request is, composed for its kind — a headline with quiet chips, the
  /// facts an approver reads first as natural lines, and the employee's reason.
  Widget _body(UnifiedApprovalItem item) {
    final children = <Widget>[];
    void gap([double h = 10]) => children.add(SizedBox(height: h));
    final reason = item.reason.trim();

    switch (item.kind) {
      case UnifiedApprovalKind.leave:
        final r = item.leave!;
        children.add(ApprovalsHeadline(
          icon: Icons.beach_access_outlined,
          title: r.leaveType.isEmpty ? 'Leave' : r.leaveType,
          chips: [
            if (r.durationDisplay.isNotEmpty) ApprovalsChip(r.durationDisplay),
            ApprovalsChip(item.tertiaryLine.split(' · ').first),
            if (r.lopDays > 0) ApprovalsChip('${approvalsNumber(r.lopDays)} LOP', tone: ApprovalsTone.warning),
          ],
        ));
        gap(12);
        children.add(ApprovalsInfoRow(Icons.calendar_today_outlined, item.secondaryLine, strong: true));
      case UnifiedApprovalKind.wfh:
        children.add(ApprovalsHeadline(
          icon: Icons.home_work_outlined,
          title: 'Work From Home',
          chips: [ApprovalsChip(item.tertiaryLine)],
        ));
        gap(12);
        children.add(ApprovalsInfoRow(Icons.calendar_today_outlined, item.secondaryLine, strong: true));
      case UnifiedApprovalKind.expense:
        children.add(ApprovalsHeadline(
          icon: Icons.receipt_long_outlined,
          title: item.primaryLine,
          chips: [if (item.tertiaryLine.isNotEmpty) ApprovalsChip(item.tertiaryLine)],
        ));
        gap(12);
        children.add(ApprovalsKeyFigure(item.secondaryLine));
      case UnifiedApprovalKind.attendanceCorrection:
        children.add(ApprovalsHeadline(icon: Icons.edit_calendar_outlined, title: item.primaryLine));
        gap(12);
        children.add(ApprovalsInfoRow(Icons.event_outlined, item.tertiaryLine, strong: true));
        gap(6);
        children.add(ApprovalsInfoRow(Icons.schedule, item.secondaryLine));
      case UnifiedApprovalKind.separation:
        children.add(ApprovalsHeadline(
          icon: Icons.logout,
          title: item.primaryLine,
          chips: [if (item.tertiaryLine.isNotEmpty) ApprovalsChip(item.tertiaryLine)],
        ));
        gap(12);
        children.add(ApprovalsInfoRow(Icons.event_busy_outlined, item.secondaryLine, strong: true));
      case UnifiedApprovalKind.payslip:
        final period = item.payslipQuery?.cycleStart ?? '';
        children.add(ApprovalsHeadline(
          icon: Icons.request_quote_outlined,
          title: 'Payslip Query',
          chips: [if (period.isNotEmpty) ApprovalsChip('Pay period from $period')],
        ));
    }

    // The employee's words: the query itself for a payslip, the reason otherwise.
    final quote = item.isPayslipQuery ? item.secondaryLine : reason;
    if (quote.isNotEmpty && quote != '—') {
      gap(12);
      children.add(ApprovalsQuote(quote));
    }
    if (item.isPayslipQuery && item.tertiaryLine.isNotEmpty) {
      gap(8);
      children.add(ApprovalsFineprint(item.tertiaryLine));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget? _footer(UnifiedApprovalItem item) {
    if (widget.selectionMode) return null;
    final showActions = item.canAction && item.isPending && item.selectable;
    final showReview = item.canAction && item.isPending && (item.opensDetailScreen || item.isLateJustification);
    final showResolve = item.canAction && item.isPending && item.isPayslipQuery;
    final detailsKey = Key('approval-details-${item.sourceId}');
    if (showReview || showResolve) {
      // One decision button (the full decision is made on its own screen / form).
      final button = showReview
          ? FilledButton(
              key: Key('approval-review-${item.sourceId}'),
              onPressed: widget.onTap,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(0, 44)),
              child: const Text('Review & decide'),
            )
          : FilledButton(
              key: Key('approval-resolve-${item.sourceId}'),
              onPressed: _busy ? null : _resolve,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(0, 44)),
              child: const Text('Resolve'),
            );
      return Row(children: [
        if (showResolve)
          TextButton.icon(
            key: detailsKey,
            onPressed: widget.onTap,
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('Details'),
            style: approvalsTextButtonStyle(),
          ),
        const Spacer(),
        button,
      ]);
    }
    return ApprovalsActionRow(
      detailsKey: detailsKey,
      rejectKey: showActions ? Key('approval-reject-${item.sourceId}') : null,
      approveKey: showActions ? Key('approval-approve-${item.sourceId}') : null,
      busy: _busy,
      onDetails: widget.onTap,
      onReject: showActions ? () => _decide(approve: false) : null,
      onApprove: showActions ? () => _decide(approve: true) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final secondary = item.department.isNotEmpty ? item.department : item.secondaryText;
    final selectable = item.canAction && item.selectable;

    return ApprovalsCardShell(
      name: item.employeeName,
      idText: item.employeeCode.isEmpty ? null : item.employeeCode,
      meta: secondary,
      badge: ApprovalsBadge(_statusLabelFor(item.status), _statusToneFor(item.status)),
      note: ApprovalsFineprint('Submitted ${approvalsSubmitted(item.submittedAt)}'),
      leading: widget.selectionMode
          ? SizedBox(
              width: 28,
              child: Checkbox(
                activeColor: AppColors.primary,
                value: widget.selected,
                onChanged: selectable ? (v) => widget.onSelectChanged(v ?? false) : null,
                visualDensity: VisualDensity.compact,
              ),
            )
          : null,
      selected: widget.selected,
      footer: _footer(item),
      onLongPress: widget.onLongPress,
      onTap: widget.selectionMode ? (selectable ? () => widget.onSelectChanged(!widget.selected) : null) : widget.onTap,
      child: _body(item),
    );
  }
}
