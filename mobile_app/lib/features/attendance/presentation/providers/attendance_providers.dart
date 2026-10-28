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

String? _fmtDate(DateTime? d) => d == null
    ? null
    : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  /// Returns null if the location is allowed, or a user-facing rejection
  /// message otherwise — same {null|message} contract as punch() below, so
  /// callers can handle both identically. Read-only; does not touch `state`.
  /// Callers should run this BEFORE opening face capture and before the
  /// real punch() call — see AttendanceRingCard._toggleClock — but it never
  /// replaces punch()'s own authoritative, independent geofence check.
  Future<String?> checkGeofence({
    required String attendanceMode,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    try {
      await _repo.checkGeofence(
        attendanceMode: attendanceMode,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      );
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
  }

  /// Returns null on success, or a user-facing error message on failure.
  /// `faceEmbedding`/`livenessPassed`/`livenessScore`/`captureSessionId` are
  /// only ever populated by the caller when Face ID Verification is
  /// mandatory and the capture flow already ran (see AttendanceRingCard) — the
  /// backend enforces this regardless, these are just carried through.
  Future<String?> punch({
    required bool isCurrentlyClockedIn,
    required String attendanceMode,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? deviceName,
    String? deviceId,
    String? operatingSystem,
    List<double>? faceEmbedding,
    bool? livenessPassed,
    double? livenessScore,
    String? captureSessionId,
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
        faceEmbedding: faceEmbedding,
        livenessPassed: livenessPassed,
        livenessScore: livenessScore,
        captureSessionId: captureSessionId,
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

// ── Employee Attendance (admin view of another employee's data) ────────────────
// Same endpoints as "My Attendance" above, scoped server-side via `employee_id`
// query param (employees.view / attendance.view permission-gated).

typedef EmployeeMonthYearKey = ({String employeeId, int year, int month});

final employeeAttendanceStatsProvider = FutureProvider.autoDispose
    .family<AttendanceStatsEntity, EmployeeMonthYearKey>((ref, key) {
  return ref.watch(attendanceRepositoryProvider).getStats(
        month: key.month,
        year: key.year,
        employeeId: key.employeeId,
      );
});

final employeeAttendanceSummaryProvider = FutureProvider.autoDispose
    .family<MonthlySummaryEntity, EmployeeMonthYearKey>((ref, key) {
  return ref.watch(attendanceRepositoryProvider).getSummary(
        month: key.month,
        year: key.year,
        employeeId: key.employeeId,
      );
});

final employeeAttendanceCalendarProvider = FutureProvider.autoDispose
    .family<AttendanceCalendarEntity, EmployeeMonthYearKey>((ref, key) {
  return ref.watch(attendanceRepositoryProvider).getCalendar(
        month: key.month,
        year: key.year,
        employeeId: key.employeeId,
      );
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
      _ref.invalidate(myCorrectionsProvider);
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
  }
}

// ── My Attendance — own correction-request history ──────────────────────────────
//
// Distinct from hrCorrectionsProvider below: this is the employee's own past
// requests (GET /attendance/corrections/my/), read-only status tracking —
// no can_action/approve-reject affordance, since an employee never reviews
// their own request.
final myCorrectionsProvider =
    FutureProvider.autoDispose<List<MyCorrectionEntity>>((ref) {
  return ref.watch(attendanceRepositoryProvider).getMyCorrections();
});

// ── HR Attendance — shared filters ──────────────────────────────────────────────

final hrAttendanceBranchFilterProvider = StateProvider.autoDispose<String>((ref) => '');
final hrAttendanceDepartmentFilterProvider = StateProvider.autoDispose<String>((ref) => '');
final hrAttendanceDateFilterProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

// ── HR Attendance — Dashboard (stats bar) ───────────────────────────────────────

final attendanceDashboardProvider =
    FutureProvider.autoDispose<AttendanceDashboardEntity>((ref) {
  final branch = ref.watch(hrAttendanceBranchFilterProvider);
  final department = ref.watch(hrAttendanceDepartmentFilterProvider);
  final date = ref.watch(hrAttendanceDateFilterProvider);
  return ref
      .watch(attendanceRepositoryProvider)
      .getDashboard(branch: branch, department: department, date: _fmtDate(date));
});

// ── HR Attendance — Records list (Attendance tab) ──────────────────────────────

final attendanceRecordsSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final attendanceRecordsPageProvider = StateProvider.autoDispose<int>((ref) => 1);
final attendanceRecordsStatusFilterProvider = StateProvider.autoDispose<String>((ref) => '');
final attendanceRecordsSortByProvider = StateProvider.autoDispose<String>((ref) => 'name');
final attendanceRecordsSortDirProvider = StateProvider.autoDispose<String>((ref) => 'asc');

final attendanceRecordsProvider = AsyncNotifierProvider.autoDispose<
    AttendanceRecordsNotifier, PaginatedListEntity<AttendanceRowEntity>>(AttendanceRecordsNotifier.new);

class AttendanceRecordsNotifier
    extends AutoDisposeAsyncNotifier<PaginatedListEntity<AttendanceRowEntity>> {
  AttendanceRepository get _repo => ref.read(attendanceRepositoryProvider);

  @override
  Future<PaginatedListEntity<AttendanceRowEntity>> build() {
    final branch = ref.watch(hrAttendanceBranchFilterProvider);
    final department = ref.watch(hrAttendanceDepartmentFilterProvider);
    final date = ref.watch(hrAttendanceDateFilterProvider);
    final search = ref.watch(attendanceRecordsSearchProvider);
    final status = ref.watch(attendanceRecordsStatusFilterProvider);
    final sortBy = ref.watch(attendanceRecordsSortByProvider);
    final sortDir = ref.watch(attendanceRecordsSortDirProvider);
    final page = ref.watch(attendanceRecordsPageProvider);
    return _repo.getRecords(
      branch: branch,
      department: department,
      date: _fmtDate(date),
      search: search,
      status: status.isEmpty ? null : status,
      sortBy: sortBy,
      sortDir: sortDir,
      page: page,
    );
  }

  // Pull-to-refresh on the Attendance HR tab was replacing the entire
  // records list with a blank spinner while refetching — copyWithPrevious
  // keeps the current page visible until the new one is ready, same pattern
  // already established for employeeListProvider's refresh(). Deliberately
  // NOT using `AsyncValue.guard()` here: guard()'s own AsyncError has no
  // previous value attached, so a failed refresh (e.g. a connectivity blip)
  // would still wipe the list to a full error screen despite the line
  // above — the try/catch instead attaches `previous` to the error branch
  // too, matching what Riverpod's own ref.invalidate()/ref.refresh() path
  // does automatically (verified against the framework's own
  // asyncTransition() in package:riverpod/src/common.dart).
  Future<void> refresh() async {
    final previous = state;
    state = const AsyncLoading<PaginatedListEntity<AttendanceRowEntity>>()
        .copyWithPrevious(state);
    try {
      state = AsyncData(await build());
    } catch (e, st) {
      state = AsyncError<PaginatedListEntity<AttendanceRowEntity>>(e, st)
          .copyWithPrevious(previous);
    }
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> createRecord({
    required String employeeId,
    required String date,
    required String status,
    String? clockIn,
    String? clockOut,
    String? note,
    required String reason,
  }) async {
    try {
      await _repo.createRecord(
        employeeId: employeeId,
        date: date,
        status: status,
        clockIn: clockIn,
        clockOut: clockOut,
        note: note,
        reason: reason,
      );
      await refresh();
      ref.invalidate(attendanceDashboardProvider);
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> updateRecord(
    String recordId, {
    String? status,
    String? clockIn,
    String? clockOut,
    String? note,
    required String reason,
  }) async {
    try {
      await _repo.updateRecord(
        recordId,
        status: status,
        clockIn: clockIn,
        clockOut: clockOut,
        note: note,
        reason: reason,
      );
      await refresh();
      ref.invalidate(attendanceDashboardProvider);
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> reprocess({required String date, String? branch, String? department}) async {
    try {
      await _repo.reprocessDay(date: date, branch: branch, department: department);
      await refresh();
      ref.invalidate(attendanceDashboardProvider);
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
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

final overtimePageProvider = StateProvider.autoDispose<int>((ref) => 1);

final overtimeListProvider = AsyncNotifierProvider.autoDispose<OvertimeListNotifier,
    PaginatedListEntity<OvertimeRowEntity>>(OvertimeListNotifier.new);

class OvertimeListNotifier extends AutoDisposeAsyncNotifier<PaginatedListEntity<OvertimeRowEntity>> {
  AttendanceRepository get _repo => ref.read(attendanceRepositoryProvider);

  // Deliberately does NOT watch hrAttendanceBranchFilterProvider /
  // hrAttendanceDepartmentFilterProvider / hrAttendanceDateFilterProvider.
  // Those filters are only exposed in the "Attendance" tab's UI — the OT
  // Entry tab has no filter controls of its own, so silently inheriting
  // whatever branch/department/date happened to be selected on a different
  // tab caused freshly-added OT entries to appear "missing" whenever they
  // fell outside that stale, invisible filter. The OT Entry tab always
  // shows the unfiltered list instead.
  @override
  Future<PaginatedListEntity<OvertimeRowEntity>> build() {
    final page = ref.watch(overtimePageProvider);
    return _repo.getOvertimeList(page: page);
  }

  // See AttendanceRecordsNotifier.refresh() above for why this is a
  // try/catch instead of AsyncValue.guard() — guard() drops `previous` on
  // failure, which would undo the copyWithPrevious just below.
  Future<void> refresh() async {
    final previous = state;
    state = const AsyncLoading<PaginatedListEntity<OvertimeRowEntity>>()
        .copyWithPrevious(state);
    try {
      state = AsyncData(await build());
    } catch (e, st) {
      state = AsyncError<PaginatedListEntity<OvertimeRowEntity>>(e, st)
          .copyWithPrevious(previous);
    }
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
      // Jump back to page 1 — the list is sorted newest-first, so the entry
      // just created would otherwise be invisible if the user was sitting
      // on a later page.
      ref.read(overtimePageProvider.notifier).state = 1;
      await refresh();
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
  }
}

// ── HR Attendance — Invalid Punches (Assign / Discard / Convert) ───────────────

final invalidPunchesProvider = AsyncNotifierProvider.autoDispose<InvalidPunchesNotifier,
    List<InvalidPunchEntity>>(InvalidPunchesNotifier.new);

class InvalidPunchesNotifier extends AutoDisposeAsyncNotifier<List<InvalidPunchEntity>> {
  AttendanceRepository get _repo => ref.read(attendanceRepositoryProvider);

  @override
  Future<List<InvalidPunchEntity>> build() {
    final branch = ref.watch(hrAttendanceBranchFilterProvider);
    final department = ref.watch(hrAttendanceDepartmentFilterProvider);
    final date = ref.watch(hrAttendanceDateFilterProvider);
    return _repo.getInvalidPunches(branch: branch, department: department, date: _fmtDate(date));
  }

  // See AttendanceRecordsNotifier.refresh() above for why this is a
  // try/catch instead of AsyncValue.guard().
  Future<void> refresh() async {
    final previous = state;
    state = const AsyncLoading<List<InvalidPunchEntity>>().copyWithPrevious(state);
    try {
      state = AsyncData(await build());
    } catch (e, st) {
      state = AsyncError<List<InvalidPunchEntity>>(e, st).copyWithPrevious(previous);
    }
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> assign(String id, {required String assignedTo}) async {
    try {
      await _repo.assignInvalidPunch(id, assignedTo: assignedTo);
      await refresh();
      ref.invalidate(attendanceDashboardProvider);
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> discard(String id, {String? remarks}) async {
    try {
      await _repo.discardInvalidPunch(id, remarks: remarks);
      await refresh();
      ref.invalidate(attendanceDashboardProvider);
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> convert(String id, {required String targetPunchType, required String targetTime}) async {
    try {
      await _repo.convertInvalidPunch(id, targetPunchType: targetPunchType, targetTime: targetTime);
      await refresh();
      ref.invalidate(attendanceDashboardProvider);
      ref.invalidate(attendanceRecordsProvider);
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
  }
}

// ── HR Attendance — HR users picker (Invalid Punch "Assign") ───────────────────

final hrUsersProvider = FutureProvider.autoDispose<List<HrUserEntity>>((ref) {
  return ref.watch(attendanceRepositoryProvider).getHrUsers();
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
    final date = ref.watch(hrAttendanceDateFilterProvider);
    return _repo.getUnpunches(branch: branch, department: department, date: _fmtDate(date));
  }

  // See AttendanceRecordsNotifier.refresh() above for why this is a
  // try/catch instead of AsyncValue.guard().
  Future<void> refresh() async {
    final previous = state;
    state = const AsyncLoading<List<UnpunchRowEntity>>().copyWithPrevious(state);
    try {
      state = AsyncData(await build());
    } catch (e, st) {
      state = AsyncError<List<UnpunchRowEntity>>(e, st).copyWithPrevious(previous);
    }
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

// ── HR Attendance — General Corrections inbox ───────────────────────────────────
// A single consolidated provider backs BOTH the Attendance screen's own
// "Correction Requests" section AND the Approvals screen's unified Team
// Approvals inbox — previously these were two independent hand-written
// notifier classes hitting the same endpoints. It's a `.family` keyed by a
// full filter record (status/branch/department) — NOT just watched from the
// shared hrAttendanceBranchFilterProvider/hrAttendanceDepartmentFilterProvider
// StateProviders — so each caller passes exactly the slice it wants with no
// ambient state leaking between them: attendance_screen.dart builds its key
// from its own local hrCorrectionsStatusFilterProvider plus the shared HR
// Attendance branch/department filters (preserving its existing behavior),
// while the Approvals feature passes an explicit empty/'all' filter so a
// branch or department filter left set on the unrelated Attendance screen
// can never silently hide rows from the Team Approvals inbox.
final hrCorrectionsStatusFilterProvider = StateProvider.autoDispose<String>((ref) => 'pending');

typedef HrCorrectionsFilter = ({String? status, String? branch, String? department});

final hrCorrectionsProvider = AsyncNotifierProvider.autoDispose
    .family<HrCorrectionsNotifier, List<HrCorrectionRowEntity>, HrCorrectionsFilter>(HrCorrectionsNotifier.new);

class HrCorrectionsNotifier extends AutoDisposeFamilyAsyncNotifier<List<HrCorrectionRowEntity>, HrCorrectionsFilter> {
  AttendanceRepository get _repo => ref.read(attendanceRepositoryProvider);

  @override
  Future<List<HrCorrectionRowEntity>> build(HrCorrectionsFilter filter) {
    return _repo.getHrCorrections(
      branch: filter.branch,
      department: filter.department,
      status: (filter.status == null || filter.status == 'all') ? null : filter.status,
    );
  }

  // See AttendanceRecordsNotifier.refresh() above for why this is a
  // try/catch instead of AsyncValue.guard().
  Future<void> refresh() async {
    final previous = state;
    state = const AsyncLoading<List<HrCorrectionRowEntity>>().copyWithPrevious(state);
    try {
      state = AsyncData(await build(arg));
    } catch (e, st) {
      state = AsyncError<List<HrCorrectionRowEntity>>(e, st).copyWithPrevious(previous);
    }
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> reviewCorrection(String correctionId, {required bool approve, String? remarks}) async {
    try {
      await _repo.reviewCorrection(correctionId, approve: approve, remarks: remarks);
      // Every filter-keyed instance of this family may be showing the row
      // that just changed state (e.g. the Attendance screen's "pending" view
      // and the Approvals screen's "all" view) — invalidate the whole family
      // rather than just this instance so neither goes stale.
      ref.invalidate(hrCorrectionsProvider);
      ref.invalidate(attendanceDashboardProvider);
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
  }
}

// ── HR Attendance — Record audit history ────────────────────────────────────────

final attendanceRecordAuditProvider = FutureProvider.autoDispose
    .family<List<AttendanceAuditEntryEntity>, String>((ref, recordId) {
  return ref.watch(attendanceRepositoryProvider).getRecordAudit(recordId);
});

// ── HR Attendance — Corrections for a single employee+date (record detail) ─────

typedef EmployeeDateKey = ({String employeeId, String date});

/// The corrections list endpoint has no server-side employee_id+date filter,
/// so — matching web's own approach — this fetches the unfiltered list and
/// narrows it client-side to the record being viewed.
final attendanceRecordCorrectionsProvider = FutureProvider.autoDispose
    .family<List<HrCorrectionRowEntity>, EmployeeDateKey>((ref, key) async {
  final all = await ref.watch(attendanceRepositoryProvider).getHrCorrections();
  return all.where((c) => c.employeeId == key.employeeId && c.date == key.date).toList();
});

// ── HR Attendance — CSV Import (Export is a direct one-shot call, see below) ───

final attendanceImportActionProvider =
    Provider.autoDispose<AttendanceImportAction>((ref) => AttendanceImportAction(ref));

class AttendanceImportAction {
  final Ref _ref;
  AttendanceImportAction(this._ref);

  /// Returns the import result (which itself may report partial row failures),
  /// or throws a friendly error message string on hard failure.
  Future<ImportResultEntity> upload(List<int> bytes, String fileName) async {
    try {
      final result = await _ref.read(attendanceRepositoryProvider).importCsv(bytes, fileName);
      await _ref.read(attendanceRecordsProvider.notifier).refresh();
      _ref.invalidate(attendanceDashboardProvider);
      return result;
    } catch (e) {
      throw friendlyAttendanceError(e);
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
