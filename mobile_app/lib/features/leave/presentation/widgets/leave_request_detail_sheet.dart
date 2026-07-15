import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/leave_entity.dart';
import '../providers/leave_providers.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

/// Opens the leave request detail sheet — mirrors web's
/// LeaveRequestDetailModal. Shows [initial] immediately (no loading flash)
/// while [leaveRequestDetailProvider] quietly refreshes it in the background.
///
/// [canApprove] should only be true when the sheet is opened from an
/// approver context (an approval-queue row) — it gates the Approve/Reject
/// footer actions. Cancel is gated separately, based on whether the viewer
/// is the request's own owner.
Future<void> showLeaveRequestDetailSheet(
  BuildContext context, {
  required LeaveRequestEntity initial,
  bool canApprove = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        LeaveRequestDetailSheet(initial: initial, canApprove: canApprove),
  );
}

Color _statusColor(String s) => switch (s) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      'cancelled' => AppColors.textSecondary,
      _ => AppColors.warning,
    };

Color _decisionColor(String? s) => switch (s) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      _ => AppColors.warning,
    };

String _decisionLabel(String? s) => switch (s) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => 'Pending',
    };

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso.length >= 10 ? iso.substring(0, 10) : iso);
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${m[d.month]} ${d.year}';
  } catch (_) {
    return iso;
  }
}

String _fmtNum(num v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

// ── Widget ────────────────────────────────────────────────────────────────────

class LeaveRequestDetailSheet extends ConsumerStatefulWidget {
  final LeaveRequestEntity initial;
  final bool canApprove;
  const LeaveRequestDetailSheet({
    super.key,
    required this.initial,
    this.canApprove = false,
  });

  @override
  ConsumerState<LeaveRequestDetailSheet> createState() =>
      _LeaveRequestDetailSheetState();
}

class _LeaveRequestDetailSheetState
    extends ConsumerState<LeaveRequestDetailSheet> {
  bool _actionLoading = false;

  void _showError(String err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _approve(String id) async {
    setState(() => _actionLoading = true);
    final err =
        await ref.read(leaveRequestsProvider.notifier).approveRequest(id);
    // This sheet can be opened from the Dashboard's team-pending queue too —
    // that list lives in a separate provider (leaveTeamPendingProvider), so
    // it needs its own invalidation on top of leaveRequestsProvider's refresh.
    ref.invalidate(leaveTeamPendingProvider);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      _showError(err);
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.cancel_outlined,
                  size: 17, color: AppColors.error),
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
                  hintText:
                      'Explain why this leave request is being rejected…'),
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
    ref.invalidate(leaveTeamPendingProvider);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      _showError(err);
    }
  }

  Future<void> _cancelRequest(String id) async {
    setState(() => _actionLoading = true);
    final err =
        await ref.read(leaveRequestsProvider.notifier).cancelRequest(id);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      _showError(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync =
        ref.watch(leaveRequestDetailProvider(widget.initial.id));
    final r = detailAsync.valueOrNull ?? widget.initial;

    // `canApprove`/`canCancel` are real backend-computed fields (see
    // LeaveRequestEntity). widget.canApprove is only an initial optimistic
    // guess supplied by the caller before this sheet's background refresh
    // completes — once the refreshed entity is in, its own `canApprove`
    // wins as the authoritative source of truth. `canCancel` has no
    // caller-supplied guess to reconcile with, so it's used directly.
    final showApprove =
        (detailAsync.valueOrNull?.canApprove ?? widget.canApprove) &&
            r.isPending;
    final showCancel = r.canCancel;
    final sc = _statusColor(r.status);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.description_outlined,
                          size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Leave Request Details',
                              style: AppTextStyles.h4.copyWith(fontSize: 15)),
                          if (r.leaveType.isNotEmpty ||
                              r.durationDisplay.isNotEmpty)
                            Text(
                              [r.leaveType, r.durationDisplay]
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                              style:
                                  AppTextStyles.caption.copyWith(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),

              // ── Body ─────────────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (detailAsync.isLoading) ...[
                        Row(
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child:
                                  CircularProgressIndicator(strokeWidth: 1.5),
                            ),
                            const SizedBox(width: 6),
                            Text('Loading latest status…',
                                style: AppTextStyles.caption
                                    .copyWith(fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (detailAsync.hasError) ...[
                        Row(
                          children: [
                            Icon(Icons.error_outline,
                                size: 13, color: AppColors.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                  'Could not refresh — showing last known details.',
                                  style: AppTextStyles.caption.copyWith(
                                      fontSize: 11, color: AppColors.error)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Employee
                      Text('EMPLOYEE',
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 3),
                      Text(r.employee.isNotEmpty ? r.employee : 'You',
                          style: AppTextStyles.label.copyWith(fontSize: 13)),
                      Text(
                        [r.branch, r.department]
                                .where((s) => s.isNotEmpty)
                                .join(' · ')
                                .isEmpty
                            ? '—'
                            : [r.branch, r.department]
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),

                      const SizedBox(height: 14),
                      Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),

                      // Dates + days + status
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${_fmtDate(r.from)} → ${_fmtDate(r.to)}',
                                    style: AppTextStyles.caption
                                        .copyWith(fontSize: 11)),
                                const SizedBox(height: 4),
                                if (r.hasLopDays) ...[
                                  Text(
                                    '${r.leaveType}: ${_fmtNum(r.days - r.lopDays)} '
                                    'day${(r.days - r.lopDays) != 1 ? 's' : ''}',
                                    style: AppTextStyles.caption
                                        .copyWith(fontSize: 11),
                                  ),
                                  Text(
                                    'LOP: ${_fmtNum(r.lopDays)} day${r.lopDays != 1 ? 's' : ''}',
                                    style: AppTextStyles.caption.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.warning),
                                  ),
                                  Text(
                                    'Total: ${r.days} day${r.days != 1 ? 's' : ''}',
                                    style: AppTextStyles.label
                                        .copyWith(fontSize: 12),
                                  ),
                                ] else
                                  Text('${r.days} day${r.days != 1 ? 's' : ''}',
                                      style: AppTextStyles.label
                                          .copyWith(fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: sc.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: sc.withValues(alpha: 0.3)),
                            ),
                            child: Text(r.status,
                                style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: sc)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),

                      // Reason
                      Text('REASON',
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 3),
                      Text(r.reason.isNotEmpty ? r.reason : '—',
                          style: AppTextStyles.body.copyWith(fontSize: 13)),

                      const SizedBox(height: 14),
                      Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),

                      // Approval Flow
                      Text('APPROVAL FLOW',
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 10),
                      // Unified "who made the final call" line — approvedBy/
                      // approvedAt reflect the FINAL decision, which may differ
                      // from the last stage below (e.g. HR overturning a manager
                      // decision). The per-stage rows remain as the detailed
                      // breakdown.
                      if ((r.isApproved || r.isRejected) &&
                          r.approvedBy.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: sc.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: r.isApproved
                                    ? 'Approved by '
                                    : 'Rejected by ',
                                style: AppTextStyles.caption
                                    .copyWith(fontSize: 11),
                              ),
                              TextSpan(
                                text: r.approvedBy,
                                style:
                                    AppTextStyles.label.copyWith(fontSize: 12),
                              ),
                              if (r.approvedAt != null &&
                                  r.approvedAt!.isNotEmpty)
                                TextSpan(
                                  text: ' on ${_fmtDate(r.approvedAt)}',
                                  style: AppTextStyles.caption
                                      .copyWith(fontSize: 11),
                                ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      _ApprovalStageRow(
                        level: 'Manager Approval',
                        approverName: r.l1ApproverName,
                        decisionStatus: r.l1Status,
                        remarks: r.l1Remarks,
                        actionedAt: r.l1ActionedAt,
                      ),
                      if (r.l2ApproverName.isNotEmpty ||
                          r.l2Status != null) ...[
                        const SizedBox(height: 10),
                        _ApprovalStageRow(
                          level: 'HR Approval',
                          approverName: r.l2ApproverName,
                          decisionStatus: r.l2Status,
                          remarks: r.l2Remarks,
                          actionedAt: r.l2ActionedAt,
                        ),
                      ],

                      if ((r.handoverTo?.isNotEmpty ?? false) ||
                          (r.contactDuringLeave?.isNotEmpty ?? false) ||
                          (r.handoverNotes?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 14),
                        Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 12),
                        Text('HANDOVER & CONTACT',
                            style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        if (r.handoverTo?.isNotEmpty ?? false)
                          Text.rich(
                              TextSpan(children: [
                                const TextSpan(text: 'Handover to: '),
                                TextSpan(
                                    text: r.handoverTo,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ]),
                              style: AppTextStyles.body.copyWith(fontSize: 13)),
                        if (r.contactDuringLeave?.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text.rich(
                                TextSpan(children: [
                                  const TextSpan(text: 'Contact: '),
                                  TextSpan(
                                      text: r.contactDuringLeave,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ]),
                                style:
                                    AppTextStyles.body.copyWith(fontSize: 13)),
                          ),
                        if (r.handoverNotes?.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(r.handoverNotes!,
                                style: AppTextStyles.caption
                                    .copyWith(fontSize: 11)),
                          ),
                      ],

                      if (r.documentUrl != null &&
                          r.documentUrl!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => _openDocument(r.documentUrl!),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.attach_file,
                                  size: 15, color: AppColors.primary),
                              const SizedBox(width: 5),
                              Text('View attached document',
                                  style: AppTextStyles.label.copyWith(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Footer actions ───────────────────────────────────────────
              if (showApprove || showCancel)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showApprove) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _actionLoading
                                      ? null
                                      : () => _showRejectDialog(r.id),
                                  icon: const Icon(Icons.close, size: 14),
                                  label: const Text('Reject',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: BorderSide(
                                        color: AppColors.error),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _actionLoading
                                      ? null
                                      : () => _approve(r.id),
                                  icon: const Icon(Icons.check, size: 14),
                                  label: const Text('Approve',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (showApprove && showCancel)
                          const SizedBox(height: 8),
                        if (showCancel)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _actionLoading
                                  ? null
                                  : () => _cancelRequest(r.id),
                              icon: const Icon(Icons.cancel_outlined, size: 14),
                              label: const Text('Cancel Request',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: BorderSide(color: AppColors.error),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                    height: MediaQuery.of(context).padding.bottom > 0
                        ? MediaQuery.of(context).padding.bottom
                        : 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Approval stage row (Manager / HR) ─────────────────────────────────────────

class _ApprovalStageRow extends StatelessWidget {
  final String level;
  final String approverName;
  final String? decisionStatus;
  final String? remarks;
  final String? actionedAt;
  const _ApprovalStageRow({
    required this.level,
    required this.approverName,
    required this.decisionStatus,
    required this.remarks,
    required this.actionedAt,
  });

  @override
  Widget build(BuildContext context) {
    final color = _decisionColor(decisionStatus);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(level,
                        style: AppTextStyles.label.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(_decisionLabel(decisionStatus),
                      style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ],
              ),
              Text(approverName.isNotEmpty ? approverName : 'Not yet assigned',
                  style: AppTextStyles.caption.copyWith(fontSize: 11)),
              if (remarks != null && remarks!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('"$remarks"',
                      style: AppTextStyles.caption.copyWith(
                          fontSize: 11, color: AppColors.textSecondary)),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    actionedAt != null && actionedAt!.isNotEmpty
                        ? _fmtDate(actionedAt)
                        : 'Not yet actioned',
                    style: AppTextStyles.caption.copyWith(fontSize: 10)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
