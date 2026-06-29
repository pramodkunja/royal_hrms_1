import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';

/// Top AppBar used inside [DashboardShell].
/// Kept as a plain [StatelessWidget] — all logic lives in [DashboardShell].
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onLogoutTap;

  const AppTopBar({
    super.key,
    required this.title,
    required this.onMenuTap,
    required this.onNotificationsTap,
    required this.onLogoutTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
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

              // Notifications
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    color: AppColors.textSecondary,
                    onPressed: onNotificationsTap,
                    tooltip: 'Notifications',
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),

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
