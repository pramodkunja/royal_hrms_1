// Company Contact Matrix — who to contact (and escalate to) for attendance,
// WFH, leave and other HR matters. Production contract
// (apps/accounts/views_policy.py, origin/production):
//   GET    /company-contacts/       every signed-in user; company-wide
//                                   contacts plus the user's own branch's →
//                                   {contacts: [...], can_manage: bool}
//   POST   /company-contacts/       documents.create
//   PATCH  /company-contacts/<id>/  documents.edit
//   DELETE /company-contacts/<id>/  documents.delete (soft delete)
// No search, filter, sort or pagination on the server; web groups the list
// by escalation level (frontend/lib/contactMatrix.ts), as here.

class CompanyContact {
  final int id;
  final String name;
  final String designation;
  final String department;
  final String email;
  final String phone;
  final String purpose;
  final int escalationLevel;
  final int? branch;
  final String branchName;
  final int displayOrder;

  const CompanyContact({
    required this.id,
    required this.name,
    this.designation = '',
    this.department = '',
    this.email = '',
    this.phone = '',
    this.purpose = '',
    this.escalationLevel = 1,
    this.branch,
    this.branchName = '',
    this.displayOrder = 0,
  });

  static int _int(Object? v, int fallback) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;
  static String _str(Object? v) => v == null ? '' : '$v';

  factory CompanyContact.fromJson(Map<String, dynamic> json) => CompanyContact(
        id: _int(json['id'], 0),
        name: _str(json['name']),
        designation: _str(json['designation']),
        department: _str(json['department']),
        email: _str(json['email']),
        phone: _str(json['phone']),
        purpose: _str(json['purpose']),
        escalationLevel: _int(json['escalation_level'], 1),
        branch: json['branch'] == null ? null : _int(json['branch'], 0),
        branchName: _str(json['branch_name']),
        displayOrder: _int(json['display_order'], 0),
      );

  ContactForm toForm() => ContactForm(
        name: name,
        designation: designation,
        department: department,
        email: email,
        phone: phone,
        purpose: purpose,
        escalationLevel: escalationLevel,
        branch: branch,
        displayOrder: displayOrder,
      );
}

/// GET /company-contacts/ — the list plus whether this user may add
/// contacts (the server's `can_manage`, i.e. documents.create).
class ContactMatrix {
  final List<CompanyContact> contacts;
  final bool canManage;

  const ContactMatrix({this.contacts = const [], this.canManage = false});

  factory ContactMatrix.fromJson(Object? data) {
    final map = data is Map ? data : const {};
    final rows = map['contacts'];
    return ContactMatrix(
      contacts: (rows is List ? rows : const [])
          .whereType<Map>()
          .map((e) => CompanyContact.fromJson(e.cast<String, dynamic>()))
          .toList(),
      canManage: map['can_manage'] == true,
    );
  }
}

/// The add/edit form — the same fields web sends (ContactForm in
/// frontend/lib/contactMatrix.ts; CompanyContactSerializer's writable ones).
class ContactForm {
  final String name;
  final String designation;
  final String department;
  final String email;
  final String phone;
  final String purpose;
  final int escalationLevel;
  final int? branch; // null = all branches (company-wide)
  final int displayOrder;

  const ContactForm({
    this.name = '',
    this.designation = '',
    this.department = '',
    this.email = '',
    this.phone = '',
    this.purpose = '',
    this.escalationLevel = 1,
    this.branch,
    this.displayOrder = 0,
  });

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'designation': designation.trim(),
        'department': department.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'purpose': purpose.trim(),
        'escalation_level': escalationLevel,
        'branch': branch,
        'display_order': displayOrder,
      };
}

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Web's contactFormError — checked before sending; the server checks too.
String? contactFormError(ContactForm f) {
  if (f.name.trim().isEmpty) return 'Name is required.';
  if (f.email.trim().isEmpty && f.phone.trim().isEmpty) return 'Enter an email or a phone number.';
  if (f.email.trim().isNotEmpty && !_emailPattern.hasMatch(f.email.trim())) return 'Enter a valid email address.';
  if (f.escalationLevel < 1) return 'Escalation level starts at 1.';
  return null;
}

/// Web's levelLabel.
String contactLevelLabel(int level) => level <= 1 ? 'First point of contact' : 'Escalation level $level';

/// Web's groupByLevel: lowest level first; within a level by display order,
/// then name.
List<({int level, List<CompanyContact> contacts})> groupContactsByLevel(List<CompanyContact> contacts) {
  final byLevel = <int, List<CompanyContact>>{};
  for (final c in contacts) {
    byLevel.putIfAbsent(c.escalationLevel, () => []).add(c);
  }
  final levels = byLevel.keys.toList()..sort();
  return [
    for (final level in levels)
      (
        level: level,
        contacts: [...byLevel[level]!]..sort((a, b) {
            final byOrder = a.displayOrder.compareTo(b.displayOrder);
            return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
          }),
      ),
  ];
}

/// A branch to pick in the form (GET /branch/branches/?page_size=100).
class ContactBranchOption {
  final int id;
  final String name;
  const ContactBranchOption(this.id, this.name);
}
