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
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/assessments/data/models/my_assessment_model.dart';
import 'package:mobile_app/features/assessments/presentation/screens/my_assessments_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/navigation/nav_config.dart';

import '../../core/router/access_control_test.dart' as roles;

// Phase 2: the employee's own assessment list — GET /api/assessments/my/
// (apps/assessments/views/portal.py MyAssessmentView: any signed-in user,
// {"assignments": [...], "all_complete": bool}, not paginated) — and its
// self-service route, while assessment management keeps assessments.view.

Map<String, dynamic> _row(String id,
        {String status = 'pending',
        String? title,
        int score = 0,
        int maxScore = 0,
        int pass = 70,
        int total = 4,
        int done = 0,
        int attempts = 1,
        String? deadline,
        String? completedAt}) =>
    {
      'id': id,
      'assessment_title': title ?? 'Assessment $id',
      'pass_percentage': pass,
      'status': status,
      'score': score,
      'max_score': maxScore,
      'total_items': total,
      'completed_items': done,
      'attempt_count': attempts,
      'effective_max_attempts': 3,
      'attempts_remaining': 2,
      'started_at': null,
      'time_limit_mins': 30,
      'time_remaining_secs': null,
      'deadline': deadline,
      'completed_at': completedAt,
      'items': <Object>[],
      'responses': <Object>[],
    };

ResponseBody _json(int status, Object body) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class _Backend implements HttpClientAdapter {
  _Backend(this.replies);

  /// Consumed in order; the last one repeats.
  final List<FutureOr<ResponseBody> Function()> replies;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    requests.add(o);
    if (o.path != ApiConstants.assessmentsMy) {
      return _json(200, {'status': 'success', 'data': {}});
    }
    final next = replies.length > 1 ? replies.removeAt(0) : replies.first;
    return next();
  }

  int get myCalls =>
      requests.where((r) => r.path == ApiConstants.assessmentsMy).length;

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok(List<Map<String, dynamic>> rows) => _json(200, {
      'status': 'success',
      'message':
          rows.isEmpty ? 'No assessments assigned.' : 'Assessments retrieved.',
      'data': {
        'assignments': rows,
        'all_complete': rows.every((r) => r['status'] == 'complete')
      },
    });

class _NullSecureStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

String? _go(UserEntity? user, String path) => resolveAuthRedirect(
    authState: user == null ? const AuthState.initial() : AuthState(user: user),
    path: path);

UserEntity _flagged(UserEntity u) => UserEntity(
    id: u.id,
    email: u.email,
    fullName: u.fullName,
    role: u.role,
    roleDisplay: u.roleDisplay,
    mustChangePassword: true,
    permissions: u.permissions,
    onboardingStatus: 'complete');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('route access', () {
    test(
        'any signed-in employee opens My Assessments, with or without assessments.view',
        () {
      expect(roles.employee.permissions, isNot(contains('assessments.view')));
      expect(_go(roles.employee, AppRoutes.myAssessments), isNull);
      expect(_go(roles.noPermissions, AppRoutes.myAssessments), isNull);
      expect(_go(roles.manager, AppRoutes.myAssessments), isNull);
      expect(_go(roles.branchAdmin, AppRoutes.myAssessments), isNull);
      expect(_go(roles.systemAdmin, AppRoutes.myAssessments), isNull);
      expect(requiredPermissionsFor(AppRoutes.myAssessments), isNull);
    });

    test(
        'signed-out users go to login; a forced password change still comes first',
        () {
      expect(_go(null, AppRoutes.myAssessments), AppRoutes.login);
      expect(_go(_flagged(roles.employee), AppRoutes.myAssessments),
          AppRoutes.changePassword);
    });

    test('assessment management stays behind assessments.view', () {
      expect(_go(roles.employee, AppRoutes.assessments), AppRoutes.dashboard);
      expect(
          _go(roles.noPermissions, AppRoutes.assessments), AppRoutes.dashboard);
      expect(_go(roles.branchAdmin, AppRoutes.assessments), isNull);
      expect(_go(roles.systemAdmin, AppRoutes.assessments), isNull);
      expect(
          requiredPermissionsFor(AppRoutes.assessments), ['assessments.view']);
      // Assessment configuration (settings) is unchanged too.
      expect(_go(roles.employee, AppRoutes.settingsAssessmentConfig),
          AppRoutes.dashboard);
    });

    test('unrelated route permissions are unchanged', () {
      expect(_go(roles.employee, AppRoutes.employees), AppRoutes.dashboard);
      expect(_go(roles.employee, AppRoutes.approvals), AppRoutes.dashboard);
      expect(_go(roles.employee, AppRoutes.leave), isNull);
      expect(_go(roles.manager, AppRoutes.approvals), isNull);
      expect(requiredPermissionsFor(AppRoutes.myAssessments),
          isNot(requiredPermissionsFor(AppRoutes.assessments)));
    });

    test(
        'menu: everyone sees My Assessments; only assessments.view holders see management',
        () {
      Set<String> ids(UserEntity? u) =>
          buildNav(u).whereType<NavItem>().map((e) => e.id).toSet();
      for (final u in [
        roles.employee,
        roles.manager,
        roles.noPermissions,
        null
      ]) {
        expect(ids(u), contains('my-assessments'));
        expect(ids(u), isNot(contains('assessments')));
      }
      expect(ids(roles.branchAdmin),
          containsAll(['my-assessments', 'assessments']));
      final item = kAllNav
          .whereType<NavItem>()
          .singleWhere((e) => e.id == 'my-assessments');
      expect(item.path, AppRoutes.myAssessments);
      expect(item.permission, isNull);
    });

    test('the route is registered in the app router', () {
      final c = ProviderContainer(overrides: [
        secureStorageProvider.overrideWithValue(_NullSecureStorage())
      ]);
      addTearDown(c.dispose);
      List<String> paths(List<RouteBase> rs) => [
            for (final r in rs) ...[
              if (r is GoRoute) r.path,
              ...paths(r.routes)
            ]
          ];
      expect(paths(c.read(appRouterProvider).configuration.routes),
          contains(AppRoutes.myAssessments));
    });
  });

  group('model (PortalAssignmentSerializer)', () {
    test('status mapping; unknown or missing values count as pending', () {
      expect(MyAssessmentStatus.fromApi('pending'), MyAssessmentStatus.pending);
      expect(MyAssessmentStatus.fromApi('in_progress'),
          MyAssessmentStatus.inProgress);
      expect(
          MyAssessmentStatus.fromApi('complete'), MyAssessmentStatus.complete);
      expect(
          MyAssessmentStatus.fromApi('archived'), MyAssessmentStatus.pending);
      expect(MyAssessmentStatus.fromApi(null), MyAssessmentStatus.pending);
    });

    test('progress, score and pass/fail follow web (rounded percentages)', () {
      final a = MyAssessmentAssignment.fromJson(_row('1', total: 3, done: 2));
      expect(a.progressPercent, 67);
      final passed = MyAssessmentAssignment.fromJson(
          _row('2', status: 'complete', score: 7, maxScore: 10, pass: 70));
      expect((passed.scorePercent, passed.passed), (70, true));
      final failed = MyAssessmentAssignment.fromJson(
          _row('3', status: 'complete', score: 6, maxScore: 10, pass: 70));
      expect((failed.scorePercent, failed.passed), (60, false));
      final noItems =
          MyAssessmentAssignment.fromJson(_row('4', total: 0, done: 0));
      expect(noItems.progressPercent, 0);
    });

    test('a row with only an id still parses', () {
      final a = MyAssessmentAssignment.fromJson({'id': 'x'});
      expect(a.title, 'Assessment');
      expect(a.status, MyAssessmentStatus.pending);
      expect(a.deadline, isNull);
      expect(a.attemptsRemaining, isNull);
      expect(MyAssessments.fromJson(null).assignments, isEmpty);
      expect(
          MyAssessments.fromJson({'assignments': 'oops'}).assignments, isEmpty);
    });
  });

  group('My Assessments screen', () {
    late _Backend backend;

    Future<void> pumpScreen(WidgetTester tester,
        List<FutureOr<ResponseBody> Function()> replies) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      backend = _Backend(replies);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(
              Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
                ..httpClientAdapter = backend),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullSecureStorage()),
        ],
        child: const MaterialApp(home: MyAssessmentsScreen()),
      ));
    }

    testWidgets(
        'loading, then pending and completed assignments with their status',
        (tester) async {
      final gate = Completer<ResponseBody>();
      await pumpScreen(tester, [() => gate.future]);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete(_ok([
        _row('a1',
            title: 'Safety Basics',
            status: 'in_progress',
            total: 4,
            done: 1,
            deadline: '2026-11-20T18:29:59Z'),
        _row('a2', title: 'Code of Conduct', total: 2, done: 0, attempts: 0),
        _row('a3',
            title: 'Data Privacy',
            status: 'complete',
            score: 8,
            maxScore: 10,
            completedAt: '2026-10-02T10:00:00Z'),
        _row('a4',
            title: 'Fire Drill',
            status: 'complete',
            score: 4,
            maxScore: 10,
            attempts: 2),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('PENDING (2)'), findsOneWidget);
      expect(find.text('COMPLETED (2)'), findsOneWidget);
      expect(find.text('Safety Basics'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets); // chip + stat label
      expect(find.text('1/4 items done'), findsOneWidget);
      expect(find.text('25% complete'), findsOneWidget);
      expect(find.textContaining('Due: '), findsOneWidget);
      expect(find.text('Attempt 1'), findsOneWidget);
      expect(find.text('Passed'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Score: 80% (pass: 70%)'), findsOneWidget);
      expect(find.text('2 attempts'), findsOneWidget);
      // Totals: 4 / 2 pending / 2 completed.
      expect(find.text('4'), findsOneWidget);
      expect(backend.myCalls, 1);
      expect(backend.requests.single.method, 'GET');
      expect(backend.requests.single.queryParameters,
          isEmpty); // unpaginated: no page params
    });

    testWidgets('no assignments: the empty state', (tester) async {
      await pumpScreen(tester, [() => _ok([])]);
      await tester.pumpAndSettle();
      expect(find.text('No assessments assigned'), findsOneWidget);
      expect(find.text('PENDING (0)'), findsNothing);
    });

    testWidgets('an error shows a message and Retry reloads', (tester) async {
      await pumpScreen(tester, [
        () =>
            _json(500, {'status': 'error', 'message': 'Something went wrong.'}),
        () => _ok([_row('b1', title: 'Onboarding Quiz')]),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Could not load your assessments'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Onboarding Quiz'), findsOneWidget);
      expect(backend.myCalls, 2);
    });

    testWidgets('missing optional fields do not break the list',
        (tester) async {
      await pumpScreen(tester, [
        () => _json(200, {
              'status': 'success',
              'data': {
                'assignments': [
                  {'id': 'm1'},
                  {'id': 'm2', 'status': 'complete'}
                ]
              },
            }),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Assessment'), findsNWidgets(2));
      expect(find.text('0/0 items done'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'one request per visit; rebuilds do not refetch, pull-to-refresh fetches once',
        (tester) async {
      await pumpScreen(tester, [
        () => _ok([_row('c1')])
      ]);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(backend.myCalls, 1);
      // Pull-to-refresh: run the indicator's own refresh (the screen's
      // onRefresh handler), as a completed pull gesture does.
      final refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await refresh;
      expect(backend.myCalls, 2);
    });

    testWidgets(
        'tapping an assignment opens that assessment (Phase 3: taking it)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      backend = _Backend([
        () => _ok([_row('d1', title: 'Compliance 101', total: 5, done: 2)])
      ]);
      final router = GoRouter(initialLocation: '/list', routes: [
        GoRoute(path: '/list', builder: (_, __) => const MyAssessmentsScreen()),
        GoRoute(
            path: AppRoutes.assessmentTake,
            builder: (_, s) =>
                Text('TAKE ${s.pathParameters['assignmentId']}')),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(
              Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
                ..httpClientAdapter = backend),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullSecureStorage()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compliance 101'));
      await tester.pumpAndSettle();
      expect(find.text('TAKE d1'), findsOneWidget);
      // Opening it sends nothing to the server.
      expect(backend.requests.where((r) => r.method != 'GET'), isEmpty);
    });
  });
}
