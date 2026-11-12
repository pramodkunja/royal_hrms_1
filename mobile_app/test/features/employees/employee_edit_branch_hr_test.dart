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
import 'package:mobile_app/features/employees/data/datasources/employees_remote_datasource.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:mobile_app/features/employees/presentation/widgets/add_employee_sheet.dart';
import 'package:mobile_app/features/settings/data/models/departments_model.dart';
import 'package:mobile_app/features/settings/data/models/roles_model.dart';

// Task 51: Employee Edit → Branch HR, as web employees/[id]/page.tsx "Branch
// HR" (EmployeePickerInline over GET /employees/hrs/?branch=<branch>;
// HRListView returns [{id: <user uuid>, employee_id, full_name, department,
// branch}], requires the branch, 403 without employees.view) and the save
// (PUT hr_id = uuid; null REMOVES the HR server-side). Root cause on device:
// the dropdown's initial value was computed before the list loaded and never
// updated, so the assigned HR showed as "— None —"; a failed load looked like
// an empty list; a branch change cleared the HR (web keeps it).
// Synthetic data on a stand-in server; nothing real is changed.

const code = 'EMP-7';
const selfUuid = '11111111-0000-0000-0000-000000000007';
const hrUuid = '22222222-0000-0000-0000-000000000001';
const mgrUuid = '33333333-0000-0000-0000-000000000001';
const apprUuid = '44444444-0000-0000-0000-000000000001';

Map<String, dynamic> person(String code, String uuid, String name) => {'id': code, 'uuid': uuid, 'name': name};
const nobody = {'id': null, 'uuid': null, 'name': null};

Map<String, dynamic> employeeJson({
  String role = 'employee',
  Map<String, dynamic>? approver,
  String phone = '9000000007',
  String doj = '2026-01-05',
}) =>
    {
      'id': code,
      'uuid': selfUuid,
      'employee_id': code,
      'first_name': 'Nia',
      'last_name': 'Test',
      'full_name': 'Nia Test',
      'email': 'nia.test@example.test',
      'phone': phone,
      'department': 'Quality',
      'designation': 'QA Analyst',
      'branch': 'Pune',
      'role': role,
      'role_display': role,
      'date_of_joining': doj,
      'is_active': true,
      'status': 'active',
      'hr': person('EMP-HR1', hrUuid, 'Asha HR'),
      'reporting_manager': person('EMP-M1', mgrUuid, 'Kiran Manager'),
      'reporting_approver': approver ?? person('EMP-A1', apprUuid, 'Arjun Approver'),
      'profile': {
        'date_of_birth': '1995-02-01',
        'gender': 'female',
        'marital_status': 'single',
      },
      'documents': <Object>[],
    };

class Server implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  List<Map<String, dynamic>> approvers = [
    {'id': apprUuid, 'employee_id': 'EMP-A1', 'full_name': 'Arjun Approver', 'department': 'Ops', 'branch': 'Pune'},
    {'id': 'u-a2', 'employee_id': 'EMP-A2', 'full_name': 'Bela Approver', 'department': 'Finance', 'branch': 'Pune'},
  ];
  List<Map<String, dynamic>> managerApprovers = [
    {
      'id': selfUuid,
      'employee_id': code,
      'full_name': 'Nia Test',
      'department': 'Quality',
      'branch': 'Pune',
      'role': 'Manager'
    },
    {
      'id': 'u-coo',
      'employee_id': 'EMP-COO',
      'full_name': 'Chitra COO',
      'department': 'Exec',
      'branch': 'HQ',
      'role': 'COO'
    },
  ];
  Map<String, List<Map<String, dynamic>>> hrsByBranch = {
    'Pune': [
      {'id': hrUuid, 'employee_id': 'EMP-HR1', 'full_name': 'Asha HR', 'department': 'HR', 'branch': 'Pune'},
      {'id': 'u-hr2', 'employee_id': 'EMP-HR2', 'full_name': 'Bina HR', 'department': 'People', 'branch': 'Pune'},
    ],
    'Mumbai': [
      {'id': 'u-hr3', 'employee_id': 'EMP-HR3', 'full_name': 'Chetan HR', 'department': 'HR', 'branch': 'Mumbai'},
    ],
  };
  final hrRequests = <String>[];
  final hrStatus = <String, int>{};
  final holdHrs = <String, Completer<void>>{};
  int approverStatus = 200;
  int putStatus = 200;
  String putMessage = 'Another account already uses this email address.';
  Completer<void>? holdApprovers;

  List<RequestOptions> of(String method, String path) =>
      calls.where((c) => c.method == method && c.path == path).toList();

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add(o);
    if (o.path == ApiConstants.employeesManagerList) {
      final gate = holdApprovers;
      if (gate != null) await gate.future;
      if (approverStatus != 200) return _json({'status': 'error', 'message': 'Nope', 'data': {}}, approverStatus);
      final isManagerList = o.queryParameters['manager_approvers'] == '1';
      return _json({'status': 'success', 'data': isManagerList ? managerApprovers : approvers});
    }
    if (o.path == ApiConstants.employeesHrList) {
      final branch = '${o.queryParameters['branch'] ?? ''}';
      hrRequests.add(branch);
      final gate = holdHrs[branch];
      if (gate != null) await gate.future;
      final st = hrStatus[branch];
      if (st != null) {
        hrStatus.remove(branch); // fails once
        return _json({
          'status': 'error',
          'message': st == 403 ? 'You do not have permission to perform this action.' : 'Server error.',
          'data': {}
        }, st);
      }
      if (branch.isEmpty) {
        return _json({'status': 'error', 'message': 'branch query parameter is required.', 'data': {}}, 400);
      }
      return _json({'status': 'success', 'data': hrsByBranch[branch] ?? []});
    }
    if (o.path == ApiConstants.employeeDetail(code) && o.method == 'PUT') {
      if (putStatus != 200) return _json({'status': 'error', 'message': putMessage, 'data': {}}, putStatus);
      return _json({'status': 'success', 'message': 'Employee updated successfully.', 'data': employeeJson()});
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
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'hr1',
          email: 'hr@example.test',
          fullName: 'Test HR',
          role: 'hr_admin',
          roleDisplay: 'HR',
          branch: 'Pune',
          mustChangePassword: false,
          permissions: ['employees.view', 'employees.edit'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

late Server server;
bool? sheetResult;

Future<void> pumpEdit(WidgetTester tester, {Map<String, dynamic>? employee, Server? with_}) async {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  sheetResult = null;
  final model = EmployeeModel.fromJson(employee ?? employeeJson());
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      employeeFormRolesProvider.overrideWithValue(AsyncData([
        RoleModel.fromJson(const {'id': 3, 'name': 'employee', 'display_name': 'Employee', 'permissions': []}),
        RoleModel.fromJson(const {
          'id': 4,
          'name': 'manager',
          'display_name': 'Manager',
          'permissions': [],
          'can_manage_team': true,
        }),
      ])),
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
              onPressed: () async => sheetResult = await AddEmployeeSheet.show(context, editing: model),
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

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));
Finder approverField() =>
    find.descendant(of: byKey('edit-employee-approver'), matching: find.byType(DropdownButtonFormField<String>));

String? approverValue(WidgetTester tester) => tester.state<FormFieldState<String>>(approverField()).value;

Future<void> pickApprover(WidgetTester tester, String option) async {
  await tester.ensureVisible(approverField());
  await tester.tap(approverField());
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save Changes'));
  await tester.tap(find.text('Save Changes'));
  await settle(tester);
}

Map<String, dynamic> lastPut() => server.of('PUT', ApiConstants.employeeDetail(code)).last.data as Map<String, dynamic>;

Future<void> enter(WidgetTester tester, String key, String text) async {
  final field = find.descendant(of: byKey(key), matching: find.byType(TextFormField));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Finder hrField() =>
    find.byWidgetPredicate((w) => w is DropdownButtonFormField<String> && '${w.key}'.contains('edit-hr-'));
String? hrValue(WidgetTester tester) => tester.state<FormFieldState<String>>(hrField()).value;
List<String> hrItems(WidgetTester tester) => tester
    .widget<DropdownButton<String>>(find.descendant(of: hrField(), matching: find.byType(DropdownButton<String>)))
    .items!
    .map((i) => (i.child as Text).data!)
    .toList();

Future<void> pickBranch(WidgetTester tester, String from, String to, {bool settleAfter = true}) async {
  final f = find.ancestor(of: find.text(from), matching: find.byType(DropdownButtonFormField<String>)).first;
  await tester.ensureVisible(f);
  await tester.tap(f);
  // Not pumpAndSettle: an HR list may be loading (its bar never settles).
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.text(to).last);
  if (settleAfter) {
    await settle(tester);
  } else {
    // The list for the new branch is held: let the menu close without
    // waiting for it (the loading bar never settles).
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

Future<void> pickHr(WidgetTester tester, String option) async {
  await tester.ensureVisible(hrField());
  await tester.tap(hrField());
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('0. the HR list is requested with the branch and read by user uuid; a branch is required', () async {
    final s = Server();
    final ds = EmployeesRemoteDataSource(Dio(BaseOptions(baseUrl: 'https://t.invalid'))..httpClientAdapter = s);
    final list = await ds.fetchHrs('Pune');
    expect(s.hrRequests, ['Pune']);
    expect(list.map((o) => (o.id, o.employeeId, o.fullName)),
        [(hrUuid, 'EMP-HR1', 'Asha HR'), ('u-hr2', 'EMP-HR2', 'Bina HR')]);
    await expectLater(ds.fetchHrs(''), throwsA(isA<DioException>()), reason: 'the API refuses a missing branch');
  });

  testWidgets('9. no branch: nothing requested (the API requires one), explained', (tester) async {
    await pumpEdit(tester, employee: {...employeeJson(), 'branch': ''});
    expect(server.hrRequests, isEmpty);
    expect(byKey('edit-hr-no-branch'), findsOneWidget);
    expect(find.text('Asha HR'), findsOneWidget, reason: 'the stored HR is still shown');
  });

  testWidgets('1. the assigned HR is shown once the branch list loads (was "— None —")', (tester) async {
    await pumpEdit(tester);
    expect(find.text('Branch HR', findRichText: true), findsOneWidget);
    expect(server.hrRequests, ['Pune']);
    expect(hrValue(tester), hrUuid);
    expect(hrItems(tester), ['Asha HR (HR)', 'Bina HR (People)']);
    expect(hrItems(tester).where((i) => i.contains('None')), isEmpty, reason: 'web has no "clear HR" option');
    await save(tester);
    expect(lastPut()['hr_id'], hrUuid, reason: 'untouched: the stored uuid is sent back');
  });

  testWidgets('2. an HR who is not in this branch\'s list stays shown and is kept on save', (tester) async {
    final s = Server()..hrsByBranch['Pune'] = [server0Hr('u-hr2', 'Bina HR')];
    await pumpEdit(tester, with_: s);
    expect(hrValue(tester), hrUuid);
    expect(hrItems(tester).first, 'Asha HR');
    await save(tester);
    expect(lastPut()['hr_id'], hrUuid);
  });

  testWidgets('3. picking another HR saves that user\'s uuid (not the code)', (tester) async {
    await pumpEdit(tester);
    await pickHr(tester, 'Bina HR (People)');
    await save(tester);
    expect(lastPut()['hr_id'], 'u-hr2');
  });

  testWidgets('4. branch change: list re-fetched for the new branch, the current HR kept (as web)', (tester) async {
    await pumpEdit(tester);
    await pickBranch(tester, 'Pune', 'Mumbai');
    expect(server.hrRequests.last, 'Mumbai');
    expect(hrValue(tester), hrUuid);
    expect(hrItems(tester), ['Asha HR', 'Chetan HR (HR)']);
    await save(tester);
    expect(lastPut()['branch'], 'Mumbai');
    expect(lastPut()['hr_id'], hrUuid);
  });

  testWidgets('5. empty list: "No options available.", the current HR still shown', (tester) async {
    final s = Server()..hrsByBranch['Pune'] = [];
    await pumpEdit(tester, with_: s);
    expect(byKey('edit-hr-empty'), findsOneWidget);
    expect(find.text('No options available.'), findsOneWidget);
    expect(hrValue(tester), hrUuid);
  });

  testWidgets('6. 403 and 500 are shown (not an empty list); Retry reloads', (tester) async {
    for (final st in [403, 500]) {
      final s = Server()..hrStatus['Pune'] = st;
      await pumpEdit(tester, with_: s);
      expect(byKey('edit-hr-error'), findsOneWidget, reason: '$st');
      expect(find.text(st == 403 ? 'You do not have permission to perform this action.' : 'Server error.'),
          findsOneWidget);
      expect(byKey('edit-hr-empty'), findsNothing);
      await tester.tap(byKey('edit-hr-retry'));
      await settle(tester);
      expect(s.hrRequests, ['Pune', 'Pune']);
      expect(hrValue(tester), hrUuid);
    }
  });

  testWidgets('7. rapid switching: a late answer for a branch no longer selected changes nothing', (tester) async {
    final s = Server();
    await pumpEdit(tester, with_: s);
    final gate = s.holdHrs['Mumbai'] = Completer<void>();
    await pickBranch(tester, 'Pune', 'Mumbai', settleAfter: false);
    await tester.pump();
    expect(byKey('edit-hr-loading'), findsOneWidget);
    await pickBranch(tester, 'Mumbai', 'Pune');
    gate.complete();
    await settle(tester);
    expect(hrItems(tester), ['Asha HR (HR)', 'Bina HR (People)'], reason: 'Pune list, not the late Mumbai one');
    expect(hrValue(tester), hrUuid);
  });

  testWidgets('8. no HR yet: the branch\'s sole HR is filled in (web); two HRs → left empty', (tester) async {
    final one = Server()..hrsByBranch['Pune'] = [server0Hr('u-solo', 'Solo HR')];
    await pumpEdit(tester, employee: {...employeeJson(), 'hr': nobody}, with_: one);
    expect(hrValue(tester), 'u-solo');
    await save(tester);
    expect(lastPut()['hr_id'], 'u-solo');

    await pumpEdit(tester, employee: {...employeeJson(), 'hr': nobody});
    expect(hrValue(tester), isNull);
    await save(tester);
    expect(lastPut()['hr_id'], isNull);
  });

}

Map<String, dynamic> server0Hr(String id, String name) =>
    {'id': id, 'employee_id': 'EMP-$id', 'full_name': name, 'department': 'HR', 'branch': 'Pune'};
