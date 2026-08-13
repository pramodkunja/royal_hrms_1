import '../../domain/entities/face_registration_entity.dart';

// Matches FaceRegistrationReadSerializer field-for-field (see
// domain/entities/face_registration_entity.dart for the full mapping note).
class FaceRegistrationModel extends FaceRegistrationEntity {
  const FaceRegistrationModel({
    required super.id,
    required super.employeeName,
    required super.employeeEmail,
    required super.livenessPassed,
    super.livenessScore,
    required super.embeddingModelVersion,
    required super.status,
    required super.approvedByName,
    super.approvedAt,
    required super.notes,
    required super.createdAt,
  });

  factory FaceRegistrationModel.fromJson(Map<String, dynamic> json) {
    return FaceRegistrationModel(
      id: json['id'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      employeeEmail: json['employee_email'] as String? ?? '',
      livenessPassed: json['liveness_passed'] as bool? ?? false,
      livenessScore: (json['liveness_score'] as num?)?.toDouble(),
      embeddingModelVersion: json['embedding_model_version'] as String? ?? '',
      status: faceRegistrationStatusFromJson(json['status'] as String?),
      approvedByName: json['approved_by_name'] as String? ?? '',
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'] as String)
          : null,
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
