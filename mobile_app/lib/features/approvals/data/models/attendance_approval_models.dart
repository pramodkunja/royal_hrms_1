import 'package:flutter/foundation.dart';

// Models for the Attendance Approval tab (Approvals screen) — a payroll-cycle
// attendance sign-off flow (L1 manager -> L2 HR). These mirror the backend's
// PayrollCycle-related endpoints (apps/payroll), which the attendance
// approval flow depends on even though it isn't itself a payroll UI feature.

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

DateTime? _toDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

// ── Payroll Cycle ─────────────────────────────────────────────────────────────
// Mirrors PayrollCycle.STATUS_CHOICES (apps/payroll/models.py) exactly.

class PayrollCycleStatus {
  PayrollCycleStatus._();
  static const String draft = 'draft';
  static const String attendancePending = 'attendance_pending';
  static const String attendanceApproved = 'attendance_approved';
  static const String processing = 'processing';
  static const String payslipsGenerated = 'payslips_generated';
  static const String queryWindowOpen = 'query_window_open';
  static const String paid = 'paid';
  static const String closed = 'closed';

  static String label(String s) => switch (s) {
    draft => 'Draft',
    attendancePending => 'Awaiting Attendance Approval',
    attendanceApproved => 'Attendance Approved',
    processing => 'Processing',
    payslipsGenerated => 'Payslips Generated',
    queryWindowOpen => 'Employee Query Window Open',
    paid => 'Paid',
    closed => 'Closed',
    _ => s,
  };
}

// One manager's sign-off row for a payroll cycle's attendance approval —
// mirrors ManagerAttendanceApprovalSerializer. Multiple managers (one per
// team) each have their own row; L1 as a whole is only "done" once every
// row is approved.
@immutable
class ManagerApprovalRow {
  final String id;
  final String managerName;
  final DateTime? approvedAt;
  // Set alongside approvedAt when the manager also self-attested their own
  // attendance for the cycle (see ManagerAttendanceApproval.self_approved_at,
  // apps/payroll/models.py) — distinct from approvedAt, which covers their team.
  final DateTime? selfApprovedAt;

  const ManagerApprovalRow({
    required this.id,
    required this.managerName,
    this.approvedAt,
    this.selfApprovedAt,
  });

  factory ManagerApprovalRow.fromJson(Map<String, dynamic> json) =>
      ManagerApprovalRow(
        id: json['id']?.toString() ?? '',
        managerName: json['manager_name'] as String? ?? '',
        approvedAt: _toDate(json['approved_at']),
        selfApprovedAt: _toDate(json['self_approved_at']),
      );
}

@immutable
class PayrollCycleModel {
  final String id;
  final DateTime cycleStart;
  final DateTime cycleEnd;
  final DateTime payDate;
  final String status;
  final String createdByName;
  // Legacy single-approver fields — only set once every manager (see
  // managerApprovals below) has signed off for L1, or HR has for L2.
  final String? l1ApproverName;
  final String? l2ApproverName;
  final DateTime? l1ApprovedAt;
  final DateTime? l2ApprovedAt;
  // HR's self-attestation of their own attendance when doing the L2 sign-off
  // (PayrollCycle.hr_self_approved_at, apps/payroll/models.py).
  final DateTime? hrSelfApprovedAt;
  final DateTime? queryWindowClosesAt;
  final DateTime? paidAt;
  final String notes;
  final int payslipCount;
  // Per-manager L1 sign-off breakdown (only populated by the
  // attendance-summary endpoint, not the plain cycle list).
  final List<ManagerApprovalRow> managerApprovals;
  final int mgrApprovedCount;
  final int mgrTotalCount;
  final bool mgrAllApproved;
  // True when the CURRENT viewer has their own pending manager-approval row
  // for this cycle — this, not a role check, is what should gate whether
  // the Approve L1 button shows for them.
  final bool currentUserPending;

  const PayrollCycleModel({
    required this.id,
    required this.cycleStart,
    required this.cycleEnd,
    required this.payDate,
    required this.status,
    required this.createdByName,
    this.l1ApproverName,
    this.l2ApproverName,
    this.l1ApprovedAt,
    this.l2ApprovedAt,
    this.hrSelfApprovedAt,
    this.queryWindowClosesAt,
    this.paidAt,
    required this.notes,
    required this.payslipCount,
    this.managerApprovals = const [],
    this.mgrApprovedCount = 0,
    this.mgrTotalCount = 0,
    this.mgrAllApproved = false,
    this.currentUserPending = false,
  });

  factory PayrollCycleModel.fromJson(Map<String, dynamic> json) => PayrollCycleModel(
    id: json['id'].toString(),
    cycleStart: _toDate(json['cycle_start']) ?? DateTime.now(),
    cycleEnd: _toDate(json['cycle_end']) ?? DateTime.now(),
    payDate: _toDate(json['pay_date']) ?? DateTime.now(),
    status: json['status'] as String? ?? PayrollCycleStatus.draft,
    createdByName: json['created_by_name'] as String? ?? '',
    l1ApproverName: json['l1_approver_name'] as String?,
    l2ApproverName: json['l2_approver_name'] as String?,
    l1ApprovedAt: _toDate(json['attendance_l1_approved_at']),
    l2ApprovedAt: _toDate(json['attendance_l2_approved_at']),
    hrSelfApprovedAt: _toDate(json['hr_self_approved_at']),
    queryWindowClosesAt: _toDate(json['query_window_closes_at']),
    paidAt: _toDate(json['paid_at']),
    notes: json['notes'] as String? ?? '',
    payslipCount: _toInt(json['payslip_count']),
  );
}

// ── Attendance summary (per-cycle, feeds the Attendance Approval step) ──────

@immutable
class AttendanceSummaryRow {
  final String employeeId;
  final String employeeUuid;
  final String fullName;
  final String department;
  final String designation;
  final int presentDays;
  final int lateDays;
  final int halfDays;
  final int absentDays;
  final int incompleteDays;
  final int onLeaveDays;
  final int lopDays;
  final double workingHours;

  const AttendanceSummaryRow({
    required this.employeeId,
    required this.employeeUuid,
    required this.fullName,
    required this.department,
    required this.designation,
    required this.presentDays,
    required this.lateDays,
    required this.halfDays,
    required this.absentDays,
    required this.incompleteDays,
    required this.onLeaveDays,
    required this.lopDays,
    required this.workingHours,
  });

  factory AttendanceSummaryRow.fromJson(Map<String, dynamic> json) => AttendanceSummaryRow(
    employeeId: json['employee_id'] as String? ?? '',
    employeeUuid: json['employee_uuid'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    department: json['department'] as String? ?? '—',
    designation: json['designation'] as String? ?? '—',
    presentDays: _toInt(json['present_days']),
    lateDays: _toInt(json['late_days']),
    halfDays: _toInt(json['half_days']),
    absentDays: _toInt(json['absent_days']),
    incompleteDays: _toInt(json['incomplete_days']),
    onLeaveDays: _toInt(json['on_leave_days']),
    lopDays: _toInt(json['lop_days']),
    workingHours: _toDouble(json['working_hours']),
  );
}

@immutable
class CycleAttendanceSummary {
  final PayrollCycleModel cycle;
  final List<AttendanceSummaryRow> employees;
  const CycleAttendanceSummary({required this.cycle, required this.employees});

  factory CycleAttendanceSummary.fromJson(Map<String, dynamic> json, PayrollCycleModel cycle) {
    final list = json['employees'] as List<dynamic>? ?? [];
    return CycleAttendanceSummary(
      cycle: cycle,
      employees: list.whereType<Map<String, dynamic>>().map(AttendanceSummaryRow.fromJson).toList(),
    );
  }
}

// ── Employee daily attendance (within a payroll cycle) ───────────────────────

class DailyAttendanceRow {
  final DateTime date;
  final String day;
  final String status;
  final String statusLabel;
  final double workingHours;
  final bool isFlagged;

  const DailyAttendanceRow({
    required this.date,
    required this.day,
    required this.status,
    required this.statusLabel,
    required this.workingHours,
    required this.isFlagged,
  });

  factory DailyAttendanceRow.fromJson(Map<String, dynamic> json) => DailyAttendanceRow(
        date: _toDate(json['date']) ?? DateTime.now(),
        day: json['day']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        statusLabel: json['status_label']?.toString() ?? '',
        workingHours: _toDouble(json['working_hours']),
        isFlagged: json['is_flagged'] as bool? ?? false,
      );
}

class EmployeeDailyAttendance {
  final String employeeId;
  final String fullName;
  final List<DailyAttendanceRow> days;

  const EmployeeDailyAttendance({required this.employeeId, required this.fullName, required this.days});

  factory EmployeeDailyAttendance.fromJson(Map<String, dynamic> json) {
    final list = json['days'] as List<dynamic>? ?? [];
    return EmployeeDailyAttendance(
      employeeId: json['employee_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      days: list.whereType<Map<String, dynamic>>().map(DailyAttendanceRow.fromJson).toList(),
    );
  }
}

// ── Payroll Settings (singleton) — only `approvalLevels` is read here, to
// decide whether the Attendance Approval flow requires L1 only or L1 + L2 ──

class ApprovalLevels {
  ApprovalLevels._();
  static const String l1 = 'L1';
  static const String l1l2 = 'L1_L2';
  static String label(String s) => s == l1 ? 'Manager only (L1)' : 'Manager + HR (L1 + L2)';
}

@immutable
class PayrollSettingsModel {
  final String id;
  final int cycleStartDay;
  final int cycleEndDay;
  final int payDay;
  final String approvalLevels;
  final int employeeQueryWindowHours;
  final bool enableReimbursements;
  final bool enableBonuses;

  const PayrollSettingsModel({
    required this.id,
    required this.cycleStartDay,
    required this.cycleEndDay,
    required this.payDay,
    required this.approvalLevels,
    required this.employeeQueryWindowHours,
    required this.enableReimbursements,
    required this.enableBonuses,
  });

  factory PayrollSettingsModel.fromJson(Map<String, dynamic> json) => PayrollSettingsModel(
    id: json['id'].toString(),
    cycleStartDay: _toInt(json['cycle_start_day']),
    cycleEndDay: _toInt(json['cycle_end_day']),
    payDay: _toInt(json['pay_day']),
    approvalLevels: json['approval_levels'] as String? ?? ApprovalLevels.l1l2,
    employeeQueryWindowHours: _toInt(json['employee_query_window_hours']),
    enableReimbursements: json['enable_reimbursements'] as bool? ?? true,
    enableBonuses: json['enable_bonuses'] as bool? ?? true,
  );
}
