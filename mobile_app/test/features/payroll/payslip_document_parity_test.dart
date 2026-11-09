import 'dart:convert';

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
import 'package:mobile_app/features/payroll/presentation/screens/my_payslip_screen.dart';

// My Payslips on-screen parity with web components/payroll/PayslipDocument.tsx
// + app/dashboard/my-payslip/page.tsx: saved values only (nothing recomputed
// but paid days = working − LOP), INR = whole rupees with en-IN grouping, zero
// rows hidden but totals always shown, LOP last, reimbursements only when > 0,
// "Net Salary Credited … In Hand". Synthetic payslips; nothing is sent.
// (PDF / print is deferred — web's is the browser print dialog; no server PDF.)

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> slip({
  String id = 'p1',
  Map<String, dynamic> extra = const {},
}) =>
    {
      'id': id,
      'cycle_start': '2026-09-01',
      'cycle_end': '2026-09-30',
      'pay_date': '2026-09-30',
      'employee_name': 'Test Person',
      'employee_id_code': 'TST001',
      'department': 'Finance',
      'basic': '50000.00',
      'hra': '20000.00',
      'special_allowance': '12345.50',
      'bonus': '0.00',
      'other_earnings': {'Night Shift Allowance': 1500, 'Zero Allowance': 0},
      'other_deductions': {'Canteen': 750.4},
      'reimbursements': '0.00',
      'gross_earnings': '123456.50',
      'total_working_days': 22,
      'lop_days': '1.5',
      'lop_deduction': '3409.09',
      'pf_employee': '1800.00',
      'esi_employee': '0.00',
      'pt_deduction': '200.00',
      'lwf_employee': '0.00',
      'total_deductions': '6159.49',
      'net_pay': '117297.01',
      'status': 'paid',
      'payslip_pdf': null,
      ...extra,
    };

class Server implements HttpClientAdapter {
  Server(this.payslips, {this.payslipsStatus = 200});
  final List<Map<String, dynamic>> payslips;
  final int payslipsStatus;
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add('${o.method} ${o.path}');
    if (o.path == '/payroll/my-payslips/') {
      if (payslipsStatus != 200) return _json(payslipsStatus, {'status': 'error', 'message': 'Server error.'});
      return _json(200, {
        'status': 'success',
        'data': {'count': payslips.length, 'results': payslips}
      });
    }
    if (o.path == '/employees/me/') {
      return _json(200, {
        'status': 'success',
        'data': {
          'id': 'u1',
          'full_name': 'Test Person',
          'employee_id': 'TST001',
          'department': 'Finance',
          'profile': {'bank_name': 'Test Bank', 'account_number': '000123456789', 'ifsc_code': 'TEST0001234'},
        }
      });
    }
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
        }
      });
    }
    if (o.path == '/payroll/queries/') return _json(200, {'status': 'success', 'data': []});
    return _json(404, {'status': 'error', 'message': 'Not found'});
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
          assessmentStatus: 'complete'));
}

late Server server;

Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> payslips, {int status = 200}) async {
  tester.view.physicalSize = const Size(1080, 5200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server(payslips, payslipsStatus: status);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      authStateProvider.overrideWith(_Auth.new),
    ],
    child: const MaterialApp(home: Scaffold(body: MyPayslipScreen())),
  ));
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

/// The amount shown on the same row as [label].
String rowAmount(WidgetTester tester, String label) {
  final row = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
  final texts = tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))).map((t) => t.data);
  return texts.last!;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('formatting (web INR / fmtDate)', () {
    test('INR: whole rupees, en-IN grouping, half rounds away from zero', () {
      expect(formatPayslipInr('0.00'), '₹0');
      expect(formatPayslipInr(999), '₹999');
      expect(formatPayslipInr('1000'), '₹1,000');
      expect(formatPayslipInr('123456.50'), '₹1,23,457');
      expect(formatPayslipInr('12345678.49'), '₹1,23,45,678');
      expect(formatPayslipInr(0.5), '₹1');
      expect(formatPayslipInr(-1500.6), '₹-1,501');
      expect(formatPayslipInr(null), '₹0');
      expect(formatPayslipInr('abc'), '₹0');
    });

    test('date: "09 Nov 2026", en-IN "Sept"; invalid kept / blank "—"; account mask', () {
      expect(formatPayslipDate('2026-11-09'), '09 Nov 2026');
      expect(formatPayslipDate('2026-09-30'), '30 Sept 2026');
      expect(formatPayslipDate('2026-01-31T00:00:00Z'), '31 Jan 2026');
      expect(formatPayslipDate(''), '—');
      expect(formatPayslipDate('soon'), 'soon');
      expect(maskPayslipAccount('000123456789'), '••••6789');
      expect(maskPayslipAccount('12'), '••••12');
      expect(maskPayslipAccount(''), '—');
      expect(payslipNumber(20.5), '20.5');
      expect(payslipNumber(22.0), '22');
    });

    test('model reads other_deductions (and keeps them through copyWith)', () {
      final p = PayslipModel.fromJson(slip());
      expect(p.otherDeductions, {'Canteen': 750.4});
      expect(p.copyWith(status: 'acknowledged').otherDeductions, {'Canteen': 750.4});
      expect(PayslipModel.fromJson(slip(extra: {'other_deductions': null})).otherDeductions, isEmpty);
      expect(PayslipModel.fromJson(slip()).paidDays, 20.5);
    });
  });

  group('payslip document', () {
    testWidgets('letterhead, salary date and web\'s four-field strip', (tester) async {
      await pump(tester, [slip()]);
      expect(find.textContaining('Test Co · CIN: U00000TS2026PTC000000'), findsOneWidget);
      expect(textOf(tester, 'payslip-company-address'), '1 Test Road, Test City, Test State, 500001');
      expect(textOf(tester, 'payslip-salary-date'), 'Salary Date: 30 Sept 2026');
      final strip = find.byKey(const Key('payslip-strip'));
      for (final t in [
        'Employee ID',
        'TST001',
        'Bank',
        'Test Bank',
        'Account No.',
        '••••6789',
        'IFSC Code',
        'TEST0001234'
      ]) {
        expect(find.descendant(of: strip, matching: find.text(t)), findsOneWidget, reason: t);
      }
      expect(find.textContaining('000123456789'), findsNothing);
    });

    testWidgets('attendance: working, paid (= working − LOP) and LOP with "₹X deducted"', (tester) async {
      await pump(tester, [slip()]);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('20.5'), findsOneWidget);
      expect(find.text('1.5'), findsOneWidget);
      expect(find.text('days credited'), findsOneWidget);
      expect(find.text('₹3,409 deducted'), findsOneWidget);
    });

    testWidgets('earnings: zero rows hidden, other earnings listed, saved gross shown (not recomputed)',
        (tester) async {
      await pump(tester, [slip()]);
      expect(rowAmount(tester, 'Basic Salary'), '₹50,000');
      expect(rowAmount(tester, 'House Rent Allowance (HRA)'), '₹20,000');
      expect(rowAmount(tester, 'Special Allowance'), '₹12,346');
      expect(rowAmount(tester, 'Night Shift Allowance'), '₹1,500');
      expect(find.text('Bonus'), findsNothing);
      expect(find.text('Zero Allowance'), findsNothing);
      expect(rowAmount(tester, 'Gross Earnings'), '₹1,23,457');
    });

    testWidgets('deductions: web labels and order, other deductions, LOP last; saved total', (tester) async {
      await pump(tester, [slip()]);
      expect(rowAmount(tester, 'Provident Fund (PF)'), '₹1,800');
      expect(rowAmount(tester, 'Professional Tax (PT)'), '₹200');
      expect(rowAmount(tester, 'Canteen'), '₹750');
      expect(rowAmount(tester, 'Loss of Pay (LOP)'), '₹3,409');
      expect(find.text('ESI'), findsNothing);
      expect(find.text('Labour Welfare Fund'), findsNothing);
      expect(
          tester.getTopLeft(find.text('Canteen')).dy, lessThan(tester.getTopLeft(find.text('Loss of Pay (LOP)')).dy));
      expect(rowAmount(tester, 'Total Deductions'), '₹6,159');
    });

    testWidgets('net banner: label, subline with bank, Gross − Ded., net, In Hand; no reimbursements line',
        (tester) async {
      await pump(tester, [slip()]);
      expect(find.text('Net Salary Credited'), findsOneWidget);
      expect(textOf(tester, 'payslip-net-subline'), 'Paid on 30 Sept 2026 · Test Bank ••••6789');
      expect(textOf(tester, 'payslip-net-breakdown'), 'Gross ₹1,23,457 − Ded. ₹6,159');
      expect(textOf(tester, 'payslip-net-amount'), '₹1,17,297');
      expect(find.text('In Hand'), findsOneWidget);
      expect(find.text('Reimbursements'), findsNothing);
      expect(
          textOf(tester, 'payslip-footer'),
          'This is a computer-generated payslip and does not require a signature. '
          'For queries contact HR at +91 90000 00000.');
    });

    testWidgets('reimbursements > 0: their own line and "+ Reimb." in the banner', (tester) async {
      await pump(tester, [
        slip(extra: {'reimbursements': '2500.00'})
      ]);
      expect(find.text('Reimbursements'), findsOneWidget);
      expect(textOf(tester, 'payslip-net-breakdown'), 'Gross ₹1,23,457 − Ded. ₹6,159 + Reimb. ₹2,500');
    });

    testWidgets('all-zero payslip: totals still shown as ₹0, no LOP, no rows', (tester) async {
      await pump(tester, [
        slip(extra: {
          'basic': '0',
          'hra': '0',
          'special_allowance': '0',
          'other_earnings': {},
          'other_deductions': {},
          'gross_earnings': '0',
          'lop_days': '0',
          'lop_deduction': '0',
          'pf_employee': '0',
          'pt_deduction': '0',
          'total_deductions': '0',
          'net_pay': '0',
        })
      ]);
      expect(rowAmount(tester, 'Gross Earnings'), '₹0');
      expect(rowAmount(tester, 'Total Deductions'), '₹0');
      expect(textOf(tester, 'payslip-net-amount'), '₹0');
      expect(find.text('no LOP'), findsOneWidget);
      expect(find.text('Basic Salary'), findsNothing);
      expect(find.text('None'), findsNothing);
    });

    testWidgets('missing / malformed values render as ₹0 instead of failing', (tester) async {
      await pump(tester, [
        slip(extra: {'basic': null, 'gross_earnings': 'n/a', 'net_pay': null, 'total_deductions': ''})
      ]);
      expect(find.text('Basic Salary'), findsNothing);
      expect(rowAmount(tester, 'Gross Earnings'), '₹0');
      expect(textOf(tester, 'payslip-net-amount'), '₹0');
    });

    testWidgets('no server PDF (production never sets payslip_pdf): no PDF button', (tester) async {
      await pump(tester, [slip()]);
      expect(find.text('Open PDF'), findsNothing);
    });

    testWidgets('empty and error states stay as before; only the user\'s own endpoint is read', (tester) async {
      await pump(tester, []);
      expect(find.text('No payslips available yet.'), findsOneWidget);
      expect(server.calls.where((c) => c.contains('/payroll/') && !c.contains('my-payslips') && !c.contains('queries')),
          isEmpty);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, [], status: 500);
      expect(find.byKey(const Key('payslip-net-amount')), findsNothing);
    });
  });
}
