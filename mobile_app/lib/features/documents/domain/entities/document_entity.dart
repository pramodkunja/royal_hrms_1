class DocumentEntity {
  final int id;
  final String title;
  final String description;
  final String category;
  final String categoryDisplay;
  final String fileUrl;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String fileSizeDisplay;
  final String? branchName;
  final String uploadedByName;
  final DateTime uploadedAt;
  final bool isActive;

  const DocumentEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.categoryDisplay,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.fileSizeDisplay,
    this.branchName,
    required this.uploadedByName,
    required this.uploadedAt,
    required this.isActive,
  });
}

class DocumentStatsEntity {
  final int total;
  final int policy;
  final int form;
  final int template;
  final int other;

  const DocumentStatsEntity({
    required this.total,
    required this.policy,
    required this.form,
    required this.template,
    required this.other,
  });
}
