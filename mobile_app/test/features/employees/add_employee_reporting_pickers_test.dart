import 'dart:async';
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

// Task 33 (gap C-E05): Add Employee "Assign HR" and "Reporting Manager", as
// web employees/_components/AddEmployeeModal.tsx — HR from
// GET /employees/hrs/?branch=, managers from GET /employees/managers/?branch=
// (&department= once chosen); both optional ("— Auto-assign —"), disabled
// until a branch is chosen and while loading; cleared when the branch (both)
// or department (manager) changes; POST /employees/ carries hr_id /
// reporting_manager_id only when chosen. Synthetic data on a stand-in server;
// nobody is really created.

class Server implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  Map<String, List<Map<String, dynamic>>> hrsByBranch = {
    'Pune': [
      {'id': 'u-hr-1', 'employee_id': 'EMP-101', 'full_name': 'Asha HR', 'department': 'HR', 'branch': 'Pune'},
      {'id': 'u-hr-2', 'employee_id': '', 'full_name': 'Ravi HR', 'department': 'HR', 'branch': 'Pune'},
    ],
    'Mumbai': [
      {'id': 'u-hr-9', 'employee_id': 'EMP-901', 'full_name': 'Meera HR', 'department': 'HR', 'branch': 'Mumbai'},
    ],
  };
  List<Map<String, dynamic>>? managersOverride;
  List<Map<String, dynamic>> managersFor(String branch, String? dept) =>
      managersOverride ??
      [
        if (branch == 'Pune' && (dept == null || dept == 'Quality'))
          {
            'id': 'u-mgr-1',
            'employee_id': 'EMP-201',
            'full_name': 'Kiran Manager',
            'department': 'Quality',
            'branch': 'Pune'
          },
        if (branch == 'Pune' && (dept == null || dept == 'Finance'))
          {
            'id': 'u-mgr-2',
            'employee_id': 'EMP-202',
            'full_name': 'Neha Manager',
            'department': 'Finance',
            'branch': 'Pune'
          },
      ];
  int hrStatus = 200;
  int managerStatus = 200;
  int createStatus = 201;
  Map<String, dynamic> createError = {
    'status': 'error',
    'message': 'HR user not found or is inactive.',
    'data': {'hr_id': 'Invalid HR selected.'},
  };
  Completer<void>? holdPeople;

  List<RequestOptions> of(String method, String path) =>
      calls.where((c) => c.method == method && c.path == path).toList();

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add(o);
    if (o.path == ApiConstants.employeesHrList || o.path == ApiConstants.employeesManagerList) {
      final gate = holdPeople;
      if (gate != null) await gate.future;
    }
    if (o.path == ApiConstants.employeesHrList) {
      if (hrStatus != 200) return _json({'status': 'error', 'message': 'Nope', 'data': {}}, hrStatus);
      return _json({'status': 'success', 'data': hrsByBranch[o.queryParameters['branch']] ?? []});
    }
    if (o.path == ApiConstants.employeesManagerList) {
      if (managerStatus != 200) return _json({'status': 'error', 'message': 'Nope', 'data': {}}, managerStatus);
      return _json({
        'status': 'success',
        'data': managersFor(o.queryParameters['branch'] as String, o.queryParameters['department'] as String?),
      });
    }
    if (o.path == ApiConstants.employees && o.method == 'POST') {
      if (createStatus >= 400) return _json(createError, createStatus);
      final body = o.data as Map<String, dynamic>;
      return _json({
        'status': 'success',
        'message': 'Employee added successfully.',
        'data': {
          'id': 'u-new',
          'employee_id': 'EMP-NEW',
          'first_name': body['first_name'],
          'last_name': body['last_name'],
          'full_name': '${body['first_name']} ${body['last_name']}',
          'email': body['email'],
          'department': body['department'],
          'designation': body['designation'],
          'branch': body['branch'],
          'role': 'employee',
          'is_active': true,
          'status': 'active',
        },
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

UserEntity user({required String role, required String branch}) => UserEntity(
      id: 'me',
      email: 'me@example.test',
      fullName: 'Test User',
      role: role,
      roleDisplay: role,
      branch: branch,
      mustChangePassword: false,
      permissions: const ['employees.view', 'employees.create'],
      isSuperuser: role == 'system_admin',
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final admin = user(role: 'system_admin', branch: '');
final branchHr = user(role: 'hr_admin', branch: 'Pune');

late Server server;
bool? sheetResult;

Future<void> pumpSheet(WidgetTester tester, {UserEntity? as, Server? with_}) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  sheetResult = null;
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? admin)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      employeeFormRolesProvider.overrideWithValue(AsyncData([
        RoleModel.fromJson(const {'id': 3, 'name': 'employee', 'display_name': 'Employee', 'permissions': []}),
      ])),
      employeeFormDepartmentsProvider.overrideWithValue(AsyncData([
        DepartmentModel.fromJson(const {'id': 1, 'name': 'Quality'}),
        DepartmentModel.fromJson(const {'id': 2, 'name': 'Finance'}),
      ])),
      employeeBranchesProvider.overrideWith((ref) async => const [
            EmployeeBranch(id: 1, name: 'Pune'),
            EmployeeBranch(id: 2, name: 'Mumbai'),
          ]),
      employeeDesignationsByDeptProvider.overrideWith((ref, id) async => id == 1 ? ['QA Analyst'] : ['Accountant']),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async => sheetResult = await AddEmployeeSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await settle(tester);
}

/// Lets the stand-in server answer, then settles.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
}

Finder hrPicker() => find.byKey(const Key('add-employee-hr'));
Finder managerPicker() => find.byKey(const Key('add-employee-manager'));

DropdownButtonFormField<String?> dropdown(WidgetTester tester, Finder picker) =>
    tester.widget<DropdownButtonFormField<String?>>(
        find.descendant(of: picker, matching: find.byType(DropdownButtonFormField<String?>)));

bool isEnabled(WidgetTester tester, Finder picker) => dropdown(tester, picker).onChanged != null;

String? shownValue(WidgetTester tester, Finder picker) {
  final state = tester.state<FormFieldState<String?>>(
      find.descendant(of: picker, matching: find.byType(DropdownButtonFormField<String?>)));
  return state.value;
}

/// What the closed picker shows (the hint/placeholder or the chosen option).
bool shows(Finder picker, String text) => find.descendant(of: picker, matching: find.text(text)).evaluate().isNotEmpty;

Future<void> choose(WidgetTester tester, Finder dropdownFinder, String option) async {
  await tester.ensureVisible(dropdownFinder);
  await tester.tap(dropdownFinder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await settle(tester);
}

Future<void> chooseBranch(WidgetTester tester, String branch) =>
    choose(tester, find.byType(DropdownButtonFormField<String>).at(1), branch);

Future<void> chooseDepartment(WidgetTester tester, String dept) =>
    choose(tester, find.byType(DropdownButtonFormField<DepartmentModel>), dept);

/// Fills every required field except branch/department choices made by the test.
Future<void> fillRequired(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Nia');
  await tester.enterText(fields.at(1), 'Test');
  await tester.enterText(fields.at(2), 'nia.test@example.test');
  await choose(tester, find.byType(DropdownButtonFormField<dynamic>), 'Employee');
  await tester.ensureVisible(find.text('dd/mm/yyyy'));
  await tester.tap(find.text('dd/mm/yyyy'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Add Employee'));
  await tester.tap(find.text('Add Employee'));
  await settle(tester);
}

Map<String, dynamic> lastCreateBody() => server.of('POST', ApiConstants.employees).last.data as Map<String, dynamic>;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model payload (web submit)', () {
    test('hr_id / reporting_manager_id only when chosen; every other field unchanged', () {
      final f = EmployeeFormData(
        firstName: 'Nia',
        lastName: 'Test',
        email: 'Nia@Example.test',
        roleId: 3,
        department: 'Quality',
        designation: 'QA Analyst',
        branch: 'Pune',
        dateOfJoining: '2026-11-10',
      );
      final base = {
        'first_name': 'Nia',
        'last_name': 'Test',
        'email': 'nia@example.test',
        'role': 3,
        'department': 'Quality',
        'designation': 'QA Analyst',
        'branch': 'Pune',
        'employee_type': 'Permanent',
        'date_of_joining': '2026-11-10',
      };
      expect(f.toJson(), base);
      f
        ..hrId = 'u-hr-1'
        ..reportingManagerId = 'u-mgr-1';
      expect(f.toJson(), {...base, 'hr_id': 'u-hr-1', 'reporting_manager_id': 'u-mgr-1'});
      f
        ..hrId = ''
        ..reportingManagerId = null;
      expect(f.toJson(), base);
    });
  });

  group('pickers', () {
    testWidgets('before a branch: both shown, disabled, "Select branch first"; nothing fetched', (tester) async {
      await pumpSheet(tester);
      expect(find.text('Assign HR', findRichText: true), findsOneWidget);
      expect(find.text('Reporting Manager', findRichText: true), findsOneWidget);
      for (final p in [hrPicker(), managerPicker()]) {
        expect(isEnabled(tester, p), isFalse);
        expect(shows(p, 'Select branch first'), isTrue);
      }
      expect(server.of('GET', ApiConstants.employeesHrList), isEmpty);
      expect(server.of('GET', ApiConstants.employeesManagerList), isEmpty);
    });

    testWidgets('branch chosen: HR ?branch=, managers ?branch= (no department yet); "Name (EMP)" options',
        (tester) async {
      await pumpSheet(tester);
      await chooseBranch(tester, 'Pune');
      final hr = server.of('GET', ApiConstants.employeesHrList).single;
      expect(hr.queryParameters, {'branch': 'Pune'});
      final mgr = server.of('GET', ApiConstants.employeesManagerList).single;
      expect(mgr.queryParameters, {'branch': 'Pune'});
      expect(isEnabled(tester, hrPicker()), isTrue);
      expect(isEnabled(tester, managerPicker()), isTrue);
      expect(shows(hrPicker(), '— Auto-assign —'), isTrue);
      expect(shows(managerPicker(), '— Auto-assign —'), isTrue);

      await tester.tap(find.descendant(of: hrPicker(), matching: find.byType(DropdownButtonFormField<String?>)));
      await tester.pumpAndSettle();
      expect(find.text('Asha HR (EMP-101)'), findsWidgets);
      expect(find.text('Ravi HR'), findsWidgets, reason: 'no code → name only');
      await tester.tap(find.text('Asha HR (EMP-101)').last);
      await tester.pumpAndSettle();
      expect(shownValue(tester, hrPicker()), 'u-hr-1');
    });

    testWidgets('department chosen: managers re-fetched with ?department=', (tester) async {
      await pumpSheet(tester);
      await chooseBranch(tester, 'Pune');
      await chooseDepartment(tester, 'Finance');
      final last = server.of('GET', ApiConstants.employeesManagerList).last;
      expect(last.queryParameters, {'branch': 'Pune', 'department': 'Finance'});
      await tester.tap(find.descendant(of: managerPicker(), matching: find.byType(DropdownButtonFormField<String?>)));
      await tester.pumpAndSettle();
      expect(find.text('Neha Manager (EMP-202)'), findsWidgets);
      expect(find.text('Kiran Manager (EMP-201)'), findsNothing, reason: 'other department filtered out');
    });

    testWidgets('while loading: both disabled with "Loading…"', (tester) async {
      final s = Server()..holdPeople = Completer();
      await pumpSheet(tester, with_: s);
      await chooseBranch(tester, 'Pune');
      for (final p in [hrPicker(), managerPicker()]) {
        expect(isEnabled(tester, p), isFalse);
        expect(shows(p, 'Loading…'), isTrue);
      }
      s.holdPeople!.complete();
      await settle(tester);
      expect(isEnabled(tester, hrPicker()), isTrue);
    });

    testWidgets('empty or failed lists: "No HR found for this branch" / "No managers found for this branch"',
        (tester) async {
      final s = Server()
        ..hrStatus = 500
        ..managerStatus = 403;
      await pumpSheet(tester, with_: s);
      await chooseBranch(tester, 'Pune');
      expect(shows(hrPicker(), 'No HR found for this branch'), isTrue);
      expect(shows(managerPicker(), 'No managers found for this branch'), isTrue);
      // A branch with no managers (and HR loading fine) — still optional, form usable.
      s.hrStatus = 200;
      s.managerStatus = 200;
      await chooseBranch(tester, 'Mumbai');
      expect(shows(hrPicker(), '— Auto-assign —'), isTrue);
      expect(shows(managerPicker(), 'No managers found for this branch'), isTrue);
    });

    testWidgets('changing the branch clears both choices; changing the department clears the manager only',
        (tester) async {
      await pumpSheet(tester);
      await chooseBranch(tester, 'Pune');
      await choose(tester, find.descendant(of: hrPicker(), matching: find.byType(DropdownButtonFormField<String?>)),
          'Asha HR (EMP-101)');
      await chooseDepartment(tester, 'Quality');
      await choose(
          tester,
          find.descendant(of: managerPicker(), matching: find.byType(DropdownButtonFormField<String?>)),
          'Kiran Manager (EMP-201)');
      expect(shownValue(tester, hrPicker()), 'u-hr-1');
      expect(shownValue(tester, managerPicker()), 'u-mgr-1');

      await chooseDepartment(tester, 'Finance');
      expect(shownValue(tester, managerPicker()), isNull);
      expect(shownValue(tester, hrPicker()), 'u-hr-1', reason: 'HR is per branch, not department');

      await choose(
          tester,
          find.descendant(of: managerPicker(), matching: find.byType(DropdownButtonFormField<String?>)),
          'Neha Manager (EMP-202)');
      await chooseBranch(tester, 'Mumbai');
      expect(shownValue(tester, hrPicker()), isNull);
      expect(shownValue(tester, managerPicker()), isNull);
    });

    testWidgets('choosing "— Auto-assign —" clears a selection', (tester) async {
      await pumpSheet(tester);
      await chooseBranch(tester, 'Pune');
      final hrField = find.descendant(of: hrPicker(), matching: find.byType(DropdownButtonFormField<String?>));
      await choose(tester, hrField, 'Asha HR (EMP-101)');
      await choose(tester, hrField, '— Auto-assign —');
      expect(shownValue(tester, hrPicker()), isNull);
    });

    testWidgets('branch-restricted user: own branch pre-filled and locked, so both lists load at once', (tester) async {
      await pumpSheet(tester, as: branchHr);
      expect(server.of('GET', ApiConstants.employeesHrList).single.queryParameters, {'branch': 'Pune'});
      expect(isEnabled(tester, hrPicker()), isTrue);
      expect(isEnabled(tester, managerPicker()), isTrue);
    });
  });

  group('submit', () {
    testWidgets('chosen HR and manager → POST /employees/ with hr_id and reporting_manager_id', (tester) async {
      await pumpSheet(tester);
      await fillRequired(tester);
      await chooseDepartment(tester, 'Quality');
      await choose(tester, find.byType(DropdownButtonFormField<String>).first, 'QA Analyst');
      await chooseBranch(tester, 'Pune');
      await choose(
          tester, find.descendant(of: hrPicker(), matching: find.byType(DropdownButtonFormField<String?>)), 'Ravi HR');
      await choose(
          tester,
          find.descendant(of: managerPicker(), matching: find.byType(DropdownButtonFormField<String?>)),
          'Kiran Manager (EMP-201)');
      await submit(tester);
      final body = lastCreateBody();
      expect(body['hr_id'], 'u-hr-2');
      expect(body['reporting_manager_id'], 'u-mgr-1');
      expect(body['branch'], 'Pune');
      expect(body['department'], 'Quality');
      expect(body['email'], 'nia.test@example.test');
      expect(sheetResult, isTrue, reason: 'sheet closed as created');
    });

    testWidgets('UUID regression: hr_id / reporting_manager_id are the people\'s user UUIDs, never their codes',
        (tester) async {
      // Real list shape (accounts/views.py HRListView / ManagerListView):
      // {'id': str(user.id) — a UUID, 'employee_id': display code, ...}.
      const hrUuid = '5f0c7d2e-1b8a-4c3e-9a77-0d2f4e6a8b10';
      const mgrUuid = '9e3a1c44-7d2b-4f60-8c11-2b5d7e9f0a32';
      final s = Server()
        ..managersOverride = [
          {
            'id': mgrUuid,
            'employee_id': 'RSS000201',
            'full_name': 'Kiran Manager',
            'department': 'Quality',
            'branch': 'Pune'
          },
        ]
        ..hrsByBranch = {
          'Pune': [
            {'id': hrUuid, 'employee_id': 'RSS000183', 'full_name': 'Asha HR', 'department': 'HR', 'branch': 'Pune'},
          ],
        };
      await pumpSheet(tester, with_: s);
      await fillRequired(tester);
      await chooseDepartment(tester, 'Quality');
      await choose(tester, find.byType(DropdownButtonFormField<String>).first, 'QA Analyst');
      await chooseBranch(tester, 'Pune');
      await choose(tester, find.descendant(of: hrPicker(), matching: find.byType(DropdownButtonFormField<String?>)),
          'Asha HR (RSS000183)');
      await choose(
          tester,
          find.descendant(of: managerPicker(), matching: find.byType(DropdownButtonFormField<String?>)),
          'Kiran Manager (RSS000201)');
      await submit(tester);
      final body = lastCreateBody();
      expect(body['hr_id'], hrUuid);
      expect(body['hr_id'], isNot('RSS000183'));
      expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(body['hr_id'] as String), isTrue);
      expect(body['reporting_manager_id'], mgrUuid);
      expect(body['reporting_manager_id'], isNot('RSS000201'));
    });

    testWidgets('nothing chosen (auto-assign) → neither key is sent', (tester) async {
      await pumpSheet(tester);
      await fillRequired(tester);
      await chooseDepartment(tester, 'Quality');
      await choose(tester, find.byType(DropdownButtonFormField<String>).first, 'QA Analyst');
      await chooseBranch(tester, 'Pune');
      await submit(tester);
      final body = lastCreateBody();
      expect(body.containsKey('hr_id'), isFalse);
      expect(body.containsKey('reporting_manager_id'), isFalse);
      expect(body.keys.toSet(), {
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

    testWidgets('a choice made under the previous branch is not submitted after a branch change', (tester) async {
      await pumpSheet(tester);
      await fillRequired(tester);
      await chooseDepartment(tester, 'Quality');
      await choose(tester, find.byType(DropdownButtonFormField<String>).first, 'QA Analyst');
      await chooseBranch(tester, 'Pune');
      await choose(tester, find.descendant(of: hrPicker(), matching: find.byType(DropdownButtonFormField<String?>)),
          'Asha HR (EMP-101)');
      await choose(
          tester,
          find.descendant(of: managerPicker(), matching: find.byType(DropdownButtonFormField<String?>)),
          'Kiran Manager (EMP-201)');
      await chooseBranch(tester, 'Mumbai');
      await submit(tester);
      final body = lastCreateBody();
      expect(body['branch'], 'Mumbai');
      expect(body.containsKey('hr_id'), isFalse);
      expect(body.containsKey('reporting_manager_id'), isFalse);
    });

    testWidgets('a manager chosen for the previous department is not submitted after a department change',
        (tester) async {
      await pumpSheet(tester);
      await fillRequired(tester);
      await chooseBranch(tester, 'Pune');
      await chooseDepartment(tester, 'Quality');
      await choose(
          tester,
          find.descendant(of: managerPicker(), matching: find.byType(DropdownButtonFormField<String?>)),
          'Kiran Manager (EMP-201)');
      await chooseDepartment(tester, 'Finance');
      await choose(tester, find.byType(DropdownButtonFormField<String>).first, 'Accountant');
      await submit(tester);
      expect(lastCreateBody().containsKey('reporting_manager_id'), isFalse);
    });

    testWidgets('server rejects the HR choice → its message is shown and the sheet stays open', (tester) async {
      final s = Server()..createStatus = 400;
      await pumpSheet(tester, with_: s);
      await fillRequired(tester);
      await chooseDepartment(tester, 'Quality');
      await choose(tester, find.byType(DropdownButtonFormField<String>).first, 'QA Analyst');
      await chooseBranch(tester, 'Pune');
      await choose(tester, find.descendant(of: hrPicker(), matching: find.byType(DropdownButtonFormField<String?>)),
          'Asha HR (EMP-101)');
      await submit(tester);
      expect(s.of('POST', ApiConstants.employees), hasLength(1));
      expect(find.textContaining('HR user not found or is inactive.'), findsOneWidget);
      expect(sheetResult, isNull, reason: 'still open');
      expect(shownValue(tester, hrPicker()), 'u-hr-1', reason: 'choice kept for a retry');
    });

    testWidgets('pickers are optional: required-field validation is unchanged', (tester) async {
      await pumpSheet(tester);
      await submit(tester);
      expect(server.of('POST', ApiConstants.employees), isEmpty);
      expect(find.text('Branch is required.'), findsOneWidget);
      expect(find.text('Assign HR is required.'), findsNothing);
    });
  });
}
