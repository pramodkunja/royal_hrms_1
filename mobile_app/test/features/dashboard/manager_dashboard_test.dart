import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/data/models/manager_dashboard_models.dart';
import 'package:mobile_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/admin_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/employee_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/hr_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/manager_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';

// Phase 6 (C): the manager dashboard — GET /dashboard/manager/ (production
// ManagerDashboardView: every widget in one response, scoped to the
// manager's direct reports), chosen for team-managing roles exactly as web's
// resolveDashboard does.

Map<String, dynamic> payload() => {
      'team_overview': {
        'greeting': 'Good morning',
        'manager_name': 'Morgan Lee',
        'current_date': '2026-11-04',
        'team_size': 6,
        'pending_approvals': 3,
        'employees_on_leave_today': 1,
        'team_attendance_percentage': 66.7,
      },
      'quick_actions': [
        {'id': 'apply_leave', 'label': 'Apply Leave', 'url': '/dashboard/leave/apply', 'count': null},
        {'id': 'my_requests', 'label': 'My Requests', 'url': '/dashboard/requests', 'count': null},
        {'id': 'team_members', 'label': 'Team Members', 'url': '/dashboard/team', 'count': null},
        {'id': 'review_approvals', 'label': 'Review Approvals', 'url': '/dashboard/approvals', 'count': 3},
        {'id': 'my_payslip', 'label': 'My Payslip', 'url': '/dashboard/payroll/payslips', 'count': null},
        {'id': 'something_new', 'label': 'Future Thing', 'url': '/x', 'count': null},
      ],
      'pending_approvals': [
        {
          'id': 'l1',
          'approval_type': 'leave',
          'employee_name': 'Asha Rao',
          'employee_id': 'EMP-2',
          'summary': 'Casual Leave — 2 day(s)',
          'date_from': '2026-11-10',
          'date_to': '2026-11-11',
          'applied_on': '2026-11-03',
          'status': 'pending',
        },
      ],
      'todays_birthdays': [
        {
          'employee_id': 'EMP-3',
          'full_name': 'Ravi Kumar',
          'email': 'r@example.com',
          'department': 'Eng',
          'designation': '',
          'branch': '',
          'date_of_birth': '1990-11-04',
          'days_until': 0,
        },
      ],
      'upcoming_birthdays': [],
      'recent_team_activity': [
        {
          'employee_name': 'Asha Rao',
          'employee_id': 'EMP-2',
          'action': 'leave_apply',
          'module': 'leave',
          'description': 'Applied for leave',
          'created_at': '2026-11-04T08:00:00Z',
        },
      ],
      'team_attendance': [
        {
          'employee_id': 'EMP-2',
          'employee_name': 'Asha Rao',
          'designation': 'Engineer',
          'clock_in': '09:05',
          'clock_out': null,
          'status': 'present',
        },
        {
          'employee_id': 'EMP-4',
          'employee_name': 'Sam Iyer',
          'designation': 'Analyst',
          'clock_in': null,
          'clock_out': null,
          'status': 'absent',
        },
      ],
      'upcoming_leaves': [
        {
          'id': 'l1',
          'employee_id': 'EMP-2',
          'employee_name': 'Asha Rao',
          'leave_type': 'Casual',
          'date_from': '2026-11-10',
          'date_to': '2026-11-11',
          'total_days': 2.0,
          'status': 'pending',
        },
      ],
    };

class FakeDashboardBackend implements HttpClientAdapter {
  FakeDashboardBackend(this.manager);
  Map<String, dynamic> manager;
  final paths = <String>[];
  int managerStatus = 200;
  bool failAnnouncement = false;
  Completer<void>? holdManager;

  int count(String path) => paths.where((p) => p == path).length;

  ResponseBody _r(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    paths.add(o.path);
    if (o.path == '/dashboard/manager/') {
      if (holdManager != null) await holdManager!.future;
      if (managerStatus != 200) {
        return _r(managerStatus,
            {'status': 'error', 'message': 'You do not have permission to perform this action.', 'data': {}});
      }
      return _r(200, {'status': 'success', 'message': 'Manager dashboard retrieved.', 'data': manager});
    }
    if (o.path == '/dashboard/announcement/' && failAnnouncement) {
      return _r(500, {'status': 'error', 'message': 'Server error.', 'data': {}});
    }
    return _r(200, {'status': 'success', 'message': 'ok', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

class _NullSecureStorage extends SecureStorageService {
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

UserEntity user({
  bool manager = false,
  bool superuser = false,
  List<String> perms = const ['leave.view', 'payroll.view_own', 'leave.approve'],
  bool mustChangePassword = false,
  String onboarding = 'complete',
  String assessment = 'complete',
}) =>
    UserEntity(
        id: 'u1',
        email: 'm@example.com',
        fullName: 'Morgan Lee',
        role: 'manager',
        roleDisplay: 'Manager',
        mustChangePassword: mustChangePassword,
        permissions: perms,
        canManageTeam: manager,
        isSuperuser: superuser,
        onboardingStatus: onboarding,
        assessmentStatus: assessment);

late FakeDashboardBackend backend;
late ProviderContainer container;

Future<void> pumpHome(WidgetTester tester, UserEntity u, {void Function(FakeDashboardBackend)? setup, bool settle = true}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  backend = FakeDashboardBackend(payload());
  setup?.call(backend);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = backend),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullSecureStorage()),
    ],
    child: const MaterialApp(home: Scaffold(body: HomeScreen())),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
}

// Dashboards start periodic timers; unmount before the test ends.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder inCard(Key key, Finder f) => find.descendant(of: find.byKey(key), matching: f);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('which dashboard', () {
    testWidgets('a team-managing role gets the manager dashboard from /dashboard/manager/', (tester) async {
      await pumpHome(tester, user(manager: true));
      expect(find.byType(ManagerDashboardView), findsOneWidget);
      expect(backend.count('/dashboard/manager/'), 1);
      expect(backend.paths.where((p) => p.startsWith('/dashboard/hr/') || p.contains('system-admin')), isEmpty);
      await unmount(tester);
    });

    testWidgets('other roles keep their dashboards and never call the manager endpoint', (tester) async {
      for (final (u, view) in [
        (user(), EmployeeDashboardView),
        (user(perms: ['employees.view']), HrDashboardView),
        (user(superuser: true, manager: true), AdminDashboardView), // superuser wins, as on web
      ]) {
        await pumpHome(tester, u);
        expect(find.byType(view), findsOneWidget, reason: '$view');
        expect(find.byType(ManagerDashboardView), findsNothing);
        expect(backend.count('/dashboard/manager/'), 0);
        await unmount(tester);
      }
    });

    test('gate precedence is unchanged for managers', () {
      String? go(UserEntity u) => resolveAuthRedirect(authState: AuthState(user: u), path: AppRoutes.dashboard);
      expect(go(user(manager: true, mustChangePassword: true)), AppRoutes.changePassword);
      expect(go(user(manager: true, onboarding: 'pending')), AppRoutes.onboarding);
      // Managers are exempt from the assessment gate (web proxy.ts), as before.
      expect(go(user(manager: true, assessment: 'pending')), isNull);
      expect(go(user(assessment: 'pending')), AppRoutes.onboardingAssessments);
    });
  });

  group('content', () {
    test('parses every widget of the response', () {
      final d = ManagerDashboardData.fromJson(payload());
      expect(d.overview.teamSize, 6);
      expect(d.overview.teamAttendancePercentage, 66.7);
      expect(d.quickActions.firstWhere((a) => a.id == 'review_approvals').count, 3);
      expect(d.pendingApprovals.single.approvalType, 'leave');
      expect(d.todaysBirthdays.single.fullName, 'Ravi Kumar');
      expect(d.recentActivity.single.description, 'Applied for leave');
      expect(d.teamAttendance.map((a) => a.status), ['present', 'absent']);
      expect(d.upcomingLeaves.single.totalDays, 2);
      final empty = ManagerDashboardData.fromJson(const {});
      expect(empty.overview.teamSize, 0);
      expect(empty.pendingApprovals, isEmpty);
      expect(empty.teamAttendance, isEmpty);
    });

    testWidgets('summary, approvals, attendance, leaves, activity and birthdays from the server', (tester) async {
      await pumpHome(tester, user(manager: true));
      final stats = find.byKey(const Key('manager-stats'));
      expect(find.descendant(of: stats, matching: find.text('6')), findsOneWidget);
      expect(find.descendant(of: stats, matching: find.text('3')), findsOneWidget);
      expect(find.descendant(of: stats, matching: find.text('66.7%')), findsOneWidget);
      expect(find.text('Morgan'), findsOneWidget);
      expect(inCard(const Key('manager-pending'), find.textContaining('Casual Leave — 2 day(s)')), findsOneWidget);
      expect(inCard(const Key('manager-team-attendance'), find.text('Present')), findsOneWidget);
      expect(inCard(const Key('manager-team-attendance'), find.text('Absent')), findsOneWidget);
      expect(inCard(const Key('manager-upcoming-leaves'), find.textContaining('Casual')), findsOneWidget);
      expect(find.textContaining('Applied for leave'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('empty team: each section says so; no birthday section', (tester) async {
      await pumpHome(tester, user(manager: true),
          setup: (b) => b.manager = {
                ...payload(),
                'pending_approvals': [],
                'todays_birthdays': [],
                'recent_team_activity': [],
                'team_attendance': [],
                'upcoming_leaves': [],
              });
      expect(find.text('No pending approvals.'), findsOneWidget);
      expect(find.text('No recent activity.'), findsOneWidget);
      expect(find.text('No attendance data.'), findsOneWidget);
      expect(find.text('No upcoming leaves.'), findsOneWidget);
      expect(find.text('Birthdays'), findsNothing);
      await unmount(tester);
    });

    test('quick actions: server ids mapped to app screens, unknown ones left out', () {
      final items = managerQuickItems(ManagerDashboardData.fromJson(payload()).quickActions);
      expect(items.map((i) => i.path), [
        AppRoutes.leave,
        AppRoutes.myRequests,
        AppRoutes.employees,
        AppRoutes.approvals,
        AppRoutes.myPayslips,
      ]);
      expect(items.firstWhere((i) => i.path == AppRoutes.approvals).label, 'Review Approvals (3)');
      // Team Members needs employees.view, as the router does.
      final visible = visibleQuickItems(items, user(manager: true));
      expect(visible.map((i) => i.path), isNot(contains(AppRoutes.employees)));
      expect(visible.map((i) => i.path), contains(AppRoutes.approvals));
    });

    testWidgets('Review on a pending approval only for those who can open Approvals', (tester) async {
      await pumpHome(tester, user(manager: true, perms: const ['leave.view']));
      expect(inCard(const Key('manager-pending'), find.text('Review')), findsNothing);
      await unmount(tester);
      await pumpHome(tester, user(manager: true));
      expect(inCard(const Key('manager-pending'), find.text('Review')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('states', () {
    testWidgets('while loading, figures show "—", never 0', (tester) async {
      await pumpHome(tester, user(manager: true), setup: (b) => b.holdManager = Completer<void>());
      final stats = find.byKey(const Key('manager-stats'));
      expect(find.descendant(of: stats, matching: find.text('—')), findsNWidgets(4));
      expect(find.descendant(of: stats, matching: find.text('0')), findsNothing);
      backend.holdManager!.complete();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.descendant(of: stats, matching: find.text('6')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a refusal is shown as such, figures stay unknown, Retry reloads', (tester) async {
      await pumpHome(tester, user(manager: true), setup: (b) => b.managerStatus = 403);
      expect(find.byKey(const Key('manager-dashboard-error')), findsOneWidget);
      expect(find.text('Access denied'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('manager-stats')), matching: find.text('—')), findsNWidgets(4));
      backend.managerStatus = 200;
      container.invalidate(managerDashboardProvider); // Retry is hidden for a refusal; a refresh reloads
      await settle(tester);
      expect(find.byKey(const Key('manager-pending')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a server error offers Retry', (tester) async {
      await pumpHome(tester, user(manager: true), setup: (b) => b.managerStatus = 500);
      expect(find.text('Retry'), findsOneWidget);
      backend.managerStatus = 200;
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.byKey(const Key('manager-pending')), findsOneWidget);
      expect(backend.count('/dashboard/manager/'), 2);
      await unmount(tester);
    });

    testWidgets('the announcement failing does not take the team sections down', (tester) async {
      await pumpHome(tester, user(manager: true), setup: (b) => b.failAnnouncement = true);
      expect(find.text('Latest Announcement'), findsOneWidget);
      expect(find.byKey(const Key('manager-pending')), findsOneWidget);
      expect(find.byKey(const Key('manager-team-attendance')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('refreshing asks the server again', (tester) async {
      await pumpHome(tester, user(manager: true));
      // The dashboard's refresh — the same one pull-to-refresh runs — as
      // triggered when the dashboard is shown again.
      container.read(dashboardRevisitProvider.notifier).state++;
      await settle(tester);
      expect(backend.count('/dashboard/manager/'), 2);
      await unmount(tester);
    });
  });
}
