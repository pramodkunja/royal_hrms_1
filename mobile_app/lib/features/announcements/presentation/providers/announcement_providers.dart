import 'package:dio/dio.dart' show DioException, DioExceptionType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/router/access_control.dart' show userHasPermission;
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/data/models/departments_model.dart';
import '../announcement_permissions.dart';
import '../../data/datasources/announcements_remote_datasource.dart';
import '../../data/models/announcement_model.dart';

// ── DataSource ─────────────────────────────────────────────────────────────────

final announcementsDataSourceProvider =
    Provider<AnnouncementsRemoteDataSource>((ref) {
  return AnnouncementsRemoteDataSource(ref.watch(dioProvider));
});

// ── Category filter ────────────────────────────────────────────────────────────

final announcementCategoryProvider =
    StateProvider.autoDispose<String?>((ref) => null);

// ── Announcements list + stats ────────────────────────────────────────────────

final announcementsProvider =
    AsyncNotifierProvider.autoDispose<AnnouncementsNotifier, AnnouncementPage>(
  AnnouncementsNotifier.new,
);

class AnnouncementsNotifier extends AutoDisposeAsyncNotifier<AnnouncementPage> {
  AnnouncementsRemoteDataSource get _ds =>
      ref.read(announcementsDataSourceProvider);

  // Bumped on every (re)build — a category change or a refresh — so a
  // further-page response that arrives afterwards is discarded instead of
  // being appended to the new list.
  int _generation = 0;
  bool _loadingMore = false; // the real one-at-a-time guard

  @override
  Future<AnnouncementPage> build() {
    _generation++;
    _loadingMore = false;
    final category = ref.watch(announcementCategoryProvider);
    return _ds.fetchAnnouncements(category: category);
  }

  /// Reloads from page 1 (pull-to-refresh), dropping the loaded pages.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // The error is in state; the screen shows it.
    }
  }

  /// Appends the next page. One request at a time; nothing once the server
  /// says there are no more pages. Announcements already shown are not
  /// repeated (the list can shift between requests, and the server returns
  /// the last page again for a page number past the end).
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || _loadingMore || !current.hasMore) return;
    _loadingMore = true;
    final generation = _generation;
    final category = ref.read(announcementCategoryProvider);
    state = AsyncData(current.copyWith(loadingMore: true, clearError: true));
    try {
      final next = await _ds.fetchAnnouncements(category: category, page: current.currentPage + 1);
      if (generation != _generation) return; // list was reset meanwhile
      final latest = state.valueOrNull ?? current; // keep edits made meanwhile
      final seen = {for (final a in latest.announcements) a.id};
      final fresh = next.announcements.where((a) => seen.add(a.id)).toList();
      // Stop when the server has nothing further (empty page, or a page
      // number that did not advance), whatever total_pages said.
      final advanced = next.currentPage > latest.currentPage && next.announcements.isNotEmpty;
      state = AsyncData(latest.copyWith(
        announcements: [...latest.announcements, ...fresh],
        stats: next.stats,
        currentPage: advanced ? next.currentPage : latest.currentPage,
        totalPages: advanced ? next.totalPages : latest.currentPage,
        loadingMore: false,
        clearError: true,
      ));
    } catch (e) {
      if (generation != _generation) return;
      final latest = state.valueOrNull ?? current;
      state = AsyncData(latest.copyWith(loadingMore: false, loadMoreError: _friendly(e)));
    } finally {
      if (generation == _generation) _loadingMore = false;
    }
  }

  /// Permission and branch-scope check before any request (the backend does
  /// not enforce the branch scope — see announcement_permissions.dart).
  Future<String?> _guard(AnnouncementFormData form, {required String permission, required String denied}) async {
    final user = ref.read(authStateProvider).valueOrNull?.user;
    if (!userHasPermission(user, permission)) return denied;
    if (isOrgWideAnnouncer(user) || form.visibility == 'department') return null;
    List<BranchSimple> branches;
    try {
      branches = await ref.read(announcementBranchesProvider.future);
    } catch (_) {
      branches = const [];
    }
    return announcementScopeError(form, user, ownBranchId: announcementOwnBranchId(user, branches));
  }

  Future<String?> create(AnnouncementFormData form) async {
    final refused = await _guard(form, permission: 'announcements.create', denied: kAnnouncementCreateDenied);
    if (refused != null) return refused;
    try {
      final created = await _ds.createAnnouncement(form);
      final current = state.valueOrNull;
      if (current != null) {
        final stats = current.stats;
        state = AsyncData(AnnouncementPage(
          announcements: [created, ...current.announcements],
          stats: AnnouncementStats(
            totalCount:     stats.totalCount + 1,
            pinnedCount:    created.isPinned ? stats.pinnedCount + 1 : stats.pinnedCount,
            totalViews:     stats.totalViews,
            totalReactions: stats.totalReactions,
          ),
          currentPage: current.currentPage,
          totalPages:  current.totalPages,
          loadingMore: current.loadingMore,
          loadMoreError: current.loadMoreError,
        ));
      }
      return null;
    } catch (e) {
      return _saveError(e);
    }
  }

  /// A save that was sent but got no reply in time may still have been
  /// applied on the server (web: "may still have been saved"). A connection
  /// that never opened did not reach the server, so it keeps the ordinary
  /// message.
  String _saveError(Object e) {
    if (e is DioException &&
        (e.type == DioExceptionType.sendTimeout || e.type == DioExceptionType.receiveTimeout)) {
      return kAnnouncementSaveTimedOut;
    }
    return _friendly(e);
  }

  Future<String?> edit(String id, AnnouncementFormData form) async {
    final refused = await _guard(form, permission: 'announcements.edit', denied: kAnnouncementEditDenied);
    if (refused != null) return refused;
    try {
      final updated = await _ds.updateAnnouncement(id, form);
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(AnnouncementPage(
          announcements: current.announcements
              .map((a) => a.id == id ? updated : a)
              .toList(),
          stats:       current.stats,
          currentPage: current.currentPage,
          totalPages:  current.totalPages,
          loadingMore: current.loadingMore,
          loadMoreError: current.loadMoreError,
        ));
      }
      return null;
    } catch (e) {
      return _saveError(e);
    }
  }

  Future<String?> remove(String id) async {
    try {
      await _ds.deleteAnnouncement(id);
      final current = state.valueOrNull;
      if (current != null) {
        final removed = current.announcements.where((a) => a.id == id).firstOrNull;
        final stats   = current.stats;
        state = AsyncData(AnnouncementPage(
          announcements: current.announcements.where((a) => a.id != id).toList(),
          stats: AnnouncementStats(
            totalCount:     stats.totalCount - 1,
            pinnedCount:    (removed?.isPinned ?? false)
                ? stats.pinnedCount - 1
                : stats.pinnedCount,
            totalViews:     stats.totalViews,
            totalReactions: stats.totalReactions,
          ),
          currentPage: current.currentPage,
          totalPages:  current.totalPages,
          loadingMore: current.loadingMore,
          loadMoreError: current.loadMoreError,
        ));
      }
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<void> toggleReaction(String id) async {
    try {
      final result  = await _ds.toggleReaction(id);
      final current = state.valueOrNull;
      if (current == null) return;
      final delta = result.hasReacted ? 1 : -1;
      state = AsyncData(AnnouncementPage(
        announcements: current.announcements.map((a) => a.id != id
            ? a
            : a.copyWith(
                hasReacted:     result.hasReacted,
                reactionsCount: result.reactionsCount,
              )).toList(),
        stats: AnnouncementStats(
          totalCount:     current.stats.totalCount,
          pinnedCount:    current.stats.pinnedCount,
          totalViews:     current.stats.totalViews,
          totalReactions: current.stats.totalReactions + delta,
        ),
        currentPage: current.currentPage,
        totalPages:  current.totalPages,
        loadingMore: current.loadingMore,
        loadMoreError: current.loadMoreError,
      ));
    } catch (_) {}
  }
}

// ── Departments (re-export from settings for form dropdowns) ──────────────────

/// Keyed by the branch-name filter: null (org-wide, all departments) or the
/// poster's own branch (web `?branch=`).
final announcementDepartmentsProvider =
    FutureProvider.autoDispose.family<List<DepartmentModel>, String?>((ref, branch) {
  return ref.watch(announcementsDataSourceProvider).fetchDepartments(branch: branch);
});

// ── Branches (for form dropdown) ──────────────────────────────────────────────

final announcementBranchesProvider =
    FutureProvider.autoDispose<List<BranchSimple>>((ref) {
  return ref.watch(announcementsDataSourceProvider).fetchBranches();
});

// ── Friendly error messages ────────────────────────────────────────────────────

String _friendly(Object e) {
  // HTTP failures keep the server's own message (e.g. "<Module> is not
  // enabled for your company…", or the permission refusal).
  if (e is DioException || e is AppException) return userFriendlyMessage(e);
  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('connection')) {
    return 'Cannot reach server. Check your connection.';
  }
  if (msg.contains('401')) return 'Session expired. Please log in again.';
  if (msg.contains('403')) return 'You do not have permission to do this.';
  if (msg.contains('404')) return 'Announcement not found.';
  if (msg.contains('500')) return 'Server error. Please try again later.';
  return msg.replaceAll('Exception:', '').trim();
}
