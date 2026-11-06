import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../leave/presentation/providers/leave_providers.dart';
import '../../data/models/leave_credit_models.dart';

/// The server's gate for all three endpoints: `_resolve_employee` checks
/// `has_perm(user, 'leave.approve')` — superuser or the role's codename, with
/// no settings.edit bypass — before anything else, then the per-employee
/// scope (`_can_manage_leave_credits`), which only the server can judge.
const kLeaveCreditPermission = 'leave.approve';
const kLeaveCreditDenied = 'Permission denied.';

bool canManageLeaveCredits(UserEntity? user) =>
    user != null && (user.isSuperuser || user.permissions.contains(kLeaveCreditPermission));

/// The three Leave Credits endpoints, exactly as web calls them.
class LeaveCreditRemoteDataSource {
  LeaveCreditRemoteDataSource(this._dio);
  final Dio _dio;

  /// GET /leave/credits/<code>/?year=[&leave_type=]. `null` on 403/404, where
  /// web renders nothing (no permission, or not an employee this user may manage).
  Future<LeaveCreditOverview?> fetchOverview(String employeeId, int year, String? leaveType) async {
    try {
      final res = await _dio.get(ApiConstants.leaveCreditsOverview(employeeId), queryParameters: {
        'year': year,
        if (leaveType != null && leaveType.isNotEmpty) 'leave_type': leaveType,
      });
      final body = res.data;
      final d = body is Map ? body['data'] : null;
      return LeaveCreditOverview.fromJson(d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{},
          requestedYear: year);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403 || status == 404) return null;
      rethrow;
    }
  }

  String _message(Response res, String fallback) {
    final body = res.data;
    return body is Map && body['message'] is String ? body['message'] as String : fallback;
  }

  /// POST /leave/credits/<code>/adjust/
  Future<String> adjust(String employeeId, Map<String, dynamic> body) async {
    final res = await _dio.post(ApiConstants.leaveCreditsAdjust(employeeId), data: body);
    return _message(res, 'Leave credits adjusted.');
  }

  /// POST /leave/credits/<code>/transactions/<id>/reverse/
  Future<String> reverse(String employeeId, String txnId, Map<String, dynamic> body) async {
    final res = await _dio.post(ApiConstants.leaveCreditsReverse(employeeId, txnId), data: body);
    return _message(res, 'Adjustment reversed.');
  }
}

final leaveCreditDataSourceProvider =
    Provider<LeaveCreditRemoteDataSource>((ref) => LeaveCreditRemoteDataSource(ref.watch(dioProvider)));

typedef LeaveCreditQuery = ({String employeeId, int year, String? leaveType});

/// The statement for one employee, year and (optionally) selected leave type.
/// `null` means the section is not shown: the user lacks leave.approve (no
/// request is made) or the server answered 403/404.
final leaveCreditOverviewProvider =
    FutureProvider.autoDispose.family<LeaveCreditOverview?, LeaveCreditQuery>((ref, q) async {
  final user = ref.watch(authStateProvider).valueOrNull?.user;
  if (!canManageLeaveCredits(user)) return null;
  return ref.read(leaveCreditDataSourceProvider).fetchOverview(q.employeeId, q.year, q.leaveType);
});

/// Web `newKey()`: a hyphen-free UUID, sent as `idempotency_key` (server: 1–64 chars).
String newLeaveCreditKey() => const Uuid().v4().replaceAll('-', '');

/// Refused before any request: the user lacks leave.approve.
class LeaveCreditDenied implements Exception {
  const LeaveCreditDenied();
  @override
  String toString() => kLeaveCreditDenied;
}

/// Refused before any request: an adjustment or reversal is already running.
class LeaveCreditBusy implements Exception {
  const LeaveCreditBusy();
}

/// The server's `message` when it sent one (validation 400, conflict 409,
/// 403, 404), else web's fallback.
String leaveCreditError(Object e) {
  if (e is LeaveCreditDenied) return e.toString();
  if (e is DioException) {
    final body = e.response?.data;
    if (body is Map && body['message'] is String && (body['message'] as String).isNotEmpty) {
      return body['message'] as String;
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach server. Check your connection.';
    }
  }
  return 'Something went wrong. Please try again.';
}

final leaveCreditServiceProvider = Provider<LeaveCreditService>((ref) => LeaveCreditService(ref));

/// Writes go through here: leave.approve first, one write at a time, and
/// after a confirmed write the statement and the Leave tab above it reload
/// (web: `refetch(); onChanged?.()`). On failure nothing reloads and the
/// caller keeps the same idempotency key for a retry.
class LeaveCreditService {
  LeaveCreditService(this._ref);
  final Ref _ref;
  bool _busy = false;

  bool get busy => _busy;

  UserEntity? get _user => _ref.read(authStateProvider).valueOrNull?.user;
  LeaveCreditRemoteDataSource get _ds => _ref.read(leaveCreditDataSourceProvider);

  Future<String> _write(Future<String> Function() run) async {
    if (!canManageLeaveCredits(_user)) throw const LeaveCreditDenied();
    if (_busy) throw const LeaveCreditBusy();
    _busy = true;
    try {
      final message = await run();
      _ref
        ..invalidate(leaveCreditOverviewProvider)
        ..invalidate(employeeLeaveStatsProvider)
        ..invalidate(employeeLeaveRequestsProvider);
      return message;
    } finally {
      _busy = false;
    }
  }

  /// Body exactly as web: amount as `String(Number(input))`.
  Future<String> adjust({
    required String employeeId,
    required String leaveType,
    required int year,
    required double amount,
    required String reason,
    required String idempotencyKey,
  }) =>
      _write(() => _ds.adjust(employeeId, {
            'leave_type': leaveType,
            'year': year,
            'amount': creditNum(amount),
            'reason': reason,
            'idempotency_key': idempotencyKey,
          }));

  Future<String> reverse({
    required String employeeId,
    required String txnId,
    required String reason,
    required String idempotencyKey,
  }) =>
      _write(() => _ds.reverse(employeeId, txnId, {'reason': reason, 'idempotency_key': idempotencyKey}));
}
