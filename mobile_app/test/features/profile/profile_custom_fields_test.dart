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
import 'package:mobile_app/features/onboarding/data/models/onboarding_config_models.dart';
import 'package:mobile_app/features/onboarding/presentation/widgets/onboarding_custom_file_field.dart';
import 'package:mobile_app/features/profile/data/models/my_profile_model.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/features/profile/presentation/widgets/profile_custom_fields.dart';

// P1-8: custom fields on My Profile, as web dashboard/profile/ProfileClient.tsx
// (local web branch): Personal/Education/Bank custom fields read-only;
// Emergency (step 3) editable — PATCH /employees/me/ {custom_field_values}
// limited to Emergency custom text keys (backend MyProfileView.patch filters
// to them and merges); Emergency file fields via /onboarding/custom-file-fields/
// (other steps read-only after onboarding — _self_can_write_custom_file).
// Mocked Dio, synthetic profile — nothing is written.

Map<String, dynamic> c(String key, String type, int step, {int order = 0}) => {
      'field_key': key,
      'label': 'Label $key',
      'field_type': type,
      'options': <String>[],
      'allow_multiple': false,
      'step': step,
      'order': order,
      'visible': true,
      'required': false,
      'is_custom': true,
      'is_locked': false,
    };

final config = {
  '0': [c('cf_passport', 'text', 0), c('cf_id_scan', 'file', 0, order: 1)],
  '3': [c('cf_kin_note', 'textarea', 3), c('cf_kin_ok', 'checkbox', 3, order: 1), c('cf_kin_doc', 'file', 3, order: 2)],
};

class Server implements HttpClientAdapter {
  Map<String, dynamic> custom = {'cf_passport': 'P123', 'cf_kin_note': 'call first', 'cf_kin_ok': 'false', 'cf_old': 'x'};
  final files = <Map<String, dynamic>>[
    {'id': 3, 'field_key': 'cf_id_scan', 'file_url': 'https://files.example.test/3/', 'file_name': 'id.png', 'file_size': 900},
  ];
  int? failStatus;
  final writes = <({String method, String path, Object? body})>[];
  int meGets = 0;

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'GET' && o.path == ApiConstants.myProfile) {
      meGets++;
      return _json(200, {
        'status': 'success',
        'data': {
          'id': 'u1',
          'full_name': 'Pat Kumar',
          'employee_id': 'EMP-7',
          'onboarding_status': 'complete',
          'profile': {'custom_field_values': custom},
        }
      });
    }
    if (o.method == 'GET' && o.path == ApiConstants.onboardingFieldConfig) {
      return _json(200, {'status': 'success', 'data': config});
    }
    if (o.method == 'GET' && o.path == ApiConstants.onboardingCustomFileFields) {
      return _json(200, {'status': 'success', 'data': files});
    }
    if (o.method != 'GET') {
      writes.add((method: o.method, path: o.path, body: o.data));
      if (failStatus != null) return _json(failStatus!, {'status': 'error', 'message': 'Could not save.', 'data': {}});
      if (o.method == 'PATCH' && o.path == ApiConstants.myProfile) {
        // MyProfileView.patch: Emergency custom keys only, merged
        final incoming = Map<String, dynamic>.from((o.data as Map)['custom_field_values'] as Map);
        custom = {...custom, ...{for (final e in incoming.entries) if (e.key.startsWith('cf_kin_')) e.key: e.value}};
        return _json(200, {'status': 'success', 'message': 'Profile updated.', 'data': {}});
      }
      if (o.method == 'POST' && o.path == ApiConstants.onboardingCustomFileFields) {
        files.add({'id': 8, 'field_key': 'cf_kin_doc', 'file_url': 'https://files.example.test/8/', 'file_name': 'kin.pdf', 'file_size': 4});
        return _json(201, {'status': 'success', 'data': files.last});
      }
      if (o.method == 'DELETE') return _json(200, {'status': 'success', 'data': {}});
    }
    return _json(404, {'status': 'error', 'message': 'Not found'});
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

late Server server;
PlatformFile? nextPick;

Future<void> pumpProfile(WidgetTester tester, {Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      onboardingFilePickerProvider.overrideWithValue(() async => nextPick),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Consumer(builder: (context, ref, _) {
            final p = ref.watch(myProfileProvider).valueOrNull;
            if (p == null) return const SizedBox();
            return Column(children: [
              ProfileCustomFields(step: 0, values: p.detail.customFieldValues),
              ProfileCustomFields(step: 3, values: p.detail.customFieldValues),
            ]);
          }),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  // The custom-field blocks mount once the profile has loaded and then
  // fetch their own config/files — let those settle too.
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));
String shown(WidgetTester tester, String key) => tester.widget<Text>(byKey('custom-value-$key')).data!;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Personal custom fields are read-only (no Edit; files listed, not uploadable)', (tester) async {
    await pumpProfile(tester);
    expect(shown(tester, 'cf_passport'), 'P123');
    expect(byKey('custom-fields-edit-0'), findsNothing);
    expect(byKey('custom-file-readonly-cf_id_scan'), findsOneWidget);
    expect(find.text('id.png'), findsOneWidget);
    expect(byKey('onboarding-file-cf_id_scan'), findsNothing);
  });

  testWidgets('Emergency custom fields save with PATCH /employees/me/ (Emergency keys only) and reload',
      (tester) async {
    await pumpProfile(tester);
    expect(shown(tester, 'cf_kin_note'), 'call first');
    expect(shown(tester, 'cf_kin_ok'), 'No');
    final gets = server.meGets;
    await tester.tap(byKey('custom-fields-edit-3'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(of: byKey('onboarding-field-cf_kin_note'), matching: find.byType(TextField)), 'text only');
    await tester.tap(find.descendant(of: byKey('onboarding-field-cf_kin_ok'), matching: find.byType(Checkbox)));
    await tester.pumpAndSettle();
    await tester.tap(byKey('custom-fields-save'));
    await tester.pumpAndSettle();

    final w = server.writes.single;
    expect(w.method, 'PATCH');
    expect(w.path, ApiConstants.myProfile);
    expect(w.body, {
      'custom_field_values': {'cf_kin_note': 'text only', 'cf_kin_ok': 'true'}
    });
    expect(server.meGets, greaterThan(gets));
    expect(shown(tester, 'cf_kin_note'), 'text only');
    expect(shown(tester, 'cf_kin_ok'), 'Yes');
    expect(server.custom['cf_old'], 'x', reason: 'unsent keys are kept');
  });

  testWidgets('a failed save keeps the sheet and the typed value; retry saves', (tester) async {
    await pumpProfile(tester, with_: Server()..failStatus = 400);
    await tester.tap(byKey('custom-fields-edit-3'));
    await tester.pumpAndSettle();
    final note = find.descendant(of: byKey('onboarding-field-cf_kin_note'), matching: find.byType(TextField));
    await tester.enterText(note, 'retry me');
    await tester.tap(byKey('custom-fields-save'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(byKey('custom-fields-save-error')).data, 'Could not save.');
    expect(tester.widget<TextField>(note).controller!.text, 'retry me');
    server.failStatus = null;
    await tester.tap(byKey('custom-fields-save'));
    await tester.pumpAndSettle();
    expect(server.writes, hasLength(2));
    expect(shown(tester, 'cf_kin_note'), 'retry me');
  });

  testWidgets('an Emergency file field uploads to /onboarding/custom-file-fields/ and refreshes the list',
      (tester) async {
    await pumpProfile(tester);
    nextPick = PlatformFile(name: 'kin.pdf', size: 4, bytes: Uint8List.fromList([37, 80, 68, 70]));
    await tester.ensureVisible(find.descendant(of: byKey('onboarding-file-cf_kin_doc'), matching: find.text('Upload')));
    await tester.tap(find.descendant(of: byKey('onboarding-file-cf_kin_doc'), matching: find.text('Upload')));
    await tester.pumpAndSettle();
    final up = server.writes.single;
    expect(up.path, ApiConstants.onboardingCustomFileFields);
    expect({for (final f in (up.body as FormData).fields) f.key: f.value}, {'field_key': 'cf_kin_doc'});
    expect(find.textContaining('kin.pdf'), findsOneWidget);
    nextPick = null;
  });

  test('the self payload keeps only Emergency text keys', () {
    final cfg = OnboardingConfig.parseFields(config);
    expect(
      selfCustomFieldsPayload(cfg, {'cf_passport': 'X', 'cf_kin_note': 'n', 'cf_kin_doc': 'f', 'cf_unknown': 'u'}),
      {'cf_kin_note': 'n'},
    );
  });

  test('the profile model reads custom_field_values; an ordinary profile save keeps them', () {
    final p = MyProfileModel.fromJson({
      'id': 'u1',
      'profile': <String, dynamic>{
        'custom_field_values': <String, dynamic>{'cf_a': 'A', 'cf_n': 2}
      },
    });
    expect(p.detail.customFieldValues, {'cf_a': 'A', 'cf_n': '2'});
    final updated = p.applyUpdate(MyProfileUpdateData(
      phone: '9',
      currentAddress: 'c',
      permanentAddress: 'p',
      emergencyName: 'n',
      emergencyRelationship: 'r',
      emergencyPhone: '1',
      emergencyEmail: 'e@example.test',
    ));
    expect(updated.detail.customFieldValues, {'cf_a': 'A', 'cf_n': '2'});
  });
}
