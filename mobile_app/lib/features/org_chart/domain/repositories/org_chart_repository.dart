import '../entities/org_chart_entity.dart';

abstract class OrgChartRepository {
  /// [branch] is only meaningful for company-scope (system-admin-tier)
  /// viewers — branch-scope viewers are always pinned server-side to their
  /// own branch regardless of what's passed here.
  Future<OrgChartEntity> getOrgChart({String? branch});

  /// Branch names for the company-scope branch picker. Only ever called for
  /// company-scope viewers.
  Future<List<String>> getBranchNames();
}
