import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/assessments_remote_datasource.dart';
import '../../data/models/assessment_model.dart';

// ── Data source (stateless factory, kept alive) ───────────────────────────────

final assessmentsDataSourceProvider = Provider<AssessmentsRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return AssessmentsRemoteDataSource(dio);
});

// ── Assessments list ──────────────────────────────────────────────────────────

final assessmentsProvider =
    AsyncNotifierProvider.autoDispose<AssessmentsNotifier, List<AssessmentModel>>(
  AssessmentsNotifier.new,
);

class AssessmentsNotifier extends AutoDisposeAsyncNotifier<List<AssessmentModel>> {
  AssessmentsRemoteDataSource get _ds => ref.read(assessmentsDataSourceProvider);

  @override
  Future<List<AssessmentModel>> build() => _ds.fetchAssessments();

  Future<String?> createAssessment(AssessmentFormData form) async {
    try {
      final created = await _ds.createAssessment(form);
      state = AsyncData([...state.valueOrNull ?? [], created]);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> editAssessment(String id, AssessmentFormData form) async {
    try {
      final updated = await _ds.updateAssessment(id, form);
      state = AsyncData(
        (state.valueOrNull ?? []).map((a) => a.id == id ? updated : a).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> removeAssessment(String id) async {
    try {
      await _ds.deleteAssessment(id);
      state = AsyncData(
        (state.valueOrNull ?? []).where((a) => a.id != id).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  /// Re-fetches a single assessment's row (candidates/counters) after an
  /// assign action, without disturbing the rest of the list or its scroll
  /// position/expansion state.
  Future<void> refreshOne(String id) async {
    try {
      final all = await _ds.fetchAssessments();
      final match = all.where((a) => a.id == id).toList();
      if (match.isEmpty) return;
      state = AsyncData(
        (state.valueOrNull ?? []).map((a) => a.id == id ? match.first : a).toList(),
      );
    } catch (_) {
      // Best-effort refresh — surfaced errors would be confusing right after
      // a successful assign, so silently keep the stale row on failure.
    }
  }
}

// ── Assessment items (per-assessment, fetched lazily when Items dialog opens) ─

final assessmentItemsProvider = AsyncNotifierProvider.autoDispose
    .family<AssessmentItemsNotifier, List<AssessmentItemModel>, String>(
  AssessmentItemsNotifier.new,
);

class AssessmentItemsNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<AssessmentItemModel>, String> {
  AssessmentsRemoteDataSource get _ds => ref.read(assessmentsDataSourceProvider);

  @override
  Future<List<AssessmentItemModel>> build(String assessmentId) =>
      _ds.fetchItems(assessmentId);

  List<AssessmentItemModel> _sorted(List<AssessmentItemModel> items) =>
      [...items]..sort((a, b) => a.order.compareTo(b.order));

  bool get _canEdit => canEditAssessments(ref.read(authStateProvider).valueOrNull?.user);

  Future<String?> createItem(AssessmentItemFormData form) async {
    if (!_canEdit) return kAssessmentEditDenied;
    try {
      final created = await _ds.createItem(arg, form);
      state = AsyncData(_sorted([...state.valueOrNull ?? [], created]));
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> editItem(String itemId, AssessmentItemFormData form) async {
    if (!_canEdit) return kAssessmentEditDenied;
    try {
      final updated = await _ds.updateItem(itemId, form);
      state = AsyncData(
        _sorted((state.valueOrNull ?? []).map((i) => i.id == itemId ? updated : i).toList()),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> removeItem(String itemId) async {
    if (!_canEdit) return kAssessmentEditDenied;
    try {
      await _ds.deleteItem(itemId);
      state = AsyncData(
        (state.valueOrNull ?? []).where((i) => i.id != itemId).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

// ── Assessment sections (web ItemsModal; fetched while the dialog is open) ────

/// Production assessments views: item and section writes need
/// `has_perm(user, 'assessments.edit')` (superuser or the role's codename);
/// reading needs `assessments.view`.
bool canEditAssessments(UserEntity? user) =>
    user != null && (user.isSuperuser || user.permissions.contains('assessments.edit'));

const kAssessmentEditDenied = 'Permission denied.';

final assessmentSectionsProvider = AsyncNotifierProvider.autoDispose
    .family<AssessmentSectionsNotifier, List<AssessmentSectionModel>, String>(
  AssessmentSectionsNotifier.new,
);

/// Sections in `order` (web sorts them the same way). Writes are refused
/// before any request without assessments.edit, and run one at a time.
class AssessmentSectionsNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<AssessmentSectionModel>, String> {
  AssessmentsRemoteDataSource get _ds => ref.read(assessmentsDataSourceProvider);
  bool _busy = false;

  @override
  Future<List<AssessmentSectionModel>> build(String assessmentId) async {
    final sections = await _ds.fetchSections(assessmentId);
    return [...sections]..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<String?> _write(Future<void> Function() run, {bool reloadItems = false}) async {
    if (!canEditAssessments(ref.read(authStateProvider).valueOrNull?.user)) return kAssessmentEditDenied;
    if (_busy) return 'Please wait — a change is already being saved.';
    _busy = true;
    try {
      await run();
      // Web: refetchSections(); after a delete also refetchItems().
      ref.invalidateSelf();
      if (reloadItems) ref.invalidate(assessmentItemsProvider(arg));
      return null;
    } catch (e) {
      return _friendly(e);
    } finally {
      _busy = false;
    }
  }

  Future<String?> createSection(AssessmentSectionFormData form) => _write(() => _ds.createSection(arg, form));

  Future<String?> editSection(String sectionId, AssessmentSectionFormData form) =>
      _write(() => _ds.updateSection(arg, sectionId, form));

  /// The server moves the section's items to unsectioned.
  Future<String?> removeSection(String sectionId) =>
      _write(() => _ds.deleteSection(arg, sectionId), reloadItems: true);
}

// ── Employees + email templates for the Assign dialog ─────────────────────────

final assignableEmployeesProvider =
    FutureProvider.autoDispose<List<AssignableEmployeeModel>>((ref) {
  return ref.read(assessmentsDataSourceProvider).fetchAssignableEmployees();
});

final assignEmailTemplateOptionsProvider =
    FutureProvider.autoDispose<List<EmailTemplateOptionModel>>((ref) {
  return ref.read(assessmentsDataSourceProvider).fetchEmailTemplateOptions();
});

// ── Assign action (one-shot, no persisted state of its own) ──────────────────
// Mirrors web's doAssign(): the caller loops this per selected employee and
// aggregates successes/failures itself — this stays a single-target call.

Future<String?> assignCandidateToAssessment(
  WidgetRef ref, {
  required String candidateId,
  required String assessmentId,
  required String templateName,
}) async {
  try {
    await ref.read(assessmentsDataSourceProvider).assignAssessment(
          candidateId: candidateId,
          assessmentId: assessmentId,
          templateName: templateName,
        );
    return null;
  } catch (e) {
    return _friendly(e);
  }
}

// ── Error helper ──────────────────────────────────────────────────────────────
//
// Unlike the string-matching `_friendly()` duplicated elsewhere in this app
// (which loses the backend's actual validation text), this uses the already
// shared-but-unwired `parseDioException()` from core/network/api_client.dart
// so field-specific messages from `core.responses.first_error()` — e.g.
// "video_url: video_url is required for video items.", "Assessment already
// assigned to this candidate.", "Cannot delete an assessment with active
// candidate assignments." — reach the user verbatim instead of a generic
// fallback.
/// Public alias of [_friendly] for the other assessment screens.
String friendlyAssessmentError(Object e) => _friendly(e);

String _friendly(Object e) {
  if (e is DioException) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Cannot reach server. Check your connection.';
    }
    return parseDioException(e).message;
  }
  return e.toString().replaceAll('Exception:', '').trim();
}
