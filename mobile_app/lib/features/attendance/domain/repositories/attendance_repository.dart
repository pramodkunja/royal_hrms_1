import '../entities/attendance_entity.dart';

abstract class AttendanceRepository {
  // My Attendance
  // Read-only pre-punch validation — see AttendanceRemoteDataSource's own
  // doc comment. Throws on rejection; returns normally (nothing to read)
  // when the location is allowed.
  Future<void> checkGeofence({
    required String attendanceMode,
    double? latitude,
    double? longitude,
    double? accuracy,
  });
  Future<TodayAttendanceEntity> punch({
    required String punchType,
    required String attendanceMode,
    String source,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? deviceName,
    String? deviceId,
    String? operatingSystem,
    // Only sent when Face ID Verification is mandatory (see
    // FaceVerificationService.verify_for_punch on the backend) — omitted
    // entirely otherwise, same as web/voice.
    List<double>? faceEmbedding,
    bool? livenessPassed,
    double? livenessScore,
    String? captureSessionId,
  });
  Future<TodayAttendanceEntity> getToday();
  Future<AttendanceStatsEntity> getStats({int? month, int? year, String? employeeId});
  Future<MonthlySummaryEntity> getSummary({int? month, int? year, String? employeeId});
  Future<AttendanceCalendarEntity> getCalendar({int? month, int? year, String? employeeId});
  Future<AttendanceCorrectionEntity> submitCorrection({
    required String date,
    required String punchType,
    String? correctInTime,
    String? correctOutTime,
    required String reason,
    String? notes,
  });

  // HR Attendance Management
  Future<AttendanceDashboardEntity> getDashboard({
    String? date,
    String? branch,
    String? department,
  });
  Future<PaginatedListEntity<AttendanceRowEntity>> getRecords({
    String? date,
    String? branch,
    String? department,
    String? status,
    String? search,
    String sortBy,
    String sortDir,
    int page,
    int pageSize,
  });
  Future<AttendanceDetailEntity> getRecordDetail(
    String recordIdOrEmployeeId, {
    String? date,
    bool isEmployeeId,
  });
  Future<AttendanceDetailEntity> createRecord({
    required String employeeId,
    required String date,
    required String status,
    String? clockIn,
    String? clockOut,
    String? note,
    required String reason,
  });
  Future<AttendanceDetailEntity> updateRecord(
    String recordId, {
    String? status,
    String? clockIn,
    String? clockOut,
    String? note,
    required String reason,
  });
  Future<void> reprocessDay({required String date, String? branch, String? department});
  Future<PaginatedListEntity<OvertimeRowEntity>> getOvertimeList({
    String? date,
    String? branch,
    String? department,
    int page,
    int pageSize,
  });
  Future<String> createOvertime({
    required String employeeId,
    required String date,
    required String otType,
    required String otStart,
    required String otEnd,
    String? approvedBy,
    String? reason,
  });
  Future<List<InvalidPunchEntity>> getInvalidPunches({
    String? date,
    String? branch,
    String? department,
  });
  Future<List<UnpunchRowEntity>> getUnpunches({
    String? date,
    String? branch,
    String? department,
  });
  Future<List<HrCorrectionRowEntity>> getHrCorrections({
    String? branch,
    String? department,
    String? status,
  });
  Future<void> reviewCorrection(String id, {required bool approve, String? remarks});
  Future<List<MyCorrectionEntity>> getMyCorrections();

  // Invalid Punch actions
  Future<List<HrUserEntity>> getHrUsers({String? branch});
  Future<void> assignInvalidPunch(String id, {required String assignedTo});
  Future<void> discardInvalidPunch(String id, {String? remarks});
  Future<void> convertInvalidPunch(
    String id, {
    required String targetPunchType,
    required String targetTime,
  });

  // Export / Import
  Future<List<int>> exportCsv({String? date, String? branch, String? department});
  Future<ImportResultEntity> importCsv(List<int> bytes, String fileName);
  Future<List<int>> fetchImportSample({String format});

  // Audit history
  Future<List<AttendanceAuditEntryEntity>> getRecordAudit(String recordId);
}
