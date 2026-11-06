// Settings → Attendance Rules → "Weekly Off Patterns" card — web
// app/dashboard/attendance/_components/WeeklyOffPatternsCard.tsx over
// /attendance/weekly-days/ (apps/attendance/views/weekly_days.py). Lists every
// pattern (active and inactive, default first then by name) three per page;
// create POST (attendance.create), edit PATCH (attendance.edit), deactivate
// DELETE (attendance.delete; refused for the default or an assigned pattern).

import '../../../auth/domain/entities/user_entity.dart';
import 'weekly_off_assignment_models.dart' show WeeklyOffPattern, kWeekdayKeys;

/// Web PAGE_SIZE for this card.
const kWeeklyOffPatternPageSize = 3;

/// Server day types and web's labels.
const kDayTypes = [('working', 'Working'), ('off', 'Off'), ('half_day', 'Half Day')];

/// Web DAYS short labels, Monday first.
const kWeekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

bool _has(UserEntity? user, String perm) => user != null && (user.isSuperuser || user.permissions.contains(perm));

/// Server GET permission (the card is shown only with it).
bool canViewWeeklyOffPatterns(UserEntity? user) => _has(user, 'attendance.view');
bool canCreateWeeklyOffPatterns(UserEntity? user) => _has(user, 'attendance.create');
bool canEditWeeklyOffPatterns(UserEntity? user) => _has(user, 'attendance.edit');
bool canDeleteWeeklyOffPatterns(UserEntity? user) => _has(user, 'attendance.delete');

/// Web daysSummary: "Sat • Sun", half days as "Fri (half-day)", or "No off days".
String weeklyOffDaysSummary(WeeklyOffPattern p) {
  final off = [
    for (var i = 0; i < 7; i++)
      if (p.days[kWeekdayKeys[i]] == 'off') kWeekdayShort[i],
  ];
  final half = [
    for (var i = 0; i < 7; i++)
      if (p.days[kWeekdayKeys[i]] == 'half_day') '${kWeekdayShort[i]} (half-day)',
  ];
  final parts = [...off, ...half];
  return parts.isEmpty ? 'No off days' : parts.join(' • ');
}

/// Web deleteBlockedReason: why Deactivate is disabled, or null.
String? deactivateBlockedReason(WeeklyOffPattern p) {
  if (p.isDefault) return 'Assign another pattern as default before removing this one.';
  final n = p.assignedEmployeeCount;
  if (n > 0) return 'Currently assigned to $n employee${n != 1 ? 's' : ''} — reassign them first.';
  return null;
}

String _i(Object? v) => '$v';

class WeeklyOffPatternPage {
  const WeeklyOffPatternPage(
      {required this.count, required this.page, required this.totalPages, required this.patterns});
  final int count;
  final int page;
  final int totalPages;
  final List<WeeklyOffPattern> patterns;

  factory WeeklyOffPatternPage.fromJson(Map<String, dynamic> j) {
    int n(Object? v, int f) => v is num ? v.toInt() : (int.tryParse(_i(v)) ?? f);
    final list = j['results'] is List ? j['results'] as List : const [];
    return WeeklyOffPatternPage(
      count: n(j['count'], 0),
      page: n(j['page'], 1),
      totalPages: n(j['total_pages'], 1),
      patterns: [
        for (final p in list)
          if (p is Map) WeeklyOffPattern.fromJson(Map<String, dynamic>.from(p)),
      ],
    );
  }
}

/// Whether the company has no active default pattern, judged from page 1 of
/// the card's own list: the server orders patterns `-is_default, name` and
/// keeps at most one default, so a default (active or not) is always on page
/// 1. Any other page can't tell, so it answers null ("unknown") — as does
/// anything not yet loaded. With no active default, employees without an
/// individual assignment fall back to the legacy AttendanceSettings.weekly_off
/// (WeeklyOffCacheService).
bool? noActiveDefaultPattern({required int requestedPage, required WeeklyOffPatternPage? page}) {
  if (page == null || requestedPage != 1) return null;
  return !page.patterns.any((p) => p.isDefault && p.isActive);
}

/// The Add/Edit form (web FormState; EMPTY_FORM = Mon–Fri working, Sat/Sun off).
class WeeklyOffPatternForm {
  WeeklyOffPatternForm({this.name = '', Map<String, String>? days, this.isDefault = false})
      : days = {
          for (final d in kWeekdayKeys) d: days?[d] ?? ((d == 'saturday' || d == 'sunday') ? 'off' : 'working'),
        };

  /// Web openEdit: the pattern's own name, days and default flag.
  factory WeeklyOffPatternForm.fromPattern(WeeklyOffPattern p) =>
      WeeklyOffPatternForm(name: p.name, days: p.days, isDefault: p.isDefault);

  String name;
  final Map<String, String> days;
  bool isDefault;

  /// Web Save button: a name is enough (the server checks the rest).
  bool get canSave => name.isNotEmpty;

  /// Web handleSave payload: no policy_code (server-generated, immutable),
  /// is_active always true.
  Map<String, dynamic> toJson() => {
        'name': name,
        for (final d in kWeekdayKeys) d: days[d],
        'is_default': isDefault,
        'is_active': true,
      };
}
