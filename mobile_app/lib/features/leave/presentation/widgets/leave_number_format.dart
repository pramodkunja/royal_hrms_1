/// A leave day count as web shows it (a JS number printed as-is): whole
/// values without a decimal point ("3", not "3.0"), fractions kept ("2.5",
/// "0.5", never rounded to "3" / "1"), negatives kept ("-1.5"). The backend
/// stores days to one decimal place; any binary floating-point noise from
/// client-side arithmetic (e.g. 12.0 − 9.7 = 2.3000000000000007) is removed
/// by rounding to two places before printing, so it reads "2.3".
/// Null reads "0", as web's `Number(undefined ?? 0)`-style fallbacks do.
String formatLeaveDays(num? value) {
  if (value == null || value.isNaN) return '0';
  final v = (value * 100).round() / 100;
  if (v == v.truncateToDouble()) return v.toInt().toString();
  var s = v.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
