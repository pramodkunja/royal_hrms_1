import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Standard AppBar used on every settings sub-screen.
/// Accepts an optional [bottom] widget (e.g. TabBar) rendered inside the AppBar.
class SettingsAppBar extends ConsumerWidget implements PreferredSizeWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // Settings sub-screens are pushed outside the dashboard shell, so
    // DashboardShell never sees them — publish the path here instead, same
    // reasoning as DashboardShell's own publish (see
    // currentVisiblePathProvider's doc comment in app_router.dart). None of
    // these screens have their own FAB-avoidance need, but VoiceMicOverlay
    // still renders above them and needs an up-to-date path to avoid
    // staying stuck on whatever /dashboard/* screen was open before.
    final currentPath = GoRouterState.of(context).uri.path;
    if (ref.read(currentVisiblePathProvider) != currentPath) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(currentVisiblePathProvider.notifier).state = currentPath,
      );
    }
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: AppColors.textSecondary,
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go(AppRoutes.settings),
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
      shape: Border(bottom: BorderSide(color: AppColors.border)),
    );
  }
}
