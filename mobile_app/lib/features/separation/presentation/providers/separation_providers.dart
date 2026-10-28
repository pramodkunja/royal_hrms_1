import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/separation_remote_datasource.dart';
import '../../data/repositories/separation_repository_impl.dart';
import '../../domain/entities/separation_entity.dart';
import '../../domain/repositories/separation_repository.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final separationDataSourceProvider = Provider<SeparationRemoteDataSource>((ref) {
  return SeparationRemoteDataSource(ref.watch(dioProvider));
});

final separationRepositoryProvider = Provider<SeparationRepository>((ref) {
  return SeparationRepositoryImpl(ref.watch(separationDataSourceProvider));
});

// ── Lookups ───────────────────────────────────────────────────────────────────

final separationTypesProvider =
    FutureProvider.autoDispose<List<SeparationLookupOption>>((ref) {
  return ref.read(separationRepositoryProvider).getTypes();
});

final separationReasonsProvider =
    FutureProvider.autoDispose<List<SeparationLookupOption>>((ref) {
  return ref.read(separationRepositoryProvider).getReasons();
});

// ── Request list (My / Team, "load more") ─────────────────────────────────────

// scope: '' = the viewer's own requests (every role); 'team' = the real
// approval queue, only effective when the viewer holds separation.approve
// (see SeparationRemoteDataSource.fetchRequests doc comment). status: '' =
// no filter, or a comma-joined list (e.g. 'approved,rejected,cancelled' for
// a history view).
typedef SeparationListFilter = ({String scope, String status});

final separationListProvider = AsyncNotifierProvider.autoDispose
    .family<SeparationListNotifier, SeparationLoadMoreState, SeparationListFilter>(
        SeparationListNotifier.new);

class SeparationListNotifier extends AutoDisposeFamilyAsyncNotifier<
    SeparationLoadMoreState, SeparationListFilter> {
  Future<SeparationLoadMoreState> _fetch(int page) async {
    final result = await ref.read(separationRepositoryProvider).getRequests(
          scope: arg.scope.isEmpty ? null : arg.scope,
          status: arg.status.isEmpty ? null : arg.status,
          page: page,
        );
    return SeparationLoadMoreState(
      items: result.results,
      page: result.page,
      totalPages: result.totalPages,
      count: result.count,
    );
  }

  @override
  Future<SeparationLoadMoreState> build(SeparationListFilter filter) =>
      _fetch(1);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(1));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(current.page + 1);
      state = AsyncData(SeparationLoadMoreState(
        items: [...current.items, ...next.items],
        page: next.page,
        totalPages: next.totalPages,
        count: next.count,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

// ── Request detail (single re-fetch) ──────────────────────────────────────────

final separationDetailProvider = FutureProvider.autoDispose
    .family<SeparationRequestEntity, String>((ref, id) {
  return ref.read(separationRepositoryProvider).getRequestById(id);
});

// ── Sub-resources (per request id) ────────────────────────────────────────────

final separationTasksProvider = FutureProvider.autoDispose
    .family<List<SeparationHandoverTaskEntity>, String>((ref, requestId) {
  return ref.read(separationRepositoryProvider).getTasks(requestId);
});

final separationClearancesProvider = FutureProvider.autoDispose
    .family<List<SeparationClearanceEntity>, String>((ref, requestId) {
  return ref.read(separationRepositoryProvider).getClearances(requestId);
});

final separationDocumentsProvider = FutureProvider.autoDispose
    .family<List<SeparationDocumentEntity>, String>((ref, requestId) {
  return ref.read(separationRepositoryProvider).getDocuments(requestId);
});

final separationActivitiesProvider = FutureProvider.autoDispose
    .family<List<SeparationActivityEntity>, String>((ref, requestId) {
  return ref.read(separationRepositoryProvider).getActivities(requestId);
});

// ── Actions (create/update/cancel/approve/reject/tasks/clearances/documents) ──
//
// Centralizes the repository call + the invalidation of every provider that
// could now be stale, so screens/widgets never have to remember which
// providers back a given mutation — mirrors LeaveRequestsNotifier's
// approve/reject/cancel methods, just not tied to one particular list.

final separationActionsProvider =
    Provider<SeparationActions>((ref) => SeparationActions(ref));

class SeparationActions {
  final Ref _ref;
  SeparationActions(this._ref);

  SeparationRepository get _repo => _ref.read(separationRepositoryProvider);

  void _invalidateLists() => _ref.invalidate(separationListProvider);

  void _invalidateRequest(String id) {
    _ref.invalidate(separationDetailProvider(id));
    _ref.invalidate(separationActivitiesProvider(id));
    _invalidateLists();
  }

  Future<String?> createRequest({
    required String separationType,
    required String reason,
    required String requestDate,
    required String proposedLastWorkingDay,
    required int noticePeriodDays,
    String? comments,
    String? employeeId,
    PlatformFile? document,
  }) async {
    try {
      final documentFile = document?.path == null
          ? null
          : await MultipartFile.fromFile(document!.path!,
              filename: document.name);
      await _repo.createRequest(
        separationType: separationType,
        reason: reason,
        requestDate: requestDate,
        proposedLastWorkingDay: proposedLastWorkingDay,
        noticePeriodDays: noticePeriodDays,
        comments: comments,
        employeeId: employeeId,
        document: documentFile,
      );
      _invalidateLists();
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> updateRequest({
    required String id,
    required String separationType,
    required String reason,
    required String requestDate,
    required String proposedLastWorkingDay,
    required int noticePeriodDays,
    String? comments,
    PlatformFile? document,
  }) async {
    try {
      final documentFile = document?.path == null
          ? null
          : await MultipartFile.fromFile(document!.path!,
              filename: document.name);
      await _repo.updateRequest(
        id: id,
        separationType: separationType,
        reason: reason,
        requestDate: requestDate,
        proposedLastWorkingDay: proposedLastWorkingDay,
        noticePeriodDays: noticePeriodDays,
        comments: comments,
        document: documentFile,
      );
      _invalidateRequest(id);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> cancelRequest(String id) async {
    try {
      await _repo.cancelRequest(id);
      _invalidateRequest(id);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> deleteRequest(String id) async {
    try {
      await _repo.deleteRequest(id);
      _invalidateLists();
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> actionStage({
    required String requestId,
    required String stageId,
    required String action,
    String? remarks,
  }) async {
    try {
      await _repo.actionStage(
        requestId: requestId,
        stageId: stageId,
        action: action,
        remarks: remarks,
      );
      _invalidateRequest(requestId);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> addTask({
    required String requestId,
    required String task,
    String? description,
    String? assignedTo,
    String? dueDate,
  }) async {
    try {
      await _repo.createTask(
        requestId: requestId,
        task: task,
        description: description,
        assignedTo: assignedTo,
        dueDate: dueDate,
      );
      _ref.invalidate(separationTasksProvider(requestId));
      _ref.invalidate(separationActivitiesProvider(requestId));
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> setTaskCompletion({
    required String requestId,
    required String taskId,
    required bool isCompleted,
  }) async {
    try {
      await _repo.setTaskCompletion(
        requestId: requestId,
        taskId: taskId,
        isCompleted: isCompleted,
      );
      _ref.invalidate(separationTasksProvider(requestId));
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> deleteTask({
    required String requestId,
    required String taskId,
  }) async {
    try {
      await _repo.deleteTask(requestId: requestId, taskId: taskId);
      _ref.invalidate(separationTasksProvider(requestId));
      _ref.invalidate(separationActivitiesProvider(requestId));
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> actionClearance({
    required String requestId,
    required String clearanceId,
    required String action,
    String? remarks,
  }) async {
    try {
      await _repo.actionClearance(
        requestId: requestId,
        clearanceId: clearanceId,
        action: action,
        remarks: remarks,
      );
      _ref.invalidate(separationClearancesProvider(requestId));
      _ref.invalidate(separationActivitiesProvider(requestId));
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> uploadDocument({
    required String requestId,
    required String documentType,
    required PlatformFile file,
  }) async {
    try {
      if (file.path == null) return 'Could not read the selected file.';
      final multipart =
          await MultipartFile.fromFile(file.path!, filename: file.name);
      await _repo.uploadDocument(
        requestId: requestId,
        documentType: documentType,
        file: multipart,
      );
      _ref.invalidate(separationDocumentsProvider(requestId));
      _ref.invalidate(separationActivitiesProvider(requestId));
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> deleteDocument({
    required String requestId,
    required String documentId,
  }) async {
    try {
      await _repo.deleteDocument(requestId: requestId, documentId: documentId);
      _ref.invalidate(separationDocumentsProvider(requestId));
      _ref.invalidate(separationActivitiesProvider(requestId));
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

// ── Error helper ──────────────────────────────────────────────────────────────

String friendlySeparationError(Object e) => _friendly(e);

String _friendly(Object e) {
  if (e is DioException) return parseDioException(e).message;
  final msg = e.toString();
  if (msg.contains('SocketException')) {
    return 'Cannot reach server. Check your connection.';
  }
  return msg.replaceAll('Exception:', '').trim();
}
