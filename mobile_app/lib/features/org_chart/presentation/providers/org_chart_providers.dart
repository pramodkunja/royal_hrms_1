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

final orgChartProvider = AsyncNotifierProvider.autoDispose<
    OrgChartNotifier, OrgChartEntity>(OrgChartNotifier.new);

class OrgChartNotifier extends AutoDisposeAsyncNotifier<OrgChartEntity> {
  OrgChartRepository get _repo => ref.read(orgChartRepositoryProvider);

  @override
  Future<OrgChartEntity> build() => _repo.getOrgChart();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getOrgChart());
  }
}
