import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Confirms an approve/reject decision on one separation stage (web:
/// separation/_components/DecisionModal.tsx). Approving takes optional
/// notes; rejecting needs a reason — the confirm button stays disabled
/// until one is typed. Resolves to the trimmed remarks, or null if
/// cancelled. Sent as `remarks` with POST
/// /separation/requests/<id>/stages/<stage>/action/.
class SeparationDecisionDialog extends StatefulWidget {
  const SeparationDecisionDialog(
      {super.key, required this.approve, required this.stageLabel, required this.employeeName});

  final bool approve;
  final String stageLabel;
  final String employeeName;

  static Future<String?> show(BuildContext context,
          {required bool approve, required String stageLabel, required String employeeName}) =>
      showDialog<String>(
        context: context,
        builder: (_) => SeparationDecisionDialog(approve: approve, stageLabel: stageLabel, employeeName: employeeName),
      );

  @override
  State<SeparationDecisionDialog> createState() => _SeparationDecisionDialogState();
}

class _SeparationDecisionDialogState extends State<SeparationDecisionDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canConfirm => widget.approve || _ctrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final approve = widget.approve;
    final color = approve ? AppColors.success : AppColors.error;
    final who = widget.employeeName.isEmpty ? 'this request' : widget.employeeName;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('${approve ? 'Approve' : 'Reject'} ${widget.stageLabel}', style: AppTextStyles.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            approve
                ? 'Approve this stage of the separation request for $who?'
                : 'Reject the separation request for $who? This ends the request.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('separation-decision-remarks'),
            controller: _ctrl,
            maxLines: 3,
            maxLength: 300,
            autofocus: !approve,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: approve ? 'Optional notes for the record…' : 'Reason for rejection (required)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('separation-decision-confirm'),
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: _canConfirm ? () => Navigator.pop(context, _ctrl.text.trim()) : null,
          child: Text(approve ? 'Approve' : 'Reject'),
        ),
      ],
    );
  }
}
