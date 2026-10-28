import '../../domain/entities/wfh_entity.dart';
import '../../domain/repositories/wfh_repository.dart';
import '../datasources/wfh_remote_datasource.dart';

class WfhRepositoryImpl implements WfhRepository {
  final WfhRemoteDataSource _ds;
  WfhRepositoryImpl(this._ds);

  @override
  Future<List<WfhRequestEntity>> getWfhRequests({String? status}) =>
      _ds.fetchWfhRequests(status: status);

  @override
  Future<WfhRequestPageEntity> getWfhRequestsPaginated({
    String? status,
    String? scope,
    String? employeeId,
    int page = 1,
    int? pageSize,
  }) =>
      _ds.fetchWfhRequestsPage(
        status: status,
        scope: scope,
        employeeId: employeeId,
        page: page,
        pageSize: pageSize,
      );

  @override
  Future<WfhRequestEntity> getWfhRequestById(String id) =>
      _ds.fetchWfhRequestById(id);

  @override
  Future<WfhRequestEntity> createWfhRequest({
    required String startDate,
    required String endDate,
    String? reason,
    String? locationLabel,
    required double latitude,
    required double longitude,
  }) =>
      _ds.createWfhRequest(
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        locationLabel: locationLabel,
        latitude: latitude,
        longitude: longitude,
      );

  @override
  Future<void> cancelWfhRequest(String id) => _ds.cancelWfhRequest(id);

  @override
  Future<void> approveWfhRequest(String id, {String? remarks}) =>
      _ds.approveWfhRequest(id, remarks: remarks);

  @override
  Future<void> rejectWfhRequest(String id, {String? remarks}) =>
      _ds.rejectWfhRequest(id, remarks: remarks);

  @override
  Future<List<WfhSavedLocationEntity>> getSavedLocations() =>
      _ds.fetchSavedLocations();

  @override
  Future<WfhSavedLocationEntity> createSavedLocation({
    required String label,
    required double latitude,
    required double longitude,
  }) =>
      _ds.createSavedLocation(
        label: label,
        latitude: latitude,
        longitude: longitude,
      );

  @override
  Future<void> deleteSavedLocation(String id) => _ds.deleteSavedLocation(id);
}
