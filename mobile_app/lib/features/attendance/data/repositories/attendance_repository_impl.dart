import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_remote_datasource.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDataSource _ds;
  AttendanceRepositoryImpl(this._ds);

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
      );

  @override
  Future<TodayAttendanceEntity> getToday() => _ds.fetchToday();

  @override
  Future<AttendanceStatsEntity> getStats({int? month, int? year}) =>
      _ds.fetchStats(month: month, year: year);

  @override
  Future<MonthlySummaryEntity> getSummary({int? month, int? year}) =>
      _ds.fetchSummary(month: month, year: year);

  @override
  Future<AttendanceCalendarEntity> getCalendar({int? month, int? year}) =>
      _ds.fetchCalendar(month: month, year: year);

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
  Future<List<AttendanceRowEntity>> getRecords({
    String? date,
    String? branch,
    String? department,
    String? status,
    String? search,
    String sortBy = 'name',
    String sortDir = 'asc',
  }) =>
      _ds.fetchRecords(
        date: date,
        branch: branch,
        department: department,
        status: status,
        search: search,
        sortBy: sortBy,
        sortDir: sortDir,
      );

  @override
  Future<AttendanceDetailEntity> getRecordDetail(
    String recordIdOrEmployeeId, {
    String? date,
    bool isEmployeeId = false,
  }) =>
      _ds.fetchRecordDetail(recordIdOrEmployeeId, date: date, isEmployeeId: isEmployeeId);

  @override
  Future<List<OvertimeRowEntity>> getOvertimeList({
    String? date,
    String? branch,
    String? department,
  }) =>
      _ds.fetchOvertimeList(date: date, branch: branch, department: department);

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
  Future<void> reviewCorrection(String id, {required bool approve}) =>
      _ds.reviewCorrection(id, approve: approve);
}
