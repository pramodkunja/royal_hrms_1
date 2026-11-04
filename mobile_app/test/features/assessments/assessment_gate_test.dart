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
import 'package:mobile_app/features/assessments/data/models/my_assessment_model.dart';
import 'package:mobile_app/features/assessments/presentation/providers/assessment_take_providers.dart';
import 'package:mobile_app/features/assessments/presentation/screens/assessment_gate_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

import '../../core/router/access_control_test.dart' as roles;
import 'assessment_fake_server.dart';

// Phase 3: the onboarding assessment gate (web frontend/proxy.ts
// needsAssessments) and its server-confirmed release.

UserEntity _user({
  String onboarding = 'complete',
  String? assessment = 'pending',
  bool mustChange = false,
  bool team = false,
  bool branch = false,
  bool superuser = false,
  List<String> permissions = const [],
}) =>
    UserEntity(
      id: 'u1',
      email: 'e@example.com',
      fullName: 'Pat',
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: mustChange,
      permissions: permissions,
      onboardingStatus: onboarding,
      assessmentStatus: assessment,
      canManageTeam: team,
      canManageBranch: branch,
      isSuperuser: superuser,
    );

String? _go(UserEntity? u, String path) => resolveAuthRedirect(
    authState: u == null ? const AuthState.initial() : AuthState(user: u),
    path: path);

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

List<String> _routes() {
  final c = ProviderContainer(overrides: [
    secureStorageProvider.overrideWithValue(_NullSecureStorage())
  ]);
  addTearDown(c.dispose);
  List<String> walk(List<RouteBase> rs) => [
        for (final r in rs) ...[
          if (r is GoRoute) r.path.replaceAll(RegExp(r':[A-Za-z]+'), 'x1'),
          ...walk(r.routes)
        ]
      ];
  return walk(c.read(appRouterProvider).configuration.routes);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('the gate is enabled together with the full taking flow', () {
    expect(kAssessmentGateEnabled, isTrue);
  });

  group('who is gated (web needsAssessments)', () {
    test(
        'onboarding approved + assessment pending: everything leads to the assessment portal',
        () {
      final u = _user();
      expect(u.needsAssessments, isTrue);
      for (final p in [
        AppRoutes.dashboard,
        AppRoutes.leave,
        AppRoutes.myAssessments,
        AppRoutes.profile,
        '/settings/roles'
      ]) {
        expect(_go(u, p), AppRoutes.onboardingAssessments, reason: p);
      }
      expect(_go(u, AppRoutes.onboardingAssessments), isNull);
      expect(_go(u, AppRoutes.assessmentTakePath('a1')), isNull);
      expect(_go(u, AppRoutes.splash), isNull);
    });

    test(
        'not gated: no assessment pending, unknown status, managers, branch managers, superusers',
        () {
      for (final u in [
        _user(assessment: 'complete'),
        _user(assessment: null),
        _user(team: true),
        _user(branch: true),
        _user(superuser: true),
      ]) {
        expect(u.needsAssessments, isFalse);
        expect(_go(u, AppRoutes.dashboard), isNull);
      }
    });

    test(
        'onboarding still open: the onboarding rules apply and the portal is not reachable',
        () {
      expect(_go(_user(onboarding: 'pending'), AppRoutes.onboardingAssessments),
          AppRoutes.onboarding);
      expect(_go(_user(onboarding: 'pending'), AppRoutes.dashboard),
          AppRoutes.onboarding);
      expect(
          _go(_user(onboarding: 'submitted'), AppRoutes.onboardingAssessments),
          AppRoutes.onboardingAwaiting);
      expect(
          _go(_user(onboarding: 'submitted'),
              AppRoutes.assessmentTakePath('a1')),
          AppRoutes.onboardingAwaiting);
    });

    test('a forced password change comes first', () {
      final u = _user(mustChange: true);
      expect(_go(u, AppRoutes.onboardingAssessments), AppRoutes.changePassword);
      expect(
          _go(u, AppRoutes.assessmentTakePath('a1')), AppRoutes.changePassword);
      expect(_go(u, AppRoutes.dashboard), AppRoutes.changePassword);
    });

    test('signed out: the assessment screens go to login', () {
      expect(_go(null, AppRoutes.onboardingAssessments), AppRoutes.login);
      expect(_go(null, AppRoutes.assessmentTakePath('a1')), AppRoutes.login);
    });

    test('no redirect loops: every redirect lands where it is allowed to stay',
        () {
      final users = [
        _user(),
        _user(assessment: 'complete'),
        _user(onboarding: 'pending'),
        _user(onboarding: 'submitted'),
        _user(mustChange: true),
        _user(team: true),
        null,
      ];
      for (final u in users) {
        for (final p in _routes()) {
          final r = _go(u, p);
          if (r != null) {
            expect(_go(u, r), isNull,
                reason:
                    '$p -> $r for ${u?.onboardingStatus}/${u?.assessmentStatus}');
          }
        }
      }
    });

    test('everyone else keeps their routes and permissions', () {
      expect(_go(roles.employee, AppRoutes.leave), isNull);
      expect(_go(roles.employee, AppRoutes.employees), AppRoutes.dashboard);
      expect(_go(roles.manager, AppRoutes.approvals), isNull);
      expect(_go(roles.systemAdmin, AppRoutes.assessments), isNull);
      // Finished employees may open their assessments and the portal.
      expect(
          _go(_user(assessment: 'complete'),
              AppRoutes.assessmentTakePath('a1')),
          isNull);
      expect(
          _go(_user(assessment: 'complete'), AppRoutes.onboardingAssessments),
          isNull);
      expect(_go(_user(assessment: 'complete'), AppRoutes.onboarding),
          AppRoutes.dashboard);
    });
  });

  group('release (syncAssessmentGate)', () {
    late FakeAssessmentServer server;

    Future<ProviderContainer> start(
        {String profile = 'pending', UserEntity? user}) async {
      final c = ProviderContainer(overrides: [
        dioProvider.overrideWithValue(
            Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
              ..httpClientAdapter = server),
        cookieJarProvider.overrideWithValue(CookieJar()),
        authStateProvider.overrideWith(() => _Auth(user ?? _user())),
      ]);
      addTearDown(c.dispose);
      server.profileStatus = profile;
      await c.read(authStateProvider.future);
      return c;
    }

    bool gated(ProviderContainer c) =>
        c.read(authStateProvider).valueOrNull!.user!.needsAssessments;

    setUp(() => server = FakeAssessmentServer([]));

    test('server still says pending: stays gated', () async {
      final c = await start();
      expect(await c.read(assessmentGateSyncProvider)(), isFalse);
      expect(gated(c), isTrue);
    });

    test('server says complete: released', () async {
      final c = await start(profile: 'complete');
      expect(await c.read(assessmentGateSyncProvider)(), isTrue);
      expect(gated(c), isFalse);
    });

    test(
        'all_complete with at least one assignment releases without asking again',
        () async {
      final c = await start();
      final list = MyAssessments.fromJson({
        'assignments': [
          {'id': 'a1', 'status': 'complete'}
        ],
        'all_complete': true
      });
      expect(await c.read(assessmentGateSyncProvider)(list: list), isTrue);
      expect(gated(c), isFalse);
      expect(server.calls, isEmpty);
    });

    test('an empty list is not proof on its own; the profile decides',
        () async {
      final c = await start();
      final empty = MyAssessments.fromJson(
          {'assignments': <Object>[], 'all_complete': true});
      expect(await c.read(assessmentGateSyncProvider)(list: empty), isFalse);
      expect(gated(c), isTrue);
      server.profileStatus =
          'complete'; // the backend marks "no assignments" complete
      expect(await c.read(assessmentGateSyncProvider)(list: empty), isTrue);
    });

    test('the check failing keeps the gate (no release on errors)', () async {
      server.failProfile = true;
      final c = await start();
      expect(await c.read(assessmentGateSyncProvider)(), isFalse);
      expect(gated(c), isTrue);
    });

    test('never puts the requirement back mid-session', () async {
      final c = await start(user: _user(assessment: 'complete'));
      expect(await c.read(assessmentGateSyncProvider)(), isTrue);
      expect(server.calls, isEmpty);
      expect(gated(c), isFalse);
    });

    test('onboarding approval hands over the server\'s assessment status',
        () async {
      final c =
          await start(user: _user(onboarding: 'submitted', assessment: null));
      final auth = c.read(authStateProvider.notifier);
      auth.updateAssessmentStatus('pending');
      expect(gated(c), isFalse); // onboarding not approved yet
      auth.updateOnboardingStatus('complete');
      expect(gated(c), isTrue);
      expect(
          _go(c.read(authStateProvider).valueOrNull!.user, AppRoutes.dashboard),
          AppRoutes.onboardingAssessments);
    });
  });

  group('assessment portal screen', () {
    late FakeAssessmentServer server;

    Future<ProviderContainer> pumpGate(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router =
          GoRouter(initialLocation: AppRoutes.onboardingAssessments, routes: [
        GoRoute(
            path: AppRoutes.onboardingAssessments,
            builder: (_, __) => const AssessmentGateScreen()),
        GoRoute(
            path: AppRoutes.dashboard,
            builder: (_, __) => const Text('DASHBOARD')),
        GoRoute(
            path: AppRoutes.assessmentTake,
            builder: (_, s) =>
                Text('TAKE ${s.pathParameters['assignmentId']}')),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(
              Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
                ..httpClientAdapter = server),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullSecureStorage()),
          authStateProvider.overrideWith(() => _Auth(_user())),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
          tester.element(find.byType(AssessmentGateScreen)));
    }

    testWidgets(
        'lists the assignments; an entry opens the assessment; no way past while pending',
        (tester) async {
      server = FakeAssessmentServer([
        FakeAssignment('a1', items: [quiz('q1', 1, 'a')])
      ]);
      await pumpGate(tester);
      expect(find.text('Complete your assessments'), findsOneWidget);
      expect(find.text('Workplace Safety'), findsOneWidget);
      expect(find.byKey(const Key('assessment-gate-continue')), findsNothing);
      expect(find.text('Log out'), findsOneWidget);
      await tester.tap(find.text('Workplace Safety'));
      await tester.pumpAndSettle();
      expect(find.text('TAKE a1'), findsOneWidget);
    });

    testWidgets('a failed load offers Retry and Log out (never a dead end)',
        (tester) async {
      server = FakeAssessmentServer([
        FakeAssignment('a1', items: [quiz('q1', 1, 'a')])
      ])
        ..failMy = true;
      await pumpGate(tester);
      expect(find.text('Could not load your assessments'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
      server.failMy = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Workplace Safety'), findsOneWidget);
    });

    testWidgets(
        'once the server confirms completion, Continue to Dashboard appears',
        (tester) async {
      final done = FakeAssignment('a1', items: [quiz('q1', 1, 'a')])
        ..status = 'complete'
        ..maxScore = 1
        ..score = 1;
      server = FakeAssessmentServer([done], profileStatus: 'complete');
      final c = await pumpGate(tester);
      expect(c.read(authStateProvider).valueOrNull!.user!.needsAssessments,
          isFalse);
      await tester.tap(find.byKey(const Key('assessment-gate-continue')));
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD'), findsOneWidget);
    });
  });
}
