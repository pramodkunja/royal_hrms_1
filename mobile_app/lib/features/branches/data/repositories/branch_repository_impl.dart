import '../../domain/branch_geofence.dart';
import '../../domain/entities/branch_entity.dart';
import '../../domain/repositories/branch_repository.dart';
import '../datasources/branch_remote_datasource.dart';

class BranchRepositoryImpl implements BranchRepository {
  final BranchRemoteDataSource _dataSource;
  BranchRepositoryImpl(this._dataSource);

  @override
  Future<List<StateEntity>> getStates() => _dataSource.fetchStates();

  @override
  Future<List<CityEntity>> getCities(int stateId) =>
      _dataSource.fetchCities(stateId);

  @override
  Future<String> previewBranchCode({int? cityId, String? cityName}) =>
      _dataSource.fetchPreviewCode(cityId: cityId, cityName: cityName);

  @override
  Future<BranchStatsEntity> getStats() => _dataSource.fetchStats();

  @override
  Future<List<BranchDistributionEntity>> getDistribution() =>
      _dataSource.fetchDistribution();

  @override
  Future<List<BranchEntity>> getBranches({
    int page = 1,
    int pageSize = 50,
  }) =>
      _dataSource.fetchBranches(page: page, pageSize: pageSize);

  @override
  Future<BranchEntity> createBranch({
    int? cityId,
    String? newCityName,
    required int stateId,
    required String branchName,
    required String address,
    required String status,
    required bool isHeadquarter,
    BranchGeofence? geofence,
  }) =>
      _dataSource.createBranch({
        // Web doSave: city, or new_city_name for the Other option — never both.
        if (newCityName != null) 'new_city_name': newCityName else 'city': cityId,
        'state': stateId,
        'branch_name': branchName,
        'address': address,
        'status': status,
        'is_headquarter': isHeadquarter,
        ...?geofence?.toPayload(),
      });

  @override
  Future<BranchEntity> updateBranch({
    required int id,
    int? cityId,
    String? newCityName,
    required int stateId,
    required String branchName,
    required String address,
    required String status,
    required bool isHeadquarter,
    BranchGeofence? geofence,
  }) =>
      _dataSource.updateBranch(id, {
        // Web doSave: city, or new_city_name for the Other option — never both.
        if (newCityName != null) 'new_city_name': newCityName else 'city': cityId,
        'state': stateId,
        'branch_name': branchName,
        'address': address,
        'status': status,
        'is_headquarter': isHeadquarter,
        ...?geofence?.toPayload(),
      });

  @override
  Future<void> deleteBranch(int id) => _dataSource.deleteBranch(id);
}
