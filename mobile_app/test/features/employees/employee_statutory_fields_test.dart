import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/domain/employee_profile_sections.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';

// Task 43 (audit C-E15): HR Employee Profile → EPF / Statutory — web
// employees/_data.ts "epf" (uan_number, name_as_per_aadhar, esi_number),
// saved via PUT /employees/<code>/ (EmployeeDetailView → _PROFILE_FIELD_KEYS →
// EmployeeProfileSerializer partial: plain strings, max 255, blank allowed,
// employees.edit + branch scope). Production's detail GET (_employee_dict)
// does NOT return these keys; this stand-in mirrors that by default, keeping
// what was PUT in [Server.stored] without echoing it. Mobile sends only the
// statutory fields actually changed (agreed for Task 43). Fictitious values
// only; no real employee is changed.

const code = 'EMP-43';
const detailPath = '/employees/$code/';
const fakeUan = '100000000001'; // fictitious
const fakeAadharName = 'TEST PERSON NAME'; // fictitious
const fakeEsi = '9000000001'; // fictitious

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class Server implements HttpClientAdapter {
  /// What the database holds (never shown unless [returnStatutory]).
  Map<String, String> stored = {'uan_number': fakeUan, 'name_as_per_aadhar': fakeAadharName, 'esi_number': fakeEsi};

  /// Production returns none of the statutory keys; true simulates a server
  /// that does.
  bool returnStatutory = false;
  ({int status, String message, Map<String, dynamic> data})? refuse;
  final puts = <Map<String, dynamic>>[];

  Map<String, dynamic> _employee() => {
        'id': 'u43',
        'uuid': 'uuid-43',
        'employee_id': code,
        'first_name': 'Ria',
        'last_name': 'Test',
        'full_name': 'Ria Test',
        'email': 'ria.test@example.test',
        'department': 'QA',
        'designation': 'Analyst',
        'branch': 'North',
        'role': 'employee',
        'is_active': true,
        'status': 'active',
        'onboarding_status': 'complete',
        'documents': <Object>[],
        'profile': {
          'bank_name': 'Test Bank',
          'custom_field_values': <String, dynamic>{},
          if (returnStatutory) ...stored,
        },
      };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == detailPath && o.method == 'GET') return _json(200, {'status': 'success', 'data': _employee()});
    if (o.path == detailPath && o.method == 'PUT') {
      final body = Map<String, dynamic>.from(o.data as Map);
      puts.add(body);
      final r = refuse;
      if (r != null) return _json(r.status, {'status': 'error', 'message': r.message, 'data': r.data});
      for (final k in const ['uan_number', 'name_as_per_aadhar', 'esi_number']) {
        if (body.containsKey(k)) stored[k] = '${body[k]}';
      }
      return _json(200, {'status': 'success', 'message': 'Employee updated.', 'data': _employee()});
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
Finder byKey(String k) => find.byKey(Key(k));

Future<void> pumpProfile(WidgetTester tester,
    {UserEntity? as, Server? with_, Size size = const Size(1080, 4000), double dpr = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
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
  final chip = find.text('EPF / Statutory').first;
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> openEditor(WidgetTester tester) async {
  await tester.tap(byKey('profile-edit-statutory'));
  await tester.pumpAndSettle();
}

String shown(WidgetTester tester, String key) => tester
    .widgetList<Text>(find.descendant(of: byKey('profile-field-$key'), matching: find.byType(Text)))
    .map((t) => t.data)
    .last!;

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(byKey('section-field-$key')).controller!.text;

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

/// Opacity of [hint] inside field [key]: InputDecorator keeps the hint Text in
/// the tree and fades it, so "visible" means opacity 1, not just present.
double hintOpacity(WidgetTester tester, String key, String hint) {
  final text = find.descendant(of: byKey('section-field-$key'), matching: find.text(hint));
  expect(text, findsOneWidget, reason: 'hint "$hint" rendered in $key');
  return tester
      .widgetList<AnimatedOpacity>(find.ancestor(of: text, matching: find.byType(AnimatedOpacity)))
      .first
      .opacity;
}

const hints = {
  'uan_number': ('UAN Number', '12-digit Universal Account Number'),
  'name_as_per_aadhar': ('Name as per Aadhar', 'Exactly as printed on Aadhaar card'),
  'esi_number': ('ESI Number', '10-digit ESI Insurance Number (IP Number)'),
};

Map<String, dynamic> detail({Map<String, dynamic>? profile}) => {
      'id': 'u43',
      'employee_id': code,
      'full_name': 'Ria Test',
      'email': '',
      'profile': profile ?? <String, dynamic>{},
    };

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model', () {
    test('profile keys parsed when present; statutoryReturned tells whether the server sent them', () {
      final e = EmployeeModel.fromJson(
          detail(profile: {'uan_number': fakeUan, 'name_as_per_aadhar': fakeAadharName, 'esi_number': fakeEsi}));
      expect(
          (e.uanNumber, e.nameAsPerAadhar, e.esiNumber, e.statutoryReturned), (fakeUan, fakeAadharName, fakeEsi, true));
      final absent = EmployeeModel.fromJson(detail(profile: {'bank_name': 'Test Bank'}));
      expect(
          (absent.uanNumber, absent.nameAsPerAadhar, absent.esiNumber, absent.statutoryReturned), ('', '', '', false));
      final nulls = EmployeeModel.fromJson(detail(profile: {'uan_number': null, 'esi_number': ''}));
      expect((nulls.uanNumber, nulls.esiNumber, nulls.statutoryReturned), ('', '', true));
      final noProfile = EmployeeModel.fromJson(const {'employee_id': code, 'full_name': 'X'});
      expect(noProfile.statutoryReturned, isFalse);
      // copyWith keeps them.
      expect(e.copyWith().uanNumber, fakeUan);
      expect(e.copyWith().statutoryReturned, isTrue);
    });
  });

  group('section definition and payload', () {
    test('web labels, placeholders and backend keys; not tied to Onboarding Fields', () {
      final def = kEmployeeProfileSections[EmployeeProfileSection.statutory]!;
      expect(def.title, 'EPF / Statutory');
      expect(def.step, isNull);
      expect(def.fields.map((f) => (f.key, f.label, f.placeholder, f.required)), [
        ('uan_number', 'UAN Number', '12-digit Universal Account Number', false),
        ('name_as_per_aadhar', 'Name as per Aadhar', 'Exactly as printed on Aadhaar card', false),
        ('esi_number', 'ESI Number', '10-digit ESI Insurance Number (IP Number)', false),
      ]);
      expect(isProfileFieldVisible(EmployeeProfileSection.statutory, 'uan_number', const {}), isTrue);
    });

    test('statutory payload: only changed fields; a value changed to blank is sent as ""', () {
      const s = EmployeeProfileSection.statutory;
      const blank = {'uan_number': '', 'name_as_per_aadhar': '', 'esi_number': ''};
      expect(profileSectionPayload(s, blank, initial: blank), isEmpty);
      expect(profileSectionPayload(s, {...blank, 'uan_number': fakeUan}, initial: blank), {'uan_number': fakeUan});
      const known = {'uan_number': fakeUan, 'name_as_per_aadhar': fakeAadharName, 'esi_number': fakeEsi};
      expect(profileSectionPayload(s, {...known, 'esi_number': ''}, initial: known), {'esi_number': ''});
      expect(profileSectionPayload(s, known, initial: known), isEmpty);
    });

    test('other sections are unchanged: every key sent', () {
      final p = profileSectionPayload(EmployeeProfileSection.bank, const {'bank_name': 'X'},
          initial: const {'bank_name': 'X'});
      expect(p.keys, containsAll(['account_holder_name', 'account_type', 'bank_name', 'bank_branch_name']));
    });
  });

  group('profile', () {
    testWidgets('1. EPF / Statutory section between Emergency Contact and Documents; blanks and the server note',
        (tester) async {
      await pumpProfile(tester);
      double x(String t) => tester.getTopLeft(find.text(t).first).dx;
      expect(x('Emergency Contact') < x('EPF / Statutory') && x('EPF / Statutory') < x('Documents'), isTrue);
      expect(shown(tester, 'uan_number'), '—');
      expect(shown(tester, 'name_as_per_aadhar'), '—');
      expect(shown(tester, 'esi_number'), '—');
      expect(find.text('UAN Number'), findsOneWidget);
      expect(find.text('Name as per Aadhar'), findsOneWidget);
      expect(find.text('ESI Number'), findsOneWidget);
      expect(byKey('profile-statutory-not-returned'), findsOneWidget);
    });

    testWidgets('2. filling one field sends exactly that key; values nobody touched stay stored', (tester) async {
      await pumpProfile(tester);
      await openEditor(tester);
      expect(byKey('section-edit-statutory-hint'), findsOneWidget);
      expect(fieldText(tester, 'uan_number'), '');
      await type(tester, 'uan_number', '100000000099');
      await save(tester);
      expect(server.puts.single, {'uan_number': '100000000099'});
      expect(server.stored['name_as_per_aadhar'], fakeAadharName, reason: 'not wiped');
      expect(server.stored['esi_number'], fakeEsi, reason: 'not wiped');
      expect(byKey('section-edit-statutory'), findsNothing, reason: 'sheet closed after saving');
    });

    testWidgets('3. all three filled: all three sent with the exact backend keys', (tester) async {
      await pumpProfile(tester);
      await openEditor(tester);
      await type(tester, 'uan_number', '100000000002');
      await type(tester, 'name_as_per_aadhar', 'ANOTHER TEST NAME');
      await type(tester, 'esi_number', '9000000002');
      await save(tester);
      expect(server.puts.single,
          {'uan_number': '100000000002', 'name_as_per_aadhar': 'ANOTHER TEST NAME', 'esi_number': '9000000002'});
    });

    testWidgets('4. nothing entered: "No changes to save." and no request', (tester) async {
      await pumpProfile(tester);
      await openEditor(tester);
      await save(tester);
      expect(find.text('No changes to save.'), findsOneWidget);
      expect(server.puts, isEmpty);
      await tester.tap(byKey('section-edit-cancel'));
      await tester.pumpAndSettle();
      expect(server.puts, isEmpty);
    });

    testWidgets('5. a server that returns the values: shown, prefilled, and clearing one sends ""', (tester) async {
      await pumpProfile(tester, with_: Server()..returnStatutory = true);
      expect(shown(tester, 'esi_number'), fakeEsi);
      expect(byKey('profile-statutory-not-returned'), findsNothing);
      await openEditor(tester);
      expect(byKey('section-edit-statutory-hint'), findsNothing);
      expect(fieldText(tester, 'uan_number'), fakeUan);
      expect(fieldText(tester, 'name_as_per_aadhar'), fakeAadharName);
      await type(tester, 'esi_number', '');
      await save(tester);
      expect(server.puts.single, {'esi_number': ''});
      expect(server.stored['uan_number'], fakeUan);
    });

    testWidgets('6. server validation error: shown on the field, entered values kept for a retry', (tester) async {
      final s = Server()
        ..refuse = (
          status: 400,
          message: 'uan_number: Ensure this field has no more than 255 characters.',
          data: {
            'uan_number': ['Ensure this field has no more than 255 characters.']
          },
        );
      await pumpProfile(tester, with_: s);
      await openEditor(tester);
      await type(tester, 'uan_number', '1' * 256);
      await save(tester);
      expect(find.text('Ensure this field has no more than 255 characters.'), findsWidgets);
      expect(fieldText(tester, 'uan_number'), '1' * 256);
      expect(byKey('section-edit-statutory'), findsOneWidget);
    });

    testWidgets('7. out of branch scope (404) or no employees.edit (403): the server message, nothing stored',
        (tester) async {
      final s = Server()..refuse = (status: 404, message: 'Employee not found.', data: <String, dynamic>{});
      await pumpProfile(tester, with_: s);
      await openEditor(tester);
      await type(tester, 'esi_number', '9000000003');
      await save(tester);
      expect(find.text('Employee not found.'), findsOneWidget);
      expect(s.stored['esi_number'], fakeEsi);
    });

    testWidgets('8. viewer without employees.edit: section visible, no Edit, nothing sent', (tester) async {
      await pumpProfile(tester, as: viewer);
      expect(find.text('UAN Number'), findsOneWidget);
      expect(byKey('profile-edit-statutory'), findsNothing);
      expect(server.puts, isEmpty);
    });

    testWidgets('9. statutory values never reach debug output while editing and saving', (tester) async {
      final printed = <String>[];
      final original = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => printed.add(m ?? '');
      try {
        await pumpProfile(tester, with_: Server()..returnStatutory = true);
        await openEditor(tester);
        await type(tester, 'uan_number', '100000000077');
        await save(tester);
      } finally {
        debugPrint = original;
      }
      final all = printed.join('\n');
      for (final v in [fakeUan, fakeAadharName, fakeEsi, '100000000077']) {
        expect(all.contains(v), isFalse);
      }
    });

    testWidgets('10. Task 53: empty fields show web\'s placeholder (visible, unfocused) under the floating label',
        (tester) async {
      await pumpProfile(tester);
      await openEditor(tester);
      for (final MapEntry(key: k, value: (label, hint)) in hints.entries) {
        expect(find.descendant(of: byKey('section-field-$k'), matching: find.text(label)), findsOneWidget);
        expect(hintOpacity(tester, k, hint), 1.0, reason: '$k hint readable before tapping');
        final dec = tester.widget<InputDecorator>(
            find.descendant(of: byKey('section-field-$k'), matching: find.byType(InputDecorator)));
        expect(dec.decoration.floatingLabelBehavior, FloatingLabelBehavior.always);
      }
      // Typing hides that field's hint (as a web placeholder); clearing brings it back.
      await type(tester, 'uan_number', '1');
      await tester.pumpAndSettle();
      expect(hintOpacity(tester, 'uan_number', hints['uan_number']!.$2), 0.0);
      expect(hintOpacity(tester, 'esi_number', hints['esi_number']!.$2), 1.0);
      await type(tester, 'uan_number', '');
      await tester.pumpAndSettle();
      expect(hintOpacity(tester, 'uan_number', hints['uan_number']!.$2), 1.0);
    });

    testWidgets('11. Task 53: populated fields show the stored values, not the hints', (tester) async {
      await pumpProfile(tester, with_: Server()..returnStatutory = true);
      await openEditor(tester);
      for (final MapEntry(key: k, value: (_, hint)) in hints.entries) {
        expect(hintOpacity(tester, k, hint), 0.0, reason: k);
      }
      expect(fieldText(tester, 'esi_number'), fakeEsi);
    });

    testWidgets('12. Task 53: phone screen with the keyboard open: hints readable, fields reachable, saves',
        (tester) async {
      await pumpProfile(tester, size: const Size(1080, 2400), dpr: 2.625);
      // The profile AppBar (title + ID Card + Reset Password + bell) overflows
      // at 411 dp only with the test font's square glyphs; on the Pixel_8 it
      // fits (title ellipsised). Not this form — clear it before checking.
      final appBar = tester.takeException();
      expect(appBar == null || '$appBar'.contains('overflowed'), isTrue);
      await openEditor(tester);
      expect(tester.takeException(), isNull, reason: 'editor opens without layout errors');
      tester.view.viewInsets = const FakeViewPadding(bottom: 900); // ~343 dp keyboard
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow with the keyboard open');
      const keyboardTop = (2400 - 900) / 2.625;
      for (final MapEntry(key: k, value: (_, hint)) in hints.entries) {
        await tester.ensureVisible(byKey('section-field-$k'));
        await tester.pumpAndSettle();
        expect(tester.getRect(byKey('section-field-$k')).bottom, lessThanOrEqualTo(keyboardTop), reason: k);
        expect(hintOpacity(tester, k, hint), 1.0, reason: k);
      }
      expect(tester.getRect(byKey('section-edit-save')).bottom, lessThanOrEqualTo(keyboardTop),
          reason: 'Save stays above the keyboard');
      await type(tester, 'esi_number', '9000000004');
      await save(tester);
      expect(server.puts.single, {'esi_number': '9000000004'});
    });
  });
}
