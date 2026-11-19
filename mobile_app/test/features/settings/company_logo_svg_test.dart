import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart'
    show employeeDocumentExternalDioProvider;
import 'package:mobile_app/features/settings/presentation/company/company_logo_svg.dart';
import 'package:mobile_app/features/settings/presentation/company/company_screen.dart';
import 'package:mobile_app/features/settings/presentation/company/widgets/company_widgets.dart';

// Task 100.1 — SVG company-logo preview (flutter_svg). The saved logo is
// fetched once through the login-free client; nothing is written to disk.
// Synthetic SVGs and fake servers only.

const okSvg = '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="40" viewBox="0 0 100 40">'
    '<rect width="100" height="40" fill="#1E4E8C"/></svg>';
const wideSvg = '<svg xmlns="http://www.w3.org/2000/svg" width="2000" height="100" viewBox="0 0 2000 100">'
    '<rect width="2000" height="100" fill="#219653"/></svg>';
const brokenSvg = '<svg xmlns="http://www.w3.org/2000/svg" width="100"><rect width=';
const unsupportedSvg = '<svg xmlns="http://www.w3.org/2000/svg" width="50" height="50">'
    '<foreignObject width="50" height="50"><div>hi</div></foreignObject><script>alert(1)</script></svg>';

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

const svgUrl = 'https://cdn.example.test/logos/company.svg?sig=SECRET123&exp=999';
const pngUrl = 'https://cdn.example.test/logos/company.png';

/// Records every request the login-free client makes.
class _ExternalServer implements HttpClientAdapter {
  _ExternalServer({this.body = okSvg, this.status = 200});
  Object body;
  int status;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    requests.add(o);
    if (status != 200) return ResponseBody.fromString('nope', status);
    final data = body is Uint8List ? body as Uint8List : bytes('$body');
    return ResponseBody.fromBytes(data, 200, headers: {
      Headers.contentTypeHeader: ['image/svg+xml'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<void> settleSvg(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<void> pumpLogo(
  WidgetTester tester, {
  String? url,
  File? file,
  Future<Uint8List?> Function(String)? loader,
  Size size = const Size(400, 300),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [if (loader != null) companyLogoSvgLoaderProvider.overrideWithValue(loader)],
    child: MaterialApp(
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: Center(child: CompanyLogoView(url: url, file: file))),
    ),
  ));
  await settleSvg(tester);
}

late Directory tmp;
File svgFile(String name, String content) => File('${tmp.path}/$name')..writeAsStringSync(content);

final iconFinder = find.byIcon(Icons.business_outlined);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    tmp = Directory.systemTemp.createTempSync('company_svg_t1001');
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  group('recognising SVG', () {
    test('by URL path, ignoring query, fragment and case', () {
      expect(isSvgUrl('https://x.test/a/logo.svg'), isTrue);
      expect(isSvgUrl('https://x.test/a/LOGO.SVG?sig=abc#f'), isTrue);
      expect(isSvgUrl('https://x.test/a/logo.png?name=x.svg'), isFalse);
      expect(isSvgUrl('https://x.test/a/logo'), isFalse);
      expect(isSvgUrl('https://x.test/a/logo.svgz'), isFalse);
      expect(isSvgUrl(''), isFalse);
    });

    test('by content: an <svg> root, after a declaration, comment or doctype', () {
      expect(looksLikeSvg(bytes(okSvg)), isTrue);
      expect(
          looksLikeSvg(bytes('<?xml version="1.0"?>\n<!-- c -->\n<!DOCTYPE svg>\n<svg viewBox="0 0 1 1"/>')), isTrue);
      expect(looksLikeSvg(bytes('﻿<SVG xmlns="x"></SVG>')), isTrue);
      expect(looksLikeSvg(bytes('<html><body>404</body></html>')), isFalse);
      expect(looksLikeSvg(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0])), isFalse);
      expect(looksLikeSvg(bytes('<svgx/>')), isFalse);
      expect(looksLikeSvg(Uint8List(0)), isFalse);
    });
  });

  group('fetching a saved SVG (one login-free request)', () {
    Future<(ProviderContainer, _ExternalServer)> setup(_ExternalServer s) async {
      final dio = Dio()..httpClientAdapter = s;
      final c = ProviderContainer(overrides: [employeeDocumentExternalDioProvider.overrideWithValue(dio)]);
      addTearDown(c.dispose);
      return (c, s);
    }

    Future<Uint8List?> load(ProviderContainer c, String url) => c.read(companyLogoSvgLoaderProvider)(url);

    test('https SVG → bytes, one request, no app credentials, signature kept off the wire headers', () async {
      final (c, s) = await setup(_ExternalServer());
      expect(await load(c, svgUrl), isNotNull);
      expect(s.requests, hasLength(1));
      final h = s.requests.single.headers.map((k, v) => MapEntry(k.toLowerCase(), '$v'));
      expect(h.containsKey('authorization'), isFalse);
      expect(h.containsKey('cookie'), isFalse);
      expect(h.values.any((v) => v.contains('SECRET123')), isFalse);
    });

    test('http, malformed URL and empty URL are refused without any request', () async {
      final (c, s) = await setup(_ExternalServer());
      expect(await load(c, 'http://cdn.example.test/a.svg'), isNull);
      expect(await load(c, 'not a url'), isNull);
      expect(await load(c, '/relative/a.svg'), isNull);
      expect(await c.read(companyLogoSvgProvider('').future), isNull);
      expect(s.requests, isEmpty);
    });

    test('a non-SVG body, an error status and an oversized file give nothing', () async {
      expect(await load((await setup(_ExternalServer(body: '<html>oops</html>'))).$1, svgUrl), isNull);
      expect(await load((await setup(_ExternalServer(status: 404))).$1, svgUrl), isNull);
      final big = Uint8List(kCompanyLogoSvgMaxBytes + 1)..setAll(0, bytes('<svg>'));
      expect(await load((await setup(_ExternalServer(body: big))).$1, svgUrl), isNull);
      final edge = Uint8List(kCompanyLogoSvgMaxBytes)..setAll(0, bytes('<svg>'));
      expect(await load((await setup(_ExternalServer(body: edge))).$1, svgUrl), isNotNull);
    });
  });

  group('the logo view', () {
    testWidgets('a valid saved SVG is drawn (no fallback icon, no raster request)', (tester) async {
      var calls = 0;
      await pumpLogo(tester, url: svgUrl, loader: (u) async {
        calls++;
        return bytes(okSvg);
      });
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(iconFinder, findsNothing);
      expect(find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage), findsNothing,
          reason: 'an SVG link must not also be fetched as a raster image');
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('while it downloads, and when it fails, the logo icon shows', (tester) async {
      await pumpLogo(tester, url: svgUrl, loader: (u) async => null);
      expect(find.byType(SvgPicture), findsNothing);
      expect(iconFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a malformed SVG falls back to the icon without an error', (tester) async {
      await pumpLogo(tester, url: svgUrl, loader: (u) async => bytes(brokenSvg));
      expect(iconFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an SVG with unsupported elements and a script renders safely', (tester) async {
      await pumpLogo(tester, url: svgUrl, loader: (u) async => bytes(unsupportedSvg));
      expect(tester.takeException(), isNull);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('raster logos are unchanged: PNG/WebP/JPEG links stay on Image.network, loader untouched',
        (tester) async {
      var calls = 0;
      for (final u in [pngUrl, 'https://cdn.example.test/l.webp', 'https://cdn.example.test/l.jpg']) {
        await pumpLogo(tester, url: u, loader: (_) async {
          calls++;
          return null;
        });
        expect(
            find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage && (w.image as NetworkImage).url == u),
            findsOneWidget,
            reason: u);
        expect(find.byType(SvgPicture), findsNothing);
      }
      expect(calls, 0);
    });

    testWidgets('no logo → the icon; no request', (tester) async {
      var calls = 0;
      await pumpLogo(tester, loader: (_) async {
        calls++;
        return null;
      });
      expect(iconFinder, findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('a picked SVG file previews; an invalid one falls back safely', (tester) async {
      await pumpLogo(tester, file: svgFile('ok.svg', okSvg));
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(iconFinder, findsNothing);
      expect(tester.takeException(), isNull);

      await pumpLogo(tester, file: svgFile('bad.svg', brokenSvg));
      expect(iconFinder, findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpLogo(tester, file: svgFile('junk.svg', 'not xml at all'));
      expect(iconFinder, findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpLogo(tester, file: svgFile('empty.svg', ''));
      expect(iconFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a picked raster file is still an Image.file', (tester) async {
      final png = File('${tmp.path}/p.png')..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);
      await pumpLogo(tester, file: png);
      expect(find.byWidgetPredicate((w) => w is Image && w.image is FileImage), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('a very wide SVG stays inside the logo box (contain)', (tester) async {
      await pumpLogo(tester, url: svgUrl, loader: (u) async => bytes(wideSvg));
      final box = tester.getSize(find.byType(CompanyLogoView));
      expect(box, const Size(72, 72));
      expect(tester.getSize(find.byType(SvgPicture)).width, lessThanOrEqualTo(72));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a 320 px screen at 2.0× text', (tester) async {
      await pumpLogo(tester, url: svgUrl, loader: (u) async => bytes(okSvg), size: const Size(320, 568), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('on the Company Information screen', () {
    Future<_Screen> pumpScreen(WidgetTester tester,
        {String? logo,
        Future<Uint8List?> Function(String)? loader,
        Size size = const Size(412, 3000),
        double textScale = 1}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = _Screen(logo);
      final router = GoRouter(initialLocation: AppRoutes.settingsCompany, routes: [
        GoRoute(path: AppRoutes.settings, builder: (_, __) => const Scaffold()),
        GoRoute(path: AppRoutes.settingsCompany, builder: (_, __) => const CompanyScreen()),
      ]);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          authStateProvider.overrideWith(() => _Auth()),
          dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullStorage()),
          companyLogoPickerProvider.overrideWithValue(() async => s.pick),
          if (loader != null) companyLogoSvgLoaderProvider.overrideWithValue(loader),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ));
      await tester.pumpAndSettle(); // drawing itself is verified in 'the logo view' (no screen fonts there)
      return s;
    }

    testWidgets('a saved SVG logo shows in the header; Remove clears the preview and is sent on Save', (tester) async {
      final s = await pumpScreen(tester, logo: svgUrl, loader: (u) async => bytes(okSvg));
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('Logo set.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('company-logo-remove')));
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.text('The logo will be removed when you save.'), findsOneWidget);
      expect(s.puts, isEmpty);

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect({for (final f in s.puts.single.fields) f.key: f.value}['remove_logo'], 'true');
    });

    testWidgets('Remove works the same for a raster logo', (tester) async {
      final s = await pumpScreen(tester, logo: pngUrl);
      expect(find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage), findsOneWidget);
      await tester.tap(find.byKey(const Key('company-logo-remove')));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage), findsNothing);
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect({for (final f in s.puts.single.fields) f.key: f.value}['remove_logo'], 'true');
    });

    testWidgets('picking an SVG previews it and uploads it as `logo` unchanged', (tester) async {
      final s = await pumpScreen(tester, loader: (u) async => null);
      s.pick = svgFile('upload.svg', okSvg);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('company-logo-change')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.textContaining('New logo selected: upload.svg'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Save Changes'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(s.puts.single.files.single.key, 'logo');
      expect(s.puts.single.files.single.value.filename, 'upload.svg');
    });

    testWidgets('a broken saved SVG leaves the screen intact (icon, no error, form still works)', (tester) async {
      await pumpScreen(tester, logo: svgUrl, loader: (u) async => bytes(brokenSvg));
      expect(tester.takeException(), isNull);
      expect(find.text('Company Name *'), findsOneWidget);
    });

    testWidgets('responsive: 320×568 at 2.0× text with an SVG logo', (tester) async {
      await pumpScreen(tester,
          logo: svgUrl, loader: (u) async => bytes(wideSvg), size: const Size(320, 568), textScale: 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('responsive: tablet', (tester) async {
      await pumpScreen(tester, logo: svgUrl, loader: (u) async => bytes(okSvg), size: const Size(1000, 800));
      expect(tester.takeException(), isNull);
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'u1',
          email: 'admin@example.test',
          fullName: 'Test Admin',
          role: 'hr_admin',
          roleDisplay: 'Admin',
          mustChangePassword: false,
          permissions: ['settings.view', 'settings.edit'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

class _NullStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class _Screen implements HttpClientAdapter {
  _Screen(this.logo);
  final String? logo;
  File? pick;
  final puts = <FormData>[];

  ResponseBody _json(Object body) => ResponseBody.fromString(jsonEncode(body), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  Map<String, dynamic> get company => {
        'id': 1,
        'company_name': 'Test Company Pvt Ltd',
        'trade_name': 'Test Co',
        'logo_url': logo,
        'gstin': '27AAPFU0939F1ZV',
        'cin': 'U74999MH2020PTC123456',
        'pan': 'AAPFU0939F',
        'tan': 'MUMA12345B',
        'address': '1 Test Street',
        'city': 'Mumbai',
        'state': 'Maharashtra',
        'pin_code': '400001',
        'website': '',
        'official_phone': '',
        'updated_at': '2026-11-05T10:15:00Z',
      };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    if (o.method == 'GET' && o.path == '/settings/company/') {
      return _json({'status': 'success', 'message': 'ok', 'data': company});
    }
    if (o.method == 'PUT' && o.path == '/settings/company/') {
      puts.add(o.data as FormData);
      return _json({
        'status': 'success',
        'message': 'saved',
        'data': {...company, 'logo_url': null}
      });
    }
    if (o.path == '/settings/company/financial-year/') {
      return _json({
        'status': 'success',
        'data': {
          'financial_year_start_month': 'April',
          'previous_financial_year': '2025-26',
          'current_financial_year': '2026-27',
          'next_financial_year': '2027-28',
        },
      });
    }
    return _json({'status': 'success', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}
