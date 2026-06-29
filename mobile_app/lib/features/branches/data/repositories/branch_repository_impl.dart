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
  Future<String> previewBranchCode(int cityId) =>
      _dataSource.fetchPreviewCode(cityId);

  @override
  Future<BranchStatsEntity> getStats() => _dataSource.fetchStats();

  @override
  Future<List<BranchEntity>> getBranches({
    int page = 1,
    int pageSize = 50,
  }) =>
      _dataSource.fetchBranches(page: page, pageSize: pageSize);

  @override
  Future<BranchEntity> createBranch({
    required int cityId,
    required int stateId,
    required String branchName,
    required String address,
    required String status,
    required bool isHeadquarter,
  }) =>
      _dataSource.createBranch({
        'city': cityId,
        'state': stateId,
        'branch_name': branchName,
        'address': address,
        'status': status,
        'is_headquarter': isHeadquarter,
      });

  @override
  Future<BranchEntity> updateBranch({
    required int id,
    required int cityId,
    required int stateId,
    required String branchName,
    required String address,
    required String status,
    required bool isHeadquarter,
  }) =>
      _dataSource.updateBranch(id, {
        'city': cityId,
        'state': stateId,
        'branch_name': branchName,
        'address': address,
        'status': status,
        'is_headquarter': isHeadquarter,
      });

  @override
  Future<void> deleteBranch(int id) => _dataSource.deleteBranch(id);
}
