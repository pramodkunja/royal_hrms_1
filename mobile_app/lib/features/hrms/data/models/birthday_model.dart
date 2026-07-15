import '../../domain/entities/birthday_entity.dart';

class BirthdayModel extends BirthdayEntity {
  const BirthdayModel({
    required super.employeeId,
    required super.name,
    required super.department,
    required super.designation,
    required super.dateOfBirth,
    required super.daysUntil,
  });

  // Backend returns: employee_id, name, email, department, designation,
  // date_of_birth ('YYYY-MM-DD'), days_until, wish_sent.
  factory BirthdayModel.fromJson(Map<String, dynamic> json) {
    return BirthdayModel(
      employeeId:  json['employee_id']?.toString() ?? '',
      name:        json['name'] as String? ?? '',
      department:  json['department'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
      dateOfBirth: json['date_of_birth'] as String? ?? '',
      daysUntil:   (json['days_until'] as num? ?? 0).toInt(),
    );
  }
}
