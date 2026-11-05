// Employee dashboard "Upcoming Holidays" — web
// components/dashboard/employee/EmpUpcomingHolidays.tsx over
// GET /leave/holidays/ with no parameters (HolidayListCreateView): every
// holiday the caller may see — company-wide ones plus, for a
// branch-restricted user, their own branch's (an unrestricted user sees all
// branches) — across all years, active and inactive. The card keeps active
// holidays dated today or later, in date order, and shows the first three.
//
// The server's `date` is "YYYY-MM-DD", `day` its short weekday ("Mon") and
// `holiday_type_display` "National" / "Regional" / "Company".

const kUpcomingHolidayCount = 3;

final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// en-IN short months, as web's toLocaleDateString("en-IN") prints them
/// (September is "Sept").
const _enInMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class DashboardHoliday {
  const DashboardHoliday({
    required this.id,
    required this.name,
    required this.date,
    required this.day,
    required this.typeDisplay,
    required this.isActive,
  });

  final String id;
  final String name;

  /// Calendar date (local midnight).
  final DateTime date;

  /// Server weekday ("Mon"), or worked out from [date] when missing.
  final String day;
  final String typeDisplay;
  final bool isActive;

  /// Null when the entry has no usable date (it can't be placed in time).
  static DashboardHoliday? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = _isoDate.firstMatch('${raw['date'] ?? ''}'.trim());
    if (m == null) return null;
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    final date = DateTime(y, mo, d);
    if (date.year != y || date.month != mo || date.day != d) return null; // e.g. 2026-02-30
    String text(Object? v) => v is String ? v.trim() : '';
    final day = text(raw['day']);
    return DashboardHoliday(
      id: '${raw['id'] ?? ''}',
      name: text(raw['name']),
      date: date,
      day: day.isNotEmpty ? day : _weekdays[date.weekday - 1],
      typeDisplay: text(raw['holiday_type_display']),
      // Web keeps only `is_active` truthy entries.
      isActive: raw['is_active'] == true,
    );
  }

  /// `data.holidays` of the list response; unusable entries are skipped.
  static List<DashboardHoliday> listFrom(Object? data) {
    final list = data is Map ? data['holidays'] : null;
    if (list is! List) return const [];
    return [
      for (final h in list.map(tryParse))
        if (h != null) h
    ];
  }

  /// Web fmtDate(...).split(" ")[0]: two-digit day, "05".
  String get dayOfMonth => date.day.toString().padLeft(2, '0');

  /// Web's month line (uppercased by CSS): "NOV", "SEPT".
  String get monthShort => _enInMonths[date.month - 1].toUpperCase();

  /// Web "<day> · <type>", without a dangling separator.
  String get subtitle => [day, typeDisplay].where((s) => s.isNotEmpty).join(' · ');

  /// Whole calendar days from [localDate] to this holiday.
  int daysFrom(DateTime localDate) => DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(localDate.year, localDate.month, localDate.day))
      .inDays;

  /// Web badge from the device-local date (web daysUntil works from local
  /// midnight): "Today", "In 3d" — and "In -1d" for a holiday the UTC date
  /// still counts but the local date has passed, exactly as web shows it.
  String badge(DateTime localDate) {
    final n = daysFrom(localDate);
    return n == 0 ? 'Today' : 'In ${n}d';
  }
}

/// The two calendar dates web's card works from: the UTC date decides which
/// holidays are upcoming (`new Date().toISOString().slice(0, 10)`), the
/// device-local date drives the badge (`daysUntil`). They differ when the
/// local and UTC days differ — in India from 00:00 to 05:29.
class HolidayDayRefs {
  const HolidayDayRefs({required this.utcDate, required this.localDate});

  /// Calendar dates only (year, month, day).
  final DateTime utcDate;
  final DateTime localDate;

  /// The device's own time zone.
  factory HolidayDayRefs.at(DateTime now) {
    final u = now.toUtc(), l = now.toLocal();
    return HolidayDayRefs(utcDate: DateTime(u.year, u.month, u.day), localDate: DateTime(l.year, l.month, l.day));
  }

  /// A fixed UTC offset (e.g. India, +05:30), independent of the device.
  factory HolidayDayRefs.withOffset(DateTime instant, Duration offset) {
    final u = instant.toUtc(), l = u.add(offset);
    return HolidayDayRefs(utcDate: DateTime(u.year, u.month, u.day), localDate: DateTime(l.year, l.month, l.day));
  }
}

int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Web's selection: active, dated on or after the UTC date, by date
/// (holidays on the same date keep the server's order, as web's stable sort
/// does), first three.
List<DashboardHoliday> upcomingHolidays(List<DashboardHoliday> all, HolidayDayRefs refs) {
  final from = _dayKey(refs.utcDate);
  final indexed = [
    for (var i = 0; i < all.length; i++)
      if (all[i].isActive && _dayKey(all[i].date) >= from) (i, all[i]),
  ]..sort((a, b) {
      final c = _dayKey(a.$2.date).compareTo(_dayKey(b.$2.date));
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed.take(kUpcomingHolidayCount)) e.$2];
}
