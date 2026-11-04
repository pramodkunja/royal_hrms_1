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
import 'package:mobile_app/features/dashboard/presentation/screens/admin_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/employee_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/hr_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';

// Permission sets mirror the backend's seeded roles, so these fixtures are
// what the login response really carries for each role.
// branch_admin: backend/apps/accounts/migrations/0052_seed_branch_admin_role.py
// (settings.edit is explicitly revoked by 0070_revoke_settings_edit_from_branch_admin.py).
const _branchAdminPermissions = [
  'employees.view', 'employees.create', 'employees.edit', 'leave.view', 'leave.approve',
  'attendance.view', 'recruitment.view', 'documents.view', 'branches.view', 'settings.view',
];

UserEntity _user({
  String role = 'employee',
  List<String> permissions = const [],
  bool isSuperuser = false,
  bool canManageTeam = false,
  bool canManageBranch = false,
}) =>
    UserEntity(
      id: 'u-1',
      email: 'user@example.com',
      fullName: 'Test User',
      role: role,
      roleDisplay: role,
      mustChangePassword: false,
      permissions: permissions,
      onboardingStatus: 'complete',
      isSuperuser: isSuperuser,
      canManageTeam: canManageTeam,
      canManageBranch: canManageBranch,
    );

final _branchAdmin = _user(
  role: 'branch_admin', permissions: _branchAdminPermissions, canManageBranch: true,
);

void main() {
  group('resolveDashboardCategory', () {
    test('Branch Admin gets the HR dashboard, not the system-admin one', () {
      // The reported bug: "branch_admin" contains "admin", so name matching
      // sent Branch Admins to /dashboard/system-admin/*, which 403s without
      // settings.edit.
      expect(resolveDashboardCategory(_branchAdmin), 'hr');
    });

    test('existing roles keep their dashboard', () {
      final cases = <String, (UserEntity, String)>{
        'system_admin (is_superuser)': (
          _user(role: 'system_admin', isSuperuser: true, permissions: ['settings.edit', 'employees.view']),
          'admin',
        ),
        'hr': (_user(role: 'hr', permissions: ['employees.view']), 'hr'),
        'hr_admin': (_user(role: 'hr_admin', permissions: ['employees.view', 'leave.approve']), 'hr'),
        'manager__team_lead': (_user(role: 'manager__team_lead', canManageTeam: true), 'manager'),
        'employee': (_user(permissions: ['leave.view', 'attendance.view']), 'employee'),
      };
      cases.forEach((label, c) {
        expect(resolveDashboardCategory(c.$1), c.$2, reason: label);
      });
    });

    test('multiple flags follow the web precedence: superuser > manager > hr > employee', () {
      expect(
        resolveDashboardCategory(_user(isSuperuser: true, canManageTeam: true, permissions: ['employees.view'])),
        'admin',
      );
      expect(resolveDashboardCategory(_user(canManageTeam: true, permissions: ['employees.view'])), 'manager');
      expect(
        resolveDashboardCategory(_user(canManageBranch: true, canManageTeam: true, permissions: ['employees.view'])),
        'manager',
      );
    });

    test('settings.edit alone resolves to admin, like the server (cached user without is_superuser)', () {
      expect(resolveDashboardCategory(_user(role: 'system_admin', permissions: ['settings.edit'])), 'admin');
    });

    test('the role name alone never grants a dashboard', () {
      for (final role in ['system_admin', 'branch_admin', 'Super Admin', 'hr', 'hr_admin', 'manager']) {
        expect(resolveDashboardCategory(_user(role: role)), 'employee', reason: role);
      }
    });

    test('missing, null or unexpected flags fall back to the employee dashboard', () {
      expect(resolveDashboardCategory(null), 'employee');
      expect(resolveDashboardCategory(_user(role: '', permissions: const [])), 'employee');
      expect(resolveDashboardCategory(_user(role: 'custom_role', permissions: ['unknown.perm'])), 'employee');
      // can_manage_branch alone is not a dashboard grant on web either.
      expect(resolveDashboardCategory(_user(canManageBranch: true)), 'employee');
    });
  });

  group('HomeScreen', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    late _RecordingBackend backend;

    Future<void> pumpHome(WidgetTester tester, UserEntity user) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      backend = _RecordingBackend();
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = backend;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => _FixedAuthNotifier(user)),
            dioProvider.overrideWithValue(dio),
            cookieJarProvider.overrideWithValue(CookieJar()),
            secureStorageProvider.overrideWithValue(_NullSecureStorage()),
          ],
          child: const MaterialApp(home: Scaffold(body: HomeScreen())),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Dashboards start periodic timers (clock ticks); unmount before the
    // test ends so none are left pending.
    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('Branch Admin sees the HR dashboard and never calls system-admin endpoints', (tester) async {
      await pumpHome(tester, _branchAdmin);

      expect(find.byType(HrDashboardView), findsOneWidget);
      expect(find.byType(AdminDashboardView), findsNothing);
      expect(backend.paths.where((p) => p.contains('/dashboard/system-admin/')), isEmpty);
      expect(backend.paths.where((p) => p.contains('/dashboard/hr/')), isNotEmpty);
      await unmount(tester);
    });

    testWidgets('System Admin still gets the admin dashboard', (tester) async {
      await pumpHome(tester, _user(role: 'system_admin', isSuperuser: true, permissions: ['settings.edit']));

      expect(find.byType(AdminDashboardView), findsOneWidget);
      expect(backend.paths.where((p) => p.contains('/dashboard/system-admin/')), isNotEmpty);
      await unmount(tester);
    });

    testWidgets('a role named like an admin without permissions gets the employee dashboard', (tester) async {
      await pumpHome(tester, _user(role: 'branch_admin'));

      expect(find.byType(EmployeeDashboardView), findsOneWidget);
      expect(backend.paths.where((p) => p.contains('/dashboard/system-admin/')), isEmpty);
      expect(backend.paths.where((p) => p.contains('/dashboard/hr/')), isEmpty);
      await unmount(tester);
    });
  });
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

/// Records every request path. Answers /dashboard/system-admin/* with the
/// backend's real response for a caller without settings.edit
/// (apps/dashboard/views/overview.py), and everything else with an empty
/// success envelope.
class _RecordingBackend implements HttpClientAdapter {
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final denied = options.path.contains('/dashboard/system-admin/');
    return ResponseBody.fromString(
      jsonEncode(denied
          ? {'status': 'error', 'message': 'You do not have permission to perform this action.', 'data': {}}
          : {'status': 'success', 'message': 'ok', 'data': {}}),
      denied ? 403 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
