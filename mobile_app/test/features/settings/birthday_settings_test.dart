import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/data/models/birthday_settings_model.dart';
import 'package:mobile_app/features/settings/presentation/email_templates/birthday_settings_providers.dart';
import 'package:mobile_app/features/settings/presentation/email_templates/email_templates_screen.dart';

// P2: Settings → Email Templates → "Automatic Birthday Wishes", as web
// settings/email-templates/page.tsx over production BirthdaySettingsView
// (GET /birthdays/settings/ needs employees.view; PATCH needs settings.edit,
// changes only the keys sent, and refuses a blank text with
// "<field> cannot be empty."). Stand-in server, synthetic data; no email is sent.

const settingsPath = ApiConstants.hrmsBirthdaySettings;

Map<String, dynamic> stored() => {
      'is_enabled': true,
      'banner_message_template': 'Have an amazing birthday! 🎂',
      'employee_notification_template': 'We wish you a wonderful birthday.',
      'team_notification_template': "Today is {employee_name}'s birthday.",
      'manager_notification_template': "Today is {employee_name}'s birthday. Your team member is celebrating.",
      'updated_at': '2026-11-01T10:00:00+05:30',
    };

Map<String, dynamic> template(int id, String name) => {
      'id': id,
      'name': name,
      'display_name': name == 'birthday_wish' ? 'Birthday Wish' : 'Welcome Email',
      'subject': 'Subject $id',
      'body': 'Body $id',
      'template_type': 'general',
      'is_active': true,
    };

class Server implements HttpClientAdapter {
  Map<String, dynamic> settings = stored();
  int getStatus = 200;
  Completer<void>? holdGet;
  Completer<void>? holdPatch;
  ({int status, String message})? refusePatch;
  List<Map<String, dynamic>> templates = [template(1, 'welcome'), template(2, 'birthday_wish')];
  final calls = <({String method, String path, Object? body})>[];

  List<({String method, String path, Object? body})> of(String m, String p) =>
      calls.where((c) => c.method == m && c.path == p).toList();

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, body: o.data));
    if (o.path == settingsPath && o.method == 'GET') {
      if (holdGet != null) await holdGet!.future;
      if (getStatus != 200) {
        return _json({'status': 'error', 'message': 'You do not have permission to perform this action.'}, getStatus);
      }
      return _json({'status': 'success', 'message': 'Birthday settings retrieved.', 'data': settings});
    }
    if (o.path == settingsPath && o.method == 'PATCH') {
      if (holdPatch != null) await holdPatch!.future;
      final r = refusePatch;
      if (r != null) {
        refusePatch = null;
        return _json({'status': 'error', 'message': r.message}, r.status);
      }
      final body = Map<String, dynamic>.from(o.data as Map);
      settings = {
        ...settings,
        for (final e in body.entries) e.key: e.value is String ? (e.value as String).trim() : e.value,
        'updated_at': '2026-11-06T12:00:00+05:30',
      };
      return _json({'status': 'success', 'message': 'Birthday settings updated.', 'data': settings});
    }
    if (o.path == ApiConstants.settingsEmailTemplates && o.method == 'GET') {
      return _json({
        'status': 'success',
        'data': {
          'results': {'general': templates}
        }
      });
    }
    if (o.path == ApiConstants.settingsCompany) {
      return _json({
        'status': 'success',
        'data': {'id': 1, 'company_name': 'Test Co'}
      });
    }
    return _json({'status': 'success', 'message': 'ok', 'data': []});
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

UserEntity user(List<String> perms, {bool superuser = false}) => UserEntity(
      id: 'u1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final editor = user(['settings.view', 'settings.edit', 'employees.view']);
final reader = user(['settings.view', 'employees.view']);

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pump(WidgetTester tester, {UserEntity? as, void Function(Server)? setup, bool settle = true}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? editor),
    child: MaterialApp.router(
      routerConfig: GoRouter(initialLocation: '/s', routes: [
        GoRoute(
          path: '/s',
          builder: (_, __) => Consumer(
            builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
                ? const SizedBox()
                : const EmailTemplatesScreen(),
          ),
        ),
      ]),
    ),
  ));
  if (settle) await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

Future<void> openEditor(WidgetTester tester) async {
  await tester.tap(byKey('birthday-settings-edit'));
  await tester.pumpAndSettle();
  expect(byKey('birthday-settings-sheet'), findsOneWidget);
}

Future<void> setText(WidgetTester tester, String field, String text) async {
  final f = byKey('birthday-$field');
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(byKey('birthday-settings-save'));
  await tester.tap(byKey('birthday-settings-save'));
  await tester.pumpAndSettle();
}

String fieldText(WidgetTester tester, String field) =>
    tester.widget<TextField>(byKey('birthday-$field')).controller!.text;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model', () {
    test('parses the server fields; anything missing falls back to web\'s EMPTY_BIRTHDAY (enabled, empty)', () {
      final m = BirthdaySettingsModel.fromJson(stored());
      expect(m.isEnabled, isTrue);
      expect(m.teamNotification, "Today is {employee_name}'s birthday.");
      expect(m.updatedAt, '2026-11-01T10:00:00+05:30');
      final empty = BirthdaySettingsModel.fromJson(const {});
      expect([empty.isEnabled, empty.bannerMessage, empty.employeeNotification], [true, '', '']);
      expect(BirthdaySettingsModel.fromJson({'is_enabled': false}).isEnabled, isFalse);
      expect(BirthdaySettingsModel.fromJson({'is_enabled': 'no', 'banner_message_template': 5}).isEnabled, isTrue);
    });

    test('serialises exactly the five fields web edits (no updated_at, nothing else)', () {
      final json = BirthdaySettingsModel.fromJson({...stored(), 'unknown_future_field': 'keep'}).toJson();
      expect(json.keys.toSet(), {
        'is_enabled',
        'banner_message_template',
        'employee_notification_template',
        'team_notification_template',
        'manager_notification_template',
      });
    });

    test('blank texts are the server\'s refusals, named as the server names them', () {
      final m = BirthdaySettingsModel.fromJson(stored()).copyWith(bannerMessage: '   ', managerNotification: '');
      expect(m.emptyFields(), ['banner_message_template', 'manager_notification_template']);
    });

    test('permission rules = production BirthdaySettingsView', () {
      expect(canViewBirthdaySettings(reader), isTrue);
      expect(canViewBirthdaySettings(user(['settings.view', 'settings.edit'])), isFalse);
      expect(canEditBirthdaySettings(editor), isTrue);
      expect(canEditBirthdaySettings(reader), isFalse);
      expect(canViewBirthdaySettings(user([], superuser: true)), isTrue);
      expect(canEditBirthdaySettings(user([], superuser: true)), isTrue);
    });

    test('save is refused before any request without settings.edit, or with a blank text', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(reader));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final loaded = (await c.read(birthdaySettingsProvider.future))!;
      await expectLater(
          c.read(birthdaySettingsProvider.notifier).save(loaded), throwsA(isA<BirthdaySettingsRefused>()));
      final c2 = ProviderContainer(overrides: overrides(editor));
      addTearDown(c2.dispose);
      await c2.read(authStateProvider.future);
      final l2 = (await c2.read(birthdaySettingsProvider.future))!;
      await expectLater(c2.read(birthdaySettingsProvider.notifier).save(l2.copyWith(employeeNotification: ' ')),
          throwsA(predicate((e) => e.toString() == 'employee_notification_template cannot be empty.')));
      expect(server.calls.where((x) => x.method == 'PATCH'), isEmpty);
    });

    test('the provider itself makes no request without employees.view (answers null)', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(user(['settings.view', 'settings.edit'])));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      expect(await c.read(birthdaySettingsProvider.future), isNull);
      expect(server.calls, isEmpty);
    });

    test('one save at a time', () async {
      server = Server()..holdPatch = Completer();
      final c = ProviderContainer(overrides: overrides(editor));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final loaded = (await c.read(birthdaySettingsProvider.future))!;
      final n = c.read(birthdaySettingsProvider.notifier);
      final first = n.save(loaded.copyWith(isEnabled: false));
      await Future<void>.delayed(Duration.zero);
      await expectLater(n.save(loaded), throwsA(isA<BirthdaySettingsRefused>()));
      server.holdPatch!.complete();
      expect((await first).isEnabled, isFalse);
      expect(server.of('PATCH', settingsPath), hasLength(1));
    });
  });

  group('card', () {
    testWidgets('loads and shows status, description and Edit, right after Email Branding; templates unchanged',
        (tester) async {
      await pump(tester);
      expect(server.of('GET', settingsPath), hasLength(1));
      expect(find.text('Automatic Birthday Wishes'), findsOneWidget);
      expect(tester.widget<Text>(byKey('birthday-settings-status')).data, 'Enabled');
      expect(find.textContaining('The birthday email subject/body is edited below, in the Wish template.'),
          findsOneWidget);
      expect(byKey('birthday-settings-edit'), findsOneWidget);
      expect(find.text('Birthday Wish'), findsOneWidget);
      expect(find.text('Welcome Email'), findsOneWidget);
      expect(tester.getTopLeft(byKey('birthday-settings-card')).dy,
          greaterThan(tester.getTopLeft(find.text('Email Branding')).dy));
    });

    testWidgets('disabled shows "Disabled"', (tester) async {
      await pump(tester, setup: (s) => s.settings = {...stored(), 'is_enabled': false});
      expect(tester.widget<Text>(byKey('birthday-settings-status')).data, 'Disabled');
    });

    testWidgets('loading state, then loaded', (tester) async {
      final gate = Completer<void>();
      await pump(tester, settle: false, setup: (s) => s.holdGet = gate);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(byKey('birthday-settings-loading'), findsOneWidget);
      expect(byKey('birthday-settings-edit'), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(byKey('birthday-settings-loading'), findsNothing);
      expect(byKey('birthday-settings-edit'), findsOneWidget);
    });

    testWidgets('a failed load shows the server message and Retry, with no Edit (no empty form to save)',
        (tester) async {
      await pump(tester, setup: (s) => s.getStatus = 500);
      expect(byKey('birthday-settings-error'), findsOneWidget);
      expect(byKey('birthday-settings-edit'), findsNothing);
      server.getStatus = 200;
      await tester.tap(byKey('birthday-settings-retry'));
      await tester.pumpAndSettle();
      expect(byKey('birthday-settings-edit'), findsOneWidget);
      // The rest of the screen is unaffected.
      expect(find.text('Birthday Wish'), findsOneWidget);
    });

    testWidgets('without employees.view the card is hidden and nothing is requested', (tester) async {
      await pump(tester, as: user(['settings.view', 'settings.edit']));
      expect(byKey('birthday-settings-card'), findsNothing);
      expect(server.of('GET', settingsPath), isEmpty);
      expect(find.text('Birthday Wish'), findsOneWidget);
    });

    testWidgets('employees.view without settings.edit: read-only (no Edit)', (tester) async {
      await pump(tester, as: reader);
      expect(byKey('birthday-settings-card'), findsOneWidget);
      expect(byKey('birthday-settings-edit'), findsNothing);
    });

    testWidgets('the card also shows when there are no email templates yet', (tester) async {
      await pump(tester, setup: (s) => s.templates = []);
      expect(byKey('birthday-settings-card'), findsOneWidget);
    });
  });

  group('editing', () {
    testWidgets('the form shows web\'s labels, help text and the stored values', (tester) async {
      await pump(tester);
      await openEditor(tester);
      for (final t in [
        'Enable automatic birthday wishes',
        'When off, no birthday email, dashboard banner, or notification is sent to anyone.',
        'Dashboard birthday banner message',
        'Employee in-app notification text',
        'Teammate notification / card text',
        'Manager notification / card text',
        'Save Birthday Settings',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.textContaining('Use {employee_name} as a placeholder'), findsNWidgets(2));
      expect(fieldText(tester, 'team_notification_template'), "Today is {employee_name}'s birthday.");
    });

    testWidgets('save sends PATCH with exactly the five fields, then shows the saved values', (tester) async {
      await pump(tester);
      await openEditor(tester);
      await tester.tap(byKey('birthday-is-enabled'));
      await tester.pump();
      await setText(tester, 'banner_message_template', 'Many happy returns!');
      await tapSave(tester);
      final patch = server.of('PATCH', settingsPath).single;
      final body = Map<String, dynamic>.from(patch.body as Map);
      expect(body, {
        'is_enabled': false,
        'banner_message_template': 'Many happy returns!',
        'employee_notification_template': 'We wish you a wonderful birthday.',
        'team_notification_template': "Today is {employee_name}'s birthday.",
        'manager_notification_template': "Today is {employee_name}'s birthday. Your team member is celebrating.",
      });
      expect(byKey('birthday-settings-sheet'), findsNothing);
      expect(find.text('Birthday wishes settings updated'), findsOneWidget);
      expect(tester.widget<Text>(byKey('birthday-settings-status')).data, 'Disabled');
      // No email-template request was touched by the save.
      expect(server.calls.where((c) => c.path.startsWith(ApiConstants.settingsEmailTemplates) && c.method != 'GET'),
          isEmpty);
    });

    testWidgets('a blank text is refused before any request, with the field marked', (tester) async {
      await pump(tester);
      await openEditor(tester);
      await setText(tester, 'manager_notification_template', '   ');
      await tapSave(tester);
      expect(find.text('This text cannot be empty.'), findsOneWidget);
      expect(server.of('PATCH', settingsPath), isEmpty);
      expect(byKey('birthday-settings-sheet'), findsOneWidget);
    });

    testWidgets('a server refusal (validation or permission) is shown and the edits stay', (tester) async {
      await pump(tester,
          setup: (s) => s.refusePatch = (status: 400, message: 'team_notification_template cannot be empty.'));
      await openEditor(tester);
      await setText(tester, 'banner_message_template', 'Edited');
      await tapSave(tester);
      expect(find.text('team_notification_template cannot be empty.'), findsOneWidget);
      expect(fieldText(tester, 'banner_message_template'), 'Edited');
      server.refusePatch = (status: 403, message: 'You do not have permission to perform this action.');
      await tapSave(tester);
      expect(find.text('You do not have permission to perform this action.'), findsOneWidget);
      expect(tester.widget<Text>(byKey('birthday-settings-status')).data, 'Enabled');
    });

    testWidgets('Cancel discards the edits; nothing is sent', (tester) async {
      await pump(tester);
      await openEditor(tester);
      await setText(tester, 'banner_message_template', 'Discard me');
      await tester.tap(byKey('birthday-settings-cancel'));
      await tester.pumpAndSettle();
      await openEditor(tester);
      expect(fieldText(tester, 'banner_message_template'), 'Have an amazing birthday! 🎂');
      expect(server.of('PATCH', settingsPath), isEmpty);
    });

    testWidgets('double-tapping Save sends one request; Saving… and Cancel disabled meanwhile', (tester) async {
      await pump(tester, setup: (s) => s.holdPatch = Completer());
      await openEditor(tester);
      await tester.ensureVisible(byKey('birthday-settings-save'));
      await tester.tap(byKey('birthday-settings-save'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      expect(tester.widget<FilledButton>(byKey('birthday-settings-save')).onPressed, isNull);
      expect(tester.widget<TextButton>(byKey('birthday-settings-cancel')).onPressed, isNull);
      await tester.tap(byKey('birthday-settings-save'), warnIfMissed: false);
      server.holdPatch!.complete();
      await tester.pumpAndSettle();
      expect(server.of('PATCH', settingsPath), hasLength(1));
    });
  });
}
