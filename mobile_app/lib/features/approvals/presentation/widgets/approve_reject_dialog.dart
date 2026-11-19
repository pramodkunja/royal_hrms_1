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
  // Outside the builder (Task 81): declared inside, it was reset on every
  // rebuild, so "Please provide a reason." never appeared.
  String? error;

  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          scrollable: true,
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
                decoration: _fieldDecoration(
                  forReject ? 'Explain why this request is being rejected…' : 'Add an optional note…',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
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
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
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
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
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

/// Web BulkConfirmModal. Returns the remarks (possibly '' for an approval) when
/// confirmed, null when cancelled. Rejecting needs a reason: the button stays
/// disabled until one is typed.
Future<String?> showBulkConfirmDialog(
  BuildContext context, {
  required bool approve,
  required int count,
}) {
  final ctrl = TextEditingController();
  final color = approve ? AppColors.success : AppColors.error;
  final plural = count == 1 ? '' : 's';
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final canConfirm = approve || ctrl.text.trim().isNotEmpty;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          scrollable: true,
          title: Text('${approve ? 'Approve' : 'Reject'} $count request$plural', style: AppTextStyles.label),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (approve ? AppColors.info : AppColors.warning).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  approve
                      ? "You're about to approve $count selected request$plural. Employees will be notified."
                      : "You're about to reject $count selected request$plural. Employees will be notified.",
                  style: AppTextStyles.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                approve ? 'Remarks' : 'Remarks *',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('bulk-remarks'),
                controller: ctrl,
                maxLines: 3,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: _fieldDecoration(approve ? 'Optional notes for the record…' : 'Reason for rejection (required)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
            FilledButton(
              key: const Key('bulk-confirm'),
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: canConfirm ? () => Navigator.pop(context, ctrl.text.trim()) : null,
              child: Text(approve ? 'Approve $count' : 'Reject $count'),
            ),
          ],
        );
      },
    ),
  );
}

/// The outlined input My Profile uses (radius 10, hairline, primary when focused).
InputDecoration _fieldDecoration(String hint, {String? errorText}) {
  OutlineInputBorder b(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
    errorText: errorText,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    filled: true,
    fillColor: AppColors.surface,
    border: b(AppColors.border),
    enabledBorder: b(AppColors.border),
    focusedBorder: b(AppColors.primary, 1.5),
    errorBorder: b(AppColors.error),
    focusedErrorBorder: b(AppColors.error, 1.5),
  );
}
