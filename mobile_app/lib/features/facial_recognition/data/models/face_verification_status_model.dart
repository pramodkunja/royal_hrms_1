import '../../domain/entities/face_verification_status_entity.dart';

class FaceVerificationStatusModel extends FaceVerificationStatusEntity {
  const FaceVerificationStatusModel({required super.isMandatory});

  factory FaceVerificationStatusModel.fromJson(Map<String, dynamic> json) {
    return FaceVerificationStatusModel(isMandatory: json['is_mandatory'] as bool? ?? false);
  }
}
