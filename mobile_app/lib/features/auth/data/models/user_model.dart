import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.fullName,
    required super.role,
    required super.roleDisplay,
    super.employeeId,
    super.department,
    super.designation,
    super.branch,
    required super.mustChangePassword,
    required super.permissions,
    super.onboardingStatus,
    super.assessmentStatus,
    super.canManageTeam,
    super.canManageBranch,
    super.companyCode,
    super.companyName,
    super.companyLogoUrl,
    super.companyBrandColor,
    super.isSuperuser,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      roleDisplay: json['role_display'] as String? ?? json['role'] as String? ?? '',
      employeeId: json['employee_id'] as String?,
      department: json['department'] as String?,
      designation: json['designation'] as String?,
      branch: json['branch'] as String?,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((p) => p as String)
              .toList() ??
          [],
      onboardingStatus: json['onboarding_status'] as String?,
      assessmentStatus: json['assessment_status'] as String?,
      canManageTeam: json['can_manage_team'] as bool? ?? false,
      canManageBranch: json['can_manage_branch'] as bool? ?? false,
      companyCode: json['company_code'] as String?,
      companyName: json['company_name'] as String?,
      companyLogoUrl: json['company_logo_url'] as String?,
      companyBrandColor: json['company_brand_color'] as String?,
      isSuperuser: json['is_superuser'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role': role,
        'role_display': roleDisplay,
        'employee_id': employeeId,
        'department': department,
        'designation': designation,
        'branch': branch,
        'must_change_password': mustChangePassword,
        'permissions': permissions,
        'onboarding_status': onboardingStatus,
        'assessment_status': assessmentStatus,
        'can_manage_team': canManageTeam,
        'can_manage_branch': canManageBranch,
        'company_code': companyCode,
        'company_name': companyName,
        'company_logo_url': companyLogoUrl,
        'company_brand_color': companyBrandColor,
        'is_superuser': isSuperuser,
      };
}
