import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/data/services/employee_document_download.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';
import 'package:mobile_app/features/employees/presentation/widgets/custom_fields_block.dart';
import 'package:mobile_app/features/onboarding/data/models/onboarding_config_models.dart';
import 'package:mobile_app/features/onboarding/presentation/widgets/onboarding_custom_file_field.dart';
import 'package:mobile_app/features/profile/data/services/profile_document_viewer.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/features/profile/presentation/screens/profile_document_viewer_screen.dart';
import 'package:mobile_app/features/settings/data/models/onboarding_field_config_model.dart';

import 'employee_documents_view_test.dart'
    show FileHost, MemStore, fileHost, htmlBytes, link, pdfBytes, pngBytes, token;

// Task 57: file-type custom fields (Settings → Onboarding Fields) open in the
// app's document viewer, like Employee Profile → Documents (Task 54), instead
// of an external browser (launchUrl) — and editors can now view them too
// (before, their list had only Remove). Contracts:
//  - HR GET /employees/<code>/ → custom_file_fields[].file = a signed file-host
//    link (views._custom_field_file_dict, ~1 hour): fetched without the login,
//    refreshed once from a new employee detail when expired.
//  - Self GET /onboarding/custom-file-fields/ → file_url = an absolute link to
//    the API's own proxy /api/onboarding/custom-file-fields/<id>/ (needs the
//    login; as web, its path goes to the app's API address).
// Synthetic files and people only.

const code = 'EMP-57';
const apiBase = 'https://hrms.test.invalid/api';

Map<String, dynamic> cfg(String key, int step, {String type = 'file', String? label}) => {
      'field_key': key,
      'label': label ?? 'Label $key',
      'field_type': type,
      'options': <String>[],
      'allow_multiple': false,
      'step': step,
      'order': 1,
      'visible': true,
      'required': false,
      'is_custom': true,
      'is_locked': false,
    };

final fieldConfig = {
  '3': [cfg('cf_proof', 3, label: 'Address proof'), cfg('cf_scan', 3, label: 'Signed form')],
};

class Api implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  int detailGets = 0;
  final writes = <RequestOptions>[];
  final proxy = <int, (int, List<int>, String)>{};

  List<Map<String, dynamic>> files(int sig) => [
        {
          'id': 11,
          'field_key': 'cf_proof',
          'file': link('proof', sig),
          'file_name': 'proof.pdf',
          'file_size': 2048,
          'uploaded_at': '2026-11-01T10:00:00Z'
        },
        {
          'id': 12,
          'field_key': 'cf_scan',
          'file': link('scan', sig),
          'file_name': 'scan.png',
          'file_size': 900,
          'uploaded_at': '2026-11-01T10:00:00Z'
        },
      ];

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add(o);
    final path = o.uri.path;
    if (o.method != 'GET') {
      writes.add(o);
      return _json(200, {'status': 'success', 'message': 'ok', 'data': {}});
    }
    if (path == '/api${ApiConstants.onboardingFieldConfig}') {
      return _json(200, {'status': 'success', 'data': fieldConfig});
    }
    if (path == '/api/employees/$code/') {
      detailGets++;
      return _json(200, {
        'status': 'success',
        'data': {
          'id': 'u57',
          'uuid': 'uuid-57',
          'employee_id': code,
          'first_name': 'Kavi',
          'last_name': 'Test',
          'full_name': 'Kavi Test',
          'email': 'kavi.test@example.test',
          'department': 'QA',
          'designation': 'Analyst',
          'branch': 'North',
          'role': 'employee',
          'is_active': true,
          'status': 'active',
          'onboarding_status': 'complete',
          'documents': <Object>[],
          'profile': {'custom_field_values': <String, dynamic>{}},
          'custom_file_fields': files(detailGets),
        },
      });
    }
    final m = RegExp(r'^/api/onboarding/custom-file-fields/(\d+)/$').firstMatch(path);
    if (m != null) {
      final p = proxy[int.parse(m.group(1)!)];
      if (p == null) return _json(404, {'status': 'error', 'message': 'File not found.', 'data': {}});
      return ResponseBody.fromBytes(p.$2, p.$1, headers: {
        Headers.contentTypeHeader: [p.$3]
      });
    }
    return _json(200, {'status': 'success', 'data': <Object>[]});
  }

  @override
  void close({bool force = false}) {}
}

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

final editor = hrUser(['employees.view', 'employees.edit']);
final viewer = hrUser(['employees.view']);

/// The app's signed-in client: adds the bearer token, as the real one does.
Dio appDio(HttpClientAdapter s) => Dio(BaseOptions(baseUrl: apiBase))
  ..httpClientAdapter = s
  ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    o.headers['Authorization'] = 'Bearer $token';
    h.next(o);
  }));

late Api api;
late FileHost host;
late MemStore mem;
final printed = <String>[];
Finder byKey(String k) => find.byKey(Key(k));
List<String> memFiles() => mem.files.keys.map((k) => k.split('/').last).toList();

FileHost defaultHost() => FileHost()
  ..files.addAll({
    'proof': (pdfBytes, 'application/octet-stream'),
    'scan': (pngBytes, 'image/png'),
  });

List<Override> overrides(UserEntity u, HttpClientAdapter fileAdapter) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(appDio(api)),
      employeeDocumentExternalDioProvider.overrideWithValue(Dio()..httpClientAdapter = fileAdapter),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      profileDocumentTempStoreProvider.overrideWithValue(mem),
      profilePdfViewBuilderProvider.overrideWithValue((path, tracker) => Text(path, key: const Key('fake-pdf-view'))),
    ];

Future<void> pumpEmployee(WidgetTester tester, {UserEntity? as, HttpClientAdapter? fileAdapter}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  api = Api();
  host = defaultHost();
  mem = MemStore();
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? editor, fileAdapter ?? host),
    child: const MaterialApp(home: EmployeeProfileScreen(employeeId: code)),
  ));
  await tester.pumpAndSettle();
  final chip = find.text('Emergency Contact').first;
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

Future<void> closeViewer(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(ProfileDocumentViewerScreen), matching: find.byIcon(Icons.close)));
  await tester.pumpAndSettle();
}

String? errorOf(WidgetTester tester, int id) {
  final f = find.descendant(of: byKey('custom-file-error-$id'), matching: find.byType(Text));
  return f.evaluate().isEmpty ? null : tester.widget<Text>(f.first).data;
}

void testFiles(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    final original = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => printed.add(m ?? '');
    try {
      await body(tester);
    } finally {
      debugPrint = original;
    }
    final all = printed.join('\n');
    for (final secret in [token, fileHost, 'signature=', '%PDF']) {
      expect(all.contains(secret), isFalse, reason: 'debug output must not contain "$secret"');
    }
    printed.clear();
  });
}

/// Refuses only links carrying [refusedSig] (an expired signature).
class SigGate implements HttpClientAdapter {
  SigGate(this.inner, this.refusedSig);
  final FileHost inner;
  final String refusedSig;
  final seen = <String?>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    seen.add(o.uri.queryParameters['signature']);
    if (o.uri.queryParameters['signature'] == refusedSig) {
      return ResponseBody.fromString('{"error":"expired"}', 401, headers: {
        Headers.contentTypeHeader: ['application/json']
      });
    }
    return inner.fetch(o, s, c);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('links', () {
    test('API links (self-service proxy) go to the app\'s API address with the login; file-host links without', () {
      ({Uri uri, bool viaApi})? r(String s) => resolveEmployeeDocumentUrl(s, apiBaseUrl: apiBase);
      // Same origin.
      expect(r('https://hrms.test.invalid/api/onboarding/custom-file-fields/9/'),
          (uri: Uri.parse('https://hrms.test.invalid/api/onboarding/custom-file-fields/9/'), viaApi: true));
      // Built behind the proxy as http / an internal host: rebuilt on the API address.
      expect(r('http://10.0.0.5:8000/api/onboarding/custom-file-fields/9/'),
          (uri: Uri.parse('https://hrms.test.invalid/api/onboarding/custom-file-fields/9/'), viaApi: true));
      expect(r('http://hrms.test.invalid/api/onboarding/custom-file-fields/9/?x=1')!.uri.toString(),
          'https://hrms.test.invalid/api/onboarding/custom-file-fields/9/?x=1');
      // Signed file-host link: fetched without the login.
      expect(r(link('proof', 1))!.viaApi, isFalse);
      // Not API paths on other hosts: still refused over http.
      expect(r('http://other.test/media/x.pdf'), isNull);
      expect(r('http://other.test/apix/x.pdf'), isNull);
    });
  });

  group('HR employee profile', () {
    testFiles('editor: PDF and image custom files open in the app; Remove/Replace still there; temp copy deleted',
        (tester) async {
      await pumpEmployee(tester);
      expect(byKey('onboarding-file-cf_proof'), findsOneWidget, reason: 'editable list');
      expect(byKey('custom-file-remove-11'), findsOneWidget);
      expect(find.text('Replace'), findsNWidgets(2));
      await tapKey(tester, 'custom-file-view-11');
      expect(byKey('fake-pdf-view'), findsOneWidget);
      expect(find.text('Address proof'), findsWidgets, reason: 'viewer titled with the field label');
      expect(memFiles(), ['doc-11.pdf']);
      final call = host.calls.single;
      expect(call.uri.queryParameters['public_id'], 'proof');
      expect(call.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
      await closeViewer(tester);
      expect(memFiles(), isEmpty);
      await tapKey(tester, 'custom-file-view-12');
      expect(find.byType(Image), findsOneWidget);
      await closeViewer(tester);
      expect(api.writes, isEmpty, reason: 'viewing never writes');
    });

    testFiles('viewer without employees.edit: read-only list; tapping the name opens it in the app', (tester) async {
      await pumpEmployee(tester, as: viewer);
      expect(byKey('custom-file-readonly-cf_scan'), findsOneWidget);
      expect(byKey('custom-file-remove-12'), findsNothing);
      await tester.ensureVisible(find.text('scan.png'));
      await tester.tap(find.text('scan.png'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      await closeViewer(tester);
    });

    testFiles('an expired link: one fresh employee detail, then it opens', (tester) async {
      final h = defaultHost();
      final gate = SigGate(h, 's1');
      await pumpEmployee(tester, fileAdapter: gate);
      host = h;
      final before = api.detailGets;
      await tapKey(tester, 'custom-file-view-12');
      expect(api.detailGets, before + 1);
      expect(gate.seen, ['s1', 's${before + 1}']);
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      await closeViewer(tester);
    });

    testFiles('missing, disguised and unreachable files show the reason with Retry; Retry opens it', (tester) async {
      await pumpEmployee(tester);
      host.offline = true;
      await tapKey(tester, 'custom-file-view-11');
      expect(errorOf(tester, 11), kDocumentNetworkMessage);
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
      host.offline = false;
      await tapKey(tester, 'custom-file-retry-11');
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      await closeViewer(tester);
      expect(byKey('custom-file-error-11'), findsNothing);

      host.files.remove('scan');
      await tapKey(tester, 'custom-file-view-12');
      expect(errorOf(tester, 12), kDocumentNotFoundMessage);
      host.files['scan'] = (htmlBytes, 'text/html');
      await tapKey(tester, 'custom-file-retry-12');
      expect(errorOf(tester, 12), kDocumentUnsupportedMessage);
      host.files['scan'] = (pngBytes, 'image/png');
      await tapKey(tester, 'custom-file-retry-12');
      expect(errorOf(tester, 12), isNull);
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      await closeViewer(tester);
      expect(memFiles(), isEmpty);
    });

    testFiles('Remove still deletes through the existing endpoint', (tester) async {
      await pumpEmployee(tester);
      await tapKey(tester, 'custom-file-remove-11');
      expect(api.writes.single.method, 'DELETE');
      expect(api.writes.single.uri.path, '/api${ApiConstants.onboardingCustomFileFieldDetail(11)}');
    });
  });

  group('self-service block (My Profile)', () {
    Future<void> pumpBlock(WidgetTester tester, List<CustomFileValue> files, {bool editable = false}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      api = Api();
      host = defaultHost();
      mem = MemStore();
      await tester.pumpWidget(ProviderScope(
        overrides: overrides(hrUser(const []), host),
        child: MaterialApp(
          home: Scaffold(
            body: CustomFieldsBlock(
              step: 3,
              values: const {},
              files: files,
              canEditFiles: editable,
              onUpload: (_, __, ___) async => null,
              onDelete: (_) async => null,
            ),
          ),
        ),
      ));
      // As in the app, the signed-in user is loaded before anything is opened.
      await ProviderScope.containerOf(tester.element(find.byType(CustomFieldsBlock))).read(authStateProvider.future);
      await tester.pumpAndSettle();
    }

    CustomFileValue proxyFile(int id, String key, String name) => CustomFileValue(
          id: id,
          fieldKey: key,
          fileName: name,
          fileSize: 10,
          // As CustomFieldFileValueSerializer builds it behind the proxy.
          fileUrl: 'http://10.0.0.5:8000/api/onboarding/custom-file-fields/$id/',
        );

    testFiles('proxy links go to the app\'s API with the login; no expiry refresh is asked for', (tester) async {
      await pumpBlock(tester, [proxyFile(21, 'cf_proof', 'mine.pdf'), proxyFile(22, 'cf_scan', 'mine.png')]);
      api.proxy[21] = (200, pdfBytes, 'application/pdf');
      await tester.tap(find.text('mine.pdf'));
      await tester.pumpAndSettle();
      expect(errorOf(tester, 21), isNull);
      expect(byKey('fake-pdf-view'), findsOneWidget);
      final req = api.calls.lastWhere((c) => c.uri.path.contains('custom-file-fields'));
      expect(req.uri.toString(), 'https://hrms.test.invalid/api/onboarding/custom-file-fields/21/');
      expect(req.headers['Authorization'], 'Bearer $token');
      expect(host.calls, isEmpty, reason: 'nothing sent to the file host');
      await closeViewer(tester);
      expect(memFiles(), isEmpty);

      // The proxy's own errors: 404 and 502 (file host unavailable).
      await tester.tap(find.text('mine.png'));
      await tester.pumpAndSettle();
      expect(errorOf(tester, 22), kDocumentNotFoundMessage);
      api.proxy[22] = (502, utf8.encode('{"message":"File temporarily unavailable."}'), 'application/json');
      await tapKey(tester, 'custom-file-retry-22');
      expect(errorOf(tester, 22), kDocumentServerErrorMessage);
      api.proxy[22] = (403, utf8.encode('{}'), 'application/json');
      await tapKey(tester, 'custom-file-retry-22');
      expect(errorOf(tester, 22), kDocumentForbiddenMessage);
      api.proxy[22] = (200, pngBytes, 'image/png');
      await tapKey(tester, 'custom-file-retry-22');
      expect(find.byType(Image), findsOneWidget);
      await closeViewer(tester);
    });

    testFiles('editable self-service list: View next to Remove; a file without a link cannot be viewed',
        (tester) async {
      await pumpBlock(
          tester,
          [
            proxyFile(23, 'cf_proof', 'mine.pdf'),
            const CustomFileValue(id: 24, fieldKey: 'cf_scan', fileName: 'nolink.png', fileSize: 5),
          ],
          editable: true);
      expect(byKey('custom-file-view-23'), findsOneWidget);
      expect(byKey('custom-file-remove-23'), findsOneWidget);
      expect(tester.widget<IconButton>(byKey('custom-file-view-24')).onPressed, isNull);
    });
  });

  testWidgets('the onboarding wizard\'s file field is unchanged (no View, plain row)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: OnboardingCustomFileField(
            config: OnboardingFieldConfigModel.fromJson(cfg('cf_proof', 3)),
            files: const [CustomFileValue(id: 31, fieldKey: 'cf_proof', fileName: 'w.pdf', fileSize: 2048)],
            onUpload: (_, __, ___) async => null,
            onDelete: (_) async => null,
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('w.pdf · 2 KB'), findsOneWidget);
    expect(byKey('custom-file-view-31'), findsNothing);
    expect(byKey('custom-file-remove-31'), findsOneWidget);
  });
}
