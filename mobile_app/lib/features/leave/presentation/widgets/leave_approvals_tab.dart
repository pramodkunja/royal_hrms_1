import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/leave_entity.dart';
import '../providers/leave_providers.dart';

// ── Date formatter ────────────────────────────────────────────────────────────

String _fmtIso(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month]}';
  } catch (_) {
    return iso;
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

class LeaveApprovalsTab extends ConsumerStatefulWidget {
  const LeaveApprovalsTab({super.key});

  @override
  ConsumerState<LeaveApprovalsTab> createState() => _LeaveApprovalsTabState();
}

class _LeaveApprovalsTabState extends ConsumerState<LeaveApprovalsTab> {
  bool _showPending = true;
  bool _actionLoading = false;

  Future<void> _approve(String id) async {
    setState(() => _actionLoading = true);
    final err = await ref
        .read(leaveRequestsProvider.notifier)
        .approveRequest(id);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showRejectDialog(String id) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
            ),
            const SizedBox(width: 10),
            Text('Reject Request', style: AppTextStyles.label),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rejection Reason *',
                style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              maxLines: 3,
              maxLength: 300,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'Explain why this leave request is being rejected…'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Submit Rejection'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    setState(() => _actionLoading = true);
    final err = await ref
        .read(leaveRequestsProvider.notifier)
        .rejectRequest(id, reason);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(leaveRequestsProvider);
    final allRequests = requestsAsync.valueOrNull ?? [];
    final pending = allRequests.where((r) => r.isPending).toList();
    final history =
        allRequests.where((r) => !r.isPending).toList();
    final rows = _showPending ? pending : history;
    final pendingCount = pending.length;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(leaveRequestsProvider);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sub-tab pills ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                _SubTabPill(
                  label: 'Pending',
                  count: pendingCount,
                  selected: _showPending,
                  onTap: () => setState(() => _showPending = true),
                ),
                const SizedBox(width: 8),
                _SubTabPill(
                  label: 'History',
                  selected: !_showPending,
                  onTap: () => setState(() => _showPending = false),
                ),
              ],
            ),
          ),

          // ── Card header ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.playlist_add_check_outlined,
                      size: 14, color: AppColors.success),
                ),
                const SizedBox(width: 8),
                Text(
                  _showPending ? 'Pending Approvals' : 'Approval History',
                  style: AppTextStyles.label,
                ),
                if (_showPending && pendingCount > 0) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Text('$pendingCount awaiting',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          Expanded(
            child: requestsAsync.isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : requestsAsync.hasError
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                            'Could not load requests: ${requestsAsync.error}',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.error)),
                      )
                    : rows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 48, color: AppColors.success),
                                const SizedBox(height: 10),
                                Text(
                                  _showPending
                                      ? 'All caught up — no pending requests.'
                                      : 'No history to show.',
                                  style: AppTextStyles.bodySecondary,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _ApprovalCard(
                              request: rows[i],
                              showActions: _showPending,
                              actionLoading: _actionLoading,
                              onApprove: () => _approve(rows[i].id),
                              onReject: () => _showRejectDialog(rows[i].id),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-tab pill ──────────────────────────────────────────────────────────────

class _SubTabPill extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _SubTabPill({
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : AppColors.textSecondary)),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$count',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? Colors.white
                              : AppColors.warning)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Approval Card ─────────────────────────────────────────────────────────────

class _ApprovalCard extends StatelessWidget {
  final LeaveRequestEntity request;
  final bool showActions;
  final bool actionLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApprovalCard({
    required this.request,
    required this.showActions,
    required this.actionLoading,
    required this.onApprove,
    required this.onReject,
  });

  static Color _statusColor(String s) => switch (s) {
    'approved'  => AppColors.success,
    'rejected'  => AppColors.error,
    'cancelled' => AppColors.textSecondary,
    _           => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(request.status);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 3, color: sc),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.employee.isNotEmpty
                                ? request.employee
                                : 'You',
                            style: AppTextStyles.label.copyWith(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (request.department.isNotEmpty)
                            Text(request.department,
                                style: AppTextStyles.caption
                                    .copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                    if (!showActions)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: sc.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sc.withValues(alpha: 0.3)),
                        ),
                        child: Text(request.status,
                            style: AppTextStyles.caption.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: sc)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(request.leaveTypeCode,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 10)),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(request.leaveType,
                          style:
                              AppTextStyles.caption.copyWith(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        size: 11, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${_fmtIso(request.from)} – ${_fmtIso(request.to)}',
                        style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text('${request.days}d',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.w700,
                              fontSize: 10)),
                    ),
                    const Spacer(),
                    if (request.appliedOn.isNotEmpty) ...[
                      const Icon(Icons.access_time_outlined,
                          size: 10, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text('Applied ${_fmtIso(request.appliedOn)}',
                          style:
                              AppTextStyles.caption.copyWith(fontSize: 10)),
                    ],
                  ],
                ),
                if (showActions) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: actionLoading ? null : onApprove,
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Approve',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: actionLoading ? null : onReject,
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text('Reject',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (request.isRejected &&
                    request.rejectReason != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.message_outlined,
                            size: 10, color: AppColors.error),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(request.rejectReason!,
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.error, fontSize: 10),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
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
    );
  }
}
