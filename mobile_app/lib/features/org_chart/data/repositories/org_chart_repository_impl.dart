import 'package:flutter/material.dart';
import '../../domain/entities/org_chart_entity.dart';
import '../../domain/repositories/org_chart_repository.dart';
import '../datasources/org_chart_remote_datasource.dart';

const _kPalette = [
  Color(0xFFE65100), // Orange  – HR
  Color(0xFF1565C0), // Blue    – Engineering
  Color(0xFF2E7D32), // Green   – Finance
  Color(0xFF6A1B9A), // Purple  – IT
  Color(0xFF00838F), // Teal
  Color(0xFFAD1457), // Pink
  Color(0xFF37474F), // Blue-grey
  Color(0xFFC62828), // Red
];

class OrgChartRepositoryImpl implements OrgChartRepository {
  final OrgChartRemoteDataSource _ds;
  OrgChartRepositoryImpl(this._ds);

  @override
  Future<OrgChartEntity> getOrgChart() async {
    final results = await Future.wait([
      _ds.fetchEmployees(),
      _ds.fetchCompanyName(),
    ]);
    return _build(
      results[0] as List<Map<String, dynamic>>,
      results[1] as String,
    );
  }

  OrgChartEntity _build(
    List<Map<String, dynamic>> raw,
    String companyName,
  ) {
    final all = raw.map(_toMember).toList();

    // ── Identify Managing Director ─────────────────────────────────────────
    OrgMemberEntity? md;
    final rest = <OrgMemberEntity>[];
    for (final m in all) {
      if (md == null && _isMD(m.designation)) {
        md = m;
      } else {
        rest.add(m);
      }
    }

    // ── Group by department ────────────────────────────────────────────────
    final deptMap = <String, List<OrgMemberEntity>>{};
    for (final m in rest) {
      final dept = m.department.trim();
      if (dept.isEmpty) continue;
      deptMap.putIfAbsent(dept, () => []).add(m);
    }

    // ── Build sorted department nodes ──────────────────────────────────────
    final sortedNames = deptMap.keys.toList()..sort();
    final nodes = <DepartmentNodeEntity>[];

    for (var i = 0; i < sortedNames.length; i++) {
      final name = sortedNames[i];
      final group = deptMap[name]!;
      final color = _kPalette[i % _kPalette.length];

      // Pick head: first with managerial designation, else first employee
      OrgMemberEntity? head;
      for (final m in group) {
        if (head == null && _isHead(m.designation)) {
          head = m;
          break;
        }
      }
      head ??= group.first;

      final members = group.where((m) => m.id != head!.id).toList();

      nodes.add(DepartmentNodeEntity(
        name: name,
        color: color,
        head: head,
        members: members,
      ));
    }

    return OrgChartEntity(
      managingDirector: md,
      companyName: companyName,
      departments: nodes,
    );
  }

  static OrgMemberEntity _toMember(Map<String, dynamic> e) {
    return OrgMemberEntity(
      id: e['id']?.toString() ?? '',
      fullName: e['full_name'] as String? ?? '',
      department: e['department'] as String? ?? '',
      designation: e['designation'] as String? ?? '',
      role: e['role'] as String? ?? '',
    );
  }

  static bool _isMD(String d) {
    final l = d.toLowerCase();
    return l.contains('managing director') ||
        l.contains('chief executive') ||
        l == 'ceo' ||
        l == 'md';
  }

  static bool _isHead(String d) {
    final l = d.toLowerCase();
    return l.contains('manager') ||
        l.contains('director') ||
        l.contains('head') ||
        l.contains('lead') ||
        l.contains('admin') ||
        l.contains('supervisor') ||
        l.contains('chief');
  }
}
