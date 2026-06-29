import '../entities/branch_entity.dart';

abstract class BranchRepository {
  Future<List<StateEntity>> getStates();

  Future<List<CityEntity>> getCities(int stateId);

  Future<String> previewBranchCode(int cityId);

  Future<BranchStatsEntity> getStats();

  Future<List<BranchEntity>> getBranches({int page = 1, int pageSize = 50});

  Future<BranchEntity> createBranch({
    required int cityId,
    required int stateId,
    required String branchName,
    required String address,
    required String status,
    required bool isHeadquarter,
  });

  Future<BranchEntity> updateBranch({
    required int id,
    required int cityId,
    required int stateId,
    required String branchName,
    required String address,
    required String status,
    required bool isHeadquarter,
  });

  Future<void> deleteBranch(int id);
}
