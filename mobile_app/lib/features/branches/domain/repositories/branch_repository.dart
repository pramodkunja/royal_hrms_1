import '../branch_geofence.dart';
import '../entities/branch_entity.dart';

abstract class BranchRepository {
  Future<List<StateEntity>> getStates();

  Future<List<CityEntity>> getCities(int stateId);

  Future<String> previewBranchCode({int? cityId, String? cityName});

  Future<BranchStatsEntity> getStats();

  Future<List<BranchDistributionEntity>> getDistribution();

  Future<List<BranchEntity>> getBranches({int page = 1, int pageSize = 50});

  Future<BranchEntity> createBranch({
    int? cityId,
    String? newCityName,
    required int stateId,
    required String branchName,
    required String address,
    required String status,
    required bool isHeadquarter,
    BranchGeofence? geofence,
  });

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
  });

  Future<void> deleteBranch(int id);
}
