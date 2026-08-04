import 'package:dio/dio.dart';
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

  Future<String?> updateCandidate(int id, Map<String, dynamic> data) async {
    try {
      final updated = await _ds.updateCandidate(id, data);
      state.whenData((list) {
        state = AsyncData(
          list.map((c) => c.id == id ? updated : c).toList(),
        );
      });
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> updateStatus(int id, String newStatus,
      {String? remarks}) async {
    try {
      final updated =
          await _ds.updateStatus(id, newStatus, remarks: remarks);
      state.whenData((list) {
        state = AsyncData(
          list.map((c) => c.id == id ? updated : c).toList(),
        );
      });
      await ref.read(candidateStatsProvider.notifier).refresh();
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  // Fire-and-forget: mirrors web, where a failed email send doesn't undo an
  // already-successful status/edit change. Errors are returned (not thrown)
  // so the caller can surface a non-blocking warning.
  Future<String?> sendStatusEmail(
    int id, {
    required String templateName,
    required Map<String, String> extraContext,
  }) async {
    try {
      await _ds.sendEmail(id,
          templateName: templateName, extraContext: extraContext);
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

// ── Filtered list (client-side search) ───────────────────────────────────────

final filteredCandidatesProvider =
    Provider.autoDispose<List<CandidateEntity>>((ref) {
  final all = ref.watch(candidateListProvider).valueOrNull ?? [];
  final status = ref.watch(candidateStatusFilterProvider);
  final search =
      ref.watch(candidateSearchProvider).toLowerCase().trim();

  final byStatus = status == 'all'
      ? all
      : all.where((c) => c.status == status).toList();

  if (search.isEmpty) return byStatus;
  return byStatus.where((c) {
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
