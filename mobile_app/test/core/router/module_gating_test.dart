import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/constants/app_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/network/auth_interceptor.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/approvals/presentation/providers/approvals_providers.dart';
import 'package:mobile_app/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:mobile_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/auth/data/models/user_model.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/navigation/nav_config.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';
import 'package:mobile_app/features/expenses/data/models/expense_model.dart';
import 'package:mobile_app/features/expenses/presentation/providers/expense_providers.dart';
import 'package:mobile_app/features/leave/domain/entities/leave_entity.dart';
import 'package:mobile_app/features/leave/presentation/providers/leave_providers.dart';
import 'package:mobile_app/features/my_requests/presentation/providers/my_requests_providers.dart';
import 'package:mobile_app/features/settings/presentation/settings_hub/settings_screen.dart';
import 'package:mobile_app/features/voice_commands/presentation/providers/voice_access_provider.dart';
import 'package:mobile_app/features/wfh/domain/entities/wfh_entity.dart';
import 'package:mobile_app/features/wfh/presentation/providers/wfh_providers.dart';

import '../../features/dashboard/dashboard_announcement_order_test.dart' as dash;
import '../../features/employees/employee_assets_tab_test.dart' as prof;

// Task 66: company (subscription) modules — web frontend/lib/modules.ts
// (hasModule, ROUTE_MODULES, KIND_MODULES), navConfig buildNav, proxy.ts route
// guard, settings/page.tsx, ProfileTabBar TAB_MODULES, approvals/page.tsx,
// TeamApprovalsSection, my-requests, dashboards and app/layout.tsx (voice).
// The list comes from login `enabled_modules` and each refreshed access
// token's `modules` claim (backend apps/accounts/tokens.py). Unknown list →
// everything shown. Synthetic sessions and stand-in servers only.

const allModules = [
  'announcements', 'assessments', 'assets', 'attendance', 'documents', 'expenses', 'face_attendance', //
  'leave', 'payroll', 'recruitment', 'separation', 'voice_commands', 'wfh',
];

UserEntity u(List<String> perms, {List<String>? modules, bool superuser = false, bool manager = false}) => UserEntity(
      id: 'u1',
      email: 'u@example.test',
      fullName: 'Test User',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      canManageTeam: manager,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

List<String> without(List<String> drop) => [for (final m in allModules) if (!drop.contains(m)) m];

final hrPerms = [
  'recruitment.view', 'assessments.view', 'facial_recognition.approve', 'employees.view', 'attendance.view', //
  'attendance.create', 'attendance.edit', 'leave.view', 'leave.approve', 'wfh.view', 'wfh.approve', 'expenses.view', //
  'expenses.approve', 'separation.approve', 'documents.view', 'settings.view', 'payroll.view',
];

List<String> navPaths(UserEntity user) => [for (final e in buildNav(user)) if (e is NavItem) e.path];

class _NullStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class _MemStorage extends SecureStorageService {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> deleteAll() async => values.clear();
  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);
}

class _Auth extends AuthNotifier {
  _Auth(this.user);
  final UserEntity user;
  @override
  Future<AuthState> build() async {
    final state = await super.build(); // keeps the session listeners
    return state.user == null ? AuthState(user: user) : state;
  }
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

/// Answers every GET with an empty list and records the paths asked for.
class Recorder implements HttpClientAdapter {
  final paths = <String>[];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    paths.add(o.path);
    return _json(200, {
      'status': 'success',
      'message': 'ok',
      'data': {'count': 0, 'page': 1, 'page_size': 100, 'total_pages': 1, 'results': <Object>[]},
    });
  }

  @override
  void close({bool force = false}) {}
}

String _jwt(Map<String, dynamic> payload) {
  String b(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.${b(payload)}.sig';
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules (web lib/modules.ts)', () {
    test('route → module, longest prefix, query ignored; core screens have none', () {
      expect(moduleForPath('/dashboard/attendance'), 'attendance');
      expect(moduleForPath('/dashboard/my-attendance'), 'attendance');
      expect(moduleForPath('/dashboard/face-id-registrations'), 'face_attendance');
      expect(moduleForPath('/dashboard/leave'), 'leave');
      expect(moduleForPath('/dashboard/wfh'), 'wfh');
      expect(moduleForPath('/dashboard/my-payslip'), 'payroll');
      expect(moduleForPath('/dashboard/expenses'), 'expenses');
      for (final p in ['/dashboard/interview-list', '/interview-list/bulk-import', '/dashboard/candidate-review', //
          '/dashboard/email-logs', '/dashboard/referrals', '/settings/referral-rules']) {
        expect(moduleForPath(p), 'recruitment', reason: p);
      }
      expect(moduleForPath('/dashboard/assessments'), 'assessments');
      expect(moduleForPath('/dashboard/my-assessments'), 'assessments');
      expect(moduleForPath('/settings/assessment-config'), 'assessments');
      expect(moduleForPath('/dashboard/separation/abc'), 'separation');
      expect(moduleForPath('/dashboard/announcements'), 'announcements');
      expect(moduleForPath('/dashboard/documents?category=policy'), 'documents');
      expect(moduleForPath('/dashboard/contacts'), 'documents');
      expect(moduleForPath('/settings/attendance-rules'), 'attendance');
      expect(moduleForPath('/settings/leave-policy/import-balances'), 'leave');
      expect(moduleForPath('/settings/holiday-calendar'), 'leave');
      for (final p in ['/dashboard', '/dashboard/employees/E1', '/dashboard/approvals', '/dashboard/my-requests', //
          '/dashboard/profile', '/dashboard/settings', '/settings/company', '/settings/notice-period', //
          '/settings/approval-rules', '/dashboard/attendance-x']) {
        expect(moduleForPath(p), isNull, reason: p);
      }
    });

    test('hasModule: unknown list (legacy session) → everything; known list → only those', () {
      expect(userHasModule(u(const []), 'leave'), isTrue); // enabledModules null
      expect(userHasModule(null, 'leave'), isTrue);
      expect(userHasModule(u(const [], modules: const []), 'leave'), isFalse);
      expect(userHasModule(u(const [], modules: const ['leave']), 'leave'), isTrue);
      expect(userHasModule(u(const [], modules: const ['leave']), null), isTrue); // core
      expect(userHasModule(u(const [], modules: const ['leave']), 'not_a_module'), isFalse);
    });

    test('module and permission are separate: each must allow the screen', () {
      final permitted = u(const ['leave.view'], modules: const ['attendance']);
      expect(canAccessPath(permitted, '/dashboard/leave'), isFalse); // permission, no module
      final moduleOnly = u(const [], modules: const ['leave']);
      expect(canAccessPath(moduleOnly, '/dashboard/leave'), isFalse); // module, no permission
      expect(canAccessPath(u(const ['leave.view'], modules: const ['leave']), '/dashboard/leave'), isTrue);
      expect(canAccessPath(u(const ['leave.view']), '/dashboard/leave'), isTrue); // legacy session
      // settings.edit still passes permission checks, never a missing module.
      final admin = u(const ['settings.edit'], superuser: true, modules: const []);
      expect(canAccessPath(admin, '/dashboard/leave'), isFalse);
      expect(canAccessPath(admin, '/dashboard/employees'), isTrue);
      // Self-service screens follow their module too.
      expect(canAccessPath(u(const [], modules: const []), '/dashboard/my-attendance'), isFalse);
      expect(canAccessPath(u(const [], modules: const ['attendance']), '/dashboard/my-attendance'), isTrue);
    });
  });

  group('navigation', () {
    test('menu: items of disabled modules are left out; empty sections dropped', () {
      final all = navPaths(u(hrPerms, superuser: true));
      expect(all, containsAll(['/dashboard/attendance', '/dashboard/leave', '/dashboard/interview-list', //
          '/dashboard/my-payslip', '/dashboard/documents', '/dashboard/contacts', '/dashboard/announcements']));
      final none = navPaths(u(hrPerms, superuser: true, modules: const []));
      for (final p in all) {
        expect(none.contains(p), moduleForPath(p) == null, reason: p);
      }
      expect(none, containsAll(['/dashboard', '/dashboard/employees', '/dashboard/approvals', '/dashboard/my-requests', //
          '/dashboard/profile', '/dashboard/settings']));
      // Recruitment section disappears with its items (sections without items dropped).
      final sections = [for (final e in buildNav(u(hrPerms, superuser: true, modules: const []))) if (e is NavSection) e.title];
      expect(sections, isNot(contains('Recruitment')));
      // One module on.
      final leaveOnly = navPaths(u(hrPerms, superuser: true, modules: const ['leave']));
      expect(leaveOnly, contains('/dashboard/leave'));
      expect(leaveOnly, isNot(contains('/dashboard/attendance')));
      expect(leaveOnly, isNot(contains('/dashboard/my-attendance')));
    });

    test('each module on/off moves exactly its own menu items', () {
      final full = u(hrPerms, superuser: true, modules: allModules);
      final base = navPaths(full);
      for (final m in allModules) {
        final paths = navPaths(u(hrPerms, superuser: true, modules: without([m])));
        final gone = base.where((p) => !paths.contains(p)).toList();
        expect(gone.every((p) => moduleForPath(p) == m), isTrue, reason: '$m: $gone');
        expect(base.where((p) => moduleForPath(p) == m).every(gone.contains), isTrue, reason: m);
      }
    });

    test('dashboard quick tiles: by module, then permission', () {
      final paths = [for (final i in visibleQuickItems(kQuickItemsEmployee, u(const [], modules: const ['documents']))) i.path];
      expect(paths, isNot(contains('/dashboard/leave')));
      expect(paths, isNot(contains('/dashboard/my-attendance')));
      expect(paths, isNot(contains('/dashboard/my-payslip')));
      expect(paths, contains('/dashboard/profile'));
      final legacy = [for (final i in visibleQuickItems(kQuickItemsEmployee, u(const ['leave.view']))) i.path];
      expect(legacy, containsAll(['/dashboard/leave', '/dashboard/my-attendance']));
    });

    test('direct navigation to a disabled module goes to the dashboard', () {
      final s = AuthState(user: u(hrPerms, modules: const ['leave']));
      expect(resolveAuthRedirect(authState: s, path: '/dashboard/attendance'), AppRoutes.dashboard);
      expect(resolveAuthRedirect(authState: s, path: '/dashboard/my-payslip'), AppRoutes.dashboard);
      expect(resolveAuthRedirect(authState: s, path: '/settings/attendance-rules'), AppRoutes.dashboard);
      expect(resolveAuthRedirect(authState: s, path: '/dashboard/leave'), isNull);
      expect(resolveAuthRedirect(authState: s, path: '/dashboard/employees'), isNull);
      // Legacy session: allowed as before.
      expect(resolveAuthRedirect(authState: AuthState(user: u(hrPerms)), path: '/dashboard/attendance'), isNull);
    });

    test('voice assistant only with voice_commands (unknown list → shown)', () {
      expect(isVoiceAssistantAllowed(AuthState(user: u(const []))), isTrue);
      expect(isVoiceAssistantAllowed(AuthState(user: u(const [], modules: const ['voice_commands']))), isTrue);
      expect(isVoiceAssistantAllowed(AuthState(user: u(const [], modules: const ['leave']))), isFalse);
    });
  });

  group('screens', () {
    Future<void> pump(WidgetTester tester, UserEntity user, Widget child, {Recorder? server}) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => _Auth(user)),
          dioProvider.overrideWithValue(
              Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server ?? Recorder()),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullStorage()),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) =>
                ref.watch(authStateProvider).valueOrNull?.user == null ? const SizedBox() : Scaffold(body: child),
          ),
        ),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    testWidgets('Settings hub: module sections hidden; core sections kept', (tester) async {
      await pump(tester, u(const ['settings.view'], modules: const ['payroll']), const SettingsScreen());
      for (final t in ['Leave Policy', 'Attendance Rules', 'Holiday Calendar', 'Referral Rules', 'Assessment Config']) {
        expect(find.text(t), findsNothing, reason: t);
      }
      for (final t in ['Company', 'Notice Period', 'Approval Rules', 'Onboarding Fields']) {
        expect(find.textContaining(t), findsWidgets, reason: t);
      }
      await tester.pumpWidget(const SizedBox());
      await pump(tester, u(const ['settings.view']), const SettingsScreen()); // legacy
      expect(find.text('Leave Policy'), findsOneWidget);
      expect(find.text('Attendance Rules'), findsOneWidget);
    });

    testWidgets('Approvals: Attendance Approval needs attendance; Face ID needs face_attendance', (tester) async {
      // payroll.edit: what the attendance-approval endpoints check (Task 77).
      final perms = ['leave.approve', 'facial_recognition.approve', 'payroll.edit'];
      await pump(tester, u(perms, modules: allModules), const ApprovalsScreen());
      expect(find.text('Attendance Approval'), findsOneWidget);
      expect(find.text('Face Registration'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, u(perms, modules: without(['attendance', 'face_attendance'])), const ApprovalsScreen());
      expect(find.text('Attendance Approval'), findsNothing);
      expect(find.text('Face Registration'), findsNothing);
      expect(find.text('Team Approvals'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    test('Team Approvals: no request for a disabled kind; type tabs follow', () async {
      final server = Recorder();
      ProviderContainer containerFor(UserEntity user) {
        final c = ProviderContainer(overrides: [
          authStateProvider.overrideWith(() => _Auth(user)),
          dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullStorage()),
        ]);
        addTearDown(c.dispose);
        return c;
      }

      var c = containerFor(u(hrPerms, modules: const ['leave']));
      await c.read(authStateProvider.future);
      final sub = c.listen(unifiedTeamApprovalsProvider, (_, __) {});
      await c.read(unifiedTeamApprovalsProvider.future);
      expect(server.paths.any((p) => p.startsWith('/leave/')), isTrue);
      for (final p in server.paths) {
        expect(p.contains('expense') || p.contains('wfh') || p.contains('separation') || //
            p.contains('/attendance/') || p.contains('/payroll/'), isFalse, reason: p);
      }
      sub.close();
      expect([for (final t in ApprovalsTypeTab.values) if (userHasModule(u(const [], modules: const ['leave']), moduleForApprovalsTab(t))) t],
          [ApprovalsTypeTab.all, ApprovalsTypeTab.leave]);

      server.paths.clear();
      c = containerFor(u(hrPerms)); // legacy: everything asked for
      await c.read(authStateProvider.future);
      final sub2 = c.listen(unifiedTeamApprovalsProvider, (_, __) {});
      await c.read(unifiedTeamApprovalsProvider.future);
      expect(server.paths.any((p) => p.contains('/attendance/corrections/')), isTrue);
      expect(server.paths.any((p) => p.contains('/payroll/')), isTrue);
      sub2.close();
    });

    test('My Requests: a disabled kind is never fetched; tabs follow', () async {
      final asked = <String>[];
      final c = ProviderContainer(overrides: [
        authStateProvider.overrideWith(() => _Auth(u(const [], modules: const ['leave', 'wfh']))),
        secureStorageProvider.overrideWithValue(_NullStorage()),
        cookieJarProvider.overrideWithValue(CookieJar()),
        leaveRequestsProvider.overrideWith(() => _Leave(asked)),
        wfhMyRequestsProvider.overrideWith(() => _Wfh(asked)),
        expenseListProvider.overrideWith(() => _Expenses(asked)),
        myCorrectionsProvider.overrideWith((ref) async {
          asked.add('attendance');
          return const <MyCorrectionEntity>[];
        }),
      ]);
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final sub = c.listen(myRequestsProvider, (_, __) {});
      await c.read(myRequestsProvider.future);
      expect(asked..sort(), ['leave', 'wfh']);
      sub.close();
      final tabs = [
        for (final t in MyRequestsTypeTab.values)
          if (userHasModule(u(const [], modules: const ['leave', 'wfh']), moduleForMyRequestsTab(t))) t
      ];
      expect(tabs, [MyRequestsTypeTab.all, MyRequestsTypeTab.leave, MyRequestsTypeTab.wfh]);
    });
  });

  group('employee profile tabs (web ProfileTabBar)', () {
    List<String> tabLabels(WidgetTester tester) => [
          for (final t in tester.widgetList<Tab>(find.descendant(of: find.byType(TabBar), matching: find.byType(Tab))))
            t.text ?? ''
        ];

    testWidgets('all modules / unknown list: web order', (tester) async {
      await prof.pumpProfile(tester, prof.user(['employees.view', 'assets.view']), openTab: false);
      expect(tabLabels(tester),
          ['Profile', 'Salary', 'Payroll', 'Leave', 'Attendance', 'Approval Matrix', 'Promotion', 'Assets', 'Send Wishes']);
    });

    testWidgets('without leave / attendance / assets: those tabs are left out, order kept', (tester) async {
      await prof.pumpProfile(tester,
          prof.user(['employees.view', 'assets.view'], modules: without(['leave', 'attendance', 'assets'])),
          openTab: false);
      expect(tabLabels(tester), ['Profile', 'Salary', 'Payroll', 'Approval Matrix', 'Promotion', 'Send Wishes']);
    });

    testWidgets('a module change (session refresh) updates the tabs and keeps the selected one', (tester) async {
      await prof.pumpProfile(tester, prof.user(['employees.view', 'assets.view'], modules: allModules), openTab: false);
      await tester.tap(find.text('Promotion'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(EmployeeProfileScreen)));
      container.read(authStateProvider.notifier).updateEnabledModules(without(['leave']));
      await tester.pumpAndSettle();
      expect(tabLabels(tester),
          ['Profile', 'Salary', 'Payroll', 'Attendance', 'Approval Matrix', 'Promotion', 'Assets', 'Send Wishes']);
      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.controller!.index, 5); // still Promotion
    });
  });

  group('dashboards', () {
    testWidgets('employee: attendance / leave / documents cards hidden and not fetched', (tester) async {
      await dash.pumpHome(tester, u(const ['leave.view'], modules: const ['announcements']));
      expect(find.text('Days Present'), findsNothing);
      expect(find.text('Absent Days'), findsNothing);
      expect(find.text('Expenses'), findsNothing);
      expect(find.text('Action Items'), findsWidgets);
      for (final p in [ApiConstants.attendanceToday, '/dashboard/employee/leave-balances/', //
          '/dashboard/employee/attendance-summary/', ApiConstants.documentPendingAcknowledgements]) {
        expect(dash.backend.paths.contains(p), isFalse, reason: p);
      }
      await dash.unmount(tester);
    });

    testWidgets('employee, legacy session: unchanged (attendance and leave fetched)', (tester) async {
      await dash.pumpHome(tester, u(const ['leave.view']));
      expect(find.text('Days Present'), findsOneWidget);
      expect(dash.backend.paths, contains(ApiConstants.attendanceToday));
      expect(dash.backend.paths, contains('/dashboard/employee/leave-balances/'));
      await dash.unmount(tester);
    });

    testWidgets('HR: announcements / attendance / recruitment cards and figures follow modules', (tester) async {
      final hrUser = u(const ['employees.view', 'leave.view'], modules: const ['leave']);
      await dash.pumpHome(tester, hrUser);
      expect(find.text('Interviews'), findsNothing);
      expect(find.text('Corrections'), findsNothing);
      expect(find.text('Workforce'), findsOneWidget);
      expect(dash.backend.paths.contains('/dashboard/hr/attendance-summary/'), isFalse);
      expect(dash.backend.paths.contains(ApiConstants.attendanceToday), isFalse);
      expect(dash.backend.paths.contains('/dashboard/announcement/'), isFalse);
      await dash.unmount(tester);
    });

    testWidgets('manager: attendance and leave figures follow modules', (tester) async {
      await dash.pumpHome(tester, u(const ['leave.view'], manager: true, modules: const ['announcements']));
      final stats = find.byKey(const Key('manager-stats'));
      expect(find.descendant(of: stats, matching: find.text('Team Size')), findsOneWidget);
      expect(find.descendant(of: stats, matching: find.text('Pending')), findsNothing);
      expect(find.descendant(of: stats, matching: find.text('Attendance')), findsNothing);
      await dash.unmount(tester);
    });
  });

  group('session', () {
    test('modules survive the cached session (login → restart)', () {
      final m = UserModel.fromJson({
        'id': 'u1', 'email': 'e@x.test', 'full_name': 'T', 'role': 'hr', 'role_display': 'HR', //
        'must_change_password': false, 'permissions': <String>[], 'enabled_modules': ['leave', 'payroll'],
      });
      expect(UserModel.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>).enabledModules,
          ['leave', 'payroll']);
      final legacy = UserModel.fromJson({
        'id': 'u1', 'email': 'e@x.test', 'full_name': 'T', 'role': 'hr', 'role_display': 'HR', //
        'must_change_password': false, 'permissions': <String>[],
      });
      expect(legacy.enabledModules, isNull);
      // Garbage values don't crash: non-strings are dropped.
      final odd = UserModel.fromJson({
        'id': 'u1', 'email': 'e@x.test', 'full_name': 'T', 'role': 'hr', 'role_display': 'HR', //
        'must_change_password': false, 'permissions': <String>[], 'enabled_modules': ['leave', 3, null],
      });
      expect(odd.enabledModules, ['leave']);
    });

    test('token claim: only a list of strings counts (web modulesFromPayload)', () {
      expect(modulesFromAccessToken(_jwt({'modules': ['leave', 'wfh']})), ['leave', 'wfh']);
      expect(modulesFromAccessToken(_jwt({'modules': []})), <String>[]);
      expect(modulesFromAccessToken(_jwt({'user_id': 'x'})), isNull);
      expect(modulesFromAccessToken(_jwt({'modules': ['leave', 3]})), isNull);
      expect(modulesFromAccessToken('not-a-jwt'), isNull);
      expect(modulesFromAccessToken(null), isNull);
    });

    test('a refreshed token with a new module list updates the cache and the signed-in user', () async {
      final storage = _MemStorage()
        ..values[AppConstants.keyUserData] = jsonEncode(UserModel.fromJson({
          'id': 'u1', 'email': 'e@x.test', 'full_name': 'T', 'role': 'hr', 'role_display': 'HR', //
          'must_change_password': false, 'permissions': ['leave.view'], 'enabled_modules': ['leave', 'attendance'],
        }).toJson())
        ..values[AppConstants.keyRefreshToken] = 'r1';
      final c = ProviderContainer(overrides: [
        secureStorageProvider.overrideWithValue(storage),
        cookieJarProvider.overrideWithValue(CookieJar()),
      ]);
      addTearDown(c.dispose);
      final authSub = c.listen(authStateProvider, (_, __) {});
      final before = await c.read(authStateProvider.future);
      expect(before.user!.enabledModules, ['leave', 'attendance']);
      expect(canAccessPath(before.user, '/dashboard/my-attendance'), isTrue);

      var first = true;
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'));
      dio.httpClientAdapter = _Scripted((o) async {
        if (o.path == ApiConstants.tokenRefresh) {
          return _json(200, {
            'status': 'success',
            'data': {'access': _jwt({'modules': ['leave']}), 'refresh': 'r2'},
          });
        }
        if (first) {
          first = false;
          return _json(401, {'status': 'error', 'message': 'expired'});
        }
        return _json(200, {'status': 'success', 'data': {}});
      });
      dio.interceptors.add(c.read(authInterceptorProvider(dio)));
      await dio.get('/employees/me/');

      final after = c.read(authStateProvider).value!.user!;
      expect(after.enabledModules, ['leave']);
      expect(canAccessPath(after, '/dashboard/my-attendance'), isFalse);
      expect(navPaths(after), isNot(contains('/dashboard/my-attendance')));
      final cached = jsonDecode(storage.values[AppConstants.keyUserData]!) as Map<String, dynamic>;
      expect(cached['enabled_modules'], ['leave']);
      expect(cached['permissions'], ['leave.view']); // the rest of the session untouched
      authSub.close();
    });

    test('a refreshed token without the claim changes nothing', () async {
      final storage = _MemStorage()
        ..values[AppConstants.keyUserData] = jsonEncode(UserModel.fromJson({
          'id': 'u1', 'email': 'e@x.test', 'full_name': 'T', 'role': 'hr', 'role_display': 'HR', //
          'must_change_password': false, 'permissions': <String>[], 'enabled_modules': ['leave'],
        }).toJson());
      final c = ProviderContainer(overrides: [
        secureStorageProvider.overrideWithValue(storage),
        cookieJarProvider.overrideWithValue(CookieJar()),
      ]);
      addTearDown(c.dispose);
      final authSub = c.listen(authStateProvider, (_, __) {});
      await c.read(authStateProvider.future);
      var first = true;
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'));
      dio.httpClientAdapter = _Scripted((o) async {
        if (o.path == ApiConstants.tokenRefresh) {
          return _json(200, {'status': 'success', 'data': {'access': _jwt({'user_id': 'u1'})}});
        }
        if (first) {
          first = false;
          return _json(401, {'status': 'error', 'message': 'expired'});
        }
        return _json(200, {'status': 'success', 'data': {}});
      });
      dio.interceptors.add(c.read(authInterceptorProvider(dio)));
      await dio.get('/employees/me/');
      expect(c.read(authStateProvider).value!.user!.enabledModules, ['leave']);
      authSub.close();
    });

    test('users differing only in modules are different (anything comparing users sees the change)', () {
      final a = u(const [], modules: const ['leave']);
      expect(a == a.withEnabledModules(const ['leave']), isTrue);
      expect(a == a.withEnabledModules(const ['leave', 'wfh']), isFalse);
      expect(a == a.withEnabledModules(null), isFalse);
      expect(AuthState(user: a) == AuthState(user: a.withEnabledModules(const [])), isFalse);
    });

    test('same list again: no new user state (no needless menu rebuild)', () async {
      final c = ProviderContainer(overrides: [
        authStateProvider.overrideWith(() => _Auth(u(const [], modules: const ['leave']))),
        secureStorageProvider.overrideWithValue(_NullStorage()),
        cookieJarProvider.overrideWithValue(CookieJar()),
      ]);
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      var changes = 0;
      c.listen(authStateProvider, (_, __) => changes++);
      c.read(authStateProvider.notifier).updateEnabledModules(const ['leave']);
      expect(changes, 0);
      c.read(authStateProvider.notifier).updateEnabledModules(const ['leave', 'wfh']);
      expect(changes, 1);
      expect(c.read(authStateProvider).value!.user!.enabledModules, ['leave', 'wfh']);
    });
  });
}

class _Scripted implements HttpClientAdapter {
  _Scripted(this.respond);
  final Future<ResponseBody> Function(RequestOptions o) respond;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) => respond(o);
  @override
  void close({bool force = false}) {}
}

class _Leave extends LeaveRequestsNotifier {
  _Leave(this.asked);
  final List<String> asked;
  @override
  Future<List<LeaveRequestEntity>> build() async {
    asked.add('leave');
    return const [];
  }
}

class _Wfh extends WfhMyRequestsNotifier {
  _Wfh(this.asked);
  final List<String> asked;
  @override
  Future<List<WfhRequestEntity>> build() async {
    asked.add('wfh');
    return const [];
  }
}

class _Expenses extends ExpenseListNotifier {
  _Expenses(this.asked);
  final List<String> asked;
  @override
  Future<List<ExpenseModel>> build() async {
    asked.add('expenses');
    return const [];
  }
}
