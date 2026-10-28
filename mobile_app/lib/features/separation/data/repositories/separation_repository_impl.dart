import 'package:dio/dio.dart';
import '../../domain/entities/separation_entity.dart';
import '../../domain/repositories/separation_repository.dart';
import '../datasources/separation_remote_datasource.dart';

class SeparationRepositoryImpl implements SeparationRepository {
  final SeparationRemoteDataSource _ds;
  SeparationRepositoryImpl(this._ds);

  @override
  Future<List<SeparationLookupOption>> getTypes() => _ds.fetchTypes();

  @override
  Future<List<SeparationLookupOption>> getReasons() => _ds.fetchReasons();

  @override
  Future<SeparationRequestPageEntity> getRequests({
    String? status,
    String? scope,
    String? employeeId,
    String? separationType,
    int page = 1,
  }) =>
      _ds.fetchRequests(
        status: status,
        scope: scope,
        employeeId: employeeId,
        separationType: separationType,
        page: page,
      );

  @override
  Future<SeparationRequestEntity> getRequestById(String id) =>
      _ds.fetchRequestById(id);

  @override
  Future<SeparationRequestEntity> createRequest({
    required String separationType,
    required String reason,
    required String requestDate,
    required String proposedLastWorkingDay,
    required int noticePeriodDays,
    String? comments,
    String? employeeId,
    MultipartFile? document,
  }) =>
      _ds.createRequest(
        separationType: separationType,
        reason: reason,
        requestDate: requestDate,
        proposedLastWorkingDay: proposedLastWorkingDay,
        noticePeriodDays: noticePeriodDays,
        comments: comments,
        employeeId: employeeId,
        document: document,
      );

  @override
  Future<SeparationRequestEntity> updateRequest({
    required String id,
    required String separationType,
    required String reason,
    required String requestDate,
    required String proposedLastWorkingDay,
    required int noticePeriodDays,
    String? comments,
    MultipartFile? document,
  }) =>
      _ds.updateRequest(
        id: id,
        separationType: separationType,
        reason: reason,
        requestDate: requestDate,
        proposedLastWorkingDay: proposedLastWorkingDay,
        noticePeriodDays: noticePeriodDays,
        comments: comments,
        document: document,
      );

  @override
  Future<void> cancelRequest(String id) => _ds.cancelRequest(id);

  @override
  Future<void> deleteRequest(String id) => _ds.deleteRequest(id);

  @override
  Future<SeparationRequestEntity> actionStage({
    required String requestId,
    required String stageId,
    required String action,
    String? remarks,
  }) =>
      _ds.actionStage(
        requestId: requestId,
        stageId: stageId,
        action: action,
        remarks: remarks,
      );

  @override
  Future<List<SeparationHandoverTaskEntity>> getTasks(String requestId) =>
      _ds.fetchTasks(requestId);

  @override
  Future<SeparationHandoverTaskEntity> createTask({
    required String requestId,
    required String task,
    String? description,
    String? assignedTo,
    String? dueDate,
  }) =>
      _ds.createTask(
        requestId: requestId,
        task: task,
        description: description,
        assignedTo: assignedTo,
        dueDate: dueDate,
      );

  @override
  Future<void> setTaskCompletion({
    required String requestId,
    required String taskId,
    required bool isCompleted,
  }) =>
      _ds.setTaskCompletion(
        requestId: requestId,
        taskId: taskId,
        isCompleted: isCompleted,
      );

  @override
  Future<void> deleteTask({required String requestId, required String taskId}) =>
      _ds.deleteTask(requestId: requestId, taskId: taskId);

  @override
  Future<List<SeparationClearanceEntity>> getClearances(String requestId) =>
      _ds.fetchClearances(requestId);

  @override
  Future<SeparationClearanceEntity> actionClearance({
    required String requestId,
    required String clearanceId,
    required String action,
    String? remarks,
  }) =>
      _ds.actionClearance(
        requestId: requestId,
        clearanceId: clearanceId,
        action: action,
        remarks: remarks,
      );

  @override
  Future<List<SeparationDocumentEntity>> getDocuments(String requestId) =>
      _ds.fetchDocuments(requestId);

  @override
  Future<SeparationDocumentEntity> uploadDocument({
    required String requestId,
    required String documentType,
    required MultipartFile file,
  }) =>
      _ds.uploadDocument(
          requestId: requestId, documentType: documentType, file: file);

  @override
  Future<void> deleteDocument(
          {required String requestId, required String documentId}) =>
      _ds.deleteDocument(requestId: requestId, documentId: documentId);

  @override
  Future<List<SeparationActivityEntity>> getActivities(String requestId) =>
      _ds.fetchActivities(requestId);

  @override
  Future<List<EmployeePickerOption>> searchEmployees(
    String query, {
    String? ownSeparationRequestId,
  }) =>
      _ds.searchEmployees(query,
          ownSeparationRequestId: ownSeparationRequestId);
}
