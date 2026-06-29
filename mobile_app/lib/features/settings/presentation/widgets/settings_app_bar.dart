import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Standard AppBar used on every settings sub-screen.
/// Accepts an optional [bottom] widget (e.g. TabBar) rendered inside the AppBar.
class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? trailing;
  final PreferredSizeWidget? bottom;

  const SettingsAppBar({
    super.key,
    required this.title,
    this.trailing,
    this.bottom,
  });

  @override
  Size get preferredSize {
    return Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: AppColors.textSecondary,
        onPressed: () => context.pop(),
      ),
      title: Text(
        title,
        style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (trailing != null) trailing!,
        const SizedBox(width: 4),
      ],
      bottom: bottom,
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
    );
  }
}
