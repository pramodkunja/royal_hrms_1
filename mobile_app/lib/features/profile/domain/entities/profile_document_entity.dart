/// A single row returned by `GET /onboarding/documents/`
/// (`EmployeeDocumentView` + `EmployeeDocumentSerializer`). `file` is
/// write_only on the backend — reads always use [fileUrl].
class ProfileDocumentEntity {
  final int id;
  final String documentType;
  final String documentTypeDisplay;
  final String fileUrl;
  final String fileName;
  final int fileSize;
  final String uploadedAt;

  const ProfileDocumentEntity({
    required this.id,
    required this.documentType,
    required this.documentTypeDisplay,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.uploadedAt,
  });
}
