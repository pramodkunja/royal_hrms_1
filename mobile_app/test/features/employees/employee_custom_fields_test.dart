import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
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
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';
import 'package:mobile_app/features/employees/presentation/widgets/custom_fields_block.dart';
import 'package:mobile_app/features/onboarding/data/models/onboarding_config_models.dart';
import 'package:mobile_app/features/onboarding/presentation/widgets/onboarding_custom_file_field.dart';

// P1-8: HR-created custom fields on the HR employee profile, as web
// employees/[id]/page.tsx (local web branch): per section (step 0-3) the
// `is_custom && visible` fields from GET /onboarding/field-config/; edit under
// employees.edit; save PUT /employees/<id>/ with custom_field_values for every
// configured text-type key (hidden included, "" when unset) — backend
// EmployeeDetailView.put merges it into the stored dict (unsent keys kept,
// file keys stripped). File fields: POST /employees/<id>/custom-file-fields/
// {field_key, file}; DELETE /onboarding/custom-file-fields/<id>/.
// Mocked Dio, synthetic employee — nothing is written.

const code = 'EMP-7';

Map<String, dynamic> cfg(String key, String type, int step,
        {List<String> options = const [], bool visible = true, bool required = false, bool custom = true, int order = 0}) =>
    {
      'field_key': key,
      'label': 'Label $key',
      'field_type': type,
      'options': options,
      'allow_multiple': false,
      'step': step,
      'order': order,
      'visible': visible,
      'required': required,
      'is_custom': custom,
      'is_locked': false,
    };

final fieldConfig = {
  '0': [
    cfg('gender', 'dropdown', 0, custom: false),
    cfg('cf_passport', 'text', 0, required: true, order: 1),
    cfg('cf_shirt', 'dropdown', 0, options: ['S', 'M', 'L'], order: 2),
    cfg('cf_vegan', 'checkbox', 0, order: 3),
    cfg('cf_hidden', 'text', 0, visible: false, order: 4),
  ],
  '1': [
    cfg('cf_cert_date', 'date', 1, order: 1),
    cfg('cf_notes', 'textarea', 1, order: 2),
  ],
  '2': [
    cfg('cf_upi', 'number', 2, order: 1),
    cfg('cf_rating', 'rating', 2, order: 2), // a type mobile doesn't know → plain text, as web
  ],
  '3': [
    cfg('cf_doc', 'file', 3, order: 1),
  ],
};

Map<String, dynamic> employee() => {
      'id': 'u7',
      'employee_id': code,
      'first_name': 'Pat',
      'last_name': 'Kumar',
      'full_name': 'Pat Kumar',
      'email': 'pat.kumar@example.test',
      'department': 'Engineering',
      'designation': 'Engineer',
      'branch': 'Surat',
      'role': 'employee',
      'role_display': 'Employee',
      'is_active': true,
      'status': 'active',
      'documents': [],
      'profile': {
        'gender': 'male',
        'custom_field_values': {
          'cf_passport': 'P123',
          'cf_shirt': 'XL', // no longer an option
          'cf_vegan': 'true',
          'cf_hidden': 'keep-me',
          'cf_cert_date': '2026-01-10',
          'cf_upi': '42',
          'cf_rating': '5',
          'cf_removed': 'legacy value', // field deleted from the config
        },
      },
      'custom_file_fields': [
        {'id': 5, 'field_key': 'cf_doc', 'file': 'https://files.example.test/5/', 'file_name': 'proof.pdf', 'file_size': 2048, 'uploaded_at': '2026-11-01T10:00:00Z'},
      ],
    };

class Server implements HttpClientAdapter {
  Map<String, dynamic> detail = employee();
  int configStatus = 200;
  ({int status, String message})? refuse; // for writes
  final writes = <({String method, String path, Object? body})>[];
  int detailGets = 0;

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'GET' && o.path == ApiConstants.onboardingFieldConfig) {
      if (configStatus != 200) return _json(configStatus, {'status': 'error', 'message': 'Config unavailable.'});
      return _json(200, {'status': 'success', 'data': fieldConfig});
    }
    if (o.method == 'GET' && o.path == ApiConstants.employeeDetail(code)) {
      detailGets++;
      return _json(200, {'status': 'success', 'data': detail});
    }
    if (o.method != 'GET') {
      writes.add((method: o.method, path: o.path, body: o.data));
      final r = refuse;
      if (r != null) return _json(r.status, {'status': 'error', 'message': r.message, 'data': {}});
      if (o.method == 'PUT' && o.path == ApiConstants.employeeDetail(code)) {
        // EmployeeDetailView.put: merge custom_field_values into the stored dict
        final profile = Map<String, dynamic>.from(detail['profile'] as Map);
        final stored = Map<String, dynamic>.from(profile['custom_field_values'] as Map);
        stored.addAll(Map<String, dynamic>.from((o.data as Map)['custom_field_values'] as Map));
        detail = {...detail, 'profile': {...profile, 'custom_field_values': stored}};
        return _json(200, {'status': 'success', 'message': 'Employee updated.', 'data': detail});
      }
      if (o.method == 'POST' && o.path == ApiConstants.employeeCustomFileFields(code)) {
        return _json(201, {
          'status': 'success',
          'data': {'id': 9, 'field_key': 'cf_doc', 'file_url': 'https://files.example.test/9/', 'file_name': 'new.pdf', 'file_size': 10, 'uploaded_at': '2026-11-09T10:00:00Z'}
        });
      }
      if (o.method == 'DELETE') return _json(200, {'status': 'success', 'message': 'Deleted.', 'data': {}});
    }
    return _json(200, {'status': 'success', 'data': {'results': [], 'count': 0}});
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
PlatformFile? nextPick;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      onboardingFilePickerProvider.overrideWithValue(() async => nextPick),
    ];

Future<void> pumpDetail(WidgetTester tester, {UserEntity? as, Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? editor),
    child: const MaterialApp(home: EmployeeProfileScreen(employeeId: code)),
  ));
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(tester.element(find.byType(EmployeeProfileScreen)));
  await c.read(authStateProvider.future);
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));
String shown(WidgetTester tester, String key) => tester.widget<Text>(byKey('custom-value-$key')).data!;

Future<void> openSection(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

Future<void> openEdit(WidgetTester tester, int step) async {
  await tester.ensureVisible(byKey('custom-fields-edit-$step'));
  await tester.tap(byKey('custom-fields-edit-$step'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(byKey('custom-fields-save'));
  await tester.tap(byKey('custom-fields-save'));
  await tester.pumpAndSettle();
}

Finder field(String key) =>
    find.descendant(of: byKey('onboarding-field-$key'), matching: find.byType(TextField));

Map<String, dynamic> lastPutValues() => Map<String, dynamic>.from((server.writes.last.body as Map)['custom_field_values'] as Map);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('display (web applyFieldConfig: is_custom && visible, per section)', () {
    testWidgets('Personal shows its visible custom fields with saved values; hidden and built-ins are not added',
        (tester) async {
      await pumpDetail(tester);
      expect(byKey('custom-fields-0'), findsOneWidget);
      expect(shown(tester, 'cf_passport'), 'P123');
      expect(find.text('Label cf_passport *'), findsOneWidget, reason: 'required is flagged');
      expect(shown(tester, 'cf_shirt'), 'XL', reason: 'a value no longer in the options is still shown');
      expect(shown(tester, 'cf_vegan'), 'Yes', reason: 'checkbox "true"');
      expect(byKey('custom-field-cf_hidden'), findsNothing);
      expect(byKey('custom-field-gender'), findsNothing, reason: 'built-in fields are not custom');
    });

    testWidgets('Education, Bank and Emergency show theirs (date, textarea, number, unknown type, file)',
        (tester) async {
      await pumpDetail(tester);
      await openSection(tester, 'Education & Experience');
      expect(shown(tester, 'cf_cert_date'), '2026-01-10');
      expect(shown(tester, 'cf_notes'), '—');
      await openSection(tester, 'Bank Details');
      expect(shown(tester, 'cf_upi'), '42');
      expect(shown(tester, 'cf_rating'), '5', reason: 'an unknown type is shown as text, never dropped');
      await openSection(tester, 'Emergency Contact');
      expect(byKey('onboarding-file-cf_doc'), findsOneWidget);
      expect(find.textContaining('proof.pdf'), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget, reason: 'single-file field');
    });

    testWidgets('a section without custom fields shows no block; a config failure is reported, not fatal',
        (tester) async {
      await pumpDetail(tester, with_: Server()..configStatus = 500);
      expect(byKey('custom-fields-error-0'), findsOneWidget);
      expect(find.text('Pat Kumar'), findsWidgets, reason: 'the rest of the profile still renders');
    });
  });

  group('edit (employees.edit)', () {
    testWidgets('saving sends PUT {custom_field_values} with every configured text key — hidden kept, '
        'removed/file keys not sent, nothing else sent', (tester) async {
      await pumpDetail(tester);
      await openEdit(tester, 0);
      await tester.enterText(field('cf_passport'), 'P999');
      await save(tester);
      final w = server.writes.single;
      expect(w.method, 'PUT');
      expect(w.path, ApiConstants.employeeDetail(code));
      expect((w.body as Map).keys, ['custom_field_values'], reason: 'only custom values are sent');
      expect(lastPutValues(), {
        'cf_passport': 'P999',
        'cf_shirt': 'XL',
        'cf_vegan': 'true',
        'cf_hidden': 'keep-me',
        'cf_cert_date': '2026-01-10',
        'cf_notes': '',
        'cf_upi': '42',
        'cf_rating': '5',
      });
      // after save the profile reloads and shows the server's values
      expect(shown(tester, 'cf_passport'), 'P999');
      expect((server.detail['profile']['custom_field_values'] as Map)['cf_removed'], 'legacy value',
          reason: 'the backend merge keeps keys that were not sent');
    });

    testWidgets('dropdown keeps a stale saved value selectable; picking an option sends it', (tester) async {
      await pumpDetail(tester);
      await openEdit(tester, 0);
      expect(find.descendant(of: byKey('onboarding-field-cf_shirt'), matching: find.text('XL')), findsOneWidget);
      await tester.tap(byKey('onboarding-field-cf_shirt'));
      await tester.pumpAndSettle();
      expect(find.text('XL'), findsWidgets);
      await tester.tap(find.text('M').last);
      await tester.pumpAndSettle();
      await save(tester);
      expect(lastPutValues()['cf_shirt'], 'M');
    });

    testWidgets('checkbox sends "true"/"false"', (tester) async {
      await pumpDetail(tester);
      await openEdit(tester, 0);
      await tester.tap(find.descendant(of: byKey('onboarding-field-cf_vegan'), matching: find.byType(Checkbox)));
      await tester.pumpAndSettle();
      await save(tester);
      expect(lastPutValues()['cf_vegan'], 'false');
    });

    testWidgets('number and unknown-type fields edit as text (web)', (tester) async {
      await pumpDetail(tester);
      await openSection(tester, 'Bank Details');
      await openEdit(tester, 2);
      await tester.enterText(field('cf_upi'), '7');
      await tester.enterText(field('cf_rating'), 'great');
      await save(tester);
      expect([lastPutValues()['cf_upi'], lastPutValues()['cf_rating']], ['7', 'great']);
    });

    testWidgets('a required field left empty is flagged but, as web, does not block the save', (tester) async {
      await pumpDetail(tester);
      await openEdit(tester, 0);
      await tester.enterText(field('cf_passport'), '');
      await tester.pumpAndSettle();
      expect(find.text('Label cf_passport is required.'), findsOneWidget);
      await save(tester);
      expect(lastPutValues()['cf_passport'], '');
    });

    testWidgets('a server validation error keeps the sheet and every value; retry saves', (tester) async {
      final s = Server()..refuse = (status: 400, message: 'custom_field_values: invalid value.');
      await pumpDetail(tester, with_: s);
      await openEdit(tester, 0);
      await tester.enterText(field('cf_passport'), 'P555');
      await save(tester);
      expect(tester.widget<Text>(byKey('custom-fields-save-error')).data, 'custom_field_values: invalid value.');
      expect(tester.widget<TextField>(field('cf_passport')).controller!.text, 'P555');
      final gets = s.detailGets;
      s.refuse = null;
      await save(tester);
      expect(s.writes, hasLength(2));
      expect(lastPutValues()['cf_passport'], 'P555');
      expect(byKey('custom-fields-save'), findsNothing, reason: 'closed on success');
      expect(s.detailGets, greaterThan(gets), reason: 'reloaded after the save');
    });

    testWidgets('an employee outside the editor\'s branch scope (server 404) shows the refusal', (tester) async {
      await pumpDetail(tester, with_: Server()..refuse = (status: 404, message: 'Employee not found.'));
      await openEdit(tester, 0);
      await save(tester);
      expect(tester.widget<Text>(byKey('custom-fields-save-error')).data, 'Employee not found.');
    });

    testWidgets('file field: upload sends {field_key, file} to the employee endpoint; Remove deletes the value',
        (tester) async {
      await pumpDetail(tester);
      await openSection(tester, 'Emergency Contact');
      nextPick = PlatformFile(name: 'new.pdf', size: 4, bytes: Uint8List.fromList([37, 80, 68, 70]));
      await tester.ensureVisible(find.text('Replace'));
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      final up = server.writes.firstWhere((w) => w.method == 'POST');
      expect(up.path, ApiConstants.employeeCustomFileFields(code));
      final form = up.body as FormData;
      expect({for (final f in form.fields) f.key: f.value}, {'field_key': 'cf_doc'});
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'new.pdf');

      await tester.tap(find.byTooltip('Remove').first);
      await tester.pumpAndSettle();
      expect(server.writes.last.method, 'DELETE');
      expect(server.writes.last.path, ApiConstants.onboardingCustomFileFieldDetail(5));
      nextPick = null;
    });
  });

  group('permission', () {
    testWidgets('without employees.edit: values shown, no Edit, files read-only', (tester) async {
      await pumpDetail(tester, as: viewer);
      expect(shown(tester, 'cf_passport'), 'P123');
      expect(byKey('custom-fields-edit-0'), findsNothing);
      await openSection(tester, 'Emergency Contact');
      expect(byKey('custom-file-readonly-cf_doc'), findsOneWidget);
      expect(byKey('onboarding-file-cf_doc'), findsNothing);
    });

    testWidgets('the actions refuse without employees.edit, before any request', (tester) async {
      server = Server();
      late WidgetRef ref;
      await tester.pumpWidget(ProviderScope(
        overrides: overrides(viewer),
        child: MaterialApp(home: Consumer(builder: (context, r, _) {
          ref = r;
          r.watch(authStateProvider);
          return const SizedBox();
        })),
      ));
      await tester.pumpAndSettle();
      // real async, so a missing guard fails here instead of hanging
      final results = await tester.runAsync(() async => [
            await saveEmployeeCustomFields(ref, code, {'cf_passport': 'X'}),
            await uploadEmployeeCustomFile(ref, code, 'cf_doc', 'a.pdf', [1]),
            await deleteEmployeeCustomFile(ref, code, 5),
          ]);
      expect(results, [kCustomFieldsEditDenied, kCustomFieldsEditDenied, kCustomFieldsEditDenied]);
      expect(server.writes, isEmpty);
    });
  });

  group('model and payload helpers', () {
    test('the employee model keeps every saved custom value (including unknown keys) and the file values', () {
      final e = EmployeeModel.fromJson(employee());
      expect(e.customFieldValues['cf_removed'], 'legacy value');
      expect(e.customFieldValues['cf_hidden'], 'keep-me');
      expect(e.customFileFields.single.fileUrl, 'https://files.example.test/5/');
      expect(e.customFileFields.single.fieldKey, 'cf_doc');
      final bare = EmployeeModel.fromJson(const {'id': 'x', 'employee_id': 'E1', 'profile': <String, dynamic>{}});
      expect([bare.customFieldValues, bare.customFileFields], [isEmpty, isEmpty]);
      // non-string values are kept as text, never dropped
      final odd = EmployeeModel.fromJson(const <String, dynamic>{
        'profile': <String, dynamic>{
          'custom_field_values': <String, dynamic>{'n': 3, 'b': true, 'z': null}
        }
      });
      expect(odd.customFieldValues, {'n': '3', 'b': 'true', 'z': ''});
    });

    test('payload = every configured text key (edit > saved > ""), no file keys, no unknown keys', () {
      final config = OnboardingConfig.parseFields(fieldConfig);
      final payload = employeeCustomFieldsPayload(config, {'cf_passport': 'P1', 'cf_removed': 'x'}, {'cf_upi': '9'});
      expect(payload.keys.toSet(),
          {'cf_passport', 'cf_shirt', 'cf_vegan', 'cf_hidden', 'cf_cert_date', 'cf_notes', 'cf_upi', 'cf_rating'});
      expect([payload['cf_passport'], payload['cf_upi'], payload['cf_shirt']], ['P1', '9', '']);
      expect(customFieldsForStep(config, 0).map((c) => c.fieldKey), ['cf_passport', 'cf_shirt', 'cf_vegan']);
    });
  });
}
