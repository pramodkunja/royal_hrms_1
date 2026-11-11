import 'package:flutter/foundation.dart';

import '../../../../shared/validators/form_validators.dart';
import 'smtp_providers.dart';

enum SmtpPriority { high, normal, low, none }
enum ReceiverEmailType { emailId, personalEmailId }

@immutable
class SmtpModel {
  final int id;
  final String name;
  final String smtpType;        // 'local' | 'server'
  final String smtpTypeDisplay; // 'Gmail / Custom SMTP' | 'Dedicated Mail Server'
  /// SMTPSettings.provider: one of kSmtpProviderOrder, '' (unspecified /
  /// pre-dates the picker) or — never from this app — something unknown.
  final String provider;
  final String providerDisplay;
  final String host;
  final int port;
  final String username;
  final String passwordDisplay;
  final bool useTls;
  final String senderName;
  final String fromEmail;
  final String bccEmail;
  final SmtpPriority priority;
  final ReceiverEmailType receiverEmailType;
  final bool isActive;
  final String updatedAt;

  const SmtpModel({
    required this.id,
    required this.name,
    required this.smtpType,
    required this.smtpTypeDisplay,
    this.provider = '',
    this.providerDisplay = '',
    required this.host,
    required this.port,
    required this.username,
    required this.passwordDisplay,
    required this.useTls,
    required this.senderName,
    required this.fromEmail,
    required this.bccEmail,
    required this.priority,
    required this.receiverEmailType,
    required this.isActive,
    required this.updatedAt,
  });

  factory SmtpModel.fromJson(Map<String, dynamic> json) => SmtpModel(
    id:                json['id'] as int,
    name:              json['name'] as String? ?? '',
    smtpType:          json['smtp_type'] as String? ?? 'local',
    smtpTypeDisplay:   json['smtp_type_display'] as String? ?? '',
    provider:          json['provider'] is String ? json['provider'] as String : '',
    providerDisplay:   json['provider_display'] as String? ?? '',
    host:              json['host'] as String? ?? '',
    port:              json['port'] as int? ?? 587,
    username:          json['username'] as String? ?? '',
    passwordDisplay:   json['password_display'] as String? ?? '••••••••',
    useTls:            json['use_tls'] as bool? ?? true,
    senderName:        json['sender_name'] as String? ?? '',
    fromEmail:         json['from_email'] as String? ?? '',
    bccEmail:          json['bcc_email'] as String? ?? '',
    priority:          _parsePriority(json['priority'] as String?),
    receiverEmailType: _parseReceiverType(json['receiver_email_type'] as String?),
    isActive:          json['is_active'] as bool? ?? false,
    updatedAt:         json['updated_at'] as String? ?? '',
  );

  static SmtpPriority _parsePriority(String? value) => switch (value) {
    'high'   => SmtpPriority.high,
    'normal' => SmtpPriority.normal,
    'low'    => SmtpPriority.low,
    _        => SmtpPriority.none,
  };

  static ReceiverEmailType _parseReceiverType(String? value) => switch (value) {
    'personal_email_id' => ReceiverEmailType.personalEmailId,
    _                   => ReceiverEmailType.emailId,
  };
}

// ── Form model ────────────────────────────────────────────────────────────────

class SmtpFormData {
  String smtpType;

  /// SMTPSettings.provider — set by the Add picker; kept as loaded on edit.
  String provider;
  String name;
  String host;
  int port;
  String username;
  String password;
  bool useTls;
  String senderName;
  String fromEmail;
  String bccEmail;
  SmtpPriority priority;
  ReceiverEmailType receiverEmailType;

  SmtpFormData({
    this.smtpType = 'local',
    this.provider = '',
    this.name = '',
    this.host = '',
    this.port = 587,
    this.username = '',
    this.password = '',
    this.useTls = true,
    this.senderName = '',
    this.fromEmail = '',
    this.bccEmail = '',
    this.priority = SmtpPriority.normal,
    this.receiverEmailType = ReceiverEmailType.emailId,
  });

  /// Web SmtpModal add mode: EMPTY_SMTP_FORM with the chosen provider's
  /// preset type / host / port / TLS.
  factory SmtpFormData.forProvider(String provider) {
    final p = kSmtpProviderPresets[provider]!;
    return SmtpFormData(provider: provider, smtpType: p.smtpType, host: p.host, port: p.port, useTls: p.useTls);
  }

  factory SmtpFormData.fromModel(SmtpModel model) => SmtpFormData(
    smtpType:          model.smtpType,
    provider:          model.provider,
    name:              model.name,
    host:              model.host,
    port:              model.port,
    username:          model.username,
    password:          '',
    useTls:            model.useTls,
    senderName:        model.senderName,
    fromEmail:         model.fromEmail,
    bccEmail:          model.bccEmail,
    priority:          model.priority,
    receiverEmailType: model.receiverEmailType,
  );

  bool get isLocal => smtpType == 'local';

  /// Web formToPayload. `provider` is always sent as web does — except a
  /// value this app doesn't know (the backend would refuse it as an invalid
  /// choice): it is left out, so the stored value is kept, never overwritten.
  /// A Dedicated Mail Server (smtp_type 'server') hides host/username; the
  /// backend still requires both, so web's placeholders are sent.
  Map<String, dynamic> toJson({required bool isAdd}) => {
    'smtp_type':           smtpType,
    if (isKnownSmtpProvider(provider)) 'provider': provider,
    'name':                name,
    if (isLocal) ...{
      'host':              host,
      'port':              port,
      'username':          username,
      if (isAdd || password.isNotEmpty) 'password': password,
    } else ...{
      'host':              host.isNotEmpty ? host : 'localhost',
      'port':              port,
      'username':          username.isNotEmpty ? username : (fromEmail.isNotEmpty ? fromEmail : 'server'),
    },
    'use_tls':             useTls,
    'sender_name':         senderName,
    'from_email':          fromEmail,
    'bcc_email':           bccEmail,
    'priority':            _priorityStr(priority),
    'receiver_email_type': _receiverStr(receiverEmailType),
  };

  static String _priorityStr(SmtpPriority p) => switch (p) {
    SmtpPriority.high   => 'high',
    SmtpPriority.normal => 'normal',
    SmtpPriority.low    => 'low',
    SmtpPriority.none   => '',
  };

  static String _receiverStr(ReceiverEmailType r) => switch (r) {
    ReceiverEmailType.personalEmailId => 'personal_email_id',
    ReceiverEmailType.emailId         => 'email_id',
  };

  Map<String, String?> validate({required bool isAdd}) {
    final errors = <String, String?>{};
    if (name.trim().isEmpty)      errors['name']      = 'Configuration name is required';
    // Web validateSmtpForm: host / username / password only for 'local'.
    if (isLocal && host.trim().isEmpty) errors['host'] = 'Host is required';
    // Backend declares both as EmailField (from_email required, bcc_email
    // optional) — SMTPSettingsSerializer/SMTPTestSerializer, so a malformed
    // value 400s even though `username` next to it deliberately accepts
    // plain (non-email) usernames too.
    if (fromEmail.trim().isEmpty) {
      errors['fromEmail'] = 'From email is required';
    } else {
      final err = FormValidators.email(fromEmail);
      if (err != null) errors['fromEmail'] = err;
    }
    if (bccEmail.trim().isNotEmpty) {
      final err = FormValidators.email(bccEmail);
      if (err != null) errors['bccEmail'] = err;
    }
    if (isLocal && username.trim().isEmpty) errors['username'] = 'Username is required';
    if (isLocal && isAdd && password.trim().isEmpty) errors['password'] = 'Password is required';
    return errors;
  }
}
