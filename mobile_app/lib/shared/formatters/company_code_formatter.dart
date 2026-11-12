import 'package:flutter/services.dart';

// Login Company Code: shown and sent in upper case. Companies are created with
// an upper-case code (tenants/services.py: company_code.strip().upper()) and
// login matches it case-insensitively (Client company_code__iexact), so this
// only normalizes what the user sees and what is sent — it never changes
// which company matches.

/// [value] with ASCII a–z changed to A–Z; every other character is kept.
/// The length never changes, so text positions stay valid.
String upperCaseAscii(String value) {
  final units = value.codeUnits;
  var changed = false;
  final out = List<int>.of(units);
  for (var i = 0; i < out.length; i++) {
    final c = out[i];
    if (c >= 0x61 && c <= 0x7A) {
      out[i] = c - 0x20;
      changed = true;
    }
  }
  return changed ? String.fromCharCodes(out) : value;
}

/// The company code as sent to the server: trimmed and in upper case.
String normalizeCompanyCode(String value) => upperCaseAscii(value.trim());

/// Upper-cases ASCII letters as they are typed or pasted. The cursor,
/// selection and keyboard composing range are kept exactly where they were
/// (the text length doesn't change).
class UpperCaseAsciiFormatter extends TextInputFormatter {
  const UpperCaseAsciiFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final upper = upperCaseAscii(newValue.text);
    if (identical(upper, newValue.text)) return newValue;
    return newValue.copyWith(text: upper);
  }
}
