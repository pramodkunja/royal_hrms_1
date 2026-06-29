class UserEntity {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String roleDisplay;
  final String? employeeId;
  final String? department;
  final String? designation;
  final String? branch;
  final bool mustChangePassword;
  final List<String> permissions;

  const UserEntity({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.roleDisplay,
    this.employeeId,
    this.department,
    this.designation,
    this.branch,
    required this.mustChangePassword,
    required this.permissions,
  });

  bool hasPermission(String permission) => permissions.contains(permission);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserEntity && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserEntity(id: $id, email: $email, role: $role)';
}
