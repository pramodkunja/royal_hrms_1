import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/data/datasources/employees_remote_datasource.dart';
import 'package:mobile_app/features/employees/data/services/employee_document_download.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';
import 'package:mobile_app/features/profile/data/services/profile_document_viewer.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/features/profile/presentation/screens/profile_document_viewer_screen.dart';

// Task 54: HR Employee Profile → Documents → View, as web DocPreviewModal.
// GET /employees/<code>/ returns each document's `file` as a signed Cloudinary
// download link (views._document_dict → private_download_url, ~1 hour). Web
// fetches it WITHOUT credentials and shows it in-page; a link on the API's own
// server (/api/..., or local /media/...) goes with the login. Before: mobile
// handed the raw link to canLaunchUrl/launchUrl — false on Android 11+ for
// https without a manifest <queries> entry — so View did nothing.
// Synthetic files and people only; the "file host" and API are stand-ins.

const code = 'EMP-54';
const apiBase = 'https://hrms.test.invalid/api';
const fileHost = 'files.test.invalid';
const token = 'test-bearer-token-54';

final pdfBytes = utf8.encode('%PDF-1.4\n% synthetic test document\n%%EOF\n');
const pngBytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
];
const jpegBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0xFF, 0xD9];
final htmlBytes = utf8.encode('<html><body>Error</body></html>');

ResponseBody _bytes(int status, List<int> body, String ct) => ResponseBody.fromBytes(body, status, headers: {
      Headers.contentTypeHeader: [ct]
    });

ResponseBody _json(int status, Object body) => _bytes(status, utf8.encode(jsonEncode(body)), Headers.jsonContentType);

/// The file host (Cloudinary stand-in). Keyed by public id; [refuse] answers
/// with a status instead; [offline] throws a connection error.
class FileHost implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final files = <String, (List<int>, String)>{};
  final refuse = <String, int>{};
  bool offline = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add(o);
    if (offline) throw DioException.connectionError(requestOptions: o, reason: 'offline');
    final id = o.uri.queryParameters['public_id'] ?? '';
    final st = refuse[id];
    if (st != null) return _bytes(st, utf8.encode('{"error":{"message":"denied"}}'), 'application/json');
    final f = files[id];
    if (f == null) return _bytes(404, utf8.encode('not found'), 'text/plain');
    return _bytes(200, f.$1, f.$2);
  }

  @override
  void close({bool force = false}) {}
}

/// The app API. Each detail GET signs the links anew (sig=<n>), as the
/// backend does. Also serves a same-origin /media/ file and the upload.
class ApiServer implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  int detailGets = 0;
  int detailStatus = 200;
  List<Map<String, dynamic>> Function(int sig) docs = (sig) => [
        doc(1, 'aadhaar_card', 'Aadhaar Card', 'aadhaar.png', link('aadhaar', sig)),
        doc(2, 'pan_card', 'PAN Card', 'pan.pdf', link('pan', sig)),
        doc(3, 'degree_certificate', 'Degree Certificate', 'degree.jpg', link('degree', sig)),
        doc(4, 'experience_letter', 'Experience Letter', 'letter.pdf', '/media/employee_docs/letter.pdf'),
      ];
  final media = <String, (int, List<int>)>{'/media/employee_docs/letter.pdf': (200, pdfBytes)};
  final uploads = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add(o);
    if (o.uri.path == '/api/employees/$code/' && o.method == 'GET') {
      detailGets++;
      if (detailStatus != 200) {
        return _json(detailStatus, {'status': 'error', 'message': 'You do not have permission.', 'data': {}});
      }
      return _json(200, {'status': 'success', 'data': employee(docs(detailGets))});
    }
    if (o.uri.path == '/api/employees/$code/documents/' && o.method == 'POST') {
      uploads.add(o);
      return _json(201, {'status': 'success', 'message': 'Document uploaded.', 'data': {}});
    }
    final m = media[o.uri.path];
    if (m != null) return _bytes(m.$1, m.$2, 'application/pdf');
    if (o.method == 'GET') return _json(200, {'status': 'success', 'data': <Object>[]});
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

String link(String id, int sig) =>
    'https://$fileHost/v1_1/demo/raw/download?public_id=$id&type=authenticated&signature=s$sig';

Map<String, dynamic> doc(int id, String type, String label, String name, String file) => {
      'id': id,
      'document_type': type,
      'document_type_display': label,
      'file': file,
      'file_name': name,
      'file_size': 2048,
      'uploaded_at': '2026-03-01T10:00:00Z',
    };

Map<String, dynamic> employee(List<Map<String, dynamic>> documents) => {
      'id': 'u54',
      'uuid': 'uuid-54',
      'employee_id': code,
      'first_name': 'Tara',
      'last_name': 'Test',
      'full_name': 'Tara Test',
      'email': 'tara.test@example.test',
      'department': 'QA',
      'designation': 'Analyst',
      'branch': 'North',
      'role': 'employee',
      'is_active': true,
      'status': 'active',
      'onboarding_status': 'complete',
      'documents': documents,
      'profile': {'custom_field_values': <String, dynamic>{}},
    };

/// The app's signed-in client: adds the bearer token, as the real one does.
Dio appDio(ApiServer s) => Dio(BaseOptions(baseUrl: apiBase))
  ..httpClientAdapter = s
  ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    o.headers['Authorization'] = 'Bearer $token';
    o.headers['Cookie'] = 'access_token=$token';
    h.next(o);
  }));

Dio plainDio(HttpClientAdapter h) => Dio()..httpClientAdapter = h;

FileHost defaultHost() => FileHost()
  ..files.addAll({
    'aadhaar': (pngBytes, 'image/png'),
    'pan': (pdfBytes, 'application/octet-stream'), // Cloudinary raw: generic type
    'degree': (jpegBytes, 'image/jpeg'),
  });

class _NullStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class _Auth extends AuthNotifier {
  _Auth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
  void signOut() => state = const AsyncData(AuthState.initial());
}

UserEntity hrUser(List<String> perms) => UserEntity(
      id: 'hr1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

late ApiServer api;
late FileHost host;
late Directory tempRoot;
late MemStore mem;
List<String> memFiles() => mem.files.keys.map((k) => k.split('/').last).toList();
final printed = <String>[];
Finder byKey(String k) => find.byKey(Key(k));

Directory get docsDir => Directory('${tempRoot.path}/${ProfileDocumentTempStore.folderName}');
List<String> tempFiles() =>
    docsDir.existsSync() ? docsDir.listSync().map((e) => e.path.split('/').last).toList() : <String>[];

Future<void> pumpProfile(WidgetTester tester,
    {UserEntity? as,
    ApiServer? withApi,
    FileHost? withHost,
    HttpClientAdapter? fileAdapter,
    bool openDocs = true}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  api = withApi ?? ApiServer();
  host = withHost ?? defaultHost();
  mem = MemStore();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? hrUser(['employees.view', 'employees.edit']))),
      dioProvider.overrideWithValue(appDio(api)),
      employeeDocumentExternalDioProvider.overrideWithValue(Dio()..httpClientAdapter = fileAdapter ?? host),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      profileDocumentTempStoreProvider.overrideWithValue(mem),
      profilePdfViewBuilderProvider.overrideWithValue((path, tracker) => Text(path, key: const Key('fake-pdf-view'))),
    ],
    child: const MaterialApp(home: EmployeeProfileScreen(employeeId: code)),
  ));
  await tester.pumpAndSettle();
  if (!openDocs) return;
  final chip = find.text('Documents').first;
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// Lets the download and the (in-memory) temp file work finish.
Future<void> settleIo(WidgetTester tester) => tester.pumpAndSettle();

/// Taps View (or Retry) on document [id] and lets the download finish.
Future<void> view(WidgetTester tester, int id, {String key = 'employee-doc-view'}) async {
  await tester.ensureVisible(byKey('$key-$id'));
  await tester.tap(byKey('$key-$id'));
  await settleIo(tester);
}

/// Closes the in-app viewer with its Close button.
Future<void> closeViewer(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(ProfileDocumentViewerScreen), matching: find.byIcon(Icons.close)));
  await settleIo(tester);
}

String? errorText(WidgetTester tester, int id) {
  final f = find.descendant(of: byKey('employee-doc-error-$id'), matching: find.byType(Text));
  return f.evaluate().isEmpty ? null : tester.widget<Text>(f.first).data;
}

/// 11. Nothing private in debug output: no token, no link, no file content.
void expectNothingPrivatePrinted() {
  final all = printed.join('\n');
  for (final secret in [token, fileHost, 'signature=', '%PDF', '/media/employee_docs']) {
    expect(all.contains(secret), isFalse, reason: 'debug output must not contain "$secret"');
  }
}

/// A widget test whose debug output is captured (and restored before the
/// framework's end-of-test checks).
void testDocs(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    final original = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => printed.add(m ?? '');
    try {
      await body(tester);
    } finally {
      debugPrint = original;
    }
  });
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('emp_docs_54');
    printed.clear();
  });
  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
    expectNothingPrivatePrinted();
  });

  group('link resolution', () {
    test('3. relative and absolute links: same server via the login, file host without it, unsafe refused', () {
      ({Uri uri, bool viaApi})? r(String s) => resolveEmployeeDocumentUrl(s, apiBaseUrl: apiBase);
      expect(r('/media/a.pdf'), (uri: Uri.parse('https://hrms.test.invalid/media/a.pdf'), viaApi: true));
      expect(r('media/a.pdf')!.uri.toString(), 'https://hrms.test.invalid/media/a.pdf');
      expect(r('/api/onboarding/documents/7/'),
          (uri: Uri.parse('https://hrms.test.invalid/api/onboarding/documents/7/'), viaApi: true));
      expect(r('https://hrms.test.invalid/api/x/')!.viaApi, isTrue);
      expect(r(link('aadhaar', 1))!.viaApi, isFalse);
      expect(r('/media/../etc/x')!.uri.host, 'hrms.test.invalid', reason: 'dot segments stay on the API origin');
      for (final bad in [
        '',
        '   ',
        '//evil.test/x',
        'file:///etc/passwd',
        'javascript:alert(1)',
        'http://other.test/x.pdf',
        'https://user:pw@files.test.invalid/x',
        'content://x/y'
      ]) {
        expect(r(bad), isNull, reason: bad);
      }
    });
  });

  group('downloader', () {
    late void Function(String? message, {int? wrapWidth}) originalPrint;
    setUp(() {
      originalPrint = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => printed.add(m ?? '');
    });
    tearDown(() => debugPrint = originalPrint);
    late ApiServer s;
    late FileHost h;
    late EmployeeDocumentDownloader d;
    setUp(() {
      s = ApiServer();
      h = defaultHost();
      d = EmployeeDocumentDownloader(api: appDio(s), external: plainDio(h), apiBaseUrl: apiBase);
    });

    test('4. file-host links go WITHOUT the login; same-server links WITH it', () async {
      final f = await d.download(link('aadhaar', 1), fileName: 'aadhaar.png');
      expect(f.bytes, pngBytes);
      expect(h.calls.single.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
      expect(h.calls.single.headers.keys.map((k) => k.toLowerCase()), isNot(contains('cookie')));
      final m = await d.download('/media/employee_docs/letter.pdf', fileName: 'letter.pdf');
      expect(m.bytes, pdfBytes);
      expect(s.calls.single.headers['Authorization'], 'Bearer $token');
      expect(s.calls.single.uri.toString(), 'https://hrms.test.invalid/media/employee_docs/letter.pdf');
    });

    test('7/8. 401/403 from the file host = expired link; API 401/403/404/500 and network failures: safe messages',
        () async {
      Future<EmployeeDocumentException> fail(String url) async {
        try {
          await d.download(url, fileName: 'x.pdf');
        } on EmployeeDocumentException catch (e) {
          return e;
        }
        throw TestFailure('expected a failure for $url');
      }

      h.refuse['aadhaar'] = 401;
      expect((await fail(link('aadhaar', 1))).linkExpired, isTrue);
      h.refuse['aadhaar'] = 403;
      expect((await fail(link('aadhaar', 1))).message, kDocumentLinkExpiredMessage);
      expect((await fail(link('gone', 1))).message, kDocumentNotFoundMessage);
      for (final (st, msg) in [
        (401, kDocumentSessionExpiredMessage),
        (403, kDocumentForbiddenMessage),
        (404, kDocumentNotFoundMessage),
        (500, kDocumentServerErrorMessage),
      ]) {
        s.media['/media/x.pdf'] = (st, utf8.encode('{}'));
        final e = await fail('/media/x.pdf');
        expect((e.message, e.linkExpired), (msg, false), reason: '$st');
      }
      h.offline = true;
      expect((await fail(link('pan', 1))).message, kDocumentNetworkMessage);
      expect((await fail('')).message, kDocumentNoFileMessage);
      expect((await fail('ftp://x/y')).message, kDocumentInvalidLinkMessage);
      for (final m in [kDocumentLinkExpiredMessage, kDocumentNetworkMessage, kDocumentServerErrorMessage]) {
        expect(m.contains('http') || m.contains(token), isFalse);
      }
    });

    test('an expired link is replaced once by a fresh one; a second refusal is not retried forever', () async {
      h.refuse['aadhaar'] = 401;
      var asked = 0;
      await expectLater(
        d.downloadWithRefresh(link('aadhaar', 1), fileName: 'a.png', freshUrl: () async {
          asked++;
          return link('aadhaar', 2);
        }),
        throwsA(isA<EmployeeDocumentException>().having((e) => e.linkExpired, 'linkExpired', isTrue)),
      );
      expect((asked, h.calls.length), (1, 2));
      h.refuse.clear();
      h.calls.clear();
      // Fresh link works.
      h.refuse['old'] = 401;
      h.files['old'] = (pngBytes, 'image/png');
      final f =
          await d.downloadWithRefresh(link('old', 1), fileName: 'a.png', freshUrl: () async => link('aadhaar', 2));
      expect(f.bytes, pngBytes);
      // Removed meanwhile: not found.
      await expectLater(d.downloadWithRefresh(link('old', 1), fileName: 'a.png', freshUrl: () async => null),
          throwsA(isA<EmployeeDocumentException>().having((e) => e.message, 'message', kDocumentNotFoundMessage)));
    });

    test(
        '5/6/10. viewer: PDF written to a private temp file and deleted on release; images stay in memory; '
        'empty and disguised files refused', () async {
      final store = ProfileDocumentTempStore(tempRoot: () async => tempRoot);
      ProfileDocumentViewer v(String url, String name) =>
          ProfileDocumentViewer(download: (_) => d.download(url, fileName: name), store: store);
      final pdf = await v(link('pan', 1), 'pan.pdf').load(2, knownFileName: 'pan.pdf') as ProfileDocumentReady;
      expect(pdf.isPdf, isTrue);
      expect(tempFiles(), ['doc-2.pdf'], reason: 'no names, tokens or links in the path');
      expect(File(pdf.pdfPath!).readAsBytesSync(), pdfBytes);
      await pdf.release();
      expect(tempFiles(), isEmpty);
      final png = await v(link('aadhaar', 1), 'aadhaar.png').load(1) as ProfileDocumentReady;
      expect((png.kind, png.pdfPath), (DocumentKind.png, null));
      final jpg = await v(link('degree', 1), 'degree.jpg').load(3) as ProfileDocumentReady;
      expect(jpg.kind, DocumentKind.jpeg);
      expect(tempFiles(), isEmpty, reason: 'images are never written');
      h.files['html'] = (htmlBytes, 'application/octet-stream');
      expect(
          ((await v(link('html', 1), 'scan.pdf').load(9)) as DocumentViewFailed).message, kDocumentUnsupportedMessage);
      h.files['empty'] = (<int>[], 'application/pdf');
      expect(((await v(link('empty', 1), 'e.pdf').load(9)) as DocumentViewFailed).message, kDocumentEmptyMessage);
      h.files['docx'] =
          (utf8.encode('PK\x03\x04'), 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      expect(
          ((await v(link('docx', 1), 'cv.docx').load(9)) as DocumentViewFailed).message, kDocumentUnsupportedMessage);
      expect(tempFiles(), isEmpty);
    });

    test('12. upload request unchanged: multipart POST /employees/<code>/documents/ with the type and file', () async {
      final ds = EmployeesRemoteDataSource(appDio(s));
      await ds.uploadEmployeeDocument(code,
          documentType: 'aadhaar_card', bytes: Uint8List.fromList(pngBytes), filename: 'aadhaar.png');
      final req = s.uploads.single;
      expect(req.data, isA<FormData>());
      final form = req.data as FormData;
      expect(form.fields.map((e) => (e.key, e.value)), [('document_type', 'aadhaar_card')]);
      expect(form.files.single.value.filename, 'aadhaar.png');
    });
  });

  group('profile', () {
    testDocs('1/5. Aadhaar (PNG on the file host) opens in the app; closing leaves nothing behind', (tester) async {
      await pumpProfile(tester);
      expect(find.text('Aadhaar Card'), findsOneWidget);
      await view(tester, 1);
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(host.calls.single.uri.queryParameters['public_id'], 'aadhaar');
      expect(host.calls.single.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
      await closeViewer(tester);
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
      expect(memFiles(), isEmpty);
    });

    testDocs('2/5. other categories: PAN (PDF), Degree (JPEG), Experience Letter (same-server PDF, with login)',
        (tester) async {
      await pumpProfile(tester);
      await view(tester, 2);
      expect(byKey('fake-pdf-view'), findsOneWidget);
      expect(memFiles(), ['doc-2.pdf']);
      await closeViewer(tester);
      expect(memFiles(), isEmpty, reason: 'PDF copy deleted when the viewer closes');

      await view(tester, 3);
      expect(find.byType(Image), findsOneWidget);
      await closeViewer(tester);

      await view(tester, 4);
      expect(byKey('fake-pdf-view'), findsOneWidget);
      final media = api.calls.where((c) => c.uri.path == '/media/employee_docs/letter.pdf').single;
      expect(media.headers['Authorization'], 'Bearer $token');
      await closeViewer(tester);
      expect(memFiles(), isEmpty);
    });

    testDocs('7. an expired link: the employee is reloaded once for a fresh link, then it opens', (tester) async {
      final h = defaultHost();
      final gate = _SigGate(h, refusedSig: 's1'); // the link from the first load has expired
      await pumpProfile(tester, withHost: h, fileAdapter: gate);
      expect(api.detailGets, 1);
      await view(tester, 1);
      expect(api.detailGets, 2, reason: 'one fresh detail for a new link');
      expect(gate.seen.map((u) => u.queryParameters['signature']), ['s1', 's2']);
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      await closeViewer(tester);
    });

    testDocs('6/7/8. not found, server error and network failure show on the card; Retry opens it', (tester) async {
      final h = defaultHost()..offline = true;
      await pumpProfile(tester, withHost: h);
      await view(tester, 1);
      expect(errorText(tester, 1), kDocumentNetworkMessage);
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
      h.offline = false;
      await view(tester, 1, key: 'employee-doc-retry');
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      await closeViewer(tester);
      expect(byKey('employee-doc-error-1'), findsNothing);

      api.media['/media/employee_docs/letter.pdf'] = (404, utf8.encode('{}'));
      await view(tester, 4);
      expect(errorText(tester, 4), kDocumentNotFoundMessage);
      api.media['/media/employee_docs/letter.pdf'] = (500, utf8.encode('{}'));
      await view(tester, 4, key: 'employee-doc-retry');
      expect(errorText(tester, 4), kDocumentServerErrorMessage);
      api.media['/media/employee_docs/letter.pdf'] = (403, utf8.encode('{}'));
      await view(tester, 4, key: 'employee-doc-retry');
      expect(errorText(tester, 4), kDocumentForbiddenMessage);
      api.media['/media/employee_docs/letter.pdf'] = (401, utf8.encode('{}'));
      await view(tester, 4, key: 'employee-doc-retry');
      expect(errorText(tester, 4), kDocumentSessionExpiredMessage);
      h.files['aadhaar'] = (htmlBytes, 'text/html');
      await view(tester, 1);
      expect(errorText(tester, 1), kDocumentUnsupportedMessage);
      expect(memFiles(), isEmpty);
    });

    testDocs('6. a document without a file: View disabled', (tester) async {
      final s = ApiServer()..docs = (sig) => [doc(5, 'other', 'Other', 'x.pdf', '')];
      await pumpProfile(tester, withApi: s);
      final btn = tester.widget<IconButton>(byKey('employee-doc-view-5'));
      expect(btn.onPressed, isNull);
    });

    testDocs('9. viewer without employees.edit can view (as web); Upload/Replace unchanged', (tester) async {
      await pumpProfile(tester, as: hrUser(['employees.view']));
      expect(find.text('Upload Document'), findsOneWidget);
      expect(find.byTooltip('Replace'), findsNWidgets(4));
      await view(tester, 3);
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      await closeViewer(tester);
    });

    testDocs('9. no access to the employee (403 on the detail): no documents, nothing downloaded', (tester) async {
      await pumpProfile(tester, withApi: ApiServer()..detailStatus = 403, openDocs: false);
      expect(find.text('Aadhaar Card'), findsNothing);
      expect(host.calls, isEmpty);
    });

    testDocs('10. signed out while downloading: never shown, temp copy released', (tester) async {
      final h = _SlowHost(defaultHost());
      await pumpProfile(tester, withHost: h.inner, fileAdapter: h);
      await tester.ensureVisible(byKey('employee-doc-view-2'));
      await tester.tap(byKey('employee-doc-view-2'));
      await tester.pump();
      expect(byKey('employee-doc-opening'), findsOneWidget, reason: 'loading shown');
      final container = ProviderScope.containerOf(tester.element(find.byType(EmployeeProfileScreen)));
      (container.read(authStateProvider.notifier) as _Auth).signOut();
      h.release();
      await settleIo(tester);
      await tester.pump();
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
      expect(memFiles(), isEmpty);
    });
  });
}

/// Refuses only links carrying [refusedSig] (an "expired" signature).
class _SigGate implements HttpClientAdapter {
  _SigGate(this.inner, {required this.refusedSig});
  final FileHost inner;
  final String refusedSig;
  final seen = <Uri>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    seen.add(o.uri);
    if (o.uri.queryParameters['signature'] == refusedSig) {
      return _bytes(401, utf8.encode('{"error":"expired"}'), 'application/json');
    }
    return inner.fetch(o, s, c);
  }

  @override
  void close({bool force = false}) {}
}

/// Holds every file-host answer until [release].
class _SlowHost implements HttpClientAdapter {
  _SlowHost(this.inner);
  final FileHost inner;
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    await _gate.future;
    return inner.fetch(o, s, c);
  }

  @override
  void close({bool force = false}) {}
}

/// The temp store in memory, for widget tests: same calls as the real one
/// (clearAll before each view, a doc-<id>.pdf per PDF, deleted on release),
/// no disk I/O. The real store's file handling is tested in 'downloader'.
class MemStore extends ProfileDocumentTempStore {
  MemStore() : super(tempRoot: () async => throw UnsupportedError('no disk in widget tests'));
  final files = <String, List<int>>{};
  int clears = 0;

  @override
  Future<File> pdfFileFor(int documentId) async =>
      _MemFile(this, '/mem/${ProfileDocumentTempStore.folderName}/doc-$documentId.pdf');

  @override
  Future<void> deleteFile(File f) async => files.remove(f.path);

  @override
  Future<void> clearAll() async {
    clears++;
    files.clear();
  }
}

class _MemFile implements File {
  _MemFile(this.store, this.path);
  final MemStore store;
  @override
  final String path;

  @override
  Future<File> writeAsBytes(List<int> bytes, {FileMode mode = FileMode.write, bool flush = false}) async {
    store.files[path] = List.of(bytes);
    return this;
  }

  @override
  Future<bool> exists() async => store.files.containsKey(path);

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    store.files.remove(path);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
