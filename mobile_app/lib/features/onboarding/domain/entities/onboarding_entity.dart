class OnboardingPersonalEntity {
  final String? firstName;
  final String? lastName;
  final String? dateOfBirth;
  final String? gender;
  final String? nationality;
  final String? bloodGroup;
  final String? maritalStatus;
  final String? fatherName;
  final String? phone;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? pincode;
  final String? country;

  const OnboardingPersonalEntity({
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.nationality,
    this.bloodGroup,
    this.maritalStatus,
    this.fatherName,
    this.phone,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pincode,
    this.country,
  });
}

class OnboardingEducationEntity {
  final String? qualification;
  final String? institution;
  final String? specialization;
  final String? yearOfPassing;
  final String? grade;

  const OnboardingEducationEntity({
    this.qualification,
    this.institution,
    this.specialization,
    this.yearOfPassing,
    this.grade,
  });
}

class OnboardingBankEntity {
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? branchName;
  final String? accountType;

  const OnboardingBankEntity({
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.branchName,
    this.accountType,
  });
}

class OnboardingEmergencyEntity {
  final String? contactName;
  final String? relationship;
  final String? phone;
  final String? email;
  final String? address;

  const OnboardingEmergencyEntity({
    this.contactName,
    this.relationship,
    this.phone,
    this.email,
    this.address,
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
