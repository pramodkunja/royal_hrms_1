// Formatting that matches the web app's `toLocaleDateString("en-IN", …)` and
// `formatMoney` output (verified against Node's Intl, ICU en-IN): September is
// "Sept", times are "3:45 pm", amounts group as 12,34,567.89 for INR.

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];

/// "5 Nov 2026", or "05 Nov 2026" with [padDay] (web `day: "2-digit"`).
String formatEnInDate(DateTime d, {bool padDay = false}) =>
    '${padDay ? d.day.toString().padLeft(2, '0') : d.day} ${_months[d.month - 1]} ${d.year}';

/// "5 Nov 2026, 3:45 pm" (web `dateStyle: "medium", timeStyle: "short"`).
String formatEnInDateTime(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '${formatEnInDate(d)}, $h12:$mm ${d.hour < 12 ? 'am' : 'pm'}';
}

/// Web `lib/currency.ts` display symbols.
const _symbols = {
  'INR': '₹',
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'AED': 'د.إ',
  'SAR': 'ر.س',
  'CAD': r'C$',
  'AUD': r'A$',
  'SGD': r'S$',
};

String _group(String digits, {required bool indian}) {
  if (digits.length <= 3) return digits;
  if (!indian) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
      b.write(digits[i]);
    }
    return b.toString();
  }
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

/// Web `formatMoney(amount, code)`: up to 2 decimals (none when whole), INR
/// grouped the Indian way, the currency symbol in front; an Arabic-script
/// symbol gets a space and an LTR mark; an unknown code reads "XYZ 49".
String formatMoney(Object? amount, [String code = 'INR']) {
  final n = double.tryParse('$amount');
  final c = (code.isEmpty ? 'INR' : code).toUpperCase();
  String value;
  if (n == null || n.isNaN) {
    value = 'NaN';
  } else {
    final fixed = n.abs().toStringAsFixed(2);
    final dot = fixed.indexOf('.');
    final whole = _group(fixed.substring(0, dot), indian: code == 'INR');
    final frac = fixed.substring(dot + 1).replaceFirst(RegExp(r'0+$'), '');
    value = '${n < 0 ? '-' : ''}$whole${frac.isEmpty ? '' : '.$frac'}';
  }
  final symbol = _symbols[c];
  if (symbol == null) return '$code $value';
  return RegExp('[؀-ۿ]').hasMatch(symbol) ? '‎$symbol $value' : '$symbol$value';
}
