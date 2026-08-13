import '../../domain/entities/face_employee_entity.dart';

class FaceEmployeeModel extends FaceEmployeeEntity {
  const FaceEmployeeModel({
    required super.uuid,
    required super.employeeId,
    required super.fullName,
    required super.email,
    super.branch,
    super.department,
    super.designation,
  });

  factory FaceEmployeeModel.fromJson(Map<String, dynamic> json) {
    return FaceEmployeeModel(
      uuid: json['uuid'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      branch: json['branch'] as String?,
      department: json['department'] as String?,
      designation: json['designation'] as String?,
    );
  }
}
