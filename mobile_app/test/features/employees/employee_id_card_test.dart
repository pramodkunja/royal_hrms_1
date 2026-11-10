import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/data/models/employee_id_card_model.dart';
import 'package:mobile_app/features/employees/presentation/id_card/id_card_pdf.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_id_card_screen.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Task 31: web /dashboard/employees/[id]/id-card (page.tsx +
// components/idcard/IdCardFaces.tsx + lib/idCard.ts) over
// GET /employees/<employee_id>/id-card/ (EmployeeIdCardView: employees.view +
// branch scope; build_id_card). 50 × 85 mm front/back card; print layouts
// "card" (one face per page) and "a4" (both faces side by side). Synthetic
// data on a stand-in server; nothing is printed or shared for real.

const code = 'EMP-7';
final cardPath = ApiConstants.employeeIdCard(code);

Map<String, dynamic> cardJson({
  bool withLogo = false,
  bool withPhoto = false,
  List<String> missing = const ['Company logo', 'Employee photo'],
  bool contact = true,
}) =>
    {
      'employee': {
        'employee_id': code,
        'full_name': 'Nia Test',
        'designation': 'QA Analyst',
        'department': 'Quality',
        'date_of_joining': '05/01/2026',
        'date_of_birth': '01/02/1995',
        'blood_group': 'O+',
        'location': 'Pune',
        'photo_url': withPhoto ? 'https://media.example.test/photo.png' : null,
        'residential_address': '12 Test Lane, Pune',
        'phone': contact ? '9000000007' : null,
        'email': contact ? 'nia.test@example.test' : null,
      },
      'company': {
        'name': 'Test Co',
        'logo_url': withLogo ? 'https://media.example.test/logo.png' : null,
        'website': 'testco.example',
        'website_url': 'https://testco.example',
        'office_address': '1 Office Road, Pune',
      },
      'card': {
        'terms': ['This card is the property of Test Co.', 'If found, please return it.'],
        'signature_url': null,
        'signatory_label': 'Authorised Signatory',
        'show_date_of_birth': true,
        'show_residential_address': true,
        'show_contact_details': contact,
      },
      'missing': missing,
    };

class Server implements HttpClientAdapter {
  Server({this.body});
  Map<String, dynamic>? body;
  String onboarding = 'complete';
  int status = 200;
  String? message;
  Completer<void>? hold;
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add('${o.method} ${o.path}');
    if (o.path == cardPath) {
      final gate = hold;
      if (gate != null) await gate.future;
      if (status != 200) {
        return ResponseBody.fromString(
            jsonEncode({'status': 'error', 'message': message ?? 'Server error.', 'data': {}}), status,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            });
      }
      return ResponseBody.fromString(
          jsonEncode({'status': 'success', 'message': 'ID card data retrieved.', 'data': body ?? cardJson()}), 200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
    }
    if (o.path == ApiConstants.employeeDetail(code)) {
      return ResponseBody.fromString(jsonEncode({'status': 'success', 'data': employee(onboarding: onboarding)}), 200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
    }
    return ResponseBody.fromString(jsonEncode({'status': 'success', 'data': []}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> employee({String onboarding = 'complete'}) => {
      'id': 'u7',
      'employee_id': code,
      'first_name': 'Nia',
      'last_name': 'Test',
      'full_name': 'Nia Test',
      'email': 'nia.test@example.test',
      'phone': '9000000007',
      'department': 'Quality',
      'designation': 'QA Analyst',
      'branch': 'Pune',
      'role': 'employee',
      'role_display': 'Employee',
      'is_active': true,
      'status': 'active',
      'onboarding_status': onboarding,
      'date_of_joining': '2026-01-05',
      'hr': <String, dynamic>{'id': null, 'name': null},
      'documents': <Object>[],
      'profile': <String, dynamic>{},
    };

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

final viewer = user(const ['employees.view']);
final noAccess = user(const ['leave.view']);

/// A tiny real PNG.
Uint8List png() => Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

final helvetica = IdCardPdfFonts(pw.Font.helvetica(), pw.Font.helveticaBold());

late Server server;
final printed = <({Uint8List bytes, String name, PdfPageFormat format})>[];
final shared = <({Uint8List bytes, String filename})>[];
Completer<void>? holdPrint;
bool failOutput = false;

/// The paper the (stand-in) print dialog selects; null = the size requested.
PdfPageFormat? printPaper;

List<Override> overrides(UserEntity u, {Future<Uint8List?> Function(String)? images}) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      idCardPdfFontsProvider.overrideWithValue(() async => helvetica),
      idCardImageLoaderProvider.overrideWithValue(images ?? (_) async => null),
      idCardOutputProvider.overrideWithValue(IdCardOutput(
        print: (layout, name, format) async {
          final gate = holdPrint;
          if (gate != null) await gate.future;
          if (failOutput) throw Exception('printer unavailable');
          // Like the printing plugin: the PDF is built for the chosen paper;
          // a layout error fails the print call.
          final bytes = await layout(printPaper ?? format);
          printed.add((bytes: bytes, name: name, format: format));
          return true;
        },
        share: (bytes, filename) async {
          if (failOutput) throw Exception('share unavailable');
          shared.add((bytes: bytes, filename: filename));
          return true;
        },
      )),
    ];

Future<void> pumpScreen(WidgetTester tester, {UserEntity? as, Server? with_, bool settle = true}) async {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  printed.clear();
  shared.clear();
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: overrides(as ?? viewer),
    child: MaterialApp(
      home: Consumer(
          builder: (_, ref, child) {
            ref.watch(authStateProvider);
            return child!;
          },
          child: const EmployeeIdCardScreen(employeeId: code)),
    ),
  ));
  if (settle) await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

Future<void> tapKey(WidgetTester tester, String k) async {
  await tester.ensureVisible(byKey(k));
  await tester.tap(byKey(k));
  await tester.pumpAndSettle();
}

/// Builds the PDF off the fake-async zone (pdf encoding is real async work).
Future<Uint8List> pdfBytes(WidgetTester tester, IdCardData d, IdCardPrintLayout l, IdCardPdfAssets a) async =>
    (await tester.runAsync(() => buildIdCardPdf(d, l, a)))!;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    holdPrint = null;
    failOutput = false;
    printPaper = null;
  });

  group('data (lib/idCard.ts rules)', () {
    test('parses every field; blank strings read as missing', () {
      final d = IdCardData.fromJson({
        ...cardJson(),
        'employee': {...cardJson()['employee'] as Map<String, dynamic>, 'blood_group': '  ', 'location': ''},
      });
      expect([d.employee.employeeId, d.employee.fullName, d.employee.designation, d.employee.dateOfJoining],
          [code, 'Nia Test', 'QA Analyst', '05/01/2026']);
      expect([d.employee.bloodGroup, d.employee.location, d.employee.photoUrl], [null, null, null]);
      expect([d.company.name, d.company.website, d.company.officeAddress],
          ['Test Co', 'testco.example', '1 Office Road, Pune']);
      expect(d.card.terms, hasLength(2));
      expect(d.card.signatoryLabel, 'Authorised Signatory');
      expect(d.missing, ['Company logo', 'Employee photo']);
      expect(d.subtitle, 'Nia Test · EMP-7');
    });

    test('front rows: reference order, rows without a value left off (web frontRows)', () {
      final full = IdCardData.fromJson(cardJson());
      expect(idCardFrontRows(full.employee).map((r) => r.text), [
        'Emp Code: EMP-7',
        'DOB: 01/02/1995',
        'DOJ: 05/01/2026',
        'Department: Quality',
        'Blood Group: O+',
        'Location: Pune',
      ]);
      final sparse = IdCardEmployee.fromJson(const {'employee_id': 'X1', 'date_of_joining': '01/01/2026'});
      expect(idCardFrontRows(sparse).map((r) => r.key), ['code', 'doj']);
    });

    test('back sections: residential, office, contact (one line each) — each only when present', () {
      final d = IdCardData.fromJson(cardJson());
      final s = idCardBackSections(d);
      expect(s.map((x) => x.title), ['Residential Address', 'Office Address', 'Contact Details']);
      expect(s.last.lines, ['9000000007', 'nia.test@example.test']);
      expect(s.last.singleLine, isTrue);
      expect(idCardBackSections(IdCardData.fromJson(cardJson(contact: false))).map((x) => x.key), ['res', 'off']);
    });

    test('route inherits /dashboard/employees (employees.view)', () {
      expect(requiredPermissionsFor(AppRoutes.employeeIdCardPath(code)), ['employees.view']);
      expect(canAccessPath(viewer, AppRoutes.employeeIdCardPath(code)), isTrue);
      expect(canAccessPath(noAccess, AppRoutes.employeeIdCardPath(code)), isFalse);
    });
  });

  group('PDF', () {
    final data = IdCardData.fromJson(cardJson());
    final noImages = IdCardPdfAssets(base: helvetica.base, bold: helvetica.bold);

    test('card layout: two pages, each exactly 50 × 85 mm', () {
      final doc = buildIdCardDocument(data, IdCardPrintLayout.card, noImages);
      final pages = doc.document.pdfPageList.pages;
      expect(pages, hasLength(2));
      for (final p in pages) {
        expect(p.pageFormat.width, closeTo(50 * PdfPageFormat.mm, .01));
        expect(p.pageFormat.height, closeTo(85 * PdfPageFormat.mm, .01));
      }
    });

    test('A4 layout: one A4 page with 15 mm margins (both faces side by side)', () {
      final doc = buildIdCardDocument(data, IdCardPrintLayout.a4, noImages);
      final pages = doc.document.pdfPageList.pages;
      expect(pages, hasLength(1));
      expect(pages.single.pageFormat.width, closeTo(PdfPageFormat.a4.width, .01));
      expect(pages.single.pageFormat.height, closeTo(PdfPageFormat.a4.height, .01));
      expect(idCardPageFormat(IdCardPrintLayout.a4).marginLeft, closeTo(15 * PdfPageFormat.mm, .01));
    });

    testWidgets('saves a real PDF — with and without logo/photo/signature images', (tester) async {
      final plain = await pdfBytes(tester, data, IdCardPrintLayout.card, noImages);
      expect(ascii.decode(plain.sublist(0, 5)), '%PDF-');
      final withImages =
          IdCardPdfAssets(base: helvetica.base, bold: helvetica.bold, logo: png(), photo: png(), signature: png());
      final rich = await pdfBytes(tester, data, IdCardPrintLayout.a4, withImages);
      expect(ascii.decode(rich.sublist(0, 5)), '%PDF-');
      expect(rich.length, greaterThan(plain.length ~/ 2));
    });

    testWidgets('very long values still produce a valid PDF', (tester) async {
      final long = IdCardData.fromJson({
        ...cardJson(),
        'employee': {
          ...cardJson()['employee'] as Map<String, dynamic>,
          'full_name': 'A' * 120,
          'residential_address': 'Long address ' * 40,
        },
        'card': {...cardJson()['card'] as Map<String, dynamic>, 'terms': List.filled(20, 'A long term line ' * 4)},
      });
      final bytes = await pdfBytes(tester, long, IdCardPrintLayout.card, noImages);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('only real images are embedded (JPEG / decodable); anything else is skipped', () {
      expect(isEmbeddableImage(png()), isTrue);
      expect(isEmbeddableImage(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0])), isTrue);
      expect(isEmbeddableImage(Uint8List.fromList(utf8.encode('<svg></svg>'))), isFalse);
    });

    test('file name uses the employee code', () {
      expect(idCardFileName(data, 'x'), 'id-card-EMP-7.pdf');
      expect(idCardFileName(IdCardData.fromJson({...cardJson(), 'employee': <String, dynamic>{}}), 'u 9'),
          'id-card-u_9.pdf');
    });
  });

  group('screen', () {
    testWidgets('loading, then the card: subtitle, warning, front and back', (tester) async {
      final s = Server()..hold = Completer();
      await pumpScreen(tester, with_: s, settle: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(byKey('idcard-loading'), findsOneWidget);
      expect(find.text('Loading ID card…'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(byKey('idcard-print')).onPressed, isNull, reason: 'no data yet');
      s.hold!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(byKey('idcard-subtitle')).data, 'Nia Test · EMP-7');
      expect(find.textContaining('Not on record, so left off the card', findRichText: true), findsOneWidget);
      expect(find.textContaining('Company logo, Employee photo.', findRichText: true), findsOneWidget);
      // front
      expect(tester.widget<Text>(byKey('idc-name')).data, 'NIA TEST');
      expect(tester.widget<Text>(byKey('idc-designation')).data, 'QA ANALYST');
      expect(byKey('idc-row-blood'), findsOneWidget);
      expect(find.text('Emp Code: EMP-7'), findsOneWidget);
      expect(byKey('idc-photo-empty'), findsOneWidget, reason: 'no photo on record');
      expect(find.text('Test Co'), findsWidgets, reason: 'no logo → company name');
      expect(find.text('testco.example'), findsNWidgets(2), reason: 'website footer on both faces');
      // back
      expect(byKey('idc-section-res'), findsOneWidget);
      expect(byKey('idc-section-con'), findsOneWidget);
      expect(byKey('idc-terms-pill'), findsOneWidget);
      expect(find.text('If found, please return it.'), findsOneWidget);
      expect(tester.widget<Text>(byKey('idc-signatory')).data, 'Authorised Signatory');
      expect(server.calls, ['GET $cardPath']);
    });

    testWidgets('no warning when nothing is missing; images are shown when on record', (tester) async {
      await pumpScreen(tester, with_: Server(body: cardJson(withLogo: true, withPhoto: true, missing: const [])));
      expect(byKey('idcard-missing'), findsNothing);
      expect(byKey('idc-photo-image'), findsOneWidget);
      expect(byKey('idc-logo-image'), findsNWidgets(2));
    });

    testWidgets('Print: card layout → one call with a 50 × 85 mm PDF', (tester) async {
      await pumpScreen(tester);
      await tester.runAsync(() async {
        await tester.tap(byKey('idcard-print'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(printed, hasLength(1));
      expect(ascii.decode(printed.single.bytes.sublist(0, 5)), '%PDF-');
      expect(printed.single.format.width, closeTo(50 * PdfPageFormat.mm, .01));
      expect(printed.single.name, 'ID Card – Nia Test');
    });

    testWidgets('Print on the paper Android picks (Letter): PDF pages are Letter, card not scaled', (tester) async {
      printPaper = PdfPageFormat.letter;
      await pumpScreen(tester);
      await tester.runAsync(() async {
        await tester.tap(byKey('idcard-print'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      final boxes = RegExp(r'/MediaBox\s*\[([^\]]*)\]')
          .allMatches(latin1.decode(printed.single.bytes))
          .map((m) => m.group(1)!.trim().split(RegExp(r'\s+')).map(double.parse).toList())
          .toList();
      expect(boxes, hasLength(2));
      for (final b in boxes) {
        expect(b[2], closeTo(PdfPageFormat.letter.width, .01));
        expect(b[3], closeTo(PdfPageFormat.letter.height, .01));
      }
    });

    testWidgets('Print on paper smaller than the card fails with a clear message', (tester) async {
      printPaper = const PdfPageFormat(52 * PdfPageFormat.mm, 74 * PdfPageFormat.mm); // ISO A8
      await pumpScreen(tester);
      await tester.runAsync(() async {
        await tester.tap(byKey('idcard-print'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(printed, isEmpty);
      expect(
          find.text('The selected paper (52 × 74 mm) is smaller than the 50 × 85 mm ID card. '
              'Choose a larger paper size (portrait), or use the A4 sheet layout.'),
          findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(byKey('idcard-print')).onPressed, isNotNull);
    });

    testWidgets('choosing A4 changes the hint and prints an A4 PDF', (tester) async {
      await pumpScreen(tester);
      expect(find.textContaining('Card size (50 × 85 mm):', findRichText: true), findsOneWidget);
      await tapKey(tester, 'idcard-layout');
      await tester.tap(find.text('A4 sheet').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('A4 sheet:', findRichText: true), findsOneWidget);
      expect(find.textContaining('Front and back side by side', findRichText: true), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(byKey('idcard-print'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(printed.single.format.width, closeTo(PdfPageFormat.a4.width, .01));
    });

    testWidgets('Share PDF hands over id-card-<code>.pdf', (tester) async {
      await pumpScreen(tester);
      await tester.runAsync(() async {
        await tester.tap(byKey('idcard-share'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(shared.single.filename, 'id-card-EMP-7.pdf');
      expect(ascii.decode(shared.single.bytes.sublist(0, 5)), '%PDF-');
    });

    testWidgets('while printing both buttons are disabled; a second tap does nothing', (tester) async {
      holdPrint = Completer();
      await pumpScreen(tester);
      await tester.runAsync(() async {
        await tester.tap(byKey('idcard-print'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      expect(tester.widget<ButtonStyleButton>(byKey('idcard-print')).onPressed, isNull);
      expect(tester.widget<ButtonStyleButton>(byKey('idcard-share')).onPressed, isNull);
      await tester.tap(byKey('idcard-print'), warnIfMissed: false);
      holdPrint!.complete();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(printed, hasLength(1));
    });

    testWidgets('a print/share failure is reported', (tester) async {
      failOutput = true;
      await pumpScreen(tester);
      await tester.runAsync(() async {
        await tester.tap(byKey('idcard-share'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.text('Could not create the ID card PDF.'), findsOneWidget);
    });

    for (final (status, message, expected) in [
      (403, 'Forbidden', "You don't have permission to generate ID cards."),
      (404, 'Employee not found.', 'Employee not found.'),
      (
        500,
        'An unexpected error occurred. Please try again later.',
        'An unexpected error occurred. Please try again later.'
      ),
    ]) {
      testWidgets('HTTP $status → "$expected" with Retry', (tester) async {
        await pumpScreen(tester,
            with_: Server()
              ..status = status
              ..message = message);
        expect(find.text(expected), findsOneWidget);
        expect(byKey('idcard-retry'), findsOneWidget);
        expect(tester.widget<ButtonStyleButton>(byKey('idcard-print')).onPressed, isNull);
      });
    }

    testWidgets('Retry reloads and shows the card', (tester) async {
      final s = Server()..status = 500;
      await pumpScreen(tester, with_: s);
      s.status = 200;
      await tapKey(tester, 'idcard-retry');
      expect(tester.widget<Text>(byKey('idc-name')).data, 'NIA TEST');
      expect(s.calls.where((c) => c == 'GET $cardPath'), hasLength(2));
    });

    testWidgets('without employees.view: permission message, no request', (tester) async {
      await pumpScreen(tester, as: noAccess);
      expect(find.text("You don't have permission to generate ID cards."), findsOneWidget);
      expect(server.calls, isEmpty);
      expect(tester.widget<ButtonStyleButton>(byKey('idcard-print')).onPressed, isNull);
    });
  });

  group('navigation from the employee profile', () {
    Future<void> pumpRouter(WidgetTester tester, {String onboarding = 'complete'}) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      server = Server()..onboarding = onboarding;
      server.body = cardJson();
      final router = GoRouter(initialLocation: AppRoutes.employeeProfilePath(code), routes: [
        GoRoute(
          path: '/dashboard/employees/:employeeId',
          builder: (_, s) => EmployeeProfileScreen(employeeId: s.pathParameters['employeeId']!),
          routes: [
            GoRoute(
              path: 'id-card',
              builder: (_, s) => EmployeeIdCardScreen(employeeId: s.pathParameters['employeeId']!),
            ),
          ],
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          ...overrides(viewer),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('no "ID Card" while onboarding is pending (web hides the link)', (tester) async {
      await pumpRouter(tester, onboarding: 'pending');
      expect(byKey('employee-id-card'), findsNothing);
    });

    testWidgets('the profile\'s "ID Card" opens the card; Back returns to the profile', (tester) async {
      await pumpRouter(tester);
      expect(byKey('employee-id-card'), findsOneWidget);
      await tapKey(tester, 'employee-id-card');
      expect(find.byType(EmployeeIdCardScreen), findsOneWidget);
      expect(tester.widget<Text>(byKey('idcard-subtitle')).data, 'Nia Test · EMP-7');
      await tester.tap(find.byTooltip('Back to profile'));
      await tester.pumpAndSettle();
      expect(find.byType(EmployeeIdCardScreen), findsNothing);
      expect(find.byType(EmployeeProfileScreen), findsOneWidget);
    });
  });
}
