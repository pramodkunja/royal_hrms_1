import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/assessment_model.dart';
import '../models/assessment_portal_models.dart';
import '../models/my_assessment_model.dart';

class AssessmentsRemoteDataSource {
  final Dio _dio;
  AssessmentsRemoteDataSource(this._dio);

  // ── My assessments (employee self-service) ─────────────────────────────────

  /// GET /assessments/my/ — every assignment of the signed-in user, unpaged.
  Future<MyAssessments> fetchMyAssessments() async {
    final res = await _dio.get(ApiConstants.assessmentsMy);
    return MyAssessments.fromJson(_unwrap(res.data));
  }

  /// POST /assessments/<a>/respond/<item>/ — saves one response at once.
  /// Videos send no body; quizzes send the chosen option (a–d).
  Future<AssessmentRespondResult> respondToItem(
    String assignmentId,
    String itemId, {
    String? selectedOption,
  }) async {
    final res = await _dio.post(
      ApiConstants.assessmentRespond(assignmentId, itemId),
      data: selectedOption == null ? <String, dynamic>{} : {'selected_option': selectedOption},
    );
    return AssessmentRespondResult.fromJson(_unwrap(res.data));
  }

  /// POST /assessments/<a>/complete/ — the server grades the attempt.
  Future<AssessmentCompleteResult> completeAssessment(String assignmentId) async {
    final res = await _dio.post(ApiConstants.assessmentComplete(assignmentId));
    return AssessmentCompleteResult.fromJson(_unwrap(res.data));
  }

  /// POST /assessments/<a>/retry/ — resets a completed attempt.
  Future<void> retryAssessment(String assignmentId) async {
    await _dio.post(ApiConstants.assessmentRetry(assignmentId));
  }

  // ── Assessments ────────────────────────────────────────────────────────────

  Future<List<AssessmentModel>> fetchAssessments() async {
    final res = await _dio
        .get(ApiConstants.assessments, queryParameters: {'page_size': 100});
    final data = _unwrap(res.data);
    return _toList(data)
        .map((e) => AssessmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AssessmentModel> createAssessment(AssessmentFormData form) async {
    final res = await _dio.post(ApiConstants.assessments, data: form.toJson());
    return AssessmentModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<AssessmentModel> updateAssessment(
      String id, AssessmentFormData form) async {
    final res =
        await _dio.put(ApiConstants.assessmentDetail(id), data: form.toJson());
    return AssessmentModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteAssessment(String id) async {
    await _dio.delete(ApiConstants.assessmentDetail(id));
  }

  // ── Assessment items (video / quiz) ───────────────────────────────────────

  Future<List<AssessmentItemModel>> fetchItems(String assessmentId) async {
    final res = await _dio.get(ApiConstants.assessmentItems(assessmentId));
    final data = _unwrap(res.data);
    return _toList(data)
        .map((e) => AssessmentItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AssessmentItemModel> createItem(
      String assessmentId, AssessmentItemFormData form) async {
    final res = await _dio.post(ApiConstants.assessmentItems(assessmentId),
        data: form.toJson());
    return AssessmentItemModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<AssessmentItemModel> updateItem(
      String itemId, AssessmentItemFormData form) async {
    final res = await _dio.put(ApiConstants.assessmentItemDetail(itemId),
        data: form.toJson());
    return AssessmentItemModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteItem(String itemId) async {
    await _dio.delete(ApiConstants.assessmentItemDetail(itemId));
  }

  // ── Assessment sections (web ItemsModal) ──────────────────────────────────

  Future<List<AssessmentSectionModel>> fetchSections(String assessmentId) async {
    final res = await _dio.get(ApiConstants.assessmentSections(assessmentId));
    return _toList(_unwrap(res.data))
        .whereType<Map>()
        .map((e) => AssessmentSectionModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> createSection(String assessmentId, AssessmentSectionFormData form) async {
    await _dio.post(ApiConstants.assessmentSections(assessmentId), data: form.toJson());
  }

  Future<void> updateSection(String assessmentId, String sectionId, AssessmentSectionFormData form) async {
    await _dio.put(ApiConstants.assessmentSectionDetail(assessmentId, sectionId), data: form.toJson());
  }

  Future<void> deleteSection(String assessmentId, String sectionId) async {
    await _dio.delete(ApiConstants.assessmentSectionDetail(assessmentId, sectionId));
  }

  // ── Assign ─────────────────────────────────────────────────────────────────

  Future<void> assignAssessment({
    required String candidateId,
    required String assessmentId,
    required String templateName,
  }) async {
    await _dio.post(ApiConstants.assessmentAssign, data: {
      'candidate_id': candidateId,
      'assessment_id': assessmentId,
      'template_name': templateName,
    });
  }

  // ── Employees (for Assign checklist) ──────────────────────────────────────
  // The backend caps page_size at 50 (EmployeeListCreateView) regardless of
  // what's requested — matches web's own (unavoidable) limitation exactly.

  Future<List<AssignableEmployeeModel>> fetchAssignableEmployees() async {
    final res = await _dio
        .get(ApiConstants.employees, queryParameters: {'page_size': 50});
    final data = _unwrap(res.data);
    return _toList(data)
        .map((e) => AssignableEmployeeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EmailTemplateOptionModel>> fetchEmailTemplateOptions() async {
    final res = await _dio.get(ApiConstants.assessmentEmailTemplateOptions);
    final data = _unwrap(res.data);
    return _toList(data)
        .map((e) => EmailTemplateOptionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  // Backend envelope: {status: "success"|"error", message: "...", data: ...}
  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data')) return body['data'];
    }
    return body;
  }

  // Assessment list is paginated ({count, page, results:[...]}); the items
  // endpoint returns a plain array. Handle both shapes.
  List<dynamic> _toList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      return data['results'] as List<dynamic>? ?? [];
    }
    return [];
  }
}
