import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../wfh/domain/entities/wfh_entity.dart';
import '../../../wfh/presentation/providers/wfh_providers.dart';

/// Attendance modes the clock-in flows send (AttendancePunch.attendance_mode).
const kAttendanceModeOffice = 'office';
const kAttendanceModeWfh = 'wfh';

/// The device's current time. Overridable in tests.
final attendanceClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

/// yyyy-MM-dd for a local calendar date (web's localDateString).
String _localDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Web's ClockWidget rule (frontend/app/dashboard/my-attendance/_components/
/// ClockWidget.tsx): 'wfh' when today (device-local date) falls inside one of
/// the employee's own APPROVED work-from-home requests, start and end dates
/// inclusive; otherwise 'office'. Pending, rejected, cancelled, ended and
/// future requests never qualify. The server validates the punch either way
/// (its geofence strategy depends on the mode); this only picks the path.
String attendanceModeFor(List<WfhRequestEntity> requests, DateTime now) {
  final today = _localDate(now);
  final onWfh = requests.any((r) =>
      r.status == 'approved' &&
      r.startDate.compareTo(today) <= 0 &&
      today.compareTo(r.endDate) <= 0);
  return onWfh ? kAttendanceModeWfh : kAttendanceModeOffice;
}

/// Today's attendance mode for the signed-in employee, from GET
/// /wfh/requests/?status=approved (the same lookup web uses). Any failure
/// falls back to 'office', as web does when its request list is unavailable.
final todayAttendanceModeProvider =
    FutureProvider.autoDispose<String>((ref) async {
  try {
    final requests = await ref
        .read(wfhRepositoryProvider)
        .getWfhRequests(status: 'approved');
    return attendanceModeFor(requests, ref.read(attendanceClockProvider)());
  } catch (_) {
    return kAttendanceModeOffice;
  }
});
