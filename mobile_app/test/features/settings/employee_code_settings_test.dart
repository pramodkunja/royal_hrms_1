import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/data/models/employee_code_model.dart';
import 'package:mobile_app/features/settings/presentation/employee_code/employee_code_screen.dart';
import 'package:mobile_app/features/settings/presentation/providers/settings_providers.dart';

// Task 48 (C-ST04): Settings → Employee ID Format, as web
// app/dashboard/settings/employee-code/page.tsx against production
// GET/PUT /settings/employee-code/ (EmployeeCodeSettingsView: CanManageRoles =
// settings.edit; EmployeeCodeSettingsSerializer: prefix letters-only stored
// uppercase, padding 3–8, next_sequence ≥ 1, errors {message, data:{field:
// [msg]}}). Codes are generated server-side as prefix + DDMM + initials.
// A stand-in server; fictitious values; nothing real changes.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class Server implements HttpClientAdapter {
  Map<String, dynamic> stored = {
    'prefix': 'RSS',
    'padding': 5,
    'next_sequence': 1,
    'format_description': 'RSS00001  (prefix + 5-digit sequence, next = 1)',
  };
  int gets = 0;
  int? failGets; // how many GETs fail with 500
  ({int status, Map<String, dynamic> body})? refuse;
  final puts = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == '/settings/employee-code/' && o.method == 'GET') {
      gets++;
      if (failGets != null && gets <= failGets!) {
        return _json(500, {'status': 'error', 'message': 'Server error.', 'data': {}});
      }
      return _json(200, {'status': 'success', 'message': 'Employee code settings retrieved.', 'data': stored});
    }
    if (o.path == '/settings/employee-code/' && o.method == 'PUT') {
      final body = Map<String, dynamic>.from(o.data as Map);
      puts.add(body);
      final r = refuse;
      if (r != null) return _json(r.status, r.body);
      stored = {...stored, ...body};
      return _json(200, {'status': 'success', 'message': 'Employee code settings updated.', 'data': stored});
    }
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
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

UserEntity user(List<String> perms) => UserEntity(
      id: 'a1',
      email: 'admin@example.test',
      fullName: 'Test Admin',
      role: 'system_admin',
      roleDisplay: 'Admin',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final editor = user(['settings.view', 'settings.edit']);
final viewer = user(['settings.view']);

late Server server;
Finder byKey(String k) => find.byKey(Key(k));

Future<void> pump(WidgetTester tester, {Server? with_, UserEntity? as}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? editor)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => const EmployeeCodeScreen())]),
    ),
  ));
  await tester.pumpAndSettle();
}

String prefixText(WidgetTester tester) => tester.widget<TextField>(byKey('employee-code-prefix')).controller!.text;
String? prefixError(WidgetTester tester) =>
    tester.widget<TextField>(byKey('employee-code-prefix')).decoration!.errorText;
bool enabled(WidgetTester tester, String key) {
  final w = tester.widget(byKey(key));
  return w is ButtonStyleButton ? w.onPressed != null : false;
}

List<String> previewCodes(WidgetTester tester) => [
      for (var i = 0; i < 3; i++)
        tester
            .widgetList<Text>(find.descendant(of: byKey('employee-code-preview-$i'), matching: find.byType(Text)))
            .first
            .data!,
    ];

Future<void> typePrefix(WidgetTester tester, String v) async {
  await tester.enterText(byKey('employee-code-prefix'), v);
  await tester.pump();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(byKey('employee-code-save'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules', () {
    test('parsing: values kept as sent; missing or wrongly-typed ones are null/blank, never defaulted', () {
      final s = EmployeeCodeSettings.fromJson(
          const {'prefix': 'RSS', 'padding': 6, 'next_sequence': 42, 'format_description': 'old sequence text'});
      expect((s.prefix, s.padding, s.nextSequence), ('RSS', 6, 42));
      final legacy = EmployeeCodeSettings.fromJson(const {'prefix': 'R-S'});
      expect((legacy.prefix, legacy.padding, legacy.nextSequence), ('R-S', null, null));
      final odd = EmployeeCodeSettings.fromJson(const {'prefix': 7, 'padding': '5', 'next_sequence': null});
      expect((odd.prefix, odd.padding, odd.nextSequence), ('', null, null));
    });

    test('payload: web onSave (trim + uppercase); padding / next_sequence carried, left out when unknown', () {
      const s = EmployeeCodeSettings(prefix: 'RSS', padding: 9, nextSequence: 0);
      // Task 63: id_format is always sent (web onSave).
      expect(s.toPayload('  abc ', 'date_initials'),
          {'prefix': 'ABC', 'id_format': 'date_initials', 'padding': 9, 'next_sequence': 0},
          reason: 'carried unchanged even out of range — never "fixed" silently');
      expect(const EmployeeCodeSettings(prefix: 'X').toPayload('xy', 'first_date_last'),
          {'prefix': 'XY', 'id_format': 'first_date_last'});
    });

    test('validation: required, ASCII letters only (trimmed); 1 and 10 letters fine', () {
      expect(validateEmployeeCodePrefix(''), 'Prefix is required.');
      expect(validateEmployeeCodePrefix('   '), 'Prefix is required.');
      for (final ok in ['A', 'rss', 'RsS', ' EMP ', 'ABCDEFGHIJ']) {
        expect(validateEmployeeCodePrefix(ok), isNull, reason: ok);
      }
      for (final bad in ['R1', 'R-S', 'R S', 'RS_', 'ÉMP', '1']) {
        expect(validateEmployeeCodePrefix(bad), 'Prefix must contain letters only.', reason: bad);
      }
      expect(kEmployeeCodePrefixMaxLength, 10);
    });

    test('preview: web examples with the typed prefix (trimmed, uppercased; EMP while empty)', () {
      List<String> codes(String p) => employeeCodePreview(p).map((r) => r.code).toList();
      expect(codes(''), ['EMP0308TG', 'EMP1509RK', 'EMP1509RK2']);
      expect(codes(' rss '), ['RSS0308TG', 'RSS1509RK', 'RSS1509RK2']);
      final rows = employeeCodePreview('RSS');
      expect(rows.map((r) => r.label),
          ['Teerdaveni Gedela (joined 03 Aug)', 'Ravi Kumar (joined 15 Sep)', 'Rahul Kumar (joined 15 Sep)']);
      expect(rows.map((r) => r.note),
          [null, null, 'Same day + same initials as above — a 2 is appended to keep it unique']);
    });

    test('permission: settings.edit only', () {
      expect(canManageEmployeeCode(editor), isTrue);
      expect(canManageEmployeeCode(viewer), isFalse);
      expect(canManageEmployeeCode(null), isFalse);
    });
  });

  group('screen', () {
    testWidgets('1. existing settings: prefix shown, preview from it, Save/Cancel disabled until a change',
        (tester) async {
      await pump(tester);
      expect(find.text('Configure the prefix used for new employee codes'), findsOneWidget);
      expect(prefixText(tester), 'RSS');
      expect(previewCodes(tester), ['RSS0308TG', 'RSS1509RK', 'RSS1509RK2']);
      expect(find.text('Letters only, max 10 characters. Saved as uppercase.'), findsOneWidget);
      // Task 63: web's per-format description (date_initials when unset).
      expect(find.text('Format: prefix + date of joining (DDMM) + first and last name initials. Example IDs:'),
          findsOneWidget);
      expect(enabled(tester, 'employee-code-save'), isFalse);
      expect(enabled(tester, 'employee-code-cancel'), isFalse);
      expect(find.textContaining('5-digit sequence'), findsNothing, reason: 'stale format_description not shown');
      expect(find.text('Padding'), findsNothing);
    });

    testWidgets('2. typing updates the preview live; Cancel restores and disables again; nothing sent', (tester) async {
      await pump(tester);
      await typePrefix(tester, ' abc');
      expect(previewCodes(tester), ['ABC0308TG', 'ABC1509RK', 'ABC1509RK2']);
      expect(enabled(tester, 'employee-code-save'), isTrue);
      expect(enabled(tester, 'employee-code-cancel'), isTrue);
      await typePrefix(tester, '');
      expect(previewCodes(tester).first, 'EMP0308TG');
      await tester.tap(byKey('employee-code-cancel'));
      await tester.pump();
      expect(prefixText(tester), 'RSS');
      expect(enabled(tester, 'employee-code-save'), isFalse);
      expect(server.puts, isEmpty);
    });

    testWidgets('3. save: web payload, saved banner, form shows the server value, buttons disabled again',
        (tester) async {
      await pump(tester);
      await typePrefix(tester, ' abc ');
      await save(tester);
      expect(server.puts.single, {'prefix': 'ABC', 'id_format': 'date_initials', 'padding': 5, 'next_sequence': 1});
      expect(byKey('employee-code-saved'), findsOneWidget);
      expect(find.text('Employee ID format saved successfully.'), findsOneWidget);
      expect(prefixText(tester), 'ABC');
      expect(enabled(tester, 'employee-code-save'), isFalse);
      await typePrefix(tester, 'ABCD');
      expect(byKey('employee-code-saved'), findsNothing, reason: 'a new change clears the banner');
    });

    testWidgets('4. client validation and the 10-character limit; nothing sent', (tester) async {
      await pump(tester);
      await typePrefix(tester, 'R1');
      await save(tester);
      expect(prefixError(tester), 'Prefix must contain letters only.');
      await typePrefix(tester, '   ');
      expect(prefixError(tester), isNull, reason: 'editing clears the error');
      await save(tester);
      expect(prefixError(tester), 'Prefix is required.');
      await typePrefix(tester, 'ABCDEFGHIJKL');
      expect(prefixText(tester), 'ABCDEFGHIJ');
      expect(server.puts, isEmpty);
    });

    testWidgets('5. server field errors: prefix under the field; padding (not editable here) in the banner',
        (tester) async {
      final s = Server()
        ..stored = {'prefix': 'RSS', 'padding': 2, 'next_sequence': 1}
        ..refuse = (
          status: 400,
          body: {
            'status': 'error',
            'message': 'Please fix the errors below.',
            'data': {
              'prefix': ['Ensure this field has no more than 10 characters.'],
              'padding': ['Padding must be between 3 and 8.'],
            }
          }
        );
      await pump(tester, with_: s);
      await typePrefix(tester, 'ABC');
      await save(tester);
      expect(s.puts.single['padding'], 2, reason: 'the legacy value was carried, not replaced');
      expect(prefixError(tester), 'Ensure this field has no more than 10 characters.');
      expect(find.text('Padding: Padding must be between 3 and 8.'), findsOneWidget);
      expect(prefixText(tester), 'ABC', reason: 'entered value kept');
    });

    testWidgets('6. a general refusal (e.g. 403) shows the server message in the banner; value kept', (tester) async {
      final s = Server()
        ..refuse = (
          status: 403,
          body: {'status': 'error', 'message': 'You do not have permission to perform this action.', 'data': {}}
        );
      await pump(tester, with_: s);
      await typePrefix(tester, 'XYZ');
      await save(tester);
      expect(
          find.descendant(of: byKey('employee-code-error'), matching: find.text(kEmployeeCodeDenied)), findsOneWidget);
      expect(prefixText(tester), 'XYZ');
      expect(enabled(tester, 'employee-code-save'), isTrue, reason: 'retry possible');
    });

    testWidgets('7. load failure: error with Retry (no defaults shown, nothing savable); Retry loads the form',
        (tester) async {
      final s = Server()..failGets = 1;
      await pump(tester, with_: s);
      expect(byKey('employee-code-load-error'), findsOneWidget);
      expect(byKey('employee-code-prefix'), findsNothing);
      await tester.tap(byKey('employee-code-retry'));
      await tester.pumpAndSettle();
      expect(s.gets, 2);
      expect(prefixText(tester), 'RSS');
      expect(s.puts, isEmpty);
    });

    testWidgets('8. without settings.edit: permission message, no request', (tester) async {
      await pump(tester, as: viewer);
      expect(byKey('employee-code-denied'), findsOneWidget);
      expect(find.text(kEmployeeCodeDenied), findsOneWidget);
      expect(server.gets, 0);
      expect(byKey('employee-code-prefix'), findsNothing);
    });

    testWidgets(
        '9. legacy server values: odd prefix shown as stored (must be corrected); missing padding / '
        'next_sequence left out of the save', (tester) async {
      final s = Server()..stored = {'prefix': 'R-S'};
      await pump(tester, with_: s);
      expect(prefixText(tester), 'R-S');
      expect(previewCodes(tester).first, 'R-S0308TG', reason: 'web previews the stored value as-is');
      await typePrefix(tester, 'R-SS');
      await save(tester);
      expect(prefixError(tester), 'Prefix must contain letters only.');
      expect(s.puts, isEmpty);
      await typePrefix(tester, 'rs');
      await save(tester);
      expect(s.puts.single, {'prefix': 'RS', 'id_format': 'date_initials'});
    });
  });
}
