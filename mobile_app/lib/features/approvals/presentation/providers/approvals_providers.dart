import 'package:dio/dio.dart' show MultipartFile;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../attendance/domain/entities/attendance_entity.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart'
    show attendanceRepositoryProvider, friendlyAttendanceError;
import '../../../expenses/data/models/expense_model.dart';
import '../../../expenses/presentation/providers/expense_providers.dart'
    show expenseDataSourceProvider;
import '../../../leave/domain/entities/leave_entity.dart';
import '../../../leave/presentation/providers/leave_providers.dart'
    show leaveRepositoryProvider;

// Aggregated "Approvals" screen (/dashboard/approvals) — ports the web
// frontend's app/dashboard/approvals/page.tsx: a "My Requests" section
// (own leave + expense requests, with quick-create) and a "Team Approvals"
// section (pending items awaiting the current user's action), each
// switchable between Leave and Expense. There is no backend endpoint that
// aggregates the two — this composes the existing /leave/requests/ and
// /expenses/ endpoints client-side, same as the web page does.

enum ApprovalsRequestType { leave, expense, attendanceCorrection }

// ── Filters (screen-local UI state) ────────────────────────────────────────────

final myRequestsTypeProvider = StateProvider.autoDispose<ApprovalsRequestType>(
    (ref) => ApprovalsRequestType.leave);

final myRequestsStatusFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'all');

final teamApprovalsTypeProvider =
    StateProvider.autoDispose<ApprovalsRequestType>(
        (ref) => ApprovalsRequestType.leave);

// ── My Requests — own leave requests ───────────────────────────────────────────

final myLeaveRequestsProvider = AsyncNotifierProvider.autoDispose<
    MyLeaveRequestsNotifier, List<LeaveRequestEntity>>(
  MyLeaveRequestsNotifier.new,
);

class MyLeaveRequestsNotifier
    extends AutoDisposeAsyncNotifier<List<LeaveRequestEntity>> {
  @override
  Future<List<LeaveRequestEntity>> build() {
    final status = ref.watch(myRequestsStatusFilterProvider);
    // scope: 'own' forces "my requests only" even for users with
    // leave.approve — without it they'd get the approval queue instead.
    return ref.read(leaveRepositoryProvider).getLeaveRequests(
          status: status == 'all' ? null : status,
          scope: 'own',
        );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<String?> apply({
    required String leaveTypeCode,
    required String fromDate,
    required String toDate,
    required String reason,
  }) async {
    try {
      await ref.read(leaveRepositoryProvider).applyLeave(
            leaveTypeCode: leaveTypeCode,
            fromDate: fromDate,
            toDate: toDate,
            reason: reason,
            duration: 'full_day',
          );
      await refresh();
      return null;
    } catch (e) {
      return friendlyApprovalsError(e);
    }
  }
}

// ── My Requests — own expenses ─────────────────────────────────────────────────

final myExpensesProvider =
    AsyncNotifierProvider.autoDispose<MyExpensesNotifier, List<ExpenseModel>>(
  MyExpensesNotifier.new,
);

class MyExpensesNotifier extends AutoDisposeAsyncNotifier<List<ExpenseModel>> {
  @override
  Future<List<ExpenseModel>> build() {
    final status = ref.watch(myRequestsStatusFilterProvider);
    return ref.read(expenseDataSourceProvider).fetchExpenses(
          status: status == 'all' ? null : status,
          scope: 'own',
        );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<String?> submit({
    required String title,
    required String amount,
    required String category,
    required String expenseDate,
    required String description,
    required List<MultipartFile> receipts,
  }) async {
    try {
      await ref.read(expenseDataSourceProvider).submitExpense(
            title: title,
            amount: amount,
            category: category,
            expenseDate: expenseDate,
            description: description,
            receipts: receipts,
          );
      await refresh();
      return null;
    } catch (e) {
      return friendlyApprovalsError(e);
    }
  }
}

// ── Team Approvals — pending leave requests ───────────────────────────────────

final pendingLeaveApprovalsProvider = AsyncNotifierProvider.autoDispose<
    PendingLeaveApprovalsNotifier, List<LeaveRequestEntity>>(
  PendingLeaveApprovalsNotifier.new,
);

class PendingLeaveApprovalsNotifier
    extends AutoDisposeAsyncNotifier<List<LeaveRequestEntity>> {
  @override
  Future<List<LeaveRequestEntity>> build() => ref
      .read(leaveRepositoryProvider)
      // scope: 'team' is required here — without it the backend returns the
      // CALLER's own requests regardless of role (see
      // LeaveRemoteDataSource.fetchLeaveRequests' doc comment), which made
      // this "Team Approvals" queue show the manager/HR's own pending leave
      // (usually none) instead of their team's, appearing empty/broken.
      // Matches web's GET /leave/requests/?scope=team.
      .getLeaveRequests(status: 'pending,l2_pending', scope: 'team');

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<String?> approve(String id) async {
    try {
      await ref.read(leaveRepositoryProvider).approveLeave(id);
      await refresh();
      return null;
    } catch (e) {
      return friendlyApprovalsError(e);
    }
  }

  Future<String?> reject(String id, String remarks) async {
    try {
      await ref.read(leaveRepositoryProvider).rejectLeave(id, remarks);
      await refresh();
      return null;
    } catch (e) {
      return friendlyApprovalsError(e);
    }
  }
}

// ── Team Approvals — pending expenses ─────────────────────────────────────────

final pendingExpenseApprovalsProvider = AsyncNotifierProvider.autoDispose<
    PendingExpenseApprovalsNotifier, List<ExpenseModel>>(
  PendingExpenseApprovalsNotifier.new,
);

class PendingExpenseApprovalsNotifier
    extends AutoDisposeAsyncNotifier<List<ExpenseModel>> {
  @override
  Future<List<ExpenseModel>> build() =>
      ref.read(expenseDataSourceProvider).fetchExpenses(status: 'pending');

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<String?> setStatus(int expenseNumber, String status) async {
    try {
      await ref
          .read(expenseDataSourceProvider)
          .updateExpenseStatus(expenseNumber, status);
      await refresh();
      return null;
    } catch (e) {
      return friendlyApprovalsError(e);
    }
  }
}

// ── Team Approvals — pending attendance corrections ───────────────────────────
// A separate provider (not attendance feature's own hrCorrectionsProvider)
// so this list isn't affected by whatever branch/department filter the user
// left set on the Attendance screen — mirrors why pendingLeaveApprovalsProvider
// is distinct from leaveTeamPendingProvider above.

final teamCorrectionsStatusFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'pending');

final teamCorrectionsProvider = AsyncNotifierProvider.autoDispose<
    TeamCorrectionsNotifier, List<HrCorrectionRowEntity>>(
  TeamCorrectionsNotifier.new,
);

class TeamCorrectionsNotifier
    extends AutoDisposeAsyncNotifier<List<HrCorrectionRowEntity>> {
  @override
  Future<List<HrCorrectionRowEntity>> build() {
    final status = ref.watch(teamCorrectionsStatusFilterProvider);
    return ref.read(attendanceRepositoryProvider).getHrCorrections(
          status: status == 'all' ? null : status,
        );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<String?> reviewCorrection(String id, {required bool approve}) async {
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .reviewCorrection(id, approve: approve);
      await refresh();
      return null;
    } catch (e) {
      return friendlyAttendanceError(e);
    }
  }
}

// ── Error helper ──────────────────────────────────────────────────────────────

String friendlyApprovalsError(Object e) {
  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('connection')) {
    return 'Cannot reach server. Check your connection.';
  }
  if (msg.contains('401')) return 'Session expired. Please log in again.';
  if (msg.contains('403')) return 'You do not have permission to do this.';
  if (msg.contains('409')) return 'This request has already been actioned.';
  if (msg.contains('500')) return 'Server error. Please try again later.';
  return msg.replaceAll('Exception:', '').trim();
}
