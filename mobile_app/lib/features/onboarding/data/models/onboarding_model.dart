import '../../domain/entities/onboarding_entity.dart';

class OnboardingPersonalModel extends OnboardingPersonalEntity {
  const OnboardingPersonalModel({
    super.dateOfBirth,
    super.gender,
    super.bloodGroup,
    super.maritalStatus,
    super.fatherName,
    super.currentAddress,
    super.permanentAddress,
  });

  factory OnboardingPersonalModel.fromJson(Map<String, dynamic> json) =>
      OnboardingPersonalModel(
        dateOfBirth: json['date_of_birth'] as String?,
        gender: json['gender'] as String?,
        bloodGroup: json['blood_group'] as String?,
        maritalStatus: json['marital_status'] as String?,
        fatherName: json['father_name'] as String?,
        currentAddress: json['current_address'] as String?,
        permanentAddress: json['permanent_address'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'date_of_birth': dateOfBirth,
        'gender': gender,
        'blood_group': bloodGroup,
        'marital_status': maritalStatus,
        'father_name': fatherName,
        'current_address': currentAddress,
        'permanent_address': permanentAddress,
      }..removeWhere((_, v) => v == null);
}

class OnboardingEducationModel extends OnboardingEducationEntity {
  const OnboardingEducationModel({
    super.highestQualification,
    super.institution,
    super.yearOfPassing,
    super.specialization,
    super.totalExperienceYears,
    super.previousEmployer,
    super.previousDesignation,
    super.leavingReason,
  });

  factory OnboardingEducationModel.fromJson(Map<String, dynamic> json) =>
      OnboardingEducationModel(
        highestQualification: json['highest_qualification'] as String?,
        institution: json['institution'] as String?,
        yearOfPassing: json['year_of_passing']?.toString(),
        specialization: json['specialization'] as String?,
        totalExperienceYears: json['total_experience_years']?.toString(),
        previousEmployer: json['previous_employer'] as String?,
        previousDesignation: json['previous_designation'] as String?,
        leavingReason: json['leaving_reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'highest_qualification': highestQualification,
        'institution': institution,
        'year_of_passing': yearOfPassing != null
            ? int.tryParse(yearOfPassing!)
            : null,
        'specialization': specialization,
        'total_experience_years': totalExperienceYears != null
            ? double.tryParse(totalExperienceYears!)
            : null,
        'previous_employer': previousEmployer,
        'previous_designation': previousDesignation,
        'leaving_reason': leavingReason,
      }..removeWhere((_, v) => v == null);
}

class OnboardingBankModel extends OnboardingBankEntity {
  const OnboardingBankModel({
    super.accountHolderName,
    super.accountType,
    super.accountNumber,
    super.ifscCode,
    super.bankName,
    super.bankBranchName,
  });

  factory OnboardingBankModel.fromJson(Map<String, dynamic> json) =>
      OnboardingBankModel(
        accountHolderName: json['account_holder_name'] as String?,
        accountType: json['account_type'] as String?,
        accountNumber: json['account_number'] as String?,
        ifscCode: json['ifsc_code'] as String?,
        bankName: json['bank_name'] as String?,
        bankBranchName: json['bank_branch_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'account_holder_name': accountHolderName,
        'account_type': accountType,
        'account_number': accountNumber,
        'ifsc_code': ifscCode,
        'bank_name': bankName,
        'bank_branch_name': bankBranchName,
      }..removeWhere((_, v) => v == null);
}

class OnboardingEmergencyModel extends OnboardingEmergencyEntity {
  const OnboardingEmergencyModel({
    super.emergencyName,
    super.emergencyRelationship,
    super.emergencyPhone,
    super.emergencyEmail,
  });

  factory OnboardingEmergencyModel.fromJson(Map<String, dynamic> json) =>
      OnboardingEmergencyModel(
        emergencyName: json['emergency_name'] as String?,
        emergencyRelationship: json['emergency_relationship'] as String?,
        emergencyPhone: json['emergency_phone'] as String?,
        emergencyEmail: json['emergency_email'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'emergency_name': emergencyName,
        'emergency_relationship': emergencyRelationship,
        'emergency_phone': emergencyPhone,
        'emergency_email': emergencyEmail,
      }..removeWhere((_, v) => v == null);
}

class OnboardingDocModel extends OnboardingDocEntity {
  const OnboardingDocModel({
    required super.id,
    required super.docType,
    required super.docTypeDisplay,
    required super.fileUrl,
    required super.fileName,
  });

  factory OnboardingDocModel.fromJson(Map<String, dynamic> json) =>
      OnboardingDocModel(
        id: json['id'] as int,
        docType: json['document_type'] as String? ??
            json['doc_type'] as String? ?? '',
        docTypeDisplay: json['document_type_display'] as String? ??
            json['doc_type_display'] as String? ??
            json['document_type'] as String? ?? '',
        fileUrl: json['file'] as String? ?? json['file_url'] as String? ?? '',
        fileName: json['file_name'] as String? ?? '',
      );
}

class OnboardingProfileModel extends OnboardingProfileEntity {
  const OnboardingProfileModel({
    required super.status,
    required super.currentStep,
    required super.personal,
    required super.education,
    required super.bank,
    required super.emergency,
    required super.documents,
  });

  /// Backend `GET /onboarding/` returns the [EmployeeProfileSerializer]
  /// fields flat (not grouped by step) plus a `completed_steps` list of
  /// step indices (0-4) whose required fields are already filled — there
  /// is no `status`/`current_step`/nested `personal`/`documents` keys, so
  /// those are derived here or supplied by the caller.
  factory OnboardingProfileModel.fromJson(
    Map<String, dynamic> json, {
    String status = 'pending',
    List<OnboardingDocModel> documents = const [],
  }) {
    final data = json['data'] is Map
        ? json['data'] as Map<String, dynamic>
        : json;
    final completedSteps = (data['completed_steps'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toSet() ??
        <int>{};
    final currentStep = List.generate(5, (i) => i)
        .firstWhere((s) => !completedSteps.contains(s), orElse: () => 4);
    return OnboardingProfileModel(
      status: status,
      currentStep: currentStep,
      personal: OnboardingPersonalModel.fromJson(data),
      education: OnboardingEducationModel.fromJson(data),
      bank: OnboardingBankModel.fromJson(data),
      emergency: OnboardingEmergencyModel.fromJson(data),
      documents: documents,
    );
  }
}
