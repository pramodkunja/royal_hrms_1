import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/email_log_remote_datasource.dart';
import '../../data/repositories/email_log_repository_impl.dart';
import '../../domain/entities/email_log_entity.dart';
import '../../domain/repositories/email_log_repository.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final emailLogDataSourceProvider = Provider<EmailLogRemoteDataSource>((ref) {
  return EmailLogRemoteDataSource(ref.watch(dioProvider));
});

final emailLogRepositoryProvider = Provider<EmailLogRepository>((ref) {
  return EmailLogRepositoryImpl(ref.watch(emailLogDataSourceProvider));
});

// ── Search box state — a separate StateProvider (not notifier-internal
// state) so keying the fetch family by its value gives every distinct
// search string its own cached page-1 result and a fresh "load more" cursor,
// mirroring leaveTeamPendingProvider's LeaveTeamFilter family pattern. ──────

final emailLogSearchProvider = StateProvider.autoDispose<String>((ref) => '');

// ── Fetch/"load more" provider, keyed by the current search string ─────────

final emailLogsProvider = AsyncNotifierProvider.autoDispose
    .family<EmailLogsNotifier, EmailLogLoadMoreState, String>(
  EmailLogsNotifier.new,
);

class EmailLogsNotifier
    extends AutoDisposeFamilyAsyncNotifier<EmailLogLoadMoreState, String> {
  @override
  Future<EmailLogLoadMoreState> build(String search) async {
    final page = await ref.read(emailLogRepositoryProvider).getEmailLogs(
          page: 1,
          search: search.isEmpty ? null : search,
        );
    return EmailLogLoadMoreState(
      items: page.results,
      page: page.page,
      totalPages: page.totalPages,
      count: page.count,
    );
  }

  // Fetches the next page and appends it to what's already loaded — the
  // list grows in place instead of jumping to a new page.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref.read(emailLogRepositoryProvider).getEmailLogs(
            page: current.page + 1,
            search: arg.isEmpty ? null : arg,
          );
      state = AsyncData(EmailLogLoadMoreState(
        items: [...current.items, ...next.results],
        page: next.page,
        totalPages: next.totalPages,
        count: next.count,
      ));
    } catch (_) {
      // A failed "load more" shouldn't wipe what's already on screen — just
      // drop the loading flag so the trigger can retry.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }
}
