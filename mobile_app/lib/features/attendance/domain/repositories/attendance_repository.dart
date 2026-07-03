import '../entities/attendance_entity.dart';

abstract class AttendanceRepository {
  // My Attendance
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
  });
  Future<TodayAttendanceEntity> getToday();
  Future<AttendanceStatsEntity> getStats({int? month, int? year});
  Future<MonthlySummaryEntity> getSummary({int? month, int? year});
  Future<AttendanceCalendarEntity> getCalendar({int? month, int? year});
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
  Future<List<AttendanceRowEntity>> getRecords({
    String? date,
    String? branch,
    String? department,
    String? status,
    String? search,
    String sortBy,
    String sortDir,
  });
  Future<AttendanceDetailEntity> getRecordDetail(
    String recordIdOrEmployeeId, {
    String? date,
    bool isEmployeeId,
  });
  Future<List<OvertimeRowEntity>> getOvertimeList({
    String? date,
    String? branch,
    String? department,
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
  Future<void> reviewCorrection(String id, {required bool approve});
}
