import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Remarks dialog used for Leave and Attendance Correction approve/reject.
/// Remarks are REQUIRED (non-empty) when [forReject] is true, and OPTIONAL
/// otherwise — matches the existing leave reject UX, now extended so approve
/// also gets a lightweight confirm step (previously leave approve fired
/// instantly with no dialog at all).
///
/// Returns the entered remarks (possibly '') on confirm, or null if the user
/// cancelled — callers should treat null as "do nothing".
Future<String?> showRemarksDialog(
  BuildContext context, {
  required bool forReject,
  String? title,
}) {
  final ctrl = TextEditingController();
  final color = forReject ? AppColors.error : AppColors.success;
  final dialogTitle = title ?? (forReject ? 'Reject Request' : 'Approve Request');

  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        String? error;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  forReject ? Icons.cancel_outlined : Icons.check_circle_outline,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(dialogTitle, style: AppTextStyles.label)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                forReject ? 'Rejection Reason *' : 'Remarks (optional)',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: ctrl,
                maxLines: 3,
                maxLength: 300,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: forReject
                      ? 'Explain why this request is being rejected…'
                      : 'Add an optional note…',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: () {
                final text = ctrl.text.trim();
                if (forReject && text.isEmpty) {
                  setState(() => error = 'Please provide a reason.');
                  return;
                }
                Navigator.pop(context, text);
              },
              child: Text(forReject ? 'Submit Rejection' : 'Confirm Approval'),
            ),
          ],
        );
      },
    ),
  );
}

/// Plain Cancel/Confirm dialog with no text field — used for Expense
/// approve/reject. The Expense model has no remarks/notes column at all;
/// the backend silently drops any remarks the client sends, so adding a
/// textarea here would be fake functionality. This still fixes the real gap
/// where expense approve/reject previously fired with zero confirmation.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required bool forReject,
  String? title,
  String? message,
}) async {
  final color = forReject ? AppColors.error : AppColors.success;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title ?? (forReject ? 'Reject Expense Claim?' : 'Approve Expense Claim?'),
        style: AppTextStyles.label,
      ),
      content: Text(
        message ??
            (forReject
                ? 'Are you sure you want to reject this expense claim?'
                : 'Are you sure you want to approve this expense claim?'),
        style: AppTextStyles.bodySmall,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: () => Navigator.pop(context, true),
          child: Text(forReject ? 'Reject' : 'Approve'),
        ),
      ],
    ),
  );
  return result ?? false;
}
