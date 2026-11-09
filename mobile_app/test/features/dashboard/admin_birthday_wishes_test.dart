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
import 'package:mobile_app/features/dashboard/data/models/dashboard_common_models.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/admin_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/send_all_birthday_wishes_sheet.dart';

// P1-7: admin dashboard birthday wishes, as web components/dashboard/
// BirthdayWidget + SendWishModal + SendAllBirthdayModal (local web branch):
// per-row Send Wish (→ "Resend" after a confirmed send) and, for today's
// birthdays, Send All — one POST /recruitment/candidates/<employee_id>/
// send-email/ {template_name, extra_context} per recipient, in order, with a
// "birthday" template pre-selected. Backend SendCandidateEmailView: needs
// recruitment.edit, sends synchronously, no duplicate guard. Mocked Dio,
// synthetic people — no email is sent.

Map<String, dynamic> person(String id, String name, {int days = 0}) => {
      'employee_id': id,
      'full_name': name,
      'email': '${id.toLowerCase()}@example.test',
      'department': 'Ops',
      'designation': 'Analyst',
      'branch': 'North',
      'date_of_birth': '1990-11-09',
      'days_until': days,
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> today = [person('TST001', 'Asha Test'), person('TST002', 'Ravi Test')];
  List<Map<String, dynamic>> upcoming = [person('TST003', 'Meera Test', days: 3)];
  bool activeTemplates = true;
  final sendResult = <String, Object>{}; // employee id → status code or DioExceptionType
  Completer<void>? holdSend;
  final sends = <({String id, Map<String, dynamic> body})>[];

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'POST' && o.path.endsWith('/send-email/')) {
      final id = o.path.split('/')[3];
      sends.add((id: id, body: Map<String, dynamic>.from(o.data as Map)));
      final gate = holdSend;
      if (gate != null) await gate.future;
      final r = sendResult[id];
      if (r is DioExceptionType) throw DioException(requestOptions: o, type: r);
      if (r is int) {
        return _json({'status': 'error', 'message': 'Failed to send email. Check SMTP configuration.', 'data': {}}, r);
      }
      return _json({'status': 'success', 'message': 'Email sent successfully.', 'data': {}});
    }
    if (o.path == ApiConstants.dashboardSystemAdminBirthdaysToday) {
      return _json({'status': 'success', 'data': today});
    }
    if (o.path == ApiConstants.dashboardSystemAdminBirthdaysUpcoming) {
      return _json({'status': 'success', 'data': upcoming});
    }
    if (o.path == ApiConstants.settingsEmailTemplates) {
      return _json({
        'status': 'success',
        'data': {
          'results': {
            'general': [
              {'id': 1, 'name': 'general_note', 'display_name': 'General Note', 'subject': 'Hi {first_name}', 'body': 'Hello', 'is_active': activeTemplates},
              {'id': 2, 'name': 'birthday_wish', 'display_name': 'Birthday Wish', 'subject': 'Happy birthday {first_name}', 'body': 'Cheers from {company_name}', 'is_active': activeTemplates},
              {'id': 3, 'name': 'old_birthday', 'display_name': 'Old Birthday', 'subject': 's', 'body': 'b', 'is_active': false},
            ]
          }
        }
      });
    }
    if (o.path == ApiConstants.settingsCompany) {
      return _json({'status': 'success', 'data': {'company_name': 'Test Co'}});
    }
    return _json({'status': 'success', 'data': {}});
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
      id: 'a1',
      email: 'admin@example.test',
      fullName: 'Test Admin',
      role: 'system_admin',
      roleDisplay: 'Admin',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final admin = user(const [], superuser: true);
final hrSender = user(const ['settings.view', 'recruitment.edit', 'employees.view']);
final noSend = user(const ['settings.view', 'employees.view']);

late Server server;

Future<void> pumpDashboard(WidgetTester tester, {UserEntity? as, Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? admin)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Consumer(builder: (context, ref, _) {
            ref.watch(authStateProvider);
            return const Scaffold(body: AdminDashboardView());
          }),
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

String rowLabel(WidgetTester tester, String id) =>
    tester.widget<Text>(find.descendant(of: byKey('birthday-wish-$id'), matching: find.byType(Text))).data!;

Future<void> tapKey(WidgetTester tester, String k) async {
  await tester.ensureVisible(byKey(k));
  await tester.tap(byKey(k));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('visibility', () {
    testWidgets('a sender sees Send Wish on every row and Send All on Today\'s card', (tester) async {
      await pumpDashboard(tester, as: hrSender);
      for (final id in ['TST001', 'TST002', 'TST003']) {
        expect(rowLabel(tester, id), 'Send Wish');
      }
      expect(byKey('birthday-send-all'), findsOneWidget);
    });

    testWidgets('without recruitment.edit there is no Send Wish or Send All (the server would refuse)',
        (tester) async {
      await pumpDashboard(tester, as: noSend);
      expect(find.text('Asha Test'), findsOneWidget);
      expect(find.text('Send Wish'), findsNothing);
      expect(byKey('birthday-send-all'), findsNothing);
    });

    testWidgets('no birthdays today → no Send All (upcoming rows still offer Send Wish)', (tester) async {
      await pumpDashboard(tester, with_: Server()..today = []);
      expect(find.text('No birthdays today'), findsOneWidget);
      expect(byKey('birthday-send-all'), findsNothing);
      expect(rowLabel(tester, 'TST003'), 'Send Wish');
    });
  });

  group('Send Wish (one employee)', () {
    testWidgets('confirm sends one POST with the birthday template and context; the row becomes Resend',
        (tester) async {
      await pumpDashboard(tester);
      await tapKey(tester, 'birthday-wish-TST001');
      expect(find.text('Birthday Wish'), findsWidgets, reason: 'a "birthday" template is pre-selected');
      expect(server.sends, isEmpty, reason: 'nothing sent before confirming');
      await tester.tap(find.text('Confirm & Send Wish'));
      await tester.pumpAndSettle();

      final s = server.sends.single;
      expect(s.id, 'TST001');
      expect(s.body['template_name'], 'birthday_wish');
      final ctx = Map<String, dynamic>.from(s.body['extra_context'] as Map);
      expect([ctx['employee_name'], ctx['first_name'], ctx['FIRST_NAME'], ctx['designation'], ctx['company_name']],
          ['Asha Test', 'Asha', 'Asha', 'Analyst', 'Test Co']);
      expect(rowLabel(tester, 'TST001'), 'Resend');
      expect(rowLabel(tester, 'TST002'), 'Send Wish');
    });

    testWidgets('a server failure keeps the sheet open with the message; the row is not marked sent',
        (tester) async {
      await pumpDashboard(tester, with_: Server()..sendResult['TST001'] = 400);
      await tapKey(tester, 'birthday-wish-TST001');
      await tester.tap(find.text('Confirm & Send Wish'));
      await tester.pumpAndSettle();
      expect(find.text('Failed to send email. Check SMTP configuration.'), findsOneWidget);
      expect(find.text('Confirm & Send Wish'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(rowLabel(tester, 'TST001'), 'Send Wish');
    });

    testWidgets('Cancel sends nothing', (tester) async {
      await pumpDashboard(tester);
      await tapKey(tester, 'birthday-wish-TST003');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(server.sends, isEmpty);
      expect(rowLabel(tester, 'TST003'), 'Send Wish');
    });
  });

  group('Send All (today\'s birthdays)', () {
    testWidgets('lists the recipients, then sends one POST each, in order, with the same template',
        (tester) async {
      await pumpDashboard(tester);
      await tapKey(tester, 'birthday-send-all');
      expect(find.text('Send Birthday Wishes — All (2)'), findsOneWidget);
      expect(tester.widget<Text>(byKey('send-all-recipients')).data, 'Sending to 2 employees: Asha Test, Ravi Test');
      expect(find.text('Send to All 2'), findsOneWidget);
      expect(server.sends, isEmpty);

      await tapKey(tester, 'send-all-confirm');
      expect(server.sends.map((s) => s.id), ['TST001', 'TST002'], reason: 'today only, upcoming excluded');
      expect(server.sends.every((s) => s.body['template_name'] == 'birthday_wish'), isTrue);
      expect((server.sends[1].body['extra_context'] as Map)['employee_name'], 'Ravi Test');
      expect(tester.widget<Text>(byKey('send-all-summary')).data, 'All birthday wishes sent successfully!');
      expect(byKey('send-all-confirm'), findsNothing, reason: 'no second send from the same sheet');

      await tapKey(tester, 'send-all-close');
      expect(rowLabel(tester, 'TST001'), 'Resend');
      expect(rowLabel(tester, 'TST002'), 'Resend');
      expect(rowLabel(tester, 'TST003'), 'Send Wish');
    });

    testWidgets('a failure for one recipient is reported; only confirmed sends become Resend', (tester) async {
      await pumpDashboard(tester, with_: Server()..sendResult['TST002'] = 400);
      await tapKey(tester, 'birthday-send-all');
      await tapKey(tester, 'send-all-confirm');
      expect(server.sends, hasLength(2), reason: 'the run continues after a failure');
      expect(tester.widget<Text>(byKey('send-all-summary')).data,
          '1 sent. Failed: Ravi Test (Failed to send email. Check SMTP configuration.).');
      await tapKey(tester, 'send-all-close');
      expect(rowLabel(tester, 'TST001'), 'Resend');
      expect(rowLabel(tester, 'TST002'), 'Send Wish');
    });

    testWidgets('no reply in time is "not confirmed" — never reported as sent', (tester) async {
      await pumpDashboard(tester, with_: Server()..sendResult['TST001'] = DioExceptionType.receiveTimeout);
      await tapKey(tester, 'birthday-send-all');
      await tapKey(tester, 'send-all-confirm');
      final summary = tester.widget<Text>(byKey('send-all-summary')).data!;
      expect(summary, startsWith('1 sent.'));
      expect(summary, contains('Not confirmed (no reply in time — the email may still have been sent): Asha Test'));
      await tapKey(tester, 'send-all-close');
      expect(rowLabel(tester, 'TST001'), 'Send Wish');
      expect(rowLabel(tester, 'TST002'), 'Resend');
    });

    testWidgets('Cancel before confirming sends nothing', (tester) async {
      await pumpDashboard(tester);
      await tapKey(tester, 'birthday-send-all');
      await tapKey(tester, 'send-all-cancel');
      expect(server.sends, isEmpty);
      expect(find.text('Send Birthday Wishes — All (2)'), findsNothing);
    });

    testWidgets('while sending: progress shows, Cancel and Send are locked, extra taps send nothing more',
        (tester) async {
      final s = Server()..holdSend = Completer();
      await pumpDashboard(tester, with_: s);
      await tapKey(tester, 'birthday-send-all');
      await tester.tap(byKey('send-all-confirm'));
      await tester.pump();
      expect(find.text('Sending wishes…'), findsOneWidget);
      expect(tester.widget<Text>(byKey('send-all-progress')).data, '0 / 2');
      expect(tester.widget<OutlinedButton>(byKey('send-all-cancel')).onPressed, isNull);
      expect(tester.widget<FilledButton>(byKey('send-all-confirm')).onPressed, isNull);
      await tester.tap(byKey('send-all-confirm'), warnIfMissed: false);
      await tester.pump();
      s.holdSend!.complete();
      s.holdSend = null;
      await tester.pumpAndSettle();
      expect(s.sends.map((x) => x.id), ['TST001', 'TST002'], reason: 'each recipient exactly once');
      expect(tester.widget<Text>(byKey('send-all-progress')).data, '2 / 2');
    });

    testWidgets('no active templates → cannot send', (tester) async {
      await pumpDashboard(tester, with_: Server()..activeTemplates = false);
      await tapKey(tester, 'birthday-send-all');
      expect(byKey('send-all-no-templates'), findsOneWidget);
      expect(tester.widget<FilledButton>(byKey('send-all-confirm')).onPressed, isNull);
    });

    testWidgets('an empty recipient list offers nothing to send', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      server = Server();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => _Auth(admin)),
          dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullStorage()),
        ],
        child: const MaterialApp(home: Scaffold(body: SendAllBirthdayWishesSheet(entries: []))),
      ));
      await tester.pumpAndSettle();
      expect(byKey('send-all-empty'), findsOneWidget);
      expect(byKey('send-all-confirm'), findsNothing);
      expect(server.sends, isEmpty);
    });
  });

  test('wish context: web buildVars keys, each also lower- and upper-cased', () {
    final ctx = birthdayWishContext(
        DashboardBirthdayEmployee.fromJson(person('TST009', 'Kiran Rao Test')), 'Test Co');
    expect(ctx['first_name'], 'Kiran');
    expect(ctx['last_name'], 'Test');
    expect(ctx['EMPLOYEE_NAME'], 'Kiran Rao Test');
    expect(ctx['COMPANY_NAME'], 'Test Co');
    expect(ctx['designation'], 'Analyst');
  });
}
