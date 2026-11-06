import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/api_client.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../data/datasources/monthly_leave_remote_datasource.dart';
import '../../../data/models/monthly_leave_models.dart';

final monthlyLeaveDataSourceProvider =
    Provider<MonthlyLeaveRemoteDataSource>((ref) => MonthlyLeaveRemoteDataSource(ref.watch(dioProvider)));

/// "Today" for the month/year defaults and year list (tests override it).
final monthlyLeaveClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Bumped after every successful import, manual save or edit so the
/// assignments list reloads from the server (web MonthlyLeaveTab refreshKey).
final monthlyLeaveRefreshProvider = StateProvider<int>((ref) => 0);

typedef YearMonth = ({int year, int month});

/// The month's current credits (loaded only while the section is open).
final monthlyAssignmentsProvider = FutureProvider.autoDispose.family<MonthlyAssignments, YearMonth>((ref, key) {
  ref.watch(monthlyLeaveRefreshProvider);
  return ref.read(monthlyLeaveServiceProvider).assignments(key.year, key.month);
});

/// A file picked for import.
typedef PickedFile = ({String name, Uint8List bytes, int size});

/// Picks a .csv / .xlsx file, or null when cancelled (tests override it).
final monthlyImportFilePickerProvider = Provider<Future<PickedFile?> Function()>((ref) => () async {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
        withData: true,
      );
      final f = (r == null || r.files.isEmpty) ? null : r.files.single;
      if (f == null || f.bytes == null) return null;
      return (name: f.name, bytes: f.bytes!, size: f.size);
    });

/// Saves a sample file; returns where, or null when cancelled.
final monthlySampleSaverProvider = Provider<Future<String?> Function(String fileName, Uint8List bytes)>(
  (ref) => (fileName, bytes) => FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: [fileName.split('.').last],
      ),
);

/// Refused before any request: the user lacks leave.approve.
class MonthlyLeaveDenied implements Exception {
  const MonthlyLeaveDenied();
  @override
  String toString() => 'Permission denied.';
}

/// Refused before any request: the same kind of save is already running.
class MonthlyLeaveBusy implements Exception {
  const MonthlyLeaveBusy();
}

/// Web apiMessage(err, fallback): the server's message, else the fallback.
String monthlyLeaveError(Object e, String fallback) {
  if (e is MonthlyLeaveDenied) return e.toString();
  if (e is DioException) {
    final body = e.response?.data;
    if (body is Map && body['message'] is String && (body['message'] as String).isNotEmpty) {
      return body['message'] as String;
    }
  }
  return fallback;
}

final monthlyLeaveServiceProvider = Provider<MonthlyLeaveService>((ref) => MonthlyLeaveService(ref));

/// Every Monthly Leave call goes through here: leave.approve is checked
/// first (the server checks it too), and a write of the same kind can't
/// start while one is running.
class MonthlyLeaveService {
  MonthlyLeaveService(this._ref);
  final Ref _ref;
  final _running = <String>{};

  MonthlyLeaveRemoteDataSource get _ds => _ref.read(monthlyLeaveDataSourceProvider);

  void _check() {
    if (!canManageMonthlyCredits(_ref.read(authStateProvider).valueOrNull?.user)) throw const MonthlyLeaveDenied();
  }

  Future<T> _write<T>(String kind, Future<T> Function() run) async {
    _check();
    if (!_running.add(kind)) throw const MonthlyLeaveBusy();
    try {
      return await run();
    } finally {
      _running.remove(kind);
    }
  }

  void _changed() => _ref.read(monthlyLeaveRefreshProvider.notifier).state++;

  Future<MonthlyAssignments> assignments(int year, int month) async {
    _check();
    return _ds.fetchAssignments(year: year, month: month);
  }

  Future<String> setCredit(MonthlyAssignment row, String credit) => _write('set', () async {
        final message = await _ds.setCredit(
            employeeId: row.employeeId, leaveType: row.leaveType, year: row.year, month: row.month, credit: credit);
        _changed();
        return message;
      });

  Future<MonthlyPlan> bulkReview(List<String> ids, String leaveType, int year, int month, String credit) => _write(
      'bulk', () => _ds.bulkReview(employeeIds: ids, leaveType: leaveType, year: year, month: month, credit: credit));

  Future<MonthlyApplyResult> bulkApply(List<String> ids, String leaveType, int year, int month, String credit) =>
      _write('bulk', () async {
        final r = await _ds.bulkApply(employeeIds: ids, leaveType: leaveType, year: year, month: month, credit: credit);
        _changed();
        return r;
      });

  Future<MonthlyPlan> importPreview(PickedFile file, int year, int month) =>
      _write('import', () => _ds.importPreview(bytes: file.bytes, fileName: file.name, year: year, month: month));

  Future<MonthlyApplyResult> importApply(PickedFile file, int year, int month) => _write('import', () async {
        final r = await _ds.importApply(bytes: file.bytes, fileName: file.name, year: year, month: month);
        _changed();
        return r;
      });

  Future<List<int>> sample(String format) => _write('sample-$format', () => _ds.sample(format));
}
