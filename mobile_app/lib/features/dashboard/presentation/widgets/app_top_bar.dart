import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/notifications/presentation/widgets/notification_bell_button.dart';

/// Top AppBar used inside [DashboardShell].
/// Kept as a plain [StatelessWidget] — all logic lives in [DashboardShell],
/// except notifications which [NotificationBellButton] owns end-to-end (it
/// needs its own RenderBox to anchor the dropdown panel under itself).
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onMenuTap;
  final VoidCallback onLogoutTap;
  final VoidCallback onThemeToggleTap;
  final bool isDarkMode;
  // Every route gets the blue theme except the Dashboard home screen, which
  // keeps the original plain white bar — set by DashboardShell per-route.
  final bool isBlueTheme;

  const AppTopBar({
    super.key,
    required this.title,
    required this.onMenuTap,
    required this.onLogoutTap,
    required this.onThemeToggleTap,
    required this.isDarkMode,
    required this.isBlueTheme,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Scaffold gives this widget a max height of preferredSize.height PLUS
    // the status bar inset (same convention Flutter's own AppBar uses), so
    // the container's actual height must match that here too — otherwise a
    // fixed 56px box on a device with a taller status bar (notch, punch-hole
    // camera, some Android skins) leaves too little room for the icon row
    // once SafeArea's top padding is subtracted, clipping/overflowing it.
    final topPadding = MediaQuery.of(context).padding.top;

    // Blue theme (every screen except Dashboard home): white icons/title on
    // an AppColors.primary bar. Plain theme (Dashboard only): the original
    // white bar with dark icons/title — unchanged from before this rollout.
    final barColor = isBlueTheme ? AppColors.primary : AppColors.surface;
    final iconColor = isBlueTheme ? Colors.white : AppColors.textSecondary;
    final titleColor = isBlueTheme ? Colors.white : AppColors.textPrimary;

    // Blue bar needs light (white) status-bar icons/clock on Android/iOS —
    // the OS defaults to dark icons, which would be near-invisible against
    // AppColors.primary. The plain (Dashboard) bar keeps the OS default dark
    // icons, correct against its white background. AnnotatedRegion applies
    // as long as this widget is on top of the tree (true here — it's every
    // route's AppBar).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isBlueTheme
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark, // iOS reads this one instead
            )
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Container(
        height: kToolbarHeight + topPadding,
        decoration: BoxDecoration(
          color: barColor,
          border: isBlueTheme ? null : Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                // Hamburger — opens the drawer
                IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  color: iconColor,
                  onPressed: onMenuTap,
                  tooltip: 'Menu',
                ),

                // Page title
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.h4.copyWith(color: titleColor, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Dark mode toggle — moon/sun swap, matches web's DashboardShell.
                IconButton(
                  icon: Icon(isDarkMode ? Icons.wb_sunny_rounded : Icons.dark_mode_outlined),
                  color: iconColor,
                  onPressed: onThemeToggleTap,
                  tooltip: isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
                ),

                // Notifications — owns its own tap handling + dropdown anchor.
                NotificationBellButton(color: iconColor),

                // Logout
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  color: iconColor,
                  onPressed: onLogoutTap,
                  tooltip: 'Sign out',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
