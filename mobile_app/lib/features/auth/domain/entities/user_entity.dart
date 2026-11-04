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
  final String? assessmentStatus;
  final bool canManageTeam;
  final bool canManageBranch;
  // Populated by the multi-tenant login response (apps/accounts/views.py
  // LoginView) — the company the authenticated user's schema belongs to.
  final String? companyCode;
  final String? companyName;
  final String? companyLogoUrl;
  final String? companyBrandColor;
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
    this.assessmentStatus,
    this.canManageTeam = false,
    this.canManageBranch = false,
    this.companyCode,
    this.companyName,
    this.companyLogoUrl,
    this.companyBrandColor,
    this.isSuperuser = false,
  });

  // Mirrors web's gate (frontend/proxy.ts, login/page.tsx): superusers are
  // exempt from onboarding regardless of onboarding_status.
  bool get needsOnboarding =>
      !isSuperuser &&
      (onboardingStatus == 'pending' || onboardingStatus == 'draft');
  bool get awaitingApproval => onboardingStatus == 'submitted';
  bool get onboardingComplete => onboardingStatus == 'complete';
  bool get onboardingRejected => !isSuperuser && onboardingStatus == 'rejected';

  /// Web's onboarding assessment gate (frontend/proxy.ts needsAssessments):
  /// onboarding approved, an assessment still pending, and not a team
  /// manager, branch manager or superuser (the backend auto-assigns default
  /// assessments to every new employee record, managers included, so web
  /// exempts those roles itself).
  bool get needsAssessments =>
      onboardingStatus == 'complete' &&
      assessmentStatus == 'pending' &&
      !canManageTeam &&
      !canManageBranch &&
      !isSuperuser;

  bool hasPermission(String permission) => permissions.contains(permission);

  UserEntity copyWith({String? onboardingStatus, String? assessmentStatus}) => UserEntity(
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
        assessmentStatus: assessmentStatus ?? this.assessmentStatus,
        canManageTeam: canManageTeam,
        canManageBranch: canManageBranch,
        companyCode: companyCode,
        companyName: companyName,
        companyLogoUrl: companyLogoUrl,
        companyBrandColor: companyBrandColor,
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
