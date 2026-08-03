import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/leave_remote_datasource.dart';
import '../../data/repositories/leave_repository_impl.dart';
import '../../domain/entities/leave_entity.dart';
import '../../domain/repositories/leave_repository.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final leaveDataSourceProvider = Provider<LeaveRemoteDataSource>((ref) {
  return LeaveRemoteDataSource(ref.watch(dioProvider));
});

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepositoryImpl(ref.watch(leaveDataSourceProvider));
});

// ── Leave Types ───────────────────────────────────────────────────────────────

final leaveTypesProvider = AsyncNotifierProvider.autoDispose<LeaveTypesNotifier,
    List<LeaveTypeEntity>>(LeaveTypesNotifier.new);

class LeaveTypesNotifier
    extends AutoDisposeAsyncNotifier<List<LeaveTypeEntity>> {
  @override
  Future<List<LeaveTypeEntity>> build() =>
      ref.read(leaveRepositoryProvider).getLeaveTypes();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(leaveRepositoryProvider).getLeaveTypes());
  }
}

// ── Leave Balances ────────────────────────────────────────────────────────────

final leaveBalancesProvider = AsyncNotifierProvider.autoDispose<
    LeaveBalancesNotifier, List<LeaveBalanceEntity>>(LeaveBalancesNotifier.new);

class LeaveBalancesNotifier
    extends AutoDisposeAsyncNotifier<List<LeaveBalanceEntity>> {
  @override
  Future<List<LeaveBalanceEntity>> build() =>
      ref.read(leaveRepositoryProvider).getLeaveBalances();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(leaveRepositoryProvider).getLeaveBalances());
  }
}

// ── Leave Stats ───────────────────────────────────────────────────────────────

final leaveStatsProvider =
    AsyncNotifierProvider.autoDispose<LeaveStatsNotifier, LeaveStatsEntity>(
        LeaveStatsNotifier.new);

class LeaveStatsNotifier extends AutoDisposeAsyncNotifier<LeaveStatsEntity> {
  @override
  Future<LeaveStatsEntity> build() =>
      ref.read(leaveRepositoryProvider).getLeaveStats();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(leaveRepositoryProvider).getLeaveStats());
  }
}

// ── Leave Requests ────────────────────────────────────────────────────────────

final leaveRequestsProvider = AsyncNotifierProvider.autoDispose<
    LeaveRequestsNotifier, List<LeaveRequestEntity>>(LeaveRequestsNotifier.new);

class LeaveRequestsNotifier
    extends AutoDisposeAsyncNotifier<List<LeaveRequestEntity>> {
  @override
  Future<List<LeaveRequestEntity>> build() =>
      ref.read(leaveRepositoryProvider).getLeaveRequests();

  Future<String?> applyLeave({
    required String leaveTypeCode,
    required String fromDate,
    required String toDate,
    required String reason,
    required String duration,
    String? handoverTo,
    String? contactDuringLeave,
    String? handoverNotes,
    PlatformFile? document,
  }) async {
    try {
      final documentFile = document?.path == null
          ? null
          : await MultipartFile.fromFile(document!.path!,
              filename: document.name);
      final created = await ref.read(leaveRepositoryProvider).applyLeave(
            leaveTypeCode: leaveTypeCode,
            fromDate: fromDate,
            toDate: toDate,
            reason: reason,
            duration: duration,
            handoverTo: handoverTo,
            contactDuringLeave: contactDuringLeave,
            handoverNotes: handoverNotes,
            document: documentFile,
          );
      state = AsyncData([created, ...state.valueOrNull ?? []]);
      ref.invalidate(leaveStatsProvider);
      ref.invalidate(leaveBalancesProvider);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> approveRequest(String id) async {
    try {
      await ref.read(leaveRepositoryProvider).approveLeave(id);
      await refresh();
      // Keep this consistent with LeaveTeamPendingNotifier's own
      // approve/reject — both paths need the stats card and History
      // sub-tab to reflect the change, not just their own list.
      ref.invalidate(leaveStatsProvider);
      ref.invalidate(leaveTeamHistoryProvider);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> rejectRequest(String id, String reason) async {
    try {
      await ref.read(leaveRepositoryProvider).rejectLeave(id, reason);
      await refresh();
      ref.invalidate(leaveStatsProvider);
      ref.invalidate(leaveTeamHistoryProvider);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> cancelRequest(String id) async {
    try {
      await ref.read(leaveRepositoryProvider).cancelLeave(id);
      await refresh();
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(leaveRepositoryProvider).getLeaveRequests());
  }
}

// ── Team Pending Requests (scope=team, accumulating "load more") ─────────────

// Filter key shared by leaveTeamPendingProvider/leaveTeamHistoryProvider —
// branch is system_admin-only server-side (silently ignored for other
// roles); department just needs leave.approve, but the UI (matching web's
// canFilterDept) only shows that filter to system_admin/hr. Both empty means
// "no filter" for that dimension.
typedef LeaveTeamFilter = ({String branch, String department});

// Backs the approver Dashboard's "Pending Approvals" sub-tab and the
// Approvals tab's "Pending" sub-tab — a real server-side approval queue
// (scope=team), distinct from leaveRequestsProvider above (which is always
// the viewer's OWN requests, no matter the role — see fetchLeaveRequests'
// doc comment). Keyed by (branch, department) — page is tracked internally
// and grows via loadMore() instead of being part of the key.
final leaveTeamPendingProvider = AsyncNotifierProvider.autoDispose
    .family<LeaveTeamPendingNotifier, LeaveLoadMoreState, LeaveTeamFilter>(
        LeaveTeamPendingNotifier.new);

class LeaveTeamPendingNotifier extends AutoDisposeFamilyAsyncNotifier<
    LeaveLoadMoreState, LeaveTeamFilter> {
  @override
  Future<LeaveLoadMoreState> build(LeaveTeamFilter filter) async {
    final page = await ref.read(leaveRepositoryProvider).getLeaveRequestsPaginated(
          scope: 'team',
          page: 1,
          branch: filter.branch.isEmpty ? null : filter.branch,
          department: filter.department.isEmpty ? null : filter.department,
        );
    return LeaveLoadMoreState(
      items: page.results,
      page: page.page,
      totalPages: page.totalPages,
      count: page.count,
    );
  }

  // Fetches the next page and appends it to what's already loaded — the
  // list grows in place ("load more") instead of jumping to a new page.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref.read(leaveRepositoryProvider).getLeaveRequestsPaginated(
            scope: 'team',
            page: current.page + 1,
            branch: arg.branch.isEmpty ? null : arg.branch,
            department: arg.department.isEmpty ? null : arg.department,
          );
      state = AsyncData(LeaveLoadMoreState(
        items: [...current.items, ...next.results],
        page: next.page,
        totalPages: next.totalPages,
        count: next.count,
      ));
    } catch (_) {
      // A failed "load more" shouldn't wipe what's already on screen —
      // just drop the loading flag so the button reappears for a retry.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<String?> approveRequest(String id) async {
    try {
      await ref.read(leaveRepositoryProvider).approveLeave(id);
      ref.invalidateSelf();
      ref.invalidate(leaveStatsProvider);
      // A request leaving the pending queue lands in History (approved) —
      // without this, switching to the History sub-tab right after
      // approving/rejecting shows stale data until a manual refresh.
      ref.invalidate(leaveTeamHistoryProvider);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> rejectRequest(String id, String reason) async {
    try {
      await ref.read(leaveRepositoryProvider).rejectLeave(id, reason);
      ref.invalidateSelf();
      ref.invalidate(leaveStatsProvider);
      ref.invalidate(leaveTeamHistoryProvider);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

// ── Team History (scope=team, status=approved/rejected/cancelled, "load more") ─

// Backs the Approvals tab's "History" sub-tab. NOTE — backend limitation:
// _approval_scope_filter bakes a status restriction directly into the
// manager/hr_admin scope Q (status=pending / status=l2_pending respectively),
// which is ANDed with any additional ?status= filter. That means this can
// only ever return rows for system_admin (whose scope filter has no baked-in
// status, just ~Q(employee=user)) — manager/hr_admin will legitimately see
// an empty history list here. That's a shared backend constraint (the web
// frontend's equivalent History fetch hits the exact same limitation), not a
// mobile-side bug — see apps/hrms/views/leave.py _approval_scope_filter.
final leaveTeamHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<LeaveTeamHistoryNotifier, LeaveLoadMoreState, LeaveTeamFilter>(
        LeaveTeamHistoryNotifier.new);

class LeaveTeamHistoryNotifier extends AutoDisposeFamilyAsyncNotifier<
    LeaveLoadMoreState, LeaveTeamFilter> {
  @override
  Future<LeaveLoadMoreState> build(LeaveTeamFilter filter) async {
    final page = await ref.read(leaveRepositoryProvider).getLeaveRequestsPaginated(
          scope: 'team',
          status: 'approved,rejected,cancelled',
          page: 1,
          branch: filter.branch.isEmpty ? null : filter.branch,
          department: filter.department.isEmpty ? null : filter.department,
        );
    return LeaveLoadMoreState(
      items: page.results,
      page: page.page,
      totalPages: page.totalPages,
      count: page.count,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref.read(leaveRepositoryProvider).getLeaveRequestsPaginated(
            scope: 'team',
            status: 'approved,rejected,cancelled',
            page: current.page + 1,
            branch: arg.branch.isEmpty ? null : arg.branch,
            department: arg.department.isEmpty ? null : arg.department,
          );
      state = AsyncData(LeaveLoadMoreState(
        items: [...current.items, ...next.results],
        page: next.page,
        totalPages: next.totalPages,
        count: next.count,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

// ── Leave Calendar ────────────────────────────────────────────────────────────

final leaveCalendarProvider = FutureProvider.autoDispose
    .family<List<LeaveCalendarEventEntity>, (int year, int month)>((ref, key) {
  final (year, month) = key;
  return ref
      .read(leaveRepositoryProvider)
      .getLeaveCalendar(year: year, month: month);
});

// ── Employee Leave (admin Employee Profile "Leave" tab) ──────────────────────

// Read-only lookups of a single employee's leave requests/stats, gated
// server-side on the viewer having employees.view or leave.approve (see
// LeaveRequestListCreateView.get / LeaveRequestStatsView — 403/404 otherwise).
// employeeId is the human-readable code (e.g. 'RSS00001'), matching
// EmployeeModel.employeeId elsewhere in this app.
final employeeLeaveRequestsProvider = FutureProvider.autoDispose
    .family<LeaveRequestPageEntity, (String employeeId, int year, int page)>(
        (ref, key) {
  final (employeeId, year, page) = key;
  return ref.read(leaveRepositoryProvider).getEmployeeLeaveRequestsPaginated(
        employeeId: employeeId,
        year: year,
        page: page,
      );
});

final employeeLeaveStatsProvider = FutureProvider.autoDispose
    .family<LeaveStatsEntity, (String employeeId, int year)>((ref, key) {
  final (employeeId, year) = key;
  return ref
      .read(leaveRepositoryProvider)
      .getEmployeeLeaveStats(employeeId: employeeId, year: year);
});

// ── Leave Request Detail (single re-fetch) ────────────────────────────────────

// Backs the leave request detail sheet's background refresh: the sheet shows
// the already-known row immediately, then this quietly supplies the latest
// state from GET /leave/requests/<id>/ — mirrors web's useFetch(requestDetail).
final leaveRequestDetailProvider =
    FutureProvider.autoDispose.family<LeaveRequestEntity, String>((ref, id) {
  return ref.read(leaveRepositoryProvider).getLeaveRequestById(id);
});

// ── Leave Preview ─────────────────────────────────────────────────────────────
//
// Authoritative day-count/LOP breakdown from GET /leave/requests/?action=preview
// — the Apply Leave form uses this (when available) instead of re-deriving
// sandwich/holiday/week-off exclusion client-side, since the local estimate
// has no knowledge of company holidays. Keyed so the same (type, dates,
// duration) combination is cached and doesn't re-fetch on every rebuild.
typedef LeavePreviewParams = ({
  String leaveType,
  String startDate,
  String endDate,
  String? duration,
});

final leavePreviewProvider = FutureProvider.autoDispose
    .family<LeavePreviewEntity, LeavePreviewParams>((ref, params) {
  return ref.read(leaveRepositoryProvider).getLeavePreview(
        leaveType: params.leaveType,
        startDate: params.startDate,
        endDate: params.endDate,
        duration: params.duration,
      );
});

// ── Error helper ──────────────────────────────────────────────────────────────

/// Public alias of [_friendly] for use outside this file (e.g. dashboard
/// widgets that watch leave providers directly).
String friendlyLeaveError(Object e) => _friendly(e);

// Dio's own DioException.toString() never includes the response status code
// or body (see dio_exception.dart) — a prior version of this helper tried to
// string-match '400'/'403'/'409' etc. against that string and could never
// actually match, silently discarding every real backend validation message
// (e.g. "Insufficient balance...", "Future-dated leave applications are not
// allowed...") in favor of a generic fallback. Route through the shared,
// already-proven parseDioException() instead, which reads the real
// {status, message, data} envelope.
String _friendly(Object e) {
  if (e is DioException) return parseDioException(e).message;
  final msg = e.toString();
  if (msg.contains('SocketException')) {
    return 'Cannot reach server. Check your connection.';
  }
  return msg.replaceAll('Exception:', '').trim();
}
