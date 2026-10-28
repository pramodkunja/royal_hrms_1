import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/org_chart_remote_datasource.dart';
import '../../data/repositories/org_chart_repository_impl.dart';
import '../../domain/entities/org_chart_entity.dart';
import '../../domain/repositories/org_chart_repository.dart';

final orgChartDataSourceProvider = Provider<OrgChartRemoteDataSource>((ref) {
  return OrgChartRemoteDataSource(ref.watch(dioProvider));
});

final orgChartRepositoryProvider = Provider<OrgChartRepository>((ref) {
  return OrgChartRepositoryImpl(ref.watch(orgChartDataSourceProvider));
});

/// Selected branch for the company-scope branch picker. Null = "All
/// Branches" (the server-side default when no `?branch=` is sent).
final orgChartSelectedBranchProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final orgChartProvider =
    AsyncNotifierProvider.autoDispose<OrgChartNotifier, OrgChartEntity>(
  OrgChartNotifier.new,
);

class OrgChartNotifier extends AutoDisposeAsyncNotifier<OrgChartEntity> {
  OrgChartRepository get _repo => ref.read(orgChartRepositoryProvider);

  @override
  Future<OrgChartEntity> build() {
    final branch = ref.watch(orgChartSelectedBranchProvider);
    return _repo.getOrgChart(branch: branch);
  }

  Future<void> refresh() async {
    final branch = ref.read(orgChartSelectedBranchProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getOrgChart(branch: branch));
  }
}

/// Branch names for the picker — only ever watched once the loaded chart's
/// scope is company-wide (branch-scope viewers never see the picker).
final orgChartBranchNamesProvider =
    FutureProvider.autoDispose<List<String>>((ref) {
  return ref.read(orgChartRepositoryProvider).getBranchNames();
});
