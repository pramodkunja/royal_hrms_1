import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
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

// ── Filter state ──────────────────────────────────────────────────────────────

final candidateStatusFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'all');

final candidateSearchProvider =
    StateProvider.autoDispose<String>((ref) => '');

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

/// Page 1 is (re)loaded whenever the applied search or the status tab
/// changes (web: fetchAll(…, 1)); a change made while an older request is
/// still running wins — Riverpod drops the stale build, and a page load
/// started under an older query is discarded ([_generation]).
class CandidateListNotifier
    extends AutoDisposeAsyncNotifier<CandidateListState> {
  InterviewDataSource get _ds =>
      ref.read(interviewDataSourceProvider);

  int _generation = 0;

  Future<CandidateListState> _loadFirst(String search, String status) async {
    final p = await _ds.fetchCandidatePage(search: search, status: status, page: 1);
    return CandidateListState(items: p.results, page: p.page, totalPages: p.totalPages, count: p.count);
  }

  @override
  Future<CandidateListState> build() {
    final search = ref.watch(candidateAppliedSearchProvider);
    final status = ref.watch(candidateStatusFilterProvider);
    _generation++;
    return _loadFirst(search, status);
  }

  Future<void> refresh() async {
    _generation++;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadFirst(
        ref.read(candidateAppliedSearchProvider), ref.read(candidateStatusFilterProvider)));
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
    final created = await _ds.createCandidate(data);
    _replaceItems((list) => [created, ...list], countDelta: 1);
    await ref.read(candidateStatsProvider.notifier).refresh();
  }

  Future<String?> updateCandidate(int id, Map<String, dynamic> data) async {
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
