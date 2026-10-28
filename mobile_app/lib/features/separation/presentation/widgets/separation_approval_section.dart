import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/separation_entity.dart';
import '../providers/separation_providers.dart';
import 'separation_status.dart';

/// Multi-stage approval timeline (1 or 2 stages, in `sequence` order —
/// HR/Manager/Branch Admin, resolved server-side per
/// _resolve_separation_chain). Mirrors web's ApprovalSection.tsx.
class SeparationApprovalSection extends ConsumerStatefulWidget {
  final String requestId;
  final List<SeparationApprovalStageEntity> stages;
  const SeparationApprovalSection({
    super.key,
    required this.requestId,
    required this.stages,
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

  Future<void> _approve(SeparationApprovalStageEntity stage) async {
    setState(() => _loading = true);
    final err = await ref.read(separationActionsProvider).actionStage(
          requestId: widget.requestId,
          stageId: stage.id,
          action: 'approve',
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) _showError(err);
  }

  Future<void> _reject(SeparationApprovalStageEntity stage) async {
    final ctrl = TextEditingController();
    final remarks = await showDialog<String>(
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
              child: Icon(Icons.cancel_outlined, size: 17, color: AppColors.error),
            ),
            const SizedBox(width: 10),
            Text('Reject ${stage.stageDisplay}', style: AppTextStyles.label),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remarks',
                style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              maxLines: 3,
              maxLength: 300,
              autofocus: true,
              decoration:
                  const InputDecoration(hintText: 'Explain the rejection…'),
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
    if (remarks == null || !mounted) return;
    setState(() => _loading = true);
    final err = await ref.read(separationActionsProvider).actionStage(
          requestId: widget.requestId,
          stageId: stage.id,
          action: 'reject',
          remarks: remarks,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) _showError(err);
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
                onApprove: () => _approve(stages[i]),
                onReject: () => _reject(stages[i]),
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
