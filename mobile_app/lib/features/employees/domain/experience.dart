/// Web `experienceFrom` (frontend app/dashboard/employees/_data.ts), ported
/// exactly: whole months from [isoDate] (yyyy-MM-dd, the date of joining) to
/// [now], minus one if today's day-of-month is before the joining day,
/// floored at 0; printed "N year(s) M month(s)", "0 months" when under a
/// month, "—" when there's no date. Same input, same arithmetic — no new
/// rule (HO-29, Phase C3).
String experienceFrom(String isoDate, {DateTime? now}) {
  final parts = isoDate.split('-');
  if (isoDate.isEmpty || parts.length < 3) return '—';
  final y = int.tryParse(parts[0]), m = int.tryParse(parts[1]), d = int.tryParse(parts[2].substring(0, parts[2].length.clamp(0, 2)));
  if (y == null || m == null || d == null) return '—';
  final n = now ?? DateTime.now();
  var months = (n.year - y) * 12 + (n.month - m);
  if (n.day < d) months -= 1;
  if (months < 0) months = 0;
  final years = months ~/ 12, rem = months % 12;
  final yp = years > 0 ? '$years year${years > 1 ? 's' : ''}' : '';
  final mp = rem > 0 ? '$rem month${rem > 1 ? 's' : ''}' : '';
  final s = [yp, mp].where((e) => e.isNotEmpty).join(' ');
  return s.isEmpty ? '0 months' : s;
}
