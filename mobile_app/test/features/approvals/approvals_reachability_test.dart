import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/attendance_approval_tab.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/delegations_tab.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/face_registration_approvals_tab.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/team_approvals_tab.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/navigation/nav_config.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';
import 'package:mobile_app/features/leave/presentation/widgets/leave_cancellation_panel.dart';

// Task 77: Approvals reachability and tab permissions.
// Web approvals/page.tsx tabs (usePermission = superuser flag or codename):
//   Team Approvals      leave / expenses .approve, attendance.create, separation.approve
//   Attendance Approval attendance module && (can_manage_team || superuser || payroll.view)
//   Face Registration   facial_recognition.approve && face_attendance module
//   Leave Cancellations leave.approve
//   Delegation          leave.approve, or attendance.create held by attendance staff
// Backend:
//   Attendance Approval endpoints (payroll/views/attendance_approval.py
//   _can_view_approvals): team manager (or superuser) or has_perm
//   payroll.edit — NOT payroll.view; and /api/payroll/ is blocked when the
//   payroll module is off (tenants feature_gate).
//   Leave cancellations (LeaveCancellationListView): has_perm leave.approve
//   (settings.edit passes).
// Mobile corrections (mobile-only defects): Attendance Approval follows the
// backend (manager or payroll.edit, attendance + payroll modules); Leave
// Cancellations accepts settings.edit sessions without the flag.
// Route: web proxy.ts / navConfig ['leave.approve','expenses.approve'];
// mobile adds wfh/separation approvers and delegators (Tasks 71a/71g).
// Users whose only tab is Face ID or Attendance Approval can't open
// Approvals on either platform — reported, not changed here.
// Synthetic users; a stand-in server records every request.

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _page(List<Object> rows) => _json({
      'status': 'success',
      'message': 'ok',
      'data': {'count': rows.length, 'page': 1, 'page_size': 100, 'total_pages': 1, 'results': rows},
    });

class Server implements HttpClientAdapter {
  final gets = <String>[];
  int writes = 0;
  bool refusePayroll = false;

  bool asked(String path) => gets.contains(path);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') {
      writes++;
      return _json({'status': 'success', 'message': 'ok', 'data': {}});
    }
    gets.add(o.path);
    if (o.path == '/payroll/cycles/pending-approval/' && refusePayroll) {
      return _json({'status': 'error', 'message': 'Only managers and HR can view attendance approvals.', 'data': {}}, 403);
    }
    if (o.path == '/payroll/cycles/pending-approval/' || o.path == '/leave/cancellations/') {
      return _json({'status': 'success', 'message': 'ok', 'data': <Object>[]});
    }
    if (o.path == '/approvals/delegations/') return _json({'status': 'success', 'message': 'ok', 'data': <Object>[]});
    return _page(const []);
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

UserEntity user(List<String> perms, {bool superuser = false, bool team = false, List<String>? modules}) => UserEntity(
      id: 'u1',
      email: 'u@example.test',
      fullName: 'Test User',
      role: 'r',
      roleDisplay: 'Role',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      canManageTeam: team,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

const team = 'Team Approvals';
const att = 'Attendance Approval';
const face = 'Face ID Approvals';
const canc = 'Leave Cancellations';
const del = 'Delegation';

late Server server;

Future<void> pump(WidgetTester tester, UserEntity u,
    {Size size = const Size(1080, 3000), double textScale = 1, void Function(Server)? setup}) async {
  tester.view.physicalSize = size;
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
      approvalsTodayProvider.overrideWithValue(() => DateTime(2026, 11, 16, 10)),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Consumer(
        builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
            ? const SizedBox()
            : const Scaffold(body: ApprovalsScreen()),
      ),
    ),
  ));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// The sections the screen offers: the tab labels, or — with a single
/// section, where the screen shows no tab bar — that section's widget.
List<String> sections(WidgetTester tester) {
  if (find.byType(TabBar).evaluate().isNotEmpty) {
    return [for (final t in tester.widgetList<Tab>(find.byType(Tab))) t.text ?? ''];
  }
  return [
    if (find.byType(TeamApprovalsTab).evaluate().isNotEmpty) team,
    if (find.byType(AttendanceApprovalTab).evaluate().isNotEmpty) att,
    if (find.byType(FaceRegistrationApprovalsTab).evaluate().isNotEmpty) face,
    if (find.byType(LeaveCancellationsTab).evaluate().isNotEmpty) canc,
    if (find.byType(DelegationsTab).evaluate().isNotEmpty) del,
  ];
}

bool route(UserEntity u) => canAccessPath(u, AppRoutes.approvals);
bool drawer(UserEntity u) => buildNav(u).any((e) => e is NavItem && e.path == AppRoutes.approvals);
bool tile(UserEntity u) => visibleQuickItems(kQuickItemsManager, u).any((i) => i.path == AppRoutes.approvals);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // (label, user, mobile route/drawer/tile, tabs on the screen)
  final matrix = <(String, UserEntity, bool, List<String>)>[
    ('ordinary employee', user(['leave.view', 'leave.create', 'attendance.view']), false, []),
    ('leave approver', user(['leave.view', 'leave.approve']), true, [team, canc, del]),
    ('expense approver', user(['expenses.view', 'expenses.approve']), true, [team]),
    ('WFH approver', user(['wfh.approve']), true, [team]),
    ('separation approver', user(['separation.approve']), true, [team]),
    ('Face ID approver only', user(['facial_recognition.approve']), false, [face]),
    ('payroll.view only (backend refuses the cycle endpoints)', user(['payroll.view']), false, []),
    ('payroll.edit only', user(['payroll.view', 'payroll.edit']), false, [att]),
    ('team manager with leave.approve', user(['leave.view', 'leave.approve'], team: true), true, [team, att, canc, del]),
    ('team manager without approve codes', user(['leave.view'], team: true), false, [att]),
    ('HR (leave.approve, attendance staff, payroll.view)',
        user(['leave.approve', 'attendance.create', 'attendance.edit', 'payroll.view', 'employees.view']), true, [team, canc, del]),
    ('superuser', user(const [], superuser: true), true, [team, att, face, canc, del]),
    ('settings.edit admin', user(['settings.view', 'settings.edit'], superuser: true), true, [team, att, face, canc, del]),
    ('legacy admin session (no flag)', user(['settings.view', 'settings.edit']), true, [team, att, face, canc, del]),
    ('unrelated permissions', user(['documents.view', 'expenses.view']), false, []),
  ];

  group('matrix: route, drawer, dashboard tile and tabs', () {
    for (final (label, u, reachable, tabs) in matrix) {
      testWidgets('$label → route ${reachable ? '✓' : '✗'}, tabs $tabs', (tester) async {
        expect(route(u), reachable, reason: 'route');
        expect(resolveAuthRedirect(authState: AuthState(user: u), path: AppRoutes.approvals),
            reachable ? isNull : AppRoutes.dashboard,
            reason: 'direct navigation');
        expect(drawer(u), reachable, reason: 'drawer');
        expect(tile(u), reachable, reason: 'dashboard tile');
        await pump(tester, u);
        expect(sections(tester), tabs);
        if (tabs.isEmpty) expect(find.text('You have no approval permissions.'), findsOneWidget);
        // Queues only for shown tabs.
        if (!tabs.contains(att)) expect(server.asked('/payroll/cycles/pending-approval/'), isFalse, reason: 'attendance');
        if (!tabs.contains(face)) expect(server.asked('/attendance/face-registration/pending/'), isFalse, reason: 'face');
        if (!tabs.contains(canc)) expect(server.asked('/leave/cancellations/'), isFalse, reason: 'cancellations');
        if (!tabs.contains(del)) expect(server.gets.where((g) => g.startsWith('/approvals/delegations')), isEmpty);
        expect(server.writes, 0);
      });
    }
  });

  group('Attendance Approval (backend: manager or payroll.edit; attendance + payroll modules)', () {
    testWidgets('authorised: the tab fetches pending cycles; empty queue shown', (tester) async {
      await pump(tester, user(['payroll.edit']));
      expect(server.asked('/payroll/cycles/pending-approval/'), isTrue);
      expect(server.writes, 0);
    });

    testWidgets('server refusal (403) is shown in the tab', (tester) async {
      await pump(tester, user(['payroll.edit']), setup: (s) => s.refusePayroll = true);
      expect(find.text('Only managers and HR can view attendance approvals.'), findsOneWidget);
      expect(server.writes, 0);
    });

    for (final (label, modules) in [
      ('payroll module off', const ['attendance', 'leave', 'face_attendance']),
      ('attendance module off', const ['payroll', 'leave', 'face_attendance']),
    ]) {
      testWidgets('$label: no Attendance Approval tab, nothing fetched (superuser)', (tester) async {
        await pump(tester, user(const [], superuser: true, modules: modules));
        expect(sections(tester), isNot(contains(att)));
        expect(server.asked('/payroll/cycles/pending-approval/'), isFalse);
      });
    }

    test('rule', () {
      // The tab rule is computed inside the screen; these are its inputs.
      expect(userHasPermission(user(['payroll.view']), 'payroll.edit'), isFalse);
      expect(userHasPermission(user(['settings.edit']), 'payroll.edit'), isTrue);
    });
  });

  group('Leave Cancellations (backend: has_perm leave.approve)', () {
    test('settings.edit sessions without the flag now included; module still required', () {
      expect(canReviewLeaveCancellations(user(['settings.edit'])), isTrue);
      expect(canReviewLeaveCancellations(user(['settings.edit'], modules: const ['attendance'])), isFalse);
      expect(canReviewLeaveCancellations(user(['leave.view'])), isFalse);
      expect(canReviewLeaveCancellations(null), isFalse);
    });

    testWidgets('legacy admin: tab shown and the queue fetched when opened', (tester) async {
      await pump(tester, user(['settings.view', 'settings.edit']));
      await tester.tap(find.widgetWithText(Tab, canc));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(server.asked('/leave/cancellations/'), isTrue);
    });
  });

  group('modules for the other tabs', () {
    testWidgets('face_attendance off: no Face ID tab, no request', (tester) async {
      await pump(tester, user(const [], superuser: true, modules: const ['leave', 'attendance', 'payroll']));
      expect(sections(tester), isNot(contains(face)));
      expect(server.asked('/attendance/face-registration/pending/'), isFalse);
    });

    testWidgets('leave off: no Leave Cancellations, no request', (tester) async {
      await pump(tester, user(const [], superuser: true, modules: const ['attendance', 'payroll', 'face_attendance']));
      expect(sections(tester), isNot(contains(canc)));
      expect(server.asked('/leave/cancellations/'), isFalse);
    });
  });

  group('layout', () {
    for (final (label, scale) in [('×1.0', 1.0), ('×1.5', 1.5), ('×2.0', 2.0)]) {
      testWidgets('360 dp, text $label: all five tabs reachable; no overflow from this task\'s parts', (tester) async {
        // Collect every layout error. The only known one is the shared
        // StatCard in the Team Approvals summary (lib/shared/widgets/
        // stat_card.dart), which is too short at large text sizes on every
        // screen that uses it — reported, outside this task.
        final errors = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.toString());
        try {
          await pump(tester, user(const [], superuser: true), size: const Size(360, 780), textScale: scale);
          expect(sections(tester), [team, att, face, canc, del]);
          for (final t in [att, face, canc, del]) {
            await tester.tap(find.widgetWithText(Tab, t));
            for (var i = 0; i < 8; i++) {
              await tester.pump(const Duration(milliseconds: 60));
            }
          }
        } finally {
          FlutterError.onError = previous;
        }
        expect(errors.where((e) => !e.contains('stat_card.dart')), isEmpty, reason: errors.join('\n---\n'));
      });
    }
  });
}
