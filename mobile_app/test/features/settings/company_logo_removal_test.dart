import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/presentation/company/company_screen.dart';
import 'package:mobile_app/features/settings/presentation/providers/settings_providers.dart';

// P1-3 (corrected to web): Company logo removal follows web's company form
// (settings/company/page.tsx): Remove only marks the logo locally (no request,
// no confirmation); Save sends ONE multipart PUT /settings/company/ with the
// form fields plus `logo` (a picked file) or else `remove_logo=true` (a pending
// removal). Production CompanyRetrieveUpdateView clears the logo on
// remove_logo=true and returns logo_url null; settings.edit, else 403.
// Synthetic company data; mocked Dio only — nothing real is removed/uploaded.

const oldLogo = 'https://cdn.example.test/logos/old.png';
const newLogo = 'https://cdn.example.test/logos/new.png';

class Server implements HttpClientAdapter {
  Map<String, dynamic> company = {
    'id': 1,
    'company_name': 'Test Company Pvt Ltd',
    'trade_name': 'Test Co',
    'logo_url': oldLogo,
    'gstin': '27AAPFU0939F1ZV',
    'cin': 'U74999MH2020PTC123456',
    'pan': 'AAPFU0939F',
    'tan': 'MUMA12345B',
    'address': '1 Test Street',
    'city': 'Mumbai',
    'state': 'Maharashtra',
    'pin_code': '400001',
    'website': 'https://example.test',
    'official_phone': '022 1234 5678',
    'updated_at': '2026-11-01T10:00:00Z',
  };
  final puts = <Object?>[];
  int putStatus = 200;
  Completer<void>? holdPut;

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path != ApiConstants.settingsCompany) {
      return _json({'status': 'success', 'data': {}});
    }
    if (o.method == 'GET') return _json({'status': 'success', 'message': 'ok', 'data': company});
    if (o.method == 'PUT') {
      puts.add(o.data);
      final gate = holdPut;
      if (gate != null) await gate.future;
      if (putStatus != 200) {
        return _json({'status': 'error', 'message': 'Could not update company info right now.', 'data': {}}, putStatus);
      }
      final d = o.data;
      if (d is FormData) {
        for (final f in d.fields) {
          if (f.key != 'remove_logo') company[f.key] = f.value;
        }
        if (d.files.any((f) => f.key == 'logo')) company['logo_url'] = newLogo;
        if (d.fields.any((f) => f.key == 'remove_logo' && f.value.toLowerCase() == 'true')) {
          company['logo_url'] = null;
        }
      } else if (d is Map) {
        company.addAll(Map<String, dynamic>.from(d));
      }
      return _json({'status': 'success', 'message': 'Company info saved successfully.', 'data': company});
    }
    return _json({'status': 'error', 'message': 'Method not allowed'}, 405);
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

UserEntity user(List<String> perms) => UserEntity(
      id: 'u1',
      email: 'admin@example.test',
      fullName: 'Test Admin',
      role: 'system_admin',
      roleDisplay: 'Admin',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final editor = user(['settings.view', 'settings.edit']);
final viewer = user(['settings.view']);

late Server server;
File? nextPick;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      companyLogoPickerProvider.overrideWithValue(() async => nextPick),
    ];

Future<void> pumpScreen(WidgetTester tester, {UserEntity? as, Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  final router = GoRouter(initialLocation: AppRoutes.settingsCompany, routes: [
    GoRoute(path: AppRoutes.settingsCompany, builder: (_, __) => const CompanyScreen()),
  ]);
  await tester.pumpWidget(ProviderScope(overrides: overrides(as ?? editor), child: MaterialApp.router(routerConfig: router)));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

Finder networkLogo(String url) =>
    find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage && (w.image as NetworkImage).url == url);

Finder anyNetworkLogo() => find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage);

Finder fileLogo() => find.byWidgetPredicate((w) => w is Image && w.image is FileImage);

Map<String, String> fieldMap(Object? body) => {for (final f in (body as FormData).fields) f.key: f.value};

const companyKeys = [
  'company_name', 'trade_name', 'gstin', 'cin', 'pan', 'tan', 'address', 'city', 'state', 'pin_code', 'website',
  'official_phone',
];

Future<void> tapRemove(WidgetTester tester) async {
  await tester.tap(byKey('company-logo-remove'));
  await tester.pumpAndSettle();
}

Future<void> pick(WidgetTester tester, File f) async {
  nextPick = f;
  await tester.tap(byKey('company-logo-change'));
  await tester.pumpAndSettle();
}

/// Save. A picked file is read from disk by MultipartFile.fromFile, which
/// needs real async I/O, so the tap runs under runAsync.
Future<void> save(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(find.text('Save Changes'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pumpAndSettle();
}

late Directory tmp;

File tempImage(String name) => File('${tmp.path}/$name')..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    tmp = Directory.systemTemp.createTempSync('company_logo_test');
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));
  setUp(() => nextPick = null);

  group('Remove is local until Save (web handleLogoRemove)', () {
    testWidgets('Remove makes no request, shows no confirmation, and hides the logo in the preview', (tester) async {
      await pumpScreen(tester);
      expect(networkLogo(oldLogo), findsOneWidget);
      await tapRemove(tester);
      expect(server.puts, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(anyNetworkLogo(), findsNothing);
      expect(byKey('company-logo-remove'), findsNothing, reason: 'nothing left to remove');
      expect(server.company['logo_url'], oldLogo, reason: 'server untouched');
    });

    testWidgets('leaving without saving keeps the server logo (reopen shows it again)', (tester) async {
      final s = Server();
      await pumpScreen(tester, with_: s);
      await tapRemove(tester);
      await tester.pumpWidget(const SizedBox()); // navigate away / discard
      await pumpScreen(tester, with_: s);
      expect(s.puts, isEmpty);
      expect(networkLogo(oldLogo), findsOneWidget);
    });

    testWidgets('Save after Remove sends one multipart PUT: all form fields + remove_logo=true, no file',
        (tester) async {
      await pumpScreen(tester);
      await tapRemove(tester);
      await save(tester);
      expect(server.puts, hasLength(1));
      final body = server.puts.single;
      expect(body, isA<FormData>());
      final f = fieldMap(body);
      expect(f['remove_logo'], 'true');
      expect(f.keys, containsAll(companyKeys));
      expect(f['company_name'], 'Test Company Pvt Ltd');
      expect((body as FormData).files, isEmpty);
      expect(server.company['logo_url'], isNull);
      expect(anyNetworkLogo(), findsNothing);
      expect(find.text('Company info saved successfully.'), findsOneWidget);
    });

    testWidgets('other unsaved edits are saved together with the removal', (tester) async {
      await pumpScreen(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Test Company Pvt Ltd'), 'Edited Name Ltd');
      await tapRemove(tester);
      expect(find.widgetWithText(TextFormField, 'Edited Name Ltd'), findsOneWidget);
      await save(tester);
      final f = fieldMap(server.puts.single);
      expect(f['company_name'], 'Edited Name Ltd');
      expect(f['remove_logo'], 'true');
    });

    testWidgets('after a successful Save the pending removal is cleared: the next Save sends no logo keys',
        (tester) async {
      await pumpScreen(tester);
      await tapRemove(tester);
      await save(tester);
      await tester.pumpAndSettle(const Duration(seconds: 5)); // snackbar away
      await save(tester);
      expect(server.puts, hasLength(2));
      final second = server.puts.last;
      expect(second, isA<Map>(), reason: 'an ordinary save, as before (JSON)');
      expect((second as Map).containsKey('remove_logo'), isFalse);
      expect(second.containsKey('logo'), isFalse);
    });
  });

  group('replacement image (web precedence: logo file wins; pick clears removal; Remove clears pick)', () {
    testWidgets('Pick → Save uploads the file as `logo` with the fields and no remove_logo', (tester) async {
      await pumpScreen(tester);
      await pick(tester, tempImage('new.png'));
      expect(fileLogo(), findsOneWidget);
      await save(tester);
      final body = server.puts.single as FormData;
      expect(body.files.single.key, 'logo');
      expect(body.files.single.value.filename, 'new.png');
      expect(fieldMap(body).containsKey('remove_logo'), isFalse);
      expect(fieldMap(body).keys, containsAll(companyKeys));
      expect(networkLogo(newLogo), findsOneWidget, reason: 'shows the server\'s new logo');
      expect(fileLogo(), findsNothing, reason: 'picked file cleared');
    });

    testWidgets('Remove then Pick → Save uploads the new file (the pick cancels the removal)', (tester) async {
      await pumpScreen(tester);
      await tapRemove(tester);
      await pick(tester, tempImage('replacement.png'));
      await save(tester);
      final body = server.puts.single as FormData;
      expect(body.files.single.key, 'logo');
      expect(fieldMap(body).containsKey('remove_logo'), isFalse);
      expect(server.company['logo_url'], newLogo);
    });

    testWidgets('Pick then Remove → Save sends remove_logo=true and no file (Remove drops the pick)',
        (tester) async {
      await pumpScreen(tester);
      await pick(tester, tempImage('discarded.png'));
      await tapRemove(tester);
      expect(fileLogo(), findsNothing);
      expect(anyNetworkLogo(), findsNothing, reason: 'web: removed → no logo shown');
      expect(server.puts, isEmpty);
      await save(tester);
      final body = server.puts.single as FormData;
      expect(body.files, isEmpty);
      expect(fieldMap(body)['remove_logo'], 'true');
      expect(server.company['logo_url'], isNull);
    });
  });

  group('failure and retry', () {
    testWidgets('a failed Save keeps the saved logo on the server, the pending removal and the form; retry works',
        (tester) async {
      await pumpScreen(tester, with_: Server()..putStatus = 500);
      await tester.enterText(find.widgetWithText(TextFormField, 'Test Company Pvt Ltd'), 'Edited Name Ltd');
      await tapRemove(tester);
      await save(tester);
      expect(find.text('Could not update company info right now.'), findsOneWidget);
      expect(server.company['logo_url'], oldLogo, reason: 'server state unchanged');
      expect(anyNetworkLogo(), findsNothing, reason: 'pending removal kept for retry');
      expect(find.widgetWithText(TextFormField, 'Edited Name Ltd'), findsOneWidget);
      expect(find.text('Company Name *'), findsOneWidget, reason: 'form still shown (no error screen)');

      server.putStatus = 200;
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await save(tester);
      expect(server.puts, hasLength(2));
      final f = fieldMap(server.puts.last);
      expect(f['remove_logo'], 'true');
      expect(f['company_name'], 'Edited Name Ltd');
      expect(server.company['logo_url'], isNull);
      expect(find.text('Company info saved successfully.'), findsOneWidget);
    });

    test('a failed save leaves the provider on the saved company (logo included)', () async {
      server = Server()..putStatus = 500;
      final c = ProviderContainer(overrides: overrides(editor));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      c.listen(companyProvider, (_, __) {});
      await c.read(companyProvider.future);
      final model = c.read(companyProvider).requireValue;
      expect(await c.read(companyProvider.notifier).save(model, removeLogo: true),
          'Could not update company info right now.');
      expect(c.read(companyProvider).hasError, isFalse);
      expect(c.read(companyProvider).requireValue.logoUrl, oldLogo);
    });
  });

  group('ordinary saves and other callers', () {
    Future<ProviderContainer> signedIn(Server s, [UserEntity? u]) async {
      server = s;
      final c = ProviderContainer(overrides: overrides(u ?? editor));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      c.listen(companyProvider, (_, __) {});
      await c.read(companyProvider.future);
      return c;
    }

    testWidgets('a Save with no logo change neither removes nor re-uploads the logo', (tester) async {
      await pumpScreen(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Mumbai'), 'Pune');
      await save(tester);
      final body = server.puts.single;
      expect(body, isA<Map>());
      expect((body as Map)['city'], 'Pune');
      expect(body.containsKey('remove_logo'), isFalse);
      expect(body.containsKey('logo'), isFalse);
      expect(server.company['logo_url'], oldLogo);
      expect(networkLogo(oldLogo), findsOneWidget);
    });

    test('email-branding style save (fields only, or with a new logo file) still works', () async {
      final c = await signedIn(Server());
      final model = c.read(companyProvider).requireValue.copyWith(website: 'https://brand.example.test');
      expect(await c.read(companyProvider.notifier).save(model), isNull);
      expect((server.puts.single as Map)['website'], 'https://brand.example.test');
      expect(c.read(companyProvider).requireValue.logoUrl, oldLogo);

      final file = tempImage('brand.png');
      expect(await c.read(companyProvider.notifier).save(model, logoFile: file), isNull);
      final body = server.puts.last as FormData;
      expect(body.files.single.key, 'logo');
      expect(fieldMap(body).containsKey('remove_logo'), isFalse);
      expect(c.read(companyProvider).requireValue.logoUrl, newLogo);
    });

    test('a logo file takes precedence over removeLogo (web: if logoFile … else if logoRemoved)', () async {
      final c = await signedIn(Server());
      final model = c.read(companyProvider).requireValue;
      expect(await c.read(companyProvider.notifier).save(model, logoFile: tempImage('p.png'), removeLogo: true),
          isNull);
      final body = server.puts.single as FormData;
      expect(body.files.single.key, 'logo');
      expect(fieldMap(body).containsKey('remove_logo'), isFalse);
    });
  });

  group('permissions', () {
    testWidgets('without settings.edit there is no Remove/Change control and no Save', (tester) async {
      await pumpScreen(tester, as: viewer);
      expect(networkLogo(oldLogo), findsOneWidget);
      expect(byKey('company-logo-remove'), findsNothing);
      expect(byKey('company-logo-change'), findsNothing);
      expect(find.text('Save Changes'), findsNothing);
    });

    test('the provider refuses a removal save without settings.edit, before any request', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(viewer));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      c.listen(companyProvider, (_, __) {});
      await c.read(companyProvider.future);
      final model = c.read(companyProvider).requireValue;
      expect(await c.read(companyProvider.notifier).save(model, removeLogo: true), kSettingsEditDenied);
      expect(server.puts, isEmpty);
      expect(c.read(companyProvider).requireValue.logoUrl, oldLogo);
    });
  });
}
