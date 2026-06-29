import '../entities/org_chart_entity.dart';

abstract class OrgChartRepository {
  Future<OrgChartEntity> getOrgChart();
}
