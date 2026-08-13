import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/attendance_approval_remote_datasource.dart';
import '../../data/models/attendance_approval_models.dart';

/// Providers backing the Attendance Approval tab (Approvals screen) — a
/// payroll-cycle attendance sign-off flow (L1 manager -> L2 HR).

final attendanceApprovalDataSourceProvider = Provider<AttendanceApprovalRemoteDataSource>((ref) {
  return AttendanceApprovalRemoteDataSource(ref.watch(dioProvider));
});

// ── Payroll Settings (read-only here — only `approvalLevels` is consulted) ──

final payrollSettingsProvider = FutureProvider.autoDispose<PayrollSettingsModel>((ref) {
  return ref.read(attendanceApprovalDataSourceProvider).fetchPayrollSettings();
});

// ── Attendance Approval (Approvals screen) ───────────────────────────────────

final pendingApprovalCyclesProvider = AsyncNotifierProvider.autoDispose<PendingApprovalCyclesNotifier,
    List<PayrollCycleModel>>(PendingApprovalCyclesNotifier.new);

class PendingApprovalCyclesNotifier extends AutoDisposeAsyncNotifier<List<PayrollCycleModel>> {
  @override
  Future<List<PayrollCycleModel>> build() =>
      ref.read(attendanceApprovalDataSourceProvider).fetchPendingApprovalCycles();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final cycleAttendanceSummaryProvider =
    FutureProvider.autoDispose.family<CycleAttendanceSummary, String>((ref, cycleId) {
  return ref.read(attendanceApprovalDataSourceProvider).fetchCycleAttendanceSummary(cycleId);
});

class EmployeeDailyAttendanceKey {
  final String cycleId;
  final String employeeId;
  const EmployeeDailyAttendanceKey(this.cycleId, this.employeeId);

  @override
  bool operator ==(Object other) =>
      other is EmployeeDailyAttendanceKey && other.cycleId == cycleId && other.employeeId == employeeId;

  @override
  int get hashCode => Object.hash(cycleId, employeeId);
}

final employeeDailyAttendanceProvider = FutureProvider.autoDispose
    .family<EmployeeDailyAttendance, EmployeeDailyAttendanceKey>((ref, key) {
  return ref.read(attendanceApprovalDataSourceProvider).fetchEmployeeDailyAttendance(key.cycleId, key.employeeId);
});

/// Approves L1/L2 attendance for an arbitrary cycle (Approvals screen).
/// `selfApprove` mirrors web's optional self-attestation checkbox.
Future<String?> approveCycleAttendance(
  WidgetRef ref,
  String cycleId,
  String level, {
  String? comment,
  bool selfApprove = false,
}) async {
  try {
    await ref
        .read(attendanceApprovalDataSourceProvider)
        .approveAttendance(cycleId, level, comment: comment, selfApprove: selfApprove);
    ref.invalidate(cycleAttendanceSummaryProvider(cycleId));
    ref.invalidate(pendingApprovalCyclesProvider);
    return null;
  } catch (e) {
    return friendlyPayrollError(e);
  }
}

// ── Error helper ──────────────────────────────────────────────────────────────

String friendlyPayrollError(Object e) {
  if (e is DioException) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Cannot reach server. Check your connection.';
    }
    return parseDioException(e).message;
  }
  return e.toString().replaceAll('Exception:', '').trim();
}
