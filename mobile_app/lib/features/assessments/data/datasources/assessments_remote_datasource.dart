import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/assessment_model.dart';

class AssessmentsRemoteDataSource {
  final Dio _dio;
  AssessmentsRemoteDataSource(this._dio);

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

  // ── Assign ─────────────────────────────────────────────────────────────────

  Future<void> assignAssessment({
    required int candidateId,
    required String assessmentId,
  }) async {
    await _dio.post(ApiConstants.assessmentAssign, data: {
      'candidate_id': candidateId,
      'assessment_id': assessmentId,
    });
  }

  // ── Candidates (for Assign dropdown) ──────────────────────────────────────

  Future<List<ReviewCandidateModel>> fetchReviewCandidates() async {
    final res = await _dio.get(ApiConstants.candidatesReview);
    final data = _unwrap(res.data);
    return _toList(data)
        .map((e) => ReviewCandidateModel.fromJson(e as Map<String, dynamic>))
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
