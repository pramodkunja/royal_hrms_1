import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'app_button.dart';

/// Shared "no data" visual — a tinted icon chip, a title, an optional
/// message, and an optional action button. Modeled directly on the
/// Employees screen's own `_EmptyView` (already the most polished existing
/// empty-state implementation in the app), generalized so every feature can
/// reuse the same icon size/spacing/typography instead of each hand-rolling
/// a slightly different version.
///
/// Deliberately does not attempt to distinguish "empty due to no data" vs
/// "empty due to a search/filter" — callers that need different copy for
/// those cases (e.g. Employees) already compute the right [title]/[message]
/// themselves and just pass the result in.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
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
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.h4, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.outline,
                width: 180,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
