import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/access_control.dart' show userHasPermission;
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'attendance_providers.dart';

// HR attendance "Export CSV" — web lib/attendanceExport.ts and
// app/dashboard/attendance/_components/AttendanceTab.tsx. One day (the date
// the table shows), a whole month, or a custom From–To range (both dates
// inclusive; one row per employee per day for month and range). The backend
// (AttendanceExportFilterSerializer) takes exactly one of `date`,
// `month=YYYY-MM` or `from_date` + `to_date`, plus `branch` / `department`;
// it rejects future months and to-dates and ranges over 31 days, and caps a
// month's end at today. The CSV itself (columns, BOM, date format, location
// columns) is built by the server and saved byte for byte, as web does.

enum AttendanceExportMode { day, month, range }

const kMaxExportRangeDays = 31;

/// Same permission web shows the Export controls for and the backend checks.
const kAttendanceExportPermission = 'attendance.export';

const kAttendanceExportNotPermitted = 'You do not have permission to export attendance.';

String isoDay(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String isoMonth(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Web exportRangeProblem: why a custom range can't be exported yet, or null.
/// Both ends are inclusive, so 1–31 January is 31 days.
String? exportRangeProblem(DateTime? from, DateTime? to, DateTime today) {
  if (from == null || to == null) return 'Select both From and To dates.';
  final f = _dayOnly(from), t = _dayOnly(to);
  if (f.isAfter(t)) return 'From date must be on or before To date.';
  if (t.isAfter(_dayOnly(today))) return 'To date cannot be in the future.';
  // Calendar days counted in UTC so a daylight-saving change can't skew it.
  final days = DateTime.utc(t.year, t.month, t.day).difference(DateTime.utc(f.year, f.month, f.day)).inDays + 1;
  if (days > kMaxExportRangeDays) return 'Range cannot exceed $kMaxExportRangeDays days.';
  return null;
}

/// Why a month can't be exported (the server's own messages), or null. Web's
/// month input stops at the current month.
String? exportMonthProblem(int? year, int? month, DateTime today) {
  if (year == null || month == null) return 'Select a month.';
  if (month < 1 || month > 12 || year < 2000) return 'month must be in YYYY-MM format.';
  if (year > today.year || (year == today.year && month > today.month)) return 'Cannot export a future month.';
  return null;
}

/// Web attendanceExportFilename's branch prefix: a branch-restricted user's
/// own branch ("North Wing" → "North-Wing_"); empty for unrestricted users.
String exportBranchSlug(UserEntity? user) {
  if (user == null || user.isSuperuser || user.permissions.contains('settings.edit')) return '';
  final branch = (user.branch ?? '').trim();
  return branch.isEmpty ? '' : '${branch.replaceAll(RegExp(r'\s+'), '-')}_';
}

/// What to export. [date] null in day mode means "today" (the server's
/// today; the app has always sent no date then).
class AttendanceExportRequest {
  const AttendanceExportRequest.day({this.date, this.branch = '', this.department = ''})
      : mode = AttendanceExportMode.day,
        year = null,
        month = null,
        from = null,
        to = null;

  const AttendanceExportRequest.month({
    required int this.year,
    required int this.month,
    this.branch = '',
    this.department = '',
  })  : mode = AttendanceExportMode.month,
        date = null,
        from = null,
        to = null;

  const AttendanceExportRequest.range({
    required this.from,
    required this.to,
    this.branch = '',
    this.department = '',
  })  : mode = AttendanceExportMode.range,
        date = null,
        year = null,
        month = null;

  final AttendanceExportMode mode;
  final DateTime? date;
  final int? year;
  final int? month;
  final DateTime? from;
  final DateTime? to;
  final String branch;
  final String department;

  /// Why this can't be exported, or null.
  String? problem(DateTime today) => switch (mode) {
        AttendanceExportMode.day => null,
        AttendanceExportMode.month => exportMonthProblem(year, month, today),
        AttendanceExportMode.range => exportRangeProblem(from, to, today),
      };

  /// The query parameters web sends (attendanceExportParams).
  Map<String, String> params() => {
        ...switch (mode) {
          AttendanceExportMode.month => {'month': isoMonth(year!, month!)},
          AttendanceExportMode.range => {'from_date': isoDay(from!), 'to_date': isoDay(to!)},
          AttendanceExportMode.day => {if (date != null) 'date': isoDay(date!)},
        },
        if (branch.isNotEmpty) 'branch': branch,
        if (department.isNotEmpty) 'department': department,
      };

  /// Web attendanceExportFilename: attendance_<branch>_<period>.csv.
  String fileName(DateTime today, {String branchSlug = ''}) {
    final period = switch (mode) {
      AttendanceExportMode.month => isoMonth(year!, month!),
      AttendanceExportMode.range => '${isoDay(from!)}_to_${isoDay(to!)}',
      AttendanceExportMode.day => isoDay(date ?? today),
    };
    return 'attendance_$branchSlug$period.csv';
  }
}

/// True when the CSV has at least one row after the header (the server
/// always sends a BOM and the header, even when nothing matched).
bool csvHasDataRows(List<int> bytes) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final newline = text.indexOf('\n');
  return newline >= 0 && text.substring(newline + 1).trim().isNotEmpty;
}

sealed class AttendanceExportOutcome {
  const AttendanceExportOutcome();
}

/// Saved as [fileName]; [empty] when no employee/day matched the filters.
class AttendanceExportSaved extends AttendanceExportOutcome {
  const AttendanceExportSaved(this.fileName, {required this.empty});
  final String fileName;
  final bool empty;
}

/// The user closed the save dialog; nothing was written.
class AttendanceExportCancelled extends AttendanceExportOutcome {
  const AttendanceExportCancelled();
}

class AttendanceExportFailed extends AttendanceExportOutcome {
  const AttendanceExportFailed(this.message);
  final String message;
}

/// An export was already running; this request was not sent.
class AttendanceExportIgnored extends AttendanceExportOutcome {
  const AttendanceExportIgnored();
}

/// Saves the CSV and returns where, or null when the user cancelled. The
/// app's existing behaviour: the system "save as" dialog via file_picker.
typedef AttendanceCsvSaver = Future<String?> Function(String fileName, Uint8List bytes);

final attendanceCsvSaverProvider = Provider<AttendanceCsvSaver>(
  (ref) => (fileName, bytes) => FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      ),
);

/// "Today" for export defaults and limits (overridable in tests).
final attendanceExportClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final attendanceExporterProvider = Provider<AttendanceExporter>((ref) => AttendanceExporter(ref));

/// Runs an export: permission, validation, one request at a time, save.
/// Never logs or keeps the CSV.
class AttendanceExporter {
  AttendanceExporter(this._ref);
  final Ref _ref;
  bool _busy = false;

  bool get busy => _busy;

  Future<AttendanceExportOutcome> export(AttendanceExportRequest request) async {
    final user = _ref.read(authStateProvider).valueOrNull?.user;
    if (!userHasPermission(user, kAttendanceExportPermission)) {
      return const AttendanceExportFailed(kAttendanceExportNotPermitted);
    }
    final today = _ref.read(attendanceExportClockProvider)();
    final problem = request.problem(today);
    if (problem != null) return AttendanceExportFailed(problem);
    if (_busy) return const AttendanceExportIgnored();
    _busy = true;
    try {
      final List<int> bytes;
      try {
        final p = request.params();
        bytes = await _ref.read(attendanceRepositoryProvider).exportCsv(
              date: p['date'],
              month: p['month'],
              fromDate: p['from_date'],
              toDate: p['to_date'],
              branch: request.branch,
              department: request.department,
            );
      } catch (e) {
        return AttendanceExportFailed(friendlyAttendanceError(e));
      }
      if (bytes.isEmpty) {
        return const AttendanceExportFailed('The server returned an empty file. Please try again.');
      }
      final fileName = request.fileName(today, branchSlug: exportBranchSlug(user));
      final String? path;
      try {
        path = await _ref.read(attendanceCsvSaverProvider)(fileName, Uint8List.fromList(bytes));
      } catch (_) {
        return const AttendanceExportFailed('Could not save the CSV file. Please try again.');
      }
      if (path == null) return const AttendanceExportCancelled();
      return AttendanceExportSaved(fileName, empty: !csvHasDataRows(bytes));
    } finally {
      _busy = false;
    }
  }
}
