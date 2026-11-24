import '../../../data/models/company_model.dart';

/// Port of web `buildEmailPreview` (frontend/lib/emailPreview.ts): the email
/// body inside the company header (logo or name) and footer (website | address).
///
/// The TEMPLATE BODY is the email's own HTML and goes in unescaped, exactly as
/// on web (web shows it in a script-less `sandbox="allow-same-origin"` iframe).
/// The company fields are HTML-escaped, and the logo is used only when its
/// scheme is https, http or data:image. On top of web's wrapper this adds a
/// viewport meta, a Content-Security-Policy that allows no script, frame, form
/// or external stylesheet, and CSS so wide tables, long URLs and big images
/// wrap/shrink instead of forcing sideways scrolling.
///
/// `{PLACEHOLDERS}` stay as typed: web does not fill them in this preview
/// either (see report: its `preview` key is never in the GET response).
String buildEmailPreviewHtml(String body, {CompanyModel? company}) {
  String clean(String? v) => (v ?? '').trim();

  final rawName = clean(company?.companyName);
  final name = escapeHtml(rawName.isEmpty ? '[Company]' : rawName);
  final logo = safePreviewLogoUrl(company?.logoUrl);
  final website = escapeHtml(clean(company?.website));
  final address =
      escapeHtml([company?.address, company?.city, company?.state].map(clean).where((p) => p.isNotEmpty).join(', '));
  final footerParts = [website, address].where((p) => p.isNotEmpty).toList();
  final footer = footerParts.isEmpty ? name : footerParts.join(' &nbsp;|&nbsp; ');

  final logoHtml = logo != null
      ? '<img src="${escapeHtml(logo)}" alt="$name" '
          'style="max-height:70px;max-width:220px;object-fit:contain;" />'
      : '<span style="font-size:18px;font-weight:700;color:#1a1a2e;">$name</span>';

  return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https: http: data:; style-src 'unsafe-inline'; font-src https: data:">
<style>
  html, body { margin:0; background:#f4f4f7; font-family:Arial,Helvetica,sans-serif; }
  * { overflow-wrap:anywhere; word-break:break-word; box-sizing:border-box; }
  img { max-width:100%; height:auto; }
  table { max-width:100%; }
  pre { white-space:pre-wrap; }
</style>
</head>
<body>
<div style="background:#f4f4f7;padding:24px 0;">
  <div style="max-width:600px;margin:0 auto;background:#fff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);">

    <div style="background:#fff;text-align:center;padding:24px 40px 18px;border-bottom:3px solid #4f46e5;">
      $logoHtml
    </div>

    <div style="padding:28px 36px;color:#333;line-height:1.7;font-size:15px;">
      $body
    </div>

    <div style="background:#f8f8fb;text-align:center;padding:14px 24px;font-size:12px;color:#888;border-top:1px solid #eee;">
      $footer
    </div>

  </div>
</div>
</body>
</html>''';
}

/// Escapes text for HTML content and double/single-quoted attributes.
String escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// The logo URL when its scheme is https, http or data:image; otherwise null.
String? safePreviewLogoUrl(String? url) {
  final u = (url ?? '').trim();
  if (u.isEmpty) return null;
  final lower = u.toLowerCase();
  if (lower.startsWith('https://') || lower.startsWith('http://') || lower.startsWith('data:image/')) return u;
  return null;
}

final _blockTags =
    RegExp(r'</?(p|div|tr|ul|ol|h[1-6]|table|blockquote|section|article|header|footer)\b[^>]*>', caseSensitive: false);
final _entity = RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);');

const _named = {
  'nbsp': ' ',
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'zwnj': '',
  'zwj': '',
  'copy': '©',
  'reg': '®',
  'ndash': '–',
  'mdash': '—',
  'hellip': '…',
  'rsquo': '’',
  'lsquo': '‘',
  'rdquo': '”',
  'ldquo': '“',
  'bull': '•',
};

String _decodeEntities(String s) => s.replaceAllMapped(_entity, (m) {
      final e = m.group(1)!;
      if (e.startsWith('#x') || e.startsWith('#X')) {
        final code = int.tryParse(e.substring(2), radix: 16);
        return code == null || code > 0x10ffff ? m.group(0)! : String.fromCharCode(code);
      }
      if (e.startsWith('#')) {
        final code = int.tryParse(e.substring(1));
        return code == null || code > 0x10ffff ? m.group(0)! : String.fromCharCode(code);
      }
      return _named[e.toLowerCase()] ?? m.group(0)!;
    });

/// A readable plain-text version of an email body: script/style dropped, block
/// tags and `<br>` become line breaks, list items get a bullet, tags removed,
/// entities decoded, and runs of spaces / blank lines collapsed.
String emailPreviewPlainText(String html) {
  var s = html
      .replaceAll(RegExp(r'<(script|style)\b[^>]*>.*?</\1\s*>', caseSensitive: false, dotAll: true), '')
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li\b[^>]*>', caseSensitive: false), '\n• ')
      .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</t[dh]\s*>', caseSensitive: false), '  ')
      .replaceAll(_blockTags, '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '');
  s = _decodeEntities(s);
  s = s
      .replaceAll('\r', '')
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'[ \t ]+'), ' ').trim())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return s;
}
