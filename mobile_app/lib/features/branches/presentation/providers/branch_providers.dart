import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/branch_remote_datasource.dart';
import '../../data/repositories/branch_repository_impl.dart';
import '../../domain/entities/branch_entity.dart';
import '../../domain/repositories/branch_repository.dart';

// ── Data source (stateless factory — kept alive) ──────────────────────────────

final branchDataSourceProvider = Provider<BranchRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return BranchRemoteDataSource(dio);
});

// ── Repository ────────────────────────────────────────────────────────────────

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepositoryImpl(ref.watch(branchDataSourceProvider));
});

// ── Stats ─────────────────────────────────────────────────────────────────────

final branchStatsProvider = AsyncNotifierProvider.autoDispose<
    BranchStatsNotifier, BranchStatsEntity>(BranchStatsNotifier.new);

class BranchStatsNotifier
    extends AutoDisposeAsyncNotifier<BranchStatsEntity> {
  BranchRepository get _repo => ref.read(branchRepositoryProvider);

  @override
  Future<BranchStatsEntity> build() => _repo.getStats();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getStats());
  }
}

// ── Branch list ───────────────────────────────────────────────────────────────

final branchListProvider = AsyncNotifierProvider.autoDispose<
    BranchListNotifier, List<BranchEntity>>(BranchListNotifier.new);

class BranchListNotifier
    extends AutoDisposeAsyncNotifier<List<BranchEntity>> {
  BranchRepository get _repo => ref.read(branchRepositoryProvider);

  @override
  Future<List<BranchEntity>> build() => _repo.getBranches();

  Future<String?> create({
    required int cityId,
    required int stateId,
    required String branchName,
    required String address,
    required String status,
    required bool isHeadquarter,
  }) async {
    try {
      final created = await _repo.createBranch(
        cityId: cityId,
        stateId: stateId,
        branchName: branchName,
        address: address,
        status: status,
        isHeadquarter: isHeadquarter,
      );
      state = AsyncData([...state.valueOrNull ?? [], created]);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> edit({
    required int id,
    required int cityId,
    required int stateId,
    required String branchName,
    required String address,
    required String status,
    required bool isHeadquarter,
  }) async {
    try {
      final updated = await _repo.updateBranch(
        id: id,
        cityId: cityId,
        stateId: stateId,
        branchName: branchName,
        address: address,
        status: status,
        isHeadquarter: isHeadquarter,
      );
      state = AsyncData(
        (state.valueOrNull ?? [])
            .map((b) => b.id == id ? updated : b)
            .toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> remove(int id) async {
    try {
      await _repo.deleteBranch(id);
      state = AsyncData(
        (state.valueOrNull ?? []).where((b) => b.id != id).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getBranches());
  }
}

// ── States dropdown ───────────────────────────────────────────────────────────

final statesProvider = AsyncNotifierProvider.autoDispose<StatesNotifier,
    List<StateEntity>>(StatesNotifier.new);

class StatesNotifier extends AutoDisposeAsyncNotifier<List<StateEntity>> {
  @override
  Future<List<StateEntity>> build() =>
      ref.read(branchRepositoryProvider).getStates();
}

// ── Cities dropdown (family — one per selected stateId) ───────────────────────

final citiesProvider = AsyncNotifierProvider.autoDispose
    .family<CitiesNotifier, List<CityEntity>, int>(CitiesNotifier.new);

class CitiesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<CityEntity>, int> {
  @override
  Future<List<CityEntity>> build(int arg) =>
      ref.read(branchRepositoryProvider).getCities(arg);
}

// ── Error helper ──────────────────────────────────────────────────────────────

String _friendly(Object e) {
  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('connection')) {
    return 'Cannot reach server. Check your connection.';
  }
  if (msg.contains('401')) return 'Session expired. Please log in again.';
  if (msg.contains('403')) return 'You do not have permission to do this.';
  if (msg.contains('404')) return 'Resource not found.';
  if (msg.contains('500')) return 'Server error. Please try again later.';
  return msg.replaceAll('Exception:', '').trim();
}
