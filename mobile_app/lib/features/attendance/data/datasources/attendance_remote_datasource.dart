import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/attendance_models.dart';

class AttendanceRemoteDataSource {
  final Dio _dio;
  AttendanceRemoteDataSource(this._dio);

  dynamic _unwrap(dynamic body) {
    if (body is Map && body['data'] != null) return body['data'];
    return body;
  }

  List<Map<String, dynamic>> _unwrapList(dynamic body) {
    final data = _unwrap(body);
    final List<dynamic> list = switch (data) {
      List d => d,
      Map<String, dynamic> d => (d['results'] as List<dynamic>? ?? []),
      _ => [],
    };
    return list.whereType<Map<String, dynamic>>().toList();
  }

  // ── My Attendance ──────────────────────────────────────────────────────────

  Future<TodayAttendanceModel> punch({
    required String punchType,
    required String attendanceMode,
    String source = 'mobile',
    double? latitude,
    double? longitude,
    double? accuracy,
    String? deviceName,
    String? deviceId,
    String? operatingSystem,
  }) async {
    final res = await _dio.post(ApiConstants.attendancePunch, data: {
      'punch_type': punchType,
      'attendance_mode': attendanceMode,
      'source': source,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (deviceName != null) 'device_name': deviceName,
      if (deviceId != null) 'device_id': deviceId,
      if (operatingSystem != null) 'operating_system': operatingSystem,
      'device_time': DateTime.now().toIso8601String(),
    });
    return TodayAttendanceModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<TodayAttendanceModel> fetchToday() async {
    final res = await _dio.get(ApiConstants.attendanceToday);
    return TodayAttendanceModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<AttendanceStatsModel> fetchStats({int? month, int? year}) async {
    final res = await _dio.get(ApiConstants.attendanceStats, queryParameters: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    return AttendanceStatsModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<MonthlySummaryModel> fetchSummary({int? month, int? year}) async {
    final res = await _dio.get(ApiConstants.attendanceSummary, queryParameters: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    return MonthlySummaryModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<AttendanceCalendarModel> fetchCalendar({int? month, int? year}) async {
    final res = await _dio.get(ApiConstants.attendanceCalendar, queryParameters: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    return AttendanceCalendarModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<AttendanceCorrectionModel> submitCorrection({
    required String date,
    required String punchType,
    String? correctInTime,
    String? correctOutTime,
    required String reason,
    String? notes,
  }) async {
    final res = await _dio.post(ApiConstants.attendanceCorrection, data: {
      'date': date,
      'punch_type': punchType,
      if (correctInTime != null) 'correct_in_time': correctInTime,
      if (correctOutTime != null) 'correct_out_time': correctOutTime,
      'reason': reason,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return AttendanceCorrectionModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // ── HR Attendance Management ─────────────────────────────────────────────────

  Future<AttendanceDashboardModel> fetchDashboard({
    String? date,
    String? branch,
    String? department,
  }) async {
    final res = await _dio.get(ApiConstants.attendanceDashboard, queryParameters: {
      if (date != null) 'date': date,
      if (branch != null && branch.isNotEmpty) 'branch': branch,
      if (department != null && department.isNotEmpty) 'department': department,
    });
    return AttendanceDashboardModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<List<AttendanceRowModel>> fetchRecords({
    String? date,
    String? branch,
    String? department,
    String? status,
    String? search,
    String sortBy = 'name',
    String sortDir = 'asc',
  }) async {
    final res = await _dio.get(ApiConstants.attendanceRecords, queryParameters: {
      if (date != null) 'date': date,
      if (branch != null && branch.isNotEmpty) 'branch': branch,
      if (department != null && department.isNotEmpty) 'department': department,
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'sort_by': sortBy,
      'sort_dir': sortDir,
      'page_size': 100,
    });
    return _unwrapList(res.data).map(AttendanceRowModel.fromJson).toList();
  }

  Future<AttendanceDetailModel> fetchRecordDetail(
    String recordIdOrEmployeeId, {
    String? date,
    bool isEmployeeId = false,
  }) async {
    final res = await _dio.get(
      ApiConstants.attendanceRecordDetail(recordIdOrEmployeeId),
      queryParameters: {
        if (date != null) 'date': date,
        if (isEmployeeId) 'employee_id': recordIdOrEmployeeId,
      },
    );
    return AttendanceDetailModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<List<OvertimeRowModel>> fetchOvertimeList({
    String? date,
    String? branch,
    String? department,
  }) async {
    final res = await _dio.get(ApiConstants.attendanceOvertimeList, queryParameters: {
      if (date != null) 'date': date,
      if (branch != null && branch.isNotEmpty) 'branch': branch,
      if (department != null && department.isNotEmpty) 'department': department,
      'page_size': 100,
    });
    return _unwrapList(res.data).map(OvertimeRowModel.fromJson).toList();
  }

  Future<String> createOvertime({
    required String employeeId,
    required String date,
    required String otType,
    required String otStart,
    required String otEnd,
    String? approvedBy,
    String? reason,
  }) async {
    final res = await _dio.post(ApiConstants.attendanceOvertimeCreate, data: {
      'employee_id': employeeId,
      'date': date,
      'ot_type': otType,
      'ot_start': otStart,
      'ot_end': otEnd,
      if (approvedBy != null && approvedBy.isNotEmpty) 'approved_by': approvedBy,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    final data = _unwrap(res.data) as Map<String, dynamic>;
    return data['id']?.toString() ?? '';
  }

  Future<List<InvalidPunchModel>> fetchInvalidPunches({
    String? date,
    String? branch,
    String? department,
  }) async {
    final res = await _dio.get(ApiConstants.attendanceInvalidPunches, queryParameters: {
      if (date != null) 'date': date,
      if (branch != null && branch.isNotEmpty) 'branch': branch,
      if (department != null && department.isNotEmpty) 'department': department,
      'page_size': 100,
    });
    return _unwrapList(res.data).map(InvalidPunchModel.fromJson).toList();
  }

  Future<List<UnpunchRowModel>> fetchUnpunches({
    String? date,
    String? branch,
    String? department,
  }) async {
    final res = await _dio.get(ApiConstants.attendanceUnpunches, queryParameters: {
      if (date != null) 'date': date,
      if (branch != null && branch.isNotEmpty) 'branch': branch,
      if (department != null && department.isNotEmpty) 'department': department,
      'page_size': 100,
    });
    return _unwrapList(res.data).map(UnpunchRowModel.fromJson).toList();
  }

  Future<List<HrCorrectionRowModel>> fetchHrCorrections({
    String? branch,
    String? department,
    String? status,
  }) async {
    final res = await _dio.get(ApiConstants.attendanceHrCorrections, queryParameters: {
      if (branch != null && branch.isNotEmpty) 'branch': branch,
      if (department != null && department.isNotEmpty) 'department': department,
      if (status != null && status.isNotEmpty) 'status': status,
      'page_size': 100,
    });
    return _unwrapList(res.data).map(HrCorrectionRowModel.fromJson).toList();
  }

  Future<void> reviewCorrection(String id, {required bool approve}) async {
    await _dio.patch(
      ApiConstants.attendanceHrCorrectionReview(id),
      data: {'action': approve ? 'approve' : 'reject'},
    );
  }
}
