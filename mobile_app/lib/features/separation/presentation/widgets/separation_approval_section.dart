import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/separation_entity.dart';
import '../providers/separation_providers.dart';
import 'separation_decision_dialog.dart';
import 'separation_status.dart';

/// Multi-stage approval timeline (1 or 2 stages, in `sequence` order —
/// HR/Manager/Branch Admin, resolved server-side per
/// _resolve_separation_chain). Mirrors web's ApprovalSection.tsx.
class SeparationApprovalSection extends ConsumerStatefulWidget {
  final String requestId;
  final List<SeparationApprovalStageEntity> stages;
  final String employeeName;
  const SeparationApprovalSection({
    super.key,
    required this.requestId,
    required this.stages,
    this.employeeName = '',
  });

  @override
  ConsumerState<SeparationApprovalSection> createState() =>
      _SeparationApprovalSectionState();
}

class _SeparationApprovalSectionState
    extends ConsumerState<SeparationApprovalSection> {
  bool _loading = false;

  void _showError(String err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating),
    );
  }

  /// Confirms, then sends the decision. One request at a time; the
  /// server's answer is authoritative — success is reported only once it
  /// accepted, and a refusal (already actioned, earlier stage pending,
  /// permission) is shown as it came.
  Future<void> _decide(SeparationApprovalStageEntity stage, {required bool approve}) async {
    if (_loading) return;
    final remarks = await SeparationDecisionDialog.show(
      context,
      approve: approve,
      stageLabel: stage.stageDisplay,
      employeeName: widget.employeeName,
    );
    if (remarks == null || !mounted || _loading) return;
    setState(() => _loading = true);
    final err = await ref.read(separationActionsProvider).actionStage(
          requestId: widget.requestId,
          stageId: stage.id,
          action: approve ? 'approve' : 'reject',
          remarks: remarks,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      _showError(err);
      // The request may have moved on meanwhile — reload what the server has.
      ref.read(separationActionsProvider).refreshRequest(widget.requestId);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(approve ? 'Stage approved.' : 'Stage rejected.'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final stages = [...widget.stages]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SeparationSectionHeader(title: 'Approval'),
          if (stages.isEmpty)
            Text('No approval stages configured.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textHint))
          else
            for (var i = 0; i < stages.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _StageRow(
                stage: stages[i],
                loading: _loading,
                onApprove: () => _decide(stages[i], approve: true),
                onReject: () => _decide(stages[i], approve: false),
              ),
            ],
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  final SeparationApprovalStageEntity stage;
  final bool loading;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _StageRow({
    required this.stage,
    required this.loading,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final color = separationStatusColor(stage.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                        child: Text(stage.stageDisplay,
                            style: AppTextStyles.label.copyWith(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(stage.statusDisplay,
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                    ],
                  ),
                  Text(
                    stage.approverName.isNotEmpty
                        ? stage.approverName
                        : 'Not yet assigned',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                  if (stage.remarks.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('"${stage.remarks}"',
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      stage.actionedAt != null && stage.actionedAt!.isNotEmpty
                          ? formatSeparationDate(stage.actionedAt)
                          : 'Not yet actioned',
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (stage.canAction) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('stage-reject-${stage.id}'),
                    onPressed: loading ? null : onReject,
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
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    key: Key('stage-approve-${stage.id}'),
                    onPressed: loading ? null : onApprove,
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Approve',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
