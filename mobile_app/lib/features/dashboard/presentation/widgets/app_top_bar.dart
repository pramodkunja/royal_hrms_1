import 'package:flutter/material.dart';
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

  const AppTopBar({
    super.key,
    required this.title,
    required this.onMenuTap,
    required this.onLogoutTap,
    required this.onThemeToggleTap,
    required this.isDarkMode,
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
    return Container(
      height: kToolbarHeight + topPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
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
                color: AppColors.textSecondary,
                onPressed: onMenuTap,
                tooltip: 'Menu',
              ),

              // Page title
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Dark mode toggle — moon/sun swap, matches web's DashboardShell.
              IconButton(
                icon: Icon(isDarkMode ? Icons.wb_sunny_rounded : Icons.dark_mode_outlined),
                color: AppColors.textSecondary,
                onPressed: onThemeToggleTap,
                tooltip: isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
              ),

              // Notifications — owns its own tap handling + dropdown anchor.
              const NotificationBellButton(),

              // Logout
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                color: AppColors.textSecondary,
                onPressed: onLogoutTap,
                tooltip: 'Sign out',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
