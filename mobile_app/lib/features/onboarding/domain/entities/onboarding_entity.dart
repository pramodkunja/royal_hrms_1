class OnboardingPersonalEntity {
  final String? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String? maritalStatus;
  final String? fatherName;
  final String? currentAddress;
  final String? permanentAddress;

  const OnboardingPersonalEntity({
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.maritalStatus,
    this.fatherName,
    this.currentAddress,
    this.permanentAddress,
  });
}

class OnboardingEducationEntity {
  final String? highestQualification;
  final String? institution;
  final String? yearOfPassing;
  final String? specialization;
  final String? totalExperienceYears;
  final String? previousEmployer;
  final String? previousDesignation;
  final String? leavingReason;

  const OnboardingEducationEntity({
    this.highestQualification,
    this.institution,
    this.yearOfPassing,
    this.specialization,
    this.totalExperienceYears,
    this.previousEmployer,
    this.previousDesignation,
    this.leavingReason,
  });
}

class OnboardingBankEntity {
  final String? accountHolderName;
  final String? accountType;
  final String? accountNumber;
  final String? ifscCode;
  final String? bankName;
  final String? bankBranchName;

  const OnboardingBankEntity({
    this.accountHolderName,
    this.accountType,
    this.accountNumber,
    this.ifscCode,
    this.bankName,
    this.bankBranchName,
  });
}

class OnboardingEmergencyEntity {
  final String? emergencyName;
  final String? emergencyRelationship;
  final String? emergencyPhone;
  final String? emergencyEmail;

  const OnboardingEmergencyEntity({
    this.emergencyName,
    this.emergencyRelationship,
    this.emergencyPhone,
    this.emergencyEmail,
  });
}

class OnboardingDocEntity {
  final int id;
  final String docType;
  final String docTypeDisplay;
  final String fileUrl;
  final String fileName;

  const OnboardingDocEntity({
    required this.id,
    required this.docType,
    required this.docTypeDisplay,
    required this.fileUrl,
    required this.fileName,
  });
}

class OnboardingProfileEntity {
  final String status;
  final int currentStep;
  final OnboardingPersonalEntity personal;
  final OnboardingEducationEntity education;
  final OnboardingBankEntity bank;
  final OnboardingEmergencyEntity emergency;
  final List<OnboardingDocEntity> documents;

  const OnboardingProfileEntity({
    required this.status,
    required this.currentStep,
    required this.personal,
    required this.education,
    required this.bank,
    required this.emergency,
    required this.documents,
  });

  static OnboardingProfileEntity empty() => const OnboardingProfileEntity(
        status: 'pending',
        currentStep: 0,
        personal: OnboardingPersonalEntity(),
        education: OnboardingEducationEntity(),
        bank: OnboardingBankEntity(),
        emergency: OnboardingEmergencyEntity(),
        documents: [],
      );
}
