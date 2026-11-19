import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_ui.dart' show ApprovalsTabLabel;
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/delegations_tab.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/navigation/nav_config.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';

// Task 71g (audit findings L6, L7): final route-access policy.
//  L6 — Approvals: the backend lets two groups delegate
//       (apps/approvals/services.py can_approve_workflow): has_perm
//       leave.approve, or attendance.create held by attendance staff
//       (apps/attendance/access.py can_manage_attendance). The Delegation
//       tab lives only on Approvals, whose route needed leave / expenses /
//       wfh / separation .approve — attendance-only delegators could not
//       reach it. Route, drawer and quick tile now also admit
//       canDelegateApprovals; every tab and queue keeps its own check.
//  L7 — mobile route / menu checks pass settings.edit and the superuser flag
//       (backend core/permissions.py has_perm); web's proxy.ts compares the
//       raw codename list. Every route's primary endpoint authorises those
//       admins and scopes rows server-side, so the access is kept and
//       documented; module gates still apply.
// Synthetic users; a stand-in server records every request.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object data) => _json(200, {'status': 'success', 'message': 'ok', 'data': data});
Map<String, dynamic> page(List<Object> rows) =>
    {'count': rows.length, 'page': 1, 'page_size': 100, 'total_pages': 1, 'results': rows};

Map<String, dynamic> person(String id, String name) => {'id': id, 'name': name, 'employee_id': 'EMP-$id', 'branch': 'North'};

Map<String, dynamic> delegation(String id, {bool canRevoke = true}) => {
      'id': id,
      'delegator': person('u1', 'Test User'),
      'delegate': person('u2', 'Asha Approver'),
      'start_date': '2026-11-10',
      'end_date': '2026-11-20',
      'workflows': ['attendance'],
      'reason': '',
      'active': true,
      'revoked': false,
      'revoked_at': null,
      'can_revoke': canRevoke,
      'given': true,
      'received': false,
      'created_at': '2026-11-01T10:00:00Z',
    };

class Server implements HttpClientAdapter {
  final gets = <(String, Map<String, dynamic>)>[];
  final writes = <(String, String)>[];
  List<Map<String, dynamic>> delegations = [delegation('D1'), delegation('D2', canRevoke: false)];
  String? refuse;

  bool asked(String path, [bool Function(Map<String, dynamic>)? q]) =>
      gets.any((g) => g.$1 == path && (q == null || q(g.$2)));

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'GET') {
      gets.add((o.path, Map.of(o.queryParameters)));
    } else {
      writes.add((o.method, o.path));
      if (refuse != null) return _json(403, {'status': 'error', 'message': refuse, 'data': {}});
      return _ok(<String, dynamic>{});
    }
    if (o.path == '/approvals/delegations/') return _ok(delegations);
    if (o.path == '/approvals/delegations/eligible/') return _ok(<Object>[]);
    return _ok(page(const []));
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

UserEntity user(List<String> perms, {bool superuser = false, bool team = false, bool branch = false, List<String>? modules}) =>
    UserEntity(
      id: 'u1',
      email: 'u@example.test',
      fullName: 'Test User',
      role: 'r',
      roleDisplay: 'Role',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      canManageTeam: team,
      canManageBranch: branch,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final superuserOnly = user(const [], superuser: true); // 1
final settingsAdmin = user(['settings.view', 'settings.edit'], superuser: true); // 2
final olderAdmin = user(['settings.view', 'settings.edit']); // 3 (no flag)
final leaveApprover = user(['leave.view', 'leave.approve']); // 4
final expenseApprover = user(['expenses.view', 'expenses.approve']); // 5
final wfhApprover = user(['wfh.approve']); // 6
final separationApprover = user(['separation.approve']); // 7
final attendanceStaff = user(['attendance.view', 'attendance.create', 'attendance.edit']); // 8
final teamManager = user(['attendance.view', 'attendance.create'], team: true); // 8 (staff by role flag)
final branchManager = user(['attendance.create'], branch: true); // 8 (staff by role flag)
final attendanceCreateOnly = user(['attendance.view', 'attendance.create']); // My Attendance only, not staff
final employee = user(['leave.view', 'leave.create', 'attendance.view']); // 9
final unrelated = user(['documents.view', 'expenses.view', 'facial_recognition.view']); // 10

bool navHasApprovals(UserEntity u) => buildNav(u).any((e) => e is NavItem && e.path == AppRoutes.approvals);
bool tileHasApprovals(UserEntity u) => visibleQuickItems(kQuickItemsManager, u).any((i) => i.path == AppRoutes.approvals);

/// The route rule before Task 71g: the codename list only.
bool before(UserEntity u) => userHasAnyPermission(u, requiredPermissionsFor(AppRoutes.approvals)!);

late Server server;

Future<void> pumpApprovals(WidgetTester tester, UserEntity u, {void Function(Server)? setup}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => TestAuth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      approvalsTodayProvider.overrideWithValue(() => DateTime(2026, 11, 13, 10)),
    ],
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
            ? const SizedBox()
            : const Scaffold(body: ApprovalsScreen()),
      ),
    ),
  ));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

List<String> tabs(WidgetTester tester) => [
      for (final t in tester.widgetList<Tab>(find.byType(Tab))) (t.child as ApprovalsTabLabel).label,
    ];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('L6 — Approvals reachability (route, direct link, drawer, quick tile, Delegation)', () {
    // (label, user, route before, route after, may delegate)
    final matrix = <(String, UserEntity, bool, bool, bool)>[
      ('explicit superuser, no codes', superuserOnly, true, true, true),
      ('settings.edit admin', settingsAdmin, true, true, true),
      ('older settings.edit session (no flag)', olderAdmin, true, true, true),
      ('leave approver', leaveApprover, true, true, true),
      ('expense approver', expenseApprover, true, true, false),
      ('WFH approver', wfhApprover, true, true, false),
      ('separation approver', separationApprover, true, true, false),
      ('attendance staff (create + edit)', attendanceStaff, false, true, true),
      ('team manager with attendance.create', teamManager, false, true, true),
      ('branch manager with attendance.create', branchManager, false, true, true),
      ('attendance.create without staff (My Attendance)', attendanceCreateOnly, false, false, false),
      ('ordinary employee', employee, false, false, false),
      ('unrelated permissions', unrelated, false, false, false),
    ];
    for (final (label, u, was, now, delegates) in matrix) {
      test('$label: route ${was ? '✓' : '✗'} → ${now ? '✓' : '✗'}, delegate ${delegates ? '✓' : '✗'}', () {
        expect(before(u), was, reason: 'route before 71g');
        expect(canAccessPath(u, AppRoutes.approvals), now, reason: 'route');
        expect(resolveAuthRedirect(authState: AuthState(user: u), path: AppRoutes.approvals), now ? isNull : AppRoutes.dashboard,
            reason: 'direct navigation');
        expect(navHasApprovals(u), now, reason: 'drawer');
        expect(tileHasApprovals(u), now, reason: 'dashboard quick tile');
        expect(canDelegateApprovals(u), delegates, reason: 'Delegation tab');
        // Nobody gets a route they couldn't use: every admitted user has a tab.
        if (now) expect(before(u) || delegates, isTrue);
      });
    }

    test('isAttendanceStaff mirrors the backend is_attendance_staff', () {
      expect(isAttendanceStaff(superuserOnly), isTrue);
      expect(isAttendanceStaff(olderAdmin), isTrue); // settings.edit, no flag
      expect(isAttendanceStaff(attendanceStaff), isTrue); // attendance.edit
      expect(isAttendanceStaff(teamManager), isTrue);
      expect(isAttendanceStaff(branchManager), isTrue);
      expect(isAttendanceStaff(attendanceCreateOnly), isFalse);
      expect(isAttendanceStaff(employee), isFalse);
      expect(isAttendanceStaff(null), isFalse);
    });

    test('the alternative rule is confined to Approvals', () {
      expect(kRouteAlternativeAccess.keys, [AppRoutes.approvals]);
      for (final p in ['/dashboard/attendance', '/dashboard/leave', '/dashboard/employees', '/settings']) {
        expect(alternativeRouteAccess(attendanceStaff, p), isFalse, reason: p);
      }
      // HR Attendance (Task 71c) unchanged: create + edit staff, not a team
      // manager holding attendance.create only.
      expect(canAccessPath(attendanceStaff, '/dashboard/attendance'), isTrue);
      expect(canAccessPath(teamManager, '/dashboard/attendance'), isFalse);
    });

    test('modules: the route is core (no module), as before; module-gated tabs stay gated', () {
      final noModules = user(['attendance.create', 'attendance.edit'], modules: const []);
      expect(moduleForPath(AppRoutes.approvals), isNull);
      expect(canAccessPath(noModules, AppRoutes.approvals), isTrue); // delegation is not module-gated (backend / web)
      expect(canAccessPath(user(['leave.approve'], modules: const []), AppRoutes.approvals), isTrue);
    });
  });

  group('L6 — Approvals screen for an attendance-only delegator', () {
    testWidgets('tabs: own corrections queue and Delegation only; no other queue fetched', (tester) async {
      await pumpApprovals(tester, attendanceStaff);
      expect(tabs(tester), ['Team Approvals', 'Delegation']);
      // Authorised queue: attendance corrections, unfiltered by branch (the
      // server scopes rows: apps/attendance/access.py).
      expect(server.asked('/attendance/corrections/'), isTrue);
      expect(server.gets.where((g) => g.$1 == '/attendance/corrections/').every((g) => !g.$2.containsKey('branch')), isTrue);
      // Unauthorised queues: nothing requested.
      expect(server.asked('/leave/requests/'), isFalse);
      expect(server.asked('/expenses/'), isFalse);
      expect(server.gets.where((g) => g.$1.startsWith('/wfh')), isEmpty);
      expect(server.asked('/separation/requests/'), isFalse);
      expect(server.gets.where((g) => g.$1.startsWith('/attendance/face-registration')), isEmpty);
      expect(server.writes, isEmpty);
    });

    testWidgets('Delegation: rows follow the server\'s can_revoke; a refusal is shown', (tester) async {
      await pumpApprovals(tester, attendanceStaff, setup: (s) => s.refuse = 'You can only revoke your own delegations.');
      await tester.tap(find.widgetWithText(Tab, 'Delegation'));
      await settle(tester);
      expect(server.asked('/approvals/delegations/'), isTrue);
      expect(find.byKey(const Key('delegation-revoke-D1')), findsOneWidget);
      expect(find.byKey(const Key('delegation-revoke-D2')), findsNothing); // can_revoke false
      await tester.tap(find.byKey(const Key('delegation-revoke-D1')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('delegation-revoke-confirm')));
      await settle(tester);
      expect(server.writes.single, ('POST', '/approvals/delegations/D1/revoke/'));
      expect(find.text('You can only revoke your own delegations.'), findsOneWidget);
    });

    for (final (label, u) in [('expense approver', expenseApprover), ('WFH approver', wfhApprover), ('separation approver', separationApprover)]) {
      testWidgets('$label: no Delegation tab and no delegation request', (tester) async {
        await pumpApprovals(tester, u);
        expect(tabs(tester), isNot(contains('Delegation')));
        expect(server.gets.where((g) => g.$1.startsWith('/approvals/delegations')), isEmpty);
        expect(server.asked('/attendance/corrections/'), isFalse);
      });
    }

    testWidgets('older settings.edit session: Delegation shown (backend has_perm passes settings.edit)', (tester) async {
      await pumpApprovals(tester, olderAdmin);
      expect(tabs(tester), contains('Delegation'));
    });

    for (final (label, u) in [('ordinary employee', employee), ('unrelated permissions', unrelated), ('attendance.create without staff', attendanceCreateOnly)]) {
      testWidgets('$label (screen reached without the guard): no queue or delegation request', (tester) async {
        await pumpApprovals(tester, u);
        expect(tabs(tester), isNot(contains('Delegation')));
        expect(server.gets.where((g) => g.$1.startsWith('/approvals/delegations')), isEmpty);
        expect(server.asked('/leave/requests/'), isFalse);
        expect(server.asked('/expenses/'), isFalse);
      });
    }
  });

  group('L7 — settings.edit / superuser route access (kept; web proxy.ts compares the raw list)', () {
    // Route → web proxy.ts codenames (raw list). Backend primary endpoints
    // all use core/permissions.py has_perm (superuser / settings.edit pass);
    // leave and expenses lists are scoped by the server (own / team /
    // branch; all for settings.edit).
    const web = <String, List<String>>{
      '/dashboard/interview-list': ['recruitment.view'],
      '/dashboard/candidate-review': ['recruitment.view'],
      '/dashboard/email-logs': ['recruitment.view'],
      '/dashboard/employees': ['employees.view'],
      '/dashboard/org-chart': ['org_chart.view'],
      '/dashboard/branches': ['settings.view'],
      '/dashboard/leave': ['leave.view'],
      '/dashboard/expenses': ['expenses.view'],
      '/dashboard/approvals': ['leave.approve', 'expenses.approve'],
      '/dashboard/documents': ['documents.view'],
      '/dashboard/settings': ['settings.view'],
    };
    final rawAdmin = user(['settings.edit']); // web proxy: raw list only
    for (final MapEntry(key: path, value: webPerms) in web.entries) {
      test('$path: settings.edit admin and superuser pass on mobile; employee refused on both', () {
        bool webAllows(UserEntity u) => webPerms.any(u.permissions.contains);
        expect(webAllows(rawAdmin), isFalse); // web: blocked
        for (final u in [superuserOnly, settingsAdmin, olderAdmin, rawAdmin]) {
          expect(canAccessPath(u, path), isTrue, reason: '$path ${u.permissions}');
        }
        expect(canAccessPath(employee, path), path == '/dashboard/leave', reason: 'employee'); // leave.view self-service
        expect(webAllows(employee), path == '/dashboard/leave');
      });
    }

    test('module off: refused even for superusers and settings.edit admins', () {
      for (final (path, module) in [
        ('/dashboard/interview-list', 'recruitment'),
        ('/dashboard/candidate-review', 'recruitment'),
        ('/dashboard/expenses', 'expenses'),
        ('/dashboard/documents', 'documents'),
        ('/dashboard/leave', 'leave'),
        ('/dashboard/attendance', 'attendance'),
        ('/dashboard/face-id-registrations', 'face_attendance'),
        ('/dashboard/assessments', 'assessments'),
      ]) {
        for (final base in [superuserOnly, olderAdmin]) {
          final off = user(base.permissions, superuser: base.isSuperuser, modules: const ['announcements']);
          final on = user(base.permissions, superuser: base.isSuperuser, modules: [module]);
          expect(canAccessPath(off, path), isFalse, reason: '$path off');
          expect(resolveAuthRedirect(authState: AuthState(user: off), path: path), AppRoutes.dashboard, reason: path);
          expect(navHasApprovals(off), isTrue); // core screen stays
          expect(canAccessPath(on, path), isTrue, reason: '$path on');
        }
      }
    });

    test('unavailable screens stay closed to everyone (Reports)', () {
      expect(canAccessPath(superuserOnly, '/dashboard/reports'), isFalse);
    });

    test('unrelated permissions get none of the admin routes', () {
      for (final p in ['/dashboard/employees', '/dashboard/interview-list', '/dashboard/settings', '/dashboard/attendance', AppRoutes.approvals]) {
        expect(canAccessPath(unrelated, p), isFalse, reason: p);
      }
      expect(canAccessPath(unrelated, '/dashboard/documents'), isTrue); // documents.view
      expect(canAccessPath(unrelated, '/dashboard/expenses'), isTrue); // expenses.view (own claims)
    });
  });
}
