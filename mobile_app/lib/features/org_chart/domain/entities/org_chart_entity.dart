/// Mirrors the shape returned by `GET /api/org-chart/` exactly — see
/// `OrgChartView`/`_build_org_chart_group` on the backend. The chart is
/// intentionally two flat levels (root, then departments with a head + flat
/// member list), not a recursive manager→report tree.
enum OrgChartScope { branch, company }

class OrgPersonEntity {
  final String id;
  final String employeeId;
  final String name;
  final String designation;

  const OrgPersonEntity({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.designation,
  });
}

class OrgDepartmentEntity {
  final int id;
  final String label;
  final OrgPersonEntity? head;
  final List<OrgPersonEntity> members;

  const OrgDepartmentEntity({
    required this.id,
    required this.label,
    this.head,
    required this.members,
  });
}

class OrgChartGroupEntity {
  final String branch;
  final OrgPersonEntity? root;
  final List<OrgDepartmentEntity> departments;

  const OrgChartGroupEntity({
    required this.branch,
    this.root,
    required this.departments,
  });
}

class OrgChartEntity {
  final OrgChartScope scope;
  final List<OrgChartGroupEntity> groups;

  const OrgChartEntity({required this.scope, required this.groups});
}
