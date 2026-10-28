import '../../domain/entities/attendance_entity.dart';

// Some numeric fields may arrive as DecimalField strings (e.g. "8.4") rather
// than JSON numbers — this guards against both, same convention as leave_models.dart.
double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool _toBool(dynamic value) => value == true;

// ── My Attendance ────────────────────────────────────────────────────────────

class PunchEntryModel extends PunchEntryEntity {
  const PunchEntryModel({
    required super.type,
    required super.time,
    required super.location,
    required super.attendanceMode,
    required super.isInsideGeofence,
    super.calculatedDistance,
  });

  factory PunchEntryModel.fromJson(Map<String, dynamic> json) {
    return PunchEntryModel(
      type: json['type'] as String? ?? '',
      time: json['time'] as String? ?? '',
      location: json['location'] as String? ?? '',
      attendanceMode: json['attendance_mode'] as String? ?? 'office',
      isInsideGeofence: _toBool(json['is_inside_geofence']),
      calculatedDistance: json['calculated_distance'] == null
          ? null
          : _toDouble(json['calculated_distance']),
    );
  }
}

class TodayAttendanceModel extends TodayAttendanceEntity {
  const TodayAttendanceModel({
    required super.isClockedIn,
    required super.punches,
    required super.totalSeconds,
    required super.sessionSeconds,
    required super.dateDisplay,
  });

  factory TodayAttendanceModel.fromJson(Map<String, dynamic> json) {
    final rawPunches = json['punches'] as List<dynamic>? ?? [];
    return TodayAttendanceModel(
      isClockedIn: _toBool(json['is_clocked_in']),
      punches: rawPunches
          .whereType<Map<String, dynamic>>()
          .map(PunchEntryModel.fromJson)
          .toList(),
      totalSeconds: _toInt(json['total_seconds']),
      sessionSeconds: _toInt(json['session_seconds']),
      dateDisplay: json['date_display'] as String? ?? '',
    );
  }
}

class AttendanceStatsModel extends AttendanceStatsEntity {
  const AttendanceStatsModel({
    required super.daysPresent,
    required super.lateArrivals,
    required super.lopPending,
    required super.avgHoursPerDay,
    required super.attendancePercentage,
    required super.workingDays,
  });

  factory AttendanceStatsModel.fromJson(Map<String, dynamic> json) {
    return AttendanceStatsModel(
      daysPresent: _toInt(json['days_present']),
      lateArrivals: _toInt(json['late_arrivals']),
      lopPending: _toInt(json['lop_pending']),
      avgHoursPerDay: _toDouble(json['avg_hours_per_day']),
      attendancePercentage: _toDouble(json['attendance_percentage']),
      workingDays: _toInt(json['working_days']),
    );
  }
}

class MonthlySummaryModel extends MonthlySummaryEntity {
  const MonthlySummaryModel({
    required super.workingDays,
    required super.daysPresent,
    required super.daysAbsent,
    required super.leaveDays,
    required super.halfDays,
    required super.otHours,
  });

  factory MonthlySummaryModel.fromJson(Map<String, dynamic> json) {
    return MonthlySummaryModel(
      workingDays: _toInt(json['working_days']),
      daysPresent: _toInt(json['days_present']),
      daysAbsent: _toInt(json['days_absent']),
      leaveDays: _toInt(json['leave_days']),
      halfDays: _toInt(json['half_days']),
      otHours: json['ot_hours'] as String? ?? '0h',
    );
  }
}

class CalendarDayModel extends CalendarDayEntity {
  const CalendarDayModel({
    required super.status,
    super.clockIn,
    super.clockOut,
    super.hours,
    super.note,
    super.holidayName,
    required super.canRegularize,
  });

  factory CalendarDayModel.fromJson(Map<String, dynamic> json) {
    return CalendarDayModel(
      status: json['status'] as String? ?? '',
      clockIn: json['clockIn'] as String?,
      clockOut: json['clockOut'] as String?,
      hours: json['hours'] as String?,
      note: json['note'] as String?,
      holidayName: json['holiday_name'] as String?,
      canRegularize: _toBool(json['canRegularize']),
    );
  }
}

class AttendanceHistoryRowModel extends AttendanceHistoryRowEntity {
  const AttendanceHistoryRowModel({
    required super.date,
    required super.day,
    super.clockIn,
    super.clockOut,
    super.hours,
    required super.status,
    required super.canRegularize,
  });

  factory AttendanceHistoryRowModel.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryRowModel(
      date: json['date'] as String? ?? '',
      day: json['day'] as String? ?? '',
      clockIn: json['clockIn'] as String?,
      clockOut: json['clockOut'] as String?,
      hours: json['hours'] as String?,
      status: json['status'] as String? ?? '',
      canRegularize: _toBool(json['canRegularize']),
    );
  }
}

class AttendanceCalendarModel extends AttendanceCalendarEntity {
  const AttendanceCalendarModel({
    required super.days,
    required super.history,
    required super.month,
    required super.year,
  });

  factory AttendanceCalendarModel.fromJson(Map<String, dynamic> json) {
    final calendar = json['calendar'] as Map<String, dynamic>? ?? {};
    final rawDays = calendar['days'] as Map<String, dynamic>? ?? {};
    final days = <int, CalendarDayEntity>{};
    for (final entry in rawDays.entries) {
      final dayNum = int.tryParse(entry.key);
      if (dayNum != null && entry.value is Map<String, dynamic>) {
        days[dayNum] = CalendarDayModel.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    final rawHistory = json['history'] as List<dynamic>? ?? [];
    return AttendanceCalendarModel(
      days: days,
      history: rawHistory
          .whereType<Map<String, dynamic>>()
          .map(AttendanceHistoryRowModel.fromJson)
          .toList(),
      month: _toInt(json['month']),
      year: _toInt(json['year']),
    );
  }
}

class AttendanceCorrectionModel extends AttendanceCorrectionEntity {
  const AttendanceCorrectionModel({
    required super.id,
    required super.date,
    required super.punchType,
    required super.reason,
    required super.status,
    required super.createdAt,
  });

  factory AttendanceCorrectionModel.fromJson(Map<String, dynamic> json) {
    return AttendanceCorrectionModel(
      id: json['id']?.toString() ?? '',
      date: json['date'] as String? ?? '',
      punchType: json['punch_type'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

// ── HR Attendance Management ────────────────────────────────────────────────

class AttendanceDashboardModel extends AttendanceDashboardEntity {
  const AttendanceDashboardModel({
    required super.presentToday,
    required super.absent,
    required super.lateArrivals,
    required super.onLeave,
    required super.totalEmployees,
    required super.summaryChips,
    required super.invalidPunchesCount,
    required super.unPunchesCount,
  });

  factory AttendanceDashboardModel.fromJson(Map<String, dynamic> json) {
    final cards = json['stat_cards'] as Map<String, dynamic>? ?? {};
    final chips = json['summary_chips'] as Map<String, dynamic>? ?? {};
    final badges = json['tab_badges'] as Map<String, dynamic>? ?? {};
    return AttendanceDashboardModel(
      presentToday: _toInt(cards['present_today']),
      absent: _toInt(cards['absent']),
      lateArrivals: _toInt(cards['late_arrivals']),
      onLeave: _toInt(cards['on_leave']),
      totalEmployees: _toInt(cards['total_employees']),
      summaryChips: chips.map((k, v) => MapEntry(k, _toInt(v))),
      invalidPunchesCount: _toInt(badges['invalid_punches']),
      unPunchesCount: _toInt(badges['un_punches']),
    );
  }
}

class AttendanceRowModel extends AttendanceRowEntity {
  const AttendanceRowModel({
    required super.recordId,
    required super.employeeId,
    required super.name,
    required super.initials,
    required super.department,
    required super.branch,
    required super.clockIn,
    required super.clockOut,
    required super.totalHours,
    required super.ot,
    required super.status,
    required super.statusKey,
    required super.isLate,
  });

  factory AttendanceRowModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRowModel(
      recordId: json['record_id'] as String?,
      employeeId: json['employee_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      initials: json['initials'] as String? ?? '',
      department: json['department'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      clockIn: json['clock_in'] as String? ?? '—',
      clockOut: json['clock_out'] as String? ?? '—',
      totalHours: json['total_hours'] as String? ?? '—',
      ot: json['ot'] as String? ?? '—',
      status: json['status'] as String? ?? '',
      statusKey: json['status_key'] as String? ?? '',
      isLate: _toBool(json['is_late']),
    );
  }
}

class AttendancePunchDetailModel extends AttendancePunchDetailEntity {
  const AttendancePunchDetailModel({
    required super.punchType,
    required super.time,
    required super.source,
    required super.mode,
    required super.isGeofence,
    super.distanceM,
  });

  factory AttendancePunchDetailModel.fromJson(Map<String, dynamic> json) {
    return AttendancePunchDetailModel(
      punchType: json['punch_type'] as String? ?? '',
      time: json['time'] as String? ?? '',
      source: json['source'] as String? ?? '',
      mode: json['mode'] as String? ?? '',
      isGeofence: _toBool(json['is_geofence']),
      distanceM: json['distance_m'] == null ? null : _toDouble(json['distance_m']),
    );
  }
}

class AttendanceDetailModel extends AttendanceDetailEntity {
  const AttendanceDetailModel({
    required super.recordId,
    required super.employeeId,
    required super.name,
    required super.department,
    required super.branch,
    required super.date,
    required super.status,
    required super.statusKey,
    required super.clockIn,
    required super.clockOut,
    required super.totalHours,
    required super.overtime,
    required super.isLate,
    required super.isEarlyExit,
    super.note,
    required super.punches,
  });

  factory AttendanceDetailModel.fromJson(Map<String, dynamic> json) {
    final rawPunches = json['punches'] as List<dynamic>? ?? [];
    return AttendanceDetailModel(
      recordId: json['record_id'] as String?,
      employeeId: json['employee_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusKey: json['status_key'] as String? ?? '',
      clockIn: json['clock_in'] as String? ?? '—',
      clockOut: json['clock_out'] as String? ?? '—',
      totalHours: json['total_hours'] as String? ?? '—',
      overtime: json['overtime'] as String? ?? '—',
      isLate: _toBool(json['is_late']),
      isEarlyExit: _toBool(json['is_early_exit']),
      note: json['note'] as String?,
      punches: rawPunches
          .whereType<Map<String, dynamic>>()
          .map(AttendancePunchDetailModel.fromJson)
          .toList(),
    );
  }
}

class OvertimeRowModel extends OvertimeRowEntity {
  const OvertimeRowModel({
    required super.id,
    required super.employeeId,
    required super.name,
    required super.initials,
    required super.date,
    required super.otHours,
    required super.otType,
    required super.otAmount,
    required super.approvedBy,
    required super.status,
  });

  factory OvertimeRowModel.fromJson(Map<String, dynamic> json) {
    return OvertimeRowModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      initials: json['initials'] as String? ?? '',
      date: json['date'] as String? ?? '',
      otHours: json['ot_hours'] as String? ?? '—',
      otType: json['ot_type'] as String? ?? '',
      otAmount: json['ot_amount']?.toString() ?? '0.00',
      approvedBy: json['approved_by'] as String? ?? '—',
      status: json['status'] as String? ?? '',
    );
  }
}

class InvalidPunchModel extends InvalidPunchEntity {
  const InvalidPunchModel({
    required super.id,
    required super.deviceId,
    required super.rawTime,
    required super.biometricId,
    required super.issue,
    required super.issueType,
    required super.suggestedMatch,
    required super.branch,
  });

  factory InvalidPunchModel.fromJson(Map<String, dynamic> json) {
    return InvalidPunchModel(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id'] as String? ?? '—',
      rawTime: json['raw_time'] as String? ?? '',
      biometricId: json['biometric_id'] as String? ?? '—',
      issue: json['issue'] as String? ?? '',
      issueType: json['issue_type'] as String? ?? '',
      suggestedMatch: json['suggested_match'] as String? ?? '—',
      branch: json['branch'] as String? ?? '—',
    );
  }
}

class UnpunchRowModel extends UnpunchRowEntity {
  const UnpunchRowModel({
    required super.employeeId,
    required super.name,
    required super.initials,
    required super.date,
    required super.clockIn,
    required super.expectedOut,
    required super.branch,
    required super.correctionPending,
    super.correctionId,
  });

  factory UnpunchRowModel.fromJson(Map<String, dynamic> json) {
    return UnpunchRowModel(
      employeeId: json['employee_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      initials: json['initials'] as String? ?? '',
      date: json['date'] as String? ?? '',
      clockIn: json['clock_in'] as String? ?? '—',
      expectedOut: json['expected_out'] as String? ?? '—',
      branch: json['branch'] as String? ?? '—',
      correctionPending: _toBool(json['correction_pending']),
      correctionId: json['correction_id'] as String?,
    );
  }
}

class HrUserModel extends HrUserEntity {
  const HrUserModel({
    required super.id,
    required super.employeeId,
    required super.fullName,
    required super.department,
    required super.branch,
  });

  factory HrUserModel.fromJson(Map<String, dynamic> json) {
    return HrUserModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
    );
  }
}

class AttendanceAuditEntryModel extends AttendanceAuditEntryEntity {
  const AttendanceAuditEntryModel({
    required super.event,
    required super.performedBy,
    required super.performedAt,
    super.oldValue,
    super.newValue,
    required super.action,
    super.remarks,
  });

  factory AttendanceAuditEntryModel.fromJson(Map<String, dynamic> json) {
    return AttendanceAuditEntryModel(
      event: json['event'] as String? ?? '',
      performedBy: json['performed_by'] as String? ?? '—',
      performedAt: json['performed_at'] as String? ?? '',
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String?,
      action: json['action'] as String? ?? '',
      remarks: json['remarks'] as String?,
    );
  }
}

class ImportResultModel extends ImportResultEntity {
  const ImportResultModel({
    required super.importId,
    required super.totalRows,
    required super.success,
    required super.failed,
    required super.status,
    required super.errors,
  });

  factory ImportResultModel.fromJson(Map<String, dynamic> json) {
    final rawErrors = json['errors'] as List<dynamic>? ?? [];
    return ImportResultModel(
      importId: json['import_id']?.toString() ?? '',
      totalRows: _toInt(json['total_rows']),
      success: _toInt(json['success']),
      failed: _toInt(json['failed']),
      status: json['status'] as String? ?? '',
      errors: rawErrors.whereType<Map<String, dynamic>>().map((e) {
        return ImportRowErrorEntity(
          row: _toInt(e['row']),
          message: _flattenRowError(e['errors']),
        );
      }).toList(),
    );
  }

  // The backend's per-row `errors` value (services_hr_ops.py) is either a
  // plain string (a raised exception's str()) or a DRF serializer errors
  // dict ({field: [messages, ...]}) — calling .toString() directly on the
  // dict case produced Dart's raw map notation ("{field: [msg]}") instead of
  // readable text. Flatten it the same way the web app does
  // ("field: msg1 msg2 · field2: msg3").
  static String _flattenRowError(dynamic errors) {
    if (errors is String) return errors;
    if (errors is Map) {
      final parts = <String>[];
      errors.forEach((field, msgs) {
        final text = msgs is List ? msgs.join(' ') : msgs.toString();
        parts.add('$field: $text');
      });
      return parts.join(' · ');
    }
    return errors.toString();
  }
}

/// Parses the backend's `{count, page, page_size, total_pages, results}`
/// envelope into a [PaginatedListEntity], given a per-item parser.
PaginatedListEntity<T> parsePaginated<T>(
  dynamic data,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (data is! Map<String, dynamic>) {
    return PaginatedListEntity<T>(results: const [], count: 0, page: 1, pageSize: 20, totalPages: 1);
  }
  final rawResults = data['results'] as List<dynamic>? ?? [];
  return PaginatedListEntity<T>(
    results: rawResults.whereType<Map<String, dynamic>>().map(fromJson).toList(),
    count: _toInt(data['count']),
    page: _toInt(data['page']) == 0 ? 1 : _toInt(data['page']),
    pageSize: _toInt(data['page_size']) == 0 ? 20 : _toInt(data['page_size']),
    totalPages: _toInt(data['total_pages']) == 0 ? 1 : _toInt(data['total_pages']),
  );
}

class HrCorrectionRowModel extends HrCorrectionRowEntity {
  const HrCorrectionRowModel({
    required super.id,
    required super.employeeId,
    required super.name,
    required super.department,
    required super.branch,
    required super.date,
    required super.punchType,
    super.requestedInTime,
    super.requestedOutTime,
    required super.reason,
    super.notes,
    required super.status,
    super.l1ApproverName,
    super.l1Status,
    super.l1Remarks,
    super.l2ApproverName,
    super.l2Status,
    super.l2Remarks,
    super.canAction,
    super.reviewedBy,
    super.reviewedAt,
    required super.createdAt,
  });

  factory HrCorrectionRowModel.fromJson(Map<String, dynamic> json) {
    return HrCorrectionRowModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      date: json['date'] as String? ?? '',
      punchType: json['punch_type'] as String? ?? '',
      // Backend key is "requested_in"/"requested_out", not "..._time".
      requestedInTime: json['requested_in'] as String?,
      requestedOutTime: json['requested_out'] as String?,
      reason: json['reason'] as String? ?? '',
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? '',
      l1ApproverName: json['l1_approver_name'] as String?,
      l1Status: json['l1_status'] as String?,
      l1Remarks: json['l1_remarks'] as String? ?? '',
      l2ApproverName: json['l2_approver_name'] as String?,
      l2Status: json['l2_status'] as String?,
      l2Remarks: json['l2_remarks'] as String? ?? '',
      canAction: json['can_action'] as bool? ?? false,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class MyCorrectionModel extends MyCorrectionEntity {
  const MyCorrectionModel({
    required super.id,
    required super.date,
    required super.punchType,
    super.originalInTime,
    super.originalOutTime,
    super.requestedInTime,
    super.requestedOutTime,
    required super.reason,
    super.notes,
    required super.status,
    super.l1ApproverName,
    super.l1Status,
    super.l1Remarks,
    super.l2ApproverName,
    super.l2Status,
    super.l2Remarks,
    super.reviewedBy,
    super.reviewedAt,
    required super.createdAt,
  });

  factory MyCorrectionModel.fromJson(Map<String, dynamic> json) {
    return MyCorrectionModel(
      id: json['id']?.toString() ?? '',
      date: json['date'] as String? ?? '',
      punchType: json['punch_type'] as String? ?? '',
      originalInTime: json['original_in'] as String?,
      originalOutTime: json['original_out'] as String?,
      requestedInTime: json['requested_in'] as String?,
      requestedOutTime: json['requested_out'] as String?,
      reason: json['reason'] as String? ?? '',
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? '',
      l1ApproverName: json['l1_approver_name'] as String?,
      l1Status: json['l1_status'] as String?,
      l1Remarks: json['l1_remarks'] as String? ?? '',
      l2ApproverName: json['l2_approver_name'] as String?,
      l2Status: json['l2_status'] as String?,
      l2Remarks: json['l2_remarks'] as String? ?? '',
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
