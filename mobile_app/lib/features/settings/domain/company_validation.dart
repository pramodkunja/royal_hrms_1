import 'dart:io';

import '../data/models/company_model.dart';

// Company Information validation — a port of web
// settings/company/page.tsx `validate()` (same rules, same order, same text),
// plus its logo checks (`handleLogoChange`).

final _gstinRe = RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][A-Z1-9]Z[A-Z\d]$');
final _panRe = RegExp(r'^[A-Z]{5}\d{4}[A-Z]$');
final _cinRe = RegExp(r'^[UL]\d{5}[A-Z]{2}\d{4}[A-Z]{3}\d{6}$');
final _tanRe = RegExp(r'^[A-Z]{4}\d{5}[A-Z]$');
final _pinRe = RegExp(r'^\d{6}$');
final _phoneRe = RegExp(r'^\+?[\d\s\-()./]{7,20}$');

/// Field → message, empty when valid. Required checks use the trimmed value;
/// the format checks test the upper-cased raw value, as web does.
Map<String, String> validateCompany(CompanyModel f) {
  final e = <String, String>{};
  if (f.companyName.trim().isEmpty) e['company_name'] = 'Company name is required.';
  if (f.gstin.trim().isEmpty) {
    e['gstin'] = 'GSTIN is required.';
  } else if (!_gstinRe.hasMatch(f.gstin.toUpperCase())) {
    e['gstin'] = 'Enter a valid 15-character GSTIN.';
  }
  if (f.cin.trim().isEmpty) {
    e['cin'] = 'CIN is required.';
  } else if (!_cinRe.hasMatch(f.cin.toUpperCase())) {
    e['cin'] = 'Enter a valid CIN (e.g. U74999MH2020PTC123456).';
  }
  if (f.pan.trim().isEmpty) {
    e['pan'] = 'PAN is required.';
  } else if (!_panRe.hasMatch(f.pan.toUpperCase())) {
    e['pan'] = 'Enter a valid 10-character PAN.';
  }
  if (f.tan.trim().isEmpty) {
    e['tan'] = 'TAN is required.';
  } else if (!_tanRe.hasMatch(f.tan.toUpperCase())) {
    e['tan'] = 'Enter a valid 10-character TAN.';
  }
  if (f.address.trim().isEmpty) e['address'] = 'Address is required.';
  if (f.city.trim().isEmpty) e['city'] = 'City is required.';
  if (f.state.isEmpty) e['state'] = 'State / UT is required.';
  if (f.pinCode.trim().isEmpty) {
    e['pin_code'] = 'PIN code is required.';
  } else if (!_pinRe.hasMatch(f.pinCode)) {
    e['pin_code'] = 'PIN code must be exactly 6 digits.';
  }
  if (f.website.isNotEmpty && !f.website.startsWith('http://') && !f.website.startsWith('https://')) {
    e['website'] = 'Must start with http:// or https://.';
  }
  if (f.officialPhone.isNotEmpty && !_phoneRe.hasMatch(f.officialPhone)) {
    e['official_phone'] = 'Enter a valid phone number.';
  }
  return e;
}

/// Top-to-bottom order the fields appear in, to find the first with an error.
const kCompanyFieldOrder = [
  'company_name',
  'gstin',
  'cin',
  'pan',
  'tan',
  'address',
  'city',
  'state',
  'pin_code',
  'website',
  'official_phone',
];

const kCompanyLogoExtensions = ['jpg', 'jpeg', 'png', 'webp', 'svg'];
const kCompanyLogoMaxBytes = 5 * 1024 * 1024;

/// Web's logo checks (type first, then size); null when the file is fine.
String? companyLogoError(String path, int bytes) {
  final dot = path.lastIndexOf('.');
  final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  if (!kCompanyLogoExtensions.contains(ext)) return 'Only JPEG, PNG, WebP, or SVG files are allowed.';
  if (bytes > kCompanyLogoMaxBytes) return 'Logo must be under 5 MB.';
  return null;
}

bool isSvgLogo(File f) => f.path.toLowerCase().endsWith('.svg');
