import 'package:flutter/material.dart';

// ── Employee ──────────────────────────────────────────────────────────────────

@immutable
class EmployeeModel {
  final String id;
  final String employeeId;
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
  final String status;
  final String dateOfJoining;
  final String? reportingManagerId;
  final String? reportingManagerName;

  // Profile: personal
  final String dateOfBirth;
  final String gender;
  final String maritalStatus;
  final String fatherName;
  final String bloodGroup;
  final String currentAddress;
  final String permanentAddress;

  // Profile: education & experience
  final String highestQualification;
  final String specialization;
  final String institution;
  final String yearOfPassing;
  final String totalExperienceYears;
  final String previousEmployer;
  final String previousDesignation;
  final String leavingReason;

  // Profile: bank details
  final String accountHolderName;
  final String accountType;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String bankBranch;

  // Profile: emergency contact
  final String emergencyName;
  final String emergencyRelationship;
  final String emergencyPhone;
  final String emergencyEmail;

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
    this.reportingManagerId,
    this.reportingManagerName,
    this.dateOfBirth = '',
    this.gender = '',
    this.maritalStatus = '',
    this.fatherName = '',
    this.bloodGroup = '',
    this.currentAddress = '',
    this.permanentAddress = '',
    this.highestQualification = '',
    this.specialization = '',
    this.institution = '',
    this.yearOfPassing = '',
    this.totalExperienceYears = '',
    this.previousEmployer = '',
    this.previousDesignation = '',
    this.leavingReason = '',
    this.accountHolderName = '',
    this.accountType = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.bankName = '',
    this.bankBranch = '',
    this.emergencyName = '',
    this.emergencyRelationship = '',
    this.emergencyPhone = '',
    this.emergencyEmail = '',
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] as Map<String, dynamic>?) ?? {};
    return EmployeeModel(
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
      reportingManagerId:   json['reporting_manager_id'] as String?,
      reportingManagerName: json['reporting_manager_name'] as String?,
      dateOfBirth:          profile['date_of_birth'] as String? ?? '',
      gender:               profile['gender'] as String? ?? '',
      maritalStatus:        profile['marital_status'] as String? ?? '',
      fatherName:           profile['father_name'] as String? ?? '',
      bloodGroup:           profile['blood_group'] as String? ?? '',
      currentAddress:       profile['current_address'] as String? ?? '',
      permanentAddress:     profile['permanent_address'] as String? ?? '',
      highestQualification: profile['highest_qualification'] as String? ?? '',
      specialization:       profile['specialization'] as String? ?? '',
      institution:          profile['institution'] as String? ?? '',
      yearOfPassing:        profile['year_of_passing']?.toString() ?? '',
      totalExperienceYears: profile['total_experience_years'] as String? ?? '',
      previousEmployer:     profile['previous_employer'] as String? ?? '',
      previousDesignation:  profile['previous_designation'] as String? ?? '',
      leavingReason:        profile['leaving_reason'] as String? ?? '',
      accountHolderName:    profile['account_holder_name'] as String? ?? '',
      accountType:          profile['account_type'] as String? ?? '',
      accountNumber:        profile['account_number'] as String? ?? '',
      ifscCode:             profile['ifsc_code'] as String? ?? '',
      bankName:             profile['bank_name'] as String? ?? '',
      bankBranch:           profile['bank_branch_name'] as String? ?? '',
      emergencyName:         profile['emergency_name'] as String? ?? '',
      emergencyRelationship: profile['emergency_relationship'] as String? ?? '',
      emergencyPhone:        profile['emergency_phone'] as String? ?? '',
      emergencyEmail:        profile['emergency_email'] as String? ?? '',
    );
  }

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
  dynamic roleId;
  int? departmentId;
  String department;
  String designation;
  String branch;
  String employeeType;
  String dateOfJoining;

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
