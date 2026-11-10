import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../branches/data/models/branch_model.dart';
import '../../data/datasources/interview_datasource.dart';
import '../../domain/entities/candidate_entity.dart';

// Dio's own DioException.toString() never includes the response status code
// or body, so surfacing it directly (as this file previously did in every
// catch block) always shows a useless "DioException [bad response]: ..."
// toast instead of the real backend validation/business-rule message (e.g.
// "Candidate must be at least at Interview Done stage...", "Portal login
// already sent...", "Failed to send email. Check SMTP configuration.").
// Route through the shared, already-proven parseDioException() instead,
// which reads the real {status, message, data} envelope — same fix already
// applied in leave_providers.dart/employee_providers.dart/etc.
String _friendlyError(Object e) {
  if (e is DioException) return parseDioException(e).message;
  return e.toString();
}

final interviewDataSourceProvider =
    Provider<InterviewDataSource>((ref) {
  return InterviewDataSource(ref.watch(dioProvider));
});

// ── Bulk import ───────────────────────────────────────────────────────────────

/// Web interview-list page: "Bulk Import" and "Add Candidate" are rendered
/// only when canCreate = usePermission("recruitment.create") — a superuser, or
/// recruitment.create in the user's own permissions. No settings.edit bypass
/// (web has none). The create and import endpoints also require
/// recruitment.create.
bool canCreateCandidates(UserEntity? user) =>
    user != null && (user.isSuperuser || user.permissions.contains('recruitment.create'));

bool canOpenCandidateBulkImport(UserEntity? user) => canCreateCandidates(user);

const kCandidateCreateDenied = 'You do not have permission to add candidates.';

/// Thrown by [CandidateListNotifier.addCandidate] before any request when the
/// user can't create candidates; its text is what the form shows.
class CandidateCreateDenied implements Exception {
  const CandidateCreateDenied();
  @override
  String toString() => kCandidateCreateDenied;
}

const kCandidateImportDenied = 'You do not have permission to import candidates.';


/// Saves a downloaded sample through the system "save as" dialog (as the
/// other import screens do — no storage permission needed); returns the saved
/// path, or null when the user cancels. Tests override it.
final candidateSampleSaverProvider = Provider<Future<String?> Function(String fileName, Uint8List bytes)>(
  (ref) => (fileName, bytes) => FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: [fileName.split('.').last],
      ),
);

// ── Filter state ──────────────────────────────────────────────────────────────

final candidateStatusFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'all');

final candidateSearchProvider =
    StateProvider.autoDispose<String>((ref) => '');

/// Web interview-list branch filter: null = "All Branches" (web's default
/// for unrestricted users), else a Branch id sent as `?branch=<id>`.
final candidateBranchFilterProvider = StateProvider.autoDispose<int?>((ref) => null);

/// Web isUnrestrictedUser (lib/auth.ts): a superuser or a settings.edit
/// holder. Only these get the branch picker — and only for them does
/// CandidateListCreateView honour `branch` (its is_admin is
/// has_perm(settings.edit), superuser included). Everyone else is scoped to
/// their own branch by the server, whatever is sent; web shows that branch
/// locked.
bool isUnrestrictedCandidateViewer(UserEntity? user) =>
    user != null && (user.isSuperuser || user.permissions.contains('settings.edit'));

/// The picker's options, as web loads them once on mount:
/// GET /branch/branches/?status=active&page_size=100 (shown "Name (CODE)").
final candidateBranchOptionsProvider = FutureProvider.autoDispose<List<BranchModel>>((ref) async {
  final res = await ref
      .read(dioProvider)
      .get(ApiConstants.branches, queryParameters: {'status': 'active', 'page_size': 100});
  final body = res.data;
  final data = body is Map && body.containsKey('data') ? body['data'] : body;
  final results = data is Map ? data['results'] : data;
  return [
    if (results is List)
      for (final b in results.whereType<Map<String, dynamic>>()) BranchModel.fromJson(b),
  ];
});

// ── Stats ─────────────────────────────────────────────────────────────────────

final candidateStatsProvider =
    AsyncNotifierProvider.autoDispose<_StatsNotifier, CandidateStatsEntity>(
        _StatsNotifier.new);

class _StatsNotifier
    extends AutoDisposeAsyncNotifier<CandidateStatsEntity> {
  @override
  Future<CandidateStatsEntity> build() =>
      ref.read(interviewDataSourceProvider).fetchStats();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(interviewDataSourceProvider).fetchStats());
  }
}

// ── Candidate list (server-side search + pagination, as web) ─────────────────

/// The search actually sent to the server — the box's text after web's
/// 350 ms debounce ([candidateSearchProvider] holds what is typed).
final candidateAppliedSearchProvider = StateProvider.autoDispose<String>((ref) => '');

/// Web's search debounce.
const kCandidateSearchDebounce = Duration(milliseconds: 350);

/// Loaded pages of the interview list plus the server's paging info.
@immutable
class CandidateListState {
  const CandidateListState({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.count,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<CandidateEntity> items;
  final int page;
  final int totalPages;
  final int count;
  final bool loadingMore;
  final String? loadMoreError;

  bool get hasMore => page < totalPages;

  CandidateListState copyWith({
    List<CandidateEntity>? items,
    int? page,
    int? totalPages,
    int? count,
    bool? loadingMore,
    String? loadMoreError,
    bool clearError = false,
  }) =>
      CandidateListState(
        items: items ?? this.items,
        page: page ?? this.page,
        totalPages: totalPages ?? this.totalPages,
        count: count ?? this.count,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: clearError ? null : (loadMoreError ?? this.loadMoreError),
      );
}

final candidateListProvider = AsyncNotifierProvider.autoDispose<
    CandidateListNotifier,
    CandidateListState>(CandidateListNotifier.new);

/// Web interview-list page: canEditRec = usePermission("recruitment.edit") —
/// a superuser, or recruitment.edit in the user's OWN permissions. Unlike
/// [userHasPermission], settings.edit is NOT a substitute (web has no such
/// bypass), so this is checked directly.
bool canEditCandidates(UserEntity? user) =>
    user != null && (user.isSuperuser || user.permissions.contains('recruitment.edit'));

/// Web: "Edit" is shown when `canEditRec && status !== "converted"` (selected
/// and offer_sent candidates can still be edited).
bool canEditCandidate(UserEntity? user, CandidateEntity candidate) =>
    canEditCandidates(user) && !candidate.isConverted;

const kCandidateEditDenied = 'You do not have permission to edit this candidate.';

const kCandidateStatusChangeDenied = 'You do not have permission to change this candidate\'s status.';

/// Web interview-list page: the status dropdown is shown only with
/// recruitment.edit and only for the pre-selection pipeline — never for a
/// selected (→ Send Login), offer_sent (→ "Login Sent") or converted
/// (→ "Employee") candidate. Its options are CandidateStatusView's
/// status_choices (pending, screening, interview_scheduled, interview_done,
/// selected, rejected — offer_sent/converted are system-set); a rejected
/// candidate can still be moved. The backend itself only refuses
/// non-recruitment.edit users and converted candidates.
bool canChangeCandidateStatus(UserEntity? user, CandidateEntity candidate) =>
    canEditCandidates(user) &&
    !candidate.isConverted &&
    !candidate.isSelected &&
    !candidate.isOfferSent;

const kCandidateSendLoginDenied = 'You do not have permission to send the portal login.';

/// Web interview-list page: "Send Login" only when `canEditRec &&
/// status === "selected"`, where canEditRec is web usePermission
/// ("recruitment.edit") — a superuser, or recruitment.edit in the user's own
/// permissions. Unlike [userHasPermission] there is NO settings.edit bypass
/// here: web doesn't grant one, so neither does this. Only the status counts —
/// a Selected candidate who was already sent a login still gets the button,
/// as on web; the server answers that request itself ("Portal login already
/// sent. …") and its message is shown.
bool canSendCandidateLogin(UserEntity? user, CandidateEntity candidate) =>
    canEditCandidates(user) && candidate.isSelected;

/// Page 1 is (re)loaded whenever the applied search, the status tab or the
/// branch filter changes (web: fetchAll(…, 1)); a change made while an older
/// request is still running wins — Riverpod drops the stale build, and a page
/// load started under an older query is discarded ([_generation]).
class CandidateListNotifier
    extends AutoDisposeAsyncNotifier<CandidateListState> {
  InterviewDataSource get _ds =>
      ref.read(interviewDataSourceProvider);

  int _generation = 0;

  /// The `branch` sent: the picked branch for an unrestricted user (null =
  /// All Branches, no param); never for anyone else — the server scopes them.
  int? _branchParam(int? picked) =>
      isUnrestrictedCandidateViewer(ref.read(authStateProvider).valueOrNull?.user) ? picked : null;

  Future<CandidateListState> _loadFirst(String search, String status, int? branch) async {
    final p = await _ds.fetchCandidatePage(search: search, status: status, page: 1, branchId: _branchParam(branch));
    return CandidateListState(items: p.results, page: p.page, totalPages: p.totalPages, count: p.count);
  }

  @override
  Future<CandidateListState> build() {
    final search = ref.watch(candidateAppliedSearchProvider);
    final status = ref.watch(candidateStatusFilterProvider);
    final branch = ref.watch(candidateBranchFilterProvider);
    _generation++;
    return _loadFirst(search, status, branch);
  }

  Future<void> refresh() async {
    _generation++;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadFirst(ref.read(candidateAppliedSearchProvider),
        ref.read(candidateStatusFilterProvider), ref.read(candidateBranchFilterProvider)));
  }

  /// The next page, appended. Ignored while one is loading or when there is
  /// none; a failure keeps what is shown and offers a retry.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore || state.isLoading) return;
    final generation = _generation;
    state = AsyncData(current.copyWith(loadingMore: true, clearError: true));
    try {
      final p = await _ds.fetchCandidatePage(
        search: ref.read(candidateAppliedSearchProvider),
        status: ref.read(candidateStatusFilterProvider),
        page: current.page + 1,
        branchId: _branchParam(ref.read(candidateBranchFilterProvider)),
      );
      if (generation != _generation) return; // the query changed meanwhile
      final now = state.valueOrNull ?? current;
      final seen = now.items.map((c) => c.id).toSet();
      state = AsyncData(now.copyWith(
        items: [...now.items, ...p.results.where((c) => !seen.contains(c.id))],
        // The server answers an out-of-range page with the last one — stop there.
        page: p.page > now.page ? p.page : now.page,
        totalPages: p.page > now.page ? p.totalPages : now.page,
        count: p.count,
        loadingMore: false,
      ));
    } catch (e) {
      if (generation != _generation) return;
      state = AsyncData((state.valueOrNull ?? current).copyWith(loadingMore: false, loadMoreError: _friendlyError(e)));
    }
  }

  void _replaceItems(List<CandidateEntity> Function(List<CandidateEntity>) change, {int countDelta = 0}) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(items: change(current.items), count: current.count + countDelta));
  }

  Future<void> addCandidate(Map<String, dynamic> data) async {
    // Same rule as the menu entry, so a candidate can't be created another way.
    if (!canCreateCandidates(ref.read(authStateProvider).valueOrNull?.user)) {
      throw const CandidateCreateDenied();
    }
    final created = await _ds.createCandidate(data);
    _replaceItems((list) => [created, ...list], countDelta: 1);
    await ref.read(candidateStatsProvider.notifier).refresh();
  }

  Future<String?> updateCandidate(int id, Map<String, dynamic> data) async {
    // Same rule as the Edit button, so a candidate can't be edited another way.
    final user = ref.read(authStateProvider).valueOrNull?.user;
    final current = state.valueOrNull?.items.where((c) => c.id == id).firstOrNull;
    if (!canEditCandidates(user) || (current != null && !canEditCandidate(user, current))) {
      return kCandidateEditDenied;
    }
    try {
      final updated = await _ds.updateCandidate(id, data);
      _replaceItems((list) => list.map((c) => c.id == id ? updated : c).toList());
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  /// Returns an error message, or null on success. [onServerMessage] receives
  /// the backend's success message, which is the only place it reports
  /// whether the selected/rejected email it sent actually went out.
  Future<String?> updateStatus(int id, String newStatus,
      {String? remarks, void Function(String message)? onServerMessage}) async {
    // Same rule as the menu, so a hidden option can't be sent another way.
    final user = ref.read(authStateProvider).valueOrNull?.user;
    final current = state.valueOrNull?.items.where((c) => c.id == id).firstOrNull;
    if (!canEditCandidates(user) || (current != null && !canChangeCandidateStatus(user, current))) {
      return kCandidateStatusChangeDenied;
    }
    try {
      final result =
          await _ds.updateStatus(id, newStatus, remarks: remarks);
      _replaceItems((list) =>
          list.map((c) => c.id == id ? result.candidate : c).toList());
      await ref.read(candidateStatsProvider.notifier).refresh();
      onServerMessage?.call(result.message);
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> sendLogin(int id, {bool resend = false}) async {
    // Same rule as the button, so the invitation can't be sent another way.
    final user = ref.read(authStateProvider).valueOrNull?.user;
    final hasPermission = user != null && (user.isSuperuser || user.permissions.contains('recruitment.edit'));
    final current = state.valueOrNull?.items.where((c) => c.id == id).firstOrNull;
    if (!hasPermission || (!resend && current != null && !canSendCandidateLogin(user, current))) {
      return kCandidateSendLoginDenied;
    }
    try {
      if (resend) {
        await _ds.resendPortalLogin(id);
      } else {
        await _ds.sendPortalLogin(id);
      }
      await refresh();
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }
}

// ── Shown list ────────────────────────────────────────────────────────────────

/// The loaded candidates. Search and the status tab are applied by the server;
/// the tab is re-applied here only so a candidate whose status was just
/// changed leaves the tab at once (web refetches the page instead).
final filteredCandidatesProvider =
    Provider.autoDispose<List<CandidateEntity>>((ref) {
  final all = ref.watch(candidateListProvider).valueOrNull?.items ?? const <CandidateEntity>[];
  final status = ref.watch(candidateStatusFilterProvider);
  return status == 'all' ? all : all.where((c) => c.status == status).toList();
});

// ── Detail (for activity log) ─────────────────────────────────────────────────

final candidateDetailProvider = FutureProvider.autoDispose
    .family<CandidateEntity, int>((ref, id) {
  return ref.read(interviewDataSourceProvider).fetchCandidate(id);
});
