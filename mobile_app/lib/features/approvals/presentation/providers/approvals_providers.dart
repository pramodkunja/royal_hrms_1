import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../attendance/domain/entities/attendance_entity.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart'
    show attendanceRepositoryProvider, hrCorrectionsProvider;
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../expenses/presentation/providers/expense_providers.dart'
    show expenseDataSourceProvider;
import '../../../leave/domain/entities/leave_entity.dart';
import '../../../leave/presentation/providers/leave_providers.dart'
    show leaveRepositoryProvider;
import '../../../wfh/domain/entities/wfh_entity.dart';
import '../../../wfh/presentation/providers/wfh_providers.dart'
    show wfhRepositoryProvider;

// Ports web's app/dashboard/approvals/page.tsx "Team Approvals" tab — a
// unified inbox merging Leave requests + Expense claims + Attendance
// Corrections + Work From Home requests into ONE list (matching web's
// TeamApprovalsSection.tsx, which folds `wfh` in as one of its request
// kinds alongside leave/expense/attendance_correction). There is no backend
// endpoint that aggregates these — this composes the existing
// /leave/requests/, /expenses/, /attendance/corrections/ and /wfh/requests/
// endpoints client-side, same as the web page does.

// ── Unified item model (presentation-layer glue, not a clean-arch entity) ──────

enum UnifiedApprovalKind { leave, expense, attendanceCorrection, wfh }

class UnifiedApprovalItem {
  final UnifiedApprovalKind kind;
  final String sourceId; // leave/correction UUID, or expense's expenseNumber as a string
  final String employeeName;
  final String employeeCode; // '' for expense
  final String department; // '' for expense
  final String secondaryText; // branchName fallback for expense rows
  final String typeLabel;
  final String primaryLine;
  final String secondaryLine;
  final String tertiaryLine;
  final String reason;
  final String status; // raw backend status string
  final DateTime submittedAt;
  final bool canAction;

  // Raw source object — carried along so the detail sheet and approve/reject
  // calls don't need to re-fetch anything.
  final LeaveRequestEntity? leave;
  final ExpenseModel? expense;
  final HrCorrectionRowEntity? correction;
  final WfhRequestEntity? wfh;

  const UnifiedApprovalItem({
    required this.kind,
    required this.sourceId,
    required this.employeeName,
    required this.employeeCode,
    required this.department,
    required this.secondaryText,
    required this.typeLabel,
    required this.primaryLine,
    required this.secondaryLine,
    required this.tertiaryLine,
    required this.reason,
    required this.status,
    required this.submittedAt,
    required this.canAction,
    this.leave,
    this.expense,
    this.correction,
    this.wfh,
  });

  bool get isPending =>
      status != 'approved' && status != 'rejected' && status != 'cancelled';

  factory UnifiedApprovalItem.fromLeave(LeaveRequestEntity r) {
    final tertiary = StringBuffer('${r.days}d');
    if (r.lopDays > 0) {
      tertiary.write(', ${r.lopDays} LOP');
    }
    return UnifiedApprovalItem(
      kind: UnifiedApprovalKind.leave,
      sourceId: r.id,
      employeeName: r.employee,
      employeeCode: r.employeeCode,
      department: r.department,
      secondaryText: r.department,
      typeLabel: r.leaveType.isNotEmpty ? r.leaveType : 'Leave',
      primaryLine: [r.leaveType, r.durationDisplay]
          .where((s) => s.isNotEmpty)
          .join(' · '),
      secondaryLine: '${r.from} – ${r.to}',
      tertiaryLine: tertiary.toString(),
      reason: r.reason,
      status: r.status,
      submittedAt: _parseDate(r.appliedOn),
      canAction: r.canApprove,
      leave: r,
    );
  }

  factory UnifiedApprovalItem.fromExpense(ExpenseModel e) {
    return UnifiedApprovalItem(
      kind: UnifiedApprovalKind.expense,
      sourceId: e.expenseNumber.toString(),
      employeeName: e.employeeName,
      employeeCode: '',
      department: '',
      secondaryText: e.branchName,
      typeLabel: 'Expense',
      primaryLine: e.title,
      secondaryLine: e.category,
      tertiaryLine: '₹${e.amount.toStringAsFixed(2)}',
      reason: e.description,
      status: e.status,
      submittedAt: _parseDate(e.createdAt),
      canAction: e.status == 'pending',
      expense: e,
    );
  }

  factory UnifiedApprovalItem.fromCorrection(HrCorrectionRowEntity c) {
    return UnifiedApprovalItem(
      kind: UnifiedApprovalKind.attendanceCorrection,
      sourceId: c.id,
      employeeName: c.name,
      employeeCode: c.employeeId,
      department: c.department,
      secondaryText: c.department,
      typeLabel: 'Attendance Correction',
      primaryLine: '${c.punchType} correction',
      secondaryLine: c.date,
      tertiaryLine: '${c.requestedInTime ?? '—'} → ${c.requestedOutTime ?? '—'}',
      reason: c.reason,
      status: c.status,
      submittedAt: _parseDate(c.createdAt),
      canAction: c.canAction,
      correction: c,
    );
  }

  factory UnifiedApprovalItem.fromWfh(WfhRequestEntity r) {
    final days = _inclusiveDays(r.startDate, r.endDate);
    return UnifiedApprovalItem(
      kind: UnifiedApprovalKind.wfh,
      sourceId: r.id,
      employeeName: r.employeeName,
      employeeCode: r.employeeCode,
      department: r.employeeDept,
      secondaryText: r.employeeBranch,
      typeLabel: 'WFH',
      primaryLine: r.locationLabel.isNotEmpty ? r.locationLabel : 'Work From Home',
      secondaryLine: '${r.startDate} – ${r.endDate}',
      tertiaryLine: '$days day${days == 1 ? '' : 's'}',
      reason: r.reason,
      status: r.status,
      submittedAt: _parseDate(r.createdAt),
      canAction: r.canApprove,
      wfh: r,
    );
  }
}

int _inclusiveDays(String startIso, String endIso) {
  final start = DateTime.tryParse(startIso);
  final end = DateTime.tryParse(endIso);
  if (start == null || end == null) return 0;
  return end.difference(start).inDays + 1;
}

DateTime _parseDate(String? iso) {
  if (iso == null || iso.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.tryParse(iso) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

// ── Unified fetch/action provider ───────────────────────────────────────────────

final unifiedTeamApprovalsProvider = AsyncNotifierProvider.autoDispose<
    UnifiedTeamApprovalsNotifier, List<UnifiedApprovalItem>>(
  UnifiedTeamApprovalsNotifier.new,
);

class UnifiedTeamApprovalsNotifier
    extends AutoDisposeAsyncNotifier<List<UnifiedApprovalItem>> {
  @override
  Future<List<UnifiedApprovalItem>> build() async {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final canLeave = user?.hasPermission('leave.approve') ?? false;
    final canExpense = user?.hasPermission('expenses.approve') ?? false;
    // attendance.create — matches the same permission web/mobile now use to
    // gate the Team Approvals tab itself (see approvals_screen.dart); an
    // approver without it shouldn't get a 403 from the corrections fetch.
    final canCorrection = user?.hasPermission('attendance.create') ?? false;
    // wfh.approve — mirrors leave.approve/expenses.approve exactly (backend
    // migration 0088 grants wfh.approve to the same roles that hold
    // leave.approve, so this is never a real-world mismatch). Deliberately
    // NOT OR'd with canManageTeam/isSuperuser here — passing scope=team
    // without the real wfh.approve permission makes the backend silently
    // fall back to the caller's OWN requests (see
    // WorkFromHomeRequestListCreateView.get), which would leak the viewer's
    // own rows into this "team" inbox instead of erroring.
    final canWfh = user?.hasPermission('wfh.approve') ?? false;

    final results = await Future.wait<dynamic>([
      canLeave
          ? ref.read(leaveRepositoryProvider).getLeaveRequests(
                // Fetch all statuses — the toolbar's own status filter
                // operates client-side, matching web's "fetch broad, filter
                // client-side" approach.
                status: null,
                scope: 'team',
                pageSize: 100,
              )
          : Future.value(<LeaveRequestEntity>[]),
      canExpense
          ? ref.read(expenseDataSourceProvider).fetchExpenses(
                status: null,
                pageSize: 100,
              )
          : Future.value(<ExpenseModel>[]),
      canCorrection
          // Explicit empty filter — deliberately bypasses whatever
          // branch/department filter is left set on the unrelated Attendance
          // screen, so those never silently hide rows from this inbox.
          ? ref.watch(hrCorrectionsProvider(
              (status: 'all', branch: null, department: null),
            ).future)
          : Future.value(<HrCorrectionRowEntity>[]),
      canWfh
          ? ref
              .read(wfhRepositoryProvider)
              .getWfhRequestsPaginated(scope: 'team', pageSize: 100)
              .then((page) => page.results)
          : Future.value(<WfhRequestEntity>[]),
    ]);

    final leaveItems = (results[0] as List<LeaveRequestEntity>)
        .map(UnifiedApprovalItem.fromLeave);
    final expenseItems = (results[1] as List<ExpenseModel>)
        .map(UnifiedApprovalItem.fromExpense);
    final correctionItems = (results[2] as List<HrCorrectionRowEntity>)
        .map(UnifiedApprovalItem.fromCorrection);
    final wfhItems = (results[3] as List<WfhRequestEntity>)
        .map(UnifiedApprovalItem.fromWfh);

    return [...leaveItems, ...expenseItems, ...correctionItems, ...wfhItems];
  }

  Future<void> refresh() async {
    ref.invalidate(hrCorrectionsProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> _dispatchApprove(UnifiedApprovalItem item, {String? remarks}) async {
    switch (item.kind) {
      case UnifiedApprovalKind.leave:
        await ref.read(leaveRepositoryProvider).approveLeave(item.sourceId);
        break;
      case UnifiedApprovalKind.expense:
        await ref
            .read(expenseDataSourceProvider)
            .updateExpenseStatus(int.parse(item.sourceId), 'approved');
        break;
      case UnifiedApprovalKind.attendanceCorrection:
        await ref.read(attendanceRepositoryProvider).reviewCorrection(
              item.sourceId,
              approve: true,
              remarks: remarks,
            );
        break;
      case UnifiedApprovalKind.wfh:
        await ref
            .read(wfhRepositoryProvider)
            .approveWfhRequest(item.sourceId, remarks: remarks);
        break;
    }
  }

  Future<void> _dispatchReject(UnifiedApprovalItem item, {required String remarks}) async {
    switch (item.kind) {
      case UnifiedApprovalKind.leave:
        await ref.read(leaveRepositoryProvider).rejectLeave(item.sourceId, remarks);
        break;
      case UnifiedApprovalKind.expense:
        await ref
            .read(expenseDataSourceProvider)
            .updateExpenseStatus(int.parse(item.sourceId), 'rejected');
        break;
      case UnifiedApprovalKind.attendanceCorrection:
        await ref.read(attendanceRepositoryProvider).reviewCorrection(
              item.sourceId,
              approve: false,
              remarks: remarks,
            );
        break;
      case UnifiedApprovalKind.wfh:
        await ref
            .read(wfhRepositoryProvider)
            .rejectWfhRequest(item.sourceId, remarks: remarks);
        break;
    }
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> approve(UnifiedApprovalItem item, {String? remarks}) async {
    try {
      await _dispatchApprove(item, remarks: remarks);
      await refresh();
      return null;
    } catch (e) {
      return friendlyApprovalsError(e);
    }
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> reject(UnifiedApprovalItem item, {required String remarks}) async {
    try {
      await _dispatchReject(item, remarks: remarks);
      await refresh();
      return null;
    } catch (e) {
      return friendlyApprovalsError(e);
    }
  }

  /// Partial-failure tolerant bulk action — mirrors web's Promise.allSettled
  /// pattern so one bad row doesn't abort the rest of the batch.
  Future<({int succeeded, int failed})> bulkAction(
    List<UnifiedApprovalItem> items, {
    required bool approve,
    String? remarks,
  }) async {
    final outcomes = await Future.wait(items.map((item) async {
      try {
        if (approve) {
          await _dispatchApprove(item, remarks: remarks);
        } else {
          await _dispatchReject(item, remarks: remarks ?? '');
        }
        return true;
      } catch (_) {
        return false;
      }
    }));
    await refresh();
    final succeeded = outcomes.where((ok) => ok).length;
    return (succeeded: succeeded, failed: outcomes.length - succeeded);
  }
}

// ── Screen-local filter / UI state ──────────────────────────────────────────────

enum ApprovalsTypeTab { all, leave, expense, attendanceCorrection, wfh }

UnifiedApprovalKind? _kindForTab(ApprovalsTypeTab tab) => switch (tab) {
      ApprovalsTypeTab.all => null,
      ApprovalsTypeTab.leave => UnifiedApprovalKind.leave,
      ApprovalsTypeTab.expense => UnifiedApprovalKind.expense,
      ApprovalsTypeTab.attendanceCorrection =>
        UnifiedApprovalKind.attendanceCorrection,
      ApprovalsTypeTab.wfh => UnifiedApprovalKind.wfh,
    };

final approvalsSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

// Matches web's default ("pending"). 'all' means no status filter.
final approvalsStatusFilterProvider = StateProvider.autoDispose<String>((ref) => 'pending');

final approvalsTypeTabProvider =
    StateProvider.autoDispose<ApprovalsTypeTab>((ref) => ApprovalsTypeTab.all);

final approvalsDateFromProvider = StateProvider.autoDispose<DateTime?>((ref) => null);
final approvalsDateToProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

// Bulk-select set of UnifiedApprovalItem.sourceId (kind-qualified — see
// approvalsItemKey below, since a leave id and a correction id could
// theoretically collide as raw UUID strings from different tables).
// Cleared whenever the type tab or status filter changes (matches web's
// "switching tabs clears selection") — watching those two providers inside
// this StateProvider's create callback makes it rebuild (and thus reset to
// the empty set) exactly when either of them changes.
final approvalsSelectedIdsProvider = StateProvider.autoDispose<Set<String>>((ref) {
  ref.watch(approvalsTypeTabProvider);
  ref.watch(approvalsStatusFilterProvider);
  return <String>{};
});

/// Stable identity for a [UnifiedApprovalItem] used as the bulk-select key —
/// qualified by kind so ids can't collide across the three source tables.
String approvalsItemKey(UnifiedApprovalItem item) => '${item.kind.name}:${item.sourceId}';

// ── Derived: filtered list the UI watches ───────────────────────────────────────

final filteredApprovalItemsProvider =
    Provider.autoDispose<AsyncValue<List<UnifiedApprovalItem>>>((ref) {
  final raw = ref.watch(unifiedTeamApprovalsProvider);
  final typeTab = ref.watch(approvalsTypeTabProvider);
  final status = ref.watch(approvalsStatusFilterProvider);
  final query = ref.watch(approvalsSearchQueryProvider).trim().toLowerCase();
  final dateFrom = ref.watch(approvalsDateFromProvider);
  final dateTo = ref.watch(approvalsDateToProvider);

  return raw.whenData((items) {
    final kindFilter = _kindForTab(typeTab);
    final from = dateFrom == null ? null : DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final to = dateTo == null
        ? null
        : DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59, 999);

    final filtered = items.where((item) {
      if (kindFilter != null && item.kind != kindFilter) return false;
      if (status != 'all' && item.status != status) return false;
      if (query.isNotEmpty) {
        final haystack = '${item.employeeName} ${item.employeeCode}'.toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      if (from != null && item.submittedAt.isBefore(from)) return false;
      if (to != null && item.submittedAt.isAfter(to)) return false;
      return true;
    }).toList();

    filtered.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return filtered;
  });
});

// ── Derived: summary counts (always from the RAW unfiltered fetch) ─────────────

class ApprovalsSummaryCounts {
  final int pendingTotal;
  final int leavePending;
  final int expensePending;
  final int correctionPending;
  final int wfhPending;
  const ApprovalsSummaryCounts({
    required this.pendingTotal,
    required this.leavePending,
    required this.expensePending,
    required this.correctionPending,
    required this.wfhPending,
  });
}

final approvalsSummaryCountsProvider = Provider.autoDispose<ApprovalsSummaryCounts>((ref) {
  final raw = ref.watch(unifiedTeamApprovalsProvider).valueOrNull ?? const [];
  int countFor(UnifiedApprovalKind kind) =>
      raw.where((i) => i.kind == kind && i.isPending).length;
  final leave = countFor(UnifiedApprovalKind.leave);
  final expense = countFor(UnifiedApprovalKind.expense);
  final correction = countFor(UnifiedApprovalKind.attendanceCorrection);
  final wfh = countFor(UnifiedApprovalKind.wfh);
  return ApprovalsSummaryCounts(
    pendingTotal: leave + expense + correction + wfh,
    leavePending: leave,
    expensePending: expense,
    correctionPending: correction,
    wfhPending: wfh,
  );
});

// Per-type-tab pending-count badges (same data as above, keyed by tab).
final approvalsTypeTabCountsProvider =
    Provider.autoDispose<Map<ApprovalsTypeTab, int>>((ref) {
  final counts = ref.watch(approvalsSummaryCountsProvider);
  return {
    ApprovalsTypeTab.all: counts.pendingTotal,
    ApprovalsTypeTab.leave: counts.leavePending,
    ApprovalsTypeTab.expense: counts.expensePending,
    ApprovalsTypeTab.attendanceCorrection: counts.correctionPending,
    ApprovalsTypeTab.wfh: counts.wfhPending,
  };
});

// ── Error helper ──────────────────────────────────────────────────────────────

String friendlyApprovalsError(Object e) {
  if (e is DioException) {
    final body = e.response?.data;
    if (body is Map) {
      final message = body['message'] ?? body['detail'];
      if (message is String && message.isNotEmpty) return message;
    }
    final statusCode = e.response?.statusCode;
    if (statusCode == 401) return 'Session expired. Please log in again.';
    if (statusCode == 403) return 'You do not have permission to do this.';
    if (statusCode == 409) return 'This request has already been actioned.';
    if (statusCode != null && statusCode >= 500) {
      return 'Server error. Please try again later.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach server. Check your connection.';
    }
  }
  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('connection')) {
    return 'Cannot reach server. Check your connection.';
  }
  return msg.replaceAll('Exception:', '').trim();
}
