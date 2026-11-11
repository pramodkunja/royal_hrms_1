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
import 'package:mobile_app/features/settings/data/models/smtp_model.dart';
import 'package:mobile_app/features/settings/data/models/smtp_providers.dart';
import 'package:mobile_app/features/settings/presentation/smtp/smtp_screen.dart';

// Task 47 (F-SM02): SMTP provider picker, as web settings/smtp/_data.ts
// (PROVIDER_ORDER / PROVIDER_META / PROVIDER_PRESETS, formToPayload,
// validateSmtpForm) + ProviderSelectModal.tsx + SmtpModal.tsx, against the
// backend contract (SMTPSettings.provider choices or '', returned with
// provider_display; POST /settings/smtp/, PUT /settings/smtp/<id>/,
// CanManageRoles). A stand-in server; fictitious credentials only — no email
// is sent, no SMTP connection is made, no real setting changes.

const _fakePassword = 'fake-app-password-123';

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> row(int id,
        {String provider = 'zoho_mail', String type = 'local', String host = 'smtp.zoho.in'}) =>
    {
      'id': id,
      'name': 'Config $id',
      'smtp_type': type,
      'smtp_type_display': type == 'local' ? 'Gmail / Custom SMTP' : 'Dedicated Mail Server',
      'provider': provider,
      'provider_display': provider,
      'host': host,
      'port': 587,
      'username': 'user$id@example.test',
      'password_display': '••••••••',
      'use_tls': true,
      'sender_name': 'Test HR',
      'from_email': 'noreply$id@example.test',
      'bcc_email': '',
      'priority': 'normal',
      'receiver_email_type': 'email_id',
      'is_active': id == 1,
      'updated_at': '2026-11-01T10:00:00Z',
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> rows = [row(1)];
  ({int status, String message})? refuse;
  final writes = <({String method, String path, Map<String, dynamic> body})>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'GET' && o.path == '/settings/smtp/') {
      return _json(200, {
        'status': 'success',
        'data': {'count': rows.length, 'results': rows}
      });
    }
    if (o.method == 'POST' || o.method == 'PUT') {
      final body = Map<String, dynamic>.from(o.data as Map);
      writes.add((method: o.method, path: o.path, body: body));
      final r = refuse;
      if (r != null) return _json(r.status, {'status': 'error', 'message': r.message, 'data': {}});
      final saved = {...row(9), ...body, 'id': o.method == 'POST' ? 9 : int.parse(o.path.split('/')[3])};
      saved.remove('password');
      return _json(o.method == 'POST' ? 201 : 200, {'status': 'success', 'data': saved});
    }
    return _json(200, {'status': 'success', 'data': {}});
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
Finder byKey(String k) => find.byKey(Key(k));

Future<void> pump(WidgetTester tester, {Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => const SmtpScreen())]),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> openPicker(WidgetTester tester) async {
  await tester.tap(find.text('Add Config'));
  await tester.pumpAndSettle();
}

Future<void> pick(WidgetTester tester, String provider) async {
  await tester.ensureVisible(byKey('smtp-provider-$provider'));
  await tester.tap(byKey('smtp-provider-$provider'));
  await tester.pumpAndSettle();
}

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.descendant(of: byKey(key), matching: find.byType(TextField))).controller!.text;
bool fieldEnabled(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.descendant(of: byKey(key), matching: find.byType(TextField))).enabled ?? true;

Future<void> type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(byKey(key));
  await tester.enterText(find.descendant(of: byKey(key), matching: find.byType(TextField)), text);
  await tester.pump();
}

Future<void> typeLabel(WidgetTester tester, String label, String text) async {
  final f = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> save(WidgetTester tester) async {
  final f = find.widgetWithText(FilledButton, 'Add Configuration').evaluate().isNotEmpty
      ? find.widgetWithText(FilledButton, 'Add Configuration')
      : find.widgetWithText(FilledButton, 'Save Changes');
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Fills what web requires for the type (fictitious values).
Future<void> fillRequired(WidgetTester tester, {required bool local}) async {
  await type(tester, 'smtp-field-name', 'Test Config');
  await typeLabel(tester, 'From Email *', 'noreply@example.test');
  if (local) {
    if (fieldEnabled(tester, 'smtp-field-host') && fieldText(tester, 'smtp-field-host').isEmpty) {
      await type(tester, 'smtp-field-host', 'smtp.example.test');
    }
    await type(tester, 'smtp-field-username', 'mailer@example.test');
    await type(tester, 'smtp-field-password', _fakePassword);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('catalogue and model', () {
    test('web order and labels; they equal the backend Provider choice labels', () {
      expect(kSmtpProviderOrder,
          ['gmail', 'amazon_ses', 'zoho_mail', 'brevo', 'resend', 'outlook365', 'custom_smtp', 'dedicated_server']);
      expect(kSmtpProviderOrder.map((v) => kSmtpProviderMeta[v]!.label), [
        'Gmail',
        'Amazon SES',
        'Zoho Mail',
        'Brevo (Sendinblue)',
        'Resend',
        'Outlook / Office 365',
        'Custom SMTP',
        'Dedicated Mail Server',
      ]);
      for (final v in kSmtpProviderOrder) {
        expect(kSmtpProviderPresets.containsKey(v), isTrue, reason: v);
        expect(kSmtpProviderMeta[v]!.description, isNotEmpty);
      }
    });

    test('presets exactly as web (type / host / port / TLS / locked)', () {
      String d(String v) {
        final p = kSmtpProviderPresets[v]!;
        return '${p.smtpType}|${p.host}|${p.port}|${p.useTls}|${p.hostLocked}';
      }

      expect(d('gmail'), 'local|smtp.gmail.com|587|true|true');
      expect(d('amazon_ses'), 'local|email-smtp.us-east-1.amazonaws.com|587|true|false');
      expect(d('zoho_mail'), 'local|smtp.zoho.com|587|true|false');
      expect(d('brevo'), 'local|smtp-relay.brevo.com|587|true|true');
      expect(d('resend'), 'local|smtp.resend.com|587|true|true');
      expect(d('outlook365'), 'local|smtp.office365.com|587|true|true');
      expect(d('custom_smtp'), 'local||587|true|false');
      expect(d('dedicated_server'), 'server||25|false|false');
    });

    test('provider parsed from the server; missing → blank; known/unknown', () {
      expect(SmtpModel.fromJson(row(1, provider: 'brevo')).provider, 'brevo');
      expect(SmtpModel.fromJson(row(1, provider: 'brevo')).providerDisplay, 'brevo');
      final legacy = Map<String, dynamic>.from(row(2))..remove('provider');
      expect(SmtpModel.fromJson(legacy).provider, '');
      expect(isKnownSmtpProvider(''), isTrue);
      expect(isKnownSmtpProvider('gmail'), isTrue);
      expect(isKnownSmtpProvider('sendgrid'), isFalse);
    });

    test('payload: provider sent (blank too); unknown left out; server-type placeholders; password rules', () {
      final f = SmtpFormData.forProvider('gmail')
        ..name = 'n'
        ..username = 'u@example.test'
        ..password = _fakePassword
        ..fromEmail = 'f@example.test';
      final j = f.toJson(isAdd: true);
      expect(j['provider'], 'gmail');
      expect([j['smtp_type'], j['host'], j['port'], j['use_tls'], j['password']],
          ['local', 'smtp.gmail.com', 587, true, _fakePassword]);
      expect((SmtpFormData.fromModel(SmtpModel.fromJson(row(1, provider: '')))).toJson(isAdd: false)['provider'], '');
      final unknown = SmtpFormData.fromModel(SmtpModel.fromJson(row(1, provider: 'sendgrid'))).toJson(isAdd: false);
      expect(unknown.containsKey('provider'), isFalse);
      expect(unknown.containsKey('password'), isFalse, reason: 'blank on edit keeps the current password');
      final server = (SmtpFormData.forProvider('dedicated_server')
            ..name = 'n'
            ..fromEmail = 'f@example.test')
          .toJson(isAdd: true);
      expect([server['smtp_type'], server['host'], server['username'], server['port'], server['use_tls']],
          ['server', 'localhost', 'f@example.test', 25, false]);
      expect(server.containsKey('password'), isFalse);
      expect((SmtpFormData.forProvider('dedicated_server')..name = 'n').toJson(isAdd: true)['username'], 'server');
    });

    test('validation: host / username / password only for local (web validateSmtpForm)', () {
      expect(SmtpFormData.forProvider('dedicated_server').validate(isAdd: true).keys.toSet(), {'name', 'fromEmail'});
      expect(SmtpFormData.forProvider('custom_smtp').validate(isAdd: true).keys.toSet(),
          {'name', 'fromEmail', 'host', 'username', 'password'});
      expect(SmtpFormData.forProvider('gmail').validate(isAdd: false).keys.toSet(), {'name', 'fromEmail', 'username'},
          reason: 'password not required on edit; host prefilled');
    });
  });

  group('Add', () {
    testWidgets('1. picker first: web title, text, 8 providers in order with descriptions; Cancel sends nothing',
        (tester) async {
      await pump(tester);
      await openPicker(tester);
      expect(byKey('smtp-provider-picker'), findsOneWidget);
      expect(find.text('Add SMTP Configuration'), findsOneWidget);
      expect(find.text('Choose a mail provider — the fields you need will be filled in for you where possible.'),
          findsOneWidget);
      final ys = [for (final v in kSmtpProviderOrder) tester.getTopLeft(byKey('smtp-provider-$v')).dy];
      expect([...ys]..sort(), ys, reason: 'web order');
      for (final v in kSmtpProviderOrder) {
        expect(find.text(kSmtpProviderMeta[v]!.description), findsOneWidget);
      }
      await tester.tap(byKey('smtp-provider-cancel'));
      await tester.pumpAndSettle();
      expect(byKey('smtp-provider-picker'), findsNothing);
      expect(find.text('Add Configuration'), findsNothing);
      expect(server.writes, isEmpty);
    });

    for (final v in kSmtpProviderOrder) {
      testWidgets('2. $v: prefilled/locked as web, then POSTed with provider "$v"', (tester) async {
        final p = kSmtpProviderPresets[v]!;
        final local = p.smtpType == 'local';
        await pump(tester);
        await openPicker(tester);
        await pick(tester, v);
        expect(find.text(kSmtpProviderMeta[v]!.label), findsOneWidget);
        expect(byKey('smtp-field-host'), local ? findsOneWidget : findsNothing);
        expect(byKey('smtp-field-username'), local ? findsOneWidget : findsNothing);
        expect(byKey('smtp-field-password'), local ? findsOneWidget : findsNothing);
        if (local) {
          expect(fieldText(tester, 'smtp-field-host'), p.host);
          expect(fieldText(tester, 'smtp-field-port'), '${p.port}');
          expect(fieldEnabled(tester, 'smtp-field-host'), !p.hostLocked);
          expect(fieldEnabled(tester, 'smtp-field-port'), !p.hostLocked);
          expect(byKey('smtp-host-hint'), p.hostHint == null ? findsNothing : findsOneWidget);
          expect(byKey('smtp-username-hint'), p.usernameHint == null ? findsNothing : findsOneWidget);
        }
        await fillRequired(tester, local: local);
        await save(tester);
        final w = server.writes.single;
        expect('${w.method} ${w.path}', 'POST /settings/smtp/');
        expect(w.body['provider'], v);
        expect(w.body['smtp_type'], p.smtpType);
        expect(w.body['port'], p.port);
        expect(w.body['use_tls'], p.useTls);
        if (p.host.isNotEmpty) expect(w.body['host'], p.host);
        if (!local) {
          expect(w.body['host'], 'localhost');
          expect(w.body['username'], 'noreply@example.test');
          expect(w.body.containsKey('password'), isFalse);
        }
      });
    }

    testWidgets('3. locked TLS (Gmail) cannot be toggled; editable TLS (Zoho) can', (tester) async {
      await pump(tester);
      await openPicker(tester);
      await pick(tester, 'gmail');
      expect(find.text('App Password'), findsOneWidget);
      await tester.ensureVisible(byKey('smtp-tls-toggle'));
      await tester.tap(find.text('Use TLS'));
      await tester.pump();
      await fillRequired(tester, local: true);
      await save(tester);
      expect(server.writes.single.body['use_tls'], isTrue);

      await pump(tester);
      await openPicker(tester);
      await pick(tester, 'zoho_mail');
      await tester.ensureVisible(byKey('smtp-tls-toggle'));
      await tester.tap(find.text('Use TLS'));
      await tester.pump();
      await type(tester, 'smtp-field-host', 'smtp.zoho.in');
      await fillRequired(tester, local: true);
      await save(tester);
      expect(server.writes.single.body['use_tls'], isFalse);
      expect(server.writes.single.body['host'], 'smtp.zoho.in');
    });

    testWidgets('4. "Change provider" goes back to the picker; the form starts again from the new preset',
        (tester) async {
      await pump(tester);
      await openPicker(tester);
      await pick(tester, 'gmail');
      await type(tester, 'smtp-field-name', 'Draft Name');
      await tester.tap(byKey('smtp-change-provider'));
      await tester.pumpAndSettle();
      expect(byKey('smtp-provider-picker'), findsOneWidget);
      await pick(tester, 'brevo');
      expect(find.text('Brevo (Sendinblue)'), findsOneWidget);
      expect(fieldText(tester, 'smtp-field-host'), 'smtp-relay.brevo.com');
      expect(fieldText(tester, 'smtp-field-name'), '', reason: 'web remounts the form from the new preset');
      expect(server.writes, isEmpty);
    });

    testWidgets('5. local validation: web messages, nothing sent', (tester) async {
      await pump(tester);
      await openPicker(tester);
      await pick(tester, 'custom_smtp');
      await save(tester);
      expect(find.text('Configuration name is required'), findsOneWidget);
      expect(find.text('Host is required'), findsOneWidget);
      expect(find.text('Username is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('From email is required'), findsOneWidget);
      expect(server.writes, isEmpty);
    });

    testWidgets('6. server refusal (validation or permission): message shown, form kept, retry possible',
        (tester) async {
      final s = Server()..refuse = (status: 400, message: 'An SMTP config named "Test Config" already exists.');
      await pump(tester, with_: s);
      await openPicker(tester);
      await pick(tester, 'outlook365');
      await fillRequired(tester, local: true);
      await save(tester);
      // Inside the form (a snackbar would sit behind the full-height dialog).
      expect(
          find.descendant(
              of: byKey('smtp-form-error'), matching: find.text('An SMTP config named "Test Config" already exists.')),
          findsOneWidget);
      expect(find.text('Outlook / Office 365'), findsOneWidget, reason: 'still in the form');
      s.refuse = (status: 403, message: 'You do not have permission to manage settings.');
      await save(tester);
      expect(
          find.descendant(
              of: byKey('smtp-form-error'), matching: find.text('You do not have permission to manage settings.')),
          findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(s.writes, hasLength(2));
      expect(s.writes.every((w) => w.body['provider'] == 'outlook365'), isTrue);
    });
  });

  group('Edit', () {
    Future<void> openEdit(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
    }

    testWidgets('7. no picker; the saved provider and every setting are sent back unchanged', (tester) async {
      await pump(tester, with_: Server()..rows = [row(1, provider: 'zoho_mail', host: 'smtp.zoho.in')]);
      await openEdit(tester);
      expect(byKey('smtp-provider-picker'), findsNothing);
      expect(byKey('smtp-change-provider'), findsNothing);
      expect(fieldEnabled(tester, 'smtp-field-host'), isTrue, reason: 'no locks on edit (web)');
      expect(fieldText(tester, 'smtp-field-host'), 'smtp.zoho.in');
      await save(tester);
      final b = server.writes.single.body;
      expect('${server.writes.single.method} ${server.writes.single.path}', 'PUT /settings/smtp/1/');
      expect(b['provider'], 'zoho_mail');
      expect(b['host'], 'smtp.zoho.in');
      expect(b['username'], 'user1@example.test');
      expect(b.containsKey('password'), isFalse);
    });

    testWidgets('8. unknown saved provider: kept on the server (left out of the PUT), other edits still saved',
        (tester) async {
      await pump(tester, with_: Server()..rows = [row(1, provider: 'sendgrid', host: 'smtp.sendgrid.net')]);
      await openEdit(tester);
      await type(tester, 'smtp-field-name', 'Renamed');
      await save(tester);
      final b = server.writes.single.body;
      expect(b.containsKey('provider'), isFalse);
      expect(b['name'], 'Renamed');
      expect(b['host'], 'smtp.sendgrid.net');
    });

    testWidgets('9. blank (pre-picker) provider stays blank', (tester) async {
      await pump(tester, with_: Server()..rows = [row(1, provider: '')]);
      await openEdit(tester);
      await save(tester);
      expect(server.writes.single.body['provider'], '');
    });

    testWidgets('10. a Dedicated Mail Server row edits without credential fields; stored host/username kept',
        (tester) async {
      final r = row(1, provider: 'dedicated_server', type: 'server', host: 'mail.internal.test');
      await pump(tester, with_: Server()..rows = [r]);
      await openEdit(tester);
      expect(byKey('smtp-field-host'), findsNothing);
      expect(byKey('smtp-field-password'), findsNothing);
      await save(tester);
      final b = server.writes.single.body;
      expect([b['smtp_type'], b['provider'], b['host'], b['username']],
          ['server', 'dedicated_server', 'mail.internal.test', 'user1@example.test']);
    });
  });
}
