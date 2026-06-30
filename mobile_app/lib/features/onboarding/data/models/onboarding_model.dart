import '../../domain/entities/onboarding_entity.dart';

class OnboardingPersonalModel extends OnboardingPersonalEntity {
  const OnboardingPersonalModel({
    super.firstName,
    super.lastName,
    super.dateOfBirth,
    super.gender,
    super.nationality,
    super.bloodGroup,
    super.maritalStatus,
    super.fatherName,
    super.phone,
    super.addressLine1,
    super.addressLine2,
    super.city,
    super.state,
    super.pincode,
    super.country,
  });

  factory OnboardingPersonalModel.fromJson(Map<String, dynamic> json) =>
      OnboardingPersonalModel(
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        gender: json['gender'] as String?,
        nationality: json['nationality'] as String?,
        bloodGroup: json['blood_group'] as String?,
        maritalStatus: json['marital_status'] as String?,
        fatherName: json['father_name'] as String?,
        phone: json['phone'] as String?,
        addressLine1: json['address_line1'] as String?,
        addressLine2: json['address_line2'] as String?,
        city: json['city'] as String?,
        state: json['state'] as String?,
        pincode: json['pincode'] as String?,
        country: json['country'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth,
        'gender': gender,
        'nationality': nationality,
        'blood_group': bloodGroup,
        'marital_status': maritalStatus,
        'father_name': fatherName,
        'phone': phone,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'city': city,
        'state': state,
        'pincode': pincode,
        'country': country,
      }..removeWhere((_, v) => v == null);
}

class OnboardingEducationModel extends OnboardingEducationEntity {
  const OnboardingEducationModel({
    super.qualification,
    super.institution,
    super.specialization,
    super.yearOfPassing,
    super.grade,
  });

  factory OnboardingEducationModel.fromJson(Map<String, dynamic> json) =>
      OnboardingEducationModel(
        qualification: json['qualification'] as String?,
        institution: json['institution'] as String?,
        specialization: json['specialization'] as String?,
        yearOfPassing: json['year_of_passing'] as String?,
        grade: json['grade'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'qualification': qualification,
        'institution': institution,
        'specialization': specialization,
        'year_of_passing': yearOfPassing,
        'grade': grade,
      }..removeWhere((_, v) => v == null);
}

class OnboardingBankModel extends OnboardingBankEntity {
  const OnboardingBankModel({
    super.bankName,
    super.accountNumber,
    super.ifscCode,
    super.branchName,
    super.accountType,
  });

  factory OnboardingBankModel.fromJson(Map<String, dynamic> json) =>
      OnboardingBankModel(
        bankName: json['bank_name'] as String?,
        accountNumber: json['account_number'] as String?,
        ifscCode: json['ifsc_code'] as String?,
        branchName: json['branch_name'] as String?,
        accountType: json['account_type'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'bank_name': bankName,
        'account_number': accountNumber,
        'ifsc_code': ifscCode,
        'branch_name': branchName,
        'account_type': accountType,
      }..removeWhere((_, v) => v == null);
}

class OnboardingEmergencyModel extends OnboardingEmergencyEntity {
  const OnboardingEmergencyModel({
    super.contactName,
    super.relationship,
    super.phone,
    super.email,
    super.address,
  });

  factory OnboardingEmergencyModel.fromJson(Map<String, dynamic> json) =>
      OnboardingEmergencyModel(
        contactName: json['contact_name'] as String?,
        relationship: json['relationship'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'contact_name': contactName,
        'relationship': relationship,
        'phone': phone,
        'email': email,
        'address': address,
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
        docType: json['doc_type'] as String,
        docTypeDisplay: json['doc_type_display'] as String? ?? json['doc_type'] as String,
        fileUrl: json['file_url'] as String? ?? json['file'] as String? ?? '',
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

  factory OnboardingProfileModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? json['data'] as Map<String, dynamic> : json;
    return OnboardingProfileModel(
      status: data['status'] as String? ?? 'pending',
      currentStep: data['current_step'] as int? ?? 0,
      personal: data['personal'] != null
          ? OnboardingPersonalModel.fromJson(
              data['personal'] as Map<String, dynamic>)
          : const OnboardingPersonalModel(),
      education: data['education'] != null
          ? OnboardingEducationModel.fromJson(
              data['education'] as Map<String, dynamic>)
          : const OnboardingEducationModel(),
      bank: data['bank'] != null
          ? OnboardingBankModel.fromJson(data['bank'] as Map<String, dynamic>)
          : const OnboardingBankModel(),
      emergency: data['emergency'] != null
          ? OnboardingEmergencyModel.fromJson(
              data['emergency'] as Map<String, dynamic>)
          : const OnboardingEmergencyModel(),
      documents: (data['documents'] as List<dynamic>?)
              ?.map((d) =>
                  OnboardingDocModel.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
