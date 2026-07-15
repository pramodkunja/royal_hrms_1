import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/notifications_remote_datasource.dart';
import '../../data/models/notification_model.dart';

const _kPollInterval = Duration(seconds: 60);

final notificationsDataSourceProvider =
    Provider<NotificationsRemoteDataSource>((ref) {
  return NotificationsRemoteDataSource(ref.watch(dioProvider));
});

/// Unread badge count — polled every 60s while the dashboard shell is
/// mounted (mirrors web's useNotifications POLL_INTERVAL_MS), stops as soon
/// as nothing is watching it (e.g. after logout), matching `autoDispose`.
final unreadNotificationCountProvider =
    AsyncNotifierProvider.autoDispose<UnreadNotificationCountNotifier, int>(
  UnreadNotificationCountNotifier.new,
);

class UnreadNotificationCountNotifier extends AutoDisposeAsyncNotifier<int> {
  Timer? _timer;

  @override
  Future<int> build() async {
    ref.onDispose(() => _timer?.cancel());
    _timer ??= Timer.periodic(_kPollInterval, (_) => refresh());
    return ref.read(notificationsDataSourceProvider).fetchUnreadCount();
  }

  Future<void> refresh() async {
    try {
      final count = await ref.read(notificationsDataSourceProvider).fetchUnreadCount();
      state = AsyncData(count);
    } catch (_) {
      // Keep showing the last known count on a transient network failure.
    }
  }

  void setLocal(int count) => state = AsyncData(count < 0 ? 0 : count);
}

/// Notification list — fetched on demand when the bell's panel opens
/// (matches web: the list isn't polled, only the unread count is).
final notificationsProvider =
    AsyncNotifierProvider.autoDispose<NotificationsNotifier, NotificationPage>(
  NotificationsNotifier.new,
);

class NotificationsNotifier extends AutoDisposeAsyncNotifier<NotificationPage> {
  NotificationsRemoteDataSource get _ds => ref.read(notificationsDataSourceProvider);

  @override
  Future<NotificationPage> build() => _ds.fetchNotifications();

  Future<void> refresh() async {
    state = const AsyncLoading<NotificationPage>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _ds.fetchNotifications());
  }

  Future<void> markRead(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final target = current.notifications.where((n) => n.id == id).firstOrNull;
    if (target == null || target.isRead) return;

    state = AsyncData(current.copyWith(
      notifications: current.notifications
          .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
          .toList(),
    ));
    ref.read(unreadNotificationCountProvider.notifier).setLocal(
          (ref.read(unreadNotificationCountProvider).valueOrNull ?? 1) - 1,
        );
    try {
      await _ds.markRead(id);
    } catch (_) {
      // Best-effort — a background unread-count poll will reconcile drift.
    }
  }

  Future<void> markAllRead() async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncData(current.copyWith(
      notifications: current.notifications.map((n) => n.copyWith(isRead: true)).toList(),
      unreadCount: 0,
    ));
    ref.read(unreadNotificationCountProvider.notifier).setLocal(0);
    try {
      await _ds.markAllRead();
    } catch (_) {}
  }
}
