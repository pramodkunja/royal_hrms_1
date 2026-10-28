import 'package:dio/dio.dart';
import '../entities/separation_entity.dart';

abstract class SeparationRepository {
  Future<List<SeparationLookupOption>> getTypes();
  Future<List<SeparationLookupOption>> getReasons();

  Future<SeparationRequestPageEntity> getRequests({
    String? status,
    String? scope,
    String? employeeId,
    String? separationType,
    int page = 1,
  });

  Future<SeparationRequestEntity> getRequestById(String id);

  Future<SeparationRequestEntity> createRequest({
    required String separationType,
    required String reason,
    required String requestDate,
    required String proposedLastWorkingDay,
    required int noticePeriodDays,
    String? comments,
    String? employeeId,
    MultipartFile? document,
  });

  Future<SeparationRequestEntity> updateRequest({
    required String id,
    required String separationType,
    required String reason,
    required String requestDate,
    required String proposedLastWorkingDay,
    required int noticePeriodDays,
    String? comments,
    MultipartFile? document,
  });

  Future<void> cancelRequest(String id);
  Future<void> deleteRequest(String id);

  Future<SeparationRequestEntity> actionStage({
    required String requestId,
    required String stageId,
    required String action,
    String? remarks,
  });

  Future<List<SeparationHandoverTaskEntity>> getTasks(String requestId);
  Future<SeparationHandoverTaskEntity> createTask({
    required String requestId,
    required String task,
    String? description,
    String? assignedTo,
    String? dueDate,
  });
  Future<void> setTaskCompletion({
    required String requestId,
    required String taskId,
    required bool isCompleted,
  });
  Future<void> deleteTask({required String requestId, required String taskId});

  Future<List<SeparationClearanceEntity>> getClearances(String requestId);
  Future<SeparationClearanceEntity> actionClearance({
    required String requestId,
    required String clearanceId,
    required String action,
    String? remarks,
  });

  Future<List<SeparationDocumentEntity>> getDocuments(String requestId);
  Future<SeparationDocumentEntity> uploadDocument({
    required String requestId,
    required String documentType,
    required MultipartFile file,
  });
  Future<void> deleteDocument(
      {required String requestId, required String documentId});

  Future<List<SeparationActivityEntity>> getActivities(String requestId);

  Future<List<EmployeePickerOption>> searchEmployees(
    String query, {
    String? ownSeparationRequestId,
  });
}
