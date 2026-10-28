/// Nested `profile` object returned by `GET /employees/me/` — backed by
/// `EmployeeProfileSerializer` on the backend. Unlike most serializers in
/// this codebase, empty nullable fields come back as real JSON `null`
/// (not `''`) — see [dateOfBirth], [yearOfPassing], [totalExperienceYears].
class MyProfileDetailEntity {
  final String? dateOfBirth;
  final String gender;
  final String maritalStatus;
  final String fatherName;
  final String bloodGroup;
  final String currentAddress;
  final String permanentAddress;
  final String highestQualification;
  final String institution;
  final int? yearOfPassing;
  final String specialization;
  final String? totalExperienceYears;
  final String previousEmployer;
  final String previousDesignation;
  final String leavingReason;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String bankBranchName;
  final String accountHolderName;
  final String accountType;
  final String emergencyName;
  final String emergencyRelationship;
  final String emergencyPhone;
  final String emergencyEmail;
  final String? updatedAt;

  const MyProfileDetailEntity({
    this.dateOfBirth,
    this.gender = '',
    this.maritalStatus = '',
    this.fatherName = '',
    this.bloodGroup = '',
    this.currentAddress = '',
    this.permanentAddress = '',
    this.highestQualification = '',
    this.institution = '',
    this.yearOfPassing,
    this.specialization = '',
    this.totalExperienceYears,
    this.previousEmployer = '',
    this.previousDesignation = '',
    this.leavingReason = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.bankName = '',
    this.bankBranchName = '',
    this.accountHolderName = '',
    this.accountType = '',
    this.emergencyName = '',
    this.emergencyRelationship = '',
    this.emergencyPhone = '',
    this.emergencyEmail = '',
    this.updatedAt,
  });
}

/// `GET /employees/me/` (`MyProfileView` + `MyProfileSerializer`) — the
/// authenticated user's own self-service profile. Note the top-level role
/// fields are `role_name`/`role_display` here, unlike the admin employee
/// endpoints which expose a plain `role` field — don't reuse a model that
/// assumes that shape.
class MyProfileEntity {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String employeeId;
  final String department;
  final String designation;
  final String branch;
  final String roleName;
  final String roleDisplay;
  final String? dateOfJoining;
  final String dateJoined;
  final String onboardingStatus;
  final String assessmentStatus;
  final String? photoUrl;
  final MyProfileDetailEntity detail;

  const MyProfileEntity({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.employeeId,
    required this.department,
    required this.designation,
    required this.branch,
    required this.roleName,
    required this.roleDisplay,
    this.dateOfJoining,
    required this.dateJoined,
    required this.onboardingStatus,
    required this.assessmentStatus,
    this.photoUrl,
    required this.detail,
  });
}
