import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/wfh_remote_datasource.dart';
import '../../data/repositories/wfh_repository_impl.dart';
import '../../domain/entities/wfh_entity.dart';
import '../../domain/repositories/wfh_repository.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final wfhDataSourceProvider = Provider<WfhRemoteDataSource>((ref) {
  return WfhRemoteDataSource(ref.watch(dioProvider));
});

final wfhRepositoryProvider = Provider<WfhRepository>((ref) {
  return WfhRepositoryImpl(ref.watch(wfhDataSourceProvider));
});

// ── My Requests (own list — create + cancel) ─────────────────────────────────

final wfhMyRequestsProvider = AsyncNotifierProvider.autoDispose<
    WfhMyRequestsNotifier, List<WfhRequestEntity>>(WfhMyRequestsNotifier.new);

class WfhMyRequestsNotifier
    extends AutoDisposeAsyncNotifier<List<WfhRequestEntity>> {
  @override
  Future<List<WfhRequestEntity>> build() =>
      ref.read(wfhRepositoryProvider).getWfhRequests();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(wfhRepositoryProvider).getWfhRequests());
  }

  // Returns null on success, else the backend's verbatim error string —
  // including both overlap-rejection messages (own WFH, own leave).
  Future<String?> createRequest({
    required String startDate,
    required String endDate,
    String? reason,
    String? locationLabel,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final created = await ref.read(wfhRepositoryProvider).createWfhRequest(
            startDate: startDate,
            endDate: endDate,
            reason: reason,
            locationLabel: locationLabel,
            latitude: latitude,
            longitude: longitude,
          );
      state = AsyncData([created, ...state.valueOrNull ?? []]);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  // can_cancel gates whether this is reachable from the UI at all; the
  // datasource call still surfaces the backend's own guard message ("Only
  // pending requests can be cancelled.") verbatim if it's somehow called
  // out of turn (e.g. a stale row after a background refresh raced an
  // approval).
  Future<String?> cancelRequest(String id) async {
    try {
      await ref.read(wfhRepositoryProvider).cancelWfhRequest(id);
      await refresh();
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

// Team-scope (scope=team) fetching and WFH approve/reject actions are NOT
// exposed through a WFH-local provider — this module has no Approvals tab
// of its own (matches web's actual WFH page, which is request+own-list
// only). Approvals live in the unified cross-feature Approvals screen
// (lib/features/approvals/), which calls wfhRepositoryProvider directly
// (getWfhRequestsPaginated(scope: 'team', ...), approveWfhRequest,
// rejectWfhRequest) the same way it already does for leave/expenses.

// ── Saved Locations ───────────────────────────────────────────────────────────

final wfhSavedLocationsProvider = AsyncNotifierProvider.autoDispose<
    WfhSavedLocationsNotifier,
    List<WfhSavedLocationEntity>>(WfhSavedLocationsNotifier.new);

class WfhSavedLocationsNotifier
    extends AutoDisposeAsyncNotifier<List<WfhSavedLocationEntity>> {
  @override
  Future<List<WfhSavedLocationEntity>> build() =>
      ref.read(wfhRepositoryProvider).getSavedLocations();

  // Duplicate-label 400 surfaces verbatim via _friendly(e) — no client-side
  // case-insensitive dedupe against the loaded list.
  Future<String?> saveLocation({
    required String label,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final created =
          await ref.read(wfhRepositoryProvider).createSavedLocation(
                label: label,
                latitude: latitude,
                longitude: longitude,
              );
      state = AsyncData([...state.valueOrNull ?? [], created]
        ..sort((a, b) => a.label.compareTo(b.label)));
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> deleteLocation(String id) async {
    try {
      await ref.read(wfhRepositoryProvider).deleteSavedLocation(id);
      state =
          AsyncData((state.valueOrNull ?? []).where((l) => l.id != id).toList());
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

// ── Request Detail (single re-fetch) ──────────────────────────────────────────
//
// Backs the detail sheet's background refresh: the sheet shows the already
// known row immediately, then this quietly supplies the latest state from
// GET /wfh/requests/<id>/ — mirrors leaveRequestDetailProvider.
final wfhRequestDetailProvider =
    FutureProvider.autoDispose.family<WfhRequestEntity, String>((ref, id) {
  return ref.read(wfhRepositoryProvider).getWfhRequestById(id);
});

// ── Error helper ──────────────────────────────────────────────────────────────

/// Public alias of [_friendly] for use outside this file.
String friendlyWfhError(Object e) => _friendly(e);

String _friendly(Object e) {
  if (e is DioException) return parseDioException(e).message;
  final msg = e.toString();
  if (msg.contains('SocketException')) {
    return 'Cannot reach server. Check your connection.';
  }
  return msg.replaceAll('Exception:', '').trim();
}
