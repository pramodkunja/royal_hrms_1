// Shift timing maths, exactly the backend's (apps/attendance/serializers.py
// _compute_net_hours and WorkingHoursPolicy.standard_working_hours): a shift
// whose end time is at or before its start time ends the NEXT day, so its
// length is (end + 24h - start); the working time is that minus the break
// (never below zero).

/// Minutes since midnight of "HH:MM" or "HH:MM:SS"; null when unparseable.
int? shiftClockMinutes(String? v) {
  if (v == null) return null;
  final p = v.trim().split(':');
  if (p.length < 2) return null;
  final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

/// Backend: end <= start means the shift runs past midnight (+1 day).
/// Null when either time is missing.
int? shiftLengthMinutes(String? start, String? end) {
  final s = shiftClockMinutes(start), e = shiftClockMinutes(end);
  if (s == null || e == null) return null;
  return e <= s ? e + 24 * 60 - s : e - s;
}

/// True when the shift ends the next day. An equal start and end is rejected
/// by the backend ("cannot be the same"), so it is not called overnight here.
bool isOvernightShift(String? start, String? end) {
  final s = shiftClockMinutes(start), e = shiftClockMinutes(end);
  return s != null && e != null && e < s;
}

/// Shift length minus the break, never below zero (backend net hours).
int? shiftNetMinutes(String? start, String? end, int breakMinutes) {
  final len = shiftLengthMinutes(start, end);
  if (len == null) return null;
  final net = len - breakMinutes;
  return net < 0 ? 0 : net;
}

/// 540 -> "9h", 510 -> "8h 30m", 45 -> "45m".
String formatShiftDuration(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
