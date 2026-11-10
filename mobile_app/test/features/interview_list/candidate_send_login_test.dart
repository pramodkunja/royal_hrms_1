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
import 'package:mobile_app/features/interview_list/data/models/candidate_model.dart';
import 'package:mobile_app/features/interview_list/presentation/providers/interview_providers.dart';
import 'package:mobile_app/features/interview_list/presentation/widgets/candidate_card.dart';

// Task 17: web interview-list page.tsx shows "Send Login" only when
// `canEditRec && c.status === "selected"`; canEditRec = usePermission
// ("recruitment.edit") → is_superuser || permissions.includes(codename) —
// no settings.edit bypass on web. The button POSTs (no body)
// /recruitment/candidates/<id>/send-portal-login/ and is disabled
// ("Sending…") while it runs. Stand-in server only — no invitation is sent.

const id = 7;

Map<String, dynamic> cand(String status, {bool sent = false}) => {
      'id': id,
      'name': 'Test Candidate',
      'email': 'candidate@example.test',
      'phone': '9000000000',
      'position_applied': 'Analyst',
      'branch': 1,
      'branch_name': 'North',
      'interview_date': '2026-12-01',
      'interview_mode': 'in_person',
      'status': status,
      'portal_credentials_sent': sent,
      'added_by_name': 'Test HR',
      'created_at': '2026-11-01T10:00:00Z',
      'logs': <Object>[],
    };

class Server implements HttpClientAdapter {
  Server(this.listStatus);
  String listStatus;
  bool listSent = false;
  final sends = <({String path, Object? body})>[];
  Completer<void>? hold;
  ({int status, String message})? refuse;

  ResponseBody _json(Object b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'POST' &&
        (o.path == ApiConstants.candidateSendLogin(id) || o.path == ApiConstants.candidateResendLogin(id))) {
      sends.add((path: o.path, body: o.data));
      final gate = hold;
      if (gate != null) await gate.future;
      final r = refuse;
      if (r != null) return _json({'status': 'error', 'message': r.message, 'data': {}}, r.status);
      listStatus = 'offer_sent';
      listSent = true;
      return _json({'status': 'success', 'message': 'Portal login sent to candidate@example.test.', 'data': {}});
    }
    if (o.path == ApiConstants.candidates) {
      return _json({
        'status': 'success',
        'data': {
          'count': 1,
          'page': 1,
          'page_size': 10,
          'total_pages': 1,
          'status_choices': <Object>[],
          'results': [cand(listStatus, sent: listSent)],
        }
      });
    }
    if (o.path == ApiConstants.candidateStats) {
      return _json({'status': 'success', 'data': {'total': 1}});
    }
    return _json({'status': 'success', 'data': <String, dynamic>{}});
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

final editor = user(const ['recruitment.view', 'recruitment.edit']);
final viewer = user(const ['recruitment.view']);
final superuser = user(const [], superuser: true);
final settingsOnly = user(const ['recruitment.view', 'settings.edit']);

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Finder get sendButton => find.byKey(const Key('candidate-send-login-$id'));

Future<void> pumpCard(WidgetTester tester, String status, {UserEntity? as, bool sent = false, Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server(status);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? editor),
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          ref.watch(authStateProvider);
          ref.watch(candidateListProvider);
          return SingleChildScrollView(child: CandidateCard(candidate: CandidateModel.fromJson(cand(status, sent: sent))));
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rule (web: canEditRec && status === "selected")', () {
    test('recruitment.edit or superuser; settings.edit alone is NOT enough (web has no bypass)', () {
      final selected = CandidateModel.fromJson(cand('selected'));
      expect(canSendCandidateLogin(editor, selected), isTrue);
      expect(canSendCandidateLogin(superuser, selected), isTrue);
      expect(canSendCandidateLogin(viewer, selected), isFalse);
      expect(canSendCandidateLogin(settingsOnly, selected), isFalse);
      expect(canSendCandidateLogin(null, selected), isFalse);
    });

    test('only a Selected candidate — whether or not a login was already sent', () {
      for (final s in ['pending', 'screening', 'interview_scheduled', 'interview_done', 'rejected', 'offer_sent', 'converted']) {
        expect(canSendCandidateLogin(editor, CandidateModel.fromJson(cand(s))), isFalse, reason: s);
      }
      expect(canSendCandidateLogin(editor, CandidateModel.fromJson(cand('selected', sent: true))), isTrue);
      expect(canSendCandidateLogin(viewer, CandidateModel.fromJson(cand('selected', sent: true))), isFalse);
    });
  });

  group('visibility', () {
    // One user per test: re-pumping inside a test keeps the first scope's
    // signed-in user.
    for (final (name, u) in [('editor', editor), ('superuser', superuser)]) {
      testWidgets('$name sees Send Login on a Selected candidate (login not sent)', (tester) async {
        await pumpCard(tester, 'selected', as: u);
        expect(sendButton, findsOneWidget);
      });
    }

    testWidgets('a Selected candidate already sent a login still shows Send Login (not a badge)', (tester) async {
      await pumpCard(tester, 'selected', sent: true);
      expect(sendButton, findsOneWidget);
      expect(find.text('Login Sent'), findsNothing);
    });

    testWidgets('…but not without the permission (and no badge either, as on web)', (tester) async {
      await pumpCard(tester, 'selected', sent: true, as: viewer);
      expect(sendButton, findsNothing);
      expect(find.text('Login Sent'), findsNothing);
    });

    for (final (name, u) in [('viewer', viewer), ('settings.edit only', settingsOnly)]) {
      testWidgets('$name: no Send Login on a Selected candidate', (tester) async {
        await pumpCard(tester, 'selected', as: u);
        expect(sendButton, findsNothing);
        expect(find.text('Send Login'), findsNothing);
      });
    }

    for (final st in ['pending', 'interview_done', 'rejected']) {
      testWidgets('$st candidate: no Send Login', (tester) async {
        await pumpCard(tester, st);
        expect(sendButton, findsNothing);
      });
    }

    for (final (name, u) in [('editor', editor), ('viewer', viewer)]) {
      testWidgets('$name: Offer Sent shows "Login Sent"', (tester) async {
        await pumpCard(tester, 'offer_sent', sent: true, as: u);
        expect(find.text('Login Sent'), findsOneWidget);
        expect(sendButton, findsNothing);
      });

      testWidgets('$name: Converted shows "Employee"', (tester) async {
        await pumpCard(tester, 'converted', sent: true, as: u);
        expect(find.text('Employee'), findsOneWidget);
        expect(sendButton, findsNothing);
      });
    }
  });

  group('sending (unchanged API behaviour)', () {
    testWidgets('one POST with no body; the list refreshes to Login Sent', (tester) async {
      await pumpCard(tester, 'selected');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();
      expect(server.sends.single.path, ApiConstants.candidateSendLogin(id));
      expect(server.sends.single.body, isNull);
      final c = ProviderScope.containerOf(tester.element(find.byType(CandidateCard)));
      expect(c.read(candidateListProvider).value!.items.single.status, 'offer_sent');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('while sending: "Sending…", disabled, a second tap sends nothing', (tester) async {
      final s = Server('selected')..hold = Completer();
      await pumpCard(tester, 'selected', with_: s);
      await tester.tap(sendButton);
      await tester.pump();
      expect(find.text('Sending…'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(sendButton).onPressed, isNull);
      await tester.tap(sendButton, warnIfMissed: false);
      await tester.pump();
      s.hold!.complete();
      await tester.pumpAndSettle();
      expect(s.sends, hasLength(1));
    });

    testWidgets('already sent: the server\'s refusal is shown, one request, button usable again', (tester) async {
      const msg = 'Portal login already sent. Use resend if you want to issue new credentials.';
      final s = Server('selected')
        ..listSent = true
        ..refuse = (status: 400, message: msg);
      await pumpCard(tester, 'selected', sent: true, with_: s);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();
      expect(find.text(msg), findsOneWidget);
      expect(s.sends, hasLength(1));
      expect(s.sends.single.path, ApiConstants.candidateSendLogin(id), reason: 'never the resend endpoint');
      expect(tester.widget<ButtonStyleButton>(sendButton).onPressed, isNotNull);
    });

    testWidgets('a server refusal shows its message and the button is usable again', (tester) async {
      final s = Server('selected')..refuse = (status: 400, message: 'Candidate does not have a valid email address.');
      await pumpCard(tester, 'selected', with_: s);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();
      expect(find.text('Candidate does not have a valid email address.'), findsOneWidget);
      expect(find.text('Send Login'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(sendButton).onPressed, isNotNull);
    });
  });

  group('the action refuses what the button hides', () {
    Future<(String?, Server)> attempt(WidgetTester tester, UserEntity u, String listStatus, {bool resend = false}) async {
      server = Server(listStatus);
      late WidgetRef captured;
      await tester.pumpWidget(ProviderScope(
        overrides: overrides(u),
        child: Consumer(builder: (_, ref, __) {
          captured = ref;
          ref.watch(authStateProvider);
          ref.watch(candidateListProvider);
          return const SizedBox();
        }),
      ));
      await tester.pumpAndSettle();
      final err = await tester.runAsync(() => captured.read(candidateListProvider.notifier).sendLogin(id, resend: resend));
      return (err, server);
    }

    for (final (name, u) in [('viewer', viewer), ('settings.edit only', settingsOnly)]) {
      testWidgets('$name: refused, no request', (tester) async {
        final (err, s) = await attempt(tester, u, 'selected');
        expect(err, kCandidateSendLoginDenied);
        expect(s.sends, isEmpty);
      });
    }

    testWidgets('viewer: resend refused too', (tester) async {
      final (err, s) = await attempt(tester, viewer, 'offer_sent', resend: true);
      expect(err, kCandidateSendLoginDenied);
      expect(s.sends, isEmpty);
    });

    for (final status in ['interview_done', 'pending', 'converted']) {
      testWidgets('editor, $status candidate: refused, no request', (tester) async {
        final (err, s) = await attempt(tester, editor, status);
        expect(err, kCandidateSendLoginDenied);
        expect(s.sends, isEmpty);
      });
    }

    for (final (name, u) in [('editor', editor), ('superuser', superuser)]) {
      testWidgets('$name, Selected candidate: sent once', (tester) async {
        final (err, s) = await attempt(tester, u, 'selected');
        expect(err, isNull);
        expect(s.sends, hasLength(1));
      });
    }
  });
}
