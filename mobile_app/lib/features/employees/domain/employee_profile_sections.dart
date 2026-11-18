import '../../settings/data/models/onboarding_field_config_model.dart';
import '../data/models/employee_model.dart';

/// The Education & Experience, Bank Details and Emergency Contact sections of
/// the HR Employee Profile, exactly as web employees/_data.ts PROFILE_SECTIONS
/// defines them (each is a single "grid" record — web has no add/remove rows
/// for any of them, and one emergency contact). Saved through
/// PUT /employees/<code>/ (EmployeeDetailView → EmployeeProfileSerializer,
/// partial): only the keys sent change. Web sends every section at once; this
/// sends one section's keys, so the other sections are never touched.
///
/// EPF / Statutory (web "epf": uan_number, name_as_per_aadhar, esi_number)
/// follows the same path, with two differences forced by production: the
/// employee detail never returns these keys (so the form can't show what is
/// stored), and web's every-field save would therefore blank them. Only the
/// statutory fields actually changed are sent (agreed for Task 43), so a
/// value nobody retyped is never wiped. Web has no Onboarding Fields step for
/// this section: no visibility config, no custom fields.
enum EmployeeProfileSection { education, bank, emergency, statutory }

enum ProfileFieldKind { text, textarea, select, phone, email }

class ProfileFieldOption {
  const ProfileFieldOption(this.value, this.label);
  final String value;
  final String label;
}

class ProfileFieldDef {
  const ProfileFieldDef({
    required this.key,
    required this.label,
    this.kind = ProfileFieldKind.text,
    this.required = false,
    this.placeholder,
    this.options = const [],
    this.full = false,
  });

  /// The backend (EmployeeProfile) column name, as sent in the PUT.
  final String key;
  final String label;
  final ProfileFieldKind kind;

  /// Web shows an asterisk only — its Save does no client-side required
  /// check; the server's validators decide.
  final bool required;
  final String? placeholder;
  final List<ProfileFieldOption> options;
  final bool full;
}

/// Web `opt(...)` — value and label identical.
List<ProfileFieldOption> _opt(List<String> values) => [for (final v in values) ProfileFieldOption(v, v)];

const _accountTypes = [ProfileFieldOption('savings', 'Savings'), ProfileFieldOption('current', 'Current')];

/// [step] is web SECTION_TO_STEP (Settings → Onboarding Fields); null for a
/// section web doesn't map (EPF / Statutory).
final Map<EmployeeProfileSection, ({String title, int? step, List<ProfileFieldDef> fields})> kEmployeeProfileSections =
    {
  EmployeeProfileSection.education: (
    title: 'Education & Experience',
    step: 1,
    fields: const [
      ProfileFieldDef(key: 'highest_qualification', label: 'Highest Qualification', placeholder: 'e.g. B.Tech, MBA'),
      ProfileFieldDef(key: 'specialization', label: 'Specialization', placeholder: 'e.g. Computer Science'),
      ProfileFieldDef(
          key: 'institution', label: 'Institution / University', placeholder: 'College or university name', full: true),
      ProfileFieldDef(key: 'year_of_passing', label: 'Year of Passing', placeholder: 'e.g. 2020'),
      ProfileFieldDef(key: 'total_experience_years', label: 'Total Experience (yrs)', placeholder: 'e.g. 3.5'),
      ProfileFieldDef(key: 'previous_employer', label: 'Previous Employer', placeholder: 'Company name (if any)'),
      ProfileFieldDef(key: 'previous_designation', label: 'Previous Designation', placeholder: 'Job title (if any)'),
      ProfileFieldDef(
          key: 'leaving_reason',
          label: 'Reason for Leaving',
          kind: ProfileFieldKind.textarea,
          placeholder: 'Optional',
          full: true),
    ],
  ),
  EmployeeProfileSection.bank: (
    title: 'Bank Details',
    step: 2,
    fields: const [
      ProfileFieldDef(
          key: 'account_holder_name',
          label: 'Account Holder Name',
          required: true,
          placeholder: 'As printed on passbook'),
      ProfileFieldDef(
          key: 'account_type',
          label: 'Account Type',
          kind: ProfileFieldKind.select,
          required: true,
          options: _accountTypes),
      ProfileFieldDef(
          key: 'account_number', label: 'Account Number', required: true, placeholder: 'Bank account number'),
      ProfileFieldDef(key: 'ifsc_code', label: 'IFSC Code', required: true, placeholder: 'e.g. SBIN0001234'),
      ProfileFieldDef(key: 'bank_name', label: 'Bank Name', required: true, placeholder: 'e.g. State Bank of India'),
      ProfileFieldDef(key: 'bank_branch_name', label: 'Bank Branch', placeholder: 'Branch city / locality'),
    ],
  ),
  EmployeeProfileSection.emergency: (
    title: 'Emergency Contact',
    step: 3,
    fields: [
      const ProfileFieldDef(key: 'emergency_name', label: 'Contact Name', required: true, placeholder: 'Full name'),
      ProfileFieldDef(
          key: 'emergency_relationship',
          label: 'Relationship',
          kind: ProfileFieldKind.select,
          required: true,
          options: _opt(const ['Father', 'Mother', 'Spouse', 'Sibling', 'Friend', 'Other'])),
      const ProfileFieldDef(
          key: 'emergency_phone',
          label: 'Phone Number',
          kind: ProfileFieldKind.phone,
          required: true,
          placeholder: '+91 XXXXX XXXXX'),
      const ProfileFieldDef(
          key: 'emergency_email', label: 'Email', kind: ProfileFieldKind.email, placeholder: 'optional@email.com'),
    ],
  ),
  // Web employees/_data.ts "epf": labels and placeholders as web. Web does no
  // client-side check and the PUT validates none (EmployeeProfileSerializer:
  // plain strings, max 255) — the placeholders' digit counts are hints only.
  EmployeeProfileSection.statutory: (
    title: 'EPF / Statutory',
    step: null,
    fields: const [
      ProfileFieldDef(key: 'uan_number', label: 'UAN Number', placeholder: '12-digit Universal Account Number'),
      ProfileFieldDef(
          key: 'name_as_per_aadhar', label: 'Name as per Aadhar', placeholder: 'Exactly as printed on Aadhaar card'),
      ProfileFieldDef(key: 'esi_number', label: 'ESI Number', placeholder: '10-digit ESI Insurance Number (IP Number)'),
    ],
  ),
};

/// The employee's current value for each field of [section], as web
/// apiToEmployee maps them ('' when absent).
Map<String, String> profileSectionValues(EmployeeProfileSection section, EmployeeModel e) => switch (section) {
      EmployeeProfileSection.education => {
          'highest_qualification': e.highestQualification,
          'specialization': e.specialization,
          'institution': e.institution,
          'year_of_passing': e.yearOfPassing,
          'total_experience_years': e.totalExperienceYears,
          'previous_employer': e.previousEmployer,
          'previous_designation': e.previousDesignation,
          'leaving_reason': e.leavingReason,
        },
      EmployeeProfileSection.bank => {
          'account_holder_name': e.accountHolderName,
          'account_type': e.accountType,
          'account_number': e.accountNumber,
          'ifsc_code': e.ifscCode,
          'bank_name': e.bankName,
          'bank_branch_name': e.bankBranch,
        },
      EmployeeProfileSection.emergency => {
          'emergency_name': e.emergencyName,
          'emergency_relationship': e.emergencyRelationship,
          'emergency_phone': e.emergencyPhone,
          'emergency_email': e.emergencyEmail,
        },
      EmployeeProfileSection.statutory => {
          'uan_number': e.uanNumber,
          'name_as_per_aadhar': e.nameAsPerAadhar,
          'esi_number': e.esiNumber,
        },
    };

/// Web onSave's encoding for these keys: blank → "" (the columns are
/// blank=True, not null=True, so the serializer rejects null), except
/// year_of_passing / total_experience_years (nullable columns) → null.
/// Values are sent as typed — the server's validators trim and check them.
///
/// EPF / Statutory sends only the keys whose value differs from [initial]
/// (what the form opened with): a blank field nobody touched is not sent, so
/// a stored value the server never showed is not erased. A value changed to
/// blank is sent as "" (clears it), as web.
Map<String, dynamic> profileSectionPayload(EmployeeProfileSection section, Map<String, String> values,
    {Map<String, String> initial = const {}}) {
  const nullable = {'year_of_passing', 'total_experience_years'};
  final changedOnly = section == EmployeeProfileSection.statutory;
  return {
    for (final f in kEmployeeProfileSections[section]!.fields)
      if (!changedOnly || (values[f.key] ?? '') != (initial[f.key] ?? ''))
        f.key: (values[f.key] ?? '').isEmpty ? (nullable.contains(f.key) ? null : '') : values[f.key],
  };
}

/// Web applyFieldConfig: a built-in field is shown unless its Settings →
/// Onboarding Fields entry for this section's step says visible=false; no
/// config (not loaded / no entry) shows everything.
bool isProfileFieldVisible(
    EmployeeProfileSection section, String key, Map<int, List<OnboardingFieldConfigModel>>? config) {
  final step = kEmployeeProfileSections[section]!.step;
  if (step == null) return true;
  final entry = (config?[step] ?? const <OnboardingFieldConfigModel>[]).where((c) => c.fieldKey == key).firstOrNull;
  return entry?.visible ?? true;
}

/// Web CAMEL_TO_SNAKE for the Personal section (onboarding step 0): the only
/// built-in Personal fields Settings → Onboarding Fields can hide. Identity
/// and employment fields (ID, name, login email, phone, joining date,
/// department, designation, role, branch, approvers, notice period) always
/// show.
const kPersonalConfigurableFields = {
  'date_of_birth', 'gender', 'marital_status', 'father_name', 'blood_group', //
  'current_address', 'permanent_address',
};

/// Web applyFieldConfig for step 0 (the Personal section).
bool isPersonalFieldVisible(String key, Map<int, List<OnboardingFieldConfigModel>>? config) {
  if (!kPersonalConfigurableFields.contains(key)) return true;
  final entry = (config?[0] ?? const <OnboardingFieldConfigModel>[]).where((c) => c.fieldKey == key).firstOrNull;
  return entry?.visible ?? true;
}

/// The label shown for a select value (e.g. "savings" → "Savings"); a value
/// that isn't one of the options (older/imported data) is shown as stored.
String profileFieldDisplay(ProfileFieldDef f, String value) {
  if (value.isEmpty) return '—';
  if (f.kind != ProfileFieldKind.select) return value;
  return f.options.where((o) => o.value == value).firstOrNull?.label ?? value;
}

// ── Documents slots (web employees/_data.ts:233-245, applyDocumentTypeConfig
// :280-288, [id]/page.tsx buildDocEntries:81-105) ───────────────────────────

/// One expected document type on the profile, with the employee's upload
/// for it (web: the first upload of that type), if any.
class EmployeeDocSlot {
  const EmployeeDocSlot({required this.typeKey, required this.label, required this.required, this.doc});
  final String typeKey;
  final String label;
  final bool required;
  final EmployeeDocumentEntity? doc;
}

/// Web's built-in list, used until / unless the type config loads.
const kBuiltInEmployeeDocSlots = [
  (typeKey: 'pan_card', label: 'PAN Card', required: true),
  (typeKey: 'aadhaar_card', label: 'Aadhaar Card', required: true),
  (typeKey: 'degree_certificate', label: 'Degree Certificate', required: false),
  (typeKey: 'experience_letter', label: 'Experience Letter', required: false),
  (typeKey: 'passport_photo', label: 'Passport Photo', required: true),
  (typeKey: 'cancelled_cheque', label: 'Cancelled Cheque', required: true),
];

/// The configured visible types in `order` (or the built-in list when the
/// config is empty), each merged with the employee's first upload of it.
List<EmployeeDocSlot> buildEmployeeDocSlots(List<DocumentTypeConfigModel> config, List<EmployeeDocumentEntity> docs) {
  final types = config.isEmpty
      ? kBuiltInEmployeeDocSlots
      : ([...config.where((t) => t.visible)]..sort((a, b) => a.order.compareTo(b.order)))
          .map((t) => (typeKey: t.typeKey, label: t.label, required: t.required))
          .toList();
  return [
    for (final t in types)
      EmployeeDocSlot(
        typeKey: t.typeKey,
        label: t.label,
        required: t.required,
        doc: docs.where((d) => d.documentType == t.typeKey).firstOrNull,
      ),
  ];
}

/// Uploads no slot shows (a type since hidden / removed, or a second file
/// of a type). Web leaves them out; mobile still lists them so they stay
/// reachable (deliberate difference).
List<EmployeeDocumentEntity> unslottedEmployeeDocs(List<EmployeeDocSlot> slots, List<EmployeeDocumentEntity> docs) {
  final shown = {
    for (final s in slots)
      if (s.doc != null) s.doc!.id
  };
  return docs.where((d) => !shown.contains(d.id)).toList();
}

/// Web fmtBytes.
String webFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Web toLocaleDateString("en-US", {month: "short", day: "numeric", year:
/// "numeric"}): "Nov 18, 2026". Unparseable → as stored.
String webShortDate(String raw) {
  final d = DateTime.tryParse(raw)?.toLocal();
  if (d == null) return raw;
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[d.month - 1]} ${d.day}, ${d.year}';
}
