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
import 'package:mobile_app/features/interview_list/presentation/widgets/add_candidate_sheet.dart';
import 'package:mobile_app/features/interview_list/presentation/widgets/candidate_card.dart';

// P1-5: Interview scheduling fields, as web interview-list AddCandidateModal
// (POST /recruitment/candidates/ with the form incl. interview_time,
// meeting_link, interviewer uuid|null) and EditCandidateModal (update with
// interview_date|null, interview_time "HH:MM"|null, interview_mode,
// meeting_link only for video_call else "", interviewer uuid|null; no
// separate send-email — the backend queues the invitation when date/time/
// link change). Production Candidate: interview_time TimeField, meeting_link
// URLField (server-validated), interviewer FK to User (uuid). Mocked Dio,
// synthetic people only — nothing is scheduled or emailed.

const candidateId = 7;

String today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day).toIso8601String().split('T').first;
}

Map<String, dynamic> cand({
  String interviewDate = '',
  int? branch = 1,
  String status = 'pending',
  String? time,
  String mode = 'in_person',
  String link = '',
  String? interviewer,
  String interviewerName = '',
}) =>
    {
      'id': candidateId,
      'name': 'Test Candidate',
      'email': 'candidate@example.test',
      'phone': '9000000000',
      'position_applied': 'Analyst',
      'branch': branch,
      'branch_name': branch == null ? '' : 'North',
      'interview_date': interviewDate.isEmpty ? null : interviewDate,
      'interview_time': time,
      'interview_mode': mode,
      'meeting_link': link,
      'interviewer': interviewer,
      'interviewer_name': interviewerName,
      'status': status,
      'portal_credentials_sent': false,
      'added_by_name': 'Test HR',
      'created_at': '2026-11-01T10:00:00Z',
      'logs': [],
    };

class Server implements HttpClientAdapter {
  final calls = <({String method, String path, Object? body, Map<String, dynamic> query})>[];
  int? writeStatus;
  String writeError = 'Enter a valid URL.';
  Completer<void>? holdWrite;

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  List<Map<String, dynamic>> writes(String method) => calls
      .where((c) => c.method == method && !c.path.endsWith('/send-email/'))
      .map((c) => Map<String, dynamic>.from(c.body as Map))
      .toList();
  int get sendEmailCalls => calls.where((c) => c.path.endsWith('/send-email/')).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, body: o.data, query: Map.of(o.queryParameters)));
    if (o.method == 'POST' || o.method == 'PUT' || o.method == 'PATCH') {
      final gate = holdWrite;
      if (gate != null) await gate.future;
      if (writeStatus != null) {
        return _json({'status': 'error', 'message': writeError, 'data': {'meeting_link': [writeError]}}, writeStatus!);
      }
      final b = Map<String, dynamic>.from(o.data as Map);
      final saved = {
        ...cand(),
        ...b,
        'interview_time': b['interview_time'] == null ? null : '${b['interview_time']}:00',
        'interviewer_name': b['interviewer'] == null ? '' : 'Picked Interviewer',
      };
      return _json({'status': 'success', 'message': 'Saved.', 'data': saved}, o.method == 'POST' ? 201 : 200);
    }
    if (o.path == ApiConstants.employees) {
      return _json({
        'status': 'success',
        'data': {
          'count': 1,
          'results': [
            {'uuid': 'u-int-1', 'id': 'TST010', 'employee_id': 'TST010', 'full_name': 'Picked Interviewer', 'department': 'Tech'}
          ]
        }
      });
    }
    if (o.path == ApiConstants.branches) {
      return _json({
        'status': 'success',
        'data': {
          'results': [
            {'id': 1, 'branch_name': 'North'}
          ]
        }
      });
    }
    if (o.path == ApiConstants.candidateStats) {
      return _json({'status': 'success', 'data': {'total': 1, 'pending': 1, 'selected': 0, 'rejected': 0}});
    }
    if (o.path == ApiConstants.candidates) {
      return _json({
        'status': 'success',
        'data': {'count': 1, 'page': 1, 'page_size': 10, 'total_pages': 1, 'status_choices': [], 'results': [cand()]}
      });
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
  _Auth([this.perms = const ['recruitment.view', 'recruitment.edit', 'recruitment.create', 'employees.view']]);
  final List<String> perms;
  @override
  Future<AuthState> build() async => AuthState(
      user: UserEntity(
          id: 'u1',
          email: 'hr@example.test',
          fullName: 'Test HR',
          role: 'hr',
          roleDisplay: 'HR',
          branch: 'North',
          mustChangePassword: false,
          permissions: perms,
          onboardingStatus: 'complete',
          assessmentStatus: 'complete'));
}

late Server server;

Future<void> open(WidgetTester tester, {Map<String, dynamic>? existing, Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth()),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          // As in the app (the router watches auth), the signed-in user is
          // loaded before the dialog reads it for the branch lock.
          ref.watch(authStateProvider);
          ref.watch(candidateListProvider);
          return Center(
            child: ElevatedButton(
              key: const Key('open'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    AddCandidateDialog(existing: existing == null ? null : CandidateModel.fromJson(existing)),
              ),
              child: const Text('open'),
            ),
          );
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

Future<void> pickToday(WidgetTester tester) async {
  await tester.tap(find.text('dd/mm/yyyy'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

/// Opens the time picker and accepts its initial value (10:00 when unset).
Future<void> pickDefaultTime(WidgetTester tester) async {
  await tester.ensureVisible(byKey('candidate-interview-time'));
  await tester.tap(byKey('candidate-interview-time'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> chooseMode(WidgetTester tester, String from, String to) async {
  await tester.ensureVisible(find.text(from).first);
  await tester.tap(find.text(from).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(to).last);
  await tester.pumpAndSettle();
}

Future<void> pickInterviewer(WidgetTester tester) async {
  final field = find.descendant(of: byKey('candidate-interviewer'), matching: find.byType(TextField));
  await tester.ensureVisible(field);
  await tester.enterText(field, 'pic');
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Picked Interviewer'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

const invited = 'Interview details saved. An interview invitation email will be sent to the candidate.';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('serialization', () {
    test('time is read from the backend (HH:MM[:SS]) and sent as web\'s HH:MM', () {
      expect(formatInterviewTime(const TimeOfDay(hour: 9, minute: 5)), '09:05');
      expect(formatInterviewTime(const TimeOfDay(hour: 14, minute: 30)), '14:30');
      expect(parseInterviewTime('14:30:00'), const TimeOfDay(hour: 14, minute: 30));
      expect(parseInterviewTime('09:05'), const TimeOfDay(hour: 9, minute: 5));
      expect(parseInterviewTime(''), isNull);
      expect(parseInterviewTime('25:00'), isNull);
    });

    test('the candidate model reads interview_time, meeting_link, interviewer and interviewer_name', () {
      final c = CandidateModel.fromJson(cand(
          interviewDate: '2030-01-15',
          time: '14:30:00',
          mode: 'video_call',
          link: 'https://meet.example.test/abc',
          interviewer: 'u-int-2',
          interviewerName: 'Second Interviewer'));
      expect([c.interviewTime, c.meetingLink, c.interviewer, c.interviewerName],
          ['14:30:00', 'https://meet.example.test/abc', 'u-int-2', 'Second Interviewer']);
      final bare = CandidateModel.fromJson(cand());
      expect([bare.interviewTime, bare.meetingLink, bare.interviewer, bare.interviewerName], ['', '', null, '']);
    });
  });

  group('Add candidate', () {
    Future<void> fillBasics(WidgetTester tester) async {
      await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Anjali Sharma'), 'New Person');
      await tester.enterText(find.widgetWithText(TextFormField, 'anjali@gmail.com'), 'new@example.test');
      await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Backend Engineer'), 'Analyst');
    }

    testWidgets('with every scheduling field: one POST with date, HH:MM time, video link and interviewer uuid',
        (tester) async {
      await open(tester);
      await fillBasics(tester);
      await pickToday(tester);
      await pickDefaultTime(tester);
      await chooseMode(tester, 'In-Person', 'Video Call');
      await tester.enterText(byKey('candidate-meeting-link'), 'https://meet.example.test/abc');
      await pickInterviewer(tester);
      await save(tester, 'Add to List');

      final posts = server.writes('POST');
      expect(posts, hasLength(1));
      final b = posts.single;
      expect(b['interview_date'], today());
      expect(b['interview_time'], '10:00');
      expect(b['interview_mode'], 'video_call');
      expect(b['meeting_link'], 'https://meet.example.test/abc');
      expect(b['interviewer'], 'u-int-1');
      expect([b['name'], b['email'], b['position_applied'], b['branch']],
          ['New Person', 'new@example.test', 'Analyst', 1]);
      expect(server.sendEmailCalls, 0, reason: 'the backend queues the invitation');
      expect(find.text(invited), findsOneWidget);
    });

    testWidgets('without scheduling: no time key, empty link, null interviewer, no invitation message',
        (tester) async {
      await open(tester);
      await fillBasics(tester);
      expect(byKey('candidate-meeting-link'), findsNothing, reason: 'link only for Video Call');
      await save(tester, 'Add to List');
      final b = server.writes('POST').single;
      expect(b.containsKey('interview_time'), isFalse);
      expect(b.containsKey('interview_date'), isFalse);
      expect(b['meeting_link'], '');
      expect(b.containsKey('interviewer'), isTrue);
      expect(b['interviewer'], isNull);
      expect(find.text(invited), findsNothing);
    });

    testWidgets('required fields are still enforced before any request', (tester) async {
      await open(tester);
      await save(tester, 'Add to List');
      expect(server.writes('POST'), isEmpty);
      expect(find.text('Add Candidate to Interview List'), findsOneWidget);
    });
  });

  group('Edit / first-time scheduling', () {
    testWidgets('first-time scheduling: invite note, one PUT with date/time/interviewer, link cleared, no send-email',
        (tester) async {
      await open(tester, existing: cand());
      expect(byKey('candidate-invite-note'), findsNothing);
      await pickToday(tester);
      expect(byKey('candidate-invite-note'), findsOneWidget);
      await pickDefaultTime(tester);
      await pickInterviewer(tester);
      await save(tester, 'Save Changes');

      final puts = server.writes('PUT');
      expect(puts, hasLength(1));
      final b = puts.single;
      expect(server.calls.where((c) => c.method == 'PUT').single.path, ApiConstants.candidateDetail(candidateId));
      expect(b['interview_date'], today());
      expect(b['interview_time'], '10:00');
      expect(b['interview_mode'], 'in_person');
      expect(b['meeting_link'], '', reason: 'web: no link unless Video Call');
      expect(b['interviewer'], 'u-int-1');
      expect(server.sendEmailCalls, 0);
      expect(find.text(invited), findsOneWidget);
    });

    testWidgets('existing interview values are prefilled and an untouched save resends them (no invitation)',
        (tester) async {
      await open(tester,
          existing: cand(
              interviewDate: '2030-01-15',
              time: '14:30:00',
              mode: 'video_call',
              link: 'https://meet.example.test/abc',
              interviewer: 'u-int-2',
              interviewerName: 'Second Interviewer'));
      expect(find.text('15/1/2030'), findsOneWidget);
      expect(find.text('14:30'), findsOneWidget);
      expect(find.text('Video Call'), findsOneWidget);
      expect(tester.widget<TextFormField>(byKey('candidate-meeting-link')).controller!.text,
          'https://meet.example.test/abc');
      expect(find.text('Second Interviewer'), findsOneWidget);
      expect(byKey('candidate-invite-note'), findsNothing);

      await save(tester, 'Save Changes');
      final b = server.writes('PUT').single;
      expect(b['interview_date'], '2030-01-15');
      expect(b['interview_time'], '14:30');
      expect(b['interview_mode'], 'video_call');
      expect(b['meeting_link'], 'https://meet.example.test/abc');
      expect(b['interviewer'], 'u-int-2');
      expect(find.text(invited), findsNothing, reason: 'nothing that triggers the email changed');
    });

    testWidgets('editing: leaving Video Call clears the link; clearing time and interviewer sends null',
        (tester) async {
      await open(tester,
          existing: cand(
              interviewDate: '2030-01-15',
              time: '14:30:00',
              mode: 'video_call',
              link: 'https://meet.example.test/abc',
              interviewer: 'u-int-2',
              interviewerName: 'Second Interviewer'));
      await chooseMode(tester, 'Video Call', 'Phone');
      expect(byKey('candidate-meeting-link'), findsNothing);
      await tester.tap(byKey('candidate-interview-time-clear'));
      await tester.pumpAndSettle();
      final clearInterviewer =
          find.descendant(of: byKey('candidate-interviewer'), matching: find.byIcon(Icons.close));
      await tester.ensureVisible(clearInterviewer);
      await tester.tap(clearInterviewer);
      await tester.pumpAndSettle();
      await save(tester, 'Save Changes');
      final b = server.writes('PUT').single;
      expect(b['interview_mode'], 'phone');
      expect(b['meeting_link'], '');
      expect(b.containsKey('interview_time'), isTrue);
      expect(b['interview_time'], isNull);
      expect(b['interviewer'], isNull);
      expect(find.text(invited), findsOneWidget, reason: 'time/link changed with a date set → backend emails');
    });

    testWidgets('a rejected meeting link (server 400) keeps the dialog and every value; retry succeeds',
        (tester) async {
      await open(tester, existing: cand(), with_: Server()..writeStatus = 400);
      await pickToday(tester);
      await pickDefaultTime(tester);
      await chooseMode(tester, 'In-Person', 'Video Call');
      await tester.enterText(byKey('candidate-meeting-link'), 'not a url');
      await pickInterviewer(tester);
      await save(tester, 'Save Changes');

      expect(find.text('Enter a valid URL.'), findsOneWidget);
      expect(find.text('Edit Candidate'), findsOneWidget, reason: 'dialog stays open');
      expect(tester.widget<TextFormField>(byKey('candidate-meeting-link')).controller!.text, 'not a url');
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('Picked Interviewer'), findsOneWidget);

      server.writeStatus = null;
      await tester.enterText(byKey('candidate-meeting-link'), 'https://meet.example.test/ok');
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await save(tester, 'Save Changes');
      expect(server.writes('PUT'), hasLength(2));
      expect(server.writes('PUT').last['meeting_link'], 'https://meet.example.test/ok');
      expect(find.text('Edit Candidate'), findsNothing);
      expect(server.sendEmailCalls, 0);
    });

    testWidgets('a second tap while saving sends no second request', (tester) async {
      await open(tester, existing: cand(interviewDate: '2030-01-15'), with_: Server()..holdWrite = Completer());
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.tap(find.text('Save Changes'), warnIfMissed: false);
      await tester.pump();
      server.holdWrite!.complete();
      await tester.pumpAndSettle();
      expect(server.writes('PUT'), hasLength(1));
    });
  });

  group('clearing the interview date (web EditCandidateModal sends interview_date: null)', () {
    Map<String, dynamic> scheduled() => cand(
        interviewDate: '2030-01-15',
        time: '14:30:00',
        mode: 'video_call',
        link: 'https://meet.example.test/abc',
        interviewer: 'u-int-2',
        interviewerName: 'Second Interviewer');

    testWidgets('clearing an existing date sends null, keeps the other fields, and claims no invitation',
        (tester) async {
      await open(tester, existing: scheduled());
      expect(find.text('15/1/2030'), findsOneWidget);
      await tester.tap(byKey('candidate-interview-date-clear'));
      await tester.pumpAndSettle();
      expect(find.text('dd/mm/yyyy'), findsOneWidget);
      expect(byKey('candidate-invite-note'), findsNothing);
      await save(tester, 'Save Changes');

      final b = server.writes('PUT').single;
      expect(b.containsKey('interview_date'), isTrue);
      expect(b['interview_date'], isNull);
      expect([b['interview_time'], b['interview_mode'], b['meeting_link'], b['interviewer']],
          ['14:30', 'video_call', 'https://meet.example.test/abc', 'u-int-2']);
      expect(server.sendEmailCalls, 0);
      expect(find.text(invited), findsNothing, reason: 'the backend sends nothing without a date');
      expect(find.text('Edit Candidate'), findsNothing, reason: 'saved and closed');
    });

    testWidgets('a cleared date stays cleared: a failed save keeps it empty and the retry sends null again',
        (tester) async {
      await open(tester, existing: scheduled(), with_: Server()..writeStatus = 422..writeError = 'Try again.');
      await tester.tap(byKey('candidate-interview-date-clear'));
      await tester.pumpAndSettle();
      await save(tester, 'Save Changes');
      expect(find.text('Try again.'), findsOneWidget);
      expect(find.text('dd/mm/yyyy'), findsOneWidget, reason: 'not restored from the candidate');

      server.writeStatus = null;
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await save(tester, 'Save Changes');
      final puts = server.writes('PUT');
      expect(puts, hasLength(2));
      expect(puts.every((b) => b['interview_date'] == null), isTrue);
    });

    test('the saved (cleared) candidate reloads with no date', () {
      final c = CandidateModel.fromJson(cand(interviewDate: ''));
      expect(c.interviewDate, '');
    });

    testWidgets('picking a new date after clearing schedules again (and the invitation is announced)',
        (tester) async {
      await open(tester, existing: scheduled());
      await tester.tap(byKey('candidate-interview-date-clear'));
      await tester.pumpAndSettle();
      await pickToday(tester);
      await save(tester, 'Save Changes');
      expect(server.writes('PUT').single['interview_date'], today());
      expect(find.text(invited), findsOneWidget);
    });

    testWidgets('Add without a date still leaves interview_date out entirely', (tester) async {
      await open(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Anjali Sharma'), 'New Person');
      await tester.enterText(find.widgetWithText(TextFormField, 'anjali@gmail.com'), 'new@example.test');
      await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Backend Engineer'), 'Analyst');
      await save(tester, 'Add to List');
      expect(server.writes('POST').single.containsKey('interview_date'), isFalse);
    });
  });

  group('web Edit Interview Details workflow gaps', () {
    testWidgets('a branch-restricted user editing a candidate with no branch gets their own branch (as web)',
        (tester) async {
      await open(tester, existing: cand(branch: null));
      await save(tester, 'Save Changes');
      expect(find.text('Please select a branch'), findsNothing);
      expect(server.writes('PUT').single['branch'], 1);
    });

    Future<void> pumpCard(WidgetTester tester, Map<String, dynamic> c, {List<String>? perms}) async {
      tester.view.physicalSize = const Size(1080, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      server = Server();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => perms == null ? _Auth() : _Auth(perms)),
          dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullStorage()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(builder: (context, ref, _) {
              ref.watch(authStateProvider);
              return SingleChildScrollView(child: CandidateCard(candidate: CandidateModel.fromJson(c)));
            }),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('Edit is offered with recruitment.edit for a non-converted candidate and opens the dialog',
        (tester) async {
      await pumpCard(tester, cand(interviewDate: '2030-01-15'));
      expect(byKey('candidate-edit-$candidateId'), findsOneWidget);
      await tester.tap(byKey('candidate-edit-$candidateId'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Candidate'), findsOneWidget);
    });

    testWidgets('no Edit for a converted candidate (backend refuses it)', (tester) async {
      await pumpCard(tester, cand(status: 'converted'));
      expect(byKey('candidate-edit-$candidateId'), findsNothing);
    });

    testWidgets('no Edit without recruitment.edit', (tester) async {
      await pumpCard(tester, cand(), perms: const ['recruitment.view']);
      expect(byKey('candidate-edit-$candidateId'), findsNothing);
    });
  });
}
