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

// Task 98 P1: Employee Edit with Settings -> Onboarding Fields hiding built-in
// personal fields. Web employees/[id]/page.tsx: applyFieldConfig hides them,
// onSave has no client-side validation and always PUTs the loaded values
// (hidden ones included, unchanged); backend EmployeeDetailView.put skips an
// empty date_of_birth. Synthetic data on a stand-in server.

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
  Map<String, dynamic>? profile,
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
      'profile': profile ??
          {
            'date_of_birth': '1995-02-01',
            'gender': 'female',
            'marital_status': 'single',
            'father_name': 'Test Father',
            'blood_group': 'O+',
            'current_address': '1 Test Road',
            'permanent_address': '2 Test Lane',
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
  Object? fieldConfig;
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
    if (o.path == ApiConstants.onboardingFieldConfig) {
      final c = fieldConfig;
      return c == null ? _json({'status': 'error', 'message': 'x'}, 500) : _json({'status': 'success', 'data': c});
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

Future<void> pumpEdit(WidgetTester tester, {Map<String, dynamic>? employee, Object? config}) async {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server()..fieldConfig = config;
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

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save Changes'));
  await tester.tap(find.text('Save Changes'));
  await settle(tester);
}

Map<String, dynamic> lastPut() => server.of('PUT', ApiConstants.employeeDetail(code)).last.data as Map<String, dynamic>;

Map<String, dynamic> cfg(Map<String, bool> visible, {List<Map<String, dynamic>> extra = const []}) => {
      '0': [
        for (final e in visible.entries)
          {'field_key': e.key, 'label': e.key, 'field_type': 'text', 'step': 0, 'visible': e.value},
        ...extra,
      ],
    };

EmployeeUpdateFormData form([Map<String, dynamic>? profile]) =>
    EmployeeUpdateFormData.fromModel(EmployeeModel.fromJson(employeeJson(profile: profile)));

Finder label(String t) =>
    find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().replaceAll(' *', '') == t);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('validate (web: no client-side required check; hidden DOB not checked)', () {
    test('visible + empty DOB: not an error (web enforces nothing; backend skips empty)', () {
      expect((form()..dateOfBirth = '').validate(), isEmpty);
      expect((form()..dateOfBirth = '').validate(dobVisible: true), isEmpty);
    });
    test('visible + bad value still checked with the backend rules', () {
      expect((form()..dateOfBirth = 'junk').validate()['date_of_birth'], 'Enter a valid date of birth.');
      expect((form()..dateOfBirth = '2020-01-01').validate()['date_of_birth'], 'Age must be between 18 and 80 years.');
    });
    test('hidden DOB: empty or stored-but-odd value never blocks', () {
      expect((form()..dateOfBirth = '').validate(dobVisible: false), isEmpty);
      expect((form()..dateOfBirth = '2020-01-01').validate(dobVisible: false), isEmpty);
    });
    test('other validation unchanged when DOB hidden', () {
      final e = (form()
            ..email = ' '
            ..designation = '')
          .validate(dobVisible: false);
      expect(e['email'], 'Login email is required.');
      expect(e['designation'], 'Designation is required.');
    });
    test('toJson: stored hidden values resent as loaded; empty DOB is null (web)', () {
      final j = form().toJson();
      expect(j['date_of_birth'], '1995-02-01');
      expect([j['gender'], j['father_name'], j['blood_group'], j['current_address'], j['permanent_address']],
          ['female', 'Test Father', 'O+', '1 Test Road', '2 Test Lane']);
      expect(j.containsKey('custom_field_values'), isFalse);
      expect((form({})..dateOfBirth = '').toJson()['date_of_birth'], isNull);
    });
  });

  group('sheet', () {
    testWidgets('1. config not loaded: every personal field shown, DOB and Gender starred', (tester) async {
      await pumpEdit(tester);
      for (final l in [
        'Date of Birth',
        'Gender',
        'Marital Status',
        "Father's Name",
        'Blood Group',
        'Current Address',
        'Permanent Address'
      ]) {
        expect(label(l), findsWidgets, reason: l);
      }
    });

    testWidgets('2. visible=true entries: all shown; PUT carries the stored values', (tester) async {
      await pumpEdit(tester, config: cfg({'date_of_birth': true, 'gender': true}));
      expect(label('Date of Birth'), findsOneWidget);
      await save(tester);
      expect(lastPut()['date_of_birth'], '1995-02-01');
      expect(lastPut()['gender'], 'female');
      expect(sheetResult, isTrue);
    });

    testWidgets('3. DOB visible + required + emptied: web does not block; PUT date_of_birth null', (tester) async {
      await pumpEdit(tester, employee: employeeJson(profile: {'gender': 'female'}));
      await save(tester);
      expect(find.text('Date of birth is required.'), findsNothing);
      expect(lastPut()['date_of_birth'], isNull);
      expect(sheetResult, isTrue);
    });

    testWidgets('4. DOB hidden + nothing stored: no field, no error, save succeeds', (tester) async {
      await pumpEdit(tester,
          employee: employeeJson(profile: {'gender': 'female'}), config: cfg({'date_of_birth': false}));
      expect(label('Date of Birth'), findsNothing);
      await save(tester);
      expect(sheetResult, isTrue);
      expect(lastPut()['date_of_birth'], isNull);
    });

    testWidgets('5. hidden fields with stored values: not shown, resent unchanged (web), other fields intact',
        (tester) async {
      await pumpEdit(tester,
          config: cfg({
            'date_of_birth': false,
            'gender': false,
            'marital_status': false,
            'father_name': false,
            'blood_group': false,
            'current_address': false,
            'permanent_address': false,
          }));
      for (final l in [
        'Date of Birth',
        'Gender',
        'Marital Status',
        "Father's Name",
        'Blood Group',
        'Current Address',
        'Permanent Address'
      ]) {
        expect(label(l), findsNothing, reason: l);
      }
      expect(label('Phone'), findsOneWidget);
      await save(tester);
      final p = lastPut();
      expect(sheetResult, isTrue);
      expect(p['date_of_birth'], '1995-02-01');
      expect([p['gender'], p['marital_status'], p['father_name'], p['blood_group']],
          ['female', 'single', 'Test Father', 'O+']);
      expect([p['current_address'], p['permanent_address']], ['1 Test Road', '2 Test Lane']);
      expect(p['phone'], '9000000007');
      expect(p.containsKey('custom_field_values'), isFalse);
    });

    testWidgets('6. hidden optional fields with nothing stored + visible optional empty: saves, blanks as loaded',
        (tester) async {
      await pumpEdit(tester,
          employee: employeeJson(profile: {'date_of_birth': '1995-02-01'}),
          config: cfg({'father_name': false, 'blood_group': false}));
      expect(label("Father's Name"), findsNothing);
      expect(label('Marital Status'), findsOneWidget);
      await save(tester);
      expect(sheetResult, isTrue);
      expect(lastPut()['father_name'], '');
      expect(lastPut()['marital_status'], '');
    });

    testWidgets('7. a custom field entry in the config does not appear or alter the PUT', (tester) async {
      await pumpEdit(tester,
          config: cfg({
            'gender': false
          }, extra: [
            {
              'field_key': 'cf_shoe',
              'label': 'Shoe',
              'field_type': 'text',
              'step': 0,
              'visible': true,
              'is_custom': true
            },
          ]));
      await save(tester);
      expect(sheetResult, isTrue);
      expect(lastPut().containsKey('custom_field_values'), isFalse);
      expect(lastPut().containsKey('cf_shoe'), isFalse);
    });
  });
}
