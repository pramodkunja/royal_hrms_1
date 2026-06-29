import 'package:flutter/material.dart';

class OrgMemberEntity {
  final String id;
  final String fullName;
  final String department;
  final String designation;
  final String role;

  const OrgMemberEntity({
    required this.id,
    required this.fullName,
    required this.department,
    required this.designation,
    required this.role,
  });
}

class DepartmentNodeEntity {
  final String name;
  final Color color;
  final OrgMemberEntity? head;
  final List<OrgMemberEntity> members;

  const DepartmentNodeEntity({
    required this.name,
    required this.color,
    this.head,
    required this.members,
  });
}

class OrgChartEntity {
  final OrgMemberEntity? managingDirector;
  final String companyName;
  final List<DepartmentNodeEntity> departments;

  const OrgChartEntity({
    this.managingDirector,
    required this.companyName,
    required this.departments,
  });
}
