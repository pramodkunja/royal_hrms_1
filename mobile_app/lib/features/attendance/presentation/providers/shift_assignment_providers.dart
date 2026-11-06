import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/shift_assignment_models.dart';

/// The Shift Assignment endpoints, exactly as web calls them.
class ShiftAssignmentRemoteDataSource {
  ShiftAssignmentRemoteDataSource(this._dio);
  final Dio _dio;

  Map<String, dynamic> _data(Object? body) {
    final d = body is Map ? body['data'] : null;
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  /// GET /attendance/working-hours/?page_size=50&is_active=true
  Future<List<ShiftOption>> fetchShifts() async {
    final res = await _dio
        .get(ApiConstants.attendanceWorkingHoursPolicies, queryParameters: {'page_size': 50, 'is_active': 'true'});
    final list = _data(res.data)['results'];
    return [
      if (list is List)
        for (final s in list)
          if (s is Map) ShiftOption.fromJson(Map<String, dynamic>.from(s)),
    ];
  }

  /// GET /attendance/shift-assignments/?branch&department&shift&status&page&page_size=20
  Future<ShiftAssignmentPage> fetchAssignments(ShiftAssignmentQuery q) async {
    final res = await _dio.get(ApiConstants.attendanceShiftAssignments, queryParameters: q.params());
    return ShiftAssignmentPage.fromJson(_data(res.data));
  }

  /// POST /attendance/shift-assignments/ {employee_id, shift, effective_from}
  Future<void> assign({required String employeeId, required String shiftId, required String effectiveFrom}) async {
    await _dio.post(ApiConstants.attendanceShiftAssignments,
        data: {'employee_id': employeeId, 'shift': shiftId, 'effective_from': effectiveFrom});
  }

  /// POST /attendance/shift-assignments/bulk/ {shift, effective_from, branch,
  /// department} — the server resolves (and scopes) who it applies to.
  /// Returns how many employees were assigned.
  Future<int> bulkAssign({
    required String shiftId,
    required String effectiveFrom,
    required String branch,
    required String department,
  }) async {
    final res = await _dio.post(ApiConstants.attendanceShiftAssignmentsBulk, data: {
      'shift': shiftId,
      'effective_from': effectiveFrom,
      'branch': branch,
      'department': department,
    });
    final count = _data(res.data)['count'];
    return count is num ? count.toInt() : 0;
  }
}

final shiftAssignmentDataSourceProvider =
    Provider<ShiftAssignmentRemoteDataSource>((ref) => ShiftAssignmentRemoteDataSource(ref.watch(dioProvider)));

/// "Today" for the Effective From default (tests override it).
final shiftAssignmentClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Active shift masters for the filter and the assign forms.
final shiftOptionsProvider = FutureProvider.autoDispose<List<ShiftOption>>(
  (ref) => ref.read(shiftAssignmentDataSourceProvider).fetchShifts(),
);

/// Current list filters (and page).
final shiftAssignmentQueryProvider =
    StateProvider.autoDispose<ShiftAssignmentQuery>((ref) => const ShiftAssignmentQuery());

/// The visible page. A restricted user's branch is always their own (web
/// getEffectiveBranch); the server scopes it again either way.
final shiftAssignmentsProvider = FutureProvider.autoDispose<ShiftAssignmentPage>((ref) {
  final q = ref.watch(shiftAssignmentQueryProvider);
  final user = ref.watch(authStateProvider).valueOrNull?.user;
  final scoped = isUnrestrictedBranchUser(user) ? q : q.copyWith(branch: effectiveBranch(user), page: q.page);
  return ref.read(shiftAssignmentDataSourceProvider).fetchAssignments(scoped);
});

/// Refused before any request: the user lacks attendance.create.
class ShiftAssignDenied implements Exception {
  const ShiftAssignDenied();
  @override
  String toString() => 'Permission denied.';
}

/// Refused before any request: an assignment is already being saved.
class ShiftAssignBusy implements Exception {
  const ShiftAssignBusy();
}

/// The server's message (web shows err.message), else [fallback].
String shiftAssignmentError(Object e, String fallback) {
  if (e is ShiftAssignDenied) return e.toString();
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

final shiftAssignmentServiceProvider = Provider<ShiftAssignmentService>((ref) => ShiftAssignmentService(ref));

/// Writes go through here: attendance.create is checked first (the server
/// checks it too), one save runs at a time, and the list reloads after a
/// confirmed save.
class ShiftAssignmentService {
  ShiftAssignmentService(this._ref);
  final Ref _ref;
  bool _busy = false;

  Future<T> _write<T>(Future<T> Function() run) async {
    if (!canAssignShifts(_ref.read(authStateProvider).valueOrNull?.user)) throw const ShiftAssignDenied();
    if (_busy) throw const ShiftAssignBusy();
    _busy = true;
    try {
      final r = await run();
      _ref.invalidate(shiftAssignmentsProvider);
      return r;
    } finally {
      _busy = false;
    }
  }

  Future<void> assign(ShiftAssignmentRow row, String shiftId, DateTime from) => _write(() => _ref
      .read(shiftAssignmentDataSourceProvider)
      .assign(employeeId: row.employeeId, shiftId: shiftId, effectiveFrom: isoDate(from)));

  Future<int> bulkAssign(
          {required String shiftId, required DateTime from, required String branch, required String department}) =>
      _write(() => _ref
          .read(shiftAssignmentDataSourceProvider)
          .bulkAssign(shiftId: shiftId, effectiveFrom: isoDate(from), branch: branch, department: department));
}
