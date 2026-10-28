import 'package:flutter/material.dart';
import '../../domain/entities/my_profile_entity.dart';

// ── Nested profile detail ──────────────────────────────────────────────────────

class MyProfileDetailModel extends MyProfileDetailEntity {
  const MyProfileDetailModel({
    super.dateOfBirth,
    super.gender,
    super.maritalStatus,
    super.fatherName,
    super.bloodGroup,
    super.currentAddress,
    super.permanentAddress,
    super.highestQualification,
    super.institution,
    super.yearOfPassing,
    super.specialization,
    super.totalExperienceYears,
    super.previousEmployer,
    super.previousDesignation,
    super.leavingReason,
    super.accountNumber,
    super.ifscCode,
    super.bankName,
    super.bankBranchName,
    super.accountHolderName,
    super.accountType,
    super.emergencyName,
    super.emergencyRelationship,
    super.emergencyPhone,
    super.emergencyEmail,
    super.updatedAt,
  });

  static const empty = MyProfileDetailModel();

  // The backend returns real JSON `null` for these fields (not '') — handle
  // both `int` and numeric-string just in case, but never assume presence.
  factory MyProfileDetailModel.fromJson(Map<String, dynamic> json) {
    final yearRaw = json['year_of_passing'];
    return MyProfileDetailModel(
      dateOfBirth: json['date_of_birth'] as String?,
      gender: json['gender'] as String? ?? '',
      maritalStatus: json['marital_status'] as String? ?? '',
      fatherName: json['father_name'] as String? ?? '',
      bloodGroup: json['blood_group'] as String? ?? '',
      currentAddress: json['current_address'] as String? ?? '',
      permanentAddress: json['permanent_address'] as String? ?? '',
      highestQualification: json['highest_qualification'] as String? ?? '',
      institution: json['institution'] as String? ?? '',
      yearOfPassing: yearRaw is int
          ? yearRaw
          : (yearRaw == null ? null : int.tryParse(yearRaw.toString())),
      specialization: json['specialization'] as String? ?? '',
      totalExperienceYears: json['total_experience_years']?.toString(),
      previousEmployer: json['previous_employer'] as String? ?? '',
      previousDesignation: json['previous_designation'] as String? ?? '',
      leavingReason: json['leaving_reason'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      ifscCode: json['ifsc_code'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
      bankBranchName: json['bank_branch_name'] as String? ?? '',
      accountHolderName: json['account_holder_name'] as String? ?? '',
      accountType: json['account_type'] as String? ?? '',
      emergencyName: json['emergency_name'] as String? ?? '',
      emergencyRelationship: json['emergency_relationship'] as String? ?? '',
      emergencyPhone: json['emergency_phone'] as String? ?? '',
      emergencyEmail: json['emergency_email'] as String? ?? '',
      updatedAt: json['updated_at'] as String?,
    );
  }

  /// Returns a copy with only the PATCH-editable fields overridden — used to
  /// optimistically update local state after a successful save without a
  /// second round-trip to the server.
  MyProfileDetailModel copyWithEditable({
    required String currentAddress,
    required String permanentAddress,
    required String emergencyName,
    required String emergencyRelationship,
    required String emergencyPhone,
    required String emergencyEmail,
  }) {
    return MyProfileDetailModel(
      dateOfBirth: dateOfBirth,
      gender: gender,
      maritalStatus: maritalStatus,
      fatherName: fatherName,
      bloodGroup: bloodGroup,
      currentAddress: currentAddress,
      permanentAddress: permanentAddress,
      highestQualification: highestQualification,
      institution: institution,
      yearOfPassing: yearOfPassing,
      specialization: specialization,
      totalExperienceYears: totalExperienceYears,
      previousEmployer: previousEmployer,
      previousDesignation: previousDesignation,
      leavingReason: leavingReason,
      accountNumber: accountNumber,
      ifscCode: ifscCode,
      bankName: bankName,
      bankBranchName: bankBranchName,
      accountHolderName: accountHolderName,
      accountType: accountType,
      emergencyName: emergencyName,
      emergencyRelationship: emergencyRelationship,
      emergencyPhone: emergencyPhone,
      emergencyEmail: emergencyEmail,
      updatedAt: updatedAt,
    );
  }
}

// ── My profile ──────────────────────────────────────────────────────────────────

class MyProfileModel extends MyProfileEntity {
  const MyProfileModel({
    required super.id,
    required super.fullName,
    required super.email,
    required super.phone,
    required super.employeeId,
    required super.department,
    required super.designation,
    required super.branch,
    required super.roleName,
    required super.roleDisplay,
    super.dateOfJoining,
    required super.dateJoined,
    required super.onboardingStatus,
    required super.assessmentStatus,
    super.photoUrl,
    required super.detail,
  });

  factory MyProfileModel.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] as Map<String, dynamic>?) ?? {};
    return MyProfileModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      department: json['department'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      roleName: json['role_name'] as String? ?? '',
      roleDisplay: json['role_display'] as String? ?? '',
      dateOfJoining: json['date_of_joining'] as String?,
      dateJoined: json['date_joined'] as String? ?? '',
      onboardingStatus: json['onboarding_status'] as String? ?? '',
      assessmentStatus: json['assessment_status'] as String? ?? '',
      photoUrl: json['profile_photo_url'] as String?,
      detail: MyProfileDetailModel.fromJson(profile),
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

  /// Applies a successful PATCH locally so the UI reflects the save
  /// immediately without waiting on a second GET — the backend's PATCH
  /// response carries no body other than a success message.
  MyProfileModel applyUpdate(MyProfileUpdateData data) {
    final detailModel =
        detail is MyProfileDetailModel ? detail as MyProfileDetailModel : MyProfileDetailModel.empty;
    return MyProfileModel(
      id: id,
      fullName: fullName,
      email: email,
      phone: data.phone,
      employeeId: employeeId,
      department: department,
      designation: designation,
      branch: branch,
      roleName: roleName,
      roleDisplay: roleDisplay,
      dateOfJoining: dateOfJoining,
      dateJoined: dateJoined,
      onboardingStatus: onboardingStatus,
      assessmentStatus: assessmentStatus,
      photoUrl: photoUrl,
      detail: detailModel.copyWithEditable(
        currentAddress: data.currentAddress,
        permanentAddress: data.permanentAddress,
        emergencyName: data.emergencyName,
        emergencyRelationship: data.emergencyRelationship,
        emergencyPhone: data.emergencyPhone,
        emergencyEmail: data.emergencyEmail,
      ),
    );
  }

  /// Applies a successful photo upload/remove locally so the avatar updates
  /// immediately without a second round-trip — mirrors [applyUpdate].
  MyProfileModel copyWithPhotoUrl(String? newPhotoUrl) {
    return MyProfileModel(
      id: id,
      fullName: fullName,
      email: email,
      phone: phone,
      employeeId: employeeId,
      department: department,
      designation: designation,
      branch: branch,
      roleName: roleName,
      roleDisplay: roleDisplay,
      dateOfJoining: dateOfJoining,
      dateJoined: dateJoined,
      onboardingStatus: onboardingStatus,
      assessmentStatus: assessmentStatus,
      photoUrl: newPhotoUrl,
      detail: detail,
    );
  }
}

// ── PATCH form data ─────────────────────────────────────────────────────────────

/// Mirrors `MyProfileUpdateSerializer` exactly — only these fields are
/// accepted by `PATCH /employees/me/`; everything else is read-only there.
class MyProfileUpdateData {
  String phone;
  String currentAddress;
  String permanentAddress;
  String emergencyName;
  String emergencyRelationship;
  String emergencyPhone;
  String emergencyEmail;

  MyProfileUpdateData({
    this.phone = '',
    this.currentAddress = '',
    this.permanentAddress = '',
    this.emergencyName = '',
    this.emergencyRelationship = '',
    this.emergencyPhone = '',
    this.emergencyEmail = '',
  });

  factory MyProfileUpdateData.fromProfile(MyProfileEntity profile) => MyProfileUpdateData(
        phone: profile.phone,
        currentAddress: profile.detail.currentAddress,
        permanentAddress: profile.detail.permanentAddress,
        emergencyName: profile.detail.emergencyName,
        emergencyRelationship: profile.detail.emergencyRelationship,
        emergencyPhone: profile.detail.emergencyPhone,
        emergencyEmail: profile.detail.emergencyEmail,
      );

  Map<String, dynamic> toJson() => {
        'phone': phone.trim(),
        'current_address': currentAddress.trim(),
        'permanent_address': permanentAddress.trim(),
        'emergency_name': emergencyName.trim(),
        'emergency_relationship': emergencyRelationship.trim(),
        'emergency_phone': emergencyPhone.trim(),
        'emergency_email': emergencyEmail.trim(),
      };
}
