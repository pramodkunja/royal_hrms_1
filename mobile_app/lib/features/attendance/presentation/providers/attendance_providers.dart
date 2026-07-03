import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/attendance_remote_datasource.dart';
import '../../data/repositories/attendance_repository_impl.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/attendance_repository.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final attendanceDataSourceProvider = Provider<AttendanceRemoteDataSource>((ref) {
  return AttendanceRemoteDataSource(ref.watch(dioProvider));
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl(ref.watch(attendanceDataSourceProvider));
});

// ── My Attendance — Today / Clock In-Out ───────────────────────────────────────

final todayAttendanceProvider = AsyncNotifierProvider.autoDispose<
    TodayAttendanceNotifier, TodayAttendanceEntity>(TodayAttendanceNotifier.new);

class TodayAttendanceNotifier
    extends AutoDisposeAsyncNotifier<TodayAttendanceEntity> {
  AttendanceRepository get _repo => ref.read(attendanceRepositoryProvider);

  @override
  Future<TodayAttendanceEntity> build() => _repo.getToday();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getToday());
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> punch({
    required bool isCurrentlyClockedIn,
    required String attendanceMode,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? deviceName,
    String? deviceId,
    String? operatingSystem,
  }) async {
    try {
      final updated = await _repo.punch(
        punchType: isCurrentlyClockedIn ? 'OUT' : 'IN',
        attendanceMode: attendanceMode,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        deviceName: deviceName,
        deviceId: deviceId,
        operatingSystem: operatingSystem,
      );
      state = AsyncData(updated);
      ref.invalidate(attendanceStatsProvider);
      ref.invalidate(attendanceSummaryProvider);
      ref.invalidate(attendanceCalendarProvider);
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
  }
}

// ── My Attendance — Stats / Summary / Calendar (keyed by month, year) ─────────

typedef MonthYearKey = ({int year, int month});

final attendanceStatsProvider = FutureProvider.autoDispose
    .family<AttendanceStatsEntity, MonthYearKey>((ref, key) {
  return ref.watch(attendanceRepositoryProvider).getStats(month: key.month, year: key.year);
});

final attendanceSummaryProvider = FutureProvider.autoDispose
    .family<MonthlySummaryEntity, MonthYearKey>((ref, key) {
  return ref.watch(attendanceRepositoryProvider).getSummary(month: key.month, year: key.year);
});

final attendanceCalendarProvider = FutureProvider.autoDispose
    .family<AttendanceCalendarEntity, MonthYearKey>((ref, key) {
  return ref.watch(attendanceRepositoryProvider).getCalendar(month: key.month, year: key.year);
});

// ── My Attendance — Correction request ─────────────────────────────────────────

final attendanceCorrectionActionProvider =
    Provider.autoDispose<AttendanceCorrectionAction>((ref) {
  return AttendanceCorrectionAction(ref);
});

class AttendanceCorrectionAction {
  final Ref _ref;
  AttendanceCorrectionAction(this._ref);

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> submit({
    required String date,
    required String punchType,
    String? correctInTime,
    String? correctOutTime,
    required String reason,
    String? notes,
  }) async {
    try {
      await _ref.read(attendanceRepositoryProvider).submitCorrection(
            date: date,
            punchType: punchType,
            correctInTime: correctInTime,
            correctOutTime: correctOutTime,
            reason: reason,
            notes: notes,
          );
      _ref.invalidate(attendanceCalendarProvider);
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
  }
}

// ── HR Attendance — shared filters ──────────────────────────────────────────────

final hrAttendanceBranchFilterProvider = StateProvider.autoDispose<String>((ref) => '');
final hrAttendanceDepartmentFilterProvider = StateProvider.autoDispose<String>((ref) => '');

// ── HR Attendance — Dashboard (stats bar) ───────────────────────────────────────

final attendanceDashboardProvider =
    FutureProvider.autoDispose<AttendanceDashboardEntity>((ref) {
  final branch = ref.watch(hrAttendanceBranchFilterProvider);
  final department = ref.watch(hrAttendanceDepartmentFilterProvider);
  return ref
      .watch(attendanceRepositoryProvider)
      .getDashboard(branch: branch, department: department);
});

// ── HR Attendance — Records list (Attendance tab) ──────────────────────────────

final attendanceRecordsSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final attendanceRecordsProvider = AsyncNotifierProvider.autoDispose<
    AttendanceRecordsNotifier, List<AttendanceRowEntity>>(AttendanceRecordsNotifier.new);

class AttendanceRecordsNotifier
    extends AutoDisposeAsyncNotifier<List<AttendanceRowEntity>> {
  AttendanceRepository get _repo => ref.read(attendanceRepositoryProvider);

  @override
  Future<List<AttendanceRowEntity>> build() {
    final branch = ref.watch(hrAttendanceBranchFilterProvider);
    final department = ref.watch(hrAttendanceDepartmentFilterProvider);
    final search = ref.watch(attendanceRecordsSearchProvider);
    return _repo.getRecords(branch: branch, department: department, search: search);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

typedef RecordDetailKey = ({String id, bool isEmployeeId});

final attendanceRecordDetailProvider = FutureProvider.autoDispose
    .family<AttendanceDetailEntity, RecordDetailKey>((ref, key) {
  return ref
      .watch(attendanceRepositoryProvider)
      .getRecordDetail(key.id, isEmployeeId: key.isEmployeeId);
});

// ── HR Attendance — Overtime (OT Entry tab) ─────────────────────────────────────

final overtimeListProvider = AsyncNotifierProvider.autoDispose<OvertimeListNotifier,
    List<OvertimeRowEntity>>(OvertimeListNotifier.new);

class OvertimeListNotifier extends AutoDisposeAsyncNotifier<List<OvertimeRowEntity>> {
  AttendanceRepository get _repo => ref.read(attendanceRepositoryProvider);

  @override
  Future<List<OvertimeRowEntity>> build() {
    final branch = ref.watch(hrAttendanceBranchFilterProvider);
    final department = ref.watch(hrAttendanceDepartmentFilterProvider);
    return _repo.getOvertimeList(branch: branch, department: department);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> create({
    required String employeeId,
    required String date,
    required String otType,
    required String otStart,
    required String otEnd,
    String? approvedBy,
    String? reason,
  }) async {
    try {
      await _repo.createOvertime(
        employeeId: employeeId,
        date: date,
        otType: otType,
        otStart: otStart,
        otEnd: otEnd,
        approvedBy: approvedBy,
        reason: reason,
      );
      await refresh();
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
  }
}

// ── HR Attendance — Invalid Punches (read-only) ────────────────────────────────

final invalidPunchesProvider =
    FutureProvider.autoDispose<List<InvalidPunchEntity>>((ref) {
  final branch = ref.watch(hrAttendanceBranchFilterProvider);
  final department = ref.watch(hrAttendanceDepartmentFilterProvider);
  return ref
      .watch(attendanceRepositoryProvider)
      .getInvalidPunches(branch: branch, department: department);
});

// ── HR Attendance — Un-punches queue ────────────────────────────────────────────

final unpunchesProvider = AsyncNotifierProvider.autoDispose<UnpunchesNotifier,
    List<UnpunchRowEntity>>(UnpunchesNotifier.new);

class UnpunchesNotifier extends AutoDisposeAsyncNotifier<List<UnpunchRowEntity>> {
  AttendanceRepository get _repo => ref.read(attendanceRepositoryProvider);

  @override
  Future<List<UnpunchRowEntity>> build() {
    final branch = ref.watch(hrAttendanceBranchFilterProvider);
    final department = ref.watch(hrAttendanceDepartmentFilterProvider);
    return _repo.getUnpunches(branch: branch, department: department);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  /// Approve/reject the pending correction behind an un-punch row.
  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> reviewCorrection(String correctionId, {required bool approve}) async {
    try {
      await _repo.reviewCorrection(correctionId, approve: approve);
      await refresh();
      ref.invalidate(attendanceDashboardProvider);
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
  }
}

// ── Error helper ──────────────────────────────────────────────────────────────

/// Prefers the backend's exact `message` field (set via core/responses.py's
/// error()/first_error() helpers) so validation messages like "Out time must
/// be after in time." reach the user verbatim instead of a generic fallback.
String friendlyAttendanceError(Object e) {
  if (e is DioException) {
    final body = e.response?.data;
    if (body is Map) {
      final message = body['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    final statusCode = e.response?.statusCode;
    if (statusCode == 401) return 'Session expired. Please log in again.';
    if (statusCode == 403) return 'You do not have permission to do this.';
    if (statusCode == 404) return 'Not found.';
    if (statusCode == 409) return 'This request conflicts with an existing record.';
    if (statusCode != null && statusCode >= 500) {
      return 'Server error. Please try again later.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach server. Check your connection.';
    }
  }
  return e.toString().replaceAll('Exception:', '').trim();
}
