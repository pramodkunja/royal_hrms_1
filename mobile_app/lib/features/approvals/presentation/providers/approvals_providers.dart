import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/formatters/en_in_format.dart';
import '../../../attendance/domain/entities/attendance_entity.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart'
    show attendanceRepositoryProvider, hrCorrectionsProvider, kLateJustificationNeedsReview;
import '../../../../core/router/access_control.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../expenses/presentation/providers/expense_providers.dart'
    show expenseDataSourceProvider;
import '../../../leave/domain/entities/leave_entity.dart';
import '../../../payroll/data/models/payslip_query_model.dart';
import '../../../payroll/presentation/providers/payroll_providers.dart'
    show payrollDataSourceProvider;
import '../../../separation/domain/entities/separation_entity.dart';
import '../../../separation/presentation/providers/separation_providers.dart'
    show separationRepositoryProvider;
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

enum UnifiedApprovalKind { leave, expense, attendanceCorrection, wfh, separation, payslip }

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
  final SeparationRequestEntity? separation;
  final PayslipQueryModel? payslipQuery;

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
    this.separation,
    this.payslipQuery,
  });

  /// Separation is a multi-stage workflow decided stage by stage on its own
  /// detail screen (web: TeamApprovalsSection routes it to
  /// /dashboard/separation/<id> and excludes it from bulk selection) — no
  /// quick approve/reject or bulk action from the inbox.
  bool get opensDetailScreen => kind == UnifiedApprovalKind.separation;

  /// A payslip query has one action — resolve, with a note — not
  /// approve/reject (web TeamApprovalsSection opens ResolveQueryModal).
  bool get isPayslipQuery => kind == UnifiedApprovalKind.payslip;

  /// Web UNSELECTABLE_KINDS: separation and payslip queries are never bulk
  /// actioned.
  bool get selectable => !opensDetailScreen && !isPayslipQuery && !isLateJustification;

  /// A late-arrival justification (an attendance correction of kind
  /// late_justification) is decided in its own review — a reason is required
  /// to reject or send back, which a quick or bulk action can't give (web
  /// opens LateJustificationReviewModal for it). Mobile also keeps it out of
  /// bulk selection, where web would send no reason and the server refuse.
  bool get isLateJustification => correction?.isLateJustification ?? false;

  /// Web payslipToItem: the HR queue row for a payslip query. [canResolve]
  /// is the viewer's payroll.edit; the server returns only open queries,
  /// shown as pending ("resolved" maps to approved, as on web).
  factory UnifiedApprovalItem.fromPayslipQuery(PayslipQueryModel q, {required bool canResolve}) {
    final text = q.description.replaceAll(RegExp(r'\s+'), ' ').trim();
    final preview = text.length > 140 ? '${text.substring(0, 140)}…' : text;
    final raised = q.createdAt.length >= 10 ? q.createdAt.substring(0, 10) : q.createdAt;
    return UnifiedApprovalItem(
      kind: UnifiedApprovalKind.payslip,
      sourceId: q.id,
      employeeName: q.raisedByName,
      employeeCode: q.employeeIdCode ?? '',
      department: '',
      secondaryText: '',
      typeLabel: 'Payslip Request',
      primaryLine: q.cycleStart == null || q.cycleStart!.isEmpty
          ? 'Payslip Query'
          : 'Payslip Query · pay period from ${q.cycleStart}',
      secondaryLine: preview.isEmpty ? '—' : preview,
      tertiaryLine: raised.isEmpty ? '' : 'Raised $raised',
      reason: q.description,
      status: q.isResolved ? 'approved' : 'pending',
      submittedAt: _parseDate(q.createdAt),
      canAction: !q.isResolved && canResolve,
      payslipQuery: q,
    );
  }

  /// Web separationToItem: the request's server-computed can_approve (some
  /// stage this user may act on now), with the request's own fields.
  factory UnifiedApprovalItem.fromSeparation(SeparationRequestEntity r) => UnifiedApprovalItem(
        kind: UnifiedApprovalKind.separation,
        sourceId: r.id,
        employeeName: r.employeeName,
        employeeCode: r.employeeCode,
        department: r.employeeDepartment,
        secondaryText: r.requestRef,
        typeLabel: 'Separation',
        primaryLine: r.separationTypeDisplay,
        secondaryLine: 'Last day: ${approvalsDate(r.proposedLastWorkingDay)}',
        tertiaryLine: r.reasonDisplay,
        reason: r.comments,
        // Both open stages (pending, stage2_pending) are "pending" in the
        // inbox, as web's toDisplayStatus shows them.
        status: (r.status == 'pending' || r.status == 'stage2_pending') ? 'pending' : r.status,
        submittedAt: _parseDate(r.createdAt),
        canAction: r.canApprove,
        separation: r,
      );

  /// The label/value facts the card shows under the request-type row — only
  /// what the web row / drawer carries for this kind (no invented fields).
  List<(String, String)> get facts => switch (kind) {
        UnifiedApprovalKind.leave => [('Dates', secondaryLine), ('Duration', tertiaryLine)],
        UnifiedApprovalKind.wfh => [('Dates', secondaryLine), ('Duration', tertiaryLine)],
        UnifiedApprovalKind.expense => [('Amount', secondaryLine), if (tertiaryLine.isNotEmpty) ('Category', tertiaryLine)],
        UnifiedApprovalKind.attendanceCorrection => [
            ('Date', tertiaryLine),
            (isLateJustification ? 'Details' : 'Time change', secondaryLine),
          ],
        UnifiedApprovalKind.separation => [
            ('Last working day', secondaryLine.replaceFirst('Last day: ', '')),
            if (tertiaryLine.isNotEmpty) ('Reason', tertiaryLine),
          ],
        UnifiedApprovalKind.payslip => [('Query', secondaryLine)],
      };

  /// Web approvals/_data.ts toDisplayStatus: the status the inbox filters,
  /// counts and gates actions on. Both approval levels read as pending.
  String get displayStatus => approvalDisplayStatus(status);

  /// Web: actions only while the display status is pending (and the server
  /// says canAction). `resubmit` (late justification sent back to the
  /// employee) is not pending, as on web.
  bool get isPending => displayStatus == 'pending';

  factory UnifiedApprovalItem.fromLeave(LeaveRequestEntity r) {
    final tertiary = StringBuffer(_days(r.days));
    if (r.lopDays > 0) {
      tertiary.write(' · ${approvalsNumber(r.lopDays)} LOP');
    }
    return UnifiedApprovalItem(
      kind: UnifiedApprovalKind.leave,
      sourceId: r.id,
      employeeName: r.employee,
      employeeCode: r.employeeCode,
      department: r.department,
      secondaryText: r.department,
      typeLabel: 'Leave',
      primaryLine: [r.leaveType, r.durationDisplay]
          .where((s) => s.isNotEmpty)
          .join(' · '),
      secondaryLine: '${approvalsDate(r.from)} - ${approvalsDate(r.to)}',
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
      primaryLine: e.title.isNotEmpty ? e.title : 'Expense',
      secondaryLine: formatMoney(e.amount),
      tertiaryLine: e.category,
      reason: e.description,
      status: e.status,
      submittedAt: _parseDate(e.createdAt),
      canAction: e.status == 'pending',
      expense: e,
    );
  }

  factory UnifiedApprovalItem.fromCorrection(HrCorrectionRowEntity c) {
    if (c.isLateJustification) {
      // Web TeamApprovalsSection detailPrimary / detailSecondary for kind late.
      final reason = c.reasonLabel.isNotEmpty ? c.reasonLabel : c.reason;
      return UnifiedApprovalItem(
        kind: UnifiedApprovalKind.attendanceCorrection,
        sourceId: c.id,
        employeeName: c.name,
        employeeCode: c.employeeId,
        department: c.department,
        secondaryText: c.department,
        typeLabel: 'Attendance Correction',
        primaryLine: 'Late Arrival Justification',
        secondaryLine: '$reason${c.hasDocument ? ' · proof attached' : ''} · clocked in ${approvalsTime12(c.originalIn)}',
        tertiaryLine: approvalsDate(c.date),
        reason: c.explanation.isNotEmpty ? c.explanation : reason,
        status: c.status,
        submittedAt: _parseDate(c.createdAt),
        canAction: c.canAction,
        correction: c,
      );
    }
    return UnifiedApprovalItem(
      kind: UnifiedApprovalKind.attendanceCorrection,
      sourceId: c.id,
      employeeName: c.name,
      employeeCode: c.employeeId,
      department: c.department,
      secondaryText: c.department,
      typeLabel: 'Attendance Correction',
      primaryLine: approvalsPunchLabel(c.punchType),
      secondaryLine: [
        if (c.punchType != 'OUT') '${approvalsTime12(c.originalIn)} → ${approvalsTime12(c.requestedInTime)}',
        if (c.punchType != 'IN') '${approvalsTime12(c.originalOut)} → ${approvalsTime12(c.requestedOutTime)}',
      ].join('  ·  '),
      tertiaryLine: approvalsDate(c.date),
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
      typeLabel: 'Work From Home',
      primaryLine: 'Work From Home',
      secondaryLine: '${approvalsDate(r.startDate)} - ${approvalsDate(r.endDate)}',
      tertiaryLine: _days(days),
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

/// Web leave/_data.ts fmtDate (en-IN, numeric day): "5 Sept 2026"; "—" when empty.
String approvalsDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  return d == null ? iso : formatEnInDate(d);
}

/// Web approvals/_data.ts fmtSubmitted (en-IN, 2-digit day): "05 Sept 2026".
String approvalsSubmitted(DateTime d) => d.millisecondsSinceEpoch == 0 ? '—' : formatEnInDate(d, padDay: true);

/// Web approvals/_data.ts fmtTime12h: "09:30 AM"; "—" when empty.
String approvalsTime12(String? hhmm) {
  if (hhmm == null || hhmm.isEmpty) return '—';
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.first);
  if (h == null) return hhmm;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '${h12.toString().padLeft(2, '0')}:${parts.length > 1 ? parts[1] : '00'} ${h >= 12 ? 'PM' : 'AM'}';
}

/// 1.0 → "1", 0.5 → "0.5" (how JS prints a number).
String approvalsNumber(num n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';

String _days(int n) => '$n Day${n == 1 ? '' : 's'}';

/// Web PUNCH_LABEL.
String approvalsPunchLabel(String punchType) => switch (punchType) {
      'IN' => 'Check-in Correction',
      'OUT' => 'Check-out Correction',
      'BOTH' => 'Check-in & Check-out Correction',
      _ => 'Attendance Correction',
    };

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
    // Web TeamApprovalsSection: a kind is fetched only when its module is on
    // (KIND_MODULES); unknown module list → all. Each kind also needs its
    // approve permission by the backend's has_perm rule (superuser /
    // settings.edit or the permission — userHasPermission), so an admin gets
    // the same team queue the server gives them (Task 71 H1).
    final canLeave = userHasPermission(user, 'leave.approve') && userHasModule(user, AppModules.leave);
    final canExpense = userHasPermission(user, 'expenses.approve') && userHasModule(user, AppModules.expenses);
    // attendance.create — matches the same permission web/mobile now use to
    // gate the Team Approvals tab itself (see approvals_screen.dart); an
    // approver without it shouldn't get a 403 from the corrections fetch.
    final canCorrection = userHasPermission(user, 'attendance.create') && userHasModule(user, AppModules.attendance);
    // wfh.approve — mirrors leave.approve/expenses.approve exactly (backend
    // migration 0088 grants wfh.approve to the same roles that hold
    // leave.approve, so this is never a real-world mismatch). Not OR'd with
    // canManageTeam: passing scope=team without wfh.approve (by the backend's
    // has_perm, which superuser / settings.edit pass) makes the backend
    // silently fall back to the caller's OWN requests (see
    // WorkFromHomeRequestListCreateView.get), which would leak the viewer's
    // own rows into this "team" inbox instead of erroring.
    final canWfh = userHasPermission(user, 'wfh.approve') && userHasModule(user, AppModules.wfh);
    // separation.approve — the backend's team queue (_approval_scope_filter:
    // direct reports for a team manager, the branch for HR/Branch Admin,
    // everyone for settings.edit). Without it, scope=team silently returns
    // the caller's OWN requests, so it is not asked for at all.
    final canSeparation = userHasPermission(user, 'separation.approve') && userHasModule(user, AppModules.separation);
    // payroll.view — web TeamApprovalsSection fetches the HR payslip-query
    // queue only for it: without it, GET /payroll/queries/ returns the
    // caller's OWN queries, which must never appear in a team inbox.
    // payroll.edit decides whether a query can be resolved.
    final canPayslipQueries = userHasPermission(user, 'payroll.view') && userHasModule(user, AppModules.payroll);
    final canResolvePayslip = userHasPermission(user, 'payroll.edit');

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
      canSeparation
          ? ref
              .read(separationRepositoryProvider)
              .getRequests(scope: 'team', pageSize: 100)
              .then((page) => page.results)
          : Future.value(<SeparationRequestEntity>[]),
      canPayslipQueries
          ? ref.read(payrollDataSourceProvider).fetchTeamQueries()
          : Future.value(<PayslipQueryModel>[]),
    ]);

    final leaveItems = (results[0] as List<LeaveRequestEntity>)
        .map(UnifiedApprovalItem.fromLeave);
    final expenseItems = (results[1] as List<ExpenseModel>)
        .map(UnifiedApprovalItem.fromExpense);
    final correctionItems = (results[2] as List<HrCorrectionRowEntity>)
        .map(UnifiedApprovalItem.fromCorrection);
    final wfhItems = (results[3] as List<WfhRequestEntity>)
        .map(UnifiedApprovalItem.fromWfh);

    final separationItems = (results[4] as List<SeparationRequestEntity>)
        .map(UnifiedApprovalItem.fromSeparation);

    final payslipItems = (results[5] as List<PayslipQueryModel>)
        .map((q) => UnifiedApprovalItem.fromPayslipQuery(q, canResolve: canResolvePayslip));

    return [...leaveItems, ...expenseItems, ...correctionItems, ...wfhItems, ...separationItems, ...payslipItems];
  }

  /// Reloads the inbox. The rows already on screen stay put while it loads (and
  /// after a failed reload, with the error alongside) — nothing is blanked or
  /// guessed before the server answers.
  Future<void> refresh() async {
    ref.invalidate(hrCorrectionsProvider);
    final previous = state;
    state = const AsyncLoading<List<UnifiedApprovalItem>>().copyWithPrevious(previous);
    try {
      state = AsyncData(await build());
    } catch (e, st) {
      state = AsyncError<List<UnifiedApprovalItem>>(e, st).copyWithPrevious(previous);
    }
  }

  Future<void> _dispatchApprove(UnifiedApprovalItem item, {String? remarks}) async {
    switch (item.kind) {
      case UnifiedApprovalKind.leave:
        // Task 81 (APR-08): the approver's remarks reach the backend
        // (l1_remarks / l2_remarks), as web sends them — they were dropped.
        await ref.read(leaveRepositoryProvider).approveLeave(item.sourceId, remarks: remarks ?? '');
        break;
      case UnifiedApprovalKind.expense:
        await ref
            .read(expenseDataSourceProvider)
            .updateExpenseStatus(int.parse(item.sourceId), 'approved');
        break;
      case UnifiedApprovalKind.attendanceCorrection:
        if (item.isLateJustification) throw StateError(kLateJustificationNeedsReview);
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
      case UnifiedApprovalKind.separation:
        // Decided per stage on the separation detail screen only.
        throw StateError('Separation requests are approved stage by stage on their detail screen.');
      case UnifiedApprovalKind.payslip:
        throw StateError('Payslip queries are resolved with a note, not approved.');
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
        if (item.isLateJustification) throw StateError(kLateJustificationNeedsReview);
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
      case UnifiedApprovalKind.separation:
        throw StateError('Separation requests are rejected stage by stage on their detail screen.');
      case UnifiedApprovalKind.payslip:
        throw StateError('Payslip queries are resolved with a note, not rejected.');
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

  /// Resolves a payslip query with [note] (web ResolveQueryModal). The
  /// query is only shown as resolved once the server confirms it and the
  /// inbox reloads. Returns null on success, or the message to show.
  Future<String?> resolvePayslipQuery(UnifiedApprovalItem item, String note) async {
    final text = note.trim();
    if (text.isEmpty) return kResolutionNoteRequired;
    try {
      await ref.read(payrollDataSourceProvider).resolveQuery(item.sourceId, resolutionNote: text);
    } catch (e) {
      return friendlyApprovalsError(e);
    }
    await refresh();
    return null;
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

/// Web TYPE_TABS order: All, Leave, Work From Home, Expense, Attendance Correction,
/// Payslip Requests, Separation.
enum ApprovalsTypeTab { all, leave, wfh, expense, attendanceCorrection, payslip, separation }

/// Web KIND_MODULES: the module a type tab belongs to (All → none).
String? moduleForApprovalsTab(ApprovalsTypeTab tab) => switch (tab) {
      ApprovalsTypeTab.all => null,
      ApprovalsTypeTab.leave => AppModules.leave,
      ApprovalsTypeTab.expense => AppModules.expenses,
      ApprovalsTypeTab.attendanceCorrection => AppModules.attendance,
      ApprovalsTypeTab.wfh => AppModules.wfh,
      ApprovalsTypeTab.separation => AppModules.separation,
      ApprovalsTypeTab.payslip => AppModules.payroll,
    };

UnifiedApprovalKind? _kindForTab(ApprovalsTypeTab tab) => switch (tab) {
      ApprovalsTypeTab.all => null,
      ApprovalsTypeTab.leave => UnifiedApprovalKind.leave,
      ApprovalsTypeTab.expense => UnifiedApprovalKind.expense,
      ApprovalsTypeTab.attendanceCorrection =>
        UnifiedApprovalKind.attendanceCorrection,
      ApprovalsTypeTab.wfh => UnifiedApprovalKind.wfh,
      ApprovalsTypeTab.separation => UnifiedApprovalKind.separation,
      ApprovalsTypeTab.payslip => UnifiedApprovalKind.payslip,
    };

/// Mobile selection mode for bulk actions: on, every selectable card shows a
/// checkbox and tapping a card selects it; off, cards open their details.
/// Long-pressing a card turns it on. Switching type tab turns it off.
final approvalsSelectionModeProvider = StateProvider.autoDispose<bool>((ref) {
  ref.watch(approvalsTypeTabProvider);
  return false;
});

final approvalsSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

// Matches web's default ("pending"). 'all' means no status filter.
final approvalsStatusFilterProvider = StateProvider.autoDispose<String>((ref) => 'pending');

final approvalsTypeTabProvider =
    StateProvider.autoDispose<ApprovalsTypeTab>((ref) => ApprovalsTypeTab.all);

final approvalsDateFromProvider = StateProvider.autoDispose<DateTime?>((ref) => null);

/// Web ApprovalsTable sort: Employee / Submitted Date / Status, default
/// Submitted Date, newest first.
enum ApprovalsSortKey { employee, submitted, status }

final approvalsSortKeyProvider = StateProvider.autoDispose<ApprovalsSortKey>((ref) => ApprovalsSortKey.submitted);
final approvalsSortDescProvider = StateProvider.autoDispose<bool>((ref) => true);

/// Back to the default view: Pending, no search, no dates, newest first.
void clearApprovalsFilters(WidgetRef ref) {
  ref.read(approvalsStatusFilterProvider.notifier).state = 'pending';
  ref.read(approvalsSearchQueryProvider.notifier).state = '';
  ref.read(approvalsDateFromProvider.notifier).state = null;
  ref.read(approvalsDateToProvider.notifier).state = null;
  ref.read(approvalsSortKeyProvider.notifier).state = ApprovalsSortKey.submitted;
  ref.read(approvalsSortDescProvider.notifier).state = true;
}

/// Web handleSort: the same key flips the direction; a new key starts ascending.
void approvalsSortBy(WidgetRef ref, ApprovalsSortKey key) {
  if (ref.read(approvalsSortKeyProvider) == key) {
    ref.read(approvalsSortDescProvider.notifier).state = !ref.read(approvalsSortDescProvider);
  } else {
    ref.read(approvalsSortKeyProvider.notifier).state = key;
    ref.read(approvalsSortDescProvider.notifier).state = false;
  }
}

/// Current page (1-based). Back to 1 whenever the tab, status, search, dates or
/// sort change (web ApprovalsTable resetKey).
final approvalsPageProvider = StateProvider.autoDispose<int>((ref) {
  ref.watch(approvalsTypeTabProvider);
  ref.watch(approvalsStatusFilterProvider);
  ref.watch(approvalsSearchQueryProvider);
  ref.watch(approvalsDateFromProvider);
  ref.watch(approvalsDateToProvider);
  ref.watch(approvalsSortKeyProvider);
  ref.watch(approvalsSortDescProvider);
  return 1;
});
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

/// Task 80: web approvals/_data.ts toDisplayStatus. The inbox's Pending
/// filter, counts and action gating use this, not the raw backend status:
/// `pending` (level 1), `l2_pending` (level 2 — leave, WFH, attendance
/// correction) and `stage2_pending` (separation) are all "pending";
/// `approved` and `rejected` as they are; anything else (cancelled,
/// resubmit, …) is "cancelled" and appears only under All.
String approvalDisplayStatus(String status) => switch (status) {
      'pending' || 'l2_pending' || 'stage2_pending' => 'pending',
      'approved' => 'approved',
      'rejected' => 'rejected',
      _ => 'cancelled',
    };

// ── Derived: filtered list the UI watches ───────────────────────────────────────

final filteredApprovalItemsProvider =
    Provider.autoDispose<AsyncValue<List<UnifiedApprovalItem>>>((ref) {
  final raw = ref.watch(unifiedTeamApprovalsProvider);
  final typeTab = ref.watch(approvalsTypeTabProvider);
  final status = ref.watch(approvalsStatusFilterProvider);
  final query = ref.watch(approvalsSearchQueryProvider).trim().toLowerCase();
  final dateFrom = ref.watch(approvalsDateFromProvider);
  final dateTo = ref.watch(approvalsDateToProvider);

  // The rows already loaded stay available while a reload runs or after one
  // fails (the error rides alongside) — AsyncValue.whenData would drop them.
  List<UnifiedApprovalItem> filterItems(List<UnifiedApprovalItem> items) {
    final kindFilter = _kindForTab(typeTab);
    final from = dateFrom == null ? null : DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final to = dateTo == null
        ? null
        : DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59, 999);

    final filtered = items.where((item) {
      if (kindFilter != null && item.kind != kindFilter) return false;
      // Display status, as web — the raw status hid every level-2 row
      // (`l2_pending`) under the default Pending filter (Task 80).
      if (status != 'all' && item.displayStatus != status) return false;
      if (query.isNotEmpty) {
        final haystack = '${item.employeeName} ${item.employeeCode}'.toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      if (from != null && item.submittedAt.isBefore(from)) return false;
      if (to != null && item.submittedAt.isAfter(to)) return false;
      return true;
    }).toList();

    final key = ref.watch(approvalsSortKeyProvider);
    final desc = ref.watch(approvalsSortDescProvider);
    filtered.sort((a, b) {
      final cmp = switch (key) {
        ApprovalsSortKey.employee => a.employeeName.toLowerCase().compareTo(b.employeeName.toLowerCase()),
        ApprovalsSortKey.status => a.displayStatus.compareTo(b.displayStatus),
        ApprovalsSortKey.submitted => a.submittedAt.compareTo(b.submittedAt),
      };
      return desc ? -cmp : cmp;
    });
    return filtered;
  }

  final loaded = raw.valueOrNull;
  if (loaded == null) {
    return raw.whenData(filterItems); // loading / error with nothing to show yet
  }
  final data = AsyncData(filterItems(loaded));
  if (raw.hasError) {
    return AsyncError<List<UnifiedApprovalItem>>(raw.error!, raw.stackTrace ?? StackTrace.empty).copyWithPrevious(data);
  }
  if (raw.isLoading) return const AsyncLoading<List<UnifiedApprovalItem>>().copyWithPrevious(data);
  return data;
});

// ── Derived: summary counts (always from the RAW unfiltered fetch) ─────────────

class ApprovalsSummaryCounts {
  final int pendingTotal;
  final int leavePending;
  final int expensePending;
  final int correctionPending;
  final int wfhPending;
  final int separationPending;
  final int payslipPending;
  const ApprovalsSummaryCounts({
    required this.pendingTotal,
    required this.leavePending,
    required this.expensePending,
    required this.correctionPending,
    required this.wfhPending,
    this.separationPending = 0,
    this.payslipPending = 0,
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
  final separation = countFor(UnifiedApprovalKind.separation);
  final payslip = countFor(UnifiedApprovalKind.payslip);
  return ApprovalsSummaryCounts(
    pendingTotal: leave + expense + correction + wfh + separation + payslip,
    leavePending: leave,
    expensePending: expense,
    correctionPending: correction,
    wfhPending: wfh,
    separationPending: separation,
    payslipPending: payslip,
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
    ApprovalsTypeTab.separation: counts.separationPending,
    ApprovalsTypeTab.payslip: counts.payslipPending,
  };
});

/// Web TeamApprovalsSection toast for a single approve / reject.
String approvalSuccessMessage(UnifiedApprovalItem item, {required bool approve}) => switch (item.kind) {
      UnifiedApprovalKind.attendanceCorrection =>
        approve ? 'Correction approved. Attendance record updated.' : 'Correction rejected.',
      UnifiedApprovalKind.wfh =>
        approve ? 'Work from home request approved.' : 'Work from home request rejected.',
      _ => approve ? 'Request approved.' : 'Request rejected.',
    };

/// Web handleBulkConfirm toast.
String approvalsBulkMessage({required int succeeded, required int failed, required bool approve}) {
  final verb = approve ? 'approved' : 'rejected';
  return failed == 0
      ? '$succeeded request${succeeded == 1 ? '' : 's'} $verb.'
      : '$succeeded $verb, $failed failed — please retry those individually.';
}

/// Web ResolveQueryModal's message for an empty note.
const kResolutionNoteRequired = 'Please enter a resolution note.';

// ── Error helper ──────────────────────────────────────────────────────────────

String friendlyApprovalsError(Object e) {
  if (e is StateError) return e.message;
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
