import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/constants/app_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/core/error/exceptions.dart';
import 'package:mobile_app/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:mobile_app/features/profile/data/models/profile_document_model.dart';

// Phase 11.4 step 1: the self-service document data layer, against a
// stand-in for the production endpoints (EmployeeProfileDocumentView,
// DocumentTypeConfigPublicView, EmployeeDocumentView). Synthetic data only.

class Captured {
  Captured(this.options, this.body);
  final RequestOptions options;
  final Uint8List body;

  String get text => latin1.decode(body);
}

typedef Handler = ResponseBody Function(RequestOptions o);

class FakeServer implements HttpClientAdapter {
  FakeServer(this.handler);
  final Handler handler;
  final requests = <Captured>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? _) async {
    final chunks = <int>[];
    if (body != null) {
      await for (final c in body) {
        chunks.addAll(c);
      }
    }
    // Headers as sent (a replayed request reuses and mutates the same options).
    requests.add(Captured(o.copyWith(headers: Map.of(o.headers)), Uint8List.fromList(chunks)));
    return handler(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

const uploadedDoc = {
  'id': 41,
  'document_type': 'pan_card',
  'document_type_display': 'PAN Card',
  'file_url': 'https://test.invalid/api/onboarding/documents/41/',
  'file_name': 'scan.pdf',
  'file_size': 4,
  'uploaded_at': '2026-11-05T10:00:00Z',
};

late FakeServer server;

ProfileRemoteDataSource ds(Handler handler) {
  server = FakeServer(handler);
  final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server;
  return ProfileRemoteDataSource(dio);
}

ProfileUploadFile file(String name, [int size = 4]) =>
    ProfileUploadFile(name: name, bytes: Uint8List.fromList(List.filled(size, 7)));

Future<Object> thrown(Future<Object?> Function() run) async {
  try {
    await run();
  } catch (e) {
    return e;
  }
  fail('expected an error');
}

void main() {
  group('fetchDocumentTypes', () {
    test('reads the public config endpoint, all types kept', () async {
      final d = ds((_) => json(200, {
            'status': 'success',
            'message': 'ok',
            'data': [
              {'type_key': 'pan_card', 'label': 'PAN Card', 'order': 1, 'visible': true, 'required': true},
              {'type_key': 'old_type', 'label': 'Old', 'order': 2, 'visible': false, 'allow_multiple': true},
            ],
          }));
      final types = await d.fetchDocumentTypes();
      expect(server.requests.single.options.method, 'GET');
      expect(server.requests.single.options.path, '/onboarding/document-type-config/');
      expect(types.map((t) => t.typeKey), ['pan_card', 'old_type']);
      expect(types[0].required, isTrue);
      expect(types[1].visible, isFalse);
      expect(types[1].allowMultiple, isTrue);
    });
  });

  group('uploadMyDocument', () {
    for (final (name, mime) in [
      ('scan.pdf', 'application/pdf'),
      ('photo.jpg', 'image/jpeg'),
      ('photo.JPEG', 'image/jpeg'),
      ('card.png', 'image/png'),
    ]) {
      test('$name goes to the own-profile endpoint as $mime', () async {
        final d = ds((_) => json(201, {'status': 'success', 'message': 'Document uploaded.', 'data': uploadedDoc}));
        final doc = await d.uploadMyDocument('EMP-T1', 'pan_card', file(name));
        final req = server.requests.single;
        expect(req.options.method, 'POST');
        expect(req.options.path, '/employees/EMP-T1/documents/');
        expect(req.options.contentType, startsWith('multipart/form-data'));
        final text = req.text;
        expect(text, contains('name="document_type"\r\n\r\npan_card\r\n'));
        expect(text, contains('name="file"; filename="$name"\r\ncontent-type: $mime\r\n'));
        expect(text, isNot(contains('octet-stream')));
        expect(doc.id, 41);
        expect(doc.documentType, 'pan_card');
      });
    }

    test('the employee code is path-escaped', () async {
      final d = ds((_) => json(201, {'status': 'success', 'message': 'ok', 'data': uploadedDoc}));
      await d.uploadMyDocument('EMP 7/A', 'pan_card', file('a.pdf'));
      expect(server.requests.single.options.uri.path, '/api/employees/EMP%207%2FA/documents/');
    });

    test('files the backend would refuse are never sent, with its messages', () async {
      final d = ds((_) => json(201, {}));
      Future<String> msg(ProfileUploadFile f) async =>
          (await thrown(() => d.uploadMyDocument('EMP-T1', 'pan_card', f)) as ValidationException).message;
      expect(await msg(file('a.pdf', 0)), 'Uploaded file is empty.');
      expect(await msg(file('a.docx')), 'Only PDF, JPG, and PNG files are allowed.');
      expect(await msg(file('noext')), 'Only PDF, JPG, and PNG files are allowed.');
      expect(await msg(file('big.pdf', 5 * 1024 * 1024 + 1)), 'File size 5.0 MB exceeds the 5 MB limit.');
      expect(server.requests, isEmpty);
    });

    test('exactly 5 MB is allowed', () async {
      final d = ds((_) => json(201, {'status': 'success', 'message': 'ok', 'data': uploadedDoc}));
      await d.uploadMyDocument('EMP-T1', 'pan_card', file('ok.pdf', 5 * 1024 * 1024));
      expect(server.requests, hasLength(1));
    });

    test('a missing employee code or type sends nothing', () async {
      final d = ds((_) => json(201, {}));
      expect(await thrown(() => d.uploadMyDocument('  ', 'pan_card', file('a.pdf'))), isA<ValidationException>());
      expect(await thrown(() => d.uploadMyDocument('EMP-T1', '', file('a.pdf'))), isA<ValidationException>());
      expect(server.requests, isEmpty);
    });

    for (final (status, message, type) in [
      (400, 'Only PDF, JPG, and PNG files are allowed.', NetworkException),
      (400, 'Invalid document type.', NetworkException),
      (403, 'You do not have permission to upload documents for this employee.', ForbiddenException),
      (404, 'Employee not found.', NotFoundException),
      (500, 'Server error.', ServerException),
    ]) {
      test('$status is an error with the server message, never success', () async {
        final d = ds((_) => json(status, {'status': 'error', 'message': message, 'data': {}}));
        final e = await thrown(() => d.uploadMyDocument('EMP-T1', 'pan_card', file('a.pdf')));
        expect(e, isA<AppException>());
        expect(e.runtimeType, type);
        expect((e as AppException).message, message);
      });
    }

    test('a 2xx without a document is not treated as success', () async {
      final d = ds((_) => json(201, {'status': 'success', 'message': 'ok', 'data': null}));
      expect(await thrown(() => d.uploadMyDocument('EMP-T1', 'pan_card', file('a.pdf'))), isA<ServerException>());
    });

    test('no connection is a friendly error', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
        ..httpClientAdapter = _Throwing(DioExceptionType.connectionError);
      final e = await thrown(() => ProfileRemoteDataSource(dio).uploadMyDocument('EMP-T1', 'pan_card', file('a.pdf')));
      expect(e, isA<NoInternetException>());
    });
  });

  group('downloadMyDocument', () {
    test('fetches by id through the logged-in client and returns the bytes', () async {
      final d = ds((_) => ResponseBody.fromBytes([37, 80, 68, 70], 200,
          headers: {
            Headers.contentTypeHeader: ['application/pdf'],
            'content-disposition': ['inline; filename="scan.pdf"'],
          }));
      final f = await d.downloadMyDocument(41);
      final req = server.requests.single;
      expect(req.options.method, 'GET');
      expect(req.options.path, '/onboarding/documents/41/');
      expect(req.options.responseType, ResponseType.bytes);
      expect(f.bytes, [37, 80, 68, 70]);
      expect(f.contentType, 'application/pdf');
      expect(f.fileName, 'scan.pdf');
    });

    test('no file name header falls back to a neutral name', () async {
      final d = ds((_) => ResponseBody.fromBytes([1], 200,
          headers: {
            Headers.contentTypeHeader: ['image/png']
          }));
      expect((await d.downloadMyDocument(9)).fileName, 'document-9');
    });

    for (final (status, message, type) in [
      (403, 'Permission denied.', ForbiddenException),
      (404, 'Document not found.', NotFoundException),
      (502, 'File temporarily unavailable.', ServerException),
    ]) {
      test('$status shows the server message from the byte body', () async {
        final d = ds((_) => json(status, {'status': 'error', 'message': message, 'data': {}}));
        final e = await thrown(() => d.downloadMyDocument(41));
        expect(e.runtimeType, type);
        expect((e as AppException).message, message);
      });
    }

    test('an empty body is an error, not an empty file', () async {
      final d = ds((_) => ResponseBody.fromBytes([], 200));
      final e = await thrown(() => d.downloadMyDocument(41));
      expect(e, isA<ServerException>());
      expect((e as AppException).message, "This document is empty and can't be opened.");
    });

    test('a non-JSON error body falls back to the default message', () async {
      final d = ds((_) => ResponseBody.fromString('<html>bad gateway</html>', 502));
      final e = await thrown(() => d.downloadMyDocument(41));
      expect(e, isA<ServerException>());
      expect((e as AppException).message, const ServerException().message);
    });
  });

  // The real client stack (dioProvider): CookieManager attaches the cookie
  // jar's session cookies on native, and AuthInterceptor adds the stored
  // access token as `Authorization: Bearer`. The backend's
  // CookieJWTAuthentication reads the `royal_access_token` cookie first and
  // falls back to the Bearer header — either one authenticates.
  group('download credentials (real dioProvider)', () {
    late ProviderContainer container;
    late _MemoryStorage storage;
    late DefaultCookieJar jar;
    late FakeServer adapter;

    Future<void> setUpStack(Handler handler, {String? token, String? cookie}) async {
      storage = _MemoryStorage();
      if (token != null) storage.values[AppConstants.keyAccessToken] = token;
      jar = DefaultCookieJar();
      if (cookie != null) {
        await jar.saveFromResponse(Uri.parse(ApiConstants.baseUrl), [Cookie('royal_access_token', cookie)]);
      }
      container = ProviderContainer(overrides: [
        cookieJarProvider.overrideWithValue(jar),
        secureStorageProvider.overrideWithValue(storage),
      ]);
      addTearDown(container.dispose);
      adapter = FakeServer(handler);
      container.read(dioProvider).httpClientAdapter = adapter;
    }

    ProfileRemoteDataSource source() => ProfileRemoteDataSource(container.read(dioProvider));

    ResponseBody pdf(RequestOptions _) => ResponseBody.fromBytes([37, 80, 68, 70], 200,
        headers: {
          Headers.contentTypeHeader: ['application/pdf']
        });

    test('sends both the Bearer token and the session cookie', () async {
      await setUpStack(pdf, token: 'synthetic-access', cookie: 'synthetic-cookie');
      await source().downloadMyDocument(41);
      final headers = adapter.requests.single.options.headers;
      expect(headers['Authorization'], 'Bearer synthetic-access');
      expect(headers['cookie'], contains('royal_access_token=synthetic-cookie'));
    });

    test('with only a stored token (empty cookie jar) the Bearer header still authenticates', () async {
      await setUpStack(pdf, token: 'synthetic-access');
      await source().downloadMyDocument(41);
      final headers = adapter.requests.single.options.headers;
      expect(headers['Authorization'], 'Bearer synthetic-access');
      expect(headers['cookie'], isNull);
    });

    test('an expired token is refreshed and the download is retried with the new one', () async {
      var downloads = 0;
      await setUpStack((o) {
        if (o.path == ApiConstants.tokenRefresh) {
          return json(200, {
            'status': 'success',
            'message': 'ok',
            'data': {'access': 'synthetic-new', 'refresh': 'synthetic-refresh-2'},
          });
        }
        downloads++;
        return downloads == 1 ? json(401, {'status': 'error', 'message': 'Token expired.', 'data': {}}) : pdf(o);
      }, token: 'synthetic-old');
      storage.values[AppConstants.keyRefreshToken] = 'synthetic-refresh';
      final f = await source().downloadMyDocument(41).timeout(const Duration(seconds: 5));
      expect(f.bytes, [37, 80, 68, 70]);
      final docRequests = adapter.requests.where((r) => r.options.path == '/onboarding/documents/41/').toList();
      expect(docRequests, hasLength(2));
      expect(docRequests.last.options.headers['Authorization'], 'Bearer synthetic-new');
      expect(docRequests.last.options.responseType, ResponseType.bytes);
    });
  });

  group('fileNameFromContentDisposition', () {
    test('reads plain, quoted, encoded and path-like names', () {
      expect(fileNameFromContentDisposition('inline; filename="a b.pdf"'), 'a b.pdf');
      expect(fileNameFromContentDisposition('attachment; filename=x.png'), 'x.png');
      expect(fileNameFromContentDisposition("inline; filename*=UTF-8''r%C3%A9sum%C3%A9.pdf"), 'résumé.pdf');
      expect(fileNameFromContentDisposition('inline; filename="../../etc/x.pdf"'), 'x.pdf');
      expect(fileNameFromContentDisposition('inline; filename="100%.pdf"'), '100%.pdf');
      expect(fileNameFromContentDisposition('inline'), isNull);
      expect(fileNameFromContentDisposition(null), isNull);
    });
  });
}

class _Throwing implements HttpClientAdapter {
  _Throwing(this.type);
  final DioExceptionType type;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async =>
      throw DioException(requestOptions: o, type: type);

  @override
  void close({bool force = false}) {}
}

/// In-memory stand-in for the platform keychain/keystore.
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
