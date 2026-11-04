import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/assessments/presentation/providers/assessment_take_providers.dart';
import 'package:mobile_app/features/assessments/presentation/screens/assessment_take_screen.dart';
import 'package:mobile_app/features/assessments/presentation/widgets/assessment_item_view.dart';
import 'package:mobile_app/shared/widgets/app_button.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

import 'assessment_fake_server.dart';

// Phase 3: taking an assessment against a stand-in for the production
// portal API — instructions, items in order, per-item saving, submission,
// the server's result, and retake.

final _now = DateTime(2026, 11, 4, 9);

class _NullSecureStorage extends SecureStorageService {
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

UserEntity _employee({String assessment = 'pending'}) => UserEntity(
    id: 'u1',
    email: 'e@example.com',
    fullName: 'Pat',
    role: 'employee',
    roleDisplay: 'Employee',
    mustChangePassword: false,
    permissions: const [],
    onboardingStatus: 'complete',
    assessmentStatus: assessment);

late FakeAssessmentServer server;
late List<String> opened;
late ProviderContainer container;

Future<void> pumpTake(WidgetTester tester, FakeAssignment a,
    {UserEntity? user, String profile = 'pending'}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = FakeAssessmentServer([a], profileStatus: profile);
  opened = [];
  final router = GoRouter(initialLocation: '/start', routes: [
    GoRoute(
        path: '/start', builder: (_, __) => const Scaffold(body: Text('LIST'))),
    GoRoute(
        path: AppRoutes.myAssessments,
        builder: (_, __) => const Scaffold(body: Text('LIST'))),
    GoRoute(
        path: AppRoutes.assessmentTake,
        builder: (_, s) => AssessmentTakeScreen(
            assignmentId: s.pathParameters['assignmentId']!)),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(
          Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
            ..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullSecureStorage()),
      authStateProvider.overrideWith(() => _Auth(user ?? _employee())),
      assessmentClockProvider.overrideWithValue(() => _now),
      assessmentVideoOpenerProvider
          .overrideWithValue((url) async => opened.add(url)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  container = ProviderScope.containerOf(tester.element(find.text('LIST')));
  await container
      .read(authStateProvider.future); // as in the app, auth is loaded
  router.push(AppRoutes.assessmentTakePath(a.id));
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> answer(WidgetTester tester, String option) async {
  await tester.tap(find.byKey(Key('assessment-option-$option')));
  await tester.pumpAndSettle();
  await tapText(tester, 'Submit answer');
}

AssessmentItemView itemView(WidgetTester tester) =>
    tester.widget<AssessmentItemView>(find.byType(AssessmentItemView));

FakeAssignment _two(
        {int maxAttempts = 2,
        int attemptCount = 1,
        int? remaining,
        int? limit,
        String? deadline}) =>
    FakeAssignment('a1',
        items: [
          quiz('q2', 2, 'b'),
          quiz('q1', 1, 'a')
        ], // server order shuffled
        maxAttempts: maxAttempts,
        attemptCount: attemptCount,
        timeRemainingSecs: remaining,
        timeLimitMins: limit,
        deadline: deadline);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('instructions', () {
    testWidgets('show the facts and rules; Start opens the first item in order',
        (tester) async {
      await pumpTake(tester, _two(limit: 15));
      expect(find.text('Workplace Safety'), findsWidgets);
      expect(find.text('2 questions'), findsOneWidget);
      expect(find.text('Pass mark'), findsOneWidget);
      expect(find.text('Attempts allowed'), findsOneWidget);
      expect(find.text('Attempts remaining'), findsOneWidget);
      expect(find.text('15 min'), findsOneWidget);
      expect(find.textContaining('15 minutes from your first answer'),
          findsOneWidget);
      expect(find.textContaining('You need 60% to pass.'), findsOneWidget);
      await tapText(tester, 'Start assessment');
      expect(
          itemView(tester).item.id, 'q1'); // order 1 first, though sent second
      expect(find.text('Item 1 of 2'), findsOneWidget);
      expect(server.count('POST', ''), 0); // starting sends nothing
    });

    testWidgets('a passed deadline blocks starting', (tester) async {
      await pumpTake(tester, _two(deadline: '2026-11-01T00:00:00Z'));
      expect(find.byKey(const Key('assessment-blocked')), findsOneWidget);
      expect(find.text('The deadline for this assessment has passed.'),
          findsOneWidget);
      await tapText(tester, 'Start assessment');
      expect(find.byType(AssessmentItemView), findsNothing);
    });
  });

  group('items', () {
    testWidgets(
        'quiz: answer required, saved immediately with the chosen option, then shown read-only',
        (tester) async {
      await pumpTake(tester, _two());
      await tapText(tester, 'Start assessment');
      expect(itemView(tester).onSave, isNotNull);
      final submit = tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Submit answer'));
      expect(submit.onPressed, isNull); // nothing chosen yet
      expect(find.byKey(const Key('assessment-option-d')),
          findsNothing); // empty option hidden
      await answer(tester, 'a');
      final post = server.calls.singleWhere((c) => c.method == 'POST');
      expect(post.path, '/assessments/a1/respond/q1/');
      expect(post.body, {'selected_option': 'a'});
      expect(find.byKey(const Key('assessment-verdict')), findsOneWidget);
      expect(find.textContaining('Correct'), findsOneWidget);
      expect(find.text('Submit answer'), findsNothing);
    });

    testWidgets(
        'items unlock in order, and an unsent choice survives moving between items',
        (tester) async {
      await pumpTake(
          tester,
          FakeAssignment('a1', items: [
            quiz('q1', 1, 'a'),
            quiz('q2', 2, 'b'),
            quiz('q3', 3, 'c')
          ]));
      await tapText(tester, 'Start assessment');
      expect(find.text('Next item'), findsNothing); // q1 not done yet
      await answer(tester, 'b');
      await tapText(tester, 'Next item');
      expect(itemView(tester).item.id, 'q2');
      await tester.tap(find.byKey(const Key('assessment-option-c')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Previous');
      expect(itemView(tester).item.id, 'q1');
      await tapText(tester, 'Next item');
      expect(itemView(tester).selected, 'c'); // still chosen, not yet sent
      expect(
          server.calls.where((c) => c.path.contains('/respond/q2/')), isEmpty);
    });

    testWidgets(
        'video: opened outside the app, then marked as watched with an empty body',
        (tester) async {
      await pumpTake(tester,
          FakeAssignment('a1', items: [video('v1', 1), quiz('q1', 2, 'a')]));
      await tapText(tester, 'Start assessment');
      expect(find.text('Duration: 3 min'), findsOneWidget);
      await tapText(tester, 'Open video');
      expect(opened, ['https://www.youtube.com/embed/abc']);
      await tapText(tester, 'Mark as watched');
      final post = server.calls.singleWhere((c) => c.method == 'POST');
      expect(post.path, '/assessments/a1/respond/v1/');
      expect(post.body, <String, dynamic>{});
      expect(find.text('You have watched this video.'), findsOneWidget);
    });

    testWidgets('a network failure keeps the choice and can be retried',
        (tester) async {
      await pumpTake(tester, _two());
      await tapText(tester, 'Start assessment');
      server.dropNextRespond = true;
      await answer(tester, 'a');
      expect(find.byKey(const Key('assessment-item-error')), findsOneWidget);
      expect(itemView(tester).selected, 'a');
      expect(itemView(tester).done, isFalse);
      await tapText(tester, 'Submit answer');
      expect(itemView(tester).done, isTrue);
    });

    testWidgets('a second tap while saving sends one request', (tester) async {
      await pumpTake(tester, _two());
      await tapText(tester, 'Start assessment');
      await tester.tap(find.byKey(const Key('assessment-option-a')));
      await tester.pumpAndSettle();
      final save = itemView(tester).onSave;
      save();
      save();
      await tester.pumpAndSettle();
      expect(server.count('POST', '/respond/'), 1);
    });

    testWidgets(
        'a deadline that passes while answering: the server\'s refusal is shown',
        (tester) async {
      await pumpTake(tester, _two());
      await tapText(tester, 'Start assessment');
      server.assignments.first.expired = true;
      await answer(tester, 'a');
      expect(find.text('The deadline for this assessment has passed.'),
          findsOneWidget);
      expect(itemView(tester).done, isFalse);
      expect(itemView(tester).selected, 'a');
    });
  });

  group('submission and results', () {
    Future<void> finishBoth(WidgetTester tester,
        {String first = 'a', String second = 'b'}) async {
      await tapText(tester, 'Start assessment');
      await answer(tester, first);
      await tapText(tester, 'Next item');
      await answer(tester, second);
    }

    testWidgets(
        'confirm, then the server grades it; the result and the refreshed list are shown',
        (tester) async {
      await pumpTake(tester, _two());
      await finishBoth(tester);
      final listCallsBefore = server.count('GET', '/assessments/my/');
      await tapText(tester, 'Submit assessment');
      await tapText(tester, 'Cancel');
      expect(server.count('POST', '/complete/'), 0);
      await tapText(tester, 'Submit assessment');
      await tapText(tester, 'Submit');
      expect(server.count('POST', '/complete/'), 1);
      expect(find.text('Passed'), findsOneWidget);
      expect(find.text('100% Score'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(server.count('GET', '/assessments/my/'),
          greaterThan(listCallsBefore));
      expect(find.text('Retake assessment'), findsNothing); // passed
    });

    testWidgets('submitting twice while the first is pending sends one request',
        (tester) async {
      await pumpTake(tester, _two());
      await finishBoth(tester);
      server.holdComplete = Completer();
      await tapText(tester, 'Submit assessment');
      await tester.tap(find.text('Submit').last);
      await tester.pump();
      expect(itemView(tester).submitting, isTrue);
      itemView(tester).onSubmitAssessment?.call();
      server.holdComplete!.complete();
      await tester.pumpAndSettle();
      expect(server.count('POST', '/complete/'), 1);
    });

    testWidgets(
        'a refused submission shows the server\'s message and no result',
        (tester) async {
      await pumpTake(tester, _two());
      await finishBoth(tester);
      server.assignments.first.responses.remove('q2'); // the server disagrees
      await tapText(tester, 'Submit assessment');
      await tapText(tester, 'Submit');
      expect(find.text('Complete all items first. 1/2 done.'), findsOneWidget);
      expect(find.text('Passed'), findsNothing);
      expect(find.text('Not Passed'), findsNothing);
    });

    testWidgets(
        'failed with attempts left: Retake resets it and shows the instructions again',
        (tester) async {
      await pumpTake(tester, _two());
      await finishBoth(tester, first: 'c', second: 'c'); // both wrong
      await tapText(tester, 'Submit assessment');
      await tapText(tester, 'Submit');
      expect(find.text('Not Passed'), findsOneWidget);
      await tapText(tester, 'Retake assessment');
      expect(server.count('POST', '/retry/'), 1);
      expect(find.text('Start assessment'), findsOneWidget);
      expect(server.assignments.first.attemptCount, 2);
    });

    testWidgets('failed with no attempts left: no Retake', (tester) async {
      await pumpTake(tester, _two(maxAttempts: 1));
      await finishBoth(tester, first: 'c', second: 'c');
      await tapText(tester, 'Submit assessment');
      await tapText(tester, 'Submit');
      expect(find.text('Not Passed'), findsOneWidget);
      expect(find.text('Retake assessment'), findsNothing);
    });

    testWidgets(
        'a completed assessment opens on its result and cannot be answered again',
        (tester) async {
      final a = _two(maxAttempts: 3);
      a.status = 'complete';
      a.score = 0;
      a.maxScore = 2;
      a.completedAt = '2026-11-03T10:00:00Z';
      await pumpTake(tester, a);
      expect(find.text('Not Passed'), findsOneWidget);
      expect(find.text('0% Score'), findsOneWidget);
      expect(find.byType(AssessmentItemView), findsNothing);
      expect(find.text('Retake assessment'), findsOneWidget);
    });

    testWidgets('a refused retake shows the server\'s message', (tester) async {
      final a = _two(maxAttempts: 0);
      a.status = 'complete';
      a.maxScore = 2;
      await pumpTake(tester, a);
      server.assignments
        ..clear()
        ..add(FakeAssignment('a1', items: a.items, maxAttempts: 1)
          ..status = 'complete'
          ..maxScore = 2);
      await tapText(tester, 'Retake assessment');
      expect(
          find.textContaining('Maximum attempts (1) reached'), findsOneWidget);
    });
  });

  group('time limit', () {
    testWidgets(
        'a timed attempt counts down and is submitted once when time runs out',
        (tester) async {
      final a = _two(limit: 10, remaining: 3);
      // Both answered already (resumed attempt).
      a.status = 'in_progress';
      a.responses['q1'] = {
        'item_id': 'q1',
        'item_type': 'quiz',
        'is_watched': false,
        'selected_option': 'a',
        'is_correct': true,
        'score_awarded': 1
      };
      a.responses['q2'] = {
        'item_id': 'q2',
        'item_type': 'quiz',
        'is_watched': false,
        'selected_option': 'b',
        'is_correct': true,
        'score_awarded': 1
      };
      await pumpTake(tester, a);
      expect(find.byKey(const Key('assessment-timer')), findsOneWidget);
      expect(find.text('00:03'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:02'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(server.count('POST', '/complete/'), 1);
      expect(find.text('Passed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(server.count('POST', '/complete/'), 1);
    });
  });

  group('gate release after completion', () {
    testWidgets('only the server\'s confirmation lifts the requirement',
        (tester) async {
      await pumpTake(tester, _two());
      expect(
          container.read(authStateProvider).valueOrNull?.user?.needsAssessments,
          isTrue);
      await tapText(tester, 'Start assessment');
      await answer(tester, 'a');
      // Still pending server-side: no release yet.
      expect(
          container.read(authStateProvider).valueOrNull?.user?.needsAssessments,
          isTrue);
      await tapText(tester, 'Next item');
      await answer(tester, 'b');
      await tapText(tester, 'Submit assessment');
      await tapText(tester, 'Submit');
      expect(
          container.read(authStateProvider).valueOrNull?.user?.assessmentStatus,
          'complete');
      expect(
          container.read(authStateProvider).valueOrNull?.user?.needsAssessments,
          isFalse);
    });

    testWidgets(
        'a failed (not passed) attempt still counts as completed for the gate, as on the server',
        (tester) async {
      await pumpTake(tester, _two(maxAttempts: 1));
      await tapText(tester, 'Start assessment');
      await answer(tester, 'c');
      await tapText(tester, 'Next item');
      await answer(tester, 'c');
      await tapText(tester, 'Submit assessment');
      await tapText(tester, 'Submit');
      expect(server.profileStatus, 'complete');
      expect(
          container.read(authStateProvider).valueOrNull?.user?.needsAssessments,
          isFalse);
    });
  });
}
