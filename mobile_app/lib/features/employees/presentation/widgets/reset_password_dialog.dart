import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/employee_providers.dart';

// Web: employees/[id]/_components/ResetPasswordModal.tsx — "Reset Password?",
// what will happen, Cancel / Reset Password. While the request runs both
// buttons are disabled ("Resetting…"). A refusal is shown here and the
// dialog stays open so it can be tried again; on success it closes and the
// caller shows the server's message. No password is ever shown.

/// Asks to confirm, then resets. Returns the server's outcome, or null when
/// cancelled.
Future<EmployeePasswordResetDone?> showResetPasswordDialog(
  BuildContext context, {
  required String employeeId,
  required String employeeName,
}) {
  return showDialog<EmployeePasswordResetDone>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ResetPasswordDialog(employeeId: employeeId, employeeName: employeeName),
  );
}

class ResetPasswordDialog extends ConsumerStatefulWidget {
  const ResetPasswordDialog({super.key, required this.employeeId, required this.employeeName});
  final String employeeId;
  final String employeeName;

  @override
  ConsumerState<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<ResetPasswordDialog> {
  bool _resetting = false;
  String? _error;

  Future<void> _confirm() async {
    if (_resetting) return; // one request at a time
    setState(() {
      _resetting = true;
      _error = null;
    });
    final outcome = await ref.read(employeePasswordResetterProvider).reset(widget.employeeId);
    if (!mounted) return;
    switch (outcome) {
      case EmployeePasswordResetDone():
        Navigator.of(context).pop(outcome);
      case EmployeePasswordResetFailed(:final message):
        setState(() {
          _resetting = false;
          _error = message;
        });
      case EmployeePasswordResetIgnored():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.employeeName.trim().isEmpty ? 'this employee' : widget.employeeName;
    return AlertDialog(
      key: const Key('reset-password-dialog'),
      icon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: AppColors.errorContainer, shape: BoxShape.circle),
        child: Icon(Icons.key_outlined, color: AppColors.error),
      ),
      title: Text('Reset Password?', style: AppTextStyles.h4.copyWith(fontSize: 16), textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 13), children: [
              const TextSpan(text: 'A new temporary password will be generated for '),
              TextSpan(text: name, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const TextSpan(text: ' and emailed to them. Their current password will stop working immediately.'),
            ]),
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: AppColors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_error!,
                      key: const Key('reset-password-error'),
                      style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('reset-password-cancel'),
          onPressed: _resetting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('reset-password-confirm'),
          onPressed: _resetting ? null : _confirm,
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: _resetting
              ? const Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                      width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  SizedBox(width: 8),
                  Text('Resetting…'),
                ])
              : const Text('Reset Password'),
        ),
      ],
    );
  }
}
