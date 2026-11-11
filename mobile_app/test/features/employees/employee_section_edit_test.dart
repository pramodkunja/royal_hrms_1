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
import 'package:mobile_app/features/employees/domain/employee_profile_sections.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';

// Task 14 (audit C-E14): HR Employee Profile → Education & Experience, Bank
// Details, Emergency Contact editing, as web employees/[id]/page.tsx +
// _data.ts PROFILE_SECTIONS: single-record grids (no add/remove rows, one
// emergency contact), saved via PUT /employees/<code>/ (EmployeeDetailView →
// EmployeeProfileSerializer partial; errors {message: "field: msg",
// data: {field: [msg]}}). Synthetic data only; a stand-in server; no real
// employee is changed. Bank values are fictitious.

const code = 'EMP-21';
const detailPath = '/employees/$code/';

Map<String, dynamic> profile() => <String, dynamic>{
      'gender': 'female',
      'father_name': 'Test Parent',
      'highest_qualification': 'B.Tech',
      'specialization': 'Computer Science',
      'institution': 'Test Institute',
      'year_of_passing': 2019,
      'total_experience_years': '3.5',
      'previous_employer': 'Test Co',
      'previous_designation': 'Analyst',
      'leaving_reason': 'Growth',
      'account_holder_name': 'Test Holder',
      'account_type': 'savings',
      'account_number': '000011112222',
      'ifsc_code': 'TEST0000001',
      'bank_name': 'Test Bank',
      'bank_branch_name': 'Test Branch',
      'emergency_name': 'Test Contact',
      'emergency_relationship': 'Brother', // not one of web's options
      'emergency_phone': '+91 90000 00000',
      'emergency_email': 'contact@example.test',
      'custom_field_values': <String, dynamic>{},
    };

Map<String, dynamic> employee(Map<String, dynamic> p) => <String, dynamic>{
      'id': 'u21',
      'employee_id': code,
      'first_name': 'Ria',
      'last_name': 'Test',
      'full_name': 'Ria Test',
      'email': 'ria.test@example.test',
      'phone': '9000000021',
      'department': 'QA',
      'designation': 'Analyst',
      'branch': 'North',
      'role': 'employee',
      'role_display': 'Employee',
      'is_active': true,
      'status': 'active',
      'onboarding_status': 'complete',
      'date_of_joining': '2026-01-05',
      'hr': <String, dynamic>{'id': null, 'name': null},
      'documents': <Object>[],
      'profile': p,
    };

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class Server implements HttpClientAdapter {
  Map<String, dynamic> prof = profile();
  List<Map<String, dynamic>> fieldConfig = [];
  ({int status, String message, Map<String, dynamic> data})? refuse;
  Completer<void>? hold;
  final puts = <Map<String, dynamic>>[];
  int detailGets = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == detailPath && o.method == 'GET') {
      detailGets++;
      return _json(200, {'status': 'success', 'data': employee(prof)});
    }
    if (o.path == detailPath && o.method == 'PUT') {
      final body = Map<String, dynamic>.from(o.data as Map);
      puts.add(body);
      final gate = hold;
      if (gate != null) await gate.future;
      final r = refuse;
      if (r != null) return _json(r.status, {'status': 'error', 'message': r.message, 'data': r.data});
      prof = {...prof, ...body}; // EmployeeProfileSerializer(partial=True)
      return _json(200, {'status': 'success', 'message': 'Employee updated.', 'data': employee(prof)});
    }
    if (o.path == ApiConstants.onboardingFieldConfig) {
      return _json(200, {
        'status': 'success',
        'data': {'1': fieldConfig, '2': <Object>[], '3': <Object>[]}
      });
    }
    if (o.method == 'GET') return _json(200, {'status': 'success', 'data': <Object>[]});
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': <String, dynamic>{}});
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

UserEntity hrUser(List<String> perms) => UserEntity(
      id: 'hr1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final editor = hrUser(['employees.view', 'employees.edit']);
final viewer = hrUser(['employees.view']);

late Server server;

Future<void> pumpProfile(WidgetTester tester, {UserEntity? as, Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? editor)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: const MaterialApp(home: EmployeeProfileScreen(employeeId: code)),
  ));
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(tester.element(find.byType(EmployeeProfileScreen)));
  await c.read(authStateProvider.future);
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

const _sectionTitles = {
  EmployeeProfileSection.education: 'Education & Experience',
  EmployeeProfileSection.bank: 'Bank Details',
  EmployeeProfileSection.emergency: 'Emergency Contact',
  EmployeeProfileSection.statutory: 'EPF / Statutory',
};

Future<void> openSection(WidgetTester tester, EmployeeProfileSection s) async {
  final chip = find.text(_sectionTitles[s]!).first;
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> openEditor(WidgetTester tester, EmployeeProfileSection s) async {
  await openSection(tester, s);
  await tester.tap(byKey('profile-edit-${s.name}'));
  await tester.pumpAndSettle();
}

String shown(WidgetTester tester, String key) => tester
    .widgetList<Text>(find.descendant(of: byKey('profile-field-$key'), matching: find.byType(Text)))
    .map((t) => t.data)
    .last!;

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(byKey('section-field-$key')).controller!.text;
String? fieldError(WidgetTester tester, String key) =>
    tester.widget<TextField>(byKey('section-field-$key')).decoration!.errorText;

Future<void> type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(byKey('section-field-$key'));
  await tester.enterText(byKey('section-field-$key'), text);
  await tester.pump();
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(byKey('section-edit-save'));
  await tester.tap(byKey('section-edit-save'));
  await tester.pumpAndSettle();
}

Future<void> pickOption(WidgetTester tester, String key, String label) async {
  await tester.ensureVisible(byKey('section-field-$key'));
  await tester.tap(byKey('section-field-$key'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('definitions and payload (web _data.ts / onSave)', () {
    test('fields, required asterisks and options match web', () {
      List<String> keys(EmployeeProfileSection s) => kEmployeeProfileSections[s]!.fields.map((f) => f.key).toList();
      List<String> req(EmployeeProfileSection s) =>
          kEmployeeProfileSections[s]!.fields.where((f) => f.required).map((f) => f.key).toList();
      expect(keys(EmployeeProfileSection.education), [
        'highest_qualification', 'specialization', 'institution', 'year_of_passing', //
        'total_experience_years', 'previous_employer', 'previous_designation', 'leaving_reason',
      ]);
      expect(req(EmployeeProfileSection.education), isEmpty);
      expect(keys(EmployeeProfileSection.bank),
          ['account_holder_name', 'account_type', 'account_number', 'ifsc_code', 'bank_name', 'bank_branch_name']);
      expect(req(EmployeeProfileSection.bank),
          ['account_holder_name', 'account_type', 'account_number', 'ifsc_code', 'bank_name']);
      expect(keys(EmployeeProfileSection.emergency),
          ['emergency_name', 'emergency_relationship', 'emergency_phone', 'emergency_email']);
      expect(req(EmployeeProfileSection.emergency), ['emergency_name', 'emergency_relationship', 'emergency_phone']);
      final rel = kEmployeeProfileSections[EmployeeProfileSection.emergency]!.fields[1];
      expect(rel.options.map((o) => o.value), ['Father', 'Mother', 'Spouse', 'Sibling', 'Friend', 'Other']);
      final type = kEmployeeProfileSections[EmployeeProfileSection.bank]!.fields[1];
      expect(type.options.map((o) => (o.value, o.label)), [('savings', 'Savings'), ('current', 'Current')]);
    });

    test('blank → "" except year_of_passing / total_experience_years → null; values as typed', () {
      final p = profileSectionPayload(EmployeeProfileSection.education, {'highest_qualification': 'MBA'});
      expect(p, {
        'highest_qualification': 'MBA',
        'specialization': '',
        'institution': '',
        'year_of_passing': null,
        'total_experience_years': null,
        'previous_employer': '',
        'previous_designation': '',
        'leaving_reason': '',
      });
      expect(profileSectionPayload(EmployeeProfileSection.education, {'year_of_passing': '2020'})['year_of_passing'],
          '2020');
    });

    test('current values come from the employee profile', () {
      final e = EmployeeModel.fromJson(employee(profile()));
      expect(profileSectionValues(EmployeeProfileSection.bank, e), {
        'account_holder_name': 'Test Holder',
        'account_type': 'savings',
        'account_number': '000011112222',
        'ifsc_code': 'TEST0000001',
        'bank_name': 'Test Bank',
        'bank_branch_name': 'Test Branch',
      });
      expect(profileSectionValues(EmployeeProfileSection.education, e)['year_of_passing'], '2019');
    });
  });

  group('display', () {
    testWidgets('existing data is shown with web labels (account type "Savings")', (tester) async {
      await pumpProfile(tester);
      await openSection(tester, EmployeeProfileSection.education);
      expect(shown(tester, 'highest_qualification'), 'B.Tech');
      expect(shown(tester, 'year_of_passing'), '2019');
      expect(shown(tester, 'total_experience_years'), '3.5');
      await openSection(tester, EmployeeProfileSection.bank);
      expect(shown(tester, 'account_type'), 'Savings');
      expect(shown(tester, 'ifsc_code'), 'TEST0000001');
      await openSection(tester, EmployeeProfileSection.emergency);
      expect(shown(tester, 'emergency_relationship'), 'Brother');
      expect(shown(tester, 'emergency_email'), 'contact@example.test');
    });

    testWidgets('a field hidden in Onboarding Fields is not shown or edited (web applyFieldConfig)', (tester) async {
      final s = Server()
        ..fieldConfig = [
          {
            'field_key': 'previous_employer',
            'label': 'Previous Employer',
            'step': 1,
            'visible': false,
            'is_custom': false
          },
        ];
      await pumpProfile(tester, with_: s);
      await openSection(tester, EmployeeProfileSection.education);
      expect(byKey('profile-field-previous_employer'), findsNothing);
      expect(byKey('profile-field-previous_designation'), findsOneWidget);
      await tester.tap(byKey('profile-edit-education'));
      await tester.pumpAndSettle();
      expect(byKey('section-field-previous_employer'), findsNothing);
      await save(tester);
      expect(s.puts.single['previous_employer'], 'Test Co', reason: 'hidden value is re-sent unchanged');
    });
  });

  group('editing', () {
    testWidgets('Education: prefilled, saved with exactly its keys, display refreshed', (tester) async {
      await pumpProfile(tester);
      await openEditor(tester, EmployeeProfileSection.education);
      expect(fieldText(tester, 'institution'), 'Test Institute');
      expect(fieldText(tester, 'year_of_passing'), '2019');
      await type(tester, 'highest_qualification', 'M.Tech');
      await type(tester, 'total_experience_years', '');
      await save(tester);
      expect(server.puts.single, {
        'highest_qualification': 'M.Tech',
        'specialization': 'Computer Science',
        'institution': 'Test Institute',
        'year_of_passing': '2019',
        'total_experience_years': null,
        'previous_employer': 'Test Co',
        'previous_designation': 'Analyst',
        'leaving_reason': 'Growth',
      });
      expect(byKey('section-edit-education'), findsNothing);
      expect(find.text('Changes saved successfully.'), findsOneWidget);
      expect(server.detailGets, greaterThanOrEqualTo(2), reason: 'the employee is reloaded');
      expect(shown(tester, 'highest_qualification'), 'M.Tech');
    });

    testWidgets('Bank: all six fields editable, account type select, saved', (tester) async {
      await pumpProfile(tester);
      await openEditor(tester, EmployeeProfileSection.bank);
      expect(fieldText(tester, 'account_number'), '000011112222');
      await pickOption(tester, 'account_type', 'Current');
      await type(tester, 'ifsc_code', 'ABCD0123456');
      await type(tester, 'bank_branch_name', 'New Branch');
      await save(tester);
      expect(server.puts.single, {
        'account_holder_name': 'Test Holder',
        'account_type': 'current',
        'account_number': '000011112222',
        'ifsc_code': 'ABCD0123456',
        'bank_name': 'Test Bank',
        'bank_branch_name': 'New Branch',
      });
      expect(shown(tester, 'account_type'), 'Current');
    });

    testWidgets('Emergency: one contact; an off-list relationship is kept unless changed', (tester) async {
      await pumpProfile(tester);
      await openEditor(tester, EmployeeProfileSection.emergency);
      await type(tester, 'emergency_phone', '+91 98888 77777');
      await save(tester);
      expect(server.puts.single, {
        'emergency_name': 'Test Contact',
        'emergency_relationship': 'Brother',
        'emergency_phone': '+91 98888 77777',
        'emergency_email': 'contact@example.test',
      });
      await tester.tap(byKey('profile-edit-emergency'));
      await tester.pumpAndSettle();
      await pickOption(tester, 'emergency_relationship', 'Sibling');
      await save(tester);
      expect(server.puts.last['emergency_relationship'], 'Sibling');
    });

    testWidgets('only the edited section is sent — other sections and employment fields untouched', (tester) async {
      await pumpProfile(tester);
      await openEditor(tester, EmployeeProfileSection.emergency);
      await save(tester);
      final keys = server.puts.single.keys.toSet();
      for (final other in [
        'account_number',
        'ifsc_code',
        'highest_qualification',
        'department',
        'role',
        'hr_id',
        'email',
        'is_active'
      ]) {
        expect(keys.contains(other), isFalse, reason: other);
      }
      await openSection(tester, EmployeeProfileSection.bank);
      expect(shown(tester, 'account_number'), '000011112222');
    });

    testWidgets('Cancel closes without a request and keeps the shown values', (tester) async {
      await pumpProfile(tester);
      await openEditor(tester, EmployeeProfileSection.bank);
      await type(tester, 'bank_name', 'Changed Bank');
      await tester.tap(byKey('section-edit-cancel'));
      await tester.pumpAndSettle();
      expect(server.puts, isEmpty);
      expect(shown(tester, 'bank_name'), 'Test Bank');
      await tester.tap(byKey('profile-edit-bank'));
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'bank_name'), 'Test Bank', reason: 'reopening starts from the saved values');
    });
  });

  group('validation, errors and retry', () {
    testWidgets('a server validation error is shown on its field and every value is kept; retry succeeds',
        (tester) async {
      final s = Server()
        ..refuse = (
          status: 400,
          message:
              'ifsc_code: Enter a valid IFSC code (e.g. SBIN0001234) — 4 letters, digit 0, then 6 alphanumeric characters.',
          data: <String, dynamic>{
            'ifsc_code': [
              'Enter a valid IFSC code (e.g. SBIN0001234) — 4 letters, digit 0, then 6 alphanumeric characters.'
            ]
          }
        );
      await pumpProfile(tester, with_: s);
      await openEditor(tester, EmployeeProfileSection.bank);
      await type(tester, 'ifsc_code', 'BAD');
      await type(tester, 'bank_name', 'Edited Bank');
      await save(tester);
      expect(byKey('section-edit-bank'), findsOneWidget, reason: 'stays open');
      expect(fieldError(tester, 'ifsc_code'), startsWith('Enter a valid IFSC code'));
      expect(byKey('section-edit-error'), findsOneWidget);
      expect(fieldText(tester, 'ifsc_code'), 'BAD');
      expect(fieldText(tester, 'bank_name'), 'Edited Bank');
      // editing the field clears its error; the retry succeeds
      await type(tester, 'ifsc_code', 'ABCD0123456');
      expect(fieldError(tester, 'ifsc_code'), isNull);
      s.refuse = null;
      await save(tester);
      expect(s.puts, hasLength(2));
      expect(s.puts.last['ifsc_code'], 'ABCD0123456');
      expect(s.puts.last['bank_name'], 'Edited Bank');
      expect(byKey('section-edit-bank'), findsNothing);
    });

    testWidgets('a network failure keeps the form and values', (tester) async {
      final s = Server()
        ..refuse =
            (status: 500, message: 'An unexpected error occurred. Please try again later.', data: <String, dynamic>{});
      await pumpProfile(tester, with_: s);
      await openEditor(tester, EmployeeProfileSection.education);
      await type(tester, 'specialization', 'Data Science');
      await save(tester);
      expect(byKey('section-edit-error'), findsOneWidget);
      expect(fieldText(tester, 'specialization'), 'Data Science');
    });

    testWidgets('a second tap while saving sends one request; Cancel is disabled meanwhile', (tester) async {
      final s = Server()..hold = Completer();
      await pumpProfile(tester, with_: s);
      await openEditor(tester, EmployeeProfileSection.emergency);
      await tester.tap(byKey('section-edit-save'));
      await tester.pump();
      expect(tester.widget<FilledButton>(byKey('section-edit-save')).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(byKey('section-edit-cancel')).onPressed, isNull);
      await tester.tap(byKey('section-edit-save'), warnIfMissed: false);
      await tester.pump();
      s.hold!.complete();
      await tester.pumpAndSettle();
      expect(s.puts, hasLength(1));
    });
  });

  group('permissions', () {
    testWidgets('without employees.edit there is no Edit on these sections and nothing can be sent', (tester) async {
      await pumpProfile(tester, as: viewer);
      for (final sct in EmployeeProfileSection.values) {
        await openSection(tester, sct);
        expect(byKey('profile-edit-${sct.name}'), findsNothing, reason: sct.name);
      }
      expect(server.puts, isEmpty);
    });

    testWidgets('the save action itself refuses without employees.edit (no request)', (tester) async {
      server = Server();
      late WidgetRef captured;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => _Auth(viewer)),
          dioProvider
              .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullStorage()),
        ],
        child: Consumer(builder: (_, ref, __) {
          captured = ref;
          ref.watch(authStateProvider);
          return const SizedBox();
        }),
      ));
      await tester.pumpAndSettle();
      final result = await tester.runAsync(() => saveEmployeeProfileSection(
          captured, code, profileSectionPayload(EmployeeProfileSection.bank, const {'bank_name': 'X'})));
      expect(result?.message, kCustomFieldsEditDenied);
      expect(server.puts, isEmpty);
    });

    testWidgets('an editor gets Edit on every section', (tester) async {
      await pumpProfile(tester);
      for (final sct in EmployeeProfileSection.values) {
        await openSection(tester, sct);
        expect(byKey('profile-edit-${sct.name}'), findsOneWidget, reason: sct.name);
      }
    });
  });
}
