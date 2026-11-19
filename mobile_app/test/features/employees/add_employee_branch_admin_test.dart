import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:mobile_app/features/employees/presentation/widgets/add_employee_sheet.dart';
import 'package:mobile_app/features/settings/data/models/departments_model.dart';
import 'package:mobile_app/features/settings/data/models/roles_model.dart';

// Task 97 (A): web AddEmployeeModal.tsx — role dropdown excludes roles with
// `settings.edit`; Branch locked unless is_superuser / settings.edit; a role
// with `can_manage_branch` (Branch Admin) locks Department ("Not applicable —
// Branch Admin", not required, sent as ""), makes Designation free text
// defaulting to "Branch Manager"; validation messages are web's. Synthetic
// data on a stand-in server; nobody is really created. Mocked tests only —
// not a production verification.

class _Server implements HttpClientAdapter {
  final calls = <RequestOptions>[];

  List<RequestOptions> posts() => calls.where((c) => c.method == 'POST' && c.path == ApiConstants.employees).toList();

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add(o);
    if (o.path == ApiConstants.employees && o.method == 'POST') {
      return _json({
        'status': 'success',
        'message': 'Employee added successfully.',
        'data': {'id': 'u-new', 'employee_id': 'EMP-NEW', 'full_name': 'Nia Test', 'role': 'employee'},
      }, 201);
    }
    return _json({'status': 'success', 'data': []});
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

UserEntity _user({bool superuser = false, List<String> perms = const [], String branch = 'Pune'}) => UserEntity(
      id: 'me',
      email: 'me@example.test',
      fullName: 'Test User',
      role: 'custom_role',
      roleDisplay: 'Custom',
      branch: branch,
      mustChangePassword: false,
      permissions: ['employees.view', 'employees.create', ...perms],
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

// Personas (synthetic). Note none is identified by role name.
final _superuser = _user(superuser: true, branch: '');
final _settingsEditUser = _user(perms: const ['settings.edit'], branch: '');
final _hr = _user(perms: const ['onboarding.approve'], branch: 'Pune');
const _branchAdmin = UserEntity(
  id: 'me-ba',
  email: 'ba@example.test',
  fullName: 'Branch Lead',
  role: 'branch_lead',
  roleDisplay: 'Branch Lead',
  branch: 'Mumbai',
  mustChangePassword: false,
  permissions: ['employees.view', 'employees.create'],
  canManageBranch: true,
  onboardingStatus: 'complete',
  assessmentStatus: 'complete',
);

final _roles = [
  RoleModel.fromJson(const {'id': 3, 'name': 'employee', 'display_name': 'Employee', 'permissions': []}),
  RoleModel.fromJson(const {
    'id': 4,
    'name': 'branch_lead',
    'display_name': 'Branch Lead',
    'permissions': ['employees.view'],
    'can_manage_branch': true,
  }),
  // Carries settings.edit under a renamed display name: must never be offered.
  RoleModel.fromJson(const {
    'id': 5,
    'name': 'org_owner',
    'display_name': 'Org Owner',
    'permissions': ['settings.edit', 'employees.view'],
  }),
  RoleModel.fromJson(const {
    'id': 6,
    'name': 'system_admin',
    'display_name': 'System Admin',
    'permissions': ['settings.edit'],
  }),
];

late _Server _server;
bool? _result;

Future<void> _pump(WidgetTester tester, UserEntity as) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _server = _Server();
  _result = null;
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = _server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      employeeFormRolesProvider.overrideWithValue(AsyncData(_roles)),
      employeeFormDepartmentsProvider.overrideWithValue(AsyncData([
        DepartmentModel.fromJson(const {'id': 1, 'name': 'Quality'}),
      ])),
      employeeBranchesProvider.overrideWith((ref) async => const [
            EmployeeBranch(id: 1, name: 'Pune'),
            EmployeeBranch(id: 2, name: 'Mumbai'),
          ]),
      employeeDesignationsByDeptProvider.overrideWith((ref, id) async => ['QA Analyst']),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async => _result = await AddEmployeeSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
}

Finder get _roleDropdown => find.byType(DropdownButtonFormField<dynamic>);

Future<void> _open(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _chooseRole(WidgetTester tester, String label) async {
  await _open(tester, _roleDropdown);
  await tester.tap(find.text(label).last);
  await _settle(tester);
}

/// Display names currently offered by the open Role dropdown.
Future<Set<String>> _offeredRoles(WidgetTester tester) async {
  await _open(tester, _roleDropdown);
  final offered = <String>{};
  for (final n in ['Employee', 'Branch Lead', 'Org Owner', 'System Admin']) {
    // Menu items are in an overlay; the closed field shows only the hint.
    if (find.text(n).evaluate().isNotEmpty) offered.add(n);
  }
  await tester.tapAt(const Offset(5, 5)); // dismiss the menu
  await tester.pumpAndSettle();
  return offered;
}

Future<void> _fillCommon(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Nia');
  await tester.enterText(fields.at(1), 'Test');
  await tester.enterText(fields.at(2), 'nia.test@example.test');
}

Future<void> _pickDate(WidgetTester tester) async {
  await tester.ensureVisible(find.text('dd/mm/yyyy'));
  await tester.tap(find.text('dd/mm/yyyy'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Add Employee'));
  await tester.tap(find.text('Add Employee'));
  await _settle(tester);
}

Map<String, dynamic> _lastBody() => _server.posts().last.data as Map<String, dynamic>;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model', () {
    test('applyRole(branch admin): clears department, defaults designation, keeps a typed one', () {
      final f = EmployeeFormData(department: 'Quality', designation: '', reportingManagerId: 'u-m')..departmentId = 1;
      f.applyRole(4, canManageBranch: true);
      expect(f.isBranchAdmin, isTrue);
      expect(f.department, '');
      expect(f.departmentId, isNull);
      expect(f.designation, 'Branch Manager');
      expect(f.reportingManagerId, isNull, reason: 'web clears the manager when the department clears');

      final g = EmployeeFormData(designation: 'Regional Head');
      g.applyRole(4, canManageBranch: true);
      expect(g.designation, 'Regional Head');
    });

    test('applyRole(other role) does not touch department/designation', () {
      final f = EmployeeFormData(department: 'Quality', designation: 'QA Analyst');
      f.applyRole(3, canManageBranch: false);
      expect(f.isBranchAdmin, isFalse);
      expect(f.department, 'Quality');
      expect(f.designation, 'QA Analyst');
    });

    EmployeeFormData valid({bool branchAdmin = false}) => EmployeeFormData(
          firstName: 'Nia',
          lastName: 'Test',
          email: 'nia@example.test',
          roleId: 3,
          department: branchAdmin ? '' : 'Quality',
          designation: branchAdmin ? 'Branch Manager' : 'QA Analyst',
          branch: 'Pune',
          dateOfJoining: '2026-11-10',
        )..isBranchAdmin = branchAdmin;

    test('department is required unless the role is a Branch Admin', () {
      expect(valid().validate(), isEmpty);
      expect(valid(branchAdmin: true).validate(), isEmpty);
      final f = valid()..department = '';
      expect(f.validate(), {'department': 'Required'});
    });

    test('empty form: web messages ("Required")', () {
      expect(EmployeeFormData().validate(), {
        'first_name': 'Required',
        'last_name': 'Required',
        'email': 'Required',
        'role': 'Required',
        'department': 'Required',
        'designation': 'Required',
        'branch': 'Required',
        'date_of_joining': 'Required',
      });
    });

    test('empty form as Branch Admin: no department error, designation still required', () {
      final e = (EmployeeFormData()..isBranchAdmin = true).validate();
      expect(e.containsKey('department'), isFalse);
      expect(e['designation'], 'Required');
    });

    test('name / email / phone format messages match web', () {
      final f = valid()
        ..firstName = 'Ni@'
        ..lastName = "O'Neil-Smith 2"
        ..email = 'nope'
        ..phone = '12345';
      final e = f.validate();
      expect(e['first_name'], 'Letters, numbers, spaces, hyphens and apostrophes only');
      expect(e.containsKey('last_name'), isFalse);
      expect(e['email'], 'Enter a valid email');
      expect(e['phone'], 'Enter a valid 10-digit phone number (optionally prefixed with +91).');
      expect((valid()..phone = '+91 98765-43210').validate(), isEmpty);
    });

    test('Branch Admin payload: department sent as "" (web spreads the empty form value)', () {
      final j = valid(branchAdmin: true).toJson();
      expect(j['department'], '');
      expect(j['designation'], 'Branch Manager');
      expect(j['role'], 3);
      expect(j.keys.toSet(), {
        'first_name',
        'last_name',
        'email',
        'role',
        'department',
        'designation',
        'branch',
        'employee_type',
        'date_of_joining',
      });
    });
  });

  group('helpers (web lib/auth.ts)', () {
    test('isUnrestrictedEmployeeUser: superuser or settings.edit only', () {
      expect(isUnrestrictedEmployeeUser(_superuser), isTrue);
      expect(isUnrestrictedEmployeeUser(_settingsEditUser), isTrue);
      expect(isUnrestrictedEmployeeUser(_hr), isFalse);
      expect(isUnrestrictedEmployeeUser(_branchAdmin), isFalse, reason: 'canManageBranch does not unlock branches');
      expect(isUnrestrictedEmployeeUser(null), isFalse);
    });

    test('assignableEmployeeRoles drops every role carrying settings.edit, by permission not name', () {
      expect(assignableEmployeeRoles(_roles).map((r) => r.displayName), ['Employee', 'Branch Lead']);
    });
  });

  group('sheet — role availability and branch lock per persona', () {
    for (final entry in {
      'superuser': _superuser,
      'settings.edit holder': _settingsEditUser,
      'HR (branch-restricted)': _hr,
      'Branch Admin (branch-restricted)': _branchAdmin,
    }.entries) {
      testWidgets('${entry.key}: roles with settings.edit are never offered', (tester) async {
        await _pump(tester, entry.value);
        expect(await _offeredRoles(tester), {'Employee', 'Branch Lead'});
      });
    }

    for (final entry in {'superuser': _superuser, 'settings.edit holder': _settingsEditUser}.entries) {
      testWidgets('${entry.key}: Branch is a free choice (not locked)', (tester) async {
        await _pump(tester, entry.value);
        expect(find.byKey(const Key('add-employee-branch-locked')), findsNothing);
      });
    }

    testWidgets('HR: Branch locked to the user own branch and submitted as such', (tester) async {
      await _pump(tester, _hr);
      expect(find.byKey(const Key('add-employee-branch-locked')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('add-employee-branch-locked')), matching: find.text('Pune')),
          findsOneWidget);
      await _fillCommon(tester);
      await _chooseRole(tester, 'Employee');
      await _pickDate(tester);
      await _open(tester, find.byType(DropdownButtonFormField<DepartmentModel>));
      await tester.tap(find.text('Quality').last);
      await _settle(tester);
      await _open(tester, find.byType(DropdownButtonFormField<String>).first);
      await tester.tap(find.text('QA Analyst').last);
      await _settle(tester);
      await _submit(tester);
      expect(_lastBody()['branch'], 'Pune');
      expect(_lastBody()['department'], 'Quality');
      expect(_lastBody()['designation'], 'QA Analyst');
    });

    testWidgets('Branch Admin caller is still branch-locked (own branch, not unrestricted)', (tester) async {
      await _pump(tester, _branchAdmin);
      expect(find.descendant(of: find.byKey(const Key('add-employee-branch-locked')), matching: find.text('Mumbai')),
          findsOneWidget);
    });
  });

  group('sheet — Branch Admin role selected', () {
    testWidgets('Department locked "Not applicable — Branch Admin", Designation free text "Branch Manager"',
        (tester) async {
      await _pump(tester, _superuser);
      expect(find.byKey(const Key('add-employee-department-locked')), findsNothing);
      expect(find.byType(DropdownButtonFormField<DepartmentModel>), findsOneWidget);
      await _chooseRole(tester, 'Branch Lead');
      expect(find.byKey(const Key('add-employee-department-locked')), findsOneWidget);
      expect(find.text('Not applicable — Branch Admin'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<DepartmentModel>), findsNothing);
      // Designation became a text field holding the default.
      expect(find.widgetWithText(TextFormField, 'Branch Manager'), findsOneWidget);
    });

    testWidgets('switching back to a normal role restores the Department dropdown', (tester) async {
      await _pump(tester, _superuser);
      await _chooseRole(tester, 'Branch Lead');
      await _chooseRole(tester, 'Employee');
      expect(find.byKey(const Key('add-employee-department-locked')), findsNothing);
      expect(find.byType(DropdownButtonFormField<DepartmentModel>), findsOneWidget);
    });

    testWidgets('submits without a department and without a department error', (tester) async {
      await _pump(tester, _superuser);
      await _fillCommon(tester);
      await _chooseRole(tester, 'Branch Lead');
      // Superuser picks the branch.
      // With a Branch Admin role Designation is a text field, so Branch is the first String dropdown.
      await _open(tester, find.byType(DropdownButtonFormField<String>).first);
      await tester.tap(find.text('Mumbai').last);
      await _settle(tester);
      await _pickDate(tester);
      await _submit(tester);
      expect(find.text('Required'), findsNothing);
      expect(_server.posts(), hasLength(1));
      final body = _lastBody();
      expect(body['role'], 4);
      expect(body['department'], '');
      expect(body['designation'], 'Branch Manager');
      expect(body['branch'], 'Mumbai');
      expect(_result, isTrue);
    });

    testWidgets('designation can be edited and a cleared one fails with "Required"', (tester) async {
      await _pump(tester, _superuser);
      await _fillCommon(tester);
      await _chooseRole(tester, 'Branch Lead');
      // With a Branch Admin role Designation is a text field, so Branch is the first String dropdown.
      await _open(tester, find.byType(DropdownButtonFormField<String>).first);
      await tester.tap(find.text('Pune').last);
      await _settle(tester);
      await _pickDate(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Branch Manager'), '');
      await _submit(tester);
      expect(_server.posts(), isEmpty);
      expect(find.text('Required'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(4), 'Zonal Head');
      await _submit(tester);
      expect(_lastBody()['designation'], 'Zonal Head');
    });
  });

  group('sheet — validation messages (web)', () {
    testWidgets('empty submit shows "Required" per field and posts nothing', (tester) async {
      await _pump(tester, _superuser);
      await _submit(tester);
      expect(_server.posts(), isEmpty);
      // first, last, email, role, department, designation, branch, joining date
      expect(find.text('Required'), findsNWidgets(8));
    });
  });
}
