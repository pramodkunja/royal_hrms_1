import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/training_models.dart';

/// Training & Learning admin endpoints (backend apps/training/views.py).
/// The backend checks every permission and scope itself; failures are
/// rethrown as the app's typed exceptions with the server's own message
/// (parseDioException), e.g. 403 "You do not have permission…" or the
/// module-disabled 403.
class TrainingRemoteDatasource {
  const TrainingRemoteDatasource(this._dio);
  final Dio _dio;

  static Object? _data(Object? body) => body is Map && body.containsKey('data') ? body['data'] : body;
  static List<Map<String, dynamic>> _rows(Object? body) {
    final d = _data(body);
    return [for (final r in (d is List ? d : const []).whereType<Map>()) r.cast<String, dynamic>()];
  }

  static Map<String, dynamic> _obj(Object? body) {
    final d = _data(body);
    return d is Map ? d.cast<String, dynamic>() : const {};
  }

  static String _message(Object? body, String fallback) =>
      body is Map && body['message'] is String && (body['message'] as String).isNotEmpty
          ? body['message'] as String
          : fallback;

  Future<T> _call<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw parseDioException(e);
    }
  }

  /// GET dashboard/ — view_reports or a progress scope; 403 otherwise.
  Future<TrainingDashboard> fetchDashboard() => _call(() async {
        final res = await _dio.get(ApiConstants.trainingDashboard);
        return TrainingDashboard.fromJson(_obj(res.data));
      });

  /// GET courses/?archived=0|1 — training.view. archived=1 includes archived
  /// courses alongside the rest (web "Show archived").
  Future<List<TrainingCourse>> fetchCourses({bool archived = false}) => _call(() async {
        final res = await _dio.get(ApiConstants.trainingCourses, queryParameters: {'archived': archived ? 1 : 0});
        return [for (final r in _rows(res.data)) TrainingCourse.fromJson(r)];
      });

  /// GET courses/<id>/ — training.view; includes active materials.
  Future<TrainingCourse> fetchCourse(String id) => _call(() async {
        final res = await _dio.get(ApiConstants.trainingCourse(id));
        return TrainingCourse.fromJson(_obj(res.data));
      });

  /// GET courses/<id>/progress/ — the viewer's scope only.
  Future<List<TrainingAssignmentRow>> fetchProgress(String courseId) => _call(() async {
        final res = await _dio.get(ApiConstants.trainingCourseProgress(courseId));
        return [for (final r in _rows(res.data)) TrainingAssignmentRow.fromJson(r)];
      });

  /// GET reports/ with filters — training.view_reports.
  Future<List<TrainingAssignmentRow>> fetchReport(TrainingReportFilter filter) => _call(() async {
        final res = await _dio.get(ApiConstants.trainingReports, queryParameters: filter.toQuery());
        return [for (final r in _rows(res.data)) TrainingAssignmentRow.fromJson(r)];
      });

  /// GET employees/?search= — training.assign; scoped to the assigner.
  Future<TrainingPicker> fetchPicker({String search = ''}) => _call(() async {
        final q = search.trim();
        final res = await _dio.get(ApiConstants.trainingEmployees, queryParameters: q.isEmpty ? null : {'search': q});
        return TrainingPicker.fromJson(_obj(res.data));
      });

  /// POST courses/<id>/assign/ — returns the server's summary message
  /// ("Assigned to N employee(s). M already had this course.").
  Future<String> assign(String courseId, AssignRequest request) => _call(() async {
        final res = await _dio.post(ApiConstants.trainingCourseAssign(courseId), data: request.toJson());
        return _message(res.data, 'Course assigned.');
      });

  /// DELETE assignments/<id>/ — only while not started (409 otherwise).
  Future<String> removeAssignment(String assignmentId) => _call(() async {
        final res = await _dio.delete(ApiConstants.trainingAssignment(assignmentId));
        return _message(res.data, 'Assignment removed.');
      });

  /// POST assignments/<id>/reset-assessment/ — manage_assessments; failed only.
  Future<String> resetAssessment(String assignmentId) => _call(() async {
        final res = await _dio.post(ApiConstants.trainingResetAssessment(assignmentId));
        return _message(res.data, 'Assessment attempts reset.');
      });

  /// DELETE courses/<id>/ — training.delete. A course with history is
  /// archived instead; the server's message says which happened.
  Future<String> deleteCourse(String courseId) => _call(() async {
        final res = await _dio.delete(ApiConstants.trainingCourse(courseId));
        return _message(res.data, 'Course deleted.');
      });

  /// GET materials/<id>/file/ — the document bytes and content type.
  /// Read-only: fetching the file records no progress (backend
  /// MaterialFileView only checks access).
  Future<({Uint8List bytes, String? contentType})> fetchMaterialFile(String materialId) => _call(() async {
        final res = await _dio.get<List<int>>(ApiConstants.trainingMaterialFile(materialId),
            options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 60)));
        return (bytes: Uint8List.fromList(res.data ?? const []), contentType: res.headers.value('content-type'));
      });

  // ── My Learning (employee) ────────────────────────────────────────────────

  /// GET my/ — the caller's own assignments (read-only).
  Future<List<MyTraining>> fetchMy() => _call(() async {
        final res = await _dio.get(ApiConstants.trainingMy);
        return [for (final r in _rows(res.data)) MyTraining.fromJson(r)];
      });

  /// GET my/<id>/ — one assignment with materials and assessment state.
  /// Read-only (MyTrainingDetailView writes nothing).
  Future<MyTraining> fetchMyDetail(String assignmentId) => _call(() async {
        final res = await _dio.get(ApiConstants.trainingMyDetail(assignmentId));
        return MyTraining.fromJson(_obj(res.data));
      });

  /// POST my/<id>/materials/<mid>/open|progress|confirm/ — WRITES progress.
  ///  - open: records opened_at and marks the course started;
  ///  - progress: a playback report {position, duration} (tracked videos);
  ///  - confirm: document read / untracked video watched.
  Future<TrainingMaterialActionResult> materialAction(
    String assignmentId,
    String materialId,
    String action, {
    double? position,
    double? duration,
  }) =>
      _call(() async {
        assert(const {'open', 'progress', 'confirm'}.contains(action));
        final res = await _dio.post(
          ApiConstants.trainingMyMaterial(assignmentId, materialId, action),
          data: action == 'progress' ? {'position': position ?? 0, 'duration': duration} : <String, dynamic>{},
        );
        final d = _obj(res.data);
        final a = d['assessment'];
        return TrainingMaterialActionResult(
          material: TrainingMaterial.fromJson(
              d['material'] is Map ? (d['material'] as Map).cast<String, dynamic>() : const {}),
          status: TrainingStatus.parse(d['status']),
          assessment: a is Map ? TrainingAssessmentState.fromJson(a.cast<String, dynamic>()) : null,
        );
      });

  /// POST my/<id>/assessment/start/ — WRITES (opens an attempt).
  Future<TrainingAttempt> startAssessment(String assignmentId) => _call(() async {
        final res = await _dio.post(ApiConstants.trainingMyAssessment(assignmentId, 'start'));
        final d = _obj(res.data);
        return TrainingAttempt(
          attemptNumber: (d['attempt_number'] as num?)?.toInt() ?? 0,
          timeLimitMins: (d['time_limit_mins'] as num?)?.toInt(),
          questions: [
            for (final q in (d['questions'] is List ? d['questions'] as List : const []).whereType<Map>())
              TrainingQuestion.fromJson(q.cast<String, dynamic>()),
          ],
        );
      });

  /// POST my/<id>/assessment/submit/ {answers: {question id: option key}} —
  /// WRITES (scored by the server).
  Future<TrainingAssessmentResult> submitAssessment(String assignmentId, Map<String, String> answers) =>
      _call(() async {
        final res =
            await _dio.post(ApiConstants.trainingMyAssessment(assignmentId, 'submit'), data: {'answers': answers});
        final d = _obj(res.data);
        final a = d['assessment'];
        return TrainingAssessmentResult(
          percentage: (d['percentage'] as num?)?.toInt() ?? 0,
          passPercentage: (d['pass_percentage'] as num?)?.toInt() ?? 0,
          passed: d['passed'] == true,
          status: d['status'] == null ? null : TrainingStatus.parse(d['status']),
          assessment: a is Map ? TrainingAssessmentState.fromJson(a.cast<String, dynamic>()) : null,
        );
      });

  /// GET materials/<id>/video-source/ — a signed, private playback URL for an
  /// uploaded video (cloud storage), or null when the file is only streamed
  /// through the API. Read-only.
  Future<String?> fetchVideoSource(String materialId) => _call(() async {
        final res = await _dio.get(ApiConstants.trainingVideoSource(materialId));
        final url = _obj(res.data)['url'];
        return url is String && url.isNotEmpty ? url : null;
      });

  /// GET courses/<id>/thumbnail/file/ — image bytes (read-only).
  Future<Uint8List> fetchThumbnail(String courseId) => _call(() async {
        final res = await _dio.get<List<int>>(ApiConstants.trainingThumbnailFile(courseId),
            options: Options(responseType: ResponseType.bytes));
        return Uint8List.fromList(res.data ?? const []);
      });

  // ── Admin authoring (Task 90 batch 3) ─────────────────────────────────────
  // Callers go through TrainingAdminActions, which checks the permission
  // first; the backend checks it again.

  /// POST courses/ {title, category} — training.create. 201 → the course.
  Future<TrainingCourse> createCourse({required String title, String category = ''}) => _call(() async {
        final res = await _dio.post(ApiConstants.trainingCourses, data: {'title': title.trim(), 'category': category});
        return TrainingCourse.fromJson(_obj(res.data));
      });

  /// PATCH courses/<id>/ — training.edit (assessment: manage_assessments).
  Future<TrainingCourse> updateCourse(String id, Map<String, dynamic> payload) => _call(() async {
        final res = await _dio.patch(ApiConstants.trainingCourse(id), data: payload);
        return TrainingCourse.fromJson(_obj(res.data));
      });

  /// POST courses/<id>/thumbnail/ multipart `thumbnail` (PNG/JPG ≤ 2 MB).
  Future<void> uploadThumbnail(String id, TrainingUploadFile file) => _call(() async {
        await _dio.post(
          ApiConstants.trainingCourseThumbnail(id),
          data: FormData.fromMap({'thumbnail': MultipartFile.fromBytes(file.bytes, filename: file.name)}),
          options: Options(sendTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)),
        );
      });

  /// GET assessments/ — active assessments with MCQ questions
  /// (training.manage_assessments).
  Future<List<TrainingAssessmentOption>> fetchAssessmentOptions() => _call(() async {
        final res = await _dio.get(ApiConstants.trainingAssessmentOptions);
        return [for (final r in _rows(res.data)) TrainingAssessmentOption.fromJson(r)];
      });

  /// POST courses/<id>/materials/ — JSON for a video link, multipart (`file`)
  /// for a document / video upload. [onProgress] reports 0–100.
  Future<TrainingMaterial> addMaterial(String courseId, TrainingMaterialDraft d,
          {void Function(int percent)? onProgress}) =>
      _call(() async {
        final Response res;
        if (d.kind == 'external_video') {
          res = await _dio.post(ApiConstants.trainingCourseMaterials(courseId), data: d.linkPayload());
        } else {
          final f = d.file!;
          res = await _dio.post(
            ApiConstants.trainingCourseMaterials(courseId),
            data: FormData.fromMap({
              ...d.uploadFields(),
              'file': MultipartFile.fromBytes(f.bytes, filename: f.name),
            }),
            options: Options(sendTimeout: const Duration(minutes: 10), receiveTimeout: const Duration(minutes: 2)),
            onSendProgress: (sent, total) {
              if (onProgress != null && total > 0) onProgress((sent * 100 / total).round());
            },
          );
        }
        return TrainingMaterial.fromJson(_obj(res.data));
      });

  /// PATCH materials/<id>/ — e.g. {is_required}, {allow_manual_completion},
  /// {duration_seconds} (the fields web edits).
  Future<TrainingMaterial> updateMaterial(String materialId, Map<String, dynamic> body) => _call(() async {
        final res = await _dio.patch(ApiConstants.trainingMaterial(materialId), data: body);
        return TrainingMaterial.fromJson(_obj(res.data));
      });

  /// DELETE materials/<id>/ — archived when employees have progress on it.
  Future<String> deleteMaterial(String materialId) => _call(() async {
        final res = await _dio.delete(ApiConstants.trainingMaterial(materialId));
        return _message(res.data, 'Material removed.');
      });

  /// POST courses/<id>/materials/reorder/ {order: [every active id once]}.
  Future<void> reorderMaterials(String courseId, List<String> ids) => _call(() async {
        await _dio.post(ApiConstants.trainingCourseReorder(courseId), data: {'order': ids});
      });

  /// GET reports/?…&export=csv — the CSV bytes (training.view_reports).
  Future<Uint8List> exportReportCsv(TrainingReportFilter filter) => _call(() async {
        final res = await _dio.get<List<int>>(ApiConstants.trainingReports,
            queryParameters: {...filter.toQuery(), 'export': 'csv'},
            options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 60)));
        return Uint8List.fromList(res.data ?? const []);
      });
}
