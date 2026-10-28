import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/separation_models.dart';

class SeparationRemoteDataSource {
  final Dio _dio;
  SeparationRemoteDataSource(this._dio);

  dynamic _unwrap(dynamic body) {
    if (body is Map && body['data'] != null) return body['data'];
    return body;
  }

  List<Map<String, dynamic>> _asMapList(dynamic data) {
    final list = data is List ? data : const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  // ── Lookups ─────────────────────────────────────────────────────────────

  Future<List<SeparationLookupOptionModel>> fetchTypes() async {
    final res = await _dio.get(ApiConstants.separationTypes);
    return _asMapList(_unwrap(res.data))
        .map(SeparationLookupOptionModel.fromJson)
        .toList();
  }

  Future<List<SeparationLookupOptionModel>> fetchReasons() async {
    final res = await _dio.get(ApiConstants.separationReasons);
    return _asMapList(_unwrap(res.data))
        .map(SeparationLookupOptionModel.fromJson)
        .toList();
  }

  // ── Requests ────────────────────────────────────────────────────────────

  // scope: omit for "my own requests" (the backend default for any role).
  // Pass 'team' to get the real approval queue instead — only effective when
  // the viewer holds separation.approve/settings.edit server-side (see
  // apps/hrms/views/separation.py _approval_scope_filter); otherwise the
  // backend silently falls back to "own requests" regardless of the param.
  // employeeId (human-readable code) is for the admin Employee Profile
  // "Separation" tab equivalent — requires employees.view or separation.approve.
  Future<SeparationRequestPageModel> fetchRequests({
    String? status,
    String? scope,
    String? employeeId,
    String? separationType,
    int page = 1,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (status != null) params['status'] = status;
    if (scope != null) params['scope'] = scope;
    if (employeeId != null) params['employee_id'] = employeeId;
    if (separationType != null) params['separation_type'] = separationType;
    final res = await _dio.get(ApiConstants.separationRequests,
        queryParameters: params);
    return SeparationRequestPageModel.fromJson(_unwrap(res.data));
  }

  Future<SeparationRequestModel> fetchRequestById(String id) async {
    final res = await _dio.get(ApiConstants.separationRequestDetail(id));
    return SeparationRequestModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  // employeeId (code): only honored server-side when the caller holds
  // employees.view AND differs from their own code — files for self
  // otherwise (see SeparationRequestListCreateView.post).
  Future<SeparationRequestModel> createRequest({
    required String separationType,
    required String reason,
    required String requestDate,
    required String proposedLastWorkingDay,
    required int noticePeriodDays,
    String? comments,
    String? employeeId,
    MultipartFile? document,
  }) async {
    final formData = FormData.fromMap({
      'separation_type': separationType,
      'reason': reason,
      'request_date': requestDate,
      'proposed_last_working_day': proposedLastWorkingDay,
      'notice_period_days': noticePeriodDays,
      if (comments != null && comments.isNotEmpty) 'comments': comments,
      if (employeeId != null && employeeId.isNotEmpty)
        'employee_id': employeeId,
      if (document != null) 'document': document,
    });
    final res =
        await _dio.post(ApiConstants.separationRequests, data: formData);
    return SeparationRequestModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<SeparationRequestModel> updateRequest({
    required String id,
    required String separationType,
    required String reason,
    required String requestDate,
    required String proposedLastWorkingDay,
    required int noticePeriodDays,
    String? comments,
    MultipartFile? document,
  }) async {
    final formData = FormData.fromMap({
      'action': 'update',
      'separation_type': separationType,
      'reason': reason,
      'request_date': requestDate,
      'proposed_last_working_day': proposedLastWorkingDay,
      'notice_period_days': noticePeriodDays,
      if (comments != null) 'comments': comments,
      if (document != null) 'document': document,
    });
    final res = await _dio.patch(ApiConstants.separationRequestDetail(id),
        data: formData);
    return SeparationRequestModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> cancelRequest(String id) async {
    await _dio.patch(ApiConstants.separationRequestDetail(id),
        data: {'action': 'cancel'});
  }

  // HR-only hard delete of a not-yet-approved request (mapped to the "Reject"
  // action on the list/detail — see web's SeparationTable/detail page, both
  // of which send DELETE for what the UI labels "Reject").
  Future<void> deleteRequest(String id) async {
    await _dio.delete(ApiConstants.separationRequestDetail(id));
  }

  // ── Approval stages ─────────────────────────────────────────────────────

  Future<SeparationRequestModel> actionStage({
    required String requestId,
    required String stageId,
    required String action, // 'approve' | 'reject'
    String? remarks,
  }) async {
    final res = await _dio.post(
      ApiConstants.separationStageAction(requestId, stageId),
      data: {
        'action': action,
        if (remarks != null) 'remarks': remarks,
      },
    );
    return SeparationRequestModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  // ── KT / Handover tasks ─────────────────────────────────────────────────

  Future<List<SeparationHandoverTaskModel>> fetchTasks(
      String requestId) async {
    final res = await _dio.get(ApiConstants.separationTasks(requestId));
    return _asMapList(_unwrap(res.data))
        .map(SeparationHandoverTaskModel.fromJson)
        .toList();
  }

  // assignedTo must be the real User UUID (EmployeePickerOption.uuid), not
  // the employee_id code — matches SeparationHandoverTaskCreateSerializer's
  // default PrimaryKeyRelatedField for assigned_to.
  Future<SeparationHandoverTaskModel> createTask({
    required String requestId,
    required String task,
    String? description,
    String? assignedTo,
    String? dueDate,
  }) async {
    final res = await _dio.post(
      ApiConstants.separationTasks(requestId),
      data: {
        'task': task,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (assignedTo != null && assignedTo.isNotEmpty)
          'assigned_to': assignedTo,
        if (dueDate != null && dueDate.isNotEmpty) 'due_date': dueDate,
      },
    );
    return SeparationHandoverTaskModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> setTaskCompletion({
    required String requestId,
    required String taskId,
    required bool isCompleted,
  }) async {
    await _dio.patch(
      ApiConstants.separationTaskDetail(requestId, taskId),
      data: {'is_completed': isCompleted},
    );
  }

  Future<void> deleteTask({
    required String requestId,
    required String taskId,
  }) async {
    await _dio.delete(ApiConstants.separationTaskDetail(requestId, taskId));
  }

  // ── Clearances ──────────────────────────────────────────────────────────

  Future<List<SeparationClearanceModel>> fetchClearances(
      String requestId) async {
    final res = await _dio.get(ApiConstants.separationClearances(requestId));
    return _asMapList(_unwrap(res.data))
        .map(SeparationClearanceModel.fromJson)
        .toList();
  }

  Future<SeparationClearanceModel> actionClearance({
    required String requestId,
    required String clearanceId,
    required String action, // 'approve' | 'reject'
    String? remarks,
  }) async {
    final res = await _dio.post(
      ApiConstants.separationClearanceAction(requestId, clearanceId),
      data: {
        'action': action,
        if (remarks != null) 'remarks': remarks,
      },
    );
    return SeparationClearanceModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  // ── Documents ───────────────────────────────────────────────────────────

  Future<List<SeparationDocumentModel>> fetchDocuments(
      String requestId) async {
    final res = await _dio.get(ApiConstants.separationDocuments(requestId));
    return _asMapList(_unwrap(res.data))
        .map(SeparationDocumentModel.fromJson)
        .toList();
  }

  Future<SeparationDocumentModel> uploadDocument({
    required String requestId,
    required String documentType,
    required MultipartFile file,
  }) async {
    final formData = FormData.fromMap({
      'document_type': documentType,
      'file': file,
    });
    final res = await _dio.post(
      ApiConstants.separationDocuments(requestId),
      data: formData,
    );
    return SeparationDocumentModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteDocument({
    required String requestId,
    required String documentId,
  }) async {
    await _dio
        .delete(ApiConstants.separationDocumentDetail(requestId, documentId));
  }

  // ── Activity log ────────────────────────────────────────────────────────

  Future<List<SeparationActivityModel>> fetchActivities(
      String requestId) async {
    final res = await _dio.get(ApiConstants.separationActivities(requestId));
    return _asMapList(_unwrap(res.data))
        .map(SeparationActivityModel.fromJson)
        .toList();
  }

  // ── Employee search (for the employee_id / assigned_to pickers) ─────────

  // Mirrors web's EmployeePickerField — hits the real, already role-scoped
  // /employees/ directory (managers see only direct reports, HR/admin see
  // everyone/branch — see EmployeeListCreateView.get). Only meaningful for
  // callers holding employees.view; a 403 there means the viewer isn't
  // meant to see this picker at all (mirrors web's canPickEmployee gate).
  // ownSeparationRequestId widens a manager/HR's own picker beyond their
  // team when assigning their OWN separation's handover task (see
  // EmployeeListCreateView.get's own_separation_request handling).
  Future<List<EmployeePickerOptionModel>> searchEmployees(
    String query, {
    String? ownSeparationRequestId,
  }) async {
    final res = await _dio.get(ApiConstants.employees, queryParameters: {
      'search': query,
      'page_size': 8,
      if (ownSeparationRequestId != null)
        'own_separation_request': ownSeparationRequestId,
    });
    final data = _unwrap(res.data);
    final list = data is Map<String, dynamic>
        ? (data['results'] as List<dynamic>? ?? [])
        : (data is List ? data : const []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(EmployeePickerOptionModel.fromJson)
        .toList();
  }
}
