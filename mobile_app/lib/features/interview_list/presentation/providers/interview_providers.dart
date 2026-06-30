import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/interview_datasource.dart';
import '../../domain/entities/candidate_entity.dart';

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

// ── Candidate list ────────────────────────────────────────────────────────────

final candidateListProvider = AsyncNotifierProvider.autoDispose<
    CandidateListNotifier,
    List<CandidateEntity>>(CandidateListNotifier.new);

class CandidateListNotifier
    extends AutoDisposeAsyncNotifier<List<CandidateEntity>> {
  InterviewDataSource get _ds =>
      ref.read(interviewDataSourceProvider);

  @override
  Future<List<CandidateEntity>> build() => _ds.fetchCandidates();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _ds.fetchCandidates());
  }

  Future<void> addCandidate(Map<String, dynamic> data) async {
    final created = await _ds.createCandidate(data);
    state.whenData((list) {
      state = AsyncData([created, ...list]);
    });
    await ref.read(candidateStatsProvider.notifier).refresh();
  }

  Future<String?> updateStatus(int id, String newStatus) async {
    try {
      final updated = await _ds.updateStatus(id, newStatus);
      state.whenData((list) {
        state = AsyncData(
          list.map((c) => c.id == id ? updated : c).toList(),
        );
      });
      await ref.read(candidateStatsProvider.notifier).refresh();
      return null;
    } catch (e) {
      return e.toString();
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
      return e.toString();
    }
  }
}

// ── Filtered list (client-side search) ───────────────────────────────────────

final filteredCandidatesProvider =
    Provider.autoDispose<List<CandidateEntity>>((ref) {
  final all = ref.watch(candidateListProvider).valueOrNull ?? [];
  final search =
      ref.watch(candidateSearchProvider).toLowerCase().trim();
  if (search.isEmpty) return all;
  return all.where((c) {
    return c.name.toLowerCase().contains(search) ||
        c.email.toLowerCase().contains(search) ||
        c.positionApplied.toLowerCase().contains(search) ||
        c.branchName.toLowerCase().contains(search);
  }).toList();
});

// ── Detail (for activity log) ─────────────────────────────────────────────────

final candidateDetailProvider = FutureProvider.autoDispose
    .family<CandidateEntity, int>((ref, id) {
  return ref.read(interviewDataSourceProvider).fetchCandidate(id);
});
