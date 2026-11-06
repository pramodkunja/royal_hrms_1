// HR Attendance → Shift Assignment — web
// app/dashboard/attendance/_components/ShiftAssignmentTab.tsx over
// /attendance/shift-assignments/ (apps/attendance/views/hr_attendance.py,
// services_hr.serialize_shift_assignment_row) and the active shift masters
// from /attendance/working-hours/.

import '../../../auth/domain/entities/user_entity.dart';

/// Rows per page (web page_size: 20).
const kShiftAssignmentPageSize = 20;

/// Web STATUS_OPTIONS.
const kShiftStatusOptions = [
  (value: '', label: 'All'),
  (value: 'assigned', label: 'Assigned'),
  (value: 'unassigned', label: 'Not Assigned (Global Default)'),
];

/// Web usePermission("attendance.create"): superuser or the permission.
bool canAssignShifts(UserEntity? user) =>
    user != null && (user.isSuperuser || user.permissions.contains('attendance.create'));

/// Web isUnrestrictedUser: superuser or settings.edit (may pick any branch).
bool isUnrestrictedBranchUser(UserEntity? user) =>
    user != null && (user.isSuperuser || user.permissions.contains('settings.edit'));

/// Web getEffectiveBranch: "" for unrestricted users, else their own branch.
String effectiveBranch(UserEntity? user) => isUnrestrictedBranchUser(user) ? '' : (user?.branch ?? '');

String _s(Object? v) => v == null ? '' : '$v';
String? _opt(Object? v) => v is String && v.isNotEmpty ? v : null;
int _i(Object? v, int fallback) => v is num ? v.toInt() : (int.tryParse('$v') ?? fallback);

/// An active shift master (web ShiftOption).
class ShiftOption {
  const ShiftOption({required this.id, required this.name, required this.policyCode});
  final String id;
  final String name;
  final String policyCode;

  factory ShiftOption.fromJson(Map<String, dynamic> j) =>
      ShiftOption(id: _s(j['id']), name: _s(j['name']), policyCode: _s(j['policy_code']));
}

/// One employee's current shift (web AssignmentRow).
class ShiftAssignmentRow {
  const ShiftAssignmentRow({
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.branch,
    required this.shiftId,
    required this.shiftName,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.status,
  });

  final String employeeId;
  final String employeeName;
  final String department;
  final String branch;
  final String? shiftId;
  final String? shiftName;
  final String? effectiveFrom;
  final String? effectiveTo;

  /// "Assigned" | "Not Assigned".
  final String status;

  bool get isAssigned => status == 'Assigned';

  factory ShiftAssignmentRow.fromJson(Map<String, dynamic> j) => ShiftAssignmentRow(
        employeeId: _s(j['employee_id']),
        employeeName: _s(j['employee_name']),
        department: _s(j['department']),
        branch: _s(j['branch']),
        shiftId: _opt(j['shift_id']),
        shiftName: _opt(j['shift_name']),
        effectiveFrom: _opt(j['effective_from']),
        effectiveTo: _opt(j['effective_to']),
        status: _s(j['status']).isEmpty ? (_opt(j['shift_id']) != null ? 'Assigned' : 'Not Assigned') : _s(j['status']),
      );
}

class ShiftAssignmentPage {
  const ShiftAssignmentPage({required this.count, required this.page, required this.totalPages, required this.rows});
  final int count;
  final int page;
  final int totalPages;
  final List<ShiftAssignmentRow> rows;

  factory ShiftAssignmentPage.fromJson(Map<String, dynamic> j) {
    final list = j['results'] is List ? j['results'] as List : const [];
    return ShiftAssignmentPage(
      count: _i(j['count'], 0),
      page: _i(j['page'], 1),
      totalPages: _i(j['total_pages'], 1),
      rows: [
        for (final r in list)
          if (r is Map) ShiftAssignmentRow.fromJson(Map<String, dynamic>.from(r))
      ],
    );
  }
}

/// List filters (web: branch, department, shift, status, page).
class ShiftAssignmentQuery {
  const ShiftAssignmentQuery(
      {this.branch = '', this.department = '', this.shift = '', this.status = '', this.page = 1});
  final String branch;
  final String department;
  final String shift;
  final String status;
  final int page;

  /// Web toQuery: empty values are left out.
  Map<String, dynamic> params() => {
        if (branch.isNotEmpty) 'branch': branch,
        if (department.isNotEmpty) 'department': department,
        if (shift.isNotEmpty) 'shift': shift,
        if (status.isNotEmpty) 'status': status,
        'page': page,
        'page_size': kShiftAssignmentPageSize,
      };

  ShiftAssignmentQuery copyWith({String? branch, String? department, String? shift, String? status, int? page}) =>
      ShiftAssignmentQuery(
        branch: branch ?? this.branch,
        department: department ?? this.department,
        shift: shift ?? this.shift,
        status: status ?? this.status,
        // Any filter change starts again at page 1 (web setPage(1)).
        page: page ?? 1,
      );

  @override
  bool operator ==(Object other) =>
      other is ShiftAssignmentQuery &&
      other.branch == branch &&
      other.department == department &&
      other.shift == shift &&
      other.status == status &&
      other.page == page;

  @override
  int get hashCode => Object.hash(branch, department, shift, status, page);
}

String isoDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
