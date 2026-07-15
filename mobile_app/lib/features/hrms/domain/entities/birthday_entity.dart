class BirthdayEntity {
  final String employeeId;
  final String name;
  final String department;
  final String designation;
  final String dateOfBirth; // ISO 'YYYY-MM-DD'
  final int daysUntil;

  const BirthdayEntity({
    required this.employeeId,
    required this.name,
    required this.department,
    required this.designation,
    required this.dateOfBirth,
    required this.daysUntil,
  });

  /// Computed from [dateOfBirth] — null if the date can't be parsed.
  int? get age {
    final dob = DateTime.tryParse(dateOfBirth);
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }
}

class BirthdaysResult {
  final List<BirthdayEntity> today;
  final List<BirthdayEntity> upcoming;

  const BirthdaysResult({required this.today, required this.upcoming});
}
