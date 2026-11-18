import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/router/access_control.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/training_remote_datasource.dart';
import '../../data/models/training_models.dart';

final trainingDatasourceProvider =
    Provider.autoDispose<TrainingRemoteDatasource>((ref) => TrainingRemoteDatasource(ref.watch(dioProvider)));

final trainingDashboardProvider = FutureProvider.autoDispose<TrainingDashboard>(
  (ref) => ref.watch(trainingDatasourceProvider).fetchDashboard(),
);

/// Courses list; the argument is web's "Show archived".
final trainingCoursesProvider = FutureProvider.autoDispose.family<List<TrainingCourse>, bool>(
  (ref, archived) => ref.watch(trainingDatasourceProvider).fetchCourses(archived: archived),
);

final trainingCourseProvider = FutureProvider.autoDispose.family<TrainingCourse, String>(
  (ref, id) => ref.watch(trainingDatasourceProvider).fetchCourse(id),
);

final trainingProgressProvider = FutureProvider.autoDispose.family<List<TrainingAssignmentRow>, String>(
  (ref, courseId) => ref.watch(trainingDatasourceProvider).fetchProgress(courseId),
);

final trainingReportProvider = FutureProvider.autoDispose.family<List<TrainingAssignmentRow>, TrainingReportFilter>(
  (ref, filter) => ref.watch(trainingDatasourceProvider).fetchReport(filter),
);

/// Employee picker (search text as argument).
final trainingPickerProvider = FutureProvider.autoDispose.family<TrainingPicker, String>(
  (ref, search) => ref.watch(trainingDatasourceProvider).fetchPicker(search: search),
);

/// What the signed-in user may do, from the same codenames web checks with
/// usePermission (training/page.tsx, training/[id]/page.tsx). The backend
/// re-checks every one; these only decide which controls are offered.
class TrainingAccess {
  const TrainingAccess(this.user);
  final UserEntity? user;

  bool get canView => userHasPermission(user, 'training.view');
  bool get canCreate => userHasPermission(user, 'training.create');
  bool get canEdit => userHasPermission(user, 'training.edit');
  bool get canDelete => userHasPermission(user, 'training.delete');
  bool get canAssign => userHasPermission(user, 'training.assign');
  bool get canResetAttempts => userHasPermission(user, 'training.manage_assessments');

  /// training.manage_assessments also governs linking an assessment.
  bool get canManageAssessments => canResetAttempts;
  bool get canViewReports => userHasPermission(user, 'training.view_reports');
}

// ── My Learning (employee) ──────────────────────────────────────────────────

/// GET /training/my/ — the signed-in user's own assignments (read-only).
final myTrainingListProvider = FutureProvider.autoDispose<List<MyTraining>>(
  (ref) => ref.watch(trainingDatasourceProvider).fetchMy(),
);

/// GET /training/my/<id>/ — read-only; never records progress.
final myTrainingDetailProvider = FutureProvider.autoDispose.family<MyTraining, String>(
  (ref, id) => ref.watch(trainingDatasourceProvider).fetchMyDetail(id),
);

/// Course thumbnail bytes (access-checked by the backend; read-only).
final trainingThumbnailProvider = FutureProvider.autoDispose.family<Uint8List, String>(
  (ref, courseId) => ref.watch(trainingDatasourceProvider).fetchThumbnail(courseId),
);

// ── Admin actions (Task 90 batch 3) ─────────────────────────────────────────

/// Every Training admin write goes through here. Each action checks the
/// same codename web's button checks (and the backend view enforces) BEFORE
/// any request is sent, so a hidden button is never the only guard — a
/// missing permission throws ForbiddenException and nothing reaches the
/// server. The backend re-checks everything.
class TrainingAdminActions {
  TrainingAdminActions(this._ds, this._access);
  final TrainingRemoteDatasource _ds;
  final TrainingAccess _access;

  void _require(bool allowed) {
    if (!allowed) throw const ForbiddenException('You do not have permission to perform this action.');
  }

  Future<TrainingCourse> createCourse({required String title, String category = ''}) {
    _require(_access.canCreate);
    if (title.trim().isEmpty) throw const ValidationException('Give the course a title.');
    return _ds.createCourse(title: title, category: category);
  }

  /// Validates like web before sending; the assessment link is included only
  /// for training.manage_assessments.
  Future<TrainingCourse> saveCourse(TrainingCourse course, TrainingCourseForm form) {
    _require(_access.canEdit && !course.archived);
    final errors = form.validate();
    if (errors.isNotEmpty) throw ValidationException(errors.values.first);
    return _ds.updateCourse(course.id, form.toPayload(canLinkAssessment: _access.canManageAssessments));
  }

  Future<void> uploadThumbnail(TrainingCourse course, TrainingUploadFile file) {
    _require(_access.canEdit && !course.archived);
    final dot = file.name.lastIndexOf('.');
    final ext = dot < 0 ? '' : file.name.substring(dot + 1).toLowerCase();
    if (!kTrainingThumbnailExtensions.contains(ext)) throw const ValidationException('Upload a PNG or JPG image.');
    if (file.size <= 0) throw const ValidationException('The thumbnail is empty.');
    if (file.size > kTrainingMaxThumbnailMb * 1024 * 1024) {
      throw const ValidationException('The thumbnail must be $kTrainingMaxThumbnailMb MB or smaller.');
    }
    return _ds.uploadThumbnail(course.id, file);
  }

  Future<List<TrainingAssessmentOption>> assessmentOptions() {
    _require(_access.canManageAssessments);
    return _ds.fetchAssessmentOptions();
  }

  Future<TrainingMaterial> addMaterial(TrainingCourse course, TrainingMaterialDraft draft,
      {void Function(int percent)? onProgress}) {
    _require(_access.canEdit && !course.archived);
    if (!draft.isValid) {
      throw ValidationException(
          [draft.titleError, draft.sourceError, draft.lengthError].firstWhere((e) => e.isNotEmpty));
    }
    return _ds.addMaterial(course.id, draft, onProgress: onProgress);
  }

  Future<TrainingMaterial> updateMaterial(TrainingCourse course, TrainingMaterial m, Map<String, dynamic> body) {
    _require(_access.canEdit && !course.archived);
    return _ds.updateMaterial(m.id, body);
  }

  Future<String> removeMaterial(TrainingCourse course, TrainingMaterial m) {
    _require(_access.canEdit && !course.archived);
    return _ds.deleteMaterial(m.id);
  }

  /// Swaps material [index] with its neighbour ([delta] −1 / +1) and sends
  /// the full order (the server wants every active material exactly once).
  Future<void> moveMaterial(TrainingCourse course, int index, int delta) {
    _require(_access.canEdit && !course.archived);
    final ids = [for (final m in course.materials ?? const <TrainingMaterial>[]) m.id];
    final j = index + delta;
    if (index < 0 || index >= ids.length || j < 0 || j >= ids.length) return Future.value();
    final t = ids[index];
    ids[index] = ids[j];
    ids[j] = t;
    return _ds.reorderMaterials(course.id, ids);
  }

  Future<String> deleteCourse(TrainingCourse course) {
    _require(_access.canDelete && !course.archived);
    return _ds.deleteCourse(course.id);
  }

  Future<String> assign(TrainingCourse course, AssignRequest request) {
    _require(_access.canAssign && !course.archived);
    if (!course.isActive) throw const ValidationException('Only an active course can be assigned.');
    if (!request.isReady) throw const ValidationException('Choose employees, departments, branches or everyone.');
    return _ds.assign(course.id, request);
  }

  Future<String> removeAssignment(TrainingAssignmentRow row) {
    _require(_access.canAssign);
    return _ds.removeAssignment(row.id);
  }

  Future<String> resetAttempts(TrainingAssignmentRow row) {
    _require(_access.canResetAttempts);
    return _ds.resetAssessment(row.id);
  }

  Future<Uint8List> exportCsv(TrainingReportFilter filter) {
    _require(_access.canViewReports);
    return _ds.exportReportCsv(filter);
  }
}

final trainingAdminActionsProvider = Provider.autoDispose<TrainingAdminActions>((ref) => TrainingAdminActions(
      ref.watch(trainingDatasourceProvider),
      TrainingAccess(ref.watch(authStateProvider).valueOrNull?.user),
    ));

/// Assessments that can be linked (training.manage_assessments only).
final trainingAssessmentOptionsProvider = FutureProvider.autoDispose<List<TrainingAssessmentOption>>(
  (ref) => ref.watch(trainingAdminActionsProvider).assessmentOptions(),
);
