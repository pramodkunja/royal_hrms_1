import 'package:flutter/foundation.dart';

// A role currently active within a department — read-only, computed by the
// backend from users with that department + role (DepartmentSerializer.get_roles).
@immutable
class DepartmentRoleTag {
  final String name;
  final String displayName;

  const DepartmentRoleTag({required this.name, required this.displayName});

  factory DepartmentRoleTag.fromJson(Map<String, dynamic> json) => DepartmentRoleTag(
    name:        json['name'] as String? ?? '',
    displayName: json['display_name'] as String? ?? '',
  );
}

@immutable
class DepartmentModel {
  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final int designationCount;  // designation_count
  final int employeeCount;     // employee_count
  final List<DepartmentRoleTag> roles;

  const DepartmentModel({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    required this.designationCount,
    required this.employeeCount,
    this.roles = const [],
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) => DepartmentModel(
    id:               json['id'] as int,
    name:             json['name'] as String? ?? '',
    description:      json['description'] as String?,
    isActive:         json['is_active'] as bool? ?? true,
    designationCount: json['designation_count'] as int? ?? 0,
    employeeCount:    json['employee_count'] as int? ?? 0,
    roles: (json['roles'] as List<dynamic>? ?? [])
        .map((e) => DepartmentRoleTag.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

@immutable
class DesignationModel {
  final int id;
  final String name;
  final int departmentId;
  final String? departmentName;  // department_name
  final bool isActive;

  const DesignationModel({
    required this.id,
    required this.name,
    required this.departmentId,
    this.departmentName,
    required this.isActive,
  });

  factory DesignationModel.fromJson(Map<String, dynamic> json) => DesignationModel(
    id:             json['id'] as int,
    name:           json['name'] as String? ?? '',
    departmentId:   json['department'] as int? ?? json['department_id'] as int? ?? 0,
    departmentName: json['department_name'] as String?,
    isActive:       json['is_active'] as bool? ?? true,
  );
}

class DeptFormData {
  String name;
  String description;
  bool isActive;

  DeptFormData({this.name = '', this.description = '', this.isActive = true});

  factory DeptFormData.fromModel(DepartmentModel model) => DeptFormData(
    name:        model.name,
    description: model.description ?? '',
    isActive:    model.isActive,
  );

  Map<String, dynamic> toJson() => {
    'name':        name,
    'description': description,
    'is_active':   isActive,
  };

  String? validate() {
    if (name.trim().isEmpty) return 'Department name is required';
    return null;
  }
}

class DesignationFormData {
  String name;
  int? departmentId;
  bool isActive;

  DesignationFormData({this.name = '', this.departmentId, this.isActive = true});

  factory DesignationFormData.fromModel(DesignationModel model) => DesignationFormData(
    name:         model.name,
    departmentId: model.departmentId,
    isActive:     model.isActive,
  );

  Map<String, dynamic> toJson() => {
    'name':       name,
    'department': departmentId,
    'is_active':  isActive,
  };

  Map<String, String?> validate() {
    final errors = <String, String?>{};
    if (name.trim().isEmpty)  errors['name']         = 'Designation name is required';
    if (departmentId == null) errors['departmentId'] = 'Department is required';
    return errors;
  }
}
