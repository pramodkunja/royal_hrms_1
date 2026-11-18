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
import 'package:mobile_app/features/contacts/presentation/screens/contact_matrix_screen.dart'
    show contactLauncherProvider;
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/domain/employee_profile_sections.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';
import 'package:mobile_app/features/employees/presentation/widgets/employee_attendance_tab.dart'
    show EmployeeAttendanceTab, webNumber;
import 'package:mobile_app/features/settings/data/models/onboarding_field_config_model.dart';

// Task 94: Employee Profile parity gaps found by the profile audit — the
// Personal section (web employees/_data.ts:144-176 + applyFieldConfig step 0),
// the Documents slot rules (web _data.ts:233-245, :280-288, [id]/page.tsx
// buildDocEntries, ProfileForm fmtBytes) and the Attendance tab's number
// format. Synthetic data only; a stand-in server; read-only.

const code = 'EMP-7';

Map<String, dynamic> employee() => {
      'id': 'u7',
      'employee_id': code,
      'first_name': 'Pat',
      'last_name': 'Kumar',
      'full_name': 'Pat Kumar',
      'email': 'pat.kumar@example.test',
      'phone': '9000000000',
      'department': 'Engineering',
      'designation': 'Engineer',
      'branch': 'Surat',
      'role': 'employee',
      'role_display': 'Employee',
      'is_active': true,
      'status': 'active',
      'date_of_joining': '2026-01-05',
      'date_of_birth': '1990-04-02',
      'reporting_manager': {'id': 'EMP-2', 'name': 'Morgan Lee'},
      'reporting_approver': {'id': 'EMP-3', 'name': 'Avery Shah'},
      'hr': {'id': 'EMP-4', 'name': 'Hema Iyer'},
      'notice_period_days': 30,
      'documents': [],
      'profile': {'gender': 'male', 'blood_group': 'O+'},
    };

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class Server implements HttpClientAdapter {
  /// Settings → Onboarding Fields, step 0 rows (empty = everything shown).
  List<Map<String, dynamic>> step0 = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') {
      fail('unexpected write ${o.method} ${o.path}');
    }
    if (o.path == '/employees/$code/') {
      return _json(200, {'status': 'success', 'data': employee()});
    }
    if (o.path == '/employees/EMP-NONE/') {
      return _json(404, {'status': 'error', 'message': 'Employee not found.', 'data': {}});
    }
    if (o.path == ApiConstants.attendanceStats) {
      return _json(200, {
        'status': 'success',
        'data': {
          'days_present': 18,
          'late_arrivals': 3,
          'lop_pending': 1,
          'avg_hours_per_day': 8.5,
          'attendance_percentage': 87.5,
          'working_days': 22,
        },
      });
    }
    if (o.path == ApiConstants.onboardingFieldConfig) {
      return _json(200, {
        'status': 'success',
        'data': {'0': step0},
      });
    }
    return _json(200, {'status': 'success', 'data': <Object>[]});
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

const hr = UserEntity(
  id: 'hr1',
  email: 'hr@example.test',
  fullName: 'Test HR',
  role: 'hr',
  roleDisplay: 'HR',
  mustChangePassword: false,
  permissions: ['employees.view', 'employees.edit'],
  onboardingStatus: 'complete',
  assessmentStatus: 'complete',
);

late Server server;

Future<void> pumpProfile(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(hr)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: const MaterialApp(home: EmployeeProfileScreen(employeeId: code)),
  ));
  await tester.pumpAndSettle();
}

Finder inPersonal(Finder f) => find.descendant(of: find.byKey(const Key('employee-personal-fields')), matching: f);

DocumentTypeConfigModel type(String key, String label, int order, {bool visible = true, bool required = false}) =>
    DocumentTypeConfigModel(
      typeKey: key,
      label: label,
      order: order,
      visible: visible,
      required: required,
      allowMultiple: false,
      isCustom: false,
      isLocked: false,
    );

EmployeeDocumentEntity upload(int id, String type) => EmployeeDocumentEntity(
      id: id,
      documentType: type,
      documentTypeDisplay: type,
      fileUrl: 'https://files.invalid/$id',
      fileName: '$id.pdf',
      fileSize: 2048,
      uploadedAt: '2026-11-18T10:00:00Z',
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => server = Server());

  group('Documents slots (web buildDocEntries / applyDocumentTypeConfig)', () {
    test('no config → web built-in six, in web order', () {
      final slots = buildEmployeeDocSlots(const [], const []);
      expect(slots.map((s) => s.typeKey), [
        'pan_card', 'aadhaar_card', 'degree_certificate', 'experience_letter',
        'passport_photo', 'cancelled_cheque', //
      ]);
      expect(slots.every((s) => s.doc == null), isTrue);
    });

    test('config: visible types only, sorted by order, labels from config; first upload of a type wins', () {
      final slots = buildEmployeeDocSlots([
        type('aadhaar_card', 'Aadhaar', 2),
        type('pan_card', 'PAN', 1),
        type('passport_photo', 'Photo', 3, visible: false),
        type('nda', 'Signed NDA', 4, required: true),
      ], [
        upload(10, 'aadhaar_card'),
        upload(11, 'aadhaar_card'),
        upload(12, 'passport_photo'),
      ]);
      expect(slots.map((s) => (s.typeKey, s.label, s.required)), [
        ('pan_card', 'PAN', false),
        ('aadhaar_card', 'Aadhaar', false),
        ('nda', 'Signed NDA', true),
      ]);
      expect(slots[1].doc!.id, 10);
      expect(slots[0].doc, isNull);
      // Hidden-type upload and the second Aadhaar stay reachable.
      expect(
          unslottedEmployeeDocs(
                  slots, [upload(10, 'aadhaar_card'), upload(11, 'aadhaar_card'), upload(12, 'passport_photo')])
              .map((d) => d.id),
          [11, 12]);
    });

    test('web fmtBytes and the en-US short date', () {
      expect(webFileSize(900), '900 B');
      expect(webFileSize(2048), '2 KB');
      expect(webFileSize(5 * 1024 * 1024), '5.0 MB');
      expect(webShortDate('2026-03-01T10:00:00Z'), 'Mar 1, 2026');
      expect(webShortDate('not a date'), 'not a date');
    });
  });

  test('Attendance tab numbers as web prints them (not rounded)', () {
    expect(webNumber(8), '8');
    expect(webNumber(7.5), '7.5');
    expect(webNumber(87.25), '87.25');
  });

  group('Personal (web PROFILE_SECTIONS "personal")', () {
    test('only the seven personal-details fields follow the step-0 config', () {
      final cfg = <int, List<OnboardingFieldConfigModel>>{
        0: [
          OnboardingFieldConfigModel.fromJson(
              {'field_key': 'date_of_birth', 'label': 'DOB', 'field_type': 'date', 'step': 0, 'visible': false}),
          OnboardingFieldConfigModel.fromJson(
              {'field_key': 'branch', 'label': 'Branch', 'field_type': 'text', 'step': 0, 'visible': false}),
        ],
      };
      expect(isPersonalFieldVisible('date_of_birth', cfg), isFalse);
      expect(isPersonalFieldVisible('branch', cfg), isTrue, reason: 'identity / employment fields always show');
      expect(isPersonalFieldVisible('gender', cfg), isTrue, reason: 'no entry → shown');
      expect(isPersonalFieldVisible('date_of_birth', null), isTrue, reason: 'config not loaded → shown');
    });

    testWidgets('web fields and labels, in web order', (tester) async {
      await pumpProfile(tester);
      for (final label in [
        'Employee ID', 'First Name', 'Last Name', 'Login Email', 'Phone',
        'Date of Joining', 'Department', //
        'Designation', 'Role', 'Branch', 'Reporting Manager',
        'Reporting Approver', 'Branch HR', 'Notice Period',
        'Date of Birth', 'Gender', 'Marital Status', "Father's Name",
        'Blood Group', 'Current Address',
        'Permanent Address',
      ]) {
        expect(inPersonal(find.text(label)), findsOneWidget, reason: label);
      }
      expect(inPersonal(find.text('Work Email')), findsNothing);
      expect(inPersonal(find.text('HR Contact')), findsNothing);
      expect(inPersonal(find.text('Avery Shah')), findsOneWidget);
      expect(inPersonal(find.text('Surat')), findsOneWidget);
      expect(inPersonal(find.text('Pat')), findsOneWidget);
      expect(inPersonal(find.text('Kumar')), findsOneWidget);
      double top(String t) => tester.getTopLeft(inPersonal(find.text(t))).dy;
      expect(top('Login Email'), lessThan(top('Department')));
      expect(top('Reporting Approver'), lessThan(top('Date of Birth')));
    });

    testWidgets('a personal field hidden in Settings → Onboarding Fields is left out', (tester) async {
      server.step0 = [
        {'field_key': 'date_of_birth', 'label': 'Date of Birth', 'field_type': 'date', 'step': 0, 'visible': false},
        {
          'field_key': 'current_address',
          'label': 'Current Address',
          'field_type': 'textarea',
          'step': 0,
          'visible': false
        },
      ];
      await pumpProfile(tester);
      expect(inPersonal(find.text('Date of Birth')), findsNothing);
      expect(inPersonal(find.text('Current Address')), findsNothing);
      expect(inPersonal(find.text('Gender')), findsOneWidget);
      expect(inPersonal(find.text('Permanent Address')), findsOneWidget);
      expect(inPersonal(find.text('Branch')), findsOneWidget);
    });
  });

  testWidgets('not found: web copy with the code and a Back to Employees button', (tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        authStateProvider.overrideWith(() => _Auth(hr)),
        dioProvider
            .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
        cookieJarProvider.overrideWithValue(CookieJar()),
        secureStorageProvider.overrideWithValue(_NullStorage()),
      ],
      child: const MaterialApp(home: EmployeeProfileScreen(employeeId: 'EMP-NONE')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Employee not found'), findsOneWidget);
    expect(find.text('No employee exists with code EMP-NONE.'), findsOneWidget);
    expect(find.text('Back to Employees'), findsOneWidget);
  });

  testWidgets('Attendance stat cards: web sub-lines, unrounded values, progress bars', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        authStateProvider.overrideWith(() => _Auth(hr)),
        dioProvider
            .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
        cookieJarProvider.overrideWithValue(CookieJar()),
        secureStorageProvider.overrideWithValue(_NullStorage()),
      ],
      child: MaterialApp(
        home: Scaffold(body: EmployeeAttendanceTab(employee: EmployeeModel.fromJson(employee()))),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('of 22 working days'), findsOneWidget);
    expect(find.text('1 LOP pending'), findsOneWidget);
    expect(find.text('Required: 9.0 hrs'), findsOneWidget);
    expect(find.text('8.5'), findsOneWidget);
    expect(find.text('87.5%'), findsOneWidget, reason: 'not rounded to 88%');
    expect(find.text('Above threshold'), findsNothing, reason: 'hard-coded on web; deliberate difference');
    final bars =
        tester.widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).map((b) => b.value!).toList();
    expect(bars.length, 4);
    expect(bars[0], closeTo(18 / 22, 1e-9));
    expect(bars[1], closeTo(3 / 22, 1e-9));
    expect(bars[2], closeTo(8.5 / 9, 1e-9));
    expect(bars[3], closeTo(0.875, 1e-9));
  });

  test('profile edit: Department is not required (web has no client check; a Branch Admin employee has none)', () {
    final form = EmployeeUpdateFormData.fromModel(EmployeeModel.fromJson(employee()))..department = '';
    expect(form.validate().containsKey('department'), isFalse);
    form.designation = '';
    expect(form.validate()['designation'], 'Designation is required.');
  });

  testWidgets('header phone is a tel: link (web ProfileHeader.tsx:145)', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final launched = <Uri>[];
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        authStateProvider.overrideWith(() => _Auth(hr)),
        dioProvider
            .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
        cookieJarProvider.overrideWithValue(CookieJar()),
        secureStorageProvider.overrideWithValue(_NullStorage()),
        contactLauncherProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return true;
        }),
      ],
      child: const MaterialApp(home: EmployeeProfileScreen(employeeId: code)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('employee-header-phone')));
    await tester.pump();
    expect(launched, [Uri(scheme: 'tel', path: '9000000000')]);
  });
}
