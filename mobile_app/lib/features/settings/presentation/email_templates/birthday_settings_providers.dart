import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/birthday_settings_model.dart';

/// Production BirthdaySettingsView: GET needs `has_perm(user, 'employees.view')`,
/// PATCH needs `has_perm(user, 'settings.edit')` (superuser or the role's codename).
bool canViewBirthdaySettings(UserEntity? user) =>
    user != null && (user.isSuperuser || user.permissions.contains('employees.view'));

bool canEditBirthdaySettings(UserEntity? user) =>
    user != null && (user.isSuperuser || user.permissions.contains('settings.edit'));

const kBirthdaySettingsDenied = 'You do not have permission to perform this action.';

/// Refused before any request.
class BirthdaySettingsRefused implements Exception {
  const BirthdaySettingsRefused(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The server's message, else [fallback] (web: "Failed to save birthday settings").
String birthdaySettingsError(Object e, String fallback) {
  if (e is BirthdaySettingsRefused) return e.message;
  if (e is DioException) {
    final body = e.response?.data;
    if (body is Map && body['message'] is String && (body['message'] as String).isNotEmpty) {
      return body['message'] as String;
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach server. Check your connection.';
    }
  }
  return fallback;
}

Map<String, dynamic> _data(Object? body) {
  final d = body is Map ? body['data'] : null;
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
}

final birthdaySettingsProvider =
    AsyncNotifierProvider.autoDispose<BirthdaySettingsNotifier, BirthdaySettingsModel?>(BirthdaySettingsNotifier.new);

/// `null` = the user may not read these settings (no request is made).
class BirthdaySettingsNotifier extends AutoDisposeAsyncNotifier<BirthdaySettingsModel?> {
  bool _saving = false;

  Dio get _dio => ref.read(dioProvider);
  UserEntity? get _user => ref.read(authStateProvider).valueOrNull?.user;

  @override
  Future<BirthdaySettingsModel?> build() async {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    if (!canViewBirthdaySettings(user)) return null;
    final res = await _dio.get(ApiConstants.hrmsBirthdaySettings);
    return BirthdaySettingsModel.fromJson(_data(res.data));
  }

  /// PATCH /birthdays/settings/ with the five fields. Refused before any
  /// request without settings.edit, with a blank text, or while a save runs.
  /// On success the card shows the server's saved values.
  Future<BirthdaySettingsModel> save(BirthdaySettingsModel form) async {
    if (!canEditBirthdaySettings(_user)) throw const BirthdaySettingsRefused(kBirthdaySettingsDenied);
    final empty = form.emptyFields();
    if (empty.isNotEmpty) throw BirthdaySettingsRefused('${empty.first} cannot be empty.');
    if (_saving) throw const BirthdaySettingsRefused('A save is already in progress.');
    _saving = true;
    try {
      final res = await _dio.patch(ApiConstants.hrmsBirthdaySettings, data: form.toJson());
      final data = _data(res.data);
      final saved = data.isEmpty ? form : BirthdaySettingsModel.fromJson(data);
      state = AsyncData(saved);
      return saved;
    } finally {
      _saving = false;
    }
  }
}
