import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/notification_model.dart';
import '../models/notification_settings_model.dart';

class NotificationsRemoteDataSource {
  final Dio _dio;
  NotificationsRemoteDataSource(this._dio);

  Future<NotificationPage> fetchNotifications({int page = 1, int pageSize = 20}) async {
    final res = await _dio.get(
      ApiConstants.notifications,
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    return NotificationPage.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<int> fetchUnreadCount() async {
    final res = await _dio.get(ApiConstants.notificationsUnreadCount);
    final data = _unwrap(res.data) as Map<String, dynamic>;
    return data['unread_count'] as int? ?? 0;
  }

  Future<void> markRead(String id) async {
    await _dio.patch(ApiConstants.notificationRead(id));
  }

  Future<void> markAllRead() async {
    await _dio.patch(ApiConstants.notificationsReadAll);
  }

  Future<NotificationSettingsModel> fetchSettings() async {
    final res = await _dio.get(ApiConstants.notificationSettings);
    return NotificationSettingsModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<NotificationSettingsModel> updateSettings(NotificationSettingsModel settings) async {
    final res = await _dio.patch(ApiConstants.notificationSettings, data: settings.toJson());
    return NotificationSettingsModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }
}
