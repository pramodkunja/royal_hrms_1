import 'dart:io';
import 'dart:typed_data';

import '../../../../core/network/api_client.dart';
import '../models/profile_document_model.dart';

// Viewing the employee's own profile documents inside the app (Phase 11.4
// step 4). Nothing is handed to another app: no content URIs, no FileProvider
// grants, no "open with".
//
// The backend's file link needs the user's login, so the file is downloaded
// through the app's signed-in client (ProfileRemoteDataSource
// .downloadMyDocument: cookie + Bearer, with the usual token refresh/retry)
// and checked to be a real PDF, JPEG or PNG. Then:
//  - JPG/PNG: shown straight from the downloaded bytes; nothing is written.
//  - PDF: written to <temp>/profile_docs/doc-<id>.pdf (no names, tokens or
//    URLs in the path) and opened read-only by pdfx with openFile. (pdfx's
//    openData would leave its own undeleted copy in the Android cache.)
//
// Temporary files are deleted (ProfileDocumentTempStore):
//  - when the viewer closes (ProfileDocumentReady.release);
//  - before each new view;
//  - at app start, and when the signed-in user goes away (sign-out or an
//    expired session) — see profileDocumentSessionCleanupProvider;
//  - at once when a PDF can't be written.
// pdfx's own page-image folder (pdf_renderer_cache: in the cache on Android,
// in Documents on iOS) is cleared at the same points. The in-app pinch viewer
// renders pages to textures, so it normally writes nothing there.

enum DocumentKind {
  pdf('application/pdf', 'pdf'),
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png');

  const DocumentKind(this.mime, this.extension);
  final String mime;
  final String extension;
}

const kDocumentEmptyMessage = "This document is empty and can't be opened.";
const kDocumentUnsupportedMessage = "This file type can't be opened. Only PDF, JPG and PNG documents are supported.";
const kDocumentOpenFailedMessage = "The document couldn't be opened. Please try again.";

const _genericContentTypes = {'', 'application/octet-stream', 'binary/octet-stream', 'application/x-download'};

/// The supported kind named by a content type, or null.
DocumentKind? documentKindFromContentType(String? contentType) {
  final ct = (contentType ?? '').split(';').first.trim().toLowerCase();
  return switch (ct) {
    'application/pdf' => DocumentKind.pdf,
    'image/jpeg' || 'image/jpg' || 'image/pjpeg' => DocumentKind.jpeg,
    'image/png' => DocumentKind.png,
    _ => null,
  };
}

/// The file name's extension in lower case, or null when it has none.
String? _extensionOf(String? fileName) {
  final name = (fileName ?? '').trim();
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  return name.substring(dot + 1).toLowerCase();
}

/// The supported kind named by a file extension, or null.
DocumentKind? documentKindFromFileName(String? fileName) => switch (_extensionOf(fileName)) {
      'pdf' => DocumentKind.pdf,
      'jpg' || 'jpeg' => DocumentKind.jpeg,
      'png' => DocumentKind.png,
      _ => null,
    };

/// The kind the file's own bytes show (its signature), or null.
DocumentKind? documentKindFromBytes(Uint8List b) {
  bool starts(List<int> sig) {
    if (b.length < sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[i] != sig[i]) return false;
    }
    return true;
  }

  if (starts(const [0x25, 0x50, 0x44, 0x46, 0x2D])) return DocumentKind.pdf; // %PDF-
  if (starts(const [0xFF, 0xD8, 0xFF])) return DocumentKind.jpeg;
  if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return DocumentKind.png;
  return null;
}

/// The kind to open the file as, or null when it must be refused:
///  - a specific content type that isn't PDF/JPEG/PNG;
///  - any file name whose extension isn't pdf/jpg/jpeg/png;
///  - content type and extensions naming different kinds;
///  - bytes that aren't a PDF, JPEG or PNG, or not the kind named.
/// A generic content type (Cloudinary raw files often arrive as
/// application/octet-stream) and names without an extension are neutral.
DocumentKind? resolveDocumentKind({
  required String? contentType,
  required List<String?> fileNames,
  required Uint8List bytes,
}) {
  final named = <DocumentKind>{};
  final ct = (contentType ?? '').split(';').first.trim().toLowerCase();
  if (!_genericContentTypes.contains(ct)) {
    final k = documentKindFromContentType(ct);
    if (k == null) return null;
    named.add(k);
  }
  for (final name in fileNames) {
    if (_extensionOf(name) == null) continue;
    final k = documentKindFromFileName(name);
    if (k == null) return null;
    named.add(k);
  }
  if (named.length > 1) return null;
  final actual = documentKindFromBytes(bytes);
  if (actual == null) return null;
  if (named.isNotEmpty && named.single != actual) return null;
  return actual;
}

sealed class DocumentViewOutcome {
  const DocumentViewOutcome();
}

/// Ready to show in the app. Call [release] when the viewer closes.
class ProfileDocumentReady extends DocumentViewOutcome {
  ProfileDocumentReady({
    required this.documentId,
    required this.kind,
    Uint8List? imageBytes,
    this.pdfPath,
    required Future<void> Function() release,
  })  : _imageBytes = imageBytes,
        _release = release;

  final int documentId;
  final DocumentKind kind;

  Uint8List? _imageBytes;

  /// JPG/PNG bytes, shown from memory (null for a PDF, and after [release]).
  Uint8List? get imageBytes => _imageBytes;

  /// The temporary PDF file (null for an image).
  final String? pdfPath;

  final Future<void> Function() _release;
  bool _released = false;

  bool get isPdf => kind == DocumentKind.pdf;

  bool get isReleased => _released;

  /// Drops the in-memory image and deletes the temporary copy, if any.
  /// Safe to call more than once.
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _imageBytes = null;
    await _release();
  }
}

/// Not ready; [message] is safe to show (no tokens, URLs or paths).
class DocumentViewFailed extends DocumentViewOutcome {
  final String message;
  const DocumentViewFailed(this.message);
}

/// The app-private folders that may hold copies of profile documents.
class ProfileDocumentTempStore {
  ProfileDocumentTempStore({required this.tempRoot, this.documentsRoot});

  /// The app's temporary (cache) folder.
  final Future<Directory> Function() tempRoot;

  /// The app's documents folder (pdfx keeps its page images here on iOS).
  final Future<Directory> Function()? documentsRoot;

  static const folderName = 'profile_docs';
  static const pdfxCacheFolder = 'pdf_renderer_cache';

  String _join(Directory d, String name) => '${d.path}${Platform.pathSeparator}$name';

  /// A fresh path for document [documentId]'s PDF (folder created).
  Future<File> pdfFileFor(int documentId) async {
    final dir = Directory(_join(await tempRoot(), folderName));
    await dir.create(recursive: true);
    return File(_join(dir, 'doc-$documentId.pdf'));
  }

  Future<void> deleteFile(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Busy or already gone: the next cleanup tries again.
    }
  }

  Future<void> _emptyFolder(Future<Directory> Function()? root, String name) async {
    if (root == null) return;
    try {
      final dir = Directory(_join(await root(), name));
      if (!await dir.exists()) return;
      await for (final e in dir.list(followLinks: false)) {
        try {
          await e.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {
      // No folder, or the platform can't provide one: nothing to clear.
    }
  }

  /// Deletes every temporary profile document and any pdfx page images.
  /// Only call while no document viewer is open. Never throws.
  Future<void> clearAll() async {
    await _emptyFolder(tempRoot, folderName);
    await _emptyFolder(tempRoot, pdfxCacheFolder);
    await _emptyFolder(documentsRoot, pdfxCacheFolder);
  }
}

class ProfileDocumentViewer {
  ProfileDocumentViewer({required this.download, required this.store});

  final Future<ProfileDocumentFile> Function(int documentId) download;
  final ProfileDocumentTempStore store;

  /// Downloads document [documentId] with the user's login and prepares it
  /// for the in-app viewer. [knownFileName] (from the document list) is
  /// checked too. The previous viewer has closed by now, so any earlier
  /// copies are cleared first.
  Future<DocumentViewOutcome> load(int documentId, {String? knownFileName}) async {
    await store.clearAll();
    final ProfileDocumentFile file;
    try {
      file = await download(documentId);
    } catch (e) {
      return DocumentViewFailed(userFriendlyMessage(e));
    }
    if (file.bytes.isEmpty) return const DocumentViewFailed(kDocumentEmptyMessage);
    final kind = resolveDocumentKind(
      contentType: file.contentType,
      fileNames: [file.fileName, knownFileName],
      bytes: file.bytes,
    );
    if (kind == null) return const DocumentViewFailed(kDocumentUnsupportedMessage);

    if (kind != DocumentKind.pdf) {
      return ProfileDocumentReady(
        documentId: documentId,
        kind: kind,
        imageBytes: file.bytes,
        release: () async {},
      );
    }

    File? target;
    try {
      target = await store.pdfFileFor(documentId);
      await target.writeAsBytes(file.bytes, flush: true);
    } catch (_) {
      if (target != null) await store.deleteFile(target);
      return const DocumentViewFailed(kDocumentOpenFailedMessage);
    }
    final written = target;
    return ProfileDocumentReady(
      documentId: documentId,
      kind: kind,
      pdfPath: written.path,
      release: () => store.deleteFile(written),
    );
  }
}
