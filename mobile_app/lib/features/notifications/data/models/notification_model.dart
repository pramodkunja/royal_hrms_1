/// Dart port of web's `Notification` / `NotificationListResponse` types
/// (frontend/types/notifications.ts) — mirrors backend's NotificationSerializer.
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String notificationType;
  final String module;
  final String referenceId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.module,
    required this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      notificationType: json['notification_type'] as String? ?? '',
      module: json['module'] as String? ?? '',
      referenceId: json['reference_id'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      message: message,
      notificationType: notificationType,
      module: module,
      referenceId: referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

class NotificationPage {
  final List<NotificationModel> notifications;
  final int count;
  final int page;
  final int totalPages;
  final int unreadCount;

  const NotificationPage({
    required this.notifications,
    required this.count,
    required this.page,
    required this.totalPages,
    required this.unreadCount,
  });

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final results = (json['results'] as List<dynamic>? ?? [])
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return NotificationPage(
      notifications: results,
      count: json['count'] as int? ?? results.length,
      page: json['page'] as int? ?? 1,
      totalPages: json['total_pages'] as int? ?? 1,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  NotificationPage copyWith({List<NotificationModel>? notifications, int? unreadCount}) {
    return NotificationPage(
      notifications: notifications ?? this.notifications,
      count: count,
      page: page,
      totalPages: totalPages,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
