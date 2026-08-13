import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'app_button.dart';

/// Shared "something failed" visual — an error-tinted icon chip, an
/// optional title, the (already-friendly, never-raw) error message, and an
/// optional Retry action. Same visual family as [AppEmptyState] (same icon
/// chip size/shape, same typography), just error-tinted instead of
/// primary-tinted, so the two read as members of one design language
/// instead of two unrelated widgets.
///
/// [message] must already be user-facing text — e.g. the result of
/// `userFriendlyMessage()` or a feature's own `friendly*Error()` helper.
/// This widget does not sanitize its input; callers are responsible for
/// never passing a raw `err.toString()`/Dio exception through.
///
/// [onRetry] should invalidate/refresh whatever provider actually failed —
/// this widget only renders the button and calls it back, it has no
/// network/provider knowledge of its own.
class AppErrorState extends StatelessWidget {
  final String message;
  final String? title;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;
  final Widget? secondaryAction;
  final EdgeInsetsGeometry padding;

  const AppErrorState({
    super.key,
    required this.message,
    this.title,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.icon = Icons.error_outline,
    this.secondaryAction,
    this.padding = const EdgeInsets.all(32),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 32, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            if (title != null) ...[
              Text(title!, style: AppTextStyles.h4, textAlign: TextAlign.center),
              const SizedBox(height: 6),
            ],
            Text(
              message,
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              AppButton(
                label: retryLabel,
                onPressed: onRetry,
                width: 160,
                leadingIcon: Icons.refresh,
              ),
            ],
            if (secondaryAction != null) ...[
              const SizedBox(height: 8),
              secondaryAction!,
            ],
          ],
        ),
      ),
    );
  }
}
