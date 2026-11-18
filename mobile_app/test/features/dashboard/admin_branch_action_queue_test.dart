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
import 'package:mobile_app/features/dashboard/presentation/screens/admin_dashboard_view.dart';

// Task 94 / HO-44: Branch Admin dashboard task list. Web AdminDashboard.tsx:83
// renders <HrActionQueue /> (GET /dashboard/hr/action-queue/, counts scoped
// to the admin's branch by the API) between Pending Approvals and Department
// Headcount when `session.can_manage_branch`; a plain System Admin gets none.
// Synthetic counts; a stand-in server; read-only.

ResponseBody _json(Object? b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class Server implements HttpClientAdapter {
  final paths = <String>[];
  int failQueue = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    paths.add(o.path);
    if (o.method != 'GET') fail('unexpected write ${o.method} ${o.path}');
    if (o.path == ApiConstants.dashboardHrActionQueue) {
      if (failQueue != 0) {
        final s = failQueue;
        failQueue = 0;
        return _json({'status': 'error', 'message': 'Server error.', 'data': null}, s);
      }
      return _json({
        'status': 'success',
        'message': 'ok',
        'data': {
          'total_pending': 10,
          'candidate_reviews': 1,
          'leave_approvals': 2,
          'attendance_corrections': 3,
          'expense_claims': 4,
          'onboarding_reviews': 0,
          'separation_requests': 0,
        },
      });
    }
    if (o.path == ApiConstants.separationRequests) {
      return _json({
        'status': 'success',
        'message': 'ok',
        'data': {'count': 0, 'results': <Object>[]},
      });
    }
    return _json({'status': 'success', 'message': 'ok', 'data': <Object>[]});
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

UserEntity admin({bool branchAdmin = false}) => UserEntity(
      id: 'a1',
      email: 'admin@example.test',
      fullName: 'Test Admin',
      role: branchAdmin ? 'branch_admin' : 'system_admin',
      roleDisplay: 'Admin',
      mustChangePassword: false,
      permissions: const ['settings.view', 'settings.edit'],
      isSuperuser: true,
      canManageBranch: branchAdmin,
      branch: branchAdmin ? 'North' : null,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

late Server server;
final queueCard = find.byKey(const Key('admin-branch-action-queue'));

Future<void> pump(WidgetTester tester, UserEntity u) async {
  tester.view.physicalSize = const Size(1080, 12000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(u)),
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
        GoRoute(path: '/dashboard/:rest(.*)', builder: (_, s) => Scaffold(body: Text('OPENED ${s.uri.path}'))),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

double _top(Finder f) => f.evaluate().isEmpty ? -1 : (f.evaluate().first.renderObject as RenderBox).localToGlobal(Offset.zero).dy;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => server = Server());

  testWidgets('System Admin (no can_manage_branch): no Action Queue and no request', (tester) async {
    await pump(tester, admin());
    expect(queueCard, findsNothing);
    expect(find.text('Action Queue'), findsNothing);
    expect(server.paths, isNot(contains(ApiConstants.dashboardHrActionQueue)));
  });

  testWidgets('Branch Admin: Action Queue between Pending Approvals and Department Headcount', (tester) async {
    await pump(tester, admin(branchAdmin: true));
    expect(queueCard, findsOneWidget);
    expect(server.paths.where((p) => p == ApiConstants.dashboardHrActionQueue).length, 1);
    final pending = _top(find.text('Pending Approvals'));
    final queue = _top(queueCard);
    final headcount = _top(find.text('Department Headcount'));
    expect(pending, greaterThan(0));
    expect(queue, greaterThan(pending));
    expect(headcount, greaterThan(queue));
    // Same card as the HR dashboard: the API's branch-scoped counts.
    expect(find.descendant(of: queueCard, matching: find.text('Action Queue')), findsOneWidget);
    expect(find.descendant(of: queueCard, matching: find.text('Leave Approvals')), findsOneWidget);
    expect(find.descendant(of: queueCard, matching: find.text('Total Pending')), findsOneWidget);
  });

  testWidgets('Branch Admin: a failed queue shows the error with Retry; Retry refetches', (tester) async {
    server.failQueue = 500;
    await pump(tester, admin(branchAdmin: true));
    expect(find.descendant(of: queueCard, matching: find.text('Retry')), findsOneWidget);
    await tester.tap(find.descendant(of: queueCard, matching: find.text('Retry')));
    await tester.pumpAndSettle();
    expect(server.paths.where((p) => p == ApiConstants.dashboardHrActionQueue).length, 2);
    expect(find.descendant(of: queueCard, matching: find.text('Total Pending')), findsOneWidget);
  });

  testWidgets('pull-to-refresh also refetches the queue', (tester) async {
    await pump(tester, admin(branchAdmin: true));
    final refresh = tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator).first);
    refresh.show();
    await tester.pumpAndSettle();
    expect(server.paths.where((p) => p == ApiConstants.dashboardHrActionQueue).length, 2);
  });
}
