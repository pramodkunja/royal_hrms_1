import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/approvals_providers.dart';
import 'approval_detail_sheet.dart';
import 'approve_reject_dialog.dart';

Color _statusColorFor(String status) => switch (status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      'cancelled' => AppColors.textSecondary,
      _ => AppColors.warning,
    };

String _statusLabelFor(String status) => switch (status) {
      'pending' => 'Pending',
      'l2_pending' => 'Pending HR',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'cancelled' => 'Cancelled',
      _ => status,
    };

class ApprovalsList extends ConsumerWidget {
  const ApprovalsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(filteredApprovalItemsProvider);
    final selected = ref.watch(approvalsSelectedIdsProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(unifiedTeamApprovalsProvider.notifier).refresh(),
      child: itemsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _errorView(friendlyApprovalsError(e)),
        data: (items) => items.isEmpty
            ? _emptyView()
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final key = approvalsItemKey(item);
                  return _ApprovalCard(
                    item: item,
                    selected: selected.contains(key),
                    onSelectChanged: (v) {
                      final next = {...selected};
                      if (v) {
                        next.add(key);
                      } else {
                        next.remove(key);
                      }
                      ref.read(approvalsSelectedIdsProvider.notifier).state = next;
                    },
                    onTap: () => showApprovalDetailSheet(context, item),
                  );
                },
              ),
      ),
    );
  }
}

Widget _emptyView() {
  return Center(
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist_outlined, size: 44, color: AppColors.success),
            const SizedBox(height: 10),
            Text('No requests match the current filters.',
                style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

Widget _errorView(String message) {
  return SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
    ),
  );
}

// ── Bulk action bar ──────────────────────────────────────────────────────────

class ApprovalsBulkActionBar extends ConsumerStatefulWidget {
  const ApprovalsBulkActionBar({super.key});

  @override
  ConsumerState<ApprovalsBulkActionBar> createState() => _ApprovalsBulkActionBarState();
}

class _ApprovalsBulkActionBarState extends ConsumerState<ApprovalsBulkActionBar> {
  bool _busy = false;

  List<UnifiedApprovalItem> _resolveSelected() {
    final selectedKeys = ref.read(approvalsSelectedIdsProvider);
    final all = ref.read(unifiedTeamApprovalsProvider).valueOrNull ?? const <UnifiedApprovalItem>[];
    return all.where((i) => selectedKeys.contains(approvalsItemKey(i))).toList();
  }

  Future<void> _bulkApprove() async {
    final items = _resolveSelected();
    if (items.isEmpty) return;
    // A mixed batch (any non-expense row) gets the remarks dialog; a
    // pure-expense batch gets the plain confirm (no remarks field exists).
    final needsRemarks = items.any((i) => i.kind != UnifiedApprovalKind.expense);
    String? remarks;
    if (needsRemarks) {
      final result =
          await showRemarksDialog(context, forReject: false, title: 'Approve ${items.length} Selected');
      if (result == null || !mounted) return;
      remarks = result;
    } else {
      final confirmed =
          await showConfirmDialog(context, forReject: false, title: 'Approve ${items.length} Selected?');
      if (!confirmed || !mounted) return;
    }
    setState(() => _busy = true);
    final outcome = await ref
        .read(unifiedTeamApprovalsProvider.notifier)
        .bulkAction(items, approve: true, remarks: remarks);
    if (!mounted) return;
    setState(() => _busy = false);
    ref.read(approvalsSelectedIdsProvider.notifier).state = {};
    _showResultSnack(outcome);
  }

  Future<void> _bulkReject() async {
    final items = _resolveSelected();
    if (items.isEmpty) return;
    // A bulk reject may mix leave/expense/correction rows — always show ONE
    // remarks dialog for the whole batch; the remarks are passed through to
    // leave/correction calls and simply not sent for any expense rows.
    final result =
        await showRemarksDialog(context, forReject: true, title: 'Reject ${items.length} Selected');
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    final outcome = await ref
        .read(unifiedTeamApprovalsProvider.notifier)
        .bulkAction(items, approve: false, remarks: result);
    if (!mounted) return;
    setState(() => _busy = false);
    ref.read(approvalsSelectedIdsProvider.notifier).state = {};
    _showResultSnack(outcome);
  }

  void _showResultSnack(({int succeeded, int failed}) outcome) {
    final message = outcome.failed > 0
        ? '${outcome.succeeded} updated, ${outcome.failed} failed — please retry those individually.'
        : '${outcome.succeeded} updated successfully.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: outcome.failed > 0 ? AppColors.warning : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(approvalsSelectedIdsProvider);
    if (selected.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('${selected.length} selected',
                style: AppTextStyles.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: _busy ? null : () => ref.read(approvalsSelectedIdsProvider.notifier).state = {},
            child: const Text('Clear', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            onPressed: _busy ? null : _bulkReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Reject Selected', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: _busy ? null : _bulkApprove,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: _busy
                ? const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Approve Selected', style: TextStyle(fontSize: 12)),
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
  final ValueChanged<bool> onSelectChanged;
  final VoidCallback onTap;
  const _ApprovalCard({
    required this.item,
    required this.selected,
    required this.onSelectChanged,
    required this.onTap,
  });

  @override
  ConsumerState<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends ConsumerState<_ApprovalCard> {
  bool _loading = false;

  Future<void> _approve() async {
    final item = widget.item;
    String? remarks;
    if (item.kind == UnifiedApprovalKind.expense) {
      final confirmed = await showConfirmDialog(context, forReject: false);
      if (!confirmed || !mounted) return;
    } else {
      final result = await showRemarksDialog(context, forReject: false);
      if (result == null || !mounted) return;
      remarks = result;
    }
    setState(() => _loading = true);
    final err = await ref.read(unifiedTeamApprovalsProvider.notifier).approve(item, remarks: remarks);
    if (!mounted) return;
    setState(() => _loading = false);
    _showResult(err, approve: true);
  }

  Future<void> _reject() async {
    final item = widget.item;
    String remarks = '';
    if (item.kind == UnifiedApprovalKind.expense) {
      final confirmed = await showConfirmDialog(context, forReject: true);
      if (!confirmed || !mounted) return;
    } else {
      final result = await showRemarksDialog(context, forReject: true);
      if (result == null || !mounted) return;
      remarks = result;
    }
    setState(() => _loading = true);
    final err = await ref.read(unifiedTeamApprovalsProvider.notifier).reject(item, remarks: remarks);
    if (!mounted) return;
    setState(() => _loading = false);
    _showResult(err, approve: false);
  }

  void _showResult(String? err, {required bool approve}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? (approve ? 'Approved.' : 'Rejected.')),
      backgroundColor: err != null ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final sc = _statusColorFor(item.status);
    final showActions = item.canAction && item.isPending;
    final secondary = item.department.isNotEmpty ? item.department : item.secondaryText;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 3, color: sc),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: widget.selected,
                        onChanged: item.canAction ? (v) => widget.onSelectChanged(v ?? false) : null,
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.employeeName.isNotEmpty ? item.employeeName : 'Unknown',
                                style: AppTextStyles.label.copyWith(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(
                              [item.employeeCode, secondary].where((s) => s.isNotEmpty).join(' · '),
                              style: AppTextStyles.caption.copyWith(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(item.typeLabel,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.primaryLine,
                            style: AppTextStyles.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(item.secondaryLine,
                            style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(item.tertiaryLine,
                            style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textHint)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: sc.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_statusLabelFor(item.status),
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 9.5, fontWeight: FontWeight.w700, color: sc)),
                        ),
                      ],
                    ),
                  ),
                  if (showActions) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 40),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _loading ? null : _approve,
                              icon: const Icon(Icons.check, size: 14),
                              label: const Text('Approve',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _loading ? null : _reject,
                              icon: const Icon(Icons.close, size: 14),
                              label: const Text('Reject',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
