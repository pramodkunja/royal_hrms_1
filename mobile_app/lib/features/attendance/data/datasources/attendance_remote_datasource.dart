import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../domain/entities/attendance_entity.dart';
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

  // Read-only — writes nothing, unlike punch() below. Throws (DioException,
  // 403) on an out-of-geofence/missing-GPS rejection, same shape callers
  // already parse via parseDioException for punch() itself.
  Future<void> checkGeofence({
    required String attendanceMode,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    await _dio.post(ApiConstants.attendanceGeofenceCheck, data: {
      'attendance_mode': attendanceMode,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
    });
  }

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
    List<double>? faceEmbedding,
    bool? livenessPassed,
    double? livenessScore,
    String? captureSessionId,
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
      if (faceEmbedding != null) 'face_embedding': faceEmbedding,
      if (livenessPassed != null) 'liveness_passed': livenessPassed,
      if (livenessScore != null) 'liveness_score': livenessScore,
      if (captureSessionId != null) 'capture_session_id': captureSessionId,
    });
    return TodayAttendanceModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<TodayAttendanceModel> fetchToday() async {
    final res = await _dio.get(ApiConstants.attendanceToday);
    return TodayAttendanceModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<AttendanceStatsModel> fetchStats({int? month, int? year, String? employeeId}) async {
    final res = await _dio.get(ApiConstants.attendanceStats, queryParameters: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
      if (employeeId != null && employeeId.isNotEmpty) 'employee_id': employeeId,
    });
    return AttendanceStatsModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<MonthlySummaryModel> fetchSummary({int? month, int? year, String? employeeId}) async {
    final res = await _dio.get(ApiConstants.attendanceSummary, queryParameters: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
      if (employeeId != null && employeeId.isNotEmpty) 'employee_id': employeeId,
    });
    return MonthlySummaryModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<AttendanceCalendarModel> fetchCalendar({int? month, int? year, String? employeeId}) async {
    final res = await _dio.get(ApiConstants.attendanceCalendar, queryParameters: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
      if (employeeId != null && employeeId.isNotEmpty) 'employee_id': employeeId,
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

  Future<PaginatedListEntity<AttendanceRowModel>> fetchRecords({
    String? date,
    String? branch,
    String? department,
    String? status,
    String? search,
    String sortBy = 'name',
    String sortDir = 'asc',
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _dio.get(ApiConstants.attendanceRecords, queryParameters: {
      if (date != null) 'date': date,
      if (branch != null && branch.isNotEmpty) 'branch': branch,
      if (department != null && department.isNotEmpty) 'department': department,
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'sort_by': sortBy,
      'sort_dir': sortDir,
      'page': page,
      'page_size': pageSize,
    });
    return parsePaginated(_unwrap(res.data), AttendanceRowModel.fromJson);
  }

  // Manual attendance creation — POST /attendance/records/create/. `reason`
  // is required by the backend for the audit trail, same as edit.
  Future<AttendanceDetailModel> createRecord({
    required String employeeId,
    required String date,
    required String status,
    String? clockIn,
    String? clockOut,
    String? note,
    required String reason,
  }) async {
    final res = await _dio.post(ApiConstants.attendanceRecordCreate, data: {
      'employee_id': employeeId,
      'date': date,
      'status': status,
      if (clockIn != null && clockIn.isNotEmpty) 'clock_in': clockIn,
      if (clockOut != null && clockOut.isNotEmpty) 'clock_out': clockOut,
      if (note != null && note.isNotEmpty) 'note': note,
      'reason': reason,
    });
    return AttendanceDetailModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // Edit an existing record — PATCH /attendance/records/<id>/. `reason` is
  // required server-side for every edit (recorded in the audit log).
  Future<AttendanceDetailModel> updateRecord(
    String recordId, {
    String? status,
    String? clockIn,
    String? clockOut,
    String? note,
    required String reason,
  }) async {
    final res = await _dio.patch(ApiConstants.attendanceRecordDetail(recordId), data: {
      if (status != null) 'status': status,
      if (clockIn != null) 'clock_in': clockIn,
      if (clockOut != null) 'clock_out': clockOut,
      if (note != null) 'note': note,
      'reason': reason,
    });
    return AttendanceDetailModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // Reprocess a day — recomputes attendance for everyone with punches or an
  // existing record on that date. POST /attendance/reprocess/.
  Future<void> reprocessDay({
    required String date,
    String? branch,
    String? department,
  }) async {
    await _dio.post(ApiConstants.attendanceReprocess, data: {
      'date': date,
      if (branch != null && branch.isNotEmpty) 'branch': branch,
      if (department != null && department.isNotEmpty) 'department': department,
    });
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

  Future<PaginatedListEntity<OvertimeRowModel>> fetchOvertimeList({
    String? date,
    String? branch,
    String? department,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _dio.get(ApiConstants.attendanceOvertimeList, queryParameters: {
      if (date != null) 'date': date,
      if (branch != null && branch.isNotEmpty) 'branch': branch,
      if (department != null && department.isNotEmpty) 'department': department,
      'page': page,
      'page_size': pageSize,
    });
    return parsePaginated(_unwrap(res.data), OvertimeRowModel.fromJson);
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

  // Own correction requests + status/approver history — distinct from the
  // HR inbox above (no employee-identity fields; carries original_in/
  // original_out alongside requested_in/requested_out instead).
  Future<List<MyCorrectionModel>> fetchMyCorrections() async {
    final res = await _dio.get(ApiConstants.attendanceMyCorrections, queryParameters: {
      'page_size': 100,
    });
    return _unwrapList(res.data).map(MyCorrectionModel.fromJson).toList();
  }

  Future<void> reviewCorrection(String id, {required bool approve, String? remarks}) async {
    await _dio.patch(
      ApiConstants.attendanceHrCorrectionReview(id),
      data: {
        'action': approve ? 'approve' : 'reject',
        'remarks': remarks ?? '',
      },
    );
  }

  // ── Invalid Punch actions ────────────────────────────────────────────────────

  Future<List<HrUserModel>> fetchHrUsers({String? branch}) async {
    final res = await _dio.get(ApiConstants.employeesHrList, queryParameters: {
      if (branch != null && branch.isNotEmpty) 'branch': branch,
    });
    return _unwrapList(res.data).map(HrUserModel.fromJson).toList();
  }

  Future<void> assignInvalidPunch(String id, {required String assignedTo}) async {
    await _dio.post(
      ApiConstants.attendanceInvalidPunchAssign(id),
      data: {'assigned_to': assignedTo},
    );
  }

  Future<void> discardInvalidPunch(String id, {String? remarks}) async {
    await _dio.post(
      ApiConstants.attendanceInvalidPunchDiscard(id),
      data: {if (remarks != null && remarks.isNotEmpty) 'remarks': remarks},
    );
  }

  Future<void> convertInvalidPunch(
    String id, {
    required String targetPunchType,
    required String targetTime,
  }) async {
    await _dio.post(
      ApiConstants.attendanceInvalidPunchConvert(id),
      data: {'target_punch_type': targetPunchType, 'target_time': targetTime},
    );
  }

  // ── Export / Import ──────────────────────────────────────────────────────────

  Future<List<int>> exportCsv({String? date, String? branch, String? department}) async {
    final res = await _dio.get(
      ApiConstants.attendanceExport,
      queryParameters: {
        if (date != null) 'date': date,
        if (branch != null && branch.isNotEmpty) 'branch': branch,
        if (department != null && department.isNotEmpty) 'department': department,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data as List<int>;
  }

  Future<ImportResultModel> importCsv(List<int> bytes, String fileName) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final res = await _dio.post(
      ApiConstants.attendanceImport,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return ImportResultModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<List<int>> fetchImportSample({String format = 'csv'}) async {
    final res = await _dio.get(
      ApiConstants.attendanceImportSample,
      queryParameters: {'format': format},
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data as List<int>;
  }

  // ── Audit history ────────────────────────────────────────────────────────────

  Future<List<AttendanceAuditEntryModel>> fetchRecordAudit(String recordId) async {
    final res = await _dio.get(ApiConstants.attendanceRecordAudit(recordId));
    return _unwrapList(res.data).map(AttendanceAuditEntryModel.fromJson).toList();
  }
}
