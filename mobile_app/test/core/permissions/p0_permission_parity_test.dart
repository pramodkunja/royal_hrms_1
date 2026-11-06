import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/branches/presentation/providers/branch_providers.dart';
import 'package:mobile_app/features/branches/presentation/screens/branches_screen.dart';
import 'package:mobile_app/features/settings/data/models/company_model.dart';
import 'package:mobile_app/features/settings/data/models/departments_model.dart';
import 'package:mobile_app/features/settings/data/models/roles_model.dart';
import 'package:mobile_app/features/settings/presentation/company/company_screen.dart';
import 'package:mobile_app/features/settings/presentation/company/widgets/financial_year_section.dart';
import 'package:mobile_app/features/settings/presentation/departments/departments_screen.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/leave_policy_screen.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/widgets/leave_carry_forward_tab.dart';
import 'package:mobile_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:mobile_app/features/settings/presentation/roles/roles_screen.dart';

// Task 17: P0 permission parity (6 Nov audit rows 69, 78, 85, 86).
//  • Company / Departments & Designations / Roles: edit only with settings.edit
//    (web usePermission("settings.edit"); the server refuses without it).
//  • Branches: Add / Edit / Delete only with settings.edit (web
//    BranchManagement canEdit); list and View Details stay with branches.view.
//  • Leave Policy: Carry Forward tab and Import Opening Balances by leave.edit
//    (web), never by role name; the server (leave.approve) stays authoritative.
//  • HR Attendance: Import only with attendance.create.
// A stand-in server with synthetic data; nothing is sent anywhere.

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
Map<String, dynamic> ok(Object data) => {'status': 'success', 'message': 'ok', 'data': data};

class Server implements HttpClientAdapter {
  final writes = <String>[];
  final gets = <String>[];
  bool refuseCarryForward = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    final key = '${o.method} ${o.path}';
    if (o.method != 'GET') {
      writes.add(key);
      if (o.path == ApiConstants.departments) {
        return _json(ok({'id': 9, 'name': 'Test New Dept', 'is_active': true}), 201);
      }
      return _json(ok(<String, dynamic>{}));
    }
    gets.add(o.path);
    switch (o.path) {
      case ApiConstants.settingsCompany:
        return _json(ok({'id': 1, 'company_name': 'Test Company Pvt Ltd', 'city': 'Test City'}));
      case ApiConstants.settingsCompanyFinancialYear:
        return _json(ok({
          'financial_year_start_month': 'April',
          'previous_financial_year': '2025-26',
          'current_financial_year': '2026-27',
          'next_financial_year': '2027-28',
        }));
      case ApiConstants.departments:
        return _json(ok([
          {'id': 1, 'name': 'Test Ops', 'is_active': true, 'designation_count': 1, 'employee_count': 3},
        ]));
      case ApiConstants.designations:
        return _json(ok([
          {'id': 11, 'name': 'Test Lead', 'department': 1, 'is_active': true},
        ]));
      case ApiConstants.roles:
        return _json(ok({
          'count': 1,
          'results': [
            {'id': 5, 'name': 'test_role', 'display_name': 'Test Role', 'permissions': [], 'user_count': 2},
          ],
        }));
      case ApiConstants.branches:
        return _json(ok({
          'count': 1,
          'results': [
            {'id': 3, 'branch_code': 'BR-003', 'branch_name': 'Test Branch', 'status': 'active', 'employees_count': 4},
          ],
        }));
      case ApiConstants.carryForwardYears:
        if (refuseCarryForward) return _json({'status': 'error', 'message': 'Permission denied.'}, 403);
        return _json(ok({'years': [], 'default_from': null, 'default_to': null}));
      case ApiConstants.leaveTypes:
        return _json(ok([]));
    }
    return _json(ok({'results': [], 'count': 0, 'summary_chips': <String, int>{}}));
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

UserEntity user(List<String> perms, {String role = 'hr', bool superuser = false}) => UserEntity(
      id: 'u1',
      email: 'user@example.test',
      fullName: 'Test User',
      role: role,
      roleDisplay: role,
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final settingsViewer = user(['settings.view', 'branches.view']);
final settingsEditor = user(['settings.view', 'settings.edit', 'branches.view']);

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pumpScreen(WidgetTester tester, Widget screen, UserEntity u, {Size size = const Size(1080, 3000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(u),
    child: MaterialApp.router(
      routerConfig: GoRouter(initialLocation: '/s', routes: [
        GoRoute(
          path: '/s',
          builder: (_, __) => Consumer(
            builder: (context, ref, _) =>
                ref.watch(authStateProvider).valueOrNull?.user == null ? const SizedBox() : screen,
          ),
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<ProviderContainer> signedIn(UserEntity u) async {
  server = Server();
  final c = ProviderContainer(overrides: overrides(u));
  addTearDown(c.dispose);
  await c.read(authStateProvider.future);
  return c;
}

/// The Financial Year month picker (the company form has its own dropdowns).
final yearEditor =
    find.descendant(of: find.byType(FinancialYearSection), matching: find.byType(DropdownButtonFormField<String>));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('P0-1 Company, Departments & Designations, Roles (settings.edit)', () {
    testWidgets('Company, settings.view only: details shown read-only; no logo change, Save or year editor',
        (tester) async {
      await pumpScreen(tester, const CompanyScreen(), settingsViewer);
      expect(find.text('Test Company Pvt Ltd'), findsWidgets);
      expect(find.text('Save Changes'), findsNothing);
      expect(find.byKey(const Key('company-logo-change')), findsNothing);
      expect(tester.widget<IgnorePointer>(find.byKey(const Key('company-fields'))).ignoring, isTrue);
      expect(find.text('Financial Year Starts In'), findsOneWidget); // shown as text
      expect(yearEditor, findsNothing);
      expect(find.text('2026-27'), findsOneWidget); // year chips still visible
    });

    testWidgets('Company, settings.edit: Save, logo change and the year editor are available', (tester) async {
      await pumpScreen(tester, const CompanyScreen(), settingsEditor);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.byKey(const Key('company-logo-change')), findsOneWidget);
      expect(tester.widget<IgnorePointer>(find.byKey(const Key('company-fields'))).ignoring, isFalse);
      expect(yearEditor, findsOneWidget);
    });

    testWidgets('Departments, settings.view only: list and designations visible; no add / edit / delete',
        (tester) async {
      await pumpScreen(tester, const DepartmentsScreen(), settingsViewer);
      expect(find.text('Test Ops'), findsOneWidget);
      expect(find.byKey(const Key('dept-add')), findsNothing);
      expect(find.byKey(const Key('dept-actions-1')), findsNothing);
      await tester.tap(find.text('Test Ops'));
      await tester.pumpAndSettle();
      expect(find.text('Test Lead'), findsOneWidget);
      expect(find.byKey(const Key('desig-add')), findsNothing);
      expect(find.byKey(const Key('desig-edit-11')), findsNothing);
    });

    testWidgets('Departments, settings.edit: add / edit / delete and designation actions shown', (tester) async {
      await pumpScreen(tester, const DepartmentsScreen(), settingsEditor);
      expect(find.byKey(const Key('dept-add')), findsOneWidget);
      expect(find.byKey(const Key('dept-actions-1')), findsOneWidget);
      await tester.tap(find.text('Test Ops'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('desig-add')), findsOneWidget);
      expect(find.byKey(const Key('desig-edit-11')), findsOneWidget);
    });

    testWidgets('Roles, settings.view only: roles listed as "View only"; no Add Role, edit or toggle', (tester) async {
      await pumpScreen(tester, const RolesScreen(), settingsViewer);
      expect(find.text('Test Role'), findsWidgets);
      expect(find.byKey(const Key('role-view-only-5')), findsOneWidget);
      expect(find.byKey(const Key('role-add')), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('Roles, settings.edit: Add Role, edit and toggle shown', (tester) async {
      await pumpScreen(tester, const RolesScreen(), settingsEditor);
      expect(find.byKey(const Key('role-add')), findsOneWidget);
      expect(find.byKey(const Key('role-view-only-5')), findsNothing);
      expect(find.byType(Switch), findsOneWidget);
    });

    test('below the UI: every write is refused without settings.edit and nothing is sent', () async {
      final c = await signedIn(settingsViewer);
      final company = CompanyModel.fromJson(const {'company_name': 'X'});
      expect(await c.read(companyProvider.notifier).save(company), kSettingsEditDenied);
      expect(await c.read(financialYearProvider.notifier).save('January'), kSettingsEditDenied);
      final depts = c.read(departmentsProvider.notifier);
      expect(await depts.createDept(DeptFormData()..name = 'X'), kSettingsEditDenied);
      expect(await depts.editDept(1, DeptFormData()..name = 'X'), kSettingsEditDenied);
      expect(await depts.removeDept(1), kSettingsEditDenied);
      final desigs = c.read(designationsProvider.notifier);
      expect(await desigs.createDesig(DesignationFormData()..name = 'X'), kSettingsEditDenied);
      expect(await desigs.editDesig(11, DesignationFormData()..name = 'X'), kSettingsEditDenied);
      expect(await desigs.removeDesig(11), kSettingsEditDenied);
      final roles = c.read(rolesProvider.notifier);
      expect(await roles.create(RoleFormData()..name = 'x'), kSettingsEditDenied);
      expect(await roles.edit(5, RoleFormData()..name = 'x'), kSettingsEditDenied);
      expect(await roles.toggleActive(5, false), kSettingsEditDenied);
      expect(server.writes, isEmpty);
    });

    test('with settings.edit the write goes to the server (superuser too)', () async {
      final c = await signedIn(settingsEditor);
      expect(await c.read(departmentsProvider.notifier).createDept(DeptFormData()..name = 'Test New Dept'), isNull);
      expect(server.writes, ['POST ${ApiConstants.departments}']);
      final s = await signedIn(user([], superuser: true));
      expect(await s.read(rolesProvider.notifier).toggleActive(5, false), isNull);
      expect(server.writes, ['PATCH ${ApiConstants.roleDetail(5)}']);
    });
  });

  group('P0-2 Branches (settings.edit for Add / Edit / Delete)', () {
    testWidgets('branches.view only: list and View Details, no Add / Edit / Delete', (tester) async {
      await pumpScreen(tester, const BranchesScreen(), settingsViewer);
      expect(find.text('Test Branch'), findsWidgets);
      expect(find.text('View Details'), findsOneWidget);
      expect(find.text('Add Branch'), findsNothing);
      expect(find.byTooltip('Edit branch'), findsNothing);
      expect(find.byTooltip('Delete branch'), findsNothing);
    });

    testWidgets('settings.edit: Add Branch, Edit and Delete shown', (tester) async {
      await pumpScreen(tester, const BranchesScreen(), settingsEditor);
      expect(find.text('Add Branch'), findsOneWidget);
      expect(find.byTooltip('Edit branch'), findsOneWidget);
      expect(find.byTooltip('Delete branch'), findsOneWidget);
    });

    test('below the UI: create / edit / delete refused without settings.edit, nothing sent', () async {
      final c = await signedIn(settingsViewer);
      final n = c.read(branchListProvider.notifier);
      expect(
          await n.create(cityId: 1, stateId: 1, branchName: 'X', address: 'Y', status: 'active', isHeadquarter: false),
          kBranchEditDenied);
      expect(
          await n.edit(
              id: 3, cityId: 1, stateId: 1, branchName: 'X', address: 'Y', status: 'active', isHeadquarter: false),
          kBranchEditDenied);
      expect(await n.remove(3), kBranchEditDenied);
      expect(server.writes, isEmpty);
    });
  });

  group('P0-3 Leave Policy carry forward and opening balances (leave.edit, not role names)', () {
    test('permission rule: leave.edit (or the app-wide superuser / settings.edit pass), never the role name', () {
      expect(canManageCarryForward(user(['leave.edit'], role: 'branch_admin')), isTrue);
      expect(canManageCarryForward(user(['leave.view', 'leave.approve'], role: 'hr')), isFalse);
      expect(canManageCarryForward(user([], role: 'system_admin')), isFalse);
      expect(canManageCarryForward(user([], superuser: true)), isTrue);
      expect(canManageCarryForward(user(['settings.edit'])), isTrue);
      expect(canManageCarryForward(null), isFalse);
    });

    testWidgets('Branch Admin with leave.edit sees the Carry Forward tab and Import Opening Balances', (tester) async {
      await pumpScreen(tester, const LeavePolicyScreen(),
          user(['settings.view', 'leave.edit', 'leave.approve'], role: 'branch_admin'));
      expect(find.text('Carry Forward'), findsOneWidget);
      expect(find.byTooltip('Import Opening Balances'), findsOneWidget);
    });

    testWidgets('"hr" role without leave.edit: neither is shown', (tester) async {
      await pumpScreen(tester, const LeavePolicyScreen(), user(['settings.view', 'leave.approve'], role: 'hr'));
      expect(find.text('Carry Forward'), findsNothing);
      expect(find.byTooltip('Import Opening Balances'), findsNothing);
      expect(find.text('Leave Types'), findsOneWidget); // the rest of Leave Policy is unchanged
    });

    testWidgets('leave.edit without leave.approve: tab shown, the server\'s refusal is displayed', (tester) async {
      tester.view.physicalSize = const Size(1600, 3000);
      await pumpScreen(tester, const LeavePolicyScreen(), user(['settings.view', 'leave.edit'], role: 'branch_admin'),
          size: const Size(1600, 3000));
      server.refuseCarryForward = true;
      await tester.tap(find.text('Carry Forward'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Permission denied.'), findsOneWidget);
      expect(server.gets, contains(ApiConstants.carryForwardYears));
      expect(server.writes, isEmpty);
    });
  });

  group('P0-4 HR Attendance Import (attendance.create)', () {
    Future<void> pumpAttendance(WidgetTester tester, UserEntity u) =>
        pumpScreen(tester, const Scaffold(body: AttendanceScreen()), u, size: const Size(1600, 4000));

    testWidgets('without attendance.create: no Import; viewing and Export unchanged', (tester) async {
      await pumpAttendance(tester, user(['attendance.view', 'attendance.export']));
      expect(find.byKey(const Key('attendance-import-button')), findsNothing);
      expect(find.byKey(const Key('attendance-export-button')), findsOneWidget);
      expect(find.text('Attendance'), findsWidgets);
    });

    testWidgets('with attendance.create: Import shown', (tester) async {
      await pumpAttendance(tester, user(['attendance.view', 'attendance.create']));
      expect(find.byKey(const Key('attendance-import-button')), findsOneWidget);
    });

    test('below the UI: the upload is refused without attendance.create and nothing is sent', () async {
      final c = await signedIn(user(['attendance.view']));
      await expectLater(c.read(attendanceImportActionProvider).upload(utf8.encode('a,b\n'), 'x.csv'),
          throwsA(kAttendanceImportDenied));
      expect(server.writes, isEmpty);
    });
  });
}
