import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../attendance/domain/entities/attendance_entity.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart'
    show myCorrectionsProvider;
import '../../../expenses/data/models/expense_model.dart';
import '../../../expenses/presentation/providers/expense_providers.dart'
    show expenseListProvider;
import '../../../leave/domain/entities/leave_entity.dart';
import '../../../leave/presentation/providers/leave_providers.dart'
    show leaveRequestsProvider;
import '../../../wfh/domain/entities/wfh_entity.dart';
import '../../../wfh/presentation/providers/wfh_providers.dart'
    show wfhMyRequestsProvider;

// Ports web's app/dashboard/my-requests/_client.tsx — there is no backend
// endpoint that aggregates a user's own requests across types (the closest
// thing, EmployeeRecentRequestsView, is a 5-row dashboard widget covering
// only leave/expense/attendance_correction, not a full paginated API). This
// composes the same 4 already-existing own-scoped list providers the Leave/
// WFH/Expenses/My-Attendance screens already use — leaveRequestsProvider,
// wfhMyRequestsProvider, expenseListProvider, myCorrectionsProvider — the
// same way approvals_providers.dart composes the team-scoped equivalents
// for the Team Approvals inbox. Watching those providers' `.future` (rather
// than reading the repository directly) means a cancel performed through
// leaveRequestsProvider/wfhMyRequestsProvider's own notifiers automatically
// flows through to this merged list with no manual invalidation needed.

// ── Unified item model (presentation-layer glue, not a clean-arch entity) ──────

enum MyRequestKind { leave, wfh, expense, attendanceCorrection }

enum MyRequestDisplayStatus { pending, approved, rejected, cancelled }

MyRequestDisplayStatus _displayStatus(String raw) => switch (raw) {
      'pending' || 'l2_pending' => MyRequestDisplayStatus.pending,
      'approved' => MyRequestDisplayStatus.approved,
      'rejected' => MyRequestDisplayStatus.rejected,
      _ => MyRequestDisplayStatus.cancelled,
    };

DateTime _parseDate(String? iso) {
  if (iso == null || iso.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.tryParse(iso) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class MyRequestItem {
  final MyRequestKind kind;
  final String sourceId;
  final String requestCode;
  final String title;
  final String detailSecondary;
  final DateTime submittedAt;
  final String status; // raw backend status
  final MyRequestDisplayStatus displayStatus;
  final String approver;
  final DateTime lastUpdated;
  final bool canCancel;

  // Raw source object — carried along so tapping a card can open the
  // matching feature's own existing detail widget without re-fetching.
  final LeaveRequestEntity? leave;
  final WfhRequestEntity? wfh;
  final ExpenseModel? expense;
  final MyCorrectionEntity? correction;

  const MyRequestItem({
    required this.kind,
    required this.sourceId,
    required this.requestCode,
    required this.title,
    required this.detailSecondary,
    required this.submittedAt,
    required this.status,
    required this.displayStatus,
    required this.approver,
    required this.lastUpdated,
    required this.canCancel,
    this.leave,
    this.wfh,
    this.expense,
    this.correction,
  });

  factory MyRequestItem.fromLeave(LeaveRequestEntity r) {
    final submitted = _parseDate(r.appliedOn);
    return MyRequestItem(
      kind: MyRequestKind.leave,
      sourceId: r.id,
      requestCode: 'LR-${r.id.length >= 6 ? r.id.substring(0, 6) : r.id}',
      title: r.leaveType.isNotEmpty ? r.leaveType : 'Leave',
      detailSecondary: '${r.from} – ${r.to} · ${r.days}d',
      submittedAt: submitted,
      status: r.status,
      displayStatus: _displayStatus(r.status),
      approver: r.approvedBy.isNotEmpty ? r.approvedBy : r.l1ApproverName,
      lastUpdated: _parseDate(r.approvedAt ?? r.l1ActionedAt ?? r.appliedOn),
      canCancel: r.canCancel,
      leave: r,
    );
  }

  factory MyRequestItem.fromWfh(WfhRequestEntity r) {
    return MyRequestItem(
      kind: MyRequestKind.wfh,
      sourceId: r.id,
      requestCode: 'WFH-${r.id.length >= 6 ? r.id.substring(0, 6) : r.id}',
      title: r.locationLabel.isNotEmpty ? r.locationLabel : 'Work From Home',
      detailSecondary: '${r.startDate} – ${r.endDate}',
      submittedAt: _parseDate(r.createdAt),
      status: r.status,
      displayStatus: _displayStatus(r.status),
      approver: r.l2ApproverName.isNotEmpty ? r.l2ApproverName : r.l1ApproverName,
      lastUpdated: _parseDate(r.l2ActionedAt ?? r.l1ActionedAt ?? r.createdAt),
      canCancel: r.canCancel,
      wfh: r,
    );
  }

  factory MyRequestItem.fromExpense(ExpenseModel e) {
    return MyRequestItem(
      kind: MyRequestKind.expense,
      sourceId: e.expenseNumber.toString(),
      requestCode: e.expenseRef,
      title: e.title,
      detailSecondary: '₹${e.amount.toStringAsFixed(2)}',
      submittedAt: _parseDate(e.createdAt),
      status: e.status,
      displayStatus: _displayStatus(e.status),
      approver: '—', // not exposed by ExpenseSerializer — matches web's My Requests, which hardcodes this too
      lastUpdated: _parseDate(e.createdAt),
      canCancel: false, // no employee-side cancel/withdraw endpoint exists for expenses
      expense: e,
    );
  }

  factory MyRequestItem.fromCorrection(MyCorrectionEntity c) {
    final label = switch (c.punchType) {
      'IN' => 'Check-in Correction',
      'OUT' => 'Check-out Correction',
      _ => 'Check-in & Check-out Correction',
    };
    return MyRequestItem(
      kind: MyRequestKind.attendanceCorrection,
      sourceId: c.id,
      requestCode: 'AC-${c.id.length >= 6 ? c.id.substring(0, 6) : c.id}',
      title: label,
      detailSecondary: '${c.date} · ${c.punchType}',
      submittedAt: _parseDate(c.createdAt),
      status: c.status,
      displayStatus: _displayStatus(c.status),
      approver: (c.l2ApproverName?.isNotEmpty ?? false) ? c.l2ApproverName! : (c.l1ApproverName ?? ''),
      lastUpdated: _parseDate(c.reviewedAt ?? c.createdAt),
      canCancel: false, // no withdraw endpoint exists for attendance corrections
      correction: c,
    );
  }
}

// ── Unified fetch provider ──────────────────────────────────────────────────────

final myRequestsProvider =
    AsyncNotifierProvider.autoDispose<MyRequestsNotifier, List<MyRequestItem>>(
  MyRequestsNotifier.new,
);

class MyRequestsNotifier extends AutoDisposeAsyncNotifier<List<MyRequestItem>> {
  @override
  Future<List<MyRequestItem>> build() async {
    final results = await Future.wait<dynamic>([
      ref.watch(leaveRequestsProvider.future),
      ref.watch(wfhMyRequestsProvider.future),
      ref.watch(expenseListProvider.future),
      ref.watch(myCorrectionsProvider.future),
    ]);

    final items = <MyRequestItem>[
      ...(results[0] as List<LeaveRequestEntity>).map(MyRequestItem.fromLeave),
      ...(results[1] as List<WfhRequestEntity>).map(MyRequestItem.fromWfh),
      ...(results[2] as List<ExpenseModel>).map(MyRequestItem.fromExpense),
      ...(results[3] as List<MyCorrectionEntity>).map(MyRequestItem.fromCorrection),
    ];
    items.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items;
  }

  Future<void> refresh() async {
    ref.invalidate(leaveRequestsProvider);
    ref.invalidate(wfhMyRequestsProvider);
    ref.invalidate(expenseListProvider);
    ref.invalidate(myCorrectionsProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  /// Returns null on success, or a user-facing error message on failure.
  /// Only leave/WFH support cancel — dispatches to the SAME notifiers the
  /// Leave/WFH screens themselves use, so their own list state (and, via the
  /// `.future` watches above, this merged list) stays in sync automatically.
  Future<String?> cancel(MyRequestItem item) {
    switch (item.kind) {
      case MyRequestKind.leave:
        return ref.read(leaveRequestsProvider.notifier).cancelRequest(item.sourceId);
      case MyRequestKind.wfh:
        return ref.read(wfhMyRequestsProvider.notifier).cancelRequest(item.sourceId);
      case MyRequestKind.expense:
      case MyRequestKind.attendanceCorrection:
        return Future.value('This request type cannot be cancelled.');
    }
  }
}

// ── Screen-local filter / UI state ──────────────────────────────────────────────

enum MyRequestsTypeTab { all, leave, wfh, expense, attendanceCorrection }

MyRequestKind? kindForMyRequestsTab(MyRequestsTypeTab tab) => switch (tab) {
      MyRequestsTypeTab.all => null,
      MyRequestsTypeTab.leave => MyRequestKind.leave,
      MyRequestsTypeTab.wfh => MyRequestKind.wfh,
      MyRequestsTypeTab.expense => MyRequestKind.expense,
      MyRequestsTypeTab.attendanceCorrection => MyRequestKind.attendanceCorrection,
    };

final myRequestsSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

// 'all' means no status filter; otherwise matches a MyRequestDisplayStatus.name.
final myRequestsStatusFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');

final myRequestsTypeTabProvider =
    StateProvider.autoDispose<MyRequestsTypeTab>((ref) => MyRequestsTypeTab.all);

final myRequestsDateFromProvider = StateProvider.autoDispose<DateTime?>((ref) => null);
final myRequestsDateToProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

// ── Derived: filtered list the UI watches ───────────────────────────────────────

final filteredMyRequestItemsProvider =
    Provider.autoDispose<AsyncValue<List<MyRequestItem>>>((ref) {
  final raw = ref.watch(myRequestsProvider);
  final typeTab = ref.watch(myRequestsTypeTabProvider);
  final status = ref.watch(myRequestsStatusFilterProvider);
  final query = ref.watch(myRequestsSearchQueryProvider).trim().toLowerCase();
  final dateFrom = ref.watch(myRequestsDateFromProvider);
  final dateTo = ref.watch(myRequestsDateToProvider);

  return raw.whenData((items) {
    final kindFilter = kindForMyRequestsTab(typeTab);
    final from = dateFrom == null ? null : DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final to = dateTo == null
        ? null
        : DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59, 999);

    final filtered = items.where((item) {
      if (kindFilter != null && item.kind != kindFilter) return false;
      if (status != 'all' && item.displayStatus.name != status) return false;
      if (query.isNotEmpty) {
        final haystack = '${item.title} ${item.requestCode}'.toLowerCase();
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

// Per-type-tab counts (always from the RAW unfiltered fetch, matching
// approvalsTypeTabCountsProvider's pattern).
final myRequestsTypeTabCountsProvider =
    Provider.autoDispose<Map<MyRequestsTypeTab, int>>((ref) {
  final raw = ref.watch(myRequestsProvider).valueOrNull ?? const <MyRequestItem>[];
  int countFor(MyRequestKind? kind) =>
      kind == null ? raw.length : raw.where((i) => i.kind == kind).length;
  return {
    MyRequestsTypeTab.all: countFor(null),
    MyRequestsTypeTab.leave: countFor(MyRequestKind.leave),
    MyRequestsTypeTab.wfh: countFor(MyRequestKind.wfh),
    MyRequestsTypeTab.expense: countFor(MyRequestKind.expense),
    MyRequestsTypeTab.attendanceCorrection: countFor(MyRequestKind.attendanceCorrection),
  };
});
