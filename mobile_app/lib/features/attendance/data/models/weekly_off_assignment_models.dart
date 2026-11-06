// HR Attendance → Weekly Off Assignment — web
// app/dashboard/attendance/_components/WeeklyOffAssignmentTab.tsx over
// /attendance/weekly-off-assignments/ (apps/attendance/views/hr_attendance.py,
// services_hr.serialize_weekly_off_assignment_row) and the active weekly-off
// patterns from /attendance/weekly-days/. Same permissions and branch rules
// as Shift Assignment (shift_assignment_models.dart: canAssignShifts =
// attendance.create, isUnrestrictedBranchUser, effectiveBranch).

/// Rows per page (web page_size: 20).
const kWeeklyOffPageSize = 20;

/// Web STATUS_OPTIONS for this tab ("Not Assigned", no "Global Default").
const kWeeklyOffStatusOptions = [
  (value: '', label: 'All'),
  (value: 'assigned', label: 'Assigned'),
  (value: 'unassigned', label: 'Not Assigned'),
];

String _s(Object? v) => v == null ? '' : '$v';
String? _opt(Object? v) => v is String && v.isNotEmpty ? v : null;
int _i(Object? v, int fallback) => v is num ? v.toInt() : (int.tryParse('$v') ?? fallback);

/// Weekday keys as the server names them (WeeklyDayPolicy day fields).
const kWeekdayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

/// A weekly-off pattern (web WeeklyOffPattern / Pattern). The assignment tab
/// only needs id and name; the Weekly Off Patterns card also reads the day
/// schedule, usage and flags from the same list response.
class WeeklyOffPattern {
  const WeeklyOffPattern({
    required this.id,
    required this.name,
    required this.policyCode,
    this.days = const {},
    this.workingDaysCount = 0,
    this.assignedEmployeeCount = 0,
    this.isDefault = false,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String policyCode;

  /// weekday key → "working" | "off" | "half_day" (as sent).
  final Map<String, String> days;
  final int workingDaysCount;

  /// Employees currently on this pattern (open assignments).
  final int assignedEmployeeCount;
  final bool isDefault;
  final bool isActive;

  factory WeeklyOffPattern.fromJson(Map<String, dynamic> j) => WeeklyOffPattern(
        id: _s(j['id']),
        name: _s(j['name']),
        policyCode: _s(j['policy_code']),
        days: {
          for (final d in kWeekdayKeys)
            if (j[d] is String) d: j[d] as String
        },
        workingDaysCount: _i(j['working_days_count'], 0),
        assignedEmployeeCount: _i(j['assigned_employee_count'], 0),
        isDefault: j['is_default'] == true,
        isActive: j['is_active'] != false,
      );
}

/// One employee's current weekly-off pattern (web AssignmentRow).
class WeeklyOffAssignmentRow {
  const WeeklyOffAssignmentRow({
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.branch,
    required this.patternId,
    required this.patternName,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.status,
  });

  final String employeeId;
  final String employeeName;
  final String department;
  final String branch;
  final String? patternId;
  final String? patternName;
  final String? effectiveFrom;
  final String? effectiveTo;

  /// "Assigned" | "Not Assigned".
  final String status;

  bool get isAssigned => status == 'Assigned';

  factory WeeklyOffAssignmentRow.fromJson(Map<String, dynamic> j) => WeeklyOffAssignmentRow(
        employeeId: _s(j['employee_id']),
        employeeName: _s(j['employee_name']),
        department: _s(j['department']),
        branch: _s(j['branch']),
        patternId: _opt(j['pattern_id']),
        patternName: _opt(j['pattern_name']),
        effectiveFrom: _opt(j['effective_from']),
        effectiveTo: _opt(j['effective_to']),
        status:
            _s(j['status']).isEmpty ? (_opt(j['pattern_id']) != null ? 'Assigned' : 'Not Assigned') : _s(j['status']),
      );
}

class WeeklyOffAssignmentPage {
  const WeeklyOffAssignmentPage(
      {required this.count, required this.page, required this.totalPages, required this.rows});
  final int count;
  final int page;
  final int totalPages;
  final List<WeeklyOffAssignmentRow> rows;

  factory WeeklyOffAssignmentPage.fromJson(Map<String, dynamic> j) {
    final list = j['results'] is List ? j['results'] as List : const [];
    return WeeklyOffAssignmentPage(
      count: _i(j['count'], 0),
      page: _i(j['page'], 1),
      totalPages: _i(j['total_pages'], 1),
      rows: [
        for (final r in list)
          if (r is Map) WeeklyOffAssignmentRow.fromJson(Map<String, dynamic>.from(r)),
      ],
    );
  }
}

/// List filters (web: branch, department, pattern, status, page).
class WeeklyOffQuery {
  const WeeklyOffQuery({this.branch = '', this.department = '', this.pattern = '', this.status = '', this.page = 1});
  final String branch;
  final String department;
  final String pattern;
  final String status;
  final int page;

  /// Web toQuery: empty values are left out.
  Map<String, dynamic> params() => {
        if (branch.isNotEmpty) 'branch': branch,
        if (department.isNotEmpty) 'department': department,
        if (pattern.isNotEmpty) 'pattern': pattern,
        if (status.isNotEmpty) 'status': status,
        'page': page,
        'page_size': kWeeklyOffPageSize,
      };

  /// Any filter change starts again at page 1 (web setPage(1)).
  WeeklyOffQuery copyWith({String? branch, String? department, String? pattern, String? status, int? page}) =>
      WeeklyOffQuery(
        branch: branch ?? this.branch,
        department: department ?? this.department,
        pattern: pattern ?? this.pattern,
        status: status ?? this.status,
        page: page ?? 1,
      );

  @override
  bool operator ==(Object other) =>
      other is WeeklyOffQuery &&
      other.branch == branch &&
      other.department == department &&
      other.pattern == pattern &&
      other.status == status &&
      other.page == page;

  @override
  int get hashCode => Object.hash(branch, department, pattern, status, page);
}
