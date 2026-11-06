// HR Attendance → Shift Assignment → "Shifts" card (Shift Masters) — web
// app/dashboard/attendance/_components/ShiftMasterCard.tsx over
// /attendance/working-hours/ (apps/attendance/views/working_hours.py,
// serializers WorkingHoursPolicy*). Create: POST (attendance.create);
// edit: PATCH (attendance.edit); delete = deactivate: DELETE
// (attendance.delete, refused for the default shift). The list shows active
// shifts only, five per page.

import '../../../auth/domain/entities/user_entity.dart';

/// Web PAGE_SIZE for this card.
const kShiftMasterPageSize = 5;

/// Web usePermission semantics (superuser, or the permission itself).
bool _has(UserEntity? user, String perm) => user != null && (user.isSuperuser || user.permissions.contains(perm));

/// Server PUT/PATCH permission.
bool canEditShiftMasters(UserEntity? user) => _has(user, 'attendance.edit');

/// Server DELETE permission.
bool canDeleteShiftMasters(UserEntity? user) => _has(user, 'attendance.delete');

String _s(Object? v) => v == null ? '' : '$v';
int _i(Object? v, int fallback) => v is num ? v.toInt() : (int.tryParse('$v') ?? fallback);

/// Web toHHMM: "09:00:00" → "09:00".
String toHHMM(String? v) => v == null || v.isEmpty ? '' : (v.length >= 5 ? v.substring(0, 5) : v);

/// One shift (WorkingHoursPolicyListSerializer).
class ShiftMaster {
  const ShiftMaster({
    required this.id,
    required this.name,
    required this.policyCode,
    required this.startTime,
    required this.endTime,
    required this.breakDuration,
    required this.gracePeriod,
    required this.minimumWorkingHours,
    required this.maximumWorkingHours,
    required this.isDefault,
    required this.isActive,
  });

  final String id;
  final String name;
  final String policyCode;

  /// "HH:MM:SS" as sent.
  final String startTime;
  final String endTime;
  final int breakDuration;
  final int gracePeriod;

  /// Decimal text as sent ("4.00"); sent back unchanged on edit, as web does.
  final String minimumWorkingHours;
  final String maximumWorkingHours;
  final bool isDefault;
  final bool isActive;

  factory ShiftMaster.fromJson(Map<String, dynamic> j) => ShiftMaster(
        id: _s(j['id']),
        name: _s(j['name']),
        policyCode: _s(j['policy_code']),
        startTime: _s(j['start_time']),
        endTime: _s(j['end_time']),
        breakDuration: _i(j['break_duration'], 0),
        gracePeriod: _i(j['grace_period'], 0),
        minimumWorkingHours: _s(j['minimum_working_hours']),
        maximumWorkingHours: _s(j['maximum_working_hours']),
        isDefault: j['is_default'] == true,
        isActive: j['is_active'] != false,
      );
}

class ShiftMasterPage {
  const ShiftMasterPage({required this.count, required this.page, required this.totalPages, required this.shifts});
  final int count;
  final int page;
  final int totalPages;
  final List<ShiftMaster> shifts;

  factory ShiftMasterPage.fromJson(Map<String, dynamic> j) {
    final list = j['results'] is List ? j['results'] as List : const [];
    return ShiftMasterPage(
      count: _i(j['count'], 0),
      page: _i(j['page'], 1),
      totalPages: _i(j['total_pages'], 1),
      shifts: [
        for (final s in list)
          if (s is Map) ShiftMaster.fromJson(Map<String, dynamic>.from(s)),
      ],
    );
  }
}

/// The Add/Edit form (web WorkingHoursPolicyForm, EMPTY_FORM defaults).
class ShiftMasterForm {
  ShiftMasterForm({
    this.name = '',
    this.startTime = '09:00',
    this.endTime = '18:00',
    this.breakDuration = 30,
    this.gracePeriod = 15,
    this.minimumWorkingHours = '4.00',
    this.maximumWorkingHours = '9.00',
    this.isDefault = false,
    this.description = '',
  });

  /// Web openEdit: the shift's own values ("HH:MM" times). The list carries
  /// no description, so none is sent back on edit (web sends undefined).
  factory ShiftMasterForm.fromShift(ShiftMaster s) => ShiftMasterForm(
        name: s.name,
        startTime: toHHMM(s.startTime),
        endTime: toHHMM(s.endTime),
        breakDuration: s.breakDuration,
        gracePeriod: s.gracePeriod,
        minimumWorkingHours: s.minimumWorkingHours,
        maximumWorkingHours: s.maximumWorkingHours,
        isDefault: s.isDefault,
        description: null,
      );

  String name;
  String startTime; // "HH:MM"
  String endTime;
  int breakDuration;
  int gracePeriod;
  String minimumWorkingHours;
  String maximumWorkingHours;
  bool isDefault;

  /// '' on create (web EMPTY_FORM); null on edit (not sent).
  String? description;

  /// Web Save button: needs a name, a start and an end.
  bool get canSave => name.isNotEmpty && startTime.isNotEmpty && endTime.isNotEmpty;

  /// Web handleSave payload. policy_code is never sent (the server generates
  /// it and keeps it read-only); is_active is always true.
  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'start_time': '$startTime:00',
        'end_time': '$endTime:00',
        'break_duration': breakDuration,
        'grace_period': gracePeriod,
        'minimum_working_hours': minimumWorkingHours,
        'maximum_working_hours': maximumWorkingHours,
        'is_default': isDefault,
        'is_active': true,
      };
}
