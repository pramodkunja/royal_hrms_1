import 'package:flutter/foundation.dart';

@immutable
class PermissionModel {
  final String id;
  final String name;        // codename e.g. 'employees.view'
  final String? module;     // e.g. 'employees'
  final String? description; // action e.g. 'view'

  const PermissionModel({
    required this.id,
    required this.name,
    this.module,
    this.description,
  });

  factory PermissionModel.fromJson(Map<String, dynamic> json) => PermissionModel(
    id:          json['id']?.toString() ?? json['codename']?.toString() ?? '',
    name:        json['codename'] as String? ?? '',
    module:      json['module'] as String?,
    description: json['action'] as String?,
  );
}

@immutable
class RoleModel {
  final dynamic id;
  final String name;            // slug e.g. 'hr_admin'
  final String displayName;     // e.g. 'HR Admin'
  final String? description;
  final List<String> permissions; // codenames
  final int userCount;
  final bool isActive;
  final bool isSystem;

  const RoleModel({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    required this.permissions,
    required this.userCount,
    required this.isActive,
    required this.isSystem,
  });

  String get idStr => id?.toString() ?? '';

  RoleModel copyWith({bool? isActive}) => RoleModel(
    id:          id,
    name:        name,
    displayName: displayName,
    description: description,
    permissions: permissions,
    userCount:   userCount,
    isActive:    isActive ?? this.isActive,
    isSystem:    isSystem,
  );

  factory RoleModel.fromJson(Map<String, dynamic> json) => RoleModel(
    id:          json['id'],
    name:        json['name'] as String? ?? '',
    displayName: json['display_name'] as String? ?? json['name'] as String? ?? '',
    description: json['description'] as String?,
    permissions: (json['permissions'] as List<dynamic>?)
            ?.map((p) => p.toString())
            .toList() ??
        const [],
    userCount: json['user_count'] as int? ?? 0,
    isActive:  json['is_active'] as bool? ?? true,
    isSystem:  json['is_system'] as bool? ?? false,
  );
}

@immutable
class RolesPage {
  final List<RoleModel> roles;
  final int count;
  const RolesPage({required this.roles, required this.count});
  factory RolesPage.empty() => const RolesPage(roles: [], count: 0);
}

// ── Form model ────────────────────────────────────────────────────────────────

class RoleFormData {
  String displayName;
  String name;          // slug — auto-generated on add, immutable on edit
  bool isActive;
  Set<String> permissions; // codenames

  RoleFormData({
    this.displayName = '',
    this.name = '',
    this.isActive = true,
    Set<String>? permissions,
  }) : permissions = permissions ?? {};

  factory RoleFormData.fromModel(RoleModel model) => RoleFormData(
    displayName: model.displayName,
    name:        model.name,
    isActive:    model.isActive,
    permissions: Set<String>.from(model.permissions),
  );

  static String toSlug(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');

  Map<String, dynamic> toJson() => {
    'name':                 name,
    'display_name':         displayName,
    'is_active':            isActive,
    'permission_codenames': permissions.toList(),
  };

  Map<String, String?> validate() {
    final errors = <String, String?>{};
    if (displayName.trim().isEmpty) errors['displayName'] = 'Role name is required';
    if (permissions.isEmpty) errors['permissions'] = 'Select at least one permission';
    return errors;
  }
}
