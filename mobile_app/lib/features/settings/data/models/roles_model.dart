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
  // Role.is_system_role (read-only): one of the roles the company was
  // provisioned with. On the backend it only blocks deletion — permissions,
  // name, capabilities and active state stay editable (web shows Edit and the
  // toggle for every role), so this drives the "System" badge only.
  final bool isSystem;
  // Whether this role is a "manager"-type role for reporting-manager
  // purposes. Backend field is a stored Role.can_manage_team boolean, NOT
  // derivable from `name` — role names drift (e.g. the seeded 'manager' role
  // was later renamed to 'manager__team_lead' via Settings -> Roles), so
  // callers must use this flag instead of comparing `name == 'manager'`.
  final bool canManageTeam;
  // Role.can_manage_branch: unconditional access to every employee, request
  // and record in the user's own branch (the Branch Admin capability). Found
  // by this flag, never by role name — same as canManageTeam.
  final bool canManageBranch;
  // Role.updated_at — echoed back as expected_updated_at on edit so the
  // server can refuse a save based on stale data (409).
  final String? updatedAt;

  const RoleModel({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    required this.permissions,
    required this.userCount,
    required this.isActive,
    required this.isSystem,
    this.canManageTeam = false,
    this.canManageBranch = false,
    this.updatedAt,
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
    canManageTeam: canManageTeam,
    canManageBranch: canManageBranch,
    updatedAt:   updatedAt,
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
    isSystem:  json['is_system_role'] as bool? ?? false,
    canManageTeam: json['can_manage_team'] as bool? ?? false,
    canManageBranch: json['can_manage_branch'] as bool? ?? false,
    updatedAt: json['updated_at']?.toString(),
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
  // Web RoleForm can_manage_team / can_manage_branch ("Can manage team" /
  // "Can manage branch"), both false for a new role.
  bool canManageTeam;
  bool canManageBranch;
  // The role's updated_at when the edit form was opened (edit only).
  String? expectedUpdatedAt;

  RoleFormData({
    this.displayName = '',
    this.name = '',
    this.isActive = true,
    Set<String>? permissions,
    this.canManageTeam = false,
    this.canManageBranch = false,
    this.expectedUpdatedAt,
  }) : permissions = permissions ?? {};

  factory RoleFormData.fromModel(RoleModel model) => RoleFormData(
    displayName: model.displayName,
    name:        model.name,
    isActive:    model.isActive,
    permissions: Set<String>.from(model.permissions),
    canManageTeam:   model.canManageTeam,
    canManageBranch: model.canManageBranch,
    expectedUpdatedAt: model.updatedAt,
  );

  static String toSlug(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');

  /// Web page.tsx addRole / editRole body. expected_updated_at is sent only
  /// for an edit (the optimistic-concurrency check on RoleDetailView.put).
  Map<String, dynamic> toJson() => {
    'name':                 name,
    'display_name':         displayName,
    'is_active':            isActive,
    'can_manage_team':      canManageTeam,
    'can_manage_branch':    canManageBranch,
    'permission_codenames': permissions.toList(),
    if (expectedUpdatedAt != null && expectedUpdatedAt!.isNotEmpty)
      'expected_updated_at': expectedUpdatedAt,
  };

  Map<String, String?> validate() {
    final errors = <String, String?>{};
    if (displayName.trim().isEmpty) errors['displayName'] = 'Role name is required';
    if (permissions.isEmpty) errors['permissions'] = 'Select at least one permission';
    return errors;
  }
}
