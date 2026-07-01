import 'package:flutter/foundation.dart';

@immutable
class ApprovalDocument {
  final int id;
  final String documentTypeDisplay;
  final String fileName;
  final String? fileUrl;

  const ApprovalDocument({
    required this.id,
    required this.documentTypeDisplay,
    required this.fileName,
    this.fileUrl,
  });

  factory ApprovalDocument.fromJson(Map<String, dynamic> json) =>
      ApprovalDocument(
        id:                   json['id'] as int,
        documentTypeDisplay:  json['document_type_display'] as String? ?? '',
        fileName:             json['file_name'] as String? ?? '',
        fileUrl:              json['file_url'] as String?,
      );
}

@immutable
class ApprovalProfile {
  final String? dateOfBirth;
  final String? gender;
  final String? maritalStatus;
  final String? fatherName;
  final String? bloodGroup;
  final String? currentAddress;
  final String? permanentAddress;
  final String? highestQualification;
  final String? institution;
  final int? yearOfPassing;
  final String? totalExperienceYears;
  final String? previousEmployer;
  final String? previousDesignation;
  final String? accountNumber;
  final String? ifscCode;
  final String? bankName;
  final String? bankBranchName;
  final String? accountHolderName;
  final String? accountType;
  final String? emergencyName;
  final String? emergencyRelationship;
  final String? emergencyPhone;

  const ApprovalProfile({
    this.dateOfBirth,
    this.gender,
    this.maritalStatus,
    this.fatherName,
    this.bloodGroup,
    this.currentAddress,
    this.permanentAddress,
    this.highestQualification,
    this.institution,
    this.yearOfPassing,
    this.totalExperienceYears,
    this.previousEmployer,
    this.previousDesignation,
    this.accountNumber,
    this.ifscCode,
    this.bankName,
    this.bankBranchName,
    this.accountHolderName,
    this.accountType,
    this.emergencyName,
    this.emergencyRelationship,
    this.emergencyPhone,
  });

  factory ApprovalProfile.fromJson(Map<String, dynamic> json) =>
      ApprovalProfile(
        dateOfBirth:           json['date_of_birth'] as String?,
        gender:                json['gender'] as String?,
        maritalStatus:         json['marital_status'] as String?,
        fatherName:            json['father_name'] as String?,
        bloodGroup:            json['blood_group'] as String?,
        currentAddress:        json['current_address'] as String?,
        permanentAddress:      json['permanent_address'] as String?,
        highestQualification:  json['highest_qualification'] as String?,
        institution:           json['institution'] as String?,
        yearOfPassing:         json['year_of_passing'] as int?,
        totalExperienceYears:  json['total_experience_years'] as String?,
        previousEmployer:      json['previous_employer'] as String?,
        previousDesignation:   json['previous_designation'] as String?,
        accountNumber:         json['account_number'] as String?,
        ifscCode:              json['ifsc_code'] as String?,
        bankName:              json['bank_name'] as String?,
        bankBranchName:        json['bank_branch_name'] as String?,
        accountHolderName:     json['account_holder_name'] as String?,
        accountType:           json['account_type'] as String?,
        emergencyName:         json['emergency_name'] as String?,
        emergencyRelationship: json['emergency_relationship'] as String?,
        emergencyPhone:        json['emergency_phone'] as String?,
      );
}

@immutable
class ApprovalUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String department;
  final String designation;
  final String branch;
  final String roleName;
  final String roleDisplay;
  final String employeeId;
  final String? dateOfJoining;
  final String onboardingStatus;
  final String dateJoined;
  final int? candidateId;
  final String positionApplied;
  final ApprovalProfile? profile;
  final List<ApprovalDocument> documents;

  const ApprovalUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.department,
    required this.designation,
    required this.branch,
    required this.roleName,
    required this.roleDisplay,
    required this.employeeId,
    this.dateOfJoining,
    required this.onboardingStatus,
    required this.dateJoined,
    this.candidateId,
    required this.positionApplied,
    this.profile,
    required this.documents,
  });

  factory ApprovalUser.fromJson(Map<String, dynamic> json) => ApprovalUser(
    id:               json['id'] as String,
    fullName:         json['full_name'] as String? ?? '',
    email:            json['email'] as String? ?? '',
    phone:            json['phone'] as String? ?? '',
    department:       json['department'] as String? ?? '',
    designation:      json['designation'] as String? ?? '',
    branch:           json['branch'] as String? ?? '',
    roleName:         json['role_name'] as String? ?? '',
    roleDisplay:      json['role_display'] as String? ?? '',
    employeeId:       json['employee_id'] as String? ?? '',
    dateOfJoining:    json['date_of_joining'] as String?,
    onboardingStatus: json['onboarding_status'] as String? ?? '',
    dateJoined:       json['date_joined'] as String? ?? '',
    candidateId:      json['candidate_id'] as int?,
    positionApplied:  json['position_applied'] as String? ?? '',
    profile: json['profile'] is Map<String, dynamic>
        ? ApprovalProfile.fromJson(json['profile'] as Map<String, dynamic>)
        : null,
    documents: (json['documents'] as List<dynamic>? ?? [])
        .map((d) => ApprovalDocument.fromJson(d as Map<String, dynamic>))
        .toList(),
  );

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    if (parts.first.isNotEmpty) return parts.first[0].toUpperCase();
    return '?';
  }
}
