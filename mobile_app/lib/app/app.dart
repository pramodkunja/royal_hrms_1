import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/network/connectivity_provider.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/core/theme/theme_mode_provider.dart';
import 'package:mobile_app/features/voice_commands/presentation/widgets/voice_mic_overlay.dart';
import 'package:mobile_app/shared/widgets/no_internet_view.dart';

class RoyalHrmsApp extends ConsumerWidget {
  const RoyalHrmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final isDark = ref.watch(themeModeProvider);

    // Almost every screen reads colors from the static AppColors fields
    // rather than Theme.of(context) (see app_colors.dart), and most
    // go_router routes are built with `const XScreen()` — so a plain
    // ancestor rebuild would get short-circuited by Flutter's identical-const
    // skip and never reach most of the tree. Keying on isDark forces a full
    // teardown/remount of the whole app on toggle, which guarantees every
    // screen re-reads the freshly-applied colors. GoRouter itself lives in a
    // provider outside this subtree, so the current route/location survives
    // the remount even though in-page widget state (scroll position, unsaved
    // form input) does not.
    return MaterialApp.router(
      key: ValueKey('app-theme-$isDark'),
      title: 'Royal HRMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(isDark),
      routerConfig: router,
      // Wraps every route the router produces (not just the dashboard
      // shell) so the voice mic is available on every screen — the overlay
      // itself decides whether it's eligible to show (see VoiceMicOverlay).
      //
      // This Stack sits alongside `child` (the router's own Navigator), not
      // inside it, so it has no Overlay ancestor of its own — and
      // FloatingActionButton/IconButton's `tooltip` internally need one
      // (RawTooltip requires Overlay.of(context)). Giving the mic overlay
      // its own nested Overlay, rather than dropping the tooltips, is the
      // fix Flutter's own assertion message points at.
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          Positioned.fill(
            child: Overlay(
              initialEntries: [
                OverlayEntry(builder: (_) => const VoiceMicOverlay()),
              ],
            ),
          ),
          // Blocks the whole app behind a full-screen "no internet" state
          // whenever connectivity drops, and clears itself the instant the
          // device reconnects — no per-screen wiring needed.
          const _ConnectivityGate(),
        ],
      ),
    );
  }
}

/// Renders nothing while online (or before the first connectivity check
/// resolves, to avoid a startup flash) and a full-screen, input-blocking
/// [NoInternetView] the moment connectivity_plus reports no active network.
class _ConnectivityGate extends ConsumerWidget {
  const _ConnectivityGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    if (isOnline) return const SizedBox.shrink();

    return Positioned.fill(
      child: NoInternetView(onRetry: () => ref.invalidate(isOnlineProvider)),
    );
  }
}
