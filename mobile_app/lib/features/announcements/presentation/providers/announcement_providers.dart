import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../settings/data/models/departments_model.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
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

  @override
  Future<AnnouncementPage> build() {
    final category = ref.watch(announcementCategoryProvider);
    return _ds.fetchAnnouncements(category: category);
  }

  Future<String?> create(AnnouncementFormData form) async {
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
        ));
      }
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> edit(String id, AnnouncementFormData form) async {
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
        ));
      }
      return null;
    } catch (e) {
      return _friendly(e);
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
      ));
    } catch (_) {}
  }
}

// ── Departments (re-export from settings for form dropdowns) ──────────────────

final announcementDepartmentsProvider =
    Provider.autoDispose<AsyncValue<List<DepartmentModel>>>((ref) {
  return ref.watch(departmentsProvider);
});

// ── Branches (for form dropdown) ──────────────────────────────────────────────

final announcementBranchesProvider =
    FutureProvider.autoDispose<List<BranchSimple>>((ref) {
  return ref.watch(announcementsDataSourceProvider).fetchBranches();
});

// ── Friendly error messages ────────────────────────────────────────────────────

String _friendly(Object e) {
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
