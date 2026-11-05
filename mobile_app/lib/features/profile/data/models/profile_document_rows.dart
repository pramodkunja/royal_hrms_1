import '../../../settings/data/models/onboarding_field_config_model.dart';
import 'profile_document_model.dart';

// The rows of My Profile → Documents, as on web (ProfileClient.tsx
// buildDocEntries + employees/_data.ts applyDocumentTypeConfig):
//  - one row per *visible* configured document type, in the admin's order,
//    shown whether or not a file has been uploaded;
//  - web's built-in list when no type configuration is available;
//  - for a single-file type, the newest upload (the backend keeps only one);
//    for an `allow_multiple` type, every upload, newest first.
// Unlike web, an uploaded file whose type is no longer offered (hidden or
// removed by the admin) is still listed, read-only, so nothing the employee
// could see before disappears from the app. The backend would refuse a new
// upload for such a type, so none is offered.

/// Web's fallback list (employees/_data.ts PROFILE_SECTIONS → documents).
const kDefaultProfileDocumentTypes = <(String, String, bool)>[
  ('pan_card', 'PAN Card', true),
  ('aadhaar_card', 'Aadhaar Card', true),
  ('degree_certificate', 'Degree Certificate', false),
  ('experience_letter', 'Experience Letter', false),
  ('passport_photo', 'Passport Photo', true),
  ('cancelled_cheque', 'Cancelled Cheque', true),
];

class ProfileDocumentRow {
  final String documentType;
  final String label;
  final bool required;
  final bool allowMultiple;

  /// Offered for upload: a type the employee can upload to right now.
  final bool canUpload;

  /// Newest first. At most one for a single-file type.
  final List<ProfileDocumentModel> files;

  const ProfileDocumentRow({
    required this.documentType,
    required this.label,
    required this.required,
    required this.allowMultiple,
    required this.canUpload,
    required this.files,
  });

  bool get uploaded => files.isNotEmpty;

  /// The file a single-file row shows (the newest), or null.
  ProfileDocumentModel? get latest => files.isEmpty ? null : files.first;

  /// Uploading again replaces the current file on the server, so ask first.
  /// An `allow_multiple` upload adds a file instead and needs no confirmation.
  bool get replaceNeedsConfirmation => uploaded && !allowMultiple;
}

class ProfileDocumentListing {
  final List<ProfileDocumentRow> rows;

  /// True when the type configuration couldn't be used and web's built-in
  /// list is shown instead.
  final bool usingDefaultTypes;

  const ProfileDocumentListing({required this.rows, required this.usingDefaultTypes});
}

DateTime? _uploadedAt(ProfileDocumentModel d) => DateTime.tryParse(d.uploadedAt);

/// Newest first; undated files keep their server order after dated ones.
List<ProfileDocumentModel> _newestFirst(List<ProfileDocumentModel> docs) {
  final indexed = docs.indexed.toList();
  indexed.sort((a, b) {
    final da = _uploadedAt(a.$2), db = _uploadedAt(b.$2);
    if (da != null && db != null && da != db) return db.compareTo(da);
    if (da == null && db != null) return 1;
    if (da != null && db == null) return -1;
    return a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

ProfileDocumentListing buildProfileDocumentListing(
  List<DocumentTypeConfigModel> types,
  List<ProfileDocumentModel> docs,
) {
  final configured = types.where((t) => t.visible && t.typeKey.isNotEmpty).toList().indexed.toList()
    ..sort((a, b) => a.$2.order != b.$2.order ? a.$2.order.compareTo(b.$2.order) : a.$1.compareTo(b.$1));
  final usingDefaults = configured.isEmpty;

  final byType = <String, List<ProfileDocumentModel>>{};
  for (final d in docs) {
    byType.putIfAbsent(d.documentType, () => []).add(d);
  }
  List<ProfileDocumentModel> filesFor(String type, bool allowMultiple) {
    final files = _newestFirst(byType[type] ?? const []);
    return allowMultiple || files.isEmpty ? files : [files.first];
  }

  final rows = <ProfileDocumentRow>[];
  final seen = <String>{};
  if (usingDefaults) {
    for (final (key, label, required) in kDefaultProfileDocumentTypes) {
      seen.add(key);
      rows.add(ProfileDocumentRow(
        documentType: key,
        label: label,
        required: required,
        allowMultiple: false,
        canUpload: true,
        files: filesFor(key, false),
      ));
    }
  } else {
    for (final (_, t) in configured) {
      if (!seen.add(t.typeKey)) continue;
      rows.add(ProfileDocumentRow(
        documentType: t.typeKey,
        label: t.label.trim().isNotEmpty ? t.label : t.typeKey,
        required: t.required,
        allowMultiple: t.allowMultiple,
        canUpload: true,
        files: filesFor(t.typeKey, t.allowMultiple),
      ));
    }
  }

  // Uploaded files of a type that isn't offered any more: listed, read-only.
  for (final entry in byType.entries) {
    if (seen.contains(entry.key)) continue;
    final files = _newestFirst(entry.value);
    final display = files.first.documentTypeDisplay.trim();
    rows.add(ProfileDocumentRow(
      documentType: entry.key,
      label: display.isNotEmpty ? display : entry.key,
      required: false,
      allowMultiple: true,
      canUpload: false,
      files: files,
    ));
  }

  return ProfileDocumentListing(rows: rows, usingDefaultTypes: usingDefaults);
}
