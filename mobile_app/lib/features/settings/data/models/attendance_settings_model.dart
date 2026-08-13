// Maps apps/attendance/serializers_settings.py exactly. Each section is a
// OneToOne child of the singleton AttendanceSettings row on the backend.

class WorkingHoursSectionModel {
  final String shiftStart; // 'HH:MM'
  final String shiftEnd; // 'HH:MM'
  final int gracePeriodMinutes;
  final int breakDurationMinutes;

  const WorkingHoursSectionModel({
    required this.shiftStart,
    required this.shiftEnd,
    required this.gracePeriodMinutes,
    required this.breakDurationMinutes,
  });

  static const defaults = WorkingHoursSectionModel(
    shiftStart: '09:00',
    shiftEnd: '18:00',
    gracePeriodMinutes: 15,
    breakDurationMinutes: 30,
  );

  factory WorkingHoursSectionModel.fromJson(Map<String, dynamic> json) {
    return WorkingHoursSectionModel(
      shiftStart: _toHHmm(json['shift_start'] as String? ?? '09:00'),
      shiftEnd: _toHHmm(json['shift_end'] as String? ?? '18:00'),
      gracePeriodMinutes: (json['grace_period_minutes'] as num? ?? 15).toInt(),
      breakDurationMinutes: (json['break_duration_minutes'] as num? ?? 30).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'shift_start': '$shiftStart:00',
        'shift_end': '$shiftEnd:00',
        'grace_period_minutes': gracePeriodMinutes,
        'break_duration_minutes': breakDurationMinutes,
      };

  WorkingHoursSectionModel copyWith({
    String? shiftStart,
    String? shiftEnd,
    int? gracePeriodMinutes,
    int? breakDurationMinutes,
  }) =>
      WorkingHoursSectionModel(
        shiftStart: shiftStart ?? this.shiftStart,
        shiftEnd: shiftEnd ?? this.shiftEnd,
        gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
        breakDurationMinutes: breakDurationMinutes ?? this.breakDurationMinutes,
      );
}

// Truncates any 'HH:MM:SS' the API returns down to 'HH:MM' for display/editing.
String _toHHmm(String raw) => raw.length >= 5 ? raw.substring(0, 5) : raw;

class WeeklyOffSectionModel {
  final bool monday;
  final bool tuesday;
  final bool wednesday;
  final bool thursday;
  final bool friday;
  final bool saturday;
  final bool sunday;

  const WeeklyOffSectionModel({
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
  });

  static const defaults = WeeklyOffSectionModel(
    monday: false,
    tuesday: false,
    wednesday: false,
    thursday: false,
    friday: false,
    saturday: true,
    sunday: true,
  );

  factory WeeklyOffSectionModel.fromJson(Map<String, dynamic> json) {
    return WeeklyOffSectionModel(
      monday: json['monday'] as bool? ?? false,
      tuesday: json['tuesday'] as bool? ?? false,
      wednesday: json['wednesday'] as bool? ?? false,
      thursday: json['thursday'] as bool? ?? false,
      friday: json['friday'] as bool? ?? false,
      saturday: json['saturday'] as bool? ?? true,
      sunday: json['sunday'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'monday': monday,
        'tuesday': tuesday,
        'wednesday': wednesday,
        'thursday': thursday,
        'friday': friday,
        'saturday': saturday,
        'sunday': sunday,
      };

  bool get hasAtLeastOneWorkingDay =>
      [monday, tuesday, wednesday, thursday, friday, saturday, sunday].contains(false);

  WeeklyOffSectionModel toggled(String day) {
    switch (day) {
      case 'monday':
        return copyWith(monday: !monday);
      case 'tuesday':
        return copyWith(tuesday: !tuesday);
      case 'wednesday':
        return copyWith(wednesday: !wednesday);
      case 'thursday':
        return copyWith(thursday: !thursday);
      case 'friday':
        return copyWith(friday: !friday);
      case 'saturday':
        return copyWith(saturday: !saturday);
      case 'sunday':
        return copyWith(sunday: !sunday);
      default:
        return this;
    }
  }

  bool valueFor(String day) => switch (day) {
        'monday' => monday,
        'tuesday' => tuesday,
        'wednesday' => wednesday,
        'thursday' => thursday,
        'friday' => friday,
        'saturday' => saturday,
        'sunday' => sunday,
        _ => false,
      };

  WeeklyOffSectionModel copyWith({
    bool? monday,
    bool? tuesday,
    bool? wednesday,
    bool? thursday,
    bool? friday,
    bool? saturday,
    bool? sunday,
  }) =>
      WeeklyOffSectionModel(
        monday: monday ?? this.monday,
        tuesday: tuesday ?? this.tuesday,
        wednesday: wednesday ?? this.wednesday,
        thursday: thursday ?? this.thursday,
        friday: friday ?? this.friday,
        saturday: saturday ?? this.saturday,
        sunday: sunday ?? this.sunday,
      );
}

class PunchRulesSectionModel {
  final String minHoursFullDay; // decimal string e.g. '8.00'
  final String minHoursHalfDay;
  final int earlyExitGraceMinutes;

  const PunchRulesSectionModel({
    required this.minHoursFullDay,
    required this.minHoursHalfDay,
    required this.earlyExitGraceMinutes,
  });

  static const defaults = PunchRulesSectionModel(
    minHoursFullDay: '8.00',
    minHoursHalfDay: '4.00',
    earlyExitGraceMinutes: 30,
  );

  factory PunchRulesSectionModel.fromJson(Map<String, dynamic> json) {
    return PunchRulesSectionModel(
      minHoursFullDay: _toDecimalString(json['min_hours_full_day'], '8.00'),
      minHoursHalfDay: _toDecimalString(json['min_hours_half_day'], '4.00'),
      earlyExitGraceMinutes: (json['early_exit_grace_minutes'] as num? ?? 30).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'min_hours_full_day': minHoursFullDay,
        'min_hours_half_day': minHoursHalfDay,
        'early_exit_grace_minutes': earlyExitGraceMinutes,
      };

  PunchRulesSectionModel copyWith({
    String? minHoursFullDay,
    String? minHoursHalfDay,
    int? earlyExitGraceMinutes,
  }) =>
      PunchRulesSectionModel(
        minHoursFullDay: minHoursFullDay ?? this.minHoursFullDay,
        minHoursHalfDay: minHoursHalfDay ?? this.minHoursHalfDay,
        earlyExitGraceMinutes: earlyExitGraceMinutes ?? this.earlyExitGraceMinutes,
      );
}

class OvertimeRulesSectionModel {
  final String otThresholdHours;
  final String otMultiplierRegular;
  final String otMultiplierHoliday;

  const OvertimeRulesSectionModel({
    required this.otThresholdHours,
    required this.otMultiplierRegular,
    required this.otMultiplierHoliday,
  });

  static const defaults = OvertimeRulesSectionModel(
    otThresholdHours: '9.00',
    otMultiplierRegular: '1.50',
    otMultiplierHoliday: '2.00',
  );

  factory OvertimeRulesSectionModel.fromJson(Map<String, dynamic> json) {
    return OvertimeRulesSectionModel(
      otThresholdHours: _toDecimalString(json['ot_threshold_hours'], '9.00'),
      otMultiplierRegular: _toDecimalString(json['ot_multiplier_regular'], '1.50'),
      otMultiplierHoliday: _toDecimalString(json['ot_multiplier_holiday'], '2.00'),
    );
  }

  Map<String, dynamic> toJson() => {
        'ot_threshold_hours': otThresholdHours,
        'ot_multiplier_regular': otMultiplierRegular,
        'ot_multiplier_holiday': otMultiplierHoliday,
      };

  OvertimeRulesSectionModel copyWith({
    String? otThresholdHours,
    String? otMultiplierRegular,
    String? otMultiplierHoliday,
  }) =>
      OvertimeRulesSectionModel(
        otThresholdHours: otThresholdHours ?? this.otThresholdHours,
        otMultiplierRegular: otMultiplierRegular ?? this.otMultiplierRegular,
        otMultiplierHoliday: otMultiplierHoliday ?? this.otMultiplierHoliday,
      );
}

class LateMarkRulesSectionModel {
  final int lateMarksPerLop;
  final String lopDeductionUnit; // 'full_day' | 'half_day'

  const LateMarkRulesSectionModel({
    required this.lateMarksPerLop,
    required this.lopDeductionUnit,
  });

  static const defaults = LateMarkRulesSectionModel(
    lateMarksPerLop: 3,
    lopDeductionUnit: 'full_day',
  );

  factory LateMarkRulesSectionModel.fromJson(Map<String, dynamic> json) {
    return LateMarkRulesSectionModel(
      lateMarksPerLop: (json['late_marks_per_lop'] as num? ?? 3).toInt(),
      lopDeductionUnit: json['lop_deduction_unit'] as String? ?? 'full_day',
    );
  }

  Map<String, dynamic> toJson() => {
        'late_marks_per_lop': lateMarksPerLop,
        'lop_deduction_unit': lopDeductionUnit,
      };

  LateMarkRulesSectionModel copyWith({int? lateMarksPerLop, String? lopDeductionUnit}) =>
      LateMarkRulesSectionModel(
        lateMarksPerLop: lateMarksPerLop ?? this.lateMarksPerLop,
        lopDeductionUnit: lopDeductionUnit ?? this.lopDeductionUnit,
      );
}

class AbsenceAlertSectionModel {
  final bool isEnabled;
  final int alertAfterDays;
  final String notifyWhom; // 'manager_and_hr' | 'hr_only' | 'manager_only'

  const AbsenceAlertSectionModel({
    required this.isEnabled,
    required this.alertAfterDays,
    required this.notifyWhom,
  });

  static const defaults = AbsenceAlertSectionModel(
    isEnabled: true,
    alertAfterDays: 3,
    notifyWhom: 'manager_and_hr',
  );

  factory AbsenceAlertSectionModel.fromJson(Map<String, dynamic> json) {
    return AbsenceAlertSectionModel(
      isEnabled: json['is_enabled'] as bool? ?? true,
      alertAfterDays: (json['alert_after_days'] as num? ?? 3).toInt(),
      notifyWhom: json['notify_whom'] as String? ?? 'manager_and_hr',
    );
  }

  Map<String, dynamic> toJson() => {
        'is_enabled': isEnabled,
        'alert_after_days': alertAfterDays,
        'notify_whom': notifyWhom,
      };

  AbsenceAlertSectionModel copyWith({
    bool? isEnabled,
    int? alertAfterDays,
    String? notifyWhom,
  }) =>
      AbsenceAlertSectionModel(
        isEnabled: isEnabled ?? this.isEnabled,
        alertAfterDays: alertAfterDays ?? this.alertAfterDays,
        notifyWhom: notifyWhom ?? this.notifyWhom,
      );
}

class FaceVerificationSectionModel {
  final bool isMandatory;

  const FaceVerificationSectionModel({required this.isMandatory});

  static const defaults = FaceVerificationSectionModel(isMandatory: false);

  factory FaceVerificationSectionModel.fromJson(Map<String, dynamic> json) {
    return FaceVerificationSectionModel(isMandatory: json['is_mandatory'] as bool? ?? false);
  }

  Map<String, dynamic> toJson() => {'is_mandatory': isMandatory};

  FaceVerificationSectionModel copyWith({bool? isMandatory}) =>
      FaceVerificationSectionModel(isMandatory: isMandatory ?? this.isMandatory);
}

class AttendanceSettingsModel {
  final WorkingHoursSectionModel workingHours;
  final WeeklyOffSectionModel weeklyOff;
  final PunchRulesSectionModel punchRules;
  final OvertimeRulesSectionModel overtimeRules;
  final LateMarkRulesSectionModel lateMarkRules;
  final AbsenceAlertSectionModel absenceAlert;
  final FaceVerificationSectionModel faceVerification;
  final String? updatedByName;
  final String? updatedAt;

  const AttendanceSettingsModel({
    required this.workingHours,
    required this.weeklyOff,
    required this.punchRules,
    required this.overtimeRules,
    required this.lateMarkRules,
    required this.absenceAlert,
    required this.faceVerification,
    this.updatedByName,
    this.updatedAt,
  });

  static const defaults = AttendanceSettingsModel(
    workingHours: WorkingHoursSectionModel.defaults,
    weeklyOff: WeeklyOffSectionModel.defaults,
    punchRules: PunchRulesSectionModel.defaults,
    overtimeRules: OvertimeRulesSectionModel.defaults,
    lateMarkRules: LateMarkRulesSectionModel.defaults,
    absenceAlert: AbsenceAlertSectionModel.defaults,
    faceVerification: FaceVerificationSectionModel.defaults,
  );

  factory AttendanceSettingsModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSettingsModel(
      workingHours: json['working_hours'] is Map<String, dynamic>
          ? WorkingHoursSectionModel.fromJson(json['working_hours'] as Map<String, dynamic>)
          : WorkingHoursSectionModel.defaults,
      weeklyOff: json['weekly_off'] is Map<String, dynamic>
          ? WeeklyOffSectionModel.fromJson(json['weekly_off'] as Map<String, dynamic>)
          : WeeklyOffSectionModel.defaults,
      punchRules: json['punch_rules'] is Map<String, dynamic>
          ? PunchRulesSectionModel.fromJson(json['punch_rules'] as Map<String, dynamic>)
          : PunchRulesSectionModel.defaults,
      overtimeRules: json['overtime_rules'] is Map<String, dynamic>
          ? OvertimeRulesSectionModel.fromJson(json['overtime_rules'] as Map<String, dynamic>)
          : OvertimeRulesSectionModel.defaults,
      lateMarkRules: json['late_mark_rules'] is Map<String, dynamic>
          ? LateMarkRulesSectionModel.fromJson(json['late_mark_rules'] as Map<String, dynamic>)
          : LateMarkRulesSectionModel.defaults,
      absenceAlert: json['absence_alert'] is Map<String, dynamic>
          ? AbsenceAlertSectionModel.fromJson(json['absence_alert'] as Map<String, dynamic>)
          : AbsenceAlertSectionModel.defaults,
      faceVerification: json['face_verification'] is Map<String, dynamic>
          ? FaceVerificationSectionModel.fromJson(json['face_verification'] as Map<String, dynamic>)
          : FaceVerificationSectionModel.defaults,
      updatedByName: json['updated_by_name'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'working_hours': workingHours.toJson(),
        'weekly_off': weeklyOff.toJson(),
        'punch_rules': punchRules.toJson(),
        'overtime_rules': overtimeRules.toJson(),
        'late_mark_rules': lateMarkRules.toJson(),
        'absence_alert': absenceAlert.toJson(),
        'face_verification': faceVerification.toJson(),
      };

  AttendanceSettingsModel copyWith({
    WorkingHoursSectionModel? workingHours,
    WeeklyOffSectionModel? weeklyOff,
    PunchRulesSectionModel? punchRules,
    OvertimeRulesSectionModel? overtimeRules,
    LateMarkRulesSectionModel? lateMarkRules,
    AbsenceAlertSectionModel? absenceAlert,
    FaceVerificationSectionModel? faceVerification,
  }) =>
      AttendanceSettingsModel(
        workingHours: workingHours ?? this.workingHours,
        weeklyOff: weeklyOff ?? this.weeklyOff,
        punchRules: punchRules ?? this.punchRules,
        overtimeRules: overtimeRules ?? this.overtimeRules,
        lateMarkRules: lateMarkRules ?? this.lateMarkRules,
        absenceAlert: absenceAlert ?? this.absenceAlert,
        faceVerification: faceVerification ?? this.faceVerification,
        updatedByName: updatedByName,
        updatedAt: updatedAt,
      );
}

// Decimal fields (DecimalField) are serialized by DRF as JSON strings, but
// defensively accept a numeric value too.
String _toDecimalString(dynamic value, String fallback) {
  if (value == null) return fallback;
  if (value is String && value.isNotEmpty) return value;
  if (value is num) return value.toStringAsFixed(2);
  return fallback;
}
