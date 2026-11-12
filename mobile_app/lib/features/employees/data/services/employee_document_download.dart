import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../profile/data/models/profile_document_model.dart';
import '../../../profile/data/services/profile_document_viewer.dart' show kDocumentEmptyMessage;

// Opening an uploaded document on the HR Employee Profile (Documents section
// and file-type custom fields), as web DocPreviewModal does:
//
//  - GET /employees/<code>/ returns each document's `file` as a signed
//    Cloudinary download link (views._document_dict → private_download_url,
//    type=authenticated, ~1 hour validity). It is fetched WITHOUT the app's
//    login: web sends no credentials to it (Cloudinary rejects credentialed
//    cross-origin requests), and the app's bearer token must never be sent to
//    another host. A separate plain client is used for it.
//  - A link on the API's own server (absolute on the same origin, or a path
//    such as /media/... from local storage) is fetched through the app's
//    signed-in client, as web routes /api/ paths through its proxy with
//    cookies.
//  - Anything else (another scheme, plain http to another host, user info in
//    the link, a protocol-relative link) is refused.
//
// Error messages never contain the link, a token or the file.

/// Where [raw] must be fetched from, or null when it can't be opened safely.
/// [viaApi] true: the app's signed-in client; false: the plain client.
({Uri uri, bool viaApi})? resolveEmployeeDocumentUrl(String raw, {required String apiBaseUrl}) {
  final text = raw.trim();
  if (text.isEmpty || text.startsWith('//')) return null;
  final base = Uri.parse(apiBaseUrl);
  final parsed = Uri.tryParse(text);
  if (parsed == null) return null;
  if (!parsed.hasScheme) {
    final origin = Uri(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null, path: '/');
    return (uri: origin.resolve(text.startsWith('/') ? text : '/$text'), viaApi: true);
  }
  if (parsed.scheme != 'https' && parsed.scheme != 'http') return null;
  if (parsed.host.isEmpty || parsed.userInfo.isNotEmpty) return null;
  final sameOrigin = parsed.scheme == base.scheme && parsed.host == base.host && parsed.port == base.port;
  if (sameOrigin) return (uri: parsed, viaApi: true);
  // A link to the API itself (e.g. /api/onboarding/custom-file-fields/<id>/,
  // built absolute by the server, perhaps with an internal host or http
  // behind the proxy): as web DocPreviewModal, keep only its path and query
  // and send it to the app's own API address — the login never leaves for
  // the host named in the link.
  final apiPath = base.path.endsWith('/') ? base.path : '${base.path}/';
  if (apiPath.length > 1 && parsed.path.startsWith(apiPath)) {
    final origin = Uri(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null);
    return (uri: origin.replace(path: parsed.path, query: parsed.hasQuery ? parsed.query : null), viaApi: true);
  }
  if (parsed.scheme != 'https') return null;
  return (uri: parsed, viaApi: false);
}

const kDocumentNoFileMessage = "This document has no file to open.";
const kDocumentInvalidLinkMessage = "This document's link isn't valid, so it can't be opened.";
const kDocumentLinkExpiredMessage = "This document's link has expired. Reload the profile and try again.";
const kDocumentSessionExpiredMessage = 'Your session has expired. Please sign in again.';
const kDocumentForbiddenMessage = "You don't have permission to view this document.";
const kDocumentNotFoundMessage = "This document's file couldn't be found. It may have been replaced or removed.";
const kDocumentServerErrorMessage = "The server couldn't send this document. Please try again.";
const kDocumentNetworkMessage = "Couldn't download the document. Check your connection and try again.";

/// A failed download; [message] is safe to show. [linkExpired]: the signed
/// link was refused (401/403 from the file host) — a fresh one may work.
class EmployeeDocumentException extends AppException {
  const EmployeeDocumentException(super.message, {this.linkExpired = false, super.statusCode});
  final bool linkExpired;
}

class EmployeeDocumentDownloader {
  EmployeeDocumentDownloader({required this.api, required this.external, required this.apiBaseUrl});

  /// The app's signed-in client (cookies + bearer, token refresh).
  final Dio api;

  /// A plain client with no login, for the file host's signed links.
  final Dio external;
  final String apiBaseUrl;

  Future<ProfileDocumentFile> download(String rawUrl, {required String fileName}) async {
    if (rawUrl.trim().isEmpty) throw const EmployeeDocumentException(kDocumentNoFileMessage);
    final target = resolveEmployeeDocumentUrl(rawUrl, apiBaseUrl: apiBaseUrl);
    if (target == null) throw const EmployeeDocumentException(kDocumentInvalidLinkMessage);
    final Response<List<int>> res;
    try {
      res = await (target.viaApi ? api : external).getUri<List<int>>(
        target.uri,
        options: Options(responseType: ResponseType.bytes, headers: {'Accept': '*/*'}),
      );
    } on DioException catch (e) {
      throw _failure(e, viaApi: target.viaApi);
    }
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) throw const EmployeeDocumentException(kDocumentEmptyMessage);
    return ProfileDocumentFile(
      bytes: Uint8List.fromList(bytes),
      contentType: res.headers.value(Headers.contentTypeHeader) ?? 'application/octet-stream',
      fileName: fileName,
    );
  }

  EmployeeDocumentException _failure(DioException e, {required bool viaApi}) {
    final status = e.response?.statusCode;
    if (status == null) return const EmployeeDocumentException(kDocumentNetworkMessage);
    if (!viaApi && (status == 401 || status == 403)) {
      return EmployeeDocumentException(kDocumentLinkExpiredMessage, linkExpired: true, statusCode: status);
    }
    return switch (status) {
      401 => const EmployeeDocumentException(kDocumentSessionExpiredMessage, statusCode: 401),
      403 => const EmployeeDocumentException(kDocumentForbiddenMessage, statusCode: 403),
      404 || 410 => EmployeeDocumentException(kDocumentNotFoundMessage, statusCode: status),
      _ => EmployeeDocumentException(kDocumentServerErrorMessage, statusCode: status),
    };
  }

  /// Downloads with [currentUrl]; when the file host refuses that signed link
  /// (expired), asks [freshUrl] once for a new one (from a fresh employee
  /// detail) and tries again. [freshUrl] returning null/empty means the
  /// document is gone.
  Future<ProfileDocumentFile> downloadWithRefresh(
    String currentUrl, {
    required String fileName,
    required Future<String?> Function() freshUrl,
  }) async {
    try {
      return await download(currentUrl, fileName: fileName);
    } on EmployeeDocumentException catch (e) {
      if (!e.linkExpired) rethrow;
    }
    final String? next;
    try {
      next = await freshUrl();
    } catch (_) {
      throw const EmployeeDocumentException(kDocumentLinkExpiredMessage, linkExpired: true);
    }
    if (next == null || next.trim().isEmpty) throw const EmployeeDocumentException(kDocumentNotFoundMessage);
    return download(next, fileName: fileName);
  }
}
