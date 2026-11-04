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

  /// Employees must read and acknowledge this document (Company Policy).
  final bool requiresAcknowledgement;

  /// Bumped by the server whenever the file is replaced; an acknowledgement
  /// counts only for the version it was given for.
  final int version;

  /// When the signed-in user acknowledged the current version (null: not yet).
  final String? myAcknowledgedAt;

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
    this.requiresAcknowledgement = false,
    this.version = 1,
    this.myAcknowledgedAt,
  });

  DocumentEntity copyWithAck({bool? requiresAcknowledgement, String? myAcknowledgedAt, bool clearAck = false}) =>
      DocumentEntity(
        id: id,
        title: title,
        description: description,
        category: category,
        categoryDisplay: categoryDisplay,
        fileUrl: fileUrl,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
        fileSizeDisplay: fileSizeDisplay,
        branchName: branchName,
        uploadedByName: uploadedByName,
        uploadedAt: uploadedAt,
        isActive: isActive,
        requiresAcknowledgement: requiresAcknowledgement ?? this.requiresAcknowledgement,
        version: version,
        myAcknowledgedAt: clearAck ? null : (myAcknowledgedAt ?? this.myAcknowledgedAt),
      );
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
