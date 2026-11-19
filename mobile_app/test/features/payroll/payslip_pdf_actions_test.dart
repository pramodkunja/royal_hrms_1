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
import 'package:mobile_app/features/payroll/data/models/payslip_model.dart';
import 'package:mobile_app/features/payroll/presentation/payslip_pdf.dart';
import 'package:mobile_app/features/payroll/presentation/screens/my_payslip_screen.dart';
import 'package:pdf/pdf.dart';

import 'payslip_document_parity_test.dart' as h;

// Phase C3 — HO-28. Web My Payslips: "Print / Save PDF" (window.print of the
// rendered payslip) and "Download PDF" (link to EmployeePayslip.payslip_pdf,
// disabled "PDF not yet available for this payslip" when null — and the
// backend never fills that field today). Mobile: Print / Save PDF and Share
// PDF build the same payslip into a PDF on the device; Download PDF mirrors
// web, including the disabled state. Data comes only from
// GET /payroll/my-payslips/ (own, non-draft) + company + own profile. The
// print/share plugins are replaced by a recorder; nothing leaves the test.

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

class Recorder {
  final printed = <(String, Uint8List)>[];
  final shared = <(String, Uint8List)>[];
  bool fail = false;
}

late Recorder rec;

Future<void> pump(WidgetTester tester, Map<String, dynamic> slip, {bool fontsFail = false}) async {
  tester.view.physicalSize = const Size(1080, 5200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  h.server = h.Server([slip]);
  rec = Recorder();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider
          .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = h.server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      authStateProvider.overrideWith(_Auth.new),
      payslipPdfOutputProvider.overrideWithValue(PayslipPdfOutput(
        print: (layout, name) async {
          if (rec.fail) throw Exception('printer unavailable');
          rec.printed.add((name, await layout(PdfPageFormat.a4)));
          return true;
        },
        share: (bytes, filename) async {
          rec.shared.add((filename, bytes));
          return true;
        },
      )),
      if (fontsFail) payslipPdfFontsProvider.overrideWithValue(() async => throw Exception('font missing')),
    ],
    child: const MaterialApp(home: Scaffold(body: MyPayslipScreen())),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  // PDF building runs real async work (font load, compression).
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500)));
  await tester.pumpAndSettle();
}

bool isPdf(Uint8List b) => b.length > 1000 && utf8.decode(b.sublist(0, 5), allowMalformed: true) == '%PDF-';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('actions shown; Download PDF disabled with web\'s reason when the server has no file', (tester) async {
    await pump(tester, h.slip());
    expect(find.byKey(const Key('payslip-print-pdf')), findsOneWidget);
    expect(find.byKey(const Key('payslip-share-pdf')), findsOneWidget);
    final dl = tester.widget<ButtonStyleButton>(find.byKey(const Key('payslip-download-pdf')));
    expect(dl.onPressed, isNull);
    expect(find.text('Download PDF (not yet available)'), findsOneWidget);
    expect(find.byTooltip('PDF not yet available for this payslip'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Download PDF enabled when the server issued a file', (tester) async {
    await pump(tester, h.slip(extra: {'payslip_pdf': 'https://files.example.test/p1.pdf'}));
    final dl = tester.widget<ButtonStyleButton>(find.byKey(const Key('payslip-download-pdf')));
    expect(dl.onPressed, isNotNull);
    expect(find.text('Download PDF'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Print / Save PDF: real PDF of this payslip, named for this employee and month', (tester) async {
    await pump(tester, h.slip());
    await tapKey(tester, 'payslip-print-pdf');
    expect(rec.printed, hasLength(1));
    expect(rec.printed.single.$1, 'payslip-TST001-2026-09.pdf');
    expect(isPdf(rec.printed.single.$2), isTrue);
    // Only the own-payslip endpoint (plus company / own profile / queries) was read; nothing written.
    expect(h.server.calls.where((c) => !c.startsWith('GET ')), isEmpty);
    expect(h.server.calls.where((c) => c.contains('/payroll/') && !c.contains('my-payslips') && !c.contains('queries')),
        isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Share PDF: same file name, PDF bytes', (tester) async {
    await pump(tester, h.slip());
    await tapKey(tester, 'payslip-share-pdf');
    expect(rec.shared, hasLength(1));
    expect(rec.shared.single.$1, 'payslip-TST001-2026-09.pdf');
    expect(isPdf(rec.shared.single.$2), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failure (printer / fonts): a plain error message, no crash, buttons usable again', (tester) async {
    await pump(tester, h.slip(), fontsFail: true);
    await tapKey(tester, 'payslip-share-pdf');
    expect(find.text("Couldn't prepare the payslip PDF. Please try again."), findsOneWidget);
    expect(rec.shared, isEmpty);
    final btn = tester.widget<ButtonStyleButton>(find.byKey(const Key('payslip-print-pdf')));
    expect(btn.onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('PDF lines = screen lines (shared): zero amounts dropped, LOP last', () {
    final p = PayslipModel.fromJson(h.slip());
    expect(payslipEarningLines(p).map((l) => l.$1), [
      'Basic Salary',
      'House Rent Allowance (HRA)',
      'Special Allowance',
      'Night Shift Allowance',
    ]);
    expect(payslipDeductionLines(p).map((l) => l.$1).last, 'Loss of Pay (LOP)');
    expect(payslipDeductionLines(p).map((l) => l.$1), isNot(contains('ESI')));
  });

  test('file name is sanitised', () {
    final p = PayslipModel.fromJson(h.slip(extra: {'employee_id_code': 'A/B C', 'cycle_start': '2026-10-01'}));
    expect(payslipPdfFileName(p), 'payslip-A_B_C-2026-10.pdf');
  });
}
