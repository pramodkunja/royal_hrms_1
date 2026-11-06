import 'package:flutter/foundation.dart' show visibleForTesting;

// Employee notice period helpers — mirrors web frontend/lib/noticePeriod.ts.
// The notice period is assigned by HR in Settings → Notice Period, in
// calendar days. The expected last working day of a resignation is the
// request date + the notice period: an expectation, not the approved date.

/// Default notice period when the employee has none assigned (web
/// SeparationFormModal's initial value).
const kDefaultNoticePeriodDays = 30;

/// Request date + [days] calendar days, or null when either is missing.
DateTime? expectedLastWorkingDay(DateTime? requestDate, int? days) {
  if (requestDate == null || days == null) return null;
  return DateTime(requestDate.year, requestDate.month, requestDate.day + days);
}

/// "Not assigned" / "1 day" / "N days".
String formatNoticePeriod(int? days) {
  if (days == null) return 'Not assigned';
  return '$days day${days == 1 ? '' : 's'}';
}

/// en-GB short months, as web's toLocaleDateString("en-GB") prints them
/// (September is "Sept").
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];

final _dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _dateTime = RegExp(r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}');

/// Tests only: the viewer's UTC offset at a given instant, instead of the
/// device's time zone.
@visibleForTesting
Duration Function(DateTime utcInstant)? debugNoticeDateOffset;

/// Web formatNoticeDate: "4 Nov 2026", or "—" when missing or unreadable.
/// A YYYY-MM-DD date is a calendar date (never shifted by time zone); a
/// timestamp such as approved_at ("2026-10-30T23:36:02+05:30") is shown on
/// the viewer's own calendar day, as web's `new Date(value)` does.
String formatNoticeDate(String? value) {
  if (value == null || value.isEmpty) return '—';
  DateTime? day;
  final m = _dateOnly.firstMatch(value);
  if (m != null) {
    // Like web's new Date(y, m - 1, d): an out-of-range day rolls over.
    day = DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  } else if (_dateTime.hasMatch(value)) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      if (!parsed.isUtc) {
        day = parsed; // no offset: local wall time, as in JavaScript
      } else {
        final offset = debugNoticeDateOffset;
        day = offset != null ? parsed.add(offset(parsed)) : parsed.toLocal();
      }
    }
  }
  if (day == null) return '—';
  return '${day.day} ${_months[day.month - 1]} ${day.year}';
}

/// "Notice completed" / "1 day remaining" / "N days remaining" / "—"
/// (web noticeRemainingLabel). The day count is the server's.
String noticeRemainingLabel(int? daysRemaining, String? status) {
  if (status == 'completed') return 'Notice completed';
  if (daysRemaining == null) return '—';
  return '$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} remaining';
}
