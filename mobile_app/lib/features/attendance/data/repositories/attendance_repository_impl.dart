import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_remote_datasource.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDataSource _ds;
  AttendanceRepositoryImpl(this._ds);

  @override
  Future<void> checkGeofence({
    required String attendanceMode,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) =>
      _ds.checkGeofence(
        attendanceMode: attendanceMode,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      );

  @override
  Future<TodayAttendanceEntity> punch({
    required String punchType,
    required String attendanceMode,
    String source = 'mobile',
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
  }) =>
      _ds.punch(
        punchType: punchType,
        attendanceMode: attendanceMode,
        source: source,
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

  @override
  Future<TodayAttendanceEntity> getToday() => _ds.fetchToday();

  @override
  Future<AttendanceStatsEntity> getStats({int? month, int? year, String? employeeId}) =>
      _ds.fetchStats(month: month, year: year, employeeId: employeeId);

  @override
  Future<MonthlySummaryEntity> getSummary({int? month, int? year, String? employeeId}) =>
      _ds.fetchSummary(month: month, year: year, employeeId: employeeId);

  @override
  Future<AttendanceCalendarEntity> getCalendar({int? month, int? year, String? employeeId}) =>
      _ds.fetchCalendar(month: month, year: year, employeeId: employeeId);

  @override
  Future<AttendanceCorrectionEntity> submitCorrection({
    required String date,
    required String punchType,
    String? correctInTime,
    String? correctOutTime,
    required String reason,
    String? notes,
  }) =>
      _ds.submitCorrection(
        date: date,
        punchType: punchType,
        correctInTime: correctInTime,
        correctOutTime: correctOutTime,
        reason: reason,
        notes: notes,
      );

  @override
  Future<AttendanceDashboardEntity> getDashboard({
    String? date,
    String? branch,
    String? department,
  }) =>
      _ds.fetchDashboard(date: date, branch: branch, department: department);

  @override
  Future<PaginatedListEntity<AttendanceRowEntity>> getRecords({
    String? date,
    String? branch,
    String? department,
    String? status,
    String? search,
    String sortBy = 'name',
    String sortDir = 'asc',
    int page = 1,
    int pageSize = 20,
  }) =>
      _ds.fetchRecords(
        date: date,
        branch: branch,
        department: department,
        status: status,
        search: search,
        sortBy: sortBy,
        sortDir: sortDir,
        page: page,
        pageSize: pageSize,
      );

  @override
  Future<AttendanceDetailEntity> getRecordDetail(
    String recordIdOrEmployeeId, {
    String? date,
    bool isEmployeeId = false,
  }) =>
      _ds.fetchRecordDetail(recordIdOrEmployeeId, date: date, isEmployeeId: isEmployeeId);

  @override
  Future<AttendanceDetailEntity> createRecord({
    required String employeeId,
    required String date,
    required String status,
    String? clockIn,
    String? clockOut,
    String? note,
    required String reason,
  }) =>
      _ds.createRecord(
        employeeId: employeeId,
        date: date,
        status: status,
        clockIn: clockIn,
        clockOut: clockOut,
        note: note,
        reason: reason,
      );

  @override
  Future<AttendanceDetailEntity> updateRecord(
    String recordId, {
    String? status,
    String? clockIn,
    String? clockOut,
    String? note,
    required String reason,
  }) =>
      _ds.updateRecord(
        recordId,
        status: status,
        clockIn: clockIn,
        clockOut: clockOut,
        note: note,
        reason: reason,
      );

  @override
  Future<void> reprocessDay({required String date, String? branch, String? department}) =>
      _ds.reprocessDay(date: date, branch: branch, department: department);

  @override
  Future<PaginatedListEntity<OvertimeRowEntity>> getOvertimeList({
    String? date,
    String? branch,
    String? department,
    int page = 1,
    int pageSize = 20,
  }) =>
      _ds.fetchOvertimeList(
        date: date,
        branch: branch,
        department: department,
        page: page,
        pageSize: pageSize,
      );

  @override
  Future<String> createOvertime({
    required String employeeId,
    required String date,
    required String otType,
    required String otStart,
    required String otEnd,
    String? approvedBy,
    String? reason,
  }) =>
      _ds.createOvertime(
        employeeId: employeeId,
        date: date,
        otType: otType,
        otStart: otStart,
        otEnd: otEnd,
        approvedBy: approvedBy,
        reason: reason,
      );

  @override
  Future<List<InvalidPunchEntity>> getInvalidPunches({
    String? date,
    String? branch,
    String? department,
  }) =>
      _ds.fetchInvalidPunches(date: date, branch: branch, department: department);

  @override
  Future<List<UnpunchRowEntity>> getUnpunches({
    String? date,
    String? branch,
    String? department,
  }) =>
      _ds.fetchUnpunches(date: date, branch: branch, department: department);

  @override
  Future<List<HrCorrectionRowEntity>> getHrCorrections({
    String? branch,
    String? department,
    String? status,
  }) =>
      _ds.fetchHrCorrections(branch: branch, department: department, status: status);

  @override
  Future<void> reviewCorrection(String id, {required bool approve, String? remarks}) =>
      _ds.reviewCorrection(id, approve: approve, remarks: remarks);

  @override
  Future<List<MyCorrectionEntity>> getMyCorrections() => _ds.fetchMyCorrections();

  @override
  Future<List<HrUserEntity>> getHrUsers({String? branch}) =>
      _ds.fetchHrUsers(branch: branch);

  @override
  Future<void> assignInvalidPunch(String id, {required String assignedTo}) =>
      _ds.assignInvalidPunch(id, assignedTo: assignedTo);

  @override
  Future<void> discardInvalidPunch(String id, {String? remarks}) =>
      _ds.discardInvalidPunch(id, remarks: remarks);

  @override
  Future<void> convertInvalidPunch(
    String id, {
    required String targetPunchType,
    required String targetTime,
  }) =>
      _ds.convertInvalidPunch(id, targetPunchType: targetPunchType, targetTime: targetTime);

  @override
  Future<List<int>> exportCsv({String? date, String? branch, String? department}) =>
      _ds.exportCsv(date: date, branch: branch, department: department);

  @override
  Future<ImportResultEntity> importCsv(List<int> bytes, String fileName) =>
      _ds.importCsv(bytes, fileName);

  @override
  Future<List<int>> fetchImportSample({String format = 'csv'}) =>
      _ds.fetchImportSample(format: format);

  @override
  Future<List<AttendanceAuditEntryEntity>> getRecordAudit(String recordId) =>
      _ds.fetchRecordAudit(recordId);
}
