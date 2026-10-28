import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/notification_settings_model.dart';
import 'notification_providers.dart';

final notificationSettingsProvider = AsyncNotifierProvider.autoDispose<
    NotificationSettingsNotifier, NotificationSettingsModel>(
  NotificationSettingsNotifier.new,
);

class NotificationSettingsNotifier
    extends AutoDisposeAsyncNotifier<NotificationSettingsModel> {
  @override
  Future<NotificationSettingsModel> build() =>
      ref.read(notificationsDataSourceProvider).fetchSettings();

  /// Returns null on success, a user-facing error message on failure.
  Future<String?> save(NotificationSettingsModel draft) async {
    try {
      final saved =
          await ref.read(notificationsDataSourceProvider).updateSettings(draft);
      state = AsyncData(saved);
      return null;
    } catch (e) {
      return friendlyNotificationSettingsError(e);
    }
  }
}

String friendlyNotificationSettingsError(Object e) {
  if (e is DioException) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Cannot reach server. Check your connection.';
    }
    return parseDioException(e).message;
  }
  return e.toString().replaceAll('Exception:', '').trim();
}
