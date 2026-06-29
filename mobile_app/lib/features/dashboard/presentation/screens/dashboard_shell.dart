import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import '../navigation/nav_config.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/app_top_bar.dart';

/// Shell that wraps every /dashboard/* route via GoRouter's ShellRoute.
///
/// Responsibilities:
///   - Scaffold with persistent Drawer (sidebar) and AppTopBar
///   - Renders the current route's page as [child]
///   - Navigates to /login when the user logs out
class DashboardShell extends ConsumerStatefulWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  // Held in state so the key is stable across rebuilds — a new GlobalKey on
  // every build would lose the Scaffold's internal drawer state.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    // Watch route path so the top bar title and sidebar active item update
    // whenever the child route changes (GoRouter rebuilds this widget).
    final currentPath = GoRouterState.of(context).uri.path;
    final title = pageTitle(currentPath);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const AppSidebar(),
      appBar: AppTopBar(
        title: title,
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        onNotificationsTap: () {
          // Notifications module — coming soon.
        },
        onLogoutTap: _handleLogout,
      ),
      body: widget.child,
    );
  }

  Future<void> _handleLogout() async {
    await ref.read(authStateProvider.notifier).logout();
    // Imperative navigation after the async logout — always outside build.
    if (mounted) context.go(AppRoutes.login);
  }
}
