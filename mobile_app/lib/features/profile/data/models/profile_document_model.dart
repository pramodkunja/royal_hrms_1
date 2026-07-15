import '../../domain/entities/profile_document_entity.dart';

class ProfileDocumentModel extends ProfileDocumentEntity {
  const ProfileDocumentModel({
    required super.id,
    required super.documentType,
    required super.documentTypeDisplay,
    required super.fileUrl,
    required super.fileName,
    required super.fileSize,
    required super.uploadedAt,
  });

  factory ProfileDocumentModel.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final sizeRaw = json['file_size'];
    return ProfileDocumentModel(
      id: idRaw is int ? idRaw : int.tryParse(idRaw.toString()) ?? 0,
      documentType: json['document_type'] as String? ?? '',
      documentTypeDisplay: json['document_type_display'] as String? ?? '',
      fileUrl: json['file_url'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      fileSize: sizeRaw is int ? sizeRaw : int.tryParse('$sizeRaw') ?? 0,
      uploadedAt: json['uploaded_at'] as String? ?? '',
    );
  }
}
