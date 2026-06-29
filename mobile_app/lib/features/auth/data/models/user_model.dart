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
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      roleDisplay: json['role_display'] as String? ?? json['role'] as String,
      employeeId: json['employee_id'] as String?,
      department: json['department'] as String?,
      designation: json['designation'] as String?,
      branch: json['branch'] as String?,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((p) => p as String)
              .toList() ??
          [],
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
      };
}
