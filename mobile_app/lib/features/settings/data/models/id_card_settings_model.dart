import '../../../employees/data/models/employee_id_card_model.dart';
import 'company_model.dart';

// Settings → ID Card — GET/PUT /settings/id-card/ (backend
// apps/accounts/views_id_card.py IdCardSettingsView + IdCardSettingsSerializer),
// as web's app/dashboard/settings/id-card/page.tsx uses it. The helpers below
// mirror web lib/idCard.ts (sampleCardData, termsFromText, formatBytes).

/// Web EMPTY_FORM / backend IdCardSettings.DEFAULT_SIGNATORY_LABEL.
const kIdCardDefaultSignatoryLabel = 'Authorised Signatory';

/// Web `<input maxLength={60}>` (model max_length=60).
const kIdCardSignatoryMaxLength = 60;

/// Web pickPdf / backend MAX_REFERENCE_PDF_BYTES.
const kIdCardReferencePdfMaxBytes = 10 * 1024 * 1024;

/// Web pickSignature / backend MAX_SIGNATURE_BYTES.
const kIdCardSignatureMaxBytes = 2 * 1024 * 1024;

String _str(Object? v, [String fallback = '']) => v is String ? v : fallback;
String? _optStr(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

/// A boolean as the server sends it; anything unexpected falls back to
/// [fallback] (web's form default), never to a guess.
bool _bool(Object? v, bool fallback) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (const ['true', '1', 'yes'].contains(s)) return true;
    if (const ['false', '0', 'no'].contains(s)) return false;
  }
  return fallback;
}

int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : (v is String ? int.tryParse(v) : null));

/// Web interface IdCardSettings (the serializer's fields). Unknown extra keys
/// are ignored.
class IdCardSettingsModel {
  const IdCardSettingsModel({
    this.signatoryLabel = kIdCardDefaultSignatoryLabel,
    this.terms = '',
    this.defaultTerms = '',
    this.showDateOfBirth = true,
    this.showResidentialAddress = true,
    this.showContactDetails = true,
    this.referencePdfName = '',
    this.referencePdfSize,
    this.referencePdfUrl,
    this.signatureUrl,
    this.updatedAt,
    this.updatedByName,
  });

  final String signatoryLabel;
  final String terms;

  /// The built-in conditions (newline-separated), used when [terms] is blank.
  final String defaultTerms;
  final bool showDateOfBirth;
  final bool showResidentialAddress;
  final bool showContactDetails;
  final String referencePdfName;
  final int? referencePdfSize;

  /// Set when a reference PDF is stored (the API path that streams it).
  final String? referencePdfUrl;

  /// Short-lived signed URL of the stored signature image.
  final String? signatureUrl;
  final String? updatedAt;
  final String? updatedByName;

  bool get hasReferencePdf => referencePdfName.isNotEmpty;

  factory IdCardSettingsModel.fromJson(Map<String, dynamic> j) => IdCardSettingsModel(
        signatoryLabel: _str(j['signatory_label'], kIdCardDefaultSignatoryLabel),
        terms: _str(j['terms']),
        defaultTerms: _str(j['default_terms']),
        showDateOfBirth: _bool(j['show_date_of_birth'], true),
        showResidentialAddress: _bool(j['show_residential_address'], true),
        showContactDetails: _bool(j['show_contact_details'], true),
        referencePdfName: _str(j['reference_pdf_name']),
        referencePdfSize: _int(j['reference_pdf_size']),
        referencePdfUrl: _optStr(j['reference_pdf_url']),
        signatureUrl: _optStr(j['signature_url']),
        updatedAt: _optStr(j['updated_at']),
        updatedByName: _optStr(j['updated_by_name']),
      );

  IdCardSettingsForm toForm() => IdCardSettingsForm(
        signatoryLabel: signatoryLabel,
        terms: terms,
        showDateOfBirth: showDateOfBirth,
        showResidentialAddress: showResidentialAddress,
        showContactDetails: showContactDetails,
      );
}

/// Web FormState: the editable text/toggle fields (files are separate).
class IdCardSettingsForm {
  const IdCardSettingsForm({
    this.signatoryLabel = kIdCardDefaultSignatoryLabel,
    this.terms = '',
    this.showDateOfBirth = true,
    this.showResidentialAddress = true,
    this.showContactDetails = true,
  });

  final String signatoryLabel;
  final String terms;
  final bool showDateOfBirth;
  final bool showResidentialAddress;
  final bool showContactDetails;

  IdCardSettingsForm copyWith({
    String? signatoryLabel,
    String? terms,
    bool? showDateOfBirth,
    bool? showResidentialAddress,
    bool? showContactDetails,
  }) =>
      IdCardSettingsForm(
        signatoryLabel: signatoryLabel ?? this.signatoryLabel,
        terms: terms ?? this.terms,
        showDateOfBirth: showDateOfBirth ?? this.showDateOfBirth,
        showResidentialAddress: showResidentialAddress ?? this.showResidentialAddress,
        showContactDetails: showContactDetails ?? this.showContactDetails,
      );

  /// Web onSave's FormData text fields, in its order: the caption trimmed,
  /// terms as typed, toggles as "true"/"false".
  Map<String, String> toFields() => {
        'signatory_label': signatoryLabel.trim(),
        'terms': terms,
        'show_date_of_birth': '$showDateOfBirth',
        'show_residential_address': '$showResidentialAddress',
        'show_contact_details': '$showContactDetails',
      };

  @override
  bool operator ==(Object other) =>
      other is IdCardSettingsForm &&
      other.signatoryLabel == signatoryLabel &&
      other.terms == terms &&
      other.showDateOfBirth == showDateOfBirth &&
      other.showResidentialAddress == showResidentialAddress &&
      other.showContactDetails == showContactDetails;

  @override
  int get hashCode => Object.hash(signatoryLabel, terms, showDateOfBirth, showResidentialAddress, showContactDetails);
}

/// A file chosen on the device for upload.
class IdCardPickedFile {
  const IdCardPickedFile({required this.path, required this.name, required this.size});
  final String path;
  final String name;
  final int size;
}

/// Web pickPdf: an error message, or null when the file may be used.
String? validateIdCardReferencePdf(IdCardPickedFile f) {
  if (!f.name.toLowerCase().endsWith('.pdf')) return 'The reference file must be a PDF.';
  if (f.size > kIdCardReferencePdfMaxBytes) return 'The reference PDF must be under 10 MB.';
  return null;
}

/// Web pickSignature (browser file type image/png, image/jpeg or image/webp —
/// derived from the extension, as on mobile): an error message, or null.
String? validateIdCardSignature(IdCardPickedFile f) {
  final name = f.name.toLowerCase();
  const ok = ['.png', '.jpg', '.jpeg', '.jfif', '.pjpeg', '.pjp', '.webp'];
  if (!ok.any(name.endsWith)) return 'The signature must be a PNG, JPEG, or WebP image.';
  if (f.size > kIdCardSignatureMaxBytes) return 'The signature image must be under 2 MB.';
  return null;
}

/// Web lib/idCard.ts termsFromText.
List<String> idCardTermsFromText(String text, String defaults, String? companyName) {
  final source = text.trim().isNotEmpty ? text : defaults;
  final name = (companyName == null || companyName.isEmpty) ? 'the company' : companyName;
  return [
    for (final l in source.split('\n'))
      if (l.trim().isNotEmpty) l.trim().replaceAll('{company}', name),
  ];
}

/// Web lib/idCard.ts formatBytes.
String formatIdCardBytes(int? bytes) {
  if (bytes == null || bytes == 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Web: trade name, else legal name, else none.
String? idCardCompanyName(CompanyModel? c) {
  if (c == null) return null;
  if (c.tradeName.isNotEmpty) return c.tradeName;
  if (c.companyName.isNotEmpty) return c.companyName;
  return null;
}

/// Web's preview `website`: the scheme and a trailing slash dropped.
String? idCardDisplayWebsite(String? website) {
  final v = (website ?? '').replaceFirst(RegExp(r'^https?://', caseSensitive: false), '').replaceFirst(RegExp(r'/$'), '');
  return v.isEmpty ? null : v;
}

/// Web previewData: lib/idCard.ts sampleCardData — bracketed placeholders,
/// clearly not a real person — with the company's branding and the form's
/// current (unsaved) settings.
IdCardData idCardSettingsSample({
  required CompanyModel? company,
  required IdCardSettingsForm form,
  required String defaultTerms,
  required String? signatureUrl,
}) {
  final name = idCardCompanyName(company);
  final website = company?.website ?? '';
  return IdCardData(
    employee: IdCardEmployee(
      employeeId: '[Emp Code]',
      fullName: '[Employee Name]',
      designation: '[Designation]',
      department: '[Department]',
      dateOfJoining: 'DD/MM/YYYY',
      dateOfBirth: form.showDateOfBirth ? 'DD/MM/YYYY' : null,
      bloodGroup: '[Blood Group]',
      location: '[Location]',
      residentialAddress: form.showResidentialAddress ? '[Residential address]' : null,
      phone: form.showContactDetails ? '[Phone]' : null,
      email: form.showContactDetails ? '[Email]' : null,
    ),
    company: IdCardCompany(
      name: name,
      logoUrl: (company?.logoUrl?.isNotEmpty ?? false) ? company!.logoUrl : null,
      website: idCardDisplayWebsite(website),
      websiteUrl: website.isEmpty ? null : website,
      officeAddress: '[Branch office address]',
    ),
    card: IdCardConfig(
      terms: idCardTermsFromText(form.terms, defaultTerms, name),
      signatureUrl: signatureUrl,
      signatoryLabel: form.signatoryLabel.trim().isEmpty ? kIdCardDefaultSignatoryLabel : form.signatoryLabel.trim(),
      showDateOfBirth: form.showDateOfBirth,
      showResidentialAddress: form.showResidentialAddress,
      showContactDetails: form.showContactDetails,
    ),
  );
}
