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
  final String? onboardingStatus;
  final bool canManageTeam;
  // is_superuser — backend computes this as `user.is_superuser or
  // 'settings.edit' in permissions` (apps/accounts/views.py login response)
  // and it's the same signal web's permission gates check directly
  // (e.g. AttendanceApprovalTab's `can_manage_team || is_superuser ||
  // payroll.view`). Only present on the login response, so this is populated
  // once at login and cached — an account promoted to superuser after their
  // last login won't see it until they log out and back in.
  final bool isSuperuser;

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
    this.onboardingStatus,
    this.canManageTeam = false,
    this.isSuperuser = false,
  });

  bool get needsOnboarding =>
      onboardingStatus == 'pending' || onboardingStatus == 'draft';
  bool get awaitingApproval => onboardingStatus == 'submitted';
  bool get onboardingComplete => onboardingStatus == 'complete';
  bool get onboardingRejected => onboardingStatus == 'rejected';

  bool hasPermission(String permission) => permissions.contains(permission);

  UserEntity copyWith({String? onboardingStatus}) => UserEntity(
        id: id,
        email: email,
        fullName: fullName,
        role: role,
        roleDisplay: roleDisplay,
        employeeId: employeeId,
        department: department,
        designation: designation,
        branch: branch,
        mustChangePassword: mustChangePassword,
        permissions: permissions,
        onboardingStatus: onboardingStatus ?? this.onboardingStatus,
        canManageTeam: canManageTeam,
        isSuperuser: isSuperuser,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          other.id == id &&
          other.onboardingStatus == onboardingStatus;

  @override
  int get hashCode => Object.hash(id, onboardingStatus);

  @override
  String toString() => 'UserEntity(id: $id, email: $email, role: $role)';
}
