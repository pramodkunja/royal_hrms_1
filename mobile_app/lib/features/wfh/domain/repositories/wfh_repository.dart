import '../entities/wfh_entity.dart';

abstract class WfhRepository {
  Future<List<WfhRequestEntity>> getWfhRequests({String? status});

  Future<WfhRequestPageEntity> getWfhRequestsPaginated({
    String? status,
    String? scope, // 'team' or null (own)
    String? employeeId,
    int page = 1,
    int? pageSize,
  });

  Future<WfhRequestEntity> getWfhRequestById(String id);

  Future<WfhRequestEntity> createWfhRequest({
    required String startDate,
    required String endDate,
    String? reason,
    String? locationLabel,
    required double latitude,
    required double longitude,
  });

  Future<void> cancelWfhRequest(String id);

  Future<void> approveWfhRequest(String id, {String? remarks});
  Future<void> rejectWfhRequest(String id, {String? remarks});

  Future<List<WfhSavedLocationEntity>> getSavedLocations();
  Future<WfhSavedLocationEntity> createSavedLocation({
    required String label,
    required double latitude,
    required double longitude,
  });
  Future<void> deleteSavedLocation(String id);
}
