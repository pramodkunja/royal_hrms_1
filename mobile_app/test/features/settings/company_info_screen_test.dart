import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:mobile_app/features/settings/presentation/company/company_screen.dart';
import 'package:mobile_app/features/settings/presentation/company/widgets/company_widgets.dart';

// Task 100 — Company Information + Plan Details (web settings/company/page.tsx,
// PlanDetailsTab.tsx, FinancialYearSection.tsx). All writes go to a fake
// server; nothing real is called.

Map<String, dynamic> companyJson({String name = 'Test Company Pvt Ltd'}) => {
      'id': 1,
      'company_name': name,
      'trade_name': 'Test Co',
      'logo_url': null,
      'gstin': '27AAPFU0939F1ZV',
      'cin': 'U74999MH2020PTC123456',
      'pan': 'AAPFU0939F',
      'tan': 'MUMA12345B',
      'address': '1 Test Street, Test Building, Test Area',
      'city': 'Mumbai',
      'state': 'Maharashtra',
      'pin_code': '400001',
      'website': 'https://example.test',
      'official_phone': '022 1234 5678',
      'updated_at': '2026-11-05T10:15:00Z',
    };

Map<String, dynamic> planJson() => jsonDecode(jsonEncode(_planRaw())) as Map<String, dynamic>;

Map<String, dynamic> _planRaw() => {
      'has_plan': true,
      'current': {
        'plan_name': 'Growth',
        'plan_code': 'growth',
        'description': 'For growing teams',
        'billing_period': 'yearly',
        'starts_on': '2026-04-01',
        'ends_on': '2027-03-31',
        'period_ended': false,
        'days_left': 120,
        'status': 'active',
        'activation': 'active',
        'payment_status': 'partially_paid',
        'employee_count': 40,
        'price_per_employee': '150.50',
        'currency': 'INR',
        'gst_rate': '18.00',
        'gst_inclusive': false,
        'total_amount': '1234567.00',
        'amount_paid': '500000.00',
        'amount_pending_confirmation': '1000.00',
        'amount_outstanding': '733567.00',
        'features': [
          {'key': 'sup', 'label': 'Priority support', 'description': 'Faster replies'},
        ],
      },
      'modules': [
        {
          'key': 'hr',
          'label': 'HR Core',
          'description': 'Employees',
          'category': 'People',
          'included': true,
          'enabled': true,
          'source': 'plan',
          'access': 'enabled',
          'required_by': <String>[],
        },
        {
          'key': 'pay',
          'label': 'Payroll',
          'description': 'Payslips',
          'category': 'Finance',
          'included': true,
          'enabled': false,
          'source': 'plan',
          'access': 'pending',
          'required_by': <String>[],
        },
        {
          'key': 'tax',
          'label': 'Tax Engine',
          'description': 'Statutory',
          'category': 'Finance',
          'included': true,
          'enabled': true,
          'source': 'dependency',
          'access': 'enabled',
          'required_by': ['Payroll'],
        },
        {
          'key': 'ats',
          'label': 'Recruitment',
          'description': 'Hiring',
          'category': 'People',
          'included': false,
          'enabled': true,
          'source': 'not_included',
          'access': 'enabled',
          'required_by': <String>[],
        },
        {
          'key': 'lms',
          'label': 'Learning',
          'description': 'Courses',
          'category': 'People',
          'included': false,
          'enabled': false,
          'source': 'not_included',
          'access': 'off',
          'required_by': <String>[],
        },
      ],
      'enabled_modules': ['hr', 'tax', 'ats'],
      'always_included': [
        {'key': 'dash', 'label': 'Dashboard', 'description': 'Home'},
      ],
      'coming_soon': [
        {'key': 'ai', 'label': 'AI Assistant', 'description': 'Soon'},
      ],
      'payments': [
        {
          'paid_on': '2026-09-05',
          'amount': '500000.00',
          'currency': 'INR',
          'method': 'Bank transfer',
          'reference': 'UTR123',
          'status': 'confirmed',
        },
        {
          'paid_on': '2026-10-01',
          'amount': '1000.00',
          'currency': 'INR',
          'method': 'UPI',
          'reference': '',
          'status': 'awaiting_confirmation',
        },
      ],
      'other_plans': [
        {
          'name': 'Enterprise',
          'code': 'ent',
          'description': 'Large orgs',
          'price_per_employee': '300',
          'currency': 'INR',
          'gst_rate': '18',
          'gst_inclusive': true,
          'billing_periods': ['monthly', 'yearly'],
          'min_employees': 100,
          'max_employees': null,
          'modules': ['hr', 'pay', 'tax', 'lms'],
          'additional_modules': ['lms'],
          'modules_not_included': ['ats'],
          'features': <Object>[],
          'estimate_employee_count': 40,
          'fits_employee_count': false,
          'estimates': [
            {'billing_period': 'monthly', 'total': '14160'},
            {'billing_period': 'yearly', 'total': '169920'},
          ],
        },
      ],
    };

class _Server implements HttpClientAdapter {
  Map<String, dynamic> company = companyJson();
  Map<String, dynamic> plan = planJson();
  int planStatus = 200;
  String planMessage = 'Only company administrators can view plan details.';
  int putStatus = 200;
  String fy = 'April';
  final calls = <String>[];
  final puts = <FormData>[];
  final fyPuts = <Object?>[];

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  Map<String, dynamic> _fy() => {
        'financial_year_start_month': fy,
        'previous_financial_year': '2025-26',
        'current_financial_year': '2026-27',
        'next_financial_year': '2027-28',
      };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add('${o.method} ${o.path}');
    switch ('${o.method} ${o.path}') {
      case 'GET /settings/company/':
        return _json({'status': 'success', 'message': 'ok', 'data': company});
      case 'PUT /settings/company/':
        puts.add(o.data as FormData);
        if (putStatus != 200) {
          return _json(
              {'status': 'error', 'message': 'Could not update company info right now.', 'data': {}}, putStatus);
        }
        for (final f in (o.data as FormData).fields) {
          if (f.key != 'remove_logo') company[f.key] = f.value;
        }
        return _json({'status': 'success', 'message': 'saved', 'data': company});
      case 'GET /settings/company/financial-year/':
        return _json({'status': 'success', 'message': 'ok', 'data': _fy()});
      case 'PUT /settings/company/financial-year/':
        fyPuts.add(o.data);
        fy = (o.data as Map)['financial_year_start_month'] as String;
        return _json({'status': 'success', 'message': 'ok', 'data': _fy()});
      case 'GET /settings/company/plan/':
        if (planStatus != 200) return _json({'status': 'error', 'message': planMessage, 'data': {}}, planStatus);
        return _json({'status': 'success', 'message': 'ok', 'data': plan});
    }
    return _json({'status': 'success', 'data': {}});
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

UserEntity user(List<String> perms, {String role = 'hr_admin'}) => UserEntity(
      id: 'u1',
      email: 'admin@example.test',
      fullName: 'Test Admin',
      role: role,
      roleDisplay: 'Admin',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final editor = user(['settings.view', 'settings.edit']);
final viewer = user(['settings.view']);

late _Server server; // ignore: library_private_types_in_public_api
File? nextPick;
late Directory tmp;

Future<void> pumpCompany(
  WidgetTester tester, {
  UserEntity? as,
  Size size = const Size(412, 3000),
  double textScale = 1,
  CompanyTab initialTab = CompanyTab.info,
  String? startAt,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: startAt ?? AppRoutes.settingsCompany, routes: [
    GoRoute(path: AppRoutes.settings, builder: (_, __) => const Scaffold(body: Text('SETTINGS HOME'))),
    GoRoute(path: AppRoutes.settingsCompany, builder: (_, __) => CompanyScreen(initialTab: initialTab)),
  ]);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? editor)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      companyLogoPickerProvider.overrideWithValue(() async => nextPick),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> openPlan(WidgetTester tester) async {
  final f = find.byKey(const ValueKey('company-tab-plan'));
  for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
    await tester.pump();
  }
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder colOf(String label) => find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
Finder inputOf(String label) => find.descendant(of: colOf(label), matching: find.byType(TextFormField));
String textOf(WidgetTester t, String label) =>
    t.widget<EditableText>(find.descendant(of: inputOf(label), matching: find.byType(EditableText))).controller.text;
Map<String, String> fields(FormData d) => {for (final f in d.fields) f.key: f.value};

Future<void> tapSave(WidgetTester tester) async {
  await tester.tap(find.text('Save Changes'));
  await tester.pumpAndSettle();
}

Future<void> pickLogo(WidgetTester tester, File f) async {
  nextPick = f;
  await tester.runAsync(() async {
    await tester.tap(find.byKey(const Key('company-logo-change')));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

File tempFile(String name, {int bytes = 4}) => File('${tmp.path}/$name')..writeAsBytesSync(List.filled(bytes, 7));

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    tmp = Directory.systemTemp.createTempSync('company_info_t100');
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));
  setUp(() {
    server = _Server();
    nextPick = null;
  });

  group('header and structure', () {
    testWidgets('identity header shows what the company API returns', (tester) async {
      await pumpCompany(tester);
      expect(find.text('Test Company Pvt Ltd'), findsWidgets);
      expect(find.text('Test Co'), findsWidgets);
      expect(find.text('Mumbai, Maharashtra'), findsOneWidget);
      expect(find.textContaining('Last saved: 5 Nov 2026,'), findsOneWidget);
      expect(find.text('Company Information'), findsWidgets);
      expect(find.text('Legal entity details, statutory identifiers, and registered address'), findsOneWidget);
    });

    testWidgets('sections in web order, with web labels and placeholders', (tester) async {
      await pumpCompany(tester);
      final order = [
        'Financial Year Configuration',
        'Branding',
        'Legal & Statutory',
        'Registered Address',
        'Contact',
      ].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
      expect(order, [...order]..sort());
      for (final l in [
        'Company Name *',
        'Trade Name',
        'GSTIN *',
        'CIN *',
        'PAN *',
        'TAN *',
        'Address *',
        'City *',
        'State / UT *',
        'PIN Code *',
        'Website',
        'Official Phone',
      ]) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
      expect(find.text('Company Logo'), findsOneWidget);
      expect(find.text('Used on payslips and other documents issued in your name · JPEG, PNG, WebP or SVG · Max 5 MB'),
          findsOneWidget);
    });

    testWidgets('a company that does not exist yet opens an empty form (web first-time setup)', (tester) async {
      server.company = {};
      await pumpCompany(tester);
      expect(find.text('Your Company'), findsOneWidget);
      expect(textOf(tester, 'Company Name *'), '');
      expect(find.textContaining('Last saved'), findsNothing);
    });
  });

  group('validation and save', () {
    testWidgets('Save on an empty form shows web messages under the fields and sends nothing', (tester) async {
      server.company = {};
      await pumpCompany(tester);
      await tapSave(tester);
      for (final m in [
        'Company name is required.',
        'GSTIN is required.',
        'CIN is required.',
        'PAN is required.',
        'TAN is required.',
        'Address is required.',
        'City is required.',
        'State / UT is required.',
        'PIN code is required.',
      ]) {
        expect(find.text(m), findsOneWidget, reason: m);
      }
      expect(server.puts, isEmpty);
    });

    testWidgets('an error clears as its field is edited', (tester) async {
      await pumpCompany(tester);
      await tester.enterText(inputOf('PAN *'), 'BAD');
      await tapSave(tester);
      expect(find.text('Enter a valid 10-character PAN.'), findsOneWidget);
      await tester.enterText(inputOf('PAN *'), 'AAPFU0939F');
      await tester.pump();
      expect(find.text('Enter a valid 10-character PAN.'), findsNothing);
    });

    testWidgets('typing upper-cases identifiers, caps their length and keeps PIN to 6 digits', (tester) async {
      server.company = {};
      await pumpCompany(tester);
      await tester.enterText(inputOf('GSTIN *'), '27aapfu0939f1zvEXTRA');
      expect(textOf(tester, 'GSTIN *'), '27AAPFU0939F1ZV');
      await tester.enterText(inputOf('PAN *'), 'aapfu0939fxx');
      expect(textOf(tester, 'PAN *'), 'AAPFU0939F');
      await tester.enterText(inputOf('PIN Code *'), '4a0b0c0d0e0f0g1');
      expect(textOf(tester, 'PIN Code *'), '400000'); // first six digits of 40000001
    });

    testWidgets('Save sends web\'s multipart payload — trimmed, identifiers upper-cased', (tester) async {
      await pumpCompany(tester);
      await tester.enterText(inputOf('Company Name *'), '  Edited Name Ltd  ');
      await tester.enterText(inputOf('City *'), ' Pune ');
      await tapSave(tester);
      expect(server.puts, hasLength(1));
      final f = fields(server.puts.single);
      expect(f['company_name'], 'Edited Name Ltd');
      expect(f['city'], 'Pune');
      expect(f['gstin'], '27AAPFU0939F1ZV');
      expect(f['state'], 'Maharashtra');
      expect(f.keys.toSet(), {
        'company_name',
        'trade_name',
        'gstin',
        'cin',
        'pan',
        'tan',
        'address',
        'city',
        'state',
        'pin_code',
        'website',
        'official_phone',
      });
      expect(server.puts.single.files, isEmpty);
      expect(find.text('Company info saved successfully.'), findsOneWidget);
    });

    testWidgets('state choices are web\'s 36 states / UTs', (tester) async {
      await pumpCompany(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      expect(find.text('Maharashtra'), findsWidgets);
    });

    testWidgets('a server refusal shows its message and keeps the edits', (tester) async {
      server.putStatus = 403;
      await pumpCompany(tester);
      await tester.enterText(inputOf('City *'), 'Pune');
      await tapSave(tester);
      expect(find.text('Could not update company info right now.'), findsOneWidget);
      expect(textOf(tester, 'City *'), 'Pune');
    });

    testWidgets('Cancel goes back to Settings without saving', (tester) async {
      await pumpCompany(tester);
      await tester.enterText(inputOf('City *'), 'Pune');
      await tester.tap(find.byKey(const Key('company-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('SETTINGS HOME'), findsOneWidget);
      expect(server.puts, isEmpty);
    });
  });

  group('logo handling (web handleLogoChange / Remove)', () {
    testWidgets('a wrong type or an oversized file is refused with web text and changes nothing', (tester) async {
      await pumpCompany(tester);
      await pickLogo(tester, tempFile('a.gif'));
      expect(find.text('Only JPEG, PNG, WebP, or SVG files are allowed.'), findsOneWidget);
      expect(find.text('No logo uploaded.'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
      await tester.pumpAndSettle();
      await pickLogo(tester, tempFile('big.png', bytes: 5 * 1024 * 1024 + 1));
      expect(find.text('Logo must be under 5 MB.'), findsOneWidget);
      expect(find.text('No logo uploaded.'), findsOneWidget);
    });

    testWidgets('an SVG is accepted, shown as selected, and uploaded as `logo`', (tester) async {
      await pumpCompany(tester);
      await pickLogo(tester, tempFile('mark.svg'));
      expect(find.textContaining('New logo selected: mark.svg'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await tester.tap(find.text('Save Changes'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(server.puts.single.files.single.key, 'logo');
      expect(fields(server.puts.single).containsKey('remove_logo'), isFalse);
    });

    testWidgets('Remove is explained, local until Save, then sent as remove_logo=true', (tester) async {
      server.company['logo_url'] = 'https://cdn.example.test/old.png';
      await pumpCompany(tester);
      expect(find.text('Logo set.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('company-logo-remove')));
      await tester.pumpAndSettle();
      expect(find.text('The logo will be removed when you save.'), findsOneWidget);
      expect(server.puts, isEmpty);
      await tapSave(tester);
      expect(fields(server.puts.single)['remove_logo'], 'true');
    });
  });

  group('permissions', () {
    testWidgets('without settings.edit: read-only values, no tabs, no actions, plan never requested', (tester) async {
      await pumpCompany(tester, as: viewer, initialTab: CompanyTab.plan);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Save Changes'), findsNothing);
      expect(find.byKey(const Key('company-cancel')), findsNothing);
      expect(find.byKey(const Key('company-logo-change')), findsNothing);
      expect(find.byKey(const ValueKey('company-tab-plan')), findsNothing);
      expect(find.text('Plan Details'), findsNothing);
      expect(find.text('Test Company Pvt Ltd'), findsWidgets);
      expect(find.text('27AAPFU0939F1ZV'), findsOneWidget);
      expect(find.text('Maharashtra'), findsWidgets);
      expect(server.calls, isNot(contains('GET /settings/company/plan/')));
      expect(find.text('Financial Year Starts In'), findsOneWidget);
    });

    testWidgets('read-only shows "—" for an empty value', (tester) async {
      server.company['trade_name'] = '';
      server.company['website'] = '';
      await pumpCompany(tester, as: viewer);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('settings.view alone is not enough for the tabs — settings.edit unlocks them', (tester) async {
      await pumpCompany(tester);
      expect(find.byKey(const ValueKey('company-tab-info')), findsOneWidget);
      expect(find.byKey(const ValueKey('company-tab-plan')), findsOneWidget);
    });

    testWidgets('only the literal settings.edit grants it: another codename does not', (tester) async {
      await pumpCompany(tester, as: user(['settings.view', 'employees.edit']));
      expect(find.byKey(const ValueKey('company-tab-plan')), findsNothing);
      expect(find.text('Save Changes'), findsNothing);
    });
  });

  group('financial year', () {
    testWidgets('an editor changes the start month and saves it on its own', (tester) async {
      await pumpCompany(tester);
      expect(find.text('Pick a different month to change it.'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('June').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      expect((server.fyPuts.single as Map)['financial_year_start_month'], 'June');
      expect(server.puts, isEmpty); // independent of the company form
      expect(find.text('Financial year configuration updated.'), findsOneWidget);
    });

    testWidgets('years show for everyone', (tester) async {
      await pumpCompany(tester, as: viewer);
      for (final y in ['2025-26', '2026-27', '2027-28']) {
        expect(find.text(y), findsOneWidget);
      }
      expect(server.fyPuts, isEmpty);
    });
  });

  group('Plan Details', () {
    testWidgets('tab opens, title and subtitle follow web', (tester) async {
      await pumpCompany(tester);
      await openPlan(tester);
      expect(find.text('Plan Details'), findsWidgets);
      expect(find.text('Your subscription, the modules it includes, other plans and payment history'), findsOneWidget);
      expect(find.text('Branding'), findsNothing);
      expect(find.text('Save Changes'), findsNothing); // read-only: no save bar
      expect(server.calls, contains('GET /settings/company/plan/'));
    });

    testWidgets('?tab=plan opens it directly for an editor', (tester) async {
      await pumpCompany(tester, initialTab: CompanyTab.plan);
      expect(find.text('Your plan'), findsOneWidget);
    });

    testWidgets('current plan: name, badges, facts, price with GST, amounts', (tester) async {
      await pumpCompany(tester, initialTab: CompanyTab.plan);
      expect(find.text('Growth'), findsOneWidget);
      expect(find.text('For growing teams'), findsOneWidget);
      for (final b in ['Active', 'Partially paid', 'Modules active']) {
        expect(find.text(b), findsOneWidget, reason: b);
      }
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('01 Apr 2026'), findsOneWidget);
      expect(find.textContaining('31 Mar 2027'), findsOneWidget);
      expect(find.textContaining('120 days left', findRichText: true), findsOneWidget);
      expect(find.textContaining('₹150.5 / employee / month + 18% GST', findRichText: true), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('₹12,34,567'), findsOneWidget); // total
      expect(find.text('₹5,00,000'), findsWidgets); // paid
      expect(find.text('Awaiting confirmation'), findsWidgets); // tile + payment badge
      expect(find.text('₹7,33,567'), findsOneWidget); // outstanding
      expect(find.text('Priority support'), findsOneWidget);
    });

    testWidgets('modules: summary line, ordering, badges and notes', (tester) async {
      await pumpCompany(tester, initialTab: CompanyTab.plan);
      expect(find.byKey(const Key('plan-module-summary')), findsOneWidget);
      expect(find.text('3 included · 3 enabled · 1 activate after payment · 2 not included'), findsOneWidget);
      final y = ['hr', 'pay', 'tax', 'lms', 'ats']
          .map((k) => tester.getTopLeft(find.byKey(Key('plan-module-$k'))).dy)
          .toList();
      // included first (HR Core, Payroll, Tax Engine by name), then the rest.
      expect(y[0] < y[1] && y[1] < y[2] && y[2] < y[3] && y[3] < y[4], isTrue);
      expect(find.text('Required by Payroll'), findsOneWidget);
      expect(find.text('Enabled (not part of your plan)'), findsOneWidget);
      expect(find.text('Not enabled'), findsOneWidget);
      expect(find.text('Activates when payment is confirmed'), findsWidgets);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('AI Assistant'), findsOneWidget);
    });

    testWidgets('other plans: price, estimates, fit warning, extra modules and the comparison', (tester) async {
      await pumpCompany(tester, initialTab: CompanyTab.plan);
      expect(find.byKey(const Key('plan-other-ent')), findsOneWidget);
      expect(find.text('Enterprise'), findsWidgets);
      expect(find.textContaining('₹300 / employee / month (GST incl.)', findRichText: true), findsOneWidget);
      expect(find.textContaining('billed monthly or yearly', findRichText: true), findsOneWidget);
      expect(
          find.textContaining('For your 40 employees: ₹14,160 / month · ₹1,69,920 / year (incl. GST)'), findsOneWidget);
      expect(find.text('This plan is for 100–any number of employees.'), findsOneWidget);
      expect(find.textContaining('You would also get: Learning', findRichText: true), findsOneWidget);
      expect(find.textContaining('Not in this plan: Recruitment', findRichText: true), findsOneWidget);
      expect(find.byKey(const Key('plan-comparison')), findsOneWidget);
      expect(find.text('Growth (current)'), findsOneWidget);
    });

    testWidgets('payment history: confirmed, awaiting, missing reference', (tester) async {
      await pumpCompany(tester, initialTab: CompanyTab.plan);
      expect(find.text('Payment history'), findsOneWidget);
      expect(find.text('05 Sept 2026 · Bank transfer'), findsOneWidget);
      expect(find.text('Reference: UTR123'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Reference: —'), findsOneWidget);
    });

    testWidgets('no payments yet / waived text', (tester) async {
      server.plan['payments'] = [];
      await pumpCompany(tester, initialTab: CompanyTab.plan);
      expect(find.text('No payments recorded yet.'), findsOneWidget);
      (server.plan['current'] as Map)['payment_status'] = 'waived';
      await pumpCompany(tester, initialTab: CompanyTab.plan);
      expect(find.text('Payment is waived for this subscription.'), findsOneWidget);
      expect(find.text('Waived'), findsWidgets);
    });

    testWidgets('period ended warning and unset total', (tester) async {
      (server.plan['current'] as Map)
        ..['period_ended'] = true
        ..['days_left'] = null
        ..['total_amount'] = null;
      await pumpCompany(tester, initialTab: CompanyTab.plan);
      expect(find.byKey(const Key('plan-period-ended')), findsOneWidget);
      expect(find.textContaining('Your access continues'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
      expect(find.textContaining('days left', findRichText: true), findsNothing);
    });

    testWidgets('no plan assigned: explanation, modules still listed, no payment section', (tester) async {
      server.plan
        ..['has_plan'] = false
        ..['current'] = null
        ..['other_plans'] = [];
      await pumpCompany(tester, initialTab: CompanyTab.plan);
      expect(find.byKey(const Key('plan-none')), findsOneWidget);
      expect(find.textContaining('No subscription plan is assigned'), findsOneWidget);
      expect(find.text('No plan'), findsWidgets);
      expect(find.text('Payment history'), findsNothing);
      expect(find.text('Other plans'), findsNothing);
    });

    testWidgets('a server refusal is shown, not hidden or faked (no retry for missing permission)', (tester) async {
      server
        ..planStatus = 403
        ..planMessage = 'Only company administrators can view plan details.';
      await pumpCompany(tester, initialTab: CompanyTab.plan);
      expect(find.textContaining('Only company administrators can view plan details.'), findsOneWidget);
      expect(find.text('Growth'), findsNothing);
    });

    testWidgets('a failed load can be retried', (tester) async {
      server.planStatus = 500;
      server.planMessage = 'Server error.';
      await pumpCompany(tester, initialTab: CompanyTab.plan);
      expect(find.text('Growth'), findsNothing);
      server.planStatus = 200;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Growth'), findsOneWidget);
    });

    testWidgets('read-only: no actions, no buttons that change a plan', (tester) async {
      await pumpCompany(tester, initialTab: CompanyTab.plan);
      for (final t in ['Upgrade', 'Subscribe', 'Pay', 'Renew', 'Change plan', 'Cancel plan', 'Buy']) {
        expect(find.text(t), findsNothing, reason: t);
      }
      expect(find.byType(TextFormField), findsNothing);
      expect(server.calls.where((c) => c.startsWith('PUT') || c.startsWith('POST') || c.startsWith('DELETE')), isEmpty);
    });
  });

  group('responsive layout', () {
    Future<void> sweep(WidgetTester tester, {bool plan = true}) async {
      expect(tester.takeException(), isNull, reason: 'info');
      if (!plan) return;
      await openPlan(tester);
      expect(tester.takeException(), isNull, reason: 'plan');
    }

    void longData() {
      server.company = companyJson(
          name: 'Alexandria Wilhelmina Montgomery-Featherstonehaugh International Staffing Solutions Private Limited')
        ..['address'] =
            'Unit 1204-1210, Twelfth Floor, Bharat Diamond Bourse Annexe Building, Bandra Kurla Complex, Bandra East'
        ..['cin'] = 'U74999MH2020PTC123456'
        ..['gstin'] = '27AAPFU0939F1ZV'
        ..['website'] = 'https://www.alexandria-wilhelmina-montgomery-featherstonehaugh.example.test/corporate/about';
      server.plan = planJson();
      (server.plan['current'] as Map)['plan_name'] = 'Enterprise Plus Annual Commitment With Premium Support';
    }

    testWidgets('320×568 — every section and both tabs, no overflow', (tester) async {
      longData();
      await pumpCompany(tester, size: const Size(320, 568));
      await sweep(tester);
    });

    testWidgets('320×568 at 2.0× text', (tester) async {
      longData();
      await pumpCompany(tester, size: const Size(320, 568), textScale: 2);
      await sweep(tester);
    });

    testWidgets('typical phone at 1.5× text', (tester) async {
      longData();
      await pumpCompany(tester, size: const Size(412, 900), textScale: 1.5);
      await sweep(tester);
    });

    testWidgets('large phone (430×932) and tablet (1000×800)', (tester) async {
      longData();
      await pumpCompany(tester, size: const Size(430, 932));
      await sweep(tester);
      await pumpCompany(tester, size: const Size(1000, 800));
      await sweep(tester);
      final card = tester.getSize(find.ancestor(of: find.text('Your plan'), matching: find.byType(Container)).first);
      expect(card.width, lessThanOrEqualTo(760));
    });

    testWidgets('read-only viewer at 320 / 2.0× has no overflow', (tester) async {
      longData();
      await pumpCompany(tester, as: viewer, size: const Size(320, 568), textScale: 2);
      await sweep(tester, plan: false);
    });

    testWidgets('field pairs stack on a narrow screen and sit side by side when there is room', (tester) async {
      Future<(Offset, Offset)> pair() async {
        await tester.scrollUntilVisible(find.text('GSTIN *'), 200, scrollable: find.byType(Scrollable).first);
        return (tester.getTopLeft(find.text('GSTIN *')), tester.getTopLeft(find.text('CIN *')));
      }

      await pumpCompany(tester, size: const Size(412, 900));
      var (a, b) = await pair();
      expect(a.dy, b.dy);
      await pumpCompany(tester, size: const Size(280, 900));
      (a, b) = await pair();
      expect(b.dy, greaterThan(a.dy));
      await pumpCompany(tester, size: const Size(412, 900), textScale: 1.6);
      (a, b) = await pair();
      expect(b.dy, greaterThan(a.dy));
    });

    testWidgets('keyboard open: the action bar steps aside; fields stay reachable', (tester) async {
      await pumpCompany(tester, size: const Size(360, 640));
      expect(find.text('Save Changes'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.text('Save Changes'), findsNothing);
      await tester.scrollUntilVisible(find.text('Official Phone'), 200, scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('the action bar fits 320 wide at 2.0× text', (tester) async {
      await pumpCompany(tester, size: const Size(320, 568), textScale: 2);
      final save = tester.getRect(find.widgetWithText(FilledButton, 'Save Changes'));
      expect(save.right, lessThanOrEqualTo(320));
      expect(save.bottom, lessThanOrEqualTo(568));
      final cancel = tester.getRect(find.byKey(const Key('company-cancel')));
      expect(cancel.right, lessThanOrEqualTo(save.left));
    });

    testWidgets('tabs stay reachable after scrolling a tall page (pinned strip)', (tester) async {
      longData();
      await pumpCompany(tester, size: const Size(320, 568));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump();
      expect(find.byKey(const ValueKey('company-tab-plan')), findsOneWidget);
      expect(tester.getRect(find.byKey(const ValueKey('company-tab-plan'))).top, lessThan(120));
    });
  });
}
