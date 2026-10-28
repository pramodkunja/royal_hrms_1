import '../../domain/entities/org_chart_entity.dart';
import '../../domain/repositories/org_chart_repository.dart';
import '../datasources/org_chart_remote_datasource.dart';

/// Maps the backend's `/org-chart/` response 1:1 — no client-side guessing
/// of who the "head"/root is. That decision is made server-side
/// (`_build_org_chart_group`) from `reporting_manager`/`Department.manager`.
class OrgChartRepositoryImpl implements OrgChartRepository {
  final OrgChartRemoteDataSource _ds;
  OrgChartRepositoryImpl(this._ds);

  @override
  Future<OrgChartEntity> getOrgChart({String? branch}) async {
    final raw = await _ds.fetchOrgChart(branch: branch);
    final scope = raw['scope'] == 'company'
        ? OrgChartScope.company
        : OrgChartScope.branch;
    final groups = (raw['groups'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_toGroup)
        .toList();
    return OrgChartEntity(scope: scope, groups: groups);
  }

  @override
  Future<List<String>> getBranchNames() => _ds.fetchBranchNames();

  static OrgChartGroupEntity _toGroup(Map<String, dynamic> g) {
    final rootJson = g['root'] as Map<String, dynamic>?;
    return OrgChartGroupEntity(
      branch: g['branch'] as String? ?? '',
      root: rootJson == null ? null : _toPerson(rootJson),
      departments: (g['departments'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(_toDepartment)
          .toList(),
    );
  }

  static OrgDepartmentEntity _toDepartment(Map<String, dynamic> d) {
    final headJson = d['head'] as Map<String, dynamic>?;
    return OrgDepartmentEntity(
      id: d['id'] as int? ?? 0,
      label: d['label'] as String? ?? '',
      head: headJson == null ? null : _toPerson(headJson),
      members: (d['members'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(_toPerson)
          .toList(),
    );
  }

  static OrgPersonEntity _toPerson(Map<String, dynamic> p) {
    return OrgPersonEntity(
      id: p['id']?.toString() ?? '',
      employeeId: p['employee_id'] as String? ?? '',
      name: p['name'] as String? ?? '',
      designation: p['designation'] as String? ?? '',
    );
  }
}
