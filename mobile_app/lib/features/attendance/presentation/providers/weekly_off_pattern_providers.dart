import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/weekly_off_pattern_models.dart';
import 'shift_assignment_providers.dart' show shiftAssignmentError;
import 'weekly_off_assignment_providers.dart' show weeklyOffAssignmentsProvider, weeklyOffPatternsProvider;

/// The Weekly Off Patterns endpoints, exactly as web calls them.
class WeeklyOffPatternRemoteDataSource {
  WeeklyOffPatternRemoteDataSource(this._dio);
  final Dio _dio;

  /// GET /attendance/weekly-days/?page&page_size=3 (all patterns, any status).
  Future<WeeklyOffPatternPage> fetchPage(int page) async {
    final res = await _dio.get(ApiConstants.attendanceWeeklyDayPolicies,
        queryParameters: {'page': page, 'page_size': kWeeklyOffPatternPageSize});
    final body = res.data;
    final d = body is Map ? body['data'] : null;
    return WeeklyOffPatternPage.fromJson(d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{});
  }

  String _message(Response res, String fallback) {
    final body = res.data;
    return body is Map && body['message'] is String ? body['message'] as String : fallback;
  }

  /// POST /attendance/weekly-days/
  Future<String> create(WeeklyOffPatternForm form) async {
    final res = await _dio.post(ApiConstants.attendanceWeeklyDayPolicies, data: form.toJson());
    return _message(res, 'Weekly day policy created successfully.');
  }

  /// PATCH /attendance/weekly-days/<id>/
  Future<String> update(String id, WeeklyOffPatternForm form) async {
    final res = await _dio.patch(ApiConstants.attendanceWeeklyDayPolicy(id), data: form.toJson());
    return _message(res, 'Weekly day policy updated successfully.');
  }

  /// DELETE /attendance/weekly-days/<id>/ — the server deactivates it.
  Future<String> deactivate(String id) async {
    final res = await _dio.delete(ApiConstants.attendanceWeeklyDayPolicy(id));
    return _message(res, 'Weekly day policy deactivated successfully.');
  }
}

final weeklyOffPatternDataSourceProvider =
    Provider<WeeklyOffPatternRemoteDataSource>((ref) => WeeklyOffPatternRemoteDataSource(ref.watch(dioProvider)));

final weeklyOffPatternPageNumberProvider = StateProvider.autoDispose<int>((ref) => 1);

/// The card's current page of patterns.
final weeklyOffPatternCardProvider = FutureProvider.autoDispose<WeeklyOffPatternPage>((ref) {
  final page = ref.watch(weeklyOffPatternPageNumberProvider);
  return ref.read(weeklyOffPatternDataSourceProvider).fetchPage(page);
});

/// Refused before any request: the user lacks the permission for this action.
class WeeklyOffPatternDenied implements Exception {
  const WeeklyOffPatternDenied();
  @override
  String toString() => 'Permission denied.';
}

/// Refused before any request: a save or deactivation is already running.
class WeeklyOffPatternBusy implements Exception {
  const WeeklyOffPatternBusy();
}

String weeklyOffPatternError(Object e, String fallback) =>
    e is WeeklyOffPatternDenied ? e.toString() : shiftAssignmentError(e, fallback);

final weeklyOffPatternServiceProvider = Provider<WeeklyOffPatternService>((ref) => WeeklyOffPatternService(ref));

/// Writes go through here: the server's permission for the action first,
/// one write at a time, and after a confirmed write the card, Weekly Off
/// Assignment's active patterns and its rows reload.
class WeeklyOffPatternService {
  WeeklyOffPatternService(this._ref);
  final Ref _ref;
  bool _busy = false;

  UserEntity? get _user => _ref.read(authStateProvider).valueOrNull?.user;
  WeeklyOffPatternRemoteDataSource get _ds => _ref.read(weeklyOffPatternDataSourceProvider);

  Future<String> _write(bool allowed, Future<String> Function() run) async {
    if (!allowed) throw const WeeklyOffPatternDenied();
    if (_busy) throw const WeeklyOffPatternBusy();
    _busy = true;
    try {
      final message = await run();
      _ref
        ..invalidate(weeklyOffPatternCardProvider)
        ..invalidate(weeklyOffPatternsProvider)
        ..invalidate(weeklyOffAssignmentsProvider);
      return message;
    } finally {
      _busy = false;
    }
  }

  Future<String> create(WeeklyOffPatternForm form) => _write(canCreateWeeklyOffPatterns(_user), () => _ds.create(form));

  Future<String> update(String id, WeeklyOffPatternForm form) =>
      _write(canEditWeeklyOffPatterns(_user), () => _ds.update(id, form));

  Future<String> deactivate(String id) => _write(canDeleteWeeklyOffPatterns(_user), () => _ds.deactivate(id));
}
