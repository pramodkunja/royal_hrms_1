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
import 'package:mobile_app/features/interview_list/presentation/widgets/mark_candidate_sheet.dart';

// P0: candidate emails must go out once. Production sends them server-side:
// - PATCH /recruitment/candidates/<id>/status/ to selected/rejected sends
//   candidate_selected / candidate_rejected and reports the outcome only in
//   the envelope message (CandidateStatusView.patch);
// - PUT/PATCH /recruitment/candidates/<id>/ sends interview_scheduled_candidate
//   whenever interview date/time/link is set or changed
//   (_fire_interview_date_emails_if_needed).
// So mobile must never also POST /recruitment/candidates/<id>/send-email/.
// Mocked Dio only — synthetic candidates, nothing real is updated or emailed.

const candidateId = 7;

Map<String, dynamic> cand({String status = 'pending', String interviewDate = '2026-12-01'}) => {
      'id': candidateId,
      'name': 'Test Candidate',
      'email': 'candidate@example.test',
      'phone': '9000000000',
      'position_applied': 'Analyst',
      'branch': 1,
      'branch_name': 'North',
      'interview_date': interviewDate,
      'interview_mode': 'in_person',
      'status': status,
      'portal_credentials_sent': false,
      'added_by_name': 'Test HR',
      'created_at': '2026-11-01T10:00:00Z',
      'logs': [],
    };

Map<String, dynamic> template(int id, String slug) => {
      'id': id,
      'name': slug,
      'display_name': slug,
      'subject': 'Subject',
      'body': 'Body',
      'template_type': 'recruitment',
      'is_active': true,
    };

class Server implements HttpClientAdapter {
  final calls = <({String method, String path, Object? body})>[];

  /// Envelope message of a successful status PATCH (selected/rejected).
  String statusMessage = 'Test Candidate marked as Selected. Notification email sent.';
  int statusCode = 200;

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  List<({String method, String path, Object? body})> where(String method, String path) =>
      calls.where((c) => c.method == method && c.path == path).toList();

  int get sendEmailCalls => calls.where((c) => c.path.endsWith('/send-email/')).length;

  int get writes => calls.where((c) => c.method != 'GET').length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, body: o.data));
    if (o.path.endsWith('/send-email/')) {
      return _json({'status': 'success', 'message': 'Email sent.', 'data': {}});
    }
    if (o.method == 'PATCH' && o.path == ApiConstants.candidateStatus(candidateId)) {
      if (statusCode != 200) {
        return _json({'status': 'error', 'message': 'Cannot change status of a converted candidate.', 'data': {}},
            statusCode);
      }
      final s = (o.data as Map)['status'] as String;
      return _json({'status': 'success', 'message': statusMessage, 'data': cand(status: s)});
    }
    if (o.method == 'PUT' && o.path == ApiConstants.candidateDetail(candidateId)) {
      final d = Map<String, dynamic>.from(o.data as Map);
      return _json({
        'status': 'success',
        'message': 'Candidate updated.',
        'data': cand(interviewDate: d['interview_date'] as String? ?? ''),
      });
    }
    if (o.path == ApiConstants.candidateStats) {
      return _json({
        'status': 'success',
        'data': {'total': 1, 'pending': 1, 'selected': 0, 'rejected': 0}
      });
    }
    if (o.path == ApiConstants.candidates) {
      return _json({
        'status': 'success',
        'data': {
          'count': 1,
          'page': 1,
          'page_size': 10,
          'total_pages': 1,
          'status_choices': [],
          'results': [cand()],
        }
      });
    }
    if (o.path == ApiConstants.settingsEmailTemplates) {
      return _json({
        'status': 'success',
        'data': {
          'count': 2,
          'results': {
            'recruitment': [template(1, 'candidate_selected'), template(2, 'candidate_rejected')]
          }
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
  @override
  Future<AuthState> build() async => const AuthState(
      user: UserEntity(
          id: 'u1',
          email: 'hr@example.test',
          fullName: 'Test HR',
          role: 'hr',
          roleDisplay: 'HR',
          mustChangePassword: false,
          permissions: ['recruitment.view', 'recruitment.edit', 'recruitment.create', 'settings.view'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete'));
}

late Server server;
bool? sheetResult;

/// Host that keeps the candidate list alive (as the Interview List screen
/// does) and opens [open] from a button.
Future<void> pumpHost(WidgetTester tester, Future<void> Function(BuildContext) open) async {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  sheetResult = null;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          ref.watch(candidateListProvider);
          return Center(
            child: ElevatedButton(
              key: const Key('open'),
              onPressed: () => open(context),
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

Future<void> openMark(WidgetTester tester, String target) => pumpHost(tester, (context) async {
      sheetResult = await MarkCandidateSheet.show(
        context,
        candidate: CandidateModel.fromJson(cand()),
        targetStatus: target,
      );
    });

Future<void> confirmMark(WidgetTester tester) async {
  await tester.tap(find.text('Confirm & Send Email'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Mark Selected / Rejected', () {
    for (final target in ['selected', 'rejected']) {
      testWidgets('$target: one status PATCH (with remarks) and no separate send-email request', (tester) async {
        await openMark(tester, target);
        await tester.enterText(find.byType(TextField).first, 'Strong interview');
        server.calls.clear();
        await confirmMark(tester);

        final patches = server.where('PATCH', ApiConstants.candidateStatus(candidateId));
        expect(patches, hasLength(1));
        expect(patches.single.body, {'status': target, 'remarks': 'Strong interview'});
        expect(server.sendEmailCalls, 0, reason: 'the backend already emails the candidate');
        expect(server.writes, 1, reason: 'the status PATCH is the only write');
        expect(sheetResult, isTrue, reason: 'sheet closes as successful');
        expect(find.text('Confirm & Send Email'), findsNothing);
        expect(find.byType(SnackBar), findsNothing, reason: 'no warning when the server sent the email');
        // the list shows the server's updated status
        final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('open'))));
        expect(container.read(candidateListProvider).value!.items.single.status, target);
      });
    }

    testWidgets('when the server reports the email failed, its message is shown as a warning — still no send-email',
        (tester) async {
      await openMark(tester, 'rejected');
      server.statusMessage = 'Test Candidate marked as Rejected. Email could not be sent — check SMTP settings.';
      await confirmMark(tester);
      expect(sheetResult, isTrue, reason: 'the status change itself succeeded');
      expect(find.text('Test Candidate marked as Rejected. Email could not be sent — check SMTP settings.'),
          findsOneWidget);
      expect(server.sendEmailCalls, 0);
    });

    testWidgets('a failed status PATCH keeps the sheet open with the error and sends nothing else', (tester) async {
      await openMark(tester, 'selected');
      server.statusCode = 400;
      server.calls.clear();
      await confirmMark(tester);
      expect(find.text('Cannot change status of a converted candidate.'), findsOneWidget);
      expect(find.text('Confirm & Send Email'), findsOneWidget, reason: 'sheet stays open for a retry');
      expect(sheetResult, isNull);
      expect(server.sendEmailCalls, 0);
      expect(server.writes, 1);
    });
  });

  group('Interview scheduling', () {
    Future<void> openEdit(WidgetTester tester, {required String interviewDate}) =>
        pumpHost(tester, (context) => showDialog<void>(
              context: context,
              builder: (_) => AddCandidateDialog(existing: CandidateModel.fromJson(cand(interviewDate: interviewDate))),
            ));

    String today() {
      final n = DateTime.now();
      return DateTime(n.year, n.month, n.day).toIso8601String().split('T').first;
    }

    testWidgets('first-time scheduling: one PUT with the interview date and no separate send-email request',
        (tester) async {
      await openEdit(tester, interviewDate: '');
      await tester.tap(find.text('dd/mm/yyyy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      server.calls.clear();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      final puts = server.where('PUT', ApiConstants.candidateDetail(candidateId));
      expect(puts, hasLength(1));
      expect((puts.single.body as Map)['interview_date'], today());
      expect(server.sendEmailCalls, 0, reason: 'the backend sends interview_scheduled_candidate on save');
      expect(server.writes, 1);
      expect(find.text('Edit Candidate'), findsNothing, reason: 'dialog closed');
      expect(find.text('Interview details saved. An interview invitation email will be sent to the candidate.'),
          findsOneWidget);
    });

    testWidgets('editing an already-scheduled candidate also sends no send-email request', (tester) async {
      await openEdit(tester, interviewDate: '2030-01-15');
      server.calls.clear();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(server.where('PUT', ApiConstants.candidateDetail(candidateId)), hasLength(1));
      expect(server.sendEmailCalls, 0);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
