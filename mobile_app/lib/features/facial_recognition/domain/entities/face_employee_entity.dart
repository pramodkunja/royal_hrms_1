// Mirrors apps/attendance/serializers_face_registration.py::FaceRegistrationEmployeeSerializer
// — the minimal projection backing the HR "register/update face ID" employee
// picker. Deliberately thin (no profile/bank/address fields) to match that
// serializer exactly.
class FaceEmployeeEntity {
  final String uuid;
  final String employeeId;
  final String fullName;
  final String email;
  final String? branch;
  final String? department;
  final String? designation;

  const FaceEmployeeEntity({
    required this.uuid,
    required this.employeeId,
    required this.fullName,
    required this.email,
    this.branch,
    this.department,
    this.designation,
  });
}
