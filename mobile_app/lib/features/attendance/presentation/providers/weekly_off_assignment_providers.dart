import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/shift_assignment_models.dart'
    show canAssignShifts, effectiveBranch, isUnrestrictedBranchUser, isoDate;
import '../../data/models/weekly_off_assignment_models.dart';
import 'shift_assignment_providers.dart' show shiftAssignmentError;

/// The Weekly Off Assignment endpoints, exactly as web calls them.
class WeeklyOffAssignmentRemoteDataSource {
  WeeklyOffAssignmentRemoteDataSource(this._dio);
  final Dio _dio;

  Map<String, dynamic> _data(Object? body) {
    final d = body is Map ? body['data'] : null;
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  /// GET /attendance/weekly-days/?page_size=50&is_active=true
  Future<List<WeeklyOffPattern>> fetchPatterns() async {
    final res = await _dio
        .get(ApiConstants.attendanceWeeklyDayPolicies, queryParameters: {'page_size': 50, 'is_active': 'true'});
    final list = _data(res.data)['results'];
    return [
      if (list is List)
        for (final p in list)
          if (p is Map) WeeklyOffPattern.fromJson(Map<String, dynamic>.from(p)),
    ];
  }

  /// GET /attendance/weekly-off-assignments/?branch&department&pattern&status&page&page_size=20
  Future<WeeklyOffAssignmentPage> fetchAssignments(WeeklyOffQuery q) async {
    final res = await _dio.get(ApiConstants.attendanceWeeklyOffAssignments, queryParameters: q.params());
    return WeeklyOffAssignmentPage.fromJson(_data(res.data));
  }

  /// POST /attendance/weekly-off-assignments/ {employee_id, pattern, effective_from}
  Future<void> assign({required String employeeId, required String patternId, required String effectiveFrom}) async {
    await _dio.post(ApiConstants.attendanceWeeklyOffAssignments,
        data: {'employee_id': employeeId, 'pattern': patternId, 'effective_from': effectiveFrom});
  }

  /// POST /attendance/weekly-off-assignments/bulk/ {pattern, effective_from,
  /// branch, department} — resolved and scoped by the server. Returns the
  /// number of employees assigned.
  Future<int> bulkAssign({
    required String patternId,
    required String effectiveFrom,
    required String branch,
    required String department,
  }) async {
    final res = await _dio.post(ApiConstants.attendanceWeeklyOffAssignmentsBulk, data: {
      'pattern': patternId,
      'effective_from': effectiveFrom,
      'branch': branch,
      'department': department,
    });
    final count = _data(res.data)['count'];
    return count is num ? count.toInt() : 0;
  }
}

final weeklyOffDataSourceProvider =
    Provider<WeeklyOffAssignmentRemoteDataSource>((ref) => WeeklyOffAssignmentRemoteDataSource(ref.watch(dioProvider)));

/// "Today" for the Effective From default (tests override it).
final weeklyOffClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Active weekly-off patterns for the filter and the assign forms.
final weeklyOffPatternsProvider = FutureProvider.autoDispose<List<WeeklyOffPattern>>(
  (ref) => ref.read(weeklyOffDataSourceProvider).fetchPatterns(),
);

final weeklyOffQueryProvider = StateProvider.autoDispose<WeeklyOffQuery>((ref) => const WeeklyOffQuery());

/// The visible page (a newer filter/page replaces any earlier request's
/// result). A restricted user's branch is always their own; the server scopes
/// it again either way.
final weeklyOffAssignmentsProvider = FutureProvider.autoDispose<WeeklyOffAssignmentPage>((ref) {
  final q = ref.watch(weeklyOffQueryProvider);
  final user = ref.watch(authStateProvider).valueOrNull?.user;
  final scoped = isUnrestrictedBranchUser(user) ? q : q.copyWith(branch: effectiveBranch(user), page: q.page);
  return ref.read(weeklyOffDataSourceProvider).fetchAssignments(scoped);
});

/// Refused before any request: the user lacks attendance.create.
class WeeklyOffAssignDenied implements Exception {
  const WeeklyOffAssignDenied();
  @override
  String toString() => 'Permission denied.';
}

/// Refused before any request: an assignment is already being saved.
class WeeklyOffAssignBusy implements Exception {
  const WeeklyOffAssignBusy();
}

/// The server's message (web shows err.message), else [fallback].
String weeklyOffError(Object e, String fallback) =>
    e is WeeklyOffAssignDenied ? e.toString() : shiftAssignmentError(e, fallback);

final weeklyOffServiceProvider = Provider<WeeklyOffAssignmentService>((ref) => WeeklyOffAssignmentService(ref));

/// Writes go through here: attendance.create first (the server checks it
/// too), one save at a time, list reloaded after a confirmed save.
class WeeklyOffAssignmentService {
  WeeklyOffAssignmentService(this._ref);
  final Ref _ref;
  bool _busy = false;

  Future<T> _write<T>(Future<T> Function() run) async {
    if (!canAssignShifts(_ref.read(authStateProvider).valueOrNull?.user)) throw const WeeklyOffAssignDenied();
    if (_busy) throw const WeeklyOffAssignBusy();
    _busy = true;
    try {
      final r = await run();
      _ref.invalidate(weeklyOffAssignmentsProvider);
      return r;
    } finally {
      _busy = false;
    }
  }

  Future<void> assign(WeeklyOffAssignmentRow row, String patternId, DateTime from) => _write(() => _ref
      .read(weeklyOffDataSourceProvider)
      .assign(employeeId: row.employeeId, patternId: patternId, effectiveFrom: isoDate(from)));

  Future<int> bulkAssign(
          {required String patternId, required DateTime from, required String branch, required String department}) =>
      _write(() => _ref
          .read(weeklyOffDataSourceProvider)
          .bulkAssign(patternId: patternId, effectiveFrom: isoDate(from), branch: branch, department: department));
}
