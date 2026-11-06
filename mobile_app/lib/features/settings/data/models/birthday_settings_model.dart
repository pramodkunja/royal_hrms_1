// Settings → Email Templates → "Automatic Birthday Wishes", as web
// settings/email-templates/page.tsx (BirthdaySettingsForm) over production
// BirthdaySettingsView (GET/PATCH /birthdays/settings/) and the per-company
// singleton BirthdaySettings row. The birthday *email* subject/body is the
// separate 'birthday_wish' email template, not part of this.

/// The four editable texts, keyed as the server names them.
const kBirthdayTextFields = [
  'banner_message_template',
  'employee_notification_template',
  'team_notification_template',
  'manager_notification_template',
];

class BirthdaySettingsModel {
  const BirthdaySettingsModel({
    required this.isEnabled,
    required this.bannerMessage,
    required this.employeeNotification,
    required this.teamNotification,
    required this.managerNotification,
    this.updatedAt,
  });

  final bool isEnabled;
  final String bannerMessage;
  final String employeeNotification;

  /// `{employee_name}` is the only placeholder the server fills in
  /// (Python `str.format(employee_name=...)`).
  final String teamNotification;
  final String managerNotification;
  final String? updatedAt;

  /// Web's EMPTY_BIRTHDAY for anything missing: enabled, empty texts.
  factory BirthdaySettingsModel.fromJson(Map<String, dynamic> j) {
    String text(String k) => j[k] is String ? j[k] as String : '';
    return BirthdaySettingsModel(
      isEnabled: j['is_enabled'] is bool ? j['is_enabled'] as bool : true,
      bannerMessage: text('banner_message_template'),
      employeeNotification: text('employee_notification_template'),
      teamNotification: text('team_notification_template'),
      managerNotification: text('manager_notification_template'),
      updatedAt: j['updated_at'] is String ? j['updated_at'] as String : null,
    );
  }

  /// The PATCH body: the five fields web edits, nothing else (the server
  /// changes only the keys sent).
  Map<String, dynamic> toJson() => {
        'is_enabled': isEnabled,
        'banner_message_template': bannerMessage,
        'employee_notification_template': employeeNotification,
        'team_notification_template': teamNotification,
        'manager_notification_template': managerNotification,
      };

  BirthdaySettingsModel copyWith({
    bool? isEnabled,
    String? bannerMessage,
    String? employeeNotification,
    String? teamNotification,
    String? managerNotification,
  }) =>
      BirthdaySettingsModel(
        isEnabled: isEnabled ?? this.isEnabled,
        bannerMessage: bannerMessage ?? this.bannerMessage,
        employeeNotification: employeeNotification ?? this.employeeNotification,
        teamNotification: teamNotification ?? this.teamNotification,
        managerNotification: managerNotification ?? this.managerNotification,
        updatedAt: updatedAt,
      );

  /// The server's rule (BirthdaySettingsView.patch): every text it receives
  /// must be non-blank after trimming, else 400 "<field> cannot be empty.".
  /// Returns the server field names that would be refused.
  List<String> emptyFields() => [
        if (bannerMessage.trim().isEmpty) 'banner_message_template',
        if (employeeNotification.trim().isEmpty) 'employee_notification_template',
        if (teamNotification.trim().isEmpty) 'team_notification_template',
        if (managerNotification.trim().isEmpty) 'manager_notification_template',
      ];
}
