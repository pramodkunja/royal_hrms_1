import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/navigation/nav_config.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';

// ─── Role fixtures: the backend's default roles as production defines them ──
// Companies can edit roles; these are the seeded defaults the permissions
// below are derived from (backend/apps/accounts/migrations):
//  - 0002 seeds the original roles and their codenames;
//  - 0029 + 0042 remove attendance.view/create and payroll.view from employee;
//  - 0045 + 0092 remove payroll.view and recruitment.* from the manager roles;
//  - 0043/0057 grant payroll.view_own and 0086 grants org_chart.view to every
//    role; 0088 mirrors wfh.view/create/approve from leave.view/create/approve;
//  - 0052 seeds branch_admin (0070 revokes its settings.edit);
//  - 0077 revokes settings.edit from hr; 0094 grants facial_recognition.approve
//    to hr_admin and branch_admin.

const _allRoles = ['payroll.view_own', 'org_chart.view'];

UserEntity _user(String role, List<String> permissions,
        {bool isSuperuser = false, bool canManageTeam = false, bool canManageBranch = false}) =>
    UserEntity(
      id: 'u-$role',
      email: '$role@example.com',
      fullName: role,
      role: role,
      roleDisplay: role,
      mustChangePassword: false,
      permissions: permissions,
      onboardingStatus: 'complete',
      isSuperuser: isSuperuser,
      canManageTeam: canManageTeam,
      canManageBranch: canManageBranch,
    );

final employee = _user('employee', [
  'leave.view', 'leave.create', 'expenses.view', 'expenses.create',
  'referrals.view', 'referrals.create', 'documents.view', 'wfh.view', 'wfh.create', ..._allRoles,
]);

final manager = _user('manager__team_lead', [
  'employees.view', 'attendance.view', 'attendance.create', 'attendance.edit', 'attendance.export',
  'leave.view', 'leave.create', 'leave.edit', 'leave.delete', 'leave.approve',
  'expenses.view', 'expenses.create', 'expenses.edit', 'expenses.delete', 'expenses.approve',
  'referrals.view', 'referrals.create', 'announcements.view', 'documents.view',
  'wfh.view', 'wfh.create', 'wfh.approve', ..._allRoles,
], canManageTeam: true);

final hr = _user('hr_admin', [
  'employees.view', 'employees.create', 'employees.edit', 'employees.delete', 'employees.export', 'employees.approve',
  'recruitment.view', 'recruitment.create', 'recruitment.edit', 'recruitment.delete', 'recruitment.approve',
  'attendance.view', 'attendance.create', 'attendance.edit', 'attendance.delete', 'attendance.export',
  'leave.view', 'leave.create', 'leave.edit', 'leave.delete', 'leave.approve',
  'payroll.view', 'payroll.create', 'payroll.edit', 'payroll.delete', 'payroll.export',
  'expenses.view', 'expenses.create', 'expenses.edit', 'expenses.delete', 'expenses.approve',
  'referrals.view', 'referrals.create',
  'announcements.view', 'announcements.create', 'announcements.edit', 'announcements.delete',
  'documents.view', 'documents.create', 'documents.edit', 'documents.delete',
  'settings.view', 'reports.view', 'reports.export', 'audit.view',
  'wfh.view', 'wfh.create', 'wfh.approve', 'facial_recognition.approve', ..._allRoles,
]);

final branchAdmin = _user('branch_admin', [
  'employees.view', 'employees.create', 'employees.edit', 'employees.delete', 'employees.approve', 'employees.export',
  'leave.view', 'leave.create', 'leave.edit', 'leave.delete', 'leave.approve',
  'expenses.view', 'expenses.create', 'expenses.edit', 'expenses.delete', 'expenses.approve',
  'attendance.view', 'attendance.create', 'attendance.edit', 'attendance.delete', 'attendance.export',
  'recruitment.view', 'recruitment.create', 'recruitment.edit', 'recruitment.delete', 'recruitment.approve',
  'documents.view', 'documents.create', 'documents.edit', 'documents.delete', 'onboarding.approve',
  'referrals.view', 'referrals.create',
  'announcements.view', 'announcements.create', 'announcements.edit', 'announcements.delete',
  'assessments.view', 'assessments.create', 'assessments.edit', 'assessments.delete',
  'reports.view', 'reports.export', 'audit.view', 'payroll.view', 'payroll.export',
  'branches.view', 'settings.view', 'wfh.view', 'wfh.create', 'wfh.approve',
  'facial_recognition.approve', ..._allRoles,
], canManageBranch: true);

// system_admin holds settings.edit, so login sets is_superuser — the backend
// then passes every permission check.
final systemAdmin = _user('system_admin', ['settings.edit', 'settings.view', 'employees.view'], isSuperuser: true);

final noPermissions = _user('custom_role', const []);

Set<String> _navIds(UserEntity? user) => buildNav(user).whereType<NavItem>().map((e) => e.id).toSet();

const _alwaysVisible = {
  'dashboard', 'announcements', 'separation', 'my-attendance', 'my-payslip', 'my-assessments', 'referrals',
  'my-requests', 'contacts', 'profile',
};
final _allNavIds = kAllNav.whereType<NavItem>().map((e) => e.id).toSet();
// Reports is defined in kAllNav but not built for mobile yet (placeholder
// only), so no role sees it — named explicitly rather than derived from
// kUnavailablePaths so this test fails if it is ever re-exposed by accident.
final _availableNavIds = _allNavIds.difference({'reports'});

void main() {
  group('menu (buildNav) by role', () {
    test('employee: self-service plus leave, WFH, expenses, documents, org chart', () {
      expect(_navIds(employee), {
        ..._alwaysVisible, 'org-chart', 'leave', 'wfh', 'expenses', 'documents',
      });
    });

    test('manager: team tools, no recruitment / settings', () {
      expect(_navIds(manager), {
        ..._alwaysVisible, 'employees', 'org-chart', 'attendance', 'leave', 'wfh', 'expenses', 'approvals',
        'documents',
      });
    });

    test('HR: recruitment, approvals (no role-name exclusion any more), settings; no branches/assessments', () {
      expect(_navIds(hr), _availableNavIds.difference({'branches', 'assessments'}));
    });

    test('Branch Admin: every item its default role grants', () {
      expect(_navIds(branchAdmin), _availableNavIds);
    });

    test('System Admin: everything (settings.edit passes every check, as on the backend)', () {
      expect(_navIds(systemAdmin), _availableNavIds);
    });

    test('no permissions, or no user at all: only the always-visible items', () {
      expect(_navIds(noPermissions), _alwaysVisible);
      expect(_navIds(null), _alwaysVisible);
    });

    test('the role name never decides visibility', () {
      // Named "employee" but holding team permissions → sees Attendance.
      expect(_navIds(_user('employee', ['attendance.create', 'attendance.view'])), contains('attendance'));
      // Named "hr" with an approval permission → sees Approvals.
      expect(_navIds(_user('hr', ['leave.approve'])), contains('approvals'));
      // Named like an admin, no permissions → nothing extra.
      expect(_navIds(_user('system_admin', const [])), _alwaysVisible);
    });

    test('a cached user without is_superuser but holding settings.edit still sees everything', () {
      expect(_navIds(_user('system_admin', ['settings.edit'])), _availableNavIds);
    });
  });

  group('Reports placeholder (not built for mobile)', () {
    final roles = {
      'employee': employee, 'manager': manager, 'hr': hr, 'branch admin': branchAdmin,
      'system admin': systemAdmin, 'reports.view only': _user('analyst', ['reports.view']),
    };

    test('the Reports menu item is hidden for every role, even with reports.view', () {
      for (final MapEntry(:key, :value) in roles.entries) {
        final labels = buildNav(value).whereType<NavItem>().map((e) => e.label);
        expect(labels, isNot(contains('Reports')), reason: key);
      }
    });

    test('the System section keeps Audit Log and Settings, and disappears when Reports was its only item', () {
      List<String> system(UserEntity u) {
        final nav = buildNav(u);
        final i = nav.indexWhere((e) => e is NavSection && e.title == 'System');
        return i < 0 ? const [] : nav.skip(i + 1).takeWhile((e) => e is NavItem).map((e) => (e as NavItem).id).toList();
      }
      expect(system(hr), ['audit', 'settings']);
      expect(system(branchAdmin), ['audit', 'settings']);
      expect(system(systemAdmin), ['audit', 'settings']);
      expect(buildNav(_user('analyst', ['reports.view'])).whereType<NavSection>().map((e) => e.title),
          isNot(contains('System')));
    });

    test('direct navigation to the placeholder (and below it) returns to the dashboard for everyone', () {
      for (final MapEntry(:key, :value) in roles.entries) {
        for (final path in ['/dashboard/reports', '/dashboard/reports/attendance']) {
          expect(resolveAuthRedirect(authState: AuthState(user: value), path: path), AppRoutes.dashboard,
              reason: '$key → $path');
        }
      }
    });

    test('the route, nav entry and permission are kept for when the module ships', () {
      expect(kAllNav.whereType<NavItem>().where((e) => e.id == 'reports'), hasLength(1));
      expect(requiredPermissionsFor(AppRoutes.reports), ['reports.view']);
      expect(isUnavailablePath('/dashboard/reports-archive'), isFalse);
    });

    test('no quick-access tile points at Reports', () {
      for (final items in kQuickItemsByRole.values) {
        expect(items.where((i) => i.path.startsWith(AppRoutes.reports)), isEmpty);
      }
    });
  });

  group('quick-access tiles by role', () {
    List<String> labels(List<QuickItem> items, UserEntity? user) =>
        visibleQuickItems(items, user).map((i) => i.label).toList();

    test('employee tiles', () {
      expect(labels(kQuickItemsEmployee, employee),
          ['Apply Leave', 'My Payslips', 'Attendance', 'My Expenses', 'Documents', 'My Profile']);
      // Without the optional permissions only the open tiles remain.
      expect(labels(kQuickItemsEmployee, noPermissions), ['Attendance', 'My Profile']);
    });

    test('manager tiles: approvals by approve permission; no Interviews without recruitment.view', () {
      expect(labels(kQuickItemsManager, manager),
          ['Review Approvals', 'Apply Leave', 'My Payslip', 'Team Members', 'My Requests']);
      // leave.view alone no longer shows "Review Approvals".
      expect(labels(kQuickItemsManager, _user('manager', ['leave.view'])), ['Apply Leave', 'My Requests']);
    });

    test('HR, Branch Admin and System Admin tiles', () {
      expect(labels(kQuickItemsHr, hr),
          ['Interview List', 'Leave Approvals', 'Employees', 'Review Candidates', 'Settings']);
      expect(labels(kQuickItemsHr, branchAdmin), labels(kQuickItemsHr, hr));
      expect(labels(kQuickItemsAdmin, systemAdmin),
          ['Employees', 'Roles & Perms', 'Attendance', 'Branches', 'Settings']);
    });

    test('missing user data shows only tiles open to everyone', () {
      for (final items in kQuickItemsByRole.values) {
        expect(visibleQuickItems(items, null).every((i) => i.permission == null && i.anyOfPermissions == null),
            isTrue);
      }
    });
  });

  group('direct navigation (resolveAuthRedirect)', () {
    String? go(UserEntity user, String path) => resolveAuthRedirect(authState: AuthState(user: user), path: path);

    test('unauthorized screens bounce to the dashboard; permitted ones open', () {
      for (final path in [
        '/dashboard/attendance', '/dashboard/approvals', '/dashboard/employees/emp-7', '/dashboard/interview-list',
        '/dashboard/settings', '/settings/roles', '/settings/audit', '/employees/bulk-import',
        '/dashboard/face-id-registrations', '/dashboard/branches', '/dashboard/reports',
      ]) {
        expect(go(employee, path), AppRoutes.dashboard, reason: 'employee → $path');
      }
      for (final path in [
        '/dashboard', '/dashboard/leave', '/dashboard/wfh', '/dashboard/expenses', '/dashboard/documents',
        '/dashboard/org-chart', '/dashboard/announcements', '/dashboard/separation/req-1', '/dashboard/my-attendance',
        '/dashboard/my-payslip', '/dashboard/my-requests', '/dashboard/referrals', '/dashboard/profile',
      ]) {
        expect(go(employee, path), isNull, reason: 'employee → $path');
      }
    });

    test('per-role spot checks', () {
      expect(go(manager, '/dashboard/approvals'), isNull);
      expect(go(manager, '/dashboard/attendance'), isNull);
      expect(go(manager, '/dashboard/interview-list'), AppRoutes.dashboard);
      expect(go(hr, '/dashboard/approvals'), isNull);
      expect(go(hr, '/dashboard/branches'), AppRoutes.dashboard);
      expect(go(branchAdmin, '/dashboard/branches'), isNull);
      expect(go(branchAdmin, '/settings/audit'), isNull);
      expect(go(systemAdmin, '/dashboard/face-id-registrations'), isNull);
      expect(go(noPermissions, '/dashboard/leave'), AppRoutes.dashboard);
    });

    test('/settings/audit needs audit.view, the rest of /settings needs settings.view', () {
      expect(go(_user('auditor', ['audit.view']), '/settings/audit'), isNull);
      expect(go(_user('auditor', ['audit.view']), '/settings/roles'), AppRoutes.dashboard);
    });

    test('earlier gates still come first (forced password change, onboarding)', () {
      const flagged = UserEntity(
        id: 'u', email: 'e@x.com', fullName: 'E', role: 'employee', roleDisplay: 'E',
        mustChangePassword: true, permissions: [], onboardingStatus: 'complete',
      );
      expect(go(flagged, '/dashboard/settings'), AppRoutes.changePassword);
      expect(resolveAuthRedirect(authState: const AuthState.initial(), path: '/dashboard/settings'), AppRoutes.login);
    });
  });

  group('consistency', () {
    test('every visible menu item and quick tile opens without being redirected', () {
      for (final user in [employee, manager, hr, branchAdmin, systemAdmin, noPermissions]) {
        for (final item in buildNav(user).whereType<NavItem>()) {
          expect(canAccessPath(user, item.path), isTrue, reason: '${user.role}: menu ${item.id}');
        }
        for (final items in kQuickItemsByRole.values) {
          for (final tile in visibleQuickItems(items, user)) {
            expect(canAccessPath(user, tile.path), isTrue, reason: '${user.role}: tile ${tile.label}');
          }
        }
      }
    });

    test('dashboard category selection is unchanged (P1-01)', () {
      expect(resolveDashboardCategory(employee), 'employee');
      expect(resolveDashboardCategory(manager), 'manager');
      expect(resolveDashboardCategory(hr), 'hr');
      expect(resolveDashboardCategory(branchAdmin), 'hr');
      expect(resolveDashboardCategory(systemAdmin), 'admin');
      expect(resolveDashboardCategory(noPermissions), 'employee');
    });
  });

  group('QuickAccessCard', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    Future<void> pumpCard(WidgetTester tester, UserEntity user, List<QuickItem> items) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authStateProvider.overrideWith(() => _FixedAuthNotifier(user))],
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: QuickAccessCard(items: items)))),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('renders only the permitted tiles', (tester) async {
      await pumpCard(tester, _user('manager', ['leave.view']), kQuickItemsManager);
      expect(find.text('Apply Leave'), findsOneWidget);
      expect(find.text('My Requests'), findsOneWidget);
      expect(find.text('Review Approvals'), findsNothing);
      expect(find.text('Team Members'), findsNothing);
    });

    testWidgets('hides itself when no tile is permitted', (tester) async {
      await pumpCard(tester, noPermissions, kQuickItemsHr);
      expect(find.text('Quick Access'), findsNothing);
    });
  });
}

class _FixedAuthNotifier extends AuthNotifier {
  _FixedAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<AuthState> build() async => AuthState(user: _user);
}
