import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../features/employees/data/services/employee_document_download.dart' show kDocumentLinkExpiredMessage;
import '../../features/employees/presentation/widgets/employee_file_viewer.dart' show openEmployeeFileInApp;
import '../../features/profile/data/services/profile_document_viewer.dart' show kDocumentUnsupportedMessage;

// Opening a request's attached document (Task 67), matching web:
//  - Where web shows the file inside the app (DocPreviewModal — Team
//    Approvals attachments, Document Center preview), the app's viewer is
//    used (openEmployeeFileInApp: PDF / JPG / PNG; the login only ever goes
//    to the API's own server, never to the file host; temporary copies are
//    deleted when the viewer closes). Any other file type opens outside the
//    app, as web's "Open" does.
//  - Where web uses a plain link that opens in a new tab (leave, expense,
//    WFH and separation documents, Document Center download), the link is
//    handed to the device's browser.
//
// The links are short-lived signed file-host links (backend
// core/storage.AuthenticatedRawMediaCloudinaryStorage) or the API's own
// token-signed document link; nothing here adds credentials to them.

/// Opens a URL outside the app; replaceable in tests.
final externalLinkLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

const kLinkOpenFailedMessage = "Couldn't open this document. Please try again.";
const kRequestDocumentExpiredMessage = "This document's link has expired. Close and reopen the request, then try again.";

/// Web fileNameFromUrl (approvals RequestDetailDrawer): the last path
/// segment, decoded — used to tell an image from a PDF.
String documentFileNameFromUrl(String url) {
  final uri = Uri.tryParse(url);
  final segments = uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const <String>[];
  if (segments.isEmpty) return 'file';
  try {
    return Uri.decodeComponent(segments.last);
  } catch (_) {
    return segments.last;
  }
}

void _snack(BuildContext context, String message) {
  // A new problem replaces the one still on screen instead of queueing behind it.
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: AppColors.error,
    behavior: SnackBarBehavior.floating,
  ));
}

/// Opens [url] in the device's browser / viewer (web `<a target="_blank">`).
/// No canLaunchUrl check first: on Android 11+ it answers false for web links
/// unless the manifest declares them, which left these buttons doing
/// nothing. Only http(s) links are opened. Shows [failureMessage] when the
/// link can't be opened.
Future<void> openDocumentLinkExternally(
  BuildContext context,
  WidgetRef ref,
  String? url, {
  String failureMessage = kLinkOpenFailedMessage,
}) async {
  final uri = Uri.tryParse((url ?? '').trim());
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) {
    if (context.mounted) _snack(context, failureMessage);
    return;
  }
  bool opened;
  try {
    opened = await ref.read(externalLinkLauncherProvider)(uri);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) _snack(context, failureMessage);
}

/// Shows [url] in the app's document viewer (web DocPreviewModal); a file
/// type the viewer can't show opens outside the app instead. Failures
/// (expired link, no permission, missing file, network) are shown as a
/// message.
Future<void> previewDocumentInApp(
  BuildContext context,
  WidgetRef ref, {
  required String url,
  required String title,
  String? fileName,
}) async {
  final name = (fileName ?? '').trim().isNotEmpty ? fileName!.trim() : documentFileNameFromUrl(url);
  final message = await openEmployeeFileInApp(
    context,
    ref,
    id: url.hashCode & 0x7fffffff,
    url: url,
    fileName: name,
    title: title,
  );
  if (message == null || !context.mounted) return;
  if (message == kDocumentUnsupportedMessage) {
    await openDocumentLinkExternally(context, ref, url);
    return;
  }
  _snack(context, message == kDocumentLinkExpiredMessage ? kRequestDocumentExpiredMessage : message);
}
