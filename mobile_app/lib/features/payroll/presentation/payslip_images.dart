import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../employees/presentation/id_card/id_card_pdf.dart' show isEmbeddableImage;
import '../../employees/presentation/providers/employee_providers.dart' show employeeDocumentExternalDioProvider;

// Images a payslip shows — the company logo (standard letterhead) and the
// wage-slip stamp. Web puts both in an <img src>, so the browser fetches the
// link directly with no login: the logo is the company's absolute media URL
// (`CompanySerializer.logo_url`) and the stamp a short-lived signed link
// (`stamp_url`, EmployeePayslipSerializer).
//
// Mobile does the same through the app's LOGIN-FREE file client, so the app's
// token never goes to another host. The bytes are held in memory only (never
// written to disk), the link is never logged or shown, and anything that
// can't be fetched, is too large, or isn't an image simply isn't drawn —
// as an <img> that fails to load.

/// Largest image fetched (a logo or stamp is a few hundred KB at most).
const kPayslipImageMaxBytes = 3 * 1024 * 1024;

/// Downloads [url] to bytes, or null. Tests override it.
final payslipImageLoaderProvider = Provider<Future<Uint8List?> Function(String url)>((ref) => (url) async {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
      try {
        final res = await ref.read(employeeDocumentExternalDioProvider).getUri<List<int>>(
              uri,
              options: Options(responseType: ResponseType.bytes),
            );
        final data = res.data;
        if (data == null || data.isEmpty || data.length > kPayslipImageMaxBytes) return null;
        final bytes = Uint8List.fromList(data);
        return isEmbeddableImage(bytes) ? bytes : null;
      } catch (_) {
        return null; // never surface the link in an error
      }
    });

/// The image behind [url] as bytes (null when absent or unavailable).
final payslipImageProvider = FutureProvider.autoDispose.family<Uint8List?, String>((ref, url) {
  if (url.isEmpty) return Future.value(null);
  return ref.read(payslipImageLoaderProvider)(url);
});
