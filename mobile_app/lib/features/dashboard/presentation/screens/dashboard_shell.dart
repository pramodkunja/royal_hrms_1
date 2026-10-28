import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/theme_mode_provider.dart';
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
    final isDarkMode = ref.watch(themeModeProvider);

    // Publish so VoiceMicOverlay (mounted above the whole Router, with no
    // GoRouterState of its own) can tell whether the current screen has a
    // FAB — see currentVisiblePathProvider's doc comment in app_router.dart
    // for why this can't just be read off GoRouter itself. Deferred to next
    // frame: this runs during build, and a provider write during build
    // throws.
    final previousPath = ref.read(currentVisiblePathProvider);
    if (previousPath != currentPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(currentVisiblePathProvider.notifier).state = currentPath;
        }
      });

      // Landing back on the dashboard home route from anywhere else — e.g.
      // popping back after goToDashboardSection pushed a section on top —
      // bump the revisit signal so HomeScreen's still-mounted providers
      // (never disposed, since push/pop never tears it down) re-fetch.
      // See dashboardRevisitProvider's doc comment for why this is needed.
      if (currentPath == AppRoutes.dashboard && previousPath != AppRoutes.dashboard) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(dashboardRevisitProvider.notifier).state++;
          }
        });
      }
    }

    return PopScope(
      // Always intercept: every /dashboard/* route lives inside this shell,
      // so this is the choke point for "nothing left to pop" — decide
      // ourselves whether that means go home, or ask before exiting.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackPress(currentPath);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        drawer: const AppSidebar(),
        appBar: AppTopBar(
          title: title,
          // Every route except the Dashboard home screen gets the blue app
          // bar theme — Dashboard keeps its original plain white bar.
          isBlueTheme: currentPath != AppRoutes.dashboard,
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          onThemeToggleTap: () => ref.read(themeModeProvider.notifier).toggle(),
          isDarkMode: isDarkMode,
          onLogoutTap: _handleLogout,
        ),
        body: widget.child,
      ),
    );
  }

  Future<void> _handleBackPress(String currentPath) async {
    if (context.canPop()) {
      context.pop();
      return;
    }
    // Reached with no back stack from a non-dashboard shell route (e.g. a
    // direct deep link) — go home instead of falling through to exit.
    if (currentPath != AppRoutes.dashboard) {
      context.go(AppRoutes.dashboard);
      return;
    }
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit Application?'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  Future<void> _handleLogout() async {
    await ref.read(authStateProvider.notifier).logout();
    // Imperative navigation after the async logout — always outside build.
    if (mounted) context.go(AppRoutes.login);
  }
}
