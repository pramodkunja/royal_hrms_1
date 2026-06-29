import 'package:flutter/foundation.dart';

@immutable
class CompanyModel {
  final int? id;
  final String companyName;
  final String tradeName;
  final String? logoUrl;
  final String gstin;
  final String cin;
  final String pan;
  final String tan;
  final String address;
  final String city;
  final String state;
  final String pinCode;
  final String website;
  final String officialPhone;
  final String? updatedAt;

  const CompanyModel({
    this.id,
    required this.companyName,
    required this.tradeName,
    this.logoUrl,
    required this.gstin,
    required this.cin,
    required this.pan,
    required this.tan,
    required this.address,
    required this.city,
    required this.state,
    required this.pinCode,
    required this.website,
    required this.officialPhone,
    this.updatedAt,
  });

  factory CompanyModel.empty() => const CompanyModel(
    companyName: '', tradeName: '',
    gstin: '', cin: '', pan: '', tan: '',
    address: '', city: '', state: '', pinCode: '',
    website: '', officialPhone: '',
  );

  factory CompanyModel.fromJson(Map<String, dynamic> json) => CompanyModel(
    id:            json['id'] as int?,
    companyName:   json['company_name'] as String? ?? '',
    tradeName:     json['trade_name'] as String? ?? '',
    logoUrl:       json['logo_url'] as String?,
    gstin:         json['gstin'] as String? ?? '',
    cin:           json['cin'] as String? ?? '',
    pan:           json['pan'] as String? ?? '',
    tan:           json['tan'] as String? ?? '',
    address:       json['address'] as String? ?? '',
    city:          json['city'] as String? ?? '',
    state:         json['state'] as String? ?? '',
    pinCode:       json['pin_code'] as String? ?? '',
    website:       json['website'] as String? ?? '',
    officialPhone: json['official_phone'] as String? ?? '',
    updatedAt:     json['updated_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'company_name':   companyName,
    'trade_name':     tradeName,
    'gstin':          gstin,
    'cin':            cin,
    'pan':            pan,
    'tan':            tan,
    'address':        address,
    'city':           city,
    'state':          state,
    'pin_code':       pinCode,
    'website':        website,
    'official_phone': officialPhone,
  };

  CompanyModel copyWith({
    int? id,
    String? companyName,
    String? tradeName,
    String? logoUrl,
    String? gstin,
    String? cin,
    String? pan,
    String? tan,
    String? address,
    String? city,
    String? state,
    String? pinCode,
    String? website,
    String? officialPhone,
    String? updatedAt,
  }) => CompanyModel(
    id:            id ?? this.id,
    companyName:   companyName ?? this.companyName,
    tradeName:     tradeName ?? this.tradeName,
    logoUrl:       logoUrl ?? this.logoUrl,
    gstin:         gstin ?? this.gstin,
    cin:           cin ?? this.cin,
    pan:           pan ?? this.pan,
    tan:           tan ?? this.tan,
    address:       address ?? this.address,
    city:          city ?? this.city,
    state:         state ?? this.state,
    pinCode:       pinCode ?? this.pinCode,
    website:       website ?? this.website,
    officialPhone: officialPhone ?? this.officialPhone,
    updatedAt:     updatedAt ?? this.updatedAt,
  );
}

// Indian states list used in the company form dropdown.
const kIndianStates = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
  'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
  'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
  'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
  'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
  'Andaman and Nicobar Islands', 'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu', 'Delhi',
  'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry',
];
