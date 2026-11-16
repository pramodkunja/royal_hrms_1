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
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';
import 'package:mobile_app/features/employees/presentation/widgets/employee_salary_payroll_tabs.dart';
import 'package:mobile_app/shared/documents/document_links.dart';

// Task 70: Employee Profile → Salary and Payroll — web employees/[id]/
// _components/SalaryTab.tsx and PayrollTab.tsx over backend apps/payroll
// (views/employee_salary.py, views/payslips.py). Both tabs follow the payroll
// module only (web ProfileTabBar TAB_MODULES); the server decides what each
// user sees (payroll.view, same branch for non-admins) and who may Assign /
// Revise CTC (payroll.edit). Synthetic people and pay; nothing real changes.

const code = 'EMP-70';
const uuid = '70707070-0000-4000-8000-000000000070';

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object data, [String message = 'ok']) => _json(200, {'status': 'success', 'message': message, 'data': data});
ResponseBody _err(int status, String message) => _json(status, {'status': 'error', 'message': message, 'data': {}});

Map<String, dynamic> revision(String id, String ctc, String monthly, String from,
        {bool active = false, String? structure, String? template, List<Map<String, dynamic>> components = const []}) =>
    {
      'id': id,
      'employee': uuid,
      'annual_ctc': ctc,
      'monthly_ctc': monthly,
      'salary_structure': structure == null ? null : 'st-1',
      'structure_name': structure,
      'template_structure_name': template,
      'effective_from': from,
      'is_active': active,
      'created_by_name': 'Hema HR',
      'components': components,
    };

Map<String, dynamic> component(String id, String name, String monthly, {String type = 'earning', bool enabled = true}) =>
    {'id': id, 'name': name, 'component_type': type, 'monthly_amount': monthly, 'is_enabled': enabled};

Map<String, dynamic> payslip(String id, String start, String status, {String? pdf, String? structure}) => {
      'id': id,
      'cycle_start': start,
      'pay_date': '${start.substring(0, 8)}28',
      'structure_name': structure,
      'gross_earnings': '52000.00',
      'total_deductions': '4200.50',
      'net_pay': '47799.50',
      'status': status,
      'payslip_pdf': pdf,
    };

class Backend implements HttpClientAdapter {
  Backend(this.me);
  final UserEntity me;
  final paths = <String>[];
  final posts = <Map<String, dynamic>>[];
  bool sameBranch = true;
  ({int status, String message})? refuseNext;
  List<Map<String, dynamic>> history = [
    revision('r2', '720000.00', '60000.00', '2026-04-01', active: true, structure: 'Standard', components: [
      component('c1', 'Basic', '30000.00'),
      component('c2', 'HRA', '12000.00'),
      component('c3', 'PF', '1800.00', type: 'deduction'),
      component('c4', 'Old Bonus', '500.00', enabled: false),
    ]),
    revision('r1', '600000.00', '50000.00', '2025-04-01', template: 'Starter'),
  ];
  List<Map<String, dynamic>> payslips = [
    payslip('p2', '2026-10-01', 'paid', pdf: 'https://files.test.invalid/payslips/oct.pdf', structure: 'Standard'),
    payslip('p1', '2026-09-01', 'queried'),
  ];

  bool can(String p) => me.isSuperuser || me.permissions.contains(p);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    final path = o.uri.path;
    paths.add('${o.method} $path');
    if (o.method == 'GET' && path == '/api/employees/$code/') {
      return _ok({
        'id': code,
        'uuid': uuid,
        'employee_id': code,
        'first_name': 'Ravi',
        'last_name': 'Test',
        'full_name': 'Ravi Test',
        'email': 'ravi.test@example.test',
        'department': 'QA',
        'designation': 'Analyst',
        'branch': 'North',
        'role': 'employee',
        'is_active': true,
        'status': 'active',
        'onboarding_status': 'complete',
        'documents': <Object>[],
        'profile': {'custom_field_values': <String, dynamic>{}},
      });
    }
    if (path == '/api/payroll/employee-salary/history/$uuid/') {
      if (!can('payroll.view')) return _err(403, 'Only HR admin can view salary history.');
      if (!sameBranch) return _err(403, 'Access denied.');
      return _ok(history, 'Salary history retrieved.');
    }
    if (path == '/api/payroll/employees/$uuid/payslips/') {
      if (!can('payroll.view')) return _err(403, 'Only HR admin can view payslips.');
      if (!sameBranch) return _err(403, 'Access denied.');
      return _ok({'count': payslips.length, 'page': 1, 'total_pages': 1, 'results': payslips});
    }
    if (path == '/api/payroll/structures/') {
      return _ok([
        {'id': 'st-1', 'name': 'Standard', 'is_default': true, 'is_active': true},
        {'id': 'st-2', 'name': 'Executive', 'is_default': false, 'is_active': true},
        {'id': 'st-3', 'name': 'Retired Plan', 'is_default': false, 'is_active': false},
      ]);
    }
    if (path == '/api/payroll/employee-salary/' && o.method == 'POST') {
      final b = Map<String, dynamic>.from(o.data as Map);
      posts.add(b);
      final r = refuseNext;
      if (r != null) {
        refuseNext = null;
        return _err(r.status, r.message);
      }
      if (!can('payroll.edit')) return _err(403, 'Only HR admin can assign salary configs.');
      history = [
        revision('r3', '${b['annual_ctc']}.00', '0', '${b['effective_from']}', active: true),
        for (final h in history) {...h, 'is_active': false},
      ];
      return _ok(history.first, 'Salary config saved.');
    }
    return _ok(<Object>[]);
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

UserEntity user(List<String> perms, {bool superuser = false, List<String>? modules, String id = 'hr1'}) => UserEntity(
      id: id,
      email: 'u@example.test',
      fullName: 'Test User',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final payrollAdmin = user(['employees.view', 'payroll.view', 'payroll.edit']);
final payrollViewer = user(['employees.view', 'payroll.view']);
final noPayroll = user(['employees.view']);

late Backend server;
final launched = <Uri>[];
Finder byKey(String k) => find.byKey(Key(k));

Future<void> pump(WidgetTester tester, UserEntity as, {void Function(Backend)? setup}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Backend(as);
  setup?.call(server);
  launched.clear();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      salaryDatePickerProvider.overrideWithValue((context, initial) async => DateTime(2026, 12, 1)),
      externalLinkLauncherProvider.overrideWithValue((uri) async {
        launched.add(uri);
        return true;
      }),
    ],
    child: MaterialApp(
      home: Consumer(
          builder: (_, ref, child) {
            ref.watch(authStateProvider);
            return child!;
          },
          child: const EmployeeProfileScreen(employeeId: code)),
    ),
  ));
  await tester.pumpAndSettle();
}

List<String> tabLabels(WidgetTester tester) => [
      for (final t in tester.widgetList<Tab>(find.descendant(of: find.byType(TabBar), matching: find.byType(Tab))))
        t.text ?? ''
    ];

Future<void> openTab(WidgetTester tester, String label) async {
  final tab = find.descendant(of: find.byType(TabBar), matching: find.text(label));
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

bool fetched(String suffix) => server.paths.any((p) => p.endsWith(suffix));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('formatting (web INR / fmtMonth)', () {
    test('rupees with Indian grouping, no decimals', () {
      expect(fmtInr('720000.00'), '₹7,20,000');
      expect(fmtInr('47799.50'), '₹47,800');
      expect(fmtInr('999'), '₹999');
      expect(fmtInr('1000'), '₹1,000');
      expect(fmtInr('12345678'), '₹1,23,45,678');
      expect(fmtInr(null), '₹0');
      expect(fmtPayMonth('2026-10-01'), 'Oct 2026');
    });
  });

  group('tabs', () {
    testWidgets('web order: Salary and Payroll right after Profile; nothing fetched until opened', (tester) async {
      await pump(tester, payrollAdmin);
      expect(tabLabels(tester).take(4), ['Profile', 'Salary', 'Payroll', 'Leave']);
      expect(fetched('/employee-salary/history/$uuid/'), isFalse);
      expect(fetched('/payroll/employees/$uuid/payslips/'), isFalse);
    });

    testWidgets('payroll module off: no Salary / Payroll tab and no payroll request', (tester) async {
      await pump(tester, user(payrollAdmin.permissions, modules: ['leave', 'attendance', 'assets']));
      expect(tabLabels(tester), isNot(contains('Salary')));
      expect(tabLabels(tester), isNot(contains('Payroll')));
      expect(server.paths.where((p) => p.contains('/payroll/')), isEmpty);
    });

    testWidgets('module switched off by a session refresh while on Payroll: tab gone, back to Profile',
        (tester) async {
      await pump(tester, user(payrollAdmin.permissions, modules: ['payroll', 'leave']));
      await openTab(tester, 'Payroll');
      final container = ProviderScope.containerOf(tester.element(find.byType(EmployeeProfileScreen)));
      container.read(authStateProvider.notifier).updateEnabledModules(const ['leave']);
      await tester.pumpAndSettle();
      expect(tabLabels(tester), isNot(contains('Payroll')));
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
    });
  });

  group('Salary', () {
    testWidgets('current CTC and revision history from the server (no local salary maths)', (tester) async {
      await pump(tester, payrollViewer);
      await openTab(tester, 'Salary');
      expect(tester.widget<Text>(byKey('salary-annual')).data, '₹7,20,000');
      expect(tester.widget<Text>(byKey('salary-monthly')).data, '₹60,000');
      expect(find.text('01 Apr 2026'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Revision History'), findsOneWidget);
      expect(find.text('₹7,20,000 / year · ₹60,000 / month'), findsOneWidget);
      expect(find.text('Structure: Starter'), findsOneWidget); // template name when no override
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('Earlier revision'), findsOneWidget);
      expect(find.text('From structure'), findsOneWidget); // r1 has no components
      // Components: only enabled ones, deductions marked.
      expect(find.text('3 components'), findsOneWidget);
      await tester.tap(find.text('3 components'));
      await tester.pumpAndSettle();
      expect(find.text('PF (deduction)'), findsOneWidget);
      expect(find.text('₹30,000/mo'), findsOneWidget);
      expect(find.text('Old Bonus'), findsNothing);
      // View only: no Assign / Revise.
      expect(byKey('salary-assign'), findsNothing);
    });

    testWidgets('no CTC yet: web empty text; "Assign CTC" for payroll.edit', (tester) async {
      await pump(tester, payrollAdmin, setup: (s) => s.history = []);
      await openTab(tester, 'Salary');
      expect(find.text('No CTC assigned'), findsOneWidget);
      expect(find.text('Assign CTC'), findsOneWidget);
      expect(byKey('salary-history'), findsNothing);
    });

    testWidgets('Revise CTC: prefilled; monthly preview; structures (active only); exact payload; reload',
        (tester) async {
      await pump(tester, payrollAdmin);
      await openTab(tester, 'Salary');
      await tapKey(tester, 'salary-assign');
      expect(find.text('Revise CTC'), findsWidgets);
      expect(tester.widget<TextField>(byKey('ctc-annual')).controller!.text, '720000');
      expect(find.text('Monthly: ₹60,000'), findsOneWidget);
      await tester.enterText(byKey('ctc-annual'), '840000');
      await tester.pumpAndSettle();
      expect(find.text('Monthly: ₹70,000'), findsOneWidget);
      await tapKey(tester, 'ctc-effective');
      await tester.tap(byKey('ctc-structure'));
      await tester.pumpAndSettle();
      expect(find.text('Standard (Default)'), findsWidgets);
      expect(find.text('Retired Plan'), findsNothing);
      await tester.tap(find.text('Executive').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'ctc-save');
      expect(server.posts.single, {
        'employee': uuid,
        'annual_ctc': '840000',
        'effective_from': '2026-12-01',
        'salary_structure': 'st-2',
      });
      expect(find.text('CTC revised successfully.'), findsOneWidget);
      expect(tester.widget<Text>(byKey('salary-annual')).data, '₹8,40,000'); // reloaded from the server
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('CTC revised successfully.'), findsNothing);
    });

    testWidgets('Assign CTC with the company default: salary_structure null; refusal shown', (tester) async {
      await pump(tester, payrollAdmin, setup: (s) => s.history = []);
      await openTab(tester, 'Salary');
      await tapKey(tester, 'salary-assign');
      expect(tester.widget<FilledButton>(byKey('ctc-save')).onPressed, isNull); // CTC required
      await tester.enterText(byKey('ctc-annual'), '500000');
      await tester.pumpAndSettle();
      server.refuseNext = (status: 400, message: 'A revision effective on this date already exists.');
      await tapKey(tester, 'ctc-save');
      expect(find.text('A revision effective on this date already exists.'), findsOneWidget);
      expect(server.posts.single['salary_structure'], isNull);
      await tapKey(tester, 'ctc-save');
      expect(find.text('CTC assigned successfully.'), findsOneWidget);
    });

    testWidgets('no payroll.view (profile access alone): the server refusal, no salary shown', (tester) async {
      await pump(tester, noPayroll);
      await openTab(tester, 'Salary');
      expect(find.text('Only HR admin can view salary history.'), findsOneWidget);
      expect(byKey('salary-annual'), findsNothing);
      expect(byKey('salary-assign'), findsNothing);
    });

    testWidgets('another branch (server scope): "Access denied."; Retry reloads', (tester) async {
      await pump(tester, payrollAdmin, setup: (s) => s.sameBranch = false);
      await openTab(tester, 'Salary');
      expect(find.text('Access denied.'), findsOneWidget);
      expect(byKey('salary-assign'), findsNothing);
      server.sameBranch = true;
      await tapKey(tester, 'salary-error-retry');
      expect(tester.widget<Text>(byKey('salary-annual')).data, '₹7,20,000');
    });

    testWidgets('settings.edit alone: no Assign / Revise (needs payroll.edit)', (tester) async {
      await pump(tester, user(['employees.view', 'payroll.view', 'settings.edit']));
      await openTab(tester, 'Salary');
      expect(byKey('salary-assign'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, user(['employees.view', 'payroll.view'], superuser: true));
      await openTab(tester, 'Salary');
      expect(byKey('salary-assign'), findsOneWidget); // web usePermission: superuser flag
    });
  });

  group('Payroll', () {
    testWidgets('payslip history as web: period, pay date, structure, amounts, status, download', (tester) async {
      await pump(tester, payrollViewer);
      await openTab(tester, 'Payroll');
      expect(find.text('Payslip History'), findsOneWidget);
      expect(find.text('Oct 2026'), findsOneWidget);
      expect(find.text('Pay date 28 Oct 2026 · Standard'), findsOneWidget);
      expect(find.text('Pay date 28 Sep 2026 · Default'), findsOneWidget);
      expect(tester.widget<Text>(byKey('payslip-net-p2')).data, 'Net ₹47,800');
      expect(find.text('Gross ₹52,000'), findsWidgets);
      expect(tester.widget<Text>(byKey('payslip-status-p2')).data, 'Paid');
      expect(tester.widget<Text>(byKey('payslip-status-p1')).data, 'Query Raised');
      expect(byKey('payslip-na-p1'), findsOneWidget);
      await tapKey(tester, 'payslip-download-p2');
      expect(launched.single.toString(), 'https://files.test.invalid/payslips/oct.pdf');
    });

    testWidgets('no payslips: web empty text', (tester) async {
      await pump(tester, payrollViewer, setup: (s) => s.payslips = []);
      await openTab(tester, 'Payroll');
      expect(find.text('No payslips yet'), findsOneWidget);
    });

    testWidgets('no payroll.view: the server refusal; nothing listed', (tester) async {
      await pump(tester, noPayroll);
      await openTab(tester, 'Payroll');
      expect(find.text('Only HR admin can view payslips.'), findsOneWidget);
      expect(find.text('Oct 2026'), findsNothing);
    });

    test('status labels as web STATUS_LABEL', () {
      expect(kEmployeePayslipStatusLabel, {
        'draft': 'Processing',
        'sent': 'Sent',
        'acknowledged': 'Acknowledged',
        'queried': 'Query Raised',
        'resolved': 'Query Resolved',
        'paid': 'Paid',
      });
    });
  });
}
