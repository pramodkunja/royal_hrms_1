import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../search/global_search_dialog.dart';
import 'app_top_bar.dart';

/// The dashboard shell's own [AppTopBar] (blue, title, Search / theme / bell /
/// Sign out) for a screen that is pushed OUTSIDE the shell and so cannot get it
/// from `DashboardShell`. The hamburger becomes a back arrow; nothing else about
/// the bar differs, and each action does what the shell's does.
class PushedAppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const PushedAppTopBar({super.key, required this.title, this.fallbackRoute = AppRoutes.dashboard});

  final String title;

  /// Where Back goes when there is nothing to pop (a direct deep link).
  final String fallbackRoute;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Same publish the Settings sub-screens' bar does, so the voice overlay knows
    // which screen is showing (see currentVisiblePathProvider).
    final currentPath = GoRouterState.of(context).uri.path;
    if (ref.read(currentVisiblePathProvider) != currentPath) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(currentVisiblePathProvider.notifier).state = currentPath,
      );
    }
    return AppTopBar(
      title: title,
      isBlueTheme: true,
      onBack: () => context.canPop() ? context.pop() : context.go(fallbackRoute),
      onThemeToggleTap: () => ref.read(themeModeProvider.notifier).toggle(),
      isDarkMode: ref.watch(themeModeProvider),
      onSearchTap: () => showGlobalSearch(context),
      onLogoutTap: () async {
        await ref.read(authStateProvider.notifier).logout();
        if (context.mounted) context.go(AppRoutes.login);
      },
    );
  }
}
