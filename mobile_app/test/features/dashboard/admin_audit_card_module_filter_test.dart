import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/admin_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';
import 'package:mobile_app/features/settings/presentation/providers/settings_providers.dart' show kAuditLogModules;

// Task 74 (audit L9): Admin dashboard "Audit Logs" card module filter.
// Backend SystemAdminAuditLogsView (GET /dashboard/system-admin/audit-logs/
// ?module&limit&offset): settings.edit (has_perm) only; module matched
// exactly against AuditLog.module; rows of subscription modules that are off
// are dropped (apps/tenants/access.py AUDIT_MODULES). The module names the
// backend writes, verified from every AuditLog create call: accounts,
// announcements, approvals, assets, birthday, branch, company,
// company_financial_year, documents, employees, leave, payroll, recruitment,
// settings, wfh, voice_commands. The old card offered 'attendance' and
// 'hrms', which match no audit row (attendance writes AttendanceAuditLog).
// Synthetic rows; a stand-in server applies the backend's exact match.

const backendModules = [
  'accounts', 'announcements', 'approvals', 'assets', 'birthday', 'branch', 'company', //
  'company_financial_year', 'documents', 'employees', 'leave', 'payroll', 'recruitment', 'settings', 'wfh',
  'voice_commands',
];

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> row(int id, String module) => {
      'id': id,
      'user': 'Actor $id',
      'action': '${module}_updated',
      'module': module,
      'object_id': '$id',
      'ip_address': '10.0.0.1',
      'created_at': '2026-11-01T10:00:00Z',
    };

class Server implements HttpClientAdapter {
  final auditQueries = <Map<String, dynamic>>[];
  int writes = 0;

  /// 30 accounts rows (two card pages), 3 leave rows, one row for every
  /// other written module — except birthday, which has none here.
  late final rows = [
    for (var i = 0; i < 30; i++) row(1000 - i, 'accounts'),
    for (var i = 0; i < 3; i++) row(900 - i, 'leave'),
    for (final (i, m) in backendModules.indexed)
      if (m != 'accounts' && m != 'leave' && m != 'birthday') row(800 - i, m),
  ];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') {
      writes++;
      return _json({'status': 'success', 'message': 'ok', 'data': {}});
    }
    if (o.path == '/dashboard/system-admin/audit-logs/') {
      final q = Map<String, dynamic>.of(o.queryParameters);
      auditQueries.add(q);
      final module = (q['module'] as String?) ?? '';
      final limit = int.parse('${q['limit'] ?? 20}');
      final offset = int.parse('${q['offset'] ?? 0}');
      final matching = module.isEmpty ? rows : rows.where((r) => r['module'] == module).toList(); // exact
      return _json({
        'status': 'success',
        'message': 'ok',
        'data': {
          'count': matching.length,
          'limit': limit,
          'offset': offset,
          'results': matching.skip(offset).take(limit).toList(),
        },
      });
    }
    return _json({'status': 'success', 'message': 'ok', 'data': <Object>[]});
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

class TestAuth extends AuthNotifier {
  TestAuth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

UserEntity user(List<String> perms, {bool superuser = false, List<String>? modules}) => UserEntity(
      id: 'a1',
      email: 'admin@example.test',
      fullName: 'Test Admin',
      role: 'r',
      roleDisplay: 'Admin',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final superuserOnly = user(const [], superuser: true);
final settingsAdmin = user(const ['settings.view', 'settings.edit']); // older session, no flag

late Server server;
final moduleButton = find.byKey(const Key('dashboard-audit-module'));

Future<void> pump(WidgetTester tester, UserEntity u,
    {Size size = const Size(1080, 9000), double textScale = 1, bool cardOnly = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => TestAuth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp.router(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      routerConfig: GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Consumer(builder: (context, ref, _) {
            ref.watch(authStateProvider);
            // cardOnly: the Audit Logs card by itself, as the dashboard
            // lays it out (padded), for layout checks.
            return cardOnly
                ? const Scaffold(
                    body: SingleChildScrollView(padding: EdgeInsets.all(16), child: AdminAuditLogsCard()))
                : const Scaffold(body: AdminDashboardView());
          }),
        ),
        GoRoute(path: AppRoutes.settingsAuditLog, builder: (_, __) => const Scaffold(body: Text('FULL AUDIT LOG'))),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> openMenu(WidgetTester tester) async {
  await tester.ensureVisible(moduleButton);
  await tester.tap(moduleButton);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String label) async {
  await openMenu(tester);
  await tester.tap(find.widgetWithText(PopupMenuItem<String>, label).last);
  await tester.pumpAndSettle();
}

List<String> menuLabels(WidgetTester tester) => [
      for (final item in tester.widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>)))
        ((item.child as Text).data ?? ''),
    ];

String moduleText(WidgetTester tester) => tester.widget<Text>(moduleButton).data!;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('the shared option list is exactly the module names the backend writes', () {
    expect(kAuditLogModules.map((m) => m.value).toSet(), backendModules.toSet());
    expect(kAuditLogModules.map((m) => m.value), isNot(contains('attendance')));
    expect(kAuditLogModules.map((m) => m.value), isNot(contains('hrms')));
  });

  group('options and exact values', () {
    testWidgets('All modules first, then every backend module by label; no attendance / hrms', (tester) async {
      await pump(tester, superuserOnly);
      expect(moduleText(tester), 'All modules');
      expect(server.auditQueries.single, {'limit': 20, 'offset': 0}); // no module
      await openMenu(tester);
      expect(menuLabels(tester), ['All modules', for (final m in kAuditLogModules) m.label]);
      for (final bad in ['attendance', 'hrms', 'Attendance', 'Employee', 'Auth', 'Expense']) {
        expect(menuLabels(tester), isNot(contains(bad)), reason: bad);
      }
    });

    testWidgets('each option sends its exact backend value, from offset 0, and shows only that module', (tester) async {
      await pump(tester, superuserOnly);
      for (final m in kAuditLogModules) {
        await choose(tester, m.label);
        expect(server.auditQueries.last, {'limit': 20, 'offset': 0, 'module': m.value}, reason: m.label);
        expect(moduleText(tester), m.label);
        if (m.value == 'birthday') {
          expect(find.text('No audit log entries yet'), findsOneWidget); // empty result
        } else {
          expect(find.text('${m.value}_updated'.toUpperCase()), findsWidgets, reason: m.value);
        }
        for (final other in backendModules.where((o) => o != m.value)) {
          expect(find.text('${other}_updated'.toUpperCase()), findsNothing, reason: '${m.value} shows only itself');
        }
      }
      expect(server.auditQueries.where((q) => q['module'] == 'attendance' || q['module'] == 'hrms'), isEmpty);
      expect(server.writes, 0);
    });

    testWidgets('back to All modules: module dropped from the request', (tester) async {
      await pump(tester, superuserOnly);
      await choose(tester, 'Leave');
      await choose(tester, 'All modules');
      expect(server.auditQueries.last, {'limit': 20, 'offset': 0});
      expect(moduleText(tester), 'All modules');
    });
  });

  group('paging, refresh, details', () {
    testWidgets('Load more continues the module; a new module starts again from offset 0', (tester) async {
      await pump(tester, superuserOnly);
      await choose(tester, 'Accounts');
      final more = find.text('Load more');
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(server.auditQueries.last, {'limit': 20, 'offset': 20, 'module': 'accounts'});
      expect(find.text('ACCOUNTS_UPDATED'), findsNWidgets(30));
      await choose(tester, 'Leave');
      expect(server.auditQueries.last, {'limit': 20, 'offset': 0, 'module': 'leave'});
      expect(find.text('LEAVE_UPDATED'), findsNWidgets(3));
      expect(find.text('ACCOUNTS_UPDATED'), findsNothing);
    });

    testWidgets('pull-to-refresh keeps the module', (tester) async {
      await pump(tester, superuserOnly);
      await choose(tester, 'Payroll');
      final n = server.auditQueries.length;
      final done = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator).first).onRefresh();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100)); // let the refetch start
      }
      await done;
      await tester.pumpAndSettle();
      expect(server.auditQueries.length, greaterThan(n));
      expect(server.auditQueries.last, {'limit': 20, 'offset': 0, 'module': 'payroll'});
      expect(moduleText(tester), 'Payroll');
    });

    testWidgets('rows keep their details; View all opens Settings → Audit Log', (tester) async {
      await pump(tester, superuserOnly);
      await choose(tester, 'Work From Home');
      expect(find.text('WFH_UPDATED'), findsOneWidget);
      expect(find.textContaining('Actor'), findsWidgets);
      final viewAll = find.text('View all');
      await tester.ensureVisible(viewAll);
      await tester.tap(viewAll);
      await tester.pumpAndSettle();
      expect(find.text('FULL AUDIT LOG'), findsOneWidget);
    });
  });

  group('subscription modules (backend hides those rows)', () {
    testWidgets('modules off: their options are hidden; core and voice commands stay', (tester) async {
      await pump(tester, user(const [], superuser: true, modules: const ['announcements', 'voice_commands']));
      await openMenu(tester);
      final labels = menuLabels(tester);
      for (final hidden in ['Leave', 'Payroll', 'Recruitment', 'Assets', 'Documents', 'Work From Home']) {
        expect(labels, isNot(contains(hidden)), reason: hidden);
      }
      for (final kept in ['Accounts', 'Announcements', 'Approvals', 'Birthday', 'Branch', 'Company', 'Settings', 'Employees', 'Voice Commands']) {
        expect(labels, contains(kept), reason: kept);
      }
    });

    testWidgets('every module off: Announcements still offered (the server never hides its rows)', (tester) async {
      // AUDIT_MODULES keys it 'announcement', but audit rows say
      // 'announcements', so those rows are always returned.
      await pump(tester, user(const [], superuser: true, modules: const []));
      await openMenu(tester);
      expect(menuLabels(tester), contains('Announcements'));
      expect(menuLabels(tester), isNot(contains('Leave')));
    });

    testWidgets('module list unknown (older session): every option offered', (tester) async {
      await pump(tester, superuserOnly);
      await openMenu(tester);
      expect(menuLabels(tester).length, kAuditLogModules.length + 1);
    });
  });

  group('access', () {
    testWidgets('settings.edit admin (no superuser flag): card works with the same values', (tester) async {
      await pump(tester, settingsAdmin);
      await choose(tester, 'Employees');
      expect(server.auditQueries.last, {'limit': 20, 'offset': 0, 'module': 'employees'});
    });

    test('only superusers / settings.edit get the admin dashboard (backend: settings.edit)', () {
      expect(resolveDashboardCategory(superuserOnly), 'admin');
      expect(resolveDashboardCategory(settingsAdmin), 'admin');
      for (final u in [
        user(const ['audit.view', 'employees.view']),
        user(const ['leave.view']),
        user(const ['settings.view']),
      ]) {
        expect(resolveDashboardCategory(u), isNot('admin'), reason: '${u.permissions}');
      }
      // Settings → Audit Log keeps its own audit.view route rule.
      expect(canAccessPath(user(const ['leave.view']), AppRoutes.settingsAuditLog), isFalse);
      expect(canAccessPath(user(const ['audit.view']), AppRoutes.settingsAuditLog), isTrue);
      expect(canAccessPath(superuserOnly, AppRoutes.settingsAuditLog), isTrue);
    });
  });

  // The card on its own: other admin dashboard sections have their own
  // large-text overflows, outside this task (reported separately).
  group('layout', () {
    testWidgets('whole admin dashboard at 360 dp, normal text: no overflow', (tester) async {
      await pump(tester, superuserOnly, size: const Size(360, 9000));
      expect(tester.takeException(), isNull);
      await choose(tester, 'Financial Year');
      expect(tester.takeException(), isNull);
    });

    for (final (label, scale) in [('×1.0', 1.0), ('×1.5', 1.5), ('×2.0', 2.0)]) {
      testWidgets('360 dp, text $label: Audit Logs card without overflow, longest label chosen', (tester) async {
        await pump(tester, superuserOnly, size: const Size(360, 9000), textScale: scale, cardOnly: true);
        expect(tester.takeException(), isNull);
        await choose(tester, 'Financial Year');
        expect(tester.takeException(), isNull);
        expect(server.auditQueries.last['module'], 'company_financial_year');
      });
    }
  });
}
