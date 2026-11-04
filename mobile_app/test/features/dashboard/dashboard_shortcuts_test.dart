import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/admin_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/employee_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/hr_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/attendance_ring_card.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/dashboard_section.dart';

import '../../core/router/access_control_test.dart' as roles;

// D1 (docs/qa/CROSS_FEATURE_REGRESSION_AUDIT.md): dashboard shortcuts outside
// Quick Access are filtered by the same route permissions as the menu
// (access_control.dart). Permission keys and paths are the ones in
// kRoutePermissions: leave.view → /dashboard/leave, expenses.view →
// /dashboard/expenses, documents.view → /dashboard/documents,
// recruitment.view → /dashboard/candidate-review, leave/expenses/wfh.approve
// → /dashboard/approvals, employees.view → /dashboard/employees.

UserEntity _user(List<String> permissions, {String role = 'custom_role'}) => UserEntity(
      id: 'u-$role',
      email: '$role@example.com',
      fullName: 'Custom User',
      role: role,
      roleDisplay: role,
      mustChangePassword: false,
      permissions: permissions,
      onboardingStatus: 'complete',
    );

// The seeded employee role minus one permission at a time.
UserEntity _employeeWithout(String permission) =>
    _user(roles.employee.permissions.where((p) => p != permission).toList());

class _Backend implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    final Object data = switch (o.path) {
      '/dashboard/employee/action-items/' => {
          'total': 2,
          'action_items': [
            {'action_type': 'missing_document', 'title': 'Upload your PAN card', 'status': 'pending'},
            {'action_type': 'leave_rejected', 'title': 'Leave request rejected', 'status': 'rejected'},
          ],
        },
      '/dashboard/employee/recent-requests/' => {'total': 0, 'requests': []},
      '/dashboard/hr/action-queue/' => {
          'total_pending': 15, 'candidate_reviews': 1, 'leave_approvals': 2, 'attendance_corrections': 3,
          'expense_claims': 4, 'onboarding_reviews': 5, 'separation_requests': 6,
        },
      _ => {},
    };
    return ResponseBody.fromString(jsonEncode({'status': 'success', 'message': 'ok', 'data': data}), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

class _FixedAuthNotifier extends AuthNotifier {
  _FixedAuthNotifier(this._user);
  final UserEntity _user;
  @override
  Future<AuthState> build() async => AuthState(user: _user);
}

class _NullSecureStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

Future<void> _pumpHome(WidgetTester tester, UserEntity user) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = _Backend();
  Widget page(String name) => Scaffold(body: Text('PAGE $name'));
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: HomeScreen())),
    for (final p in ['leave', 'expenses', 'documents', 'my-attendance', 'candidate-review', 'approvals',
      'employees', 'separation', 'profile', 'announcements'])
      GoRoute(path: '/dashboard/$p', builder: (_, __) => page(p)),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _FixedAuthNotifier(user)),
      dioProvider.overrideWithValue(dio),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullSecureStorage()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

// Dashboards start periodic timers; unmount before the test ends.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Finder _inCard(String title, Finder f) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(SectionCard)).first, matching: f);
Finder _ringApplyLeave() => find.descendant(of: find.byType(AttendanceRingCard), matching: find.text('Apply Leave'));
Finder _quickLink(String label) => _inCard('Quick Links', find.text(label));
Finder _queueRows() => _inCard('Action Queue', find.byType(ActionRow));
String _queueTotal(WidgetTester tester) =>
    (tester.widget<Text>(_inCard('Action Queue', find.textContaining(RegExp(r'^\d+$'))).first)).data!;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('employee dashboard', () {
    testWidgets('without leave.view: no Leave shortcut anywhere; the leave action item stays but is inert', (tester) async {
      await _pumpHome(tester, _employeeWithout('leave.view'));
      expect(find.byType(EmployeeDashboardView), findsOneWidget);
      expect(_quickLink('Leave History'), findsNothing);
      expect(_quickLink('My Attendance'), findsOneWidget);
      expect(_ringApplyLeave(), findsNothing);
      // The empty-state message stays; only its "Apply leave" link goes.
      expect(find.text('No requests yet. ', findRichText: true), findsOneWidget);
      expect(find.textContaining('Apply leave', findRichText: true), findsNothing);
      expect(find.text('Leave request rejected'), findsOneWidget);
      await tester.tap(find.text('Leave request rejected'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE leave'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('without expenses.view: no Claim Expense link', (tester) async {
      await _pumpHome(tester, _employeeWithout('expenses.view'));
      expect(_quickLink('Claim Expense'), findsNothing);
      expect(_quickLink('Leave History'), findsOneWidget);
      expect(_quickLink('My Documents'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('without documents.view: no My Documents link; the document action item is inert', (tester) async {
      await _pumpHome(tester, _employeeWithout('documents.view'));
      expect(_quickLink('My Documents'), findsNothing);
      await tester.tap(find.text('Upload your PAN card'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE documents'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('with the permissions: every shortcut is shown and works', (tester) async {
      await _pumpHome(tester, roles.employee);
      for (final l in ['Leave History', 'My Attendance', 'Claim Expense', 'My Documents']) {
        expect(_quickLink(l), findsOneWidget, reason: l);
      }
      expect(_ringApplyLeave(), findsOneWidget);
      expect(find.textContaining('Apply leave', findRichText: true), findsOneWidget);
      await tester.tap(find.text('Upload your PAN card'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE documents'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('the Quick Links card is never left empty (My Attendance is open to everyone)', (tester) async {
      await _pumpHome(tester, _user(const []));
      expect(find.text('Quick Links'), findsOneWidget);
      expect(_quickLink('My Attendance'), findsOneWidget);
      expect(_inCard('Quick Links', find.byType(GestureDetector)), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a permitted Quick Link opens its screen', (tester) async {
      await _pumpHome(tester, roles.employee);
      await tester.tap(_quickLink('Claim Expense'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE expenses'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('HR dashboard Action Queue', () {
    testWidgets('custom HR role without recruitment.view or approve permissions: those rows are hidden and the total matches', (tester) async {
      await _pumpHome(tester, _user(const ['employees.view', 'leave.view', 'expenses.view']));
      expect(find.byType(HrDashboardView), findsOneWidget);
      final titles = tester.widgetList<ActionRow>(_queueRows()).map((r) => r.title).toList();
      expect(titles, ['Leave Approvals', 'Expense Claims', 'Onboarding Reviews', 'Separation Requests']);
      // Leave 2 + Expenses 4 + Onboarding 5 (separation is not part of the server's total).
      expect(_queueTotal(tester), '11');
      await _unmount(tester);
    });

    testWidgets('without the approve permissions only Attendance Corrections (→ Approvals) is hidden', (tester) async {
      await _pumpHome(tester,
          _user(roles.hr.permissions.where((p) => !p.endsWith('.approve')).toList(), role: 'hr_custom'));
      final titles = tester.widgetList<ActionRow>(_queueRows()).map((r) => r.title);
      expect(titles, isNot(contains('Attendance Corrections')));
      expect(titles, contains('Candidate Reviews'));
      expect(_queueTotal(tester), '12');
      await _unmount(tester);
    });

    testWidgets('a visible row still opens its screen', (tester) async {
      await _pumpHome(tester, roles.hr);
      await tester.tap(_inCard('Action Queue', find.text('Candidate Reviews')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE candidate-review'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('the five standard roles keep their dashboards', () {
    testWidgets('Employee: all four Quick Links, Apply Leave', (tester) async {
      await _pumpHome(tester, roles.employee);
      expect(find.byType(EmployeeDashboardView), findsOneWidget);
      expect(_inCard('Quick Links', find.byType(GestureDetector)), findsNWidgets(4));
      expect(_ringApplyLeave(), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('Manager: generic dashboard with Apply Leave', (tester) async {
      await _pumpHome(tester, roles.manager);
      expect(find.byType(EmployeeDashboardView), findsNothing);
      expect(find.byType(HrDashboardView), findsNothing);
      expect(_ringApplyLeave(), findsOneWidget);
      await _unmount(tester);
    });

    for (final (name, user) in [('HR Admin', roles.hr), ('Branch Admin', roles.branchAdmin)]) {
      testWidgets('$name: all six queue rows and the server total', (tester) async {
        await _pumpHome(tester, user);
        expect(find.byType(HrDashboardView), findsOneWidget);
        expect(_queueRows(), findsNWidgets(6));
        expect(_queueTotal(tester), '15');
        expect(_ringApplyLeave(), findsOneWidget);
        await _unmount(tester);
      });
    }

    testWidgets('System Admin: admin dashboard, Apply Leave available', (tester) async {
      await _pumpHome(tester, roles.systemAdmin);
      expect(find.byType(AdminDashboardView), findsOneWidget);
      expect(_ringApplyLeave(), findsOneWidget);
      await _unmount(tester);
    });
  });
}
