import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/attendance_approval_models.dart';

/// Backs the Attendance Approval tab (Approvals screen) — a payroll-cycle
/// attendance sign-off flow (L1 manager -> L2 HR). Hits the same backend
/// payroll-cycle endpoints the (removed) mobile Payroll module used, since
/// attendance approval is gated on payroll cycles server-side.
class AttendanceApprovalRemoteDataSource {
  final Dio _dio;
  AttendanceApprovalRemoteDataSource(this._dio);

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  List<dynamic> _resultsList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) return data['results'] as List<dynamic>? ?? [];
    return const [];
  }

  Future<PayrollSettingsModel> fetchPayrollSettings() async {
    final res = await _dio.get(ApiConstants.payrollSettings);
    return PayrollSettingsModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<List<PayrollCycleModel>> fetchPendingApprovalCycles() async {
    final res = await _dio.get(ApiConstants.payrollPendingApproval);
    return _resultsList(_unwrap(res.data))
        .whereType<Map<String, dynamic>>()
        .map(PayrollCycleModel.fromJson)
        .toList();
  }

  Future<CycleAttendanceSummary> fetchCycleAttendanceSummary(String cycleId) async {
    final res = await _dio.get(ApiConstants.payrollAttendanceSummary(cycleId));
    final data = _unwrap(res.data) as Map<String, dynamic>;
    final cycleJson = data['cycle'] as Map<String, dynamic>? ?? {};
    final managerApprovals = (cycleJson['manager_approvals'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ManagerApprovalRow.fromJson)
        .toList();
    final cycle = PayrollCycleModel(
      id: cycleJson['id']?.toString() ?? cycleId,
      cycleStart: DateTime.tryParse(cycleJson['cycle_start']?.toString() ?? '') ?? DateTime.now(),
      cycleEnd: DateTime.tryParse(cycleJson['cycle_end']?.toString() ?? '') ?? DateTime.now(),
      payDate: DateTime.tryParse(cycleJson['pay_date']?.toString() ?? '') ?? DateTime.now(),
      status: cycleJson['status'] as String? ?? PayrollCycleStatus.attendancePending,
      createdByName: '',
      l1ApproverName: cycleJson['l1_approver'] as String?,
      l2ApproverName: cycleJson['l2_approver'] as String?,
      l1ApprovedAt: DateTime.tryParse(cycleJson['l1_approved_at']?.toString() ?? ''),
      l2ApprovedAt: DateTime.tryParse(cycleJson['l2_approved_at']?.toString() ?? ''),
      hrSelfApprovedAt: DateTime.tryParse(cycleJson['hr_self_approved_at']?.toString() ?? ''),
      notes: '',
      payslipCount: 0,
      managerApprovals: managerApprovals,
      mgrApprovedCount: (cycleJson['mgr_approved_count'] as num?)?.toInt() ?? 0,
      mgrTotalCount: (cycleJson['mgr_total_count'] as num?)?.toInt() ?? 0,
      mgrAllApproved: cycleJson['mgr_all_approved'] as bool? ?? false,
      currentUserPending: cycleJson['current_user_pending'] as bool? ?? false,
    );
    return CycleAttendanceSummary.fromJson(data, cycle);
  }

  /// level: 'L1' (manager) or 'L2' (hr_admin). `selfApprove` mirrors web's
  /// `self_approve` flag — optional self-attestation of the approver's own
  /// attendance for the cycle, separate from approving their team/the cycle
  /// (see ManagerAttendanceApproval.self_approved_at / PayrollCycle.hr_self_approved_at,
  /// apps/payroll/views/cycles.py AttendanceApprovalView.post).
  Future<PayrollCycleModel> approveAttendance(
    String cycleId,
    String level, {
    String? comment,
    bool selfApprove = false,
  }) async {
    final res = await _dio.post(ApiConstants.payrollApproveAttendance(cycleId), data: {
      'level': level,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      'self_approve': selfApprove,
    });
    return PayrollCycleModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<EmployeeDailyAttendance> fetchEmployeeDailyAttendance(String cycleId, String employeeId) async {
    final res = await _dio.get(ApiConstants.payrollEmployeeDailyAttendance(cycleId, employeeId));
    final data = _unwrap(res.data) as Map<String, dynamic>;
    return EmployeeDailyAttendance.fromJson(data);
  }
}
