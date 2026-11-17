import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/dashboard_section.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/presentation/employees_screen.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:mobile_app/features/employees/presentation/widgets/employee_card.dart';
import 'package:mobile_app/features/payroll/presentation/screens/my_payslip_screen.dart';
import 'package:mobile_app/shared/widgets/stat_card.dart';

import '../features/payroll/payslip_document_parity_test.dart' as payslip;

// Phase C2 — responsive fixes found on the moto g06 (411 dp wide) at system
// font scale 1.3 / 1.5 (17 Nov 2026):
//  HO-19  My Payslips month chip: fixed 68 × 132 px → 8 px bottom overflow.
//  HO-20  Employees: fixed-ratio grid cells overflowed at 1.5 (and wasted
//         ~130 px at 1.0, HO-09); the stats strip grew with text but its
//         hero box didn't, covering the "N employees" line at 1.3.
//  HO-21  Dashboard KPIs clipped ("Employ…"); strip stat labels broke
//         mid-word ("Pendin / g").
// Each test here fails if its fix is reverted. Synthetic data only.

const phone = Size(720, 1640);
const dpr = 1.75;

Widget scaled(double s, Widget child) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(s)),
        child: child,
      ),
    );

void setPhone(WidgetTester tester) {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
}

/// Flutter reports every RenderFlex overflow as an exception the test
/// binding holds; the first one (if any) is returned here.
String? overflowOf(WidgetTester tester) {
  final e = tester.takeException();
  return e?.toString().split('\n').first;
}

// ── Employees harness ─────────────────────────────────────────────────────────

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'u1',
          email: 'hr@example.test',
          fullName: 'HR User',
          role: 'hr',
          roleDisplay: 'HR',
          mustChangePassword: false,
          permissions: ['employees.view', 'employees.edit', 'employees.create'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

class _Empty implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async =>
      ResponseBody.fromString(
          jsonEncode({
            'status': 'success',
            'data': {'count': 0, 'page': 1, 'total_pages': 1, 'results': []}
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
  @override
  void close({bool force = false}) {}
}

class _NullStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

EmployeeModel emp(int i, {String? name}) => EmployeeModel.fromJson({
      'id': 'id$i',
      'employee_id': 'EMP$i',
      'full_name': name ?? 'Person $i',
      'first_name': 'Person',
      'last_name': '$i',
      'email': 'p$i@example.test',
      'designation': 'Senior Software Engineer',
      'department': 'Engineering',
      'branch': 'Main',
      'role': 'employee',
      'status': 'active',
      'is_active': true,
    });

class _List extends EmployeeListNotifier {
  @override
  Future<EmployeeListState> build() async => EmployeeListState(
        items: [
          emp(1, name: 'Venkata Satyanarayana Ramachandramurthy Lakshminarasimhan'),
          emp(2),
          emp(3),
          emp(4),
        ],
        page: 1,
        totalPages: 1,
        count: 4,
      );
}

Future<void> pumpEmployees(WidgetTester tester, double s) async {
  setPhone(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = _Empty()),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      employeeListProvider.overrideWith(_List.new),
      employeeStatsProvider.overrideWith((ref) async => const EmployeeStats(total: 4, active: 4, onboarding: 0, departments: 1)),
    ],
    child: MaterialApp(home: scaled(s, const Scaffold(body: EmployeesScreen()))),
  ));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('HO-20 Employees at every text scale', () {
    for (final s in [1.0, 1.3, 1.5, 2.0]) {
      testWidgets('scale $s: no overflow, every card fully laid out, stats clear of the count line', (tester) async {
        await pumpEmployees(tester, s);
        expect(overflowOf(tester), isNull);
        expect(find.byType(EmployeeCard), findsNWidgets(4));
        // Each card's content fits inside its cell.
        for (final card in tester.widgetList(find.byType(EmployeeCard))) {
          final el = find.byWidget(card);
          final box = tester.renderObject<RenderBox>(el);
          expect(box.size.height, greaterThanOrEqualTo(box.getMinIntrinsicHeight(box.size.width) - 0.5));
        }
        // Stats strip ends above the "N employees" line.
        final statsBottom = tester.getRect(find.byType(StatCardRow)).bottom;
        final countTop = tester.getRect(find.text('4 employees')).top;
        expect(statsBottom, lessThanOrEqualTo(countTop + 0.5), reason: 'stats overlap the count line');
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('scale 1.0: no large dead space under the buttons (HO-09)', (tester) async {
      await pumpEmployees(tester, 1.0);
      // Row 1 (cards 3 and 4, short names): the cell is as tall as its content.
      final card = find.byType(EmployeeCard).at(2);
      final box = tester.renderObject<RenderBox>(card);
      final natural = box.getMinIntrinsicHeight(box.size.width);
      expect(box.size.height - natural, lessThan(8), reason: 'old fixed ratio left ~130 px');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('HO-19 payslip month chip', () {
    for (final s in [1.0, 1.3, 1.5, 2.0]) {
      testWidgets('scale $s: month chip has room for both lines', (tester) async {
        payslip.server = payslip.Server([payslip.slip()]);
        setPhone(tester);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = payslip.server),
            cookieJarProvider.overrideWithValue(CookieJar()),
            secureStorageProvider.overrideWithValue(_NullStorage()),
            authStateProvider.overrideWith(_Auth.new),
          ],
          child: MaterialApp(home: scaled(s, const Scaffold(body: MyPayslipScreen()))),
        ));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 80));
        }
        expect(overflowOf(tester), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('HO-21 labels at large text', () {
    final stats = <ConsoleStatData>[
      (icon: Icons.groups_outlined, value: '7', label: 'Employees', color: AppColors.primary),
      (icon: Icons.fact_check_outlined, value: '6', label: 'Approvals', color: AppColors.warning),
      (icon: Icons.person_add_alt_outlined, value: '0', label: 'Onboard', color: AppColors.success),
      (icon: Icons.apartment_outlined, value: '1', label: 'Branches', color: AppColors.info),
    ];

    // Label-fit checks run at the scales the fix targets. flutter_test draws
    // text in its block test font, far wider than the app's Poppins, so a
    // quarter-width cell can't hold "Employees" in a test even at 1.0 —
    // where the phone shows it fine (device evidence, Phase B / C2).
    testWidgets('dashboard KPIs at 1.0 keep the four-across row', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(28), child: ConsoleStatsRow(stats: stats))),
      ));
      await tester.pump();
      expect(find.byKey(const Key('console-stats-two-column')), findsNothing);
      expect(find.text('Employees'), findsOneWidget);
    });

    for (final s in [1.3, 1.5]) {
      testWidgets('dashboard KPIs at $s: every label shown in full', (tester) async {
        setPhone(tester);
        await tester.pumpWidget(MaterialApp(
          home: scaled(s, Scaffold(body: Padding(padding: const EdgeInsets.all(28), child: ConsoleStatsRow(stats: stats)))),
        ));
        await tester.pump();
        for (final l in ['Employees', 'Approvals', 'Onboard', 'Branches']) {
          final p = tester.renderObject<RenderParagraph>(find.text(l));
          expect(p.didExceedMaxLines, isFalse, reason: '$l clipped at $s');
        }
        expect(find.byKey(const Key('console-stats-two-column')), findsOneWidget);
      });
    }

    for (final s in [1.3, 1.5]) {
      testWidgets('strip stat label "Pending" at $s stays on one line (no mid-word break)', (tester) async {
        setPhone(tester);
        await tester.pumpWidget(MaterialApp(
          home: scaled(
            s,
            const Scaffold(
              body: StatCardRow(cards: [
                StatCard(icon: Icons.pending_actions, count: 11, label: 'Pending', color: Colors.orange),
                StatCard(icon: Icons.event, count: 5, label: 'Leave', color: Colors.blue),
                StatCard(icon: Icons.receipt_long, count: 0, label: 'Total Assessments', color: Colors.teal),
              ]),
            ),
          ),
        ));
        await tester.pump();
        final p = tester.renderObject<RenderParagraph>(find.text('Pending'));
        // Laid out at (at least) its natural one-line width → not broken.
        expect(p.size.width, greaterThanOrEqualTo(p.getMaxIntrinsicWidth(double.infinity) - 0.5));
        expect(p.didExceedMaxLines, isFalse);
      });
    }
  });
}
