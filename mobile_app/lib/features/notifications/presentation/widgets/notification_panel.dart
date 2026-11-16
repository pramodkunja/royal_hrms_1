import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/access_control.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/notification_model.dart';
import '../providers/notification_providers.dart';

// Dart port of web's MODULE_ROUTES (components/NotificationBell.tsx): the
// destination is chosen by Notification.module only (reference_id is not
// used, as on web). 'holiday' → HR Attendance, as on web.
const _kModuleRoutes = <String, String>{
  'leave': AppRoutes.leave,
  'attendance': AppRoutes.myAttendance,
  'regularization': AppRoutes.myAttendance,
  'announcement': AppRoutes.announcements,
  'holiday': AppRoutes.attendance,
  'permission': AppRoutes.leave,
  // Web: promotion → /dashboard/profile — the recipient's own profile (the
  // backend notifies only the promoted employee; reference_id is the
  // promotion record, not an employee). Self-service, so every signed-in
  // user may open it (Task 78).
  'promotion': AppRoutes.profile,
};

/// Where tapping [notification] takes [user] (Task 75).
///
/// Web routes by module and leaves access to its route guard (proxy.ts),
/// which sends anyone who can't open the page back to /dashboard — e.g. an
/// ordinary employee tapping a holiday notification (→ HR Attendance, which
/// needs attendance.edit or settings.edit) lands on the dashboard, where the
/// Upcoming Holidays card is. Here that outcome is decided up front with the
/// same rule as the router (canAccessPath: permission and subscription
/// module), so the app never navigates to a screen the user can't open.
/// Unknown, missing or malformed modules go to the dashboard, as on web.
String notificationDestination(NotificationModel notification, UserEntity? user) {
  final route = _kModuleRoutes[notification.module];
  // No signed-in user (still loading / signed out): home, never a screen.
  if (route == null || user == null) return AppRoutes.dashboard;
  return canAccessPath(user, route) ? route : AppRoutes.dashboard;
}

/// Dropdown panel anchored under [NotificationBellButton] — a fixed-width
/// floating card, not a bottom sheet (matches web's absolutely-positioned
/// dropdown under the bell icon).
class NotificationPanel extends ConsumerWidget {
  final double? width;

  const NotificationPanel({super.key, this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final screenSize = MediaQuery.of(context).size;
    // Cap width to the screen so the panel never spans almost edge-to-edge
    // on narrower phones — it should read as a compact dropdown under the
    // bell, not a near-full-width sheet. [NotificationBellButton] normally
    // passes an exact width computed from the bell's anchor position.
    final resolvedWidth =
        width ?? (screenSize.width - 24 < 340 ? screenSize.width - 24 : 340.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: resolvedWidth,
        constraints: BoxConstraints(maxHeight: screenSize.height * 0.6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.elevatedShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                // Both texts may shrink (ellipsis), so a narrow panel or large
                // text can't overflow the header.
                children: [
                  Expanded(
                    child: Text('Notifications',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary)),
                  ),
                  if (async.valueOrNull?.notifications.any((n) => !n.isRead) ?? false)
                    Flexible(
                      child: TextButton(
                        onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
                        child: const Text('Mark all as read', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.border),
            Flexible(
              child: async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load notifications.',
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                data: (page) {
                  if (page.notifications.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No notifications yet.',
                        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: page.notifications.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final n = page.notifications[index];
                      return _NotificationRow(
                        notification: n,
                        onTap: () {
                          ref.read(notificationsProvider.notifier).markRead(n.id);
                          Navigator.of(context).pop();
                          goToDashboardSection(context,
                              notificationDestination(n, ref.read(authStateProvider).valueOrNull?.user));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationRow({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: unread ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(notification.createdAt),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
