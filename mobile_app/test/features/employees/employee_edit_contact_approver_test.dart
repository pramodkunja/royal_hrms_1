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

// Task 34 (gap C-E13): Employee Edit — Login Email, Phone, Date of Joining
// and Reporting Approver, as web employees/[id]/page.tsx (+ _data.ts Personal
// section, lib/reportingManager.ts, ReportingManagerCard.tsx
// EmployeePickerInline) over PUT /employees/<code>/ (EmployeeDetailView.put).
// Also: assigned people are identified by their user id (`uuid`), not the
// display code in `id` — the code can't be sent back as hr_id etc.
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
      return _json({
        'status': 'success',
        'data': [
          {'id': hrUuid, 'employee_id': 'EMP-HR1', 'full_name': 'Asha HR', 'department': 'HR', 'branch': 'Pune'},
        ],
      });
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

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model', () {
    test('assigned people are read by user id (uuid), not their display code', () {
      final m = EmployeeModel.fromJson(employeeJson());
      expect(m.uuid, selfUuid);
      expect([m.hrId, m.hrName], [hrUuid, 'Asha HR']);
      expect([m.reportingManagerId, m.reportingManagerName], [mgrUuid, 'Kiran Manager']);
      expect([m.reportingApproverId, m.reportingApproverName], [apprUuid, 'Arjun Approver']);
    });

    test('nobody assigned (null objects, or missing keys) → null', () {
      final m = EmployeeModel.fromJson({...employeeJson(approver: nobody), 'hr': nobody}..remove('reporting_manager'));
      expect([m.hrId, m.reportingManagerId, m.reportingApproverId, m.reportingApproverName], [null, null, null, null]);
    });

    test('edit form starts from the record: email, phone, date of joining, approver', () {
      final f = EmployeeUpdateFormData.fromModel(EmployeeModel.fromJson(employeeJson()));
      expect([f.email, f.phone, f.dateOfJoining], ['nia.test@example.test', '9000000007', '2026-01-05']);
      expect([f.reportingApproverId, f.reportingApproverName, f.selfUuid], [apprUuid, 'Arjun Approver', selfUuid]);
    });

    test('payload = web onSave for these fields: email || null, phone || "", date_of_joining || null, approver id', () {
      final f = EmployeeUpdateFormData.fromModel(EmployeeModel.fromJson(employeeJson()))..canManageTeam = false;
      final j = f.toJson();
      expect(j['email'], 'nia.test@example.test');
      expect(j['phone'], '9000000007');
      expect(j['date_of_joining'], '2026-01-05');
      expect(j['reporting_approver_id'], apprUuid);
      expect(j['hr_id'], hrUuid);
      expect(j['reporting_manager_id'], mgrUuid);
      f
        ..email = '  '
        ..phone = ''
        ..dateOfJoining = ''
        ..reportingApproverId = null;
      final cleared = f.toJson();
      expect(cleared.containsKey('email'), isTrue);
      expect(cleared['email'], isNull, reason: 'blank → null (backend keeps the login)');
      expect(cleared['phone'], '', reason: 'blank clears the phone');
      expect(cleared['date_of_joining'], isNull);
      expect(cleared.containsKey('reporting_approver_id'), isTrue);
      expect(cleared['reporting_approver_id'], isNull, reason: 'null clears the approver');
      // Existing keys unchanged.
      expect(
          j.keys.toSet(),
          containsAll(<String>[
            'role',
            'department',
            'designation',
            'branch',
            'date_of_birth',
            'gender',
            'marital_status',
            'father_name',
            'blood_group',
            'current_address',
            'permanent_address',
          ]));
    });

    test('validation: login email required + backend format rule; phone backend rule; others unchanged', () {
      EmployeeUpdateFormData f() => EmployeeUpdateFormData.fromModel(EmployeeModel.fromJson(employeeJson()));
      expect(f().validate(), isEmpty);
      expect((f()..email = ' ').validate()['email'], 'Login email is required.');
      for (final bad in ['nia', 'nia@', 'nia@example', '.nia@example.test', 'nia@-example.test']) {
        expect((f()..email = bad).validate()['email'], 'Enter a valid email address.', reason: bad);
      }
      expect((f()..email = 'Nia.Test+hr@sub.example.co.in').validate(), isEmpty);
      for (final bad in ['12345', 'abcdefghij', '9' * 21]) {
        expect((f()..phone = bad).validate()['phone'],
            'Enter a valid mobile number (digits, spaces, +, -, ( ) allowed; 7–20 characters).',
            reason: bad);
      }
      for (final ok in ['', '+91 98765 43210', '(022) 2345-6789', '9876543210']) {
        expect((f()..phone = ok).validate().containsKey('phone'), isFalse, reason: ok);
      }
      expect((f()..branch = '').validate()['branch'], 'Branch is required.');
    });
  });

  group('edit sheet', () {
    testWidgets('fields are editable and pre-filled; the current approver is shown', (tester) async {
      await pumpEdit(tester);
      expect(find.textContaining('Login Email', findRichText: true), findsOneWidget);
      expect(find.text('nia.test@example.test'), findsOneWidget);
      expect(find.text('9000000007'), findsOneWidget);
      expect(find.text('Jan 5, 2026'), findsOneWidget);
      expect(find.text('Reporting Approver', findRichText: true), findsOneWidget);
      expect(approverValue(tester), apprUuid);
      // Non-manager list: ?branch= only.
      final req = server
          .of('GET', ApiConstants.employeesManagerList)
          .where((r) => !r.queryParameters.containsKey('department'))
          .last;
      expect(req.queryParameters, {'branch': 'Pune'});
    });

    testWidgets('editing each field → one PUT with the new values (and user ids, not codes)', (tester) async {
      await pumpEdit(tester);
      await enter(tester, 'edit-employee-email', 'nia.new@example.test');
      await enter(tester, 'edit-employee-phone', '+91 98765 43210');
      await tester.ensureVisible(byKey('edit-employee-doj'));
      await tester.tap(find.descendant(of: byKey('edit-employee-doj'), matching: find.byType(TextFormField)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await pickApprover(tester, 'Bela Approver (EMP-A2 · Finance)');
      await save(tester);
      final body = lastPut();
      expect(body['email'], 'nia.new@example.test');
      expect(body['phone'], '+91 98765 43210');
      expect(body['date_of_joining'], '2026-01-15');
      expect(body['reporting_approver_id'], 'u-a2');
      expect(body['hr_id'], hrUuid, reason: 'stored HR echoed back as its user id');
      expect(body['reporting_manager_id'], mgrUuid);
      expect(sheetResult, isTrue);
    });

    testWidgets('unchanged save keeps every value (no accidental clearing)', (tester) async {
      await pumpEdit(tester);
      await save(tester);
      final body = lastPut();
      expect([body['email'], body['phone'], body['date_of_joining']],
          ['nia.test@example.test', '9000000007', '2026-01-05']);
      expect([body['hr_id'], body['reporting_manager_id'], body['reporting_approver_id']], [hrUuid, mgrUuid, apprUuid]);
    });

    testWidgets('clearing the phone sends "" (clears it)', (tester) async {
      await pumpEdit(tester);
      await enter(tester, 'edit-employee-phone', '');
      await save(tester);
      expect(lastPut()['phone'], '');
    });

    testWidgets('invalid email / phone: shown on the fields, nothing sent', (tester) async {
      await pumpEdit(tester);
      await enter(tester, 'edit-employee-email', 'not-an-email');
      await enter(tester, 'edit-employee-phone', '12');
      await save(tester);
      expect(server.of('PUT', ApiConstants.employeeDetail(code)), isEmpty);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Enter a valid mobile number (digits, spaces, +, -, ( ) allowed; 7–20 characters).'),
          findsOneWidget);
      await enter(tester, 'edit-employee-email', '');
      await save(tester);
      expect(find.text('Login email is required.'), findsOneWidget);
    });

    testWidgets('non-manager: no "None" option (web allowClear only for managers)', (tester) async {
      await pumpEdit(tester);
      await tester.ensureVisible(approverField());
      await tester.tap(approverField());
      await tester.pumpAndSettle();
      expect(find.text('None — no reporting manager'), findsNothing);
      expect(find.text('Bela Approver (EMP-A2 · Finance)'), findsWidgets);
      expect(find.byKey(const Key('edit-employee-manager-note')), findsNothing);
    });

    testWidgets('manager role: ?manager_approvers=1&branch&designation, self excluded, None clears to null',
        (tester) async {
      await pumpEdit(tester,
          employee: employeeJson(role: 'manager', approver: person('EMP-COO', 'u-coo', 'Chitra COO')));
      final req = server.of('GET', ApiConstants.employeesManagerList).last;
      expect(req.queryParameters, {'manager_approvers': '1', 'branch': 'Pune', 'designation': 'QA Analyst'});
      expect(find.byKey(const Key('edit-employee-manager-note')), findsOneWidget);
      await tester.ensureVisible(approverField());
      await tester.tap(approverField());
      await tester.pumpAndSettle();
      expect(find.text('Nia Test (EMP-7 · Manager)'), findsNothing, reason: 'the employee themself is left out');
      expect(find.text('Chitra COO (EMP-COO · COO)'), findsWidgets, reason: 'role shown when the list sends it');
      await tester.tap(find.text('None — no reporting manager').last);
      await tester.pumpAndSettle();
      await save(tester);
      final body = lastPut();
      expect(body.containsKey('reporting_approver_id'), isTrue);
      expect(body['reporting_approver_id'], isNull);
      // Task 36: a Manager's stored reporting manager is now sent back (as web).
      expect(body['reporting_manager_id'], mgrUuid);
    });

    testWidgets('current approver not in the list is still shown and kept', (tester) async {
      final s = Server()..approvers = [];
      await pumpEdit(tester, with_: s, employee: employeeJson(approver: person('EMP-OLD', 'u-old', 'Old Approver')));
      expect(approverValue(tester), 'u-old');
      expect(find.text('Old Approver'), findsWidgets);
      await save(tester);
      expect(lastPut()['reporting_approver_id'], 'u-old');
    });

    testWidgets('no approver and an empty or failed list → "No options available."', (tester) async {
      final s = Server()..approverStatus = 500;
      await pumpEdit(tester, with_: s, employee: employeeJson(approver: nobody));
      expect(find.text('No options available.'), findsWidgets);
      expect(approverValue(tester), isNull);
      await save(tester);
      expect(lastPut()['reporting_approver_id'], isNull);
    });

    testWidgets('while the list loads: "Loading…" and the picker is disabled', (tester) async {
      final s = Server()..holdApprovers = Completer();
      await pumpEdit(tester, with_: s, employee: employeeJson(approver: nobody));
      expect(find.text('Loading…'), findsWidgets);
      expect(tester.widget<DropdownButtonFormField<String>>(approverField()).onChanged, isNull);
      s.holdApprovers!.complete();
      await settle(tester);
      expect(tester.widget<DropdownButtonFormField<String>>(approverField()).onChanged, isNotNull);
    });

    testWidgets('changing the branch re-fetches the approvers for it but keeps the chosen approver (as web)',
        (tester) async {
      await pumpEdit(tester);
      final branchField =
          find.ancestor(of: find.text('Pune'), matching: find.byType(DropdownButtonFormField<String>)).first;
      await tester.ensureVisible(branchField);
      await tester.tap(branchField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mumbai').last);
      await settle(tester);
      expect(server.of('GET', ApiConstants.employeesManagerList).map((r) => r.queryParameters['branch']),
          contains('Mumbai'));
      await save(tester);
      final body = lastPut();
      expect(body['branch'], 'Mumbai');
      expect(body['reporting_approver_id'], apprUuid);
      // Task 51: web keeps the Branch HR on a branch change (sending null
      // removed the HR on save).
      expect(body['hr_id'], hrUuid);
    });

    testWidgets('server refuses (e.g. email in use): message shown, sheet stays, retry after a fix succeeds',
        (tester) async {
      final s = Server()..putStatus = 400;
      await pumpEdit(tester, with_: s);
      await enter(tester, 'edit-employee-email', 'taken@example.test');
      await save(tester);
      expect(find.text('Another account already uses this email address.'), findsOneWidget);
      expect(sheetResult, isNull);
      s.putStatus = 200;
      await enter(tester, 'edit-employee-email', 'free@example.test');
      await save(tester);
      expect(s.of('PUT', ApiConstants.employeeDetail(code)), hasLength(2));
      expect(lastPut()['email'], 'free@example.test');
      expect(sheetResult, isTrue);
    });
  });
}
