import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../employees/presentation/providers/employee_providers.dart' show employeeDocumentExternalDioProvider;

// SVG company logos (web shows them in an <img>; Company Information accepts
// SVG uploads). The saved logo is the company's absolute media URL
// (`CompanySerializer.logo_url`) — fetched once through the app's LOGIN-FREE
// file client so the app's token never goes to another host. The bytes stay in
// memory (never written to disk); the link is never logged or shown; an
// oversized, non-https, unreachable or non-SVG response simply isn't drawn —
// the logo icon shows instead, as an <img> that fails to load.

/// Largest SVG fetched — the same ceiling the upload enforces (5 MB).
const kCompanyLogoSvgMaxBytes = 5 * 1024 * 1024;

/// Whether [url] points at an SVG, by its path (query and fragment ignored).
bool isSvgUrl(String url) => (Uri.tryParse(url)?.path.toLowerCase() ?? '').endsWith('.svg');

/// Whether [bytes] open like an SVG document (an `<svg` root, optionally after
/// an XML declaration, comments or a doctype) — checked before any parsing so
/// an HTML error page or an image served under a .svg link is never parsed.
bool looksLikeSvg(Uint8List bytes) {
  if (bytes.isEmpty) return false;
  final head = utf8.decode(bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes, allowMalformed: true);
  return RegExp(r'<svg[\s>/]', caseSensitive: false).hasMatch(head);
}

/// Downloads [url] to SVG bytes, or null. Tests override it.
final companyLogoSvgLoaderProvider = Provider<Future<Uint8List?> Function(String url)>((ref) => (url) async {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
      try {
        final res = await ref.read(employeeDocumentExternalDioProvider).getUri<List<int>>(
              uri,
              options: Options(responseType: ResponseType.bytes),
            );
        final data = res.data;
        if (data == null || data.isEmpty || data.length > kCompanyLogoSvgMaxBytes) return null;
        final bytes = Uint8List.fromList(data);
        return looksLikeSvg(bytes) ? bytes : null;
      } catch (_) {
        return null; // never surface the link in an error
      }
    });

/// The SVG behind [url] as bytes (null when absent or unusable).
final companyLogoSvgProvider = FutureProvider.autoDispose.family<Uint8List?, String>((ref, url) {
  if (url.isEmpty) return Future.value(null);
  return ref.read(companyLogoSvgLoaderProvider)(url);
});
