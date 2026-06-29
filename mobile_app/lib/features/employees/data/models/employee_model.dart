import 'package:flutter/material.dart';

// ── Employee ──────────────────────────────────────────────────────────────────

@immutable
class EmployeeModel {
  final String id;             // UUID
  final String employeeId;     // e.g. EMP001
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String phone;
  final String department;
  final String designation;
  final String branch;
  final String roleDisplay;
  final bool isActive;
  final String status;         // 'active' | 'onboarding' | 'inactive'
  final String dateOfJoining;  // ISO date string yyyy-MM-dd

  const EmployeeModel({
    required this.id,
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.department,
    required this.designation,
    required this.branch,
    required this.roleDisplay,
    required this.isActive,
    required this.status,
    required this.dateOfJoining,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) => EmployeeModel(
        id:            json['id']?.toString() ?? '',
        employeeId:    json['employee_id'] as String? ?? '',
        firstName:     json['first_name'] as String? ?? '',
        lastName:      json['last_name'] as String? ?? '',
        fullName:      json['full_name'] as String? ?? '',
        email:         json['email'] as String? ?? '',
        phone:         json['phone'] as String? ?? '',
        department:    json['department'] as String? ?? '',
        designation:   json['designation'] as String? ?? '',
        branch:        json['branch'] as String? ?? '',
        roleDisplay:   json['role_display'] as String? ?? '',
        isActive:      json['is_active'] as bool? ?? false,
        status:        json['status'] as String? ?? 'inactive',
        dateOfJoining: json['date_of_joining'] as String? ?? '',
      );

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || fullName.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color get avatarColor {
    const palette = [
      Color(0xFF1E4E8C),
      Color(0xFF219653),
      Color(0xFF7C3AED),
      Color(0xFFD4487B),
      Color(0xFFF2994A),
      Color(0xFF2D9CDB),
      Color(0xFFEB5757),
      Color(0xFF9B51E0),
      Color(0xFF0D7490),
    ];
    if (fullName.isEmpty) return palette[0];
    return palette[fullName.codeUnitAt(0) % palette.length];
  }
}

// ── Stats ─────────────────────────────────────────────────────────────────────

@immutable
class EmployeeStats {
  final int total;
  final int active;
  final int onboarding;
  final int departments;

  const EmployeeStats({
    required this.total,
    required this.active,
    required this.onboarding,
    required this.departments,
  });

  static const empty = EmployeeStats(
    total: 0, active: 0, onboarding: 0, departments: 0,
  );

  factory EmployeeStats.fromList(List<EmployeeModel> employees) {
    final depts = employees
        .map((e) => e.department)
        .where((d) => d.isNotEmpty)
        .toSet();
    return EmployeeStats(
      total:       employees.length,
      active:      employees.where((e) => e.status == 'active').length,
      onboarding:  employees.where((e) => e.status == 'onboarding').length,
      departments: depts.length,
    );
  }
}

// ── Filters ───────────────────────────────────────────────────────────────────

@immutable
class EmployeeFilters {
  final String search;
  final String status;
  final String department;
  final String designation;
  final String branch;

  const EmployeeFilters({
    this.search = '',
    this.status = '',
    this.department = '',
    this.designation = '',
    this.branch = '',
  });

  EmployeeFilters copyWith({
    String? search,
    String? status,
    String? department,
    String? designation,
    String? branch,
  }) =>
      EmployeeFilters(
        search:      search ?? this.search,
        status:      status ?? this.status,
        department:  department ?? this.department,
        designation: designation ?? this.designation,
        branch:      branch ?? this.branch,
      );

  int get activeCount => [
        search,
        status,
        department,
        designation,
        branch,
      ].where((s) => s.isNotEmpty).length;

  bool get hasActive => activeCount > 0;
}

// ── Branch option (for add/edit form dropdown) ────────────────────────────────

@immutable
class EmployeeBranch {
  final int id;
  final String name;

  const EmployeeBranch({required this.id, required this.name});

  factory EmployeeBranch.fromJson(Map<String, dynamic> json) => EmployeeBranch(
        id:   json['id'] as int,
        name: json['branch_name'] as String? ?? '',
      );
}

// ── Form data (add + edit) ────────────────────────────────────────────────────

class EmployeeFormData {
  String firstName;
  String lastName;
  String email;
  String phone;
  dynamic roleId;      // matches RoleModel.id (dynamic)
  int? departmentId;   // used to filter designations dropdown
  String department;   // dept name string — sent to backend
  String designation;  // designation name string — sent to backend
  String branch;       // branch name string — sent to backend
  String employeeType;
  String dateOfJoining; // yyyy-MM-dd

  EmployeeFormData({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.roleId,
    this.departmentId,
    this.department = '',
    this.designation = '',
    this.branch = '',
    this.employeeType = 'Permanent',
    this.dateOfJoining = '',
  });

  factory EmployeeFormData.fromModel(EmployeeModel model) => EmployeeFormData(
        firstName:    model.firstName,
        lastName:     model.lastName,
        email:        model.email,
        phone:        model.phone,
        department:   model.department,
        designation:  model.designation,
        branch:       model.branch,
        employeeType: 'Permanent',
        dateOfJoining: model.dateOfJoining,
      );

  Map<String, String> validate() {
    final errors = <String, String>{};
    if (firstName.trim().isEmpty) errors['first_name'] = 'First name is required.';
    if (lastName.trim().isEmpty)  errors['last_name'] = 'Last name is required.';
    if (email.trim().isEmpty)     errors['email'] = 'Work email is required.';
    if (roleId == null)           errors['role'] = 'Role is required.';
    if (department.isEmpty)       errors['department'] = 'Department is required.';
    if (designation.isEmpty)      errors['designation'] = 'Designation is required.';
    if (branch.isEmpty)           errors['branch'] = 'Branch is required.';
    if (dateOfJoining.isEmpty)    errors['date_of_joining'] = 'Date of joining is required.';
    return errors;
  }

  Map<String, dynamic> toJson() => {
        'first_name':     firstName.trim(),
        'last_name':      lastName.trim(),
        'email':          email.trim().toLowerCase(),
        if (phone.trim().isNotEmpty) 'phone': phone.trim(),
        'role':           roleId,
        'department':     department,
        'designation':    designation,
        'branch':         branch,
        'employee_type':  employeeType,
        'date_of_joining': dateOfJoining,
      };
}
