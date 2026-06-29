import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';

enum AppButtonVariant { filled, outline, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? leadingIcon;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.filled,
    this.leadingIcon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: 48,
      child: switch (variant) {
        AppButtonVariant.filled => _FilledButton(
            label: label,
            onPressed: isLoading ? null : onPressed,
            isLoading: isLoading,
            leadingIcon: leadingIcon,
          ),
        AppButtonVariant.outline => _OutlineButton(
            label: label,
            onPressed: isLoading ? null : onPressed,
            leadingIcon: leadingIcon,
          ),
        AppButtonVariant.ghost => _GhostButton(
            label: label,
            onPressed: isLoading ? null : onPressed,
            leadingIcon: leadingIcon,
          ),
      },
    );
  }
}

class _FilledButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? leadingIcon;

  const _FilledButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primaryLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label, style: AppTextStyles.button.copyWith(color: Colors.white)),
              ],
            ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;

  const _OutlineButton({required this.label, required this.onPressed, this.leadingIcon});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[Icon(leadingIcon, size: 18), const SizedBox(width: 8)],
          Text(label, style: AppTextStyles.button.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;

  const _GhostButton({required this.label, required this.onPressed, this.leadingIcon});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[Icon(leadingIcon, size: 18), const SizedBox(width: 6)],
          Text(label, style: AppTextStyles.button.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}
