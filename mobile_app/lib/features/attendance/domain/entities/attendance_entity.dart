// ── My Attendance (employee self-service) ──────────────────────────────────

class PunchEntryEntity {
  final String type; // 'IN' | 'OUT'
  final String time;
  final String location;
  final String attendanceMode;
  final bool isInsideGeofence;
  final double? calculatedDistance;

  const PunchEntryEntity({
    required this.type,
    required this.time,
    required this.location,
    required this.attendanceMode,
    required this.isInsideGeofence,
    this.calculatedDistance,
  });
}

class TodayAttendanceEntity {
  final bool isClockedIn;
  final List<PunchEntryEntity> punches;
  final int totalSeconds;
  final int sessionSeconds;
  final String dateDisplay;

  const TodayAttendanceEntity({
    required this.isClockedIn,
    required this.punches,
    required this.totalSeconds,
    required this.sessionSeconds,
    required this.dateDisplay,
  });
}

class AttendanceStatsEntity {
  final int daysPresent;
  final int lateArrivals;
  final int lopPending;
  final double avgHoursPerDay;
  final double attendancePercentage;
  final int workingDays;

  const AttendanceStatsEntity({
    required this.daysPresent,
    required this.lateArrivals,
    required this.lopPending,
    required this.avgHoursPerDay,
    required this.attendancePercentage,
    required this.workingDays,
  });
}

class MonthlySummaryEntity {
  final int workingDays;
  final int daysPresent;
  final int daysAbsent;
  final int leaveDays;
  final int halfDays;
  final String otHours; // backend-formatted display string, e.g. "9h 07m" or "0h"

  const MonthlySummaryEntity({
    required this.workingDays,
    required this.daysPresent,
    required this.daysAbsent,
    required this.leaveDays,
    required this.halfDays,
    required this.otHours,
  });
}

class CalendarDayEntity {
  final String status;
  final String? clockIn;
  final String? clockOut;
  final String? hours;
  final String? note;
  final String? holidayName;
  final bool canRegularize;

  const CalendarDayEntity({
    required this.status,
    this.clockIn,
    this.clockOut,
    this.hours,
    this.note,
    this.holidayName,
    required this.canRegularize,
  });
}

class AttendanceHistoryRowEntity {
  final String date;
  final String day;
  final String? clockIn;
  final String? clockOut;
  final String? hours;
  final String status;
  final bool canRegularize;

  const AttendanceHistoryRowEntity({
    required this.date,
    required this.day,
    this.clockIn,
    this.clockOut,
    this.hours,
    required this.status,
    required this.canRegularize,
  });
}

class AttendanceCalendarEntity {
  final Map<int, CalendarDayEntity> days;
  final List<AttendanceHistoryRowEntity> history;
  final int month;
  final int year;

  const AttendanceCalendarEntity({
    required this.days,
    required this.history,
    required this.month,
    required this.year,
  });
}

class AttendanceCorrectionEntity {
  final String id;
  final String date;
  final String punchType;
  final String reason;
  final String status;
  final String createdAt;

  const AttendanceCorrectionEntity({
    required this.id,
    required this.date,
    required this.punchType,
    required this.reason,
    required this.status,
    required this.createdAt,
  });
}

// ── HR Attendance Management ────────────────────────────────────────────────

class AttendanceDashboardEntity {
  final int presentToday;
  final int absent;
  final int lateArrivals;
  final int onLeave;
  final int totalEmployees;
  final Map<String, int> summaryChips;
  final int invalidPunchesCount;
  final int unPunchesCount;

  const AttendanceDashboardEntity({
    required this.presentToday,
    required this.absent,
    required this.lateArrivals,
    required this.onLeave,
    required this.totalEmployees,
    required this.summaryChips,
    required this.invalidPunchesCount,
    required this.unPunchesCount,
  });
}

class AttendanceRowEntity {
  final String? recordId;
  final String employeeId;
  final String name;
  final String initials;
  final String department;
  final String branch;
  final String clockIn;
  final String clockOut;
  final String totalHours;
  final String ot;
  final String status;
  final String statusKey;
  final bool isLate;

  const AttendanceRowEntity({
    required this.recordId,
    required this.employeeId,
    required this.name,
    required this.initials,
    required this.department,
    required this.branch,
    required this.clockIn,
    required this.clockOut,
    required this.totalHours,
    required this.ot,
    required this.status,
    required this.statusKey,
    required this.isLate,
  });
}

class AttendancePunchDetailEntity {
  final String punchType;
  final String time;
  final String source;
  final String mode;
  final bool isGeofence;
  final double? distanceM;

  const AttendancePunchDetailEntity({
    required this.punchType,
    required this.time,
    required this.source,
    required this.mode,
    required this.isGeofence,
    this.distanceM,
  });
}

class AttendanceDetailEntity {
  final String? recordId;
  final String employeeId;
  final String name;
  final String department;
  final String branch;
  final String date;
  final String status;
  final String statusKey;
  final String clockIn;
  final String clockOut;
  final String totalHours;
  final String overtime;
  final bool isLate;
  final bool isEarlyExit;
  final String? note;
  final List<AttendancePunchDetailEntity> punches;

  const AttendanceDetailEntity({
    required this.recordId,
    required this.employeeId,
    required this.name,
    required this.department,
    required this.branch,
    required this.date,
    required this.status,
    required this.statusKey,
    required this.clockIn,
    required this.clockOut,
    required this.totalHours,
    required this.overtime,
    required this.isLate,
    required this.isEarlyExit,
    this.note,
    required this.punches,
  });
}

class OvertimeRowEntity {
  final String id;
  final String employeeId;
  final String name;
  final String initials;
  final String date;
  final String otHours;
  final String otType;
  final String otAmount;
  final String approvedBy;
  final String status;

  const OvertimeRowEntity({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.initials,
    required this.date,
    required this.otHours,
    required this.otType,
    required this.otAmount,
    required this.approvedBy,
    required this.status,
  });
}

class InvalidPunchEntity {
  final String id;
  final String deviceId;
  final String rawTime;
  final String biometricId;
  final String issue;
  final String issueType;
  final String suggestedMatch;
  final String branch;

  const InvalidPunchEntity({
    required this.id,
    required this.deviceId,
    required this.rawTime,
    required this.biometricId,
    required this.issue,
    required this.issueType,
    required this.suggestedMatch,
    required this.branch,
  });
}

class UnpunchRowEntity {
  final String employeeId;
  final String name;
  final String initials;
  final String date;
  final String clockIn;
  final String expectedOut;
  final String branch;
  final bool correctionPending;
  final String? correctionId;

  const UnpunchRowEntity({
    required this.employeeId,
    required this.name,
    required this.initials,
    required this.date,
    required this.clockIn,
    required this.expectedOut,
    required this.branch,
    required this.correctionPending,
    this.correctionId,
  });
}

class HrCorrectionRowEntity {
  final String id;
  final String employeeId;
  final String name;
  final String department;
  final String branch;
  final String date;
  final String punchType;
  final String? requestedInTime;
  final String? requestedOutTime;
  final String reason;
  final String? notes;
  final String status;
  // Two-stage approval breakdown (L1 = reporting manager, L2 = HR) — matches
  // web's CorrectionRow. `canAction` is server-computed: true only when the
  // current user is the designated approver for whichever stage the request
  // currently sits at (l1_pending -> manager, l2_pending -> HR).
  final String? l1ApproverName;
  final String? l1Status;
  final String l1Remarks;
  final String? l2ApproverName;
  final String? l2Status;
  final String l2Remarks;
  final bool canAction;
  final String? reviewedBy;
  final String? reviewedAt;
  final String createdAt;

  const HrCorrectionRowEntity({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.department,
    required this.branch,
    required this.date,
    required this.punchType,
    this.requestedInTime,
    this.requestedOutTime,
    required this.reason,
    this.notes,
    required this.status,
    this.l1ApproverName,
    this.l1Status,
    this.l1Remarks = '',
    this.l2ApproverName,
    this.l2Status,
    this.l2Remarks = '',
    this.canAction = false,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
  });
}

// An employee's own correction request (GET /attendance/corrections/my/) —
// distinct from HrCorrectionRowEntity above, which is the HR/manager review
// inbox (all employees, with a canAction approve/reject affordance). This is
// always the caller's own request, so it carries no employee-identity
// fields, but does carry `original*Time` (the punch as it was originally
// recorded) alongside `requested*Time` (what the employee is asking to
// change it to) — mirrors web's MyCorrectionRequest (my-requests/_data.ts).
class MyCorrectionEntity {
  final String id;
  final String date;
  final String punchType;
  final String? originalInTime;
  final String? originalOutTime;
  final String? requestedInTime;
  final String? requestedOutTime;
  final String reason;
  final String? notes;
  final String status;
  final String? l1ApproverName;
  final String? l1Status;
  final String l1Remarks;
  final String? l2ApproverName;
  final String? l2Status;
  final String l2Remarks;
  final String? reviewedBy;
  final String? reviewedAt;
  final String createdAt;

  const MyCorrectionEntity({
    required this.id,
    required this.date,
    required this.punchType,
    this.originalInTime,
    this.originalOutTime,
    this.requestedInTime,
    this.requestedOutTime,
    required this.reason,
    this.notes,
    required this.status,
    this.l1ApproverName,
    this.l1Status,
    this.l1Remarks = '',
    this.l2ApproverName,
    this.l2Status,
    this.l2Remarks = '',
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
  });
}

class HrUserEntity {
  final String id;
  final String employeeId;
  final String fullName;
  final String department;
  final String branch;

  const HrUserEntity({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.department,
    required this.branch,
  });
}

class AttendanceAuditEntryEntity {
  final String event;
  final String performedBy;
  final String performedAt;
  final String? oldValue;
  final String? newValue;
  final String action;
  final String? remarks;

  const AttendanceAuditEntryEntity({
    required this.event,
    required this.performedBy,
    required this.performedAt,
    this.oldValue,
    this.newValue,
    required this.action,
    this.remarks,
  });
}

class ImportRowErrorEntity {
  final int row;
  final String message;
  const ImportRowErrorEntity({required this.row, required this.message});
}

class ImportResultEntity {
  final String importId;
  final int totalRows;
  final int success;
  final int failed;
  final String status;
  final List<ImportRowErrorEntity> errors;

  const ImportResultEntity({
    required this.importId,
    required this.totalRows,
    required this.success,
    required this.failed,
    required this.status,
    required this.errors,
  });
}

/// Generic page envelope matching the backend's `{count, page, page_size,
/// total_pages, results}` pagination shape.
class PaginatedListEntity<T> {
  final List<T> results;
  final int count;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedListEntity({
    required this.results,
    required this.count,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });
}

// Reason codes for AttendanceCorrection.reason — must match backend REASON_CHOICES exactly.
class CorrectionReasonCodes {
  CorrectionReasonCodes._();

  static const String biometricError = 'biometric_error';
  static const String forgotToPunch = 'forgot_to_punch';
  static const String fieldWork = 'field_work';
  static const String systemDowntime = 'system_downtime';
  static const String other = 'other';

  static const Map<String, String> labels = {
    biometricError: 'Device malfunction / biometric error',
    forgotToPunch: 'Forgot to punch',
    fieldWork: 'Work from field (client visit)',
    systemDowntime: 'System downtime',
    other: 'Other',
  };
}
