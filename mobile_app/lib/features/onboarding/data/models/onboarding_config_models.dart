import '../../../settings/data/models/onboarding_field_config_model.dart';

// Admin-configured onboarding (Settings → Onboarding Fields on web), as the
// production backend serves it to the employee:
//  - GET /onboarding/field-config/          {"0": [field…], "1": …, "3": […]}
//    every field, visible and hidden, grouped by step and sorted by order
//    (OnboardingFieldConfigPublicView / OnboardingFieldConfigSerializer);
//  - GET /onboarding/document-type-config/  [type…] sorted by order
//    (DocumentTypeConfigPublicView / DocumentTypeConfigSerializer);
//  - GET/POST/DELETE /onboarding/custom-file-fields/ — files for custom
//    fields of type "file" (CustomFieldFileValueView).
// The field and document-type rows reuse the settings models, which match
// those serializers exactly.

/// The configuration for the wizard. Callers only ever see visible rows,
/// in configured order (web filters `visible` client-side the same way).
class OnboardingConfig {
  final Map<int, List<OnboardingFieldConfigModel>> fieldsByStep;
  final List<DocumentTypeConfigModel> documentTypes;

  const OnboardingConfig({this.fieldsByStep = const {}, this.documentTypes = const []});

  List<OnboardingFieldConfigModel> fieldsFor(int step) =>
      [...(fieldsByStep[step] ?? const <OnboardingFieldConfigModel>[])].where((f) => f.visible).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  List<DocumentTypeConfigModel> get visibleDocumentTypes =>
      documentTypes.where((t) => t.visible).toList()..sort((a, b) => a.order.compareTo(b.order));

  static Map<int, List<OnboardingFieldConfigModel>> parseFields(Object? data) {
    final out = <int, List<OnboardingFieldConfigModel>>{};
    if (data is! Map) return out;
    data.forEach((key, rows) {
      final step = int.tryParse('$key');
      if (step == null || rows is! List) return;
      out[step] = rows.whereType<Map<String, dynamic>>().map(OnboardingFieldConfigModel.fromJson).toList();
    });
    return out;
  }

  static List<DocumentTypeConfigModel> parseDocumentTypes(Object? data) =>
      (data is List ? data : const []).whereType<Map<String, dynamic>>().map(DocumentTypeConfigModel.fromJson).toList();
}

/// One uploaded file for a custom file field (CustomFieldFileValueSerializer).
class CustomFileValue {
  final int id;
  final String fieldKey;
  final String fileName;
  final int fileSize;
  final String? fileUrl;
  final String? uploadedAt;

  const CustomFileValue({
    required this.id,
    required this.fieldKey,
    required this.fileName,
    this.fileSize = 0,
    this.fileUrl,
    this.uploadedAt,
  });

  factory CustomFileValue.fromJson(Map<String, dynamic> json) => CustomFileValue(
        id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
        fieldKey: '${json['field_key'] ?? ''}',
        fileName: '${json['file_name'] ?? ''}',
        fileSize: json['file_size'] is num ? (json['file_size'] as num).toInt() : 0,
        fileUrl: json['file_url'] as String?,
        uploadedAt: json['uploaded_at'] as String?,
      );
}

// ── Upload rules (EmployeeDocument.ALLOWED_MIME_TYPES / MAX_FILE_SIZE) ──────
// Onboarding documents and custom file fields share them: PDF, JPG or PNG,
// at most 5 MB. The server checks the part's content type, so it is sent
// explicitly from this allowlist.

const kOnboardingUploadMaxBytes = 5 * 1024 * 1024;
const kOnboardingUploadExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
const _mimeByExtension = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
};

/// The content type to send for [fileName], or null when not allowed.
String? onboardingUploadMime(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return null;
  return _mimeByExtension[fileName.substring(dot + 1).toLowerCase()];
}

/// The backend's own messages, checked before uploading; null when fine.
String? onboardingUploadError(String fileName, int sizeBytes) {
  if (sizeBytes <= 0) return 'Uploaded file is empty.';
  if (onboardingUploadMime(fileName) == null) return 'Only PDF, JPG, and PNG files are allowed.';
  if (sizeBytes > kOnboardingUploadMaxBytes) {
    return 'File size ${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB exceeds the 5 MB limit.';
  }
  return null;
}
