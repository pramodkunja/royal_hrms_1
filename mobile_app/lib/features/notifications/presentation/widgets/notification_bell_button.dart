import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/notification_providers.dart';
import 'notification_panel.dart';

/// Self-contained bell icon + unread badge for [AppTopBar] — owns its own
/// tap handling so it can measure its own position and anchor the dropdown
/// panel directly under itself (matches web's NotificationBell.tsx, which
/// renders its dropdown as a `position: absolute` panel under the button).
class NotificationBellButton extends ConsumerWidget {
  // Defaults to AppColors.textSecondary (the icon's original color, for the
  // employee-profile screen's own white AppBar) — AppTopBar's now-blue
  // background passes Colors.white explicitly instead.
  final Color? color;
  const NotificationBellButton({super.key, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          color: color ?? AppColors.textSecondary,
          onPressed: () => _openPanel(context),
          tooltip: 'Notifications',
        ),
        if (unreadCount > 0)
          Positioned(
            top: 6,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static const _kMinSideMargin = 12.0;
  static const _kMaxPanelWidth = 340.0;

  void _openPanel(BuildContext context) {
    final button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    // Anchor the panel's top-right corner just under the bell's bottom-right
    // corner, in Overlay-local coordinates — so it always renders directly
    // beneath the bell icon, not centered on the screen.
    final topRight = button.localToGlobal(
      Offset(button.size.width, button.size.height + 8),
      ancestor: overlay,
    );

    // A fixed-width panel right-aligned under the bell can run off the left
    // edge on narrow phones (the bell isn't the last icon in the row, so its
    // right edge sits well short of the screen's own right edge). Compute an
    // explicit left position and clamp it to a minimum margin instead of
    // relying on `right:`, so the panel shrinks/shifts to always stay
    // on-screen rather than overflowing.
    final width = overlay.size.width - (_kMinSideMargin * 2) < _kMaxPanelWidth
        ? overlay.size.width - (_kMinSideMargin * 2)
        : _kMaxPanelWidth;
    var left = topRight.dx - width;
    if (left < _kMinSideMargin) left = _kMinSideMargin;

    showGeneralDialog(
      context: context,
      barrierLabel: 'Notifications',
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, __) {
        return Stack(
          children: [
            Positioned(
              top: topRight.dy,
              left: left,
              child: NotificationPanel(width: width),
            ),
          ],
        );
      },
      transitionBuilder: (dialogContext, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );
  }
}
