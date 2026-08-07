import 'package:flutter/material.dart';

import '../../../../shared/validators/form_validators.dart';

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
  final String role;
  final String roleDisplay;
  final bool isActive;
  final String status;
  final String dateOfJoining;
  final String? reportingManagerId;
  final String? reportingManagerName;
  final String? hrId;
  final String? hrName;
  final List<EmployeeDocumentEntity> documents;

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
    this.role = '',
    this.reportingManagerId,
    this.reportingManagerName,
    this.hrId,
    this.hrName,
    this.documents = const [],
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
    // Backend omits the "reporting_manager" key entirely when the employee's
    // own role is "manager" (managers have no reporting manager) — must not
    // assume the key exists. "hr" is always present but its id/name may be null.
    final reportingManager = json['reporting_manager'] as Map<String, dynamic>?;
    final hr = json['hr'] as Map<String, dynamic>?;
    final documentsRaw = json['documents'] as List<dynamic>? ?? [];
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
      role:          json['role'] as String? ?? '',
      roleDisplay:   json['role_display'] as String? ?? '',
      isActive:      json['is_active'] as bool? ?? false,
      status:        json['status'] as String? ?? 'inactive',
      dateOfJoining: json['date_of_joining'] as String? ?? '',
      reportingManagerId:   reportingManager?['id'] as String?,
      reportingManagerName: reportingManager?['name'] as String?,
      hrId:                 hr?['id'] as String?,
      hrName:               hr?['name'] as String?,
      documents: documentsRaw
          .whereType<Map<String, dynamic>>()
          .map(EmployeeDocumentEntity.fromJson)
          .toList(),
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

  EmployeeModel copyWith({
    bool? isActive,
    String? status,
  }) {
    return EmployeeModel(
      id: id, employeeId: employeeId,
      firstName: firstName, lastName: lastName, fullName: fullName,
      email: email, phone: phone,
      department: department, designation: designation, branch: branch,
      role: role, roleDisplay: roleDisplay,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      dateOfJoining: dateOfJoining,
      reportingManagerId: reportingManagerId,
      reportingManagerName: reportingManagerName,
      hrId: hrId, hrName: hrName,
      documents: documents,
      dateOfBirth: dateOfBirth, gender: gender, maritalStatus: maritalStatus,
      fatherName: fatherName, bloodGroup: bloodGroup,
      currentAddress: currentAddress, permanentAddress: permanentAddress,
      highestQualification: highestQualification, specialization: specialization,
      institution: institution, yearOfPassing: yearOfPassing,
      totalExperienceYears: totalExperienceYears, previousEmployer: previousEmployer,
      previousDesignation: previousDesignation, leavingReason: leavingReason,
      accountHolderName: accountHolderName, accountType: accountType,
      accountNumber: accountNumber, ifscCode: ifscCode,
      bankName: bankName, bankBranch: bankBranch,
      emergencyName: emergencyName, emergencyRelationship: emergencyRelationship,
      emergencyPhone: emergencyPhone, emergencyEmail: emergencyEmail,
    );
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

// ── Document (from the employee detail response's "documents" array) ─────────
// Real backend document types are only: pan_card, aadhaar_card,
// degree_certificate, experience_letter, other — five values. There is no
// "passport_photo" or "cancelled_cheque" type server-side.

@immutable
class EmployeeDocumentEntity {
  final int id;
  final String documentType;
  final String documentTypeDisplay;
  final String fileUrl;
  final String fileName;
  final int fileSize;
  final String uploadedAt;

  const EmployeeDocumentEntity({
    required this.id,
    required this.documentType,
    required this.documentTypeDisplay,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.uploadedAt,
  });

  factory EmployeeDocumentEntity.fromJson(Map<String, dynamic> json) =>
      EmployeeDocumentEntity(
        id:                  json['id'] as int? ?? 0,
        documentType:        json['document_type'] as String? ?? '',
        documentTypeDisplay: json['document_type_display'] as String? ?? '',
        // Backend key is literally "file", not "file_url".
        fileUrl:             json['file'] as String? ?? '',
        fileName:            json['file_name'] as String? ?? '',
        fileSize:            json['file_size'] as int? ?? 0,
        uploadedAt:          json['uploaded_at'] as String? ?? '',
      );
}

// ── Picker option — shared shape for /employees/hrs/ and /employees/managers/ ─

@immutable
class EmployeePickerOption {
  final String id; // real User UUID (used as hr_id / reporting_manager_id)
  final String employeeId;
  final String fullName;
  final String department;
  final String branch;

  const EmployeePickerOption({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.department,
    required this.branch,
  });

  factory EmployeePickerOption.fromJson(Map<String, dynamic> json) =>
      EmployeePickerOption(
        id:         json['id']?.toString() ?? '',
        employeeId: json['employee_id'] as String? ?? '',
        fullName:   json['full_name'] as String? ?? '',
        department: json['department'] as String? ?? '',
        branch:     json['branch'] as String? ?? '',
      );
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

  static final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  Map<String, String> validate() {
    final errors = <String, String>{};
    if (firstName.trim().isEmpty) errors['first_name'] = 'First name is required.';
    if (lastName.trim().isEmpty)  errors['last_name'] = 'Last name is required.';
    if (email.trim().isEmpty) {
      errors['email'] = 'Work email is required.';
    } else if (!_emailRe.hasMatch(email.trim())) {
      errors['email'] = 'Enter a valid email address.';
    }
    // Mirrors EmployeeListCreateView.post's _is_valid_phone: optional field,
    // but if provided it must be exactly 10 digits (spaces/-/()/./ stripped
    // first) with an optional leading 91 or +91.
    final phoneError = FormValidators.employeeCreatePhone(phone);
    if (phoneError != null) errors['phone'] = phoneError;
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

// ── Form data (edit only) ──────────────────────────────────────────────────
//
// `PUT /employees/<employee_id>/` only reads and persists these 8 keys —
// everything else sent is silently ignored by the backend:
//   role (Role.name slug), department, designation, branch, phone, full_name,
//   date_of_joining, date_of_birth, hr_id, reporting_manager_id
//
// This diverges enough from the create form (single full_name vs first/last
// split, role sent as a slug string vs an id, no employee_type, plus the
// dob/hr/reporting-manager fields the create endpoint doesn't accept) that a
// distinct class is clearer than bolting "edit-only" fields onto
// [EmployeeFormData].
class EmployeeUpdateFormData {
  String fullName;
  String phone;
  String role; // Role.name slug, e.g. 'hr_admin' — NOT the role id
  int? departmentId;
  String department;
  String designation;
  String branch;
  String dateOfJoining;
  String dateOfBirth;
  String gender;
  String maritalStatus;
  String fatherName;
  String bloodGroup;
  String currentAddress;
  String permanentAddress;
  String? hrId;
  String? hrName;
  String? reportingManagerId;
  String? reportingManagerName;
  // Whether the currently-selected `role` is a manager-type role
  // (Role.can_manage_team on the backend) — null until resolved against the
  // loaded roles list. See `isManagerRole` doc comment below for why this
  // can't be derived from `role` itself.
  bool? canManageTeam;

  EmployeeUpdateFormData({
    this.fullName = '',
    this.phone = '',
    this.role = '',
    this.departmentId,
    this.department = '',
    this.designation = '',
    this.branch = '',
    this.dateOfJoining = '',
    this.dateOfBirth = '',
    this.gender = '',
    this.maritalStatus = '',
    this.fatherName = '',
    this.bloodGroup = '',
    this.currentAddress = '',
    this.permanentAddress = '',
    this.hrId,
    this.hrName,
    this.reportingManagerId,
    this.reportingManagerName,
    this.canManageTeam,
  });

  factory EmployeeUpdateFormData.fromModel(EmployeeModel model) =>
      EmployeeUpdateFormData(
        fullName:   model.fullName,
        phone:      model.phone,
        role:       model.role,
        department: model.department,
        designation: model.designation,
        branch:     model.branch,
        dateOfJoining: model.dateOfJoining,
        dateOfBirth:   model.dateOfBirth,
        gender:        model.gender,
        maritalStatus: model.maritalStatus,
        fatherName:    model.fatherName,
        bloodGroup:    model.bloodGroup,
        currentAddress:   model.currentAddress,
        permanentAddress: model.permanentAddress,
        hrId:       model.hrId,
        hrName:     model.hrName,
        reportingManagerId:   model.reportingManagerId,
        reportingManagerName: model.reportingManagerName,
      );

  // Managers don't have a reporting manager — the backend rejects
  // `reporting_manager_id` outright when the (possibly just-changed) role
  // has `can_manage_team=True`, so the field is hidden and omitted from the
  // payload in that case.
  //
  // IMPORTANT: this must NOT be `role == 'manager'`. Role *names* drift in
  // this system (e.g. the originally-seeded 'manager' role was renamed to
  // 'manager__team_lead' via Settings -> Roles, per the backend migration
  // 0045's docstring) — a literal-string check silently stops matching after
  // such a rename, so `reporting_manager_id` gets sent for an employee whose
  // role IS manager-type, and the backend's PUT rejects the whole request
  // with 400 "Managers do not have a reporting manager." `canManageTeam` is
  // resolved from the real Role.can_manage_team flag (see the caller in
  // add_employee_sheet.dart) instead.
  bool get isManagerRole => canManageTeam ?? false;

  Map<String, String> validate() {
    final errors = <String, String>{};
    if (role.isEmpty)            errors['role'] = 'Role is required.';
    if (department.isEmpty)      errors['department'] = 'Department is required.';
    if (designation.isEmpty)     errors['designation'] = 'Designation is required.';
    if (branch.isEmpty)          errors['branch'] = 'Branch is required.';
    if (dateOfBirth.isEmpty) {
      errors['date_of_birth'] = 'Date of birth is required.';
    } else {
      final dob = DateTime.tryParse(dateOfBirth);
      if (dob == null) {
        errors['date_of_birth'] = 'Enter a valid date of birth.';
      } else {
        final now = DateTime.now();
        var age = now.year - dob.year;
        if (now.month < dob.month ||
            (now.month == dob.month && now.day < dob.day)) {
          age--;
        }
        if (age < 18 || age > 80) {
          errors['date_of_birth'] = 'Age must be between 18 and 80 years.';
        }
      }
    }
    return errors;
  }

  // Full Name, Phone and Date of Joining are read-only forever on the
  // Employee Profile (matches web — see the class doc comment above: the
  // backend's PUT would technically accept changes to them, but the web UI
  // deliberately never offers them as editable, so neither does this form).
  Map<String, dynamic> toJson() => {
        'role':            role,
        'department':      department,
        'designation':     designation,
        'branch':          branch,
        'date_of_birth': dateOfBirth,
        'gender': gender,
        'marital_status': maritalStatus,
        'father_name': fatherName,
        'blood_group': bloodGroup,
        'current_address': currentAddress,
        'permanent_address': permanentAddress,
        // Always sent (even null) so clearing HR works; reporting_manager_id
        // is omitted entirely for managers — sending it at all is rejected.
        'hr_id': hrId,
        if (!isManagerRole) 'reporting_manager_id': reportingManagerId,
      };
}
