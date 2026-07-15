import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/core/theme/theme_mode_provider.dart';

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
    );
  }
}
