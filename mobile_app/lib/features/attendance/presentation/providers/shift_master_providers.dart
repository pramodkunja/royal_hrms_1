import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/shift_assignment_models.dart' show canAssignShifts;
import '../../data/models/shift_master_models.dart';
import 'shift_assignment_providers.dart' show shiftAssignmentError, shiftAssignmentsProvider, shiftOptionsProvider;

/// The Shift Masters endpoints, exactly as web calls them.
class ShiftMasterRemoteDataSource {
  ShiftMasterRemoteDataSource(this._dio);
  final Dio _dio;

  /// GET /attendance/working-hours/?page&page_size=5&is_active=true
  Future<ShiftMasterPage> fetchPage(int page) async {
    final res = await _dio.get(ApiConstants.attendanceWorkingHoursPolicies,
        queryParameters: {'page': page, 'page_size': kShiftMasterPageSize, 'is_active': 'true'});
    final body = res.data;
    final d = body is Map ? body['data'] : null;
    return ShiftMasterPage.fromJson(d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{});
  }

  String _message(Response res, String fallback) {
    final body = res.data;
    return body is Map && body['message'] is String ? body['message'] as String : fallback;
  }

  /// POST /attendance/working-hours/
  Future<String> create(ShiftMasterForm form) async {
    final res = await _dio.post(ApiConstants.attendanceWorkingHoursPolicies, data: form.toJson());
    return _message(res, 'Working hours policy created successfully.');
  }

  /// PATCH /attendance/working-hours/<id>/
  Future<String> update(String id, ShiftMasterForm form) async {
    final res = await _dio.patch(ApiConstants.attendanceWorkingHoursPolicy(id), data: form.toJson());
    return _message(res, 'Working hours policy updated successfully.');
  }

  /// DELETE /attendance/working-hours/<id>/ — the server deactivates it.
  Future<String> deactivate(String id) async {
    final res = await _dio.delete(ApiConstants.attendanceWorkingHoursPolicy(id));
    return _message(res, 'Working hours policy deactivated successfully.');
  }
}

final shiftMasterDataSourceProvider =
    Provider<ShiftMasterRemoteDataSource>((ref) => ShiftMasterRemoteDataSource(ref.watch(dioProvider)));

final shiftMasterPageNumberProvider = StateProvider.autoDispose<int>((ref) => 1);

/// The card's current page of active shifts.
final shiftMastersProvider = FutureProvider.autoDispose<ShiftMasterPage>((ref) {
  final page = ref.watch(shiftMasterPageNumberProvider);
  return ref.read(shiftMasterDataSourceProvider).fetchPage(page);
});

/// Refused before any request: the user lacks the permission for this action.
class ShiftMasterDenied implements Exception {
  const ShiftMasterDenied();
  @override
  String toString() => 'Permission denied.';
}

/// Refused before any request: a save or deactivation is already running.
class ShiftMasterBusy implements Exception {
  const ShiftMasterBusy();
}

String shiftMasterError(Object e, String fallback) =>
    e is ShiftMasterDenied ? e.toString() : shiftAssignmentError(e, fallback);

final shiftMasterServiceProvider = Provider<ShiftMasterService>((ref) => ShiftMasterService(ref));

/// Writes go through here: the server's permission for the action is checked
/// first (create: attendance.create, edit: attendance.edit, deactivate:
/// attendance.delete), one write runs at a time, and after a confirmed write
/// the card, Shift Assignment's shift list and its rows reload.
class ShiftMasterService {
  ShiftMasterService(this._ref);
  final Ref _ref;
  bool _busy = false;

  Future<String> _write(bool allowed, Future<String> Function() run) async {
    if (!allowed) throw const ShiftMasterDenied();
    if (_busy) throw const ShiftMasterBusy();
    _busy = true;
    try {
      final message = await run();
      _ref
        ..invalidate(shiftMastersProvider)
        ..invalidate(shiftOptionsProvider)
        ..invalidate(shiftAssignmentsProvider);
      return message;
    } finally {
      _busy = false;
    }
  }

  UserEntity? get _user => _ref.read(authStateProvider).valueOrNull?.user;
  ShiftMasterRemoteDataSource get _ds => _ref.read(shiftMasterDataSourceProvider);

  Future<String> create(ShiftMasterForm form) => _write(canAssignShifts(_user), () => _ds.create(form));

  Future<String> update(String id, ShiftMasterForm form) =>
      _write(canEditShiftMasters(_user), () => _ds.update(id, form));

  Future<String> deactivate(String id) => _write(canDeleteShiftMasters(_user), () => _ds.deactivate(id));
}
