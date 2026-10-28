import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/wfh_entity.dart';
import '../providers/wfh_providers.dart';
import 'wfh_status_chip.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

/// Opens the WFH request detail sheet — reachable only from "My Requests"
/// (this module has no Approvals tab of its own; WFH approve/reject lives
/// in the unified cross-feature Approvals screen, see
/// lib/features/approvals/presentation/widgets/approval_detail_sheet.dart's
/// UnifiedApprovalKind.wfh case). Shows [initial] immediately (no loading
/// flash) while [wfhRequestDetailProvider] quietly refreshes it in the
/// background. The only action ever offered here is Cancel, gated on the
/// entity's own `canCancel` — a request can never show as approvable to
/// its own owner (the backend excludes self from `can_approve`).
Future<void> showWfhRequestDetailSheet(
  BuildContext context, {
  required WfhRequestEntity initial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => WfhRequestDetailSheet(initial: initial),
  );
}

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

// ── Widget ────────────────────────────────────────────────────────────────────

class WfhRequestDetailSheet extends ConsumerStatefulWidget {
  final WfhRequestEntity initial;
  const WfhRequestDetailSheet({super.key, required this.initial});

  @override
  ConsumerState<WfhRequestDetailSheet> createState() =>
      _WfhRequestDetailSheetState();
}

class _WfhRequestDetailSheetState
    extends ConsumerState<WfhRequestDetailSheet> {
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

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _cancelRequest(String id) async {
    setState(() => _actionLoading = true);
    final err = await ref.read(wfhMyRequestsProvider.notifier).cancelRequest(id);
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
    final detailAsync = ref.watch(wfhRequestDetailProvider(widget.initial.id));
    final r = detailAsync.valueOrNull ?? widget.initial;
    final showCancel = r.canCancel;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
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
                      child: Icon(Icons.home_work_outlined, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('WFH Request Details',
                          style: AppTextStyles.h4.copyWith(fontSize: 15)),
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
                                width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
                            const SizedBox(width: 6),
                            Text('Loading latest status…',
                                style: AppTextStyles.caption.copyWith(fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (detailAsync.hasError) ...[
                        Row(
                          children: [
                            Icon(Icons.error_outline, size: 13, color: AppColors.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('Could not refresh — showing last known details.',
                                  style: AppTextStyles.caption
                                      .copyWith(fontSize: 11, color: AppColors.error)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Dates + status
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text('${_fmtDate(r.startDate)} → ${_fmtDate(r.endDate)}',
                                style: AppTextStyles.label.copyWith(fontSize: 13)),
                          ),
                          WfhStatusChip(status: r.status),
                        ],
                      ),

                      const SizedBox(height: 14),
                      Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),

                      // Location
                      Text('LOCATION',
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      const SizedBox(height: 3),
                      if (r.locationLabel.isNotEmpty)
                        Text(r.locationLabel, style: AppTextStyles.body.copyWith(fontSize: 13)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _openMap(r.latitude, r.longitude),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.place_outlined, size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${r.latitude.toStringAsFixed(6)}, ${r.longitude.toStringAsFixed(6)}',
                              style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.primary),
                            ),
                            const SizedBox(width: 4),
                            Text('View on map',
                                style: AppTextStyles.caption.copyWith(
                                    fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
                      Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),

                      // Reason
                      Text('REASON',
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      const SizedBox(height: 3),
                      Text(r.reason.isNotEmpty ? r.reason : '—',
                          style: AppTextStyles.body.copyWith(fontSize: 13)),

                      const SizedBox(height: 14),
                      Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),

                      // Approval Flow
                      Text('APPROVAL FLOW',
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      const SizedBox(height: 10),
                      _ApprovalStageRow(
                        level: 'Manager Approval',
                        approverName: r.l1ApproverName,
                        decisionStatus: r.l1Status,
                        remarks: r.l1Remarks,
                        actionedAt: r.l1ActionedAt,
                      ),
                      const SizedBox(height: 10),
                      _ApprovalStageRow(
                        level: 'HR Approval',
                        approverName: r.l2ApproverName,
                        decisionStatus: r.l2Status,
                        remarks: r.l2Remarks,
                        actionedAt: r.l2ActionedAt,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Footer ───────────────────────────────────────────────────
              if (showCancel)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _actionLoading ? null : () => _cancelRequest(r.id),
                        icon: const Icon(Icons.cancel_outlined, size: 14),
                        label: const Text('Cancel Request',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
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
  final String remarks;
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
                      style: AppTextStyles.caption
                          .copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                ],
              ),
              Text(approverName.isNotEmpty ? approverName : 'Not yet assigned',
                  style: AppTextStyles.caption.copyWith(fontSize: 11)),
              if (remarks.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('"$remarks"',
                      style: AppTextStyles.caption
                          .copyWith(fontSize: 11, color: AppColors.textSecondary)),
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
