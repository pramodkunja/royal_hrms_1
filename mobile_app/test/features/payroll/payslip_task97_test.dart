import 'dart:convert';
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
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart'
    show employeeDocumentExternalDioProvider;
import 'package:mobile_app/features/payroll/data/models/payslip_model.dart';
import 'package:mobile_app/features/payroll/presentation/payslip_images.dart';
import 'package:mobile_app/features/payroll/presentation/payslip_pdf.dart';
import 'package:mobile_app/features/payroll/presentation/screens/my_payslip_screen.dart';
import 'package:pdf/pdf.dart';

import 'payslip_document_parity_test.dart' as h;

// Task 97, Phase 1: My Payslip's remaining Flutter-only gaps — the company
// logo in the standard letterhead (web PayslipDocument.tsx: max 48 × 160,
// contain), the sidebar employee card (my-payslip/page.tsx:291-316: initials,
// name, designation, ID, Department, Date of Join; the month list with pay
// dates) and the wage-slip stamp embedded in the PDF (WageSlipDocument.tsx
// .ws-stamp, max 80 × 140). Web shows the logo/stamp through <img src>, i.e.
// fetched directly with no login; mobile fetches the bytes with the login-free
// file client and keeps them in memory only. Synthetic data; stand-in servers.

/// A valid 1×1 PNG.
final png =
    base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

const logoUrl = 'https://files.invalid/media/company/logo.png';
const stampUrl = 'https://files.invalid/signed/stamp.png?signature=SECRETSIG';

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class PayslipServer extends h.Server {
  PayslipServer(super.payslips, {this.logo = logoUrl, this.me = true});
  final String? logo;
  final bool me;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path == '/settings/company/') {
      return _json(200, {
        'status': 'success',
        'data': {
          'id': 1,
          'company_name': 'Test Co',
          'cin': 'U00000TS2026PTC000000',
          'address': '1 Test Road',
          'city': 'Test City',
          'state': 'Test State',
          'pin_code': '500001',
          'official_phone': '+91 90000 00000',
          'logo_url': logo,
        }
      });
    }
    if (o.path == '/employees/me/') {
      if (!me) return _json(500, {'status': 'error', 'message': 'Server error.'});
      return _json(200, {
        'status': 'success',
        'data': {
          'id': 'u1',
          'full_name': 'Test Person',
          'employee_id': 'TST001',
          'department': 'Finance',
          'designation': 'Senior Analyst',
          'date_of_joining': '2026-01-05',
          'profile': {'bank_name': 'Test Bank', 'account_number': '000123456789', 'ifsc_code': 'TEST0001234'},
        }
      });
    }
    return super.fetch(o, s, c);
  }
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'u1',
          email: 'e@example.test',
          fullName: 'Test Person',
          role: 'employee',
          roleDisplay: 'Employee',
          mustChangePassword: false,
          permissions: ['payroll.view_own'],
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

final requested = <String>[];
final printed = <Uint8List>[];

/// [images] maps a URL to its bytes (anything else → null).
Future<void> pumpScreen(WidgetTester tester, List<Map<String, dynamic>> slips,
    {PayslipServer? server, Map<String, Uint8List> images = const {}}) async {
  tester.view.physicalSize = const Size(1080, 5600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  requested.clear();
  printed.clear();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(
          Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server ?? PayslipServer(slips)),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      authStateProvider.overrideWith(_Auth.new),
      payslipImageLoaderProvider.overrideWithValue((url) async {
        requested.add(url);
        return images[url];
      }),
      payslipPdfOutputProvider.overrideWithValue(PayslipPdfOutput(
        print: (layout, name) async {
          printed.add(await layout(PdfPageFormat.a4));
          return true;
        },
        share: (bytes, filename) async {
          printed.add(bytes);
          return true;
        },
      )),
    ],
    child: const MaterialApp(home: Scaffold(body: MyPayslipScreen())),
  ));
  await tester.pumpAndSettle();
}

Map<String, dynamic> wageSlip({String? stamp = stampUrl}) => h.slip(extra: {
      'payslip_template': 'wage_slip',
      'cycle_end': '2026-09-30',
      'designation': 'Analyst',
      'stamp_url': stamp,
    });

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

Future<void> tapAndBuild(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500)));
  await tester.pumpAndSettle();
}

/// How many image objects the PDF holds. One RGBA picture is stored as an
/// image plus its alpha mask, so compare counts rather than expect exactly 1.
int pdfImages(Uint8List b) => RegExp('/Subtype */Image').allMatches(latin1.decode(b)).length;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('company logo (standard letterhead)', () {
    testWidgets('shown above the company line, web size limits (max 48 high, 160 wide, contain)', (tester) async {
      await pumpScreen(tester, [h.slip()], images: {logoUrl: png});
      expect(find.byKey(const Key('payslip-logo')), findsOneWidget);
      final box = tester.widget<ConstrainedBox>(
          find.ancestor(of: find.byKey(const Key('payslip-logo')), matching: find.byType(ConstrainedBox)).first);
      expect((box.constraints.maxHeight, box.constraints.maxWidth), (48, 160));
      expect(tester.widget<Image>(find.byKey(const Key('payslip-logo'))).fit, BoxFit.contain);
      expect(tester.getTopLeft(find.byKey(const Key('payslip-logo'))).dy,
          lessThan(tester.getTopLeft(find.textContaining('Test Co · CIN')).dy));
      expect(requested, [logoUrl], reason: 'only the company logo link is fetched for this layout');
    });

    testWidgets('no logo configured, or the image cannot be loaded → nothing drawn, nothing broken', (tester) async {
      await pumpScreen(tester, [h.slip()], server: PayslipServer([h.slip()], logo: null));
      expect(find.byKey(const Key('payslip-logo')), findsNothing);
      expect(requested, isEmpty);
      expect(find.textContaining('Test Co · CIN'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpScreen(tester, [h.slip()], images: const {}); // loader answers null
      expect(find.byKey(const Key('payslip-logo')), findsNothing);
      expect(find.textContaining('Test Co · CIN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the wage-slip layout has no logo (as web) and never requests it', (tester) async {
      await pumpScreen(tester, [wageSlip(stamp: null)], images: {logoUrl: png});
      expect(find.byKey(const Key('payslip-logo')), findsNothing);
      expect(requested, isEmpty);
    });

    testWidgets('the link itself is never shown as text', (tester) async {
      await pumpScreen(tester, [h.slip()], images: {logoUrl: png});
      expect(find.textContaining('files.invalid'), findsNothing);
    });
  });

  group('sidebar employee card and month list (web my-payslip sidebar)', () {
    testWidgets('initials, name, designation, ID, Department and Date of Join from the employee record',
        (tester) async {
      await pumpScreen(tester, [h.slip()]);
      expect(textOf(tester, 'payslip-emp-initials'), 'TP');
      expect(textOf(tester, 'payslip-emp-name'), 'Test Person');
      expect(textOf(tester, 'payslip-emp-designation'), 'Senior Analyst');
      expect(textOf(tester, 'payslip-emp-id'), 'TST001');
      expect(textOf(tester, 'payslip-emp-department'), 'Finance');
      expect(textOf(tester, 'payslip-emp-doj'), '05 Jan 2026');
      expect(find.text('DEPARTMENT'), findsOneWidget);
      expect(find.text('DATE OF JOIN'), findsOneWidget);
    });

    testWidgets('while the record is unavailable: "—" everywhere (web), payslip still shown', (tester) async {
      await pumpScreen(tester, [h.slip()], server: PayslipServer([h.slip()], me: false));
      for (final k in ['payslip-emp-initials', 'payslip-emp-name', 'payslip-emp-designation', 'payslip-emp-id']) {
        expect(textOf(tester, k), '—', reason: k);
      }
      expect(textOf(tester, 'payslip-emp-department'), '—');
      expect(textOf(tester, 'payslip-emp-doj'), '—');
      expect(textOf(tester, 'payslip-net-amount'), '₹1,17,297');
    });

    testWidgets('month list: "Select Month" heading and each month\'s pay date', (tester) async {
      await pumpScreen(tester, [
        h.slip(id: 'a'),
        h.slip(id: 'b', extra: {'cycle_start': '2026-08-01', 'pay_date': '2026-08-31'}),
      ]);
      expect(find.text('SELECT MONTH'), findsOneWidget);
      expect(textOf(tester, 'payslip-month-paydate-a'), '30 Sept 2026');
      expect(textOf(tester, 'payslip-month-paydate-b'), '31 Aug 2026');
    });
  });

  group('wage-slip stamp', () {
    testWidgets('on screen: the fetched image above "Authorized Signature" (max 80 × 140); link never shown',
        (tester) async {
      await pumpScreen(tester, [wageSlip()], images: {stampUrl: png});
      expect(find.byKey(const Key('wageslip-stamp')), findsOneWidget);
      final box = tester.widget<ConstrainedBox>(
          find.ancestor(of: find.byKey(const Key('wageslip-stamp')), matching: find.byType(ConstrainedBox)).first);
      expect((box.constraints.maxHeight, box.constraints.maxWidth), (80, 140));
      expect(tester.getTopLeft(find.byKey(const Key('wageslip-stamp'))).dy,
          lessThan(tester.getTopLeft(find.text('Authorized Signature')).dy));
      expect(find.textContaining('SECRETSIG'), findsNothing);
      expect(find.textContaining('files.invalid'), findsNothing);
    });

    testWidgets('no stamp, or an unusable image → just the signature line', (tester) async {
      await pumpScreen(tester, [wageSlip(stamp: null)]);
      expect(find.byKey(const Key('wageslip-stamp')), findsNothing);
      expect(requested, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await pumpScreen(tester, [wageSlip()], images: const {});
      expect(find.byKey(const Key('wageslip-stamp')), findsNothing);
      expect(find.text('Authorized Signature'), findsOneWidget);
    });
  });

  group('PDF output with the real image bytes', () {
    testWidgets('Print: the wage slip embeds the stamp image; the signed link is nowhere in the file', (tester) async {
      await pumpScreen(tester, [wageSlip()], images: {stampUrl: png});
      await tapAndBuild(tester, 'payslip-print-pdf');
      expect(printed, hasLength(1));
      expect(pdfImages(printed.single), greaterThan(0));
      final raw = latin1.decode(printed.single);
      expect(raw.contains('SECRETSIG'), isFalse);
      expect(raw.contains('files.invalid'), isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Share: the standard layout embeds the company logo', (tester) async {
      await pumpScreen(tester, [h.slip()], images: {logoUrl: png});
      await tapAndBuild(tester, 'payslip-share-pdf');
      expect(printed, hasLength(1));
      expect(pdfImages(printed.single), greaterThan(0));
      expect(latin1.decode(printed.single).contains('files.invalid'), isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('image unavailable: the PDF is still produced, without it', (tester) async {
      await pumpScreen(tester, [wageSlip()], images: const {});
      await tapAndBuild(tester, 'payslip-print-pdf');
      expect(printed, hasLength(1));
      expect(pdfImages(printed.single), 0);
      expect(latin1.decode(printed.single, allowInvalid: true).startsWith('%PDF-'), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('both layouts built directly: only the image that belongs to each is embedded', (tester) async {
      await tester.runAsync(() async {
        final fonts = await loadPayslipPdfFonts();
        const ctx = PayslipPdfContext(monthLabel: 'September 2026', companyName: 'Test Co');
        final withBoth = ctx.withImages(logo: png, stamp: png);
        Future<int> count(Map<String, dynamic> slip, PayslipPdfContext c) async =>
            pdfImages(await buildPayslipPdf(PayslipModel.fromJson(slip), c, fonts).save());
        final none = await count(h.slip(), ctx);
        final logoOnly = await count(h.slip(), ctx.withImages(logo: png));
        final stampOnly = await count(wageSlip(), ctx.withImages(stamp: png));
        expect(none, 0);
        expect(logoOnly, greaterThan(0));
        expect(stampOnly, greaterThan(0));
        // Handing over both images changes nothing: a standard slip never
        // uses the stamp, a wage slip never uses the logo.
        expect(await count(h.slip(), withBoth), logoOnly);
        expect(await count(wageSlip(), withBoth), stampOnly);
        expect(await count(wageSlip(), ctx.withImages(logo: png)), 0, reason: 'a wage slip has no logo');
        expect(await count(h.slip(), ctx.withImages(stamp: png)), 0, reason: 'a standard slip has no stamp');
      });
    });
  });

  group('the secure image loader', () {
    ProviderContainer containerWith(HttpClientAdapter adapter) {
      final c = ProviderContainer(overrides: [
        employeeDocumentExternalDioProvider.overrideWithValue(Dio()..httpClientAdapter = adapter),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('https image → bytes, fetched with a plain client: no Authorization header, no cookies', () async {
      final a = _ImageAdapter({stampUrl: (200, png)});
      final bytes = await containerWith(a).read(payslipImageLoaderProvider)(stampUrl);
      expect(bytes, png);
      expect(a.headers.single.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
      expect(a.headers.single.keys.map((k) => k.toLowerCase()), isNot(contains('cookie')));
    });

    test('non-https, malformed, empty, missing, non-image, oversize or failing → null (never an error with the link)',
        () async {
      final big = Uint8List(kPayslipImageMaxBytes + 1);
      final a = _ImageAdapter({
        'https://files.invalid/ok.png': (200, png),
        'https://files.invalid/empty': (200, Uint8List(0)),
        'https://files.invalid/html': (200, Uint8List.fromList(utf8.encode('<html>not an image</html>'))),
        'https://files.invalid/big.png': (200, big),
        'https://files.invalid/gone': (404, Uint8List(0)),
      });
      final load = containerWith(a).read(payslipImageLoaderProvider);
      expect(await load('http://files.invalid/ok.png'), isNull, reason: 'cleartext is refused without a request');
      expect(await load('ftp://files.invalid/ok.png'), isNull);
      expect(await load('not a url'), isNull);
      expect(await load(''), isNull);
      expect(a.requests, isEmpty, reason: 'refused links never leave the device');
      expect(await load('https://files.invalid/empty'), isNull);
      expect(await load('https://files.invalid/html'), isNull);
      expect(await load('https://files.invalid/big.png'), isNull);
      expect(await load('https://files.invalid/gone'), isNull);
      expect(await load('https://files.invalid/offline'), isNull); // adapter throws
      expect(await load('https://files.invalid/ok.png'), png);
    });
  });
}

class _ImageAdapter implements HttpClientAdapter {
  _ImageAdapter(this.files);
  final Map<String, (int, Uint8List)> files;
  final requests = <String>[];
  final headers = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    final url = o.uri.toString();
    requests.add(url);
    headers.add(Map.of(o.headers));
    final f = files[url];
    if (f == null) throw DioException.connectionError(requestOptions: o, reason: 'offline');
    return ResponseBody.fromBytes(f.$2, f.$1, headers: {
      Headers.contentTypeHeader: ['image/png']
    });
  }

  @override
  void close({bool force = false}) {}
}
