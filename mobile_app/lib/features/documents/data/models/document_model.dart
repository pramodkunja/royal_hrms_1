import '../../domain/entities/document_entity.dart';

class DocumentModel extends DocumentEntity {
  const DocumentModel({
    required super.id,
    required super.title,
    required super.description,
    required super.category,
    required super.categoryDisplay,
    required super.fileUrl,
    required super.fileName,
    required super.fileType,
    required super.fileSize,
    required super.fileSizeDisplay,
    super.branchName,
    required super.uploadedByName,
    required super.uploadedAt,
    required super.isActive,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      categoryDisplay: json['category_display'] as String? ?? 'Other',
      fileUrl: json['file_url'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      fileType: json['file_type'] as String? ?? '',
      fileSize: json['file_size'] as int? ?? 0,
      fileSizeDisplay: json['file_size_display'] as String? ?? '',
      branchName: json['branch_name'] as String?,
      uploadedByName: json['uploaded_by_name'] as String? ?? '',
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.tryParse(json['uploaded_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class DocumentStatsModel extends DocumentStatsEntity {
  const DocumentStatsModel({
    required super.total,
    required super.policy,
    required super.form,
    required super.template,
    required super.other,
  });

  factory DocumentStatsModel.fromJson(Map<String, dynamic> json) {
    final byCategory =
        json['by_category'] as Map<String, dynamic>? ?? {};
    return DocumentStatsModel(
      total: json['total'] as int? ?? 0,
      policy: byCategory['policy'] as int? ?? 0,
      form: byCategory['form'] as int? ?? 0,
      template: byCategory['template'] as int? ?? 0,
      other: byCategory['other'] as int? ?? 0,
    );
  }
}
