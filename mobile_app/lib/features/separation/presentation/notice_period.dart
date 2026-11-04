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

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

/// A YYYY-MM-DD date as "4 Nov 2026" (read as a local calendar date so it
/// never shifts a day), or "—" when missing or unreadable.
String formatNoticeDate(String? value) {
  if (value == null || value.isEmpty) return '—';
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (m == null) return '—';
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return '—';
  return '${int.parse(m.group(3)!)} ${_months[month - 1]} ${m.group(1)}';
}
