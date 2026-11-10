// Employee ID card — GET /employees/<employee_id>/id-card/
// (apps/accounts/views_id_card.py EmployeeIdCardView → build_id_card), the
// same data web's ID card page renders (frontend/lib/idCard.ts IdCardData).
// Every value is the server's: blank or hidden values arrive as null (never
// placeholders), dates are already formatted, image URLs are absolute, and
// `missing` lists what is not on record.

String? _s(Object? v) {
  if (v is! String) return null;
  return v.trim().isEmpty ? null : v;
}

class IdCardEmployee {
  const IdCardEmployee({
    this.employeeId,
    this.fullName,
    this.designation,
    this.department,
    this.dateOfJoining,
    this.dateOfBirth,
    this.bloodGroup,
    this.location,
    this.photoUrl,
    this.residentialAddress,
    this.phone,
    this.email,
  });

  final String? employeeId;
  final String? fullName;
  final String? designation;
  final String? department;
  final String? dateOfJoining;
  final String? dateOfBirth;
  final String? bloodGroup;
  final String? location;
  final String? photoUrl;
  final String? residentialAddress;
  final String? phone;
  final String? email;

  factory IdCardEmployee.fromJson(Map<String, dynamic> j) => IdCardEmployee(
        employeeId: _s(j['employee_id']),
        fullName: _s(j['full_name']),
        designation: _s(j['designation']),
        department: _s(j['department']),
        dateOfJoining: _s(j['date_of_joining']),
        dateOfBirth: _s(j['date_of_birth']),
        bloodGroup: _s(j['blood_group']),
        location: _s(j['location']),
        photoUrl: _s(j['photo_url']),
        residentialAddress: _s(j['residential_address']),
        phone: _s(j['phone']),
        email: _s(j['email']),
      );
}

class IdCardCompany {
  const IdCardCompany({this.name, this.logoUrl, this.website, this.websiteUrl, this.officeAddress});

  final String? name;
  final String? logoUrl;
  final String? website;
  final String? websiteUrl;
  final String? officeAddress;

  factory IdCardCompany.fromJson(Map<String, dynamic> j) => IdCardCompany(
        name: _s(j['name']),
        logoUrl: _s(j['logo_url']),
        website: _s(j['website']),
        websiteUrl: _s(j['website_url']),
        officeAddress: _s(j['office_address']),
      );
}

class IdCardConfig {
  const IdCardConfig({
    this.terms = const [],
    this.signatureUrl,
    this.signatoryLabel = '',
    this.showDateOfBirth = false,
    this.showResidentialAddress = false,
    this.showContactDetails = false,
  });

  final List<String> terms;
  final String? signatureUrl;
  final String signatoryLabel;
  final bool showDateOfBirth;
  final bool showResidentialAddress;
  final bool showContactDetails;

  factory IdCardConfig.fromJson(Map<String, dynamic> j) => IdCardConfig(
        terms: [
          for (final t in (j['terms'] as List? ?? const []))
            if (t is String && t.trim().isNotEmpty) t,
        ],
        signatureUrl: _s(j['signature_url']),
        signatoryLabel: j['signatory_label'] as String? ?? '',
        showDateOfBirth: j['show_date_of_birth'] == true,
        showResidentialAddress: j['show_residential_address'] == true,
        showContactDetails: j['show_contact_details'] == true,
      );
}

class IdCardData {
  const IdCardData({required this.employee, required this.company, required this.card, this.missing = const []});

  final IdCardEmployee employee;
  final IdCardCompany company;
  final IdCardConfig card;

  /// Labels of details not on record ("Employee photo", "Blood group", …).
  final List<String> missing;

  factory IdCardData.fromJson(Map<String, dynamic> j) => IdCardData(
        employee: IdCardEmployee.fromJson((j['employee'] as Map?)?.cast<String, dynamic>() ?? const {}),
        company: IdCardCompany.fromJson((j['company'] as Map?)?.cast<String, dynamic>() ?? const {}),
        card: IdCardConfig.fromJson((j['card'] as Map?)?.cast<String, dynamic>() ?? const {}),
        missing: [
          for (final m in (j['missing'] as List? ?? const []))
            if (m is String) m
        ],
      );

  /// Web page subtitle: "<full name> · <employee code>".
  String get subtitle {
    final name = employee.fullName ?? '';
    return employee.employeeId == null ? name : '$name · ${employee.employeeId}';
  }
}

/// The icons the card uses (web: Tabler icons in navy circles).
enum IdCardIcon { code, dob, doj, department, blood, location, residential, office, contact, website, person }

class IdCardRow {
  const IdCardRow(this.key, this.icon, this.label, this.value);
  final String key;
  final IdCardIcon icon;
  final String label;
  final String value;

  String get text => '$label: $value';
}

/// Web frontRows: the front detail rows in the reference order; rows with no
/// value on record are left off entirely — never printed blank or guessed.
List<IdCardRow> idCardFrontRows(IdCardEmployee e) => [
      for (final (key, icon, label, value) in [
        ('code', IdCardIcon.code, 'Emp Code', e.employeeId),
        ('dob', IdCardIcon.dob, 'DOB', e.dateOfBirth),
        ('doj', IdCardIcon.doj, 'DOJ', e.dateOfJoining),
        ('dept', IdCardIcon.department, 'Department', e.department),
        ('blood', IdCardIcon.blood, 'Blood Group', e.bloodGroup),
        ('loc', IdCardIcon.location, 'Location', e.location),
      ])
        if (value != null && value.trim().isNotEmpty) IdCardRow(key, icon, label, value),
    ];

class IdCardSection {
  const IdCardSection(this.key, this.icon, this.title, this.lines, {this.singleLine = false});
  final String key;
  final IdCardIcon icon;
  final String title;
  final List<String> lines;

  /// Contact lines are clamped to one line each (web `.idc-sec-text.one`).
  final bool singleLine;
}

/// Web IdCardBack sections, in order, each only when there is something to show.
List<IdCardSection> idCardBackSections(IdCardData d) {
  final contact = [d.employee.phone, d.employee.email].whereType<String>().toList();
  return [
    if (d.employee.residentialAddress != null)
      IdCardSection('res', IdCardIcon.residential, 'Residential Address', [d.employee.residentialAddress!]),
    if (d.company.officeAddress != null)
      IdCardSection('off', IdCardIcon.office, 'Office Address', [d.company.officeAddress!]),
    if (contact.isNotEmpty) IdCardSection('con', IdCardIcon.contact, 'Contact Details', contact, singleLine: true),
  ];
}

/// Web PrintLayout.
enum IdCardPrintLayout {
  card('Card size (50 × 85 mm)', 'One side per page, for card printers or pre-cut card stock.'),
  a4('A4 sheet', 'Front and back side by side at actual size, with cut guides.');

  const IdCardPrintLayout(this.label, this.hint);
  final String label;
  final String hint;
}
