import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/constants/app_constants.dart';
import 'package:mobile_app/core/error/exceptions.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:mobile_app/features/profile/data/models/profile_document_model.dart';
import 'package:mobile_app/features/profile/data/services/profile_document_viewer.dart';

// Phase 11.4 step 4: in-app viewing of the employee's own documents —
// download with the user's login, check, keep images in memory, write PDFs
// to the private temp folder for pdfx, and delete copies. Synthetic files
// and tokens only.

final pdfBytes = Uint8List.fromList([...ascii.encode('%PDF-1.7\n'), 1, 2, 3]);
final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 1, 2]);
final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0]);

late Directory tempRoot;
late Directory docsRoot;

ProfileDocumentTempStore store() =>
    ProfileDocumentTempStore(tempRoot: () async => tempRoot, documentsRoot: () async => docsRoot);

ProfileDocumentViewer viewer(Future<ProfileDocumentFile> Function(int id) download) =>
    ProfileDocumentViewer(download: download, store: store());

Future<ProfileDocumentFile> Function(int) serve(Uint8List bytes, String contentType, [String? name]) =>
    (id) async => ProfileDocumentFile(bytes: bytes, contentType: contentType, fileName: name ?? 'document-$id');

Directory get docsDir => Directory('${tempRoot.path}/${ProfileDocumentTempStore.folderName}');

/// Every file under both roots, relative, sorted.
List<String> allFiles() {
  final out = <String>[];
  for (final root in [tempRoot, docsRoot]) {
    if (!root.existsSync()) continue;
    for (final e in root.listSync(recursive: true)) {
      if (e is File) out.add('${root == tempRoot ? 'tmp' : 'docs'}:${e.path.substring(root.path.length + 1)}');
    }
  }
  return out..sort();
}

void main() {
  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('profile_docs_tmp');
    docsRoot = await Directory.systemTemp.createTemp('profile_docs_docs');
  });
  tearDown(() async {
    for (final d in [tempRoot, docsRoot]) {
      if (await d.exists()) await d.delete(recursive: true);
    }
  });

  group('resolveDocumentKind', () {
    DocumentKind? kind(String? ct, List<String?> names, Uint8List bytes) =>
        resolveDocumentKind(contentType: ct, fileNames: names, bytes: bytes);

    test('PDF, JPEG and PNG by content type, extension and signature', () {
      expect(kind('application/pdf', ['scan.pdf'], pdfBytes), DocumentKind.pdf);
      expect(kind('application/pdf; charset=binary', ['scan.PDF'], pdfBytes), DocumentKind.pdf);
      expect(kind('image/jpeg', ['photo.jpg'], jpegBytes), DocumentKind.jpeg);
      expect(kind('image/jpeg', ['photo.JPEG'], jpegBytes), DocumentKind.jpeg);
      expect(kind('image/png', ['card.png'], pngBytes), DocumentKind.png);
    });

    test('a generic content type (Cloudinary raw) relies on the name and the bytes', () {
      expect(kind('application/octet-stream', ['card.png'], pngBytes), DocumentKind.png);
      expect(kind(null, ['document-9', null], jpegBytes), DocumentKind.jpeg);
      expect(kind('', ['scan.pdf'], pdfBytes), DocumentKind.pdf);
    });

    test('unsupported content types are refused', () {
      for (final ct in ['text/html', 'application/zip', 'image/gif', 'application/msword', 'image/webp']) {
        expect(kind(ct, ['x.pdf'], pdfBytes), isNull, reason: ct);
      }
    });

    test('unsupported extensions are refused', () {
      for (final name in ['x.exe', 'x.docx', 'x.gif', 'x.pdf.html', 'x.svg']) {
        expect(kind('application/octet-stream', [name], pdfBytes), isNull, reason: name);
      }
      expect(kind('application/pdf', ['scan.pdf', 'scan.exe'], pdfBytes), isNull);
    });

    test('content that does not match what it claims is refused', () {
      expect(kind('application/pdf', ['scan.pdf'], pngBytes), isNull);
      expect(kind('image/png', ['scan.pdf'], pngBytes), isNull);
      expect(kind('application/octet-stream', ['x.png'], jpegBytes), isNull);
      expect(kind('application/octet-stream', ['document-1'], Uint8List.fromList(ascii.encode('<html>'))), isNull);
      expect(kind('application/pdf', ['scan.pdf'], Uint8List.fromList([0x25, 0x50])), isNull);
    });
  });

  group('load', () {
    test('a PDF is written privately as doc-<id>.pdf for pdfx; release deletes it', () async {
      final out = await viewer(serve(pdfBytes, 'application/pdf', 'PAN scan [Test].pdf')).load(41);
      final ready = out as ProfileDocumentReady;
      expect(ready.isPdf, isTrue);
      expect(ready.kind, DocumentKind.pdf);
      expect(ready.imageBytes, isNull);
      expect(ready.pdfPath, '${docsDir.path}/doc-41.pdf');
      expect(File(ready.pdfPath!).readAsBytesSync(), pdfBytes);
      expect(allFiles(), ['tmp:profile_docs/doc-41.pdf']);
      await ready.release();
      expect(allFiles(), isEmpty);
      await ready.release(); // twice is fine
    });

    test('JPG and PNG stay in memory: nothing is written', () async {
      for (final (bytes, ct, name, kind) in [
        (jpegBytes, 'application/octet-stream', 'photo.jpeg', DocumentKind.jpeg),
        (pngBytes, 'image/png', 'card.png', DocumentKind.png),
      ]) {
        final ready = await viewer(serve(bytes, ct, name)).load(7) as ProfileDocumentReady;
        expect(ready.kind, kind);
        expect(ready.imageBytes, bytes);
        expect(ready.pdfPath, isNull);
        expect(allFiles(), isEmpty);
        await ready.release();
      }
    });

    test('the listed file name is checked too', () async {
      final out = await viewer(serve(pdfBytes, 'application/octet-stream')).load(5, knownFileName: 'notes.docx');
      expect((out as DocumentViewFailed).message, kDocumentUnsupportedMessage);
      expect(allFiles(), isEmpty);
    });

    test('an empty file is refused with a clear message', () async {
      final out = await viewer(serve(Uint8List(0), 'application/pdf', 'x.pdf')).load(5);
      expect((out as DocumentViewFailed).message, kDocumentEmptyMessage);
    });

    test('unsupported or disguised files are refused and nothing is written', () async {
      for (final (bytes, ct, name) in [
        (Uint8List.fromList(ascii.encode('<html>hi</html>')), 'text/html', 'page.html'),
        (pngBytes, 'application/pdf', 'scan.pdf'),
        (Uint8List.fromList(ascii.encode('MZ....')), 'application/octet-stream', 'run.exe'),
      ]) {
        final out = await viewer(serve(bytes, ct, name)).load(5);
        expect((out as DocumentViewFailed).message, kDocumentUnsupportedMessage, reason: name);
      }
      expect(allFiles(), isEmpty);
    });

    test('a failed download shows its own message', () async {
      for (final (error, message) in [
        (const ServerException('File temporarily unavailable.'), 'File temporarily unavailable.'),
        (const NotFoundException('Document not found.'), 'Document not found.'),
        (const NoInternetException(), userFriendlyMessage(const NoInternetException())),
      ]) {
        final out = await viewer((_) async => throw error).load(5);
        expect((out as DocumentViewFailed).message, message);
      }
      expect(allFiles(), isEmpty);
    });

    test('a PDF that cannot be written is a message, not a crash, and leaves nothing', () async {
      // A plain file where the profile_docs folder would go.
      File('${tempRoot.path}/${ProfileDocumentTempStore.folderName}').writeAsStringSync('x');
      final v = ProfileDocumentViewer(
        download: serve(pdfBytes, 'application/pdf'),
        store: ProfileDocumentTempStore(tempRoot: () async => tempRoot),
      );
      // clearAll() can't empty a file, so the folder stays blocked.
      expect(((await v.load(5)) as DocumentViewFailed).message, kDocumentOpenFailedMessage);
    });

    test('each view downloads afresh and clears earlier copies first', () async {
      var n = 0;
      final v = viewer((id) async {
        n++;
        return ProfileDocumentFile(
            bytes: Uint8List.fromList([...pdfBytes, n]), contentType: 'application/pdf', fileName: 'x.pdf');
      });
      final first = await v.load(1) as ProfileDocumentReady;
      // An earlier copy left behind (e.g. the app was killed while viewing).
      expect(allFiles(), ['tmp:profile_docs/doc-1.pdf']);
      final second = await v.load(2) as ProfileDocumentReady;
      expect(n, 2);
      expect(allFiles(), ['tmp:profile_docs/doc-2.pdf']);
      expect(File(second.pdfPath!).readAsBytesSync().last, 2);
      await first.release(); // already gone: no error
      await second.release();
      expect(allFiles(), isEmpty);
    });
  });

  group('ProfileDocumentTempStore.clearAll', () {
    test('empties profile_docs and pdfx page images (cache and documents), nothing else', () async {
      File('${docsDir.path}/doc-1.pdf')
        ..createSync(recursive: true)
        ..writeAsBytesSync(pdfBytes);
      File('${tempRoot.path}/pdf_renderer_cache/abc.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(pngBytes);
      File('${docsRoot.path}/pdf_renderer_cache/def.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync(jpegBytes);
      // Other features' files must survive.
      File('${tempRoot.path}/file_picker/upload.pdf')
        ..createSync(recursive: true)
        ..writeAsBytesSync(pdfBytes);
      File('${tempRoot.path}/other.pdf').writeAsBytesSync(pdfBytes);
      File('${docsRoot.path}/keep.txt').writeAsStringSync('keep');

      await store().clearAll();
      expect(allFiles(), ['docs:keep.txt', 'tmp:file_picker/upload.pdf', 'tmp:other.pdf']);
    });

    test('nothing to clear, or no platform folders, never throws', () async {
      await store().clearAll();
      await ProfileDocumentTempStore(tempRoot: () async => throw const FileSystemException('no temp dir')).clearAll();
      await ProfileDocumentTempStore(
        tempRoot: () async => tempRoot,
        documentsRoot: () async => throw const FileSystemException('no documents dir'),
      ).clearAll();
    });
  });

  // Through the app's real client stack: CookieManager + AuthInterceptor.
  group('with the signed-in client', () {
    const token = 'synthetic-access-token-123';
    const cookie = 'synthetic-cookie-456';
    late _Adapter adapter;
    late _MemoryStorage storage;

    Future<ProfileDocumentViewer> signedIn(ResponseBody Function(RequestOptions o) handler) async {
      storage = _MemoryStorage()..values[AppConstants.keyAccessToken] = token;
      final jar = DefaultCookieJar();
      await jar.saveFromResponse(Uri.parse(ApiConstants.baseUrl), [Cookie('royal_access_token', cookie)]);
      final container = ProviderContainer(overrides: [
        cookieJarProvider.overrideWithValue(jar),
        secureStorageProvider.overrideWithValue(storage),
      ]);
      addTearDown(container.dispose);
      adapter = _Adapter(handler);
      final dio = container.read(dioProvider)..httpClientAdapter = adapter;
      return viewer(ProfileRemoteDataSource(dio).downloadMyDocument);
    }

    ResponseBody jsonBody(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });

    test('the download carries the Bearer token and session cookie; nothing exposes them', () async {
      final v = await signedIn((_) => ResponseBody.fromBytes(pdfBytes, 200, headers: {
            Headers.contentTypeHeader: ['application/pdf'],
            'content-disposition': ['inline; filename="scan.pdf"'],
          }));
      final ready = await v.load(41) as ProfileDocumentReady;
      final req = adapter.requests.single;
      expect(req.path, '/onboarding/documents/41/');
      expect(req.headers['Authorization'], 'Bearer $token');
      expect(req.headers['cookie'], contains('royal_access_token=$cookie'));
      expect(req.uri.toString(), isNot(contains(token)));
      expect(req.uri.query, isEmpty);
      expect(ready.pdfPath, isNot(contains(token)));
      expect(ready.pdfPath, isNot(contains(cookie)));
      await ready.release();
    });

    test('an expired token is refreshed and the download retried', () async {
      var docCalls = 0;
      final v = await signedIn((o) {
        if (o.path == ApiConstants.tokenRefresh) {
          return jsonBody(200, {
            'status': 'success',
            'message': 'ok',
            'data': {'access': 'synthetic-new-token', 'refresh': 'synthetic-refresh-2'}
          });
        }
        docCalls++;
        if (docCalls == 1) return jsonBody(401, {'status': 'error', 'message': 'Token expired.', 'data': {}});
        return ResponseBody.fromBytes(pngBytes, 200, headers: {
          Headers.contentTypeHeader: ['application/octet-stream'],
          'content-disposition': ['inline; filename="card.png"'],
        });
      });
      storage.values[AppConstants.keyRefreshToken] = 'synthetic-refresh';
      final ready = await v.load(9).timeout(const Duration(seconds: 5)) as ProfileDocumentReady;
      expect(ready.kind, DocumentKind.png);
      expect(adapter.requests.last.headers['Authorization'], 'Bearer synthetic-new-token');
    });

    test('a refused download shows the server message, never a token or URL', () async {
      for (final (status, message) in [
        (403, 'Permission denied.'),
        (404, 'Document not found.'),
        (502, 'File temporarily unavailable.'),
      ]) {
        final v = await signedIn((_) => jsonBody(status, {'status': 'error', 'message': message, 'data': {}}));
        final out = await v.load(41) as DocumentViewFailed;
        expect(out.message, message);
        for (final secret in [token, cookie, 'Bearer', 'http', '/onboarding/']) {
          expect(out.message, isNot(contains(secret)));
        }
      }
      expect(allFiles(), isEmpty);
    });
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ResponseBody Function(RequestOptions o) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    requests.add(o.copyWith(headers: Map.of(o.headers)));
    return handler(o);
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryStorage extends SecureStorageService {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);
}
