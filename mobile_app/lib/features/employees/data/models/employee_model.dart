import 'package:flutter/material.dart';

import '../../../../shared/validators/form_validators.dart';
import '../../../onboarding/data/models/onboarding_config_models.dart' show CustomFileValue;

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

  /// User.onboarding_status — pending | draft | submitted | complete |
  /// rejected ('' when not sent). See [isPendingOnboarding].
  final String onboardingStatus;
  final String dateOfJoining;

  /// The employee's own user id (`uuid`) — `id` above is the display code.
  final String? uuid;

  // Assigned people. The ids are the people's user ids (`uuid` in the API's
  // {id, uuid, name} objects) — what hr_id / reporting_manager_id /
  // reporting_approver_id expect and what the picker lists return. The
  // object's `id` is only their display employee code (web
  // employees/[id]/page.tsx reads `.uuid` for the same reason).
  final String? reportingManagerId;
  final String? reportingManagerName;
  final String? reportingApproverId;
  final String? reportingApproverName;
  final String? hrId;
  final String? hrName;

  /// Notice period in days assigned by HR (Settings → Notice Period);
  /// null = not assigned. Display only: never sent back on save (web
  /// employees/[id]/page.tsx).
  final int? noticePeriodDays;
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

  // Profile: EPF / Statutory (web PROFILE_SECTIONS "epf"). EmployeeProfile
  // uan_number / name_as_per_aadhar / esi_number. Production's employee
  // detail (accounts _employee_dict) does not return these keys today, so
  // they read '' and [statutoryReturned] is false; they are parsed if a
  // server ever includes them. Sensitive — never logged.
  final String uanNumber;
  final String nameAsPerAadhar;
  final String esiNumber;

  /// Whether the server sent any of the statutory keys at all.
  final bool statutoryReturned;

  // HR-created custom fields (Settings → Onboarding Fields): text-type values
  // by field_key from profile.custom_field_values — every saved key is kept,
  // including ones whose field is hidden or no longer configured — and the
  // file-type values from custom_file_fields.
  final Map<String, String> customFieldValues;
  final List<CustomFileValue> customFileFields;

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
    this.onboardingStatus = '',
    this.role = '',
    this.uuid,
    this.reportingManagerId,
    this.reportingManagerName,
    this.reportingApproverId,
    this.reportingApproverName,
    this.hrId,
    this.hrName,
    this.noticePeriodDays,
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
    this.uanNumber = '',
    this.nameAsPerAadhar = '',
    this.esiNumber = '',
    this.statutoryReturned = false,
    this.customFieldValues = const {},
    this.customFileFields = const [],
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] as Map<String, dynamic>?) ?? {};
    // Backend omits the "reporting_manager" key entirely when the employee's
    // own role is "manager" (managers have no reporting manager) — must not
    // assume the key exists. "hr" is always present but its id/name may be null.
    final reportingManager = json['reporting_manager'] as Map<String, dynamic>?;
    final hr = json['hr'] as Map<String, dynamic>?;
    final approver = json['reporting_approver'] as Map<String, dynamic>?;
    String? uuidOf(Map<String, dynamic>? person) {
      final v = person?['uuid'];
      return v is String && v.isNotEmpty ? v : null;
    }

    final documentsRaw = json['documents'] as List<dynamic>? ?? [];
    return EmployeeModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      department: json['department'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      role: json['role'] as String? ?? '',
      roleDisplay: json['role_display'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      status: json['status'] as String? ?? 'inactive',
      onboardingStatus: json['onboarding_status'] is String ? (json['onboarding_status'] as String).trim() : '',
      dateOfJoining: json['date_of_joining'] as String? ?? '',
      uuid: json['uuid'] is String ? json['uuid'] as String : null,
      reportingManagerId: uuidOf(reportingManager),
      reportingManagerName: reportingManager?['name'] as String?,
      reportingApproverId: uuidOf(approver),
      reportingApproverName: approver?['name'] as String?,
      hrId: uuidOf(hr),
      hrName: hr?['name'] as String?,
      noticePeriodDays: _noticeDays(json['notice_period_days']),
      documents: documentsRaw.whereType<Map<String, dynamic>>().map(EmployeeDocumentEntity.fromJson).toList(),
      dateOfBirth: profile['date_of_birth'] as String? ?? '',
      gender: profile['gender'] as String? ?? '',
      maritalStatus: profile['marital_status'] as String? ?? '',
      fatherName: profile['father_name'] as String? ?? '',
      bloodGroup: profile['blood_group'] as String? ?? '',
      currentAddress: profile['current_address'] as String? ?? '',
      permanentAddress: profile['permanent_address'] as String? ?? '',
      highestQualification: profile['highest_qualification'] as String? ?? '',
      specialization: profile['specialization'] as String? ?? '',
      institution: profile['institution'] as String? ?? '',
      yearOfPassing: profile['year_of_passing']?.toString() ?? '',
      totalExperienceYears: profile['total_experience_years'] as String? ?? '',
      previousEmployer: profile['previous_employer'] as String? ?? '',
      previousDesignation: profile['previous_designation'] as String? ?? '',
      leavingReason: profile['leaving_reason'] as String? ?? '',
      accountHolderName: profile['account_holder_name'] as String? ?? '',
      accountType: profile['account_type'] as String? ?? '',
      accountNumber: profile['account_number'] as String? ?? '',
      ifscCode: profile['ifsc_code'] as String? ?? '',
      bankName: profile['bank_name'] as String? ?? '',
      bankBranch: profile['bank_branch_name'] as String? ?? '',
      emergencyName: profile['emergency_name'] as String? ?? '',
      emergencyRelationship: profile['emergency_relationship'] as String? ?? '',
      emergencyPhone: profile['emergency_phone'] as String? ?? '',
      emergencyEmail: profile['emergency_email'] as String? ?? '',
      uanNumber: profile['uan_number'] as String? ?? '',
      nameAsPerAadhar: profile['name_as_per_aadhar'] as String? ?? '',
      esiNumber: profile['esi_number'] as String? ?? '',
      statutoryReturned: const ['uan_number', 'name_as_per_aadhar', 'esi_number'].any(profile.containsKey),
      customFieldValues: _customValues(profile['custom_field_values']),
      customFileFields: [
        for (final f in (json['custom_file_fields'] as List<dynamic>? ?? const []))
          if (f is Map<String, dynamic>)
            // This payload names the file URL `file` (web maps file_url: f.file).
            CustomFileValue.fromJson({...f, 'file_url': f['file_url'] ?? f['file']}),
      ],
    );
  }

  /// custom_field_values as strings (the backend stores what clients send —
  /// strings; anything else is kept as its text form, never dropped).
  static Map<String, String> _customValues(Object? raw) =>
      raw is Map ? {for (final e in raw.entries) '${e.key}': e.value == null ? '' : '${e.value}'} : const {};

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || fullName.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// `notice_period_days` as sent (an integer or null). Anything else — a
  /// non-number, a fraction or a negative — is treated as not assigned
  /// rather than shown as a misleading figure.
  static int? _noticeDays(Object? v) {
    final n = v is num ? v : (v is String ? num.tryParse(v.trim()) : null);
    if (n == null || n < 0 || n != n.roundToDouble()) return null;
    return n.toInt();
  }

  /// Web employees/[id]/page.tsx isPendingOnboarding: the employee hasn't
  /// submitted the onboarding form yet (never opened it, or saved a draft).
  /// Submitted, rejected (sent back) and complete profiles show normally.
  bool get isPendingOnboarding => onboardingStatus == 'pending' || onboardingStatus == 'draft';

  EmployeeModel copyWith({
    bool? isActive,
    String? status,
  }) {
    return EmployeeModel(
      id: id,
      employeeId: employeeId,
      firstName: firstName,
      lastName: lastName,
      fullName: fullName,
      email: email,
      phone: phone,
      department: department,
      designation: designation,
      branch: branch,
      role: role,
      roleDisplay: roleDisplay,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      onboardingStatus: onboardingStatus,
      dateOfJoining: dateOfJoining,
      uuid: uuid,
      reportingManagerId: reportingManagerId,
      reportingManagerName: reportingManagerName,
      reportingApproverId: reportingApproverId,
      reportingApproverName: reportingApproverName,
      hrId: hrId,
      hrName: hrName,
      noticePeriodDays: noticePeriodDays,
      documents: documents,
      dateOfBirth: dateOfBirth,
      gender: gender,
      maritalStatus: maritalStatus,
      fatherName: fatherName,
      bloodGroup: bloodGroup,
      currentAddress: currentAddress,
      permanentAddress: permanentAddress,
      highestQualification: highestQualification,
      specialization: specialization,
      institution: institution,
      yearOfPassing: yearOfPassing,
      totalExperienceYears: totalExperienceYears,
      previousEmployer: previousEmployer,
      previousDesignation: previousDesignation,
      leavingReason: leavingReason,
      accountHolderName: accountHolderName,
      accountType: accountType,
      accountNumber: accountNumber,
      ifscCode: ifscCode,
      bankName: bankName,
      bankBranch: bankBranch,
      emergencyName: emergencyName,
      emergencyRelationship: emergencyRelationship,
      emergencyPhone: emergencyPhone,
      emergencyEmail: emergencyEmail,
      uanNumber: uanNumber,
      nameAsPerAadhar: nameAsPerAadhar,
      esiNumber: esiNumber,
      statutoryReturned: statutoryReturned,
      customFieldValues: customFieldValues,
      customFileFields: customFileFields,
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

  factory EmployeeDocumentEntity.fromJson(Map<String, dynamic> json) => EmployeeDocumentEntity(
        id: json['id'] as int? ?? 0,
        documentType: json['document_type'] as String? ?? '',
        documentTypeDisplay: json['document_type_display'] as String? ?? '',
        // Backend key is literally "file", not "file_url".
        fileUrl: json['file'] as String? ?? '',
        fileName: json['file_name'] as String? ?? '',
        fileSize: json['file_size'] as int? ?? 0,
        uploadedAt: json['uploaded_at'] as String? ?? '',
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

  /// Role display name — only the Manager reporting list sends it.
  final String role;

  const EmployeePickerOption({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.department,
    required this.branch,
    this.role = '',
  });

  factory EmployeePickerOption.fromJson(Map<String, dynamic> json) => EmployeePickerOption(
        id: json['id']?.toString() ?? '',
        employeeId: json['employee_id'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        department: json['department'] as String? ?? '',
        branch: json['branch'] as String? ?? '',
        role: json['role'] as String? ?? '',
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
    total: 0,
    active: 0,
    onboarding: 0,
    departments: 0,
  );

  factory EmployeeStats.fromList(List<EmployeeModel> employees) {
    final depts = employees.map((e) => e.department).where((d) => d.isNotEmpty).toSet();
    return EmployeeStats(
      total: employees.length,
      active: employees.where((e) => e.status == 'active').length,
      onboarding: employees.where((e) => e.status == 'onboarding').length,
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
        search: search ?? this.search,
        status: status ?? this.status,
        department: department ?? this.department,
        designation: designation ?? this.designation,
        branch: branch ?? this.branch,
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
        id: json['id'] as int,
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

  /// Web AddEmployeeModal "Assign HR" — a user id from /employees/hrs/, or
  /// null for "— Auto-assign —" (the backend then picks the branch's HR).
  String? hrId;

  /// Web "Reporting Manager" — a user id from /employees/managers/, or null
  /// for "— Auto-assign —".
  String? reportingManagerId;

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
    this.hrId,
    this.reportingManagerId,
  });

  static final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  Map<String, String> validate() {
    final errors = <String, String>{};
    if (firstName.trim().isEmpty) errors['first_name'] = 'First name is required.';
    if (lastName.trim().isEmpty) errors['last_name'] = 'Last name is required.';
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
    if (roleId == null) errors['role'] = 'Role is required.';
    if (department.isEmpty) errors['department'] = 'Department is required.';
    if (designation.isEmpty) errors['designation'] = 'Designation is required.';
    if (branch.isEmpty) errors['branch'] = 'Branch is required.';
    if (dateOfJoining.isEmpty) errors['date_of_joining'] = 'Date of joining is required.';
    return errors;
  }

  Map<String, dynamic> toJson() => {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'email': email.trim().toLowerCase(),
        if (phone.trim().isNotEmpty) 'phone': phone.trim(),
        'role': roleId,
        'department': department,
        'designation': designation,
        'branch': branch,
        'employee_type': employeeType,
        'date_of_joining': dateOfJoining,
        // Web submit: `...(hr ? { hr_id: hr } : {})` — sent only when chosen.
        if (hrId != null && hrId!.isNotEmpty) 'hr_id': hrId,
        if (reportingManagerId != null && reportingManagerId!.isNotEmpty) 'reporting_manager_id': reportingManagerId,
      };
}

// ── Form data (edit only) ──────────────────────────────────────────────────
//
// `PUT /employees/<employee_id>/` (EmployeeDetailView.put) — what this
// form sends, as web employees/[id]/page.tsx onSave does for these fields:
//   role (Role.name slug), department, designation, branch, email, phone,
//   date_of_joining, date_of_birth, gender, marital_status, father_name,
//   blood_group, current/permanent address, hr_id, reporting_manager_id,
//   reporting_approver_id. (Other sections — education, bank, emergency,
//   statutory, custom fields — save through their own section sheets.)
// Employee ID and name are immutable on the backend and never sent.
//
// This diverges enough from the create form (single full_name vs first/last
// split, role sent as a slug string vs an id, no employee_type, plus the
// dob/hr/reporting-manager fields the create endpoint doesn't accept) that a
// distinct class is clearer than bolting "edit-only" fields onto
// [EmployeeFormData].
class EmployeeUpdateFormData {
  String fullName;

  /// Login email (web "Login Email", editable). The backend ignores a blank
  /// value (it never clears the login), validates the format and rejects an
  /// address another account already uses.
  String email;
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

  /// Web "Reporting Approver" (user id); null = none.
  String? reportingApproverId;
  String? reportingApproverName;

  /// The employee's own user id — never offered as their own approver.
  String? selfUuid;
  // Whether the currently-selected `role` is a manager-type role
  // (Role.can_manage_team on the backend) — null until resolved against the
  // loaded roles list. See `isManagerRole` doc comment below for why this
  // can't be derived from `role` itself.
  bool? canManageTeam;

  EmployeeUpdateFormData({
    this.fullName = '',
    this.email = '',
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
    this.reportingApproverId,
    this.reportingApproverName,
    this.selfUuid,
    this.canManageTeam,
  });

  factory EmployeeUpdateFormData.fromModel(EmployeeModel model) => EmployeeUpdateFormData(
        fullName: model.fullName,
        email: model.email,
        phone: model.phone,
        role: model.role,
        department: model.department,
        designation: model.designation,
        branch: model.branch,
        dateOfJoining: model.dateOfJoining,
        dateOfBirth: model.dateOfBirth,
        gender: model.gender,
        maritalStatus: model.maritalStatus,
        fatherName: model.fatherName,
        bloodGroup: model.bloodGroup,
        currentAddress: model.currentAddress,
        permanentAddress: model.permanentAddress,
        hrId: model.hrId,
        hrName: model.hrName,
        reportingManagerId: model.reportingManagerId,
        reportingManagerName: model.reportingManagerName,
        reportingApproverId: model.reportingApproverId,
        reportingApproverName: model.reportingApproverName,
        selfUuid: model.uuid,
      );

  // Whether the selected role is manager-type. A Manager may only have an
  // eligible Reporting Manager / Approver (COO / CMD, Admin Head, or their
  // branch's HR Manager / HR Admin / Branch Admin — backend
  // _manager_reporting_candidates), so for them both pickers list
  // /employees/managers/?manager_approvers=1&branch=&designation= (web
  // lib/reportingManager.ts), offer "None", and leave the employee out.
  //
  // IMPORTANT: this must NOT be `role == 'manager'`. Role *names* drift in
  // this system (roles can be renamed in Settings -> Roles) — `canManageTeam`
  // is resolved from the real Role.can_manage_team flag (see the caller in
  // add_employee_sheet.dart) instead, as web matches managerRoleNames by
  // can_manage_team.
  bool get isManagerRole => canManageTeam ?? false;

  /// Backend EMAIL_RE (accounts/views.py) — same check the PUT applies.
  static final RegExp _loginEmailRe = RegExp(
      r'^[A-Za-z0-9][A-Za-z0-9._%+-]*@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$');

  /// Backend _PHONE_RE_PROFILE (accounts/serializers.py).
  static final RegExp _phoneRe = RegExp(r'^\+?[\d\s\-()./]{7,20}$');

  Map<String, String> validate() {
    final errors = <String, String>{};
    // Web marks Login Email required; checked here with the backend's own
    // format rule and message so the request isn't sent only to be refused.
    final mail = email.trim();
    if (mail.isEmpty) {
      errors['email'] = 'Login email is required.';
    } else if (!_loginEmailRe.hasMatch(mail)) {
      errors['email'] = 'Enter a valid email address.';
    }
    final ph = phone.trim();
    if (ph.isNotEmpty && !_phoneRe.hasMatch(ph)) {
      errors['phone'] = 'Enter a valid mobile number (digits, spaces, +, -, ( ) allowed; 7–20 characters).';
    }
    if (role.isEmpty) errors['role'] = 'Role is required.';
    if (department.isEmpty) errors['department'] = 'Department is required.';
    if (designation.isEmpty) errors['designation'] = 'Designation is required.';
    if (branch.isEmpty) errors['branch'] = 'Branch is required.';
    if (dateOfBirth.isEmpty) {
      errors['date_of_birth'] = 'Date of birth is required.';
    } else {
      final dob = DateTime.tryParse(dateOfBirth);
      if (dob == null) {
        errors['date_of_birth'] = 'Enter a valid date of birth.';
      } else {
        final now = DateTime.now();
        var age = now.year - dob.year;
        if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
          age--;
        }
        if (age < 18 || age > 80) {
          errors['date_of_birth'] = 'Age must be between 18 and 80 years.';
        }
      }
    }
    return errors;
  }

  // Employee ID and full name are read-only (immutable on the backend).
  // Login Email, Phone and Date of Joining ARE editable, as on web's profile
  // form (employees/_data.ts Personal section; page.tsx onSave sends
  // `email || null`, `phone || ""`, `date_of_joining || null`).
  Map<String, dynamic> toJson() => {
        'email': email.trim().isEmpty ? null : email.trim(),
        'phone': phone.trim(),
        'date_of_joining': dateOfJoining.isEmpty ? null : dateOfJoining,
        'role': role,
        'department': department,
        'designation': designation,
        'branch': branch,
        'date_of_birth': dateOfBirth,
        'gender': gender,
        'marital_status': maritalStatus,
        'father_name': fatherName,
        'blood_group': bloodGroup,
        'current_address': currentAddress,
        'permanent_address': permanentAddress,
        // Always sent, null clears — as web onSave (`|| null`) for every role.
        // For a Manager the backend accepts only an eligible reporting
        // manager, or the one already stored, resent unchanged.
        'hr_id': hrId,
        'reporting_manager_id': reportingManagerId,
        // Always sent (null clears), as web.
        'reporting_approver_id': reportingApproverId,
      };
}
