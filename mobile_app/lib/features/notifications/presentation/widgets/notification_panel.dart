import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/notification_model.dart';
import '../providers/notification_providers.dart';

// Dart port of web's MODULE_ROUTES (components/NotificationBell.tsx).
const _kModuleRoutes = <String, String>{
  'leave': AppRoutes.leave,
  'attendance': AppRoutes.myAttendance,
  'regularization': AppRoutes.myAttendance,
  'announcement': AppRoutes.announcements,
  'holiday': AppRoutes.attendance,
  'permission': AppRoutes.leave,
};

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
                children: [
                  Text('Notifications', style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary)),
                  const Spacer(),
                  if (async.valueOrNull?.notifications.any((n) => !n.isRead) ?? false)
                    TextButton(
                      onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
                      child: const Text('Mark all as read'),
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
                          goToDashboardSection(
                              context, _kModuleRoutes[n.module] ?? AppRoutes.dashboard);
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
