import 'dart:async';
import 'dart:convert';

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
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/data/models/employee_notice_period_model.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/admin_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/employee_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/hr_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/manager_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/emp_notice_period_card.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';
import 'package:mobile_app/features/separation/presentation/notice_period.dart';

// Phase 11.5: the Employee dashboard's Notice Period card (web
// EmpNoticePeriodCard) from GET /dashboard/employee/notice-period/
// (production EmployeeNoticePeriodView). Synthetic data only.

const noticePath = '/dashboard/employee/notice-period/';

Map<String, dynamic> serving({int days = 12}) => {
      'request_id': '7d0c1e2a-0000-4000-8000-000000000001',
      'request_ref': 'SEP-14',
      'separation_type': 'Resignation',
      'notice_status': 'serving',
      'days_remaining': days,
      'confirmed_last_working_day': '2026-11-17',
      'approved_at': '2026-10-30T11:36:02.123456+05:30',
    };

class Backend implements HttpClientAdapter {
  Backend(this.notice);
  Object? notice; // the notice_period value
  int noticeStatus = 200;
  Completer<void>? hold;
  final paths = <String>[];

  int count(String p) => paths.where((x) => x == p).length;

  ResponseBody _r(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    paths.add(o.path);
    if (o.path == noticePath) {
      final gate = hold;
      if (gate != null) await gate.future;
      if (noticeStatus != 200) {
        return _r(noticeStatus, {'status': 'error', 'message': 'Failed.', 'data': {}});
      }
      return _r(200, {
        'status': 'success',
        'message': notice == null ? 'No active notice period.' : 'Notice period retrieved.',
        'data': {'notice_period': notice},
      });
    }
    return _r(200, {'status': 'success', 'message': 'ok', 'data': {}});
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

UserEntity user({bool manager = false, bool superuser = false, List<String> perms = const ['leave.view']}) =>
    UserEntity(
      id: 'u1',
      email: 'emp@example.test',
      fullName: 'Test Employee',
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: false,
      permissions: perms,
      canManageTeam: manager,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

late Backend backend;
late ProviderContainer container;

Future<void> pumpHome(WidgetTester tester,
    {Object? notice, UserEntity? as, void Function(Backend)? setup, bool settle = true}) async {
  tester.view.physicalSize = const Size(1080, 7000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  backend = Backend(notice);
  setup?.call(backend);
  final router = GoRouter(initialLocation: AppRoutes.dashboard, routes: [
    // As the app's router does, the dashboard is only built once the
    // signed-in user is known (it redirects to login otherwise).
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (_, __) => Consumer(
        builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
            ? const SizedBox()
            : const Scaffold(body: HomeScreen()),
      ),
    ),
    GoRoute(
      path: '/dashboard/separation/:id',
      builder: (_, s) => Scaffold(body: Text('Separation detail ${s.pathParameters['id']}')),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? user())),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = backend),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  if (settle) await settleSome(tester);
  container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
}

Future<void> settleSome(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// Dashboards start periodic timers; unmount before the test ends.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

final card = find.byKey(const Key('notice-period-card'));
Finder inCard(Finder f) => find.descendant(of: card, matching: f);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('response parsing', () {
    test('a served notice period is read field by field', () {
      final np = EmployeeNoticePeriod.fromResponseData({'notice_period': serving()})!;
      expect(np.requestId, '7d0c1e2a-0000-4000-8000-000000000001');
      expect(np.requestRef, 'SEP-14');
      expect(np.separationType, 'Resignation');
      expect(np.noticeStatus, 'serving');
      expect(np.isCompleted, isFalse);
      expect(np.daysRemaining, 12);
      expect(np.confirmedLastWorkingDay, '2026-11-17');
      expect(np.approvedAt, '2026-10-30T11:36:02.123456+05:30');
    });

    test('no notice period, or an unexpected shape, is null', () {
      expect(EmployeeNoticePeriod.fromResponseData({'notice_period': null}), isNull);
      expect(EmployeeNoticePeriod.fromResponseData(<String, dynamic>{}), isNull);
      expect(EmployeeNoticePeriod.fromResponseData(null), isNull);
      expect(EmployeeNoticePeriod.fromResponseData([1, 2]), isNull);
      expect(EmployeeNoticePeriod.fromResponseData({'notice_period': 'yes'}), isNull);
    });

    test('missing, null or oddly typed fields degrade safely', () {
      final np = EmployeeNoticePeriod.fromResponseData({
        'notice_period': {'notice_status': 'COMPLETED', 'days_remaining': '3', 'approved_at': null, 'request_id': null}
      })!;
      expect(np.isCompleted, isTrue);
      expect(np.daysRemaining, 3);
      expect(np.approvedAt, isNull);
      expect(np.confirmedLastWorkingDay, isNull);
      expect(np.requestId, '');
      expect(np.separationType, '');
      final odd = EmployeeNoticePeriod.fromJson({'days_remaining': 'soon', 'notice_status': 7});
      expect(odd.daysRemaining, isNull);
      expect(odd.isCompleted, isFalse);
    });
  });

  group('labels and dates (web lib/noticePeriod.ts)', () {
    test('remaining-days label', () {
      expect(noticeRemainingLabel(12, 'serving'), '12 days remaining');
      expect(noticeRemainingLabel(1, 'serving'), '1 day remaining');
      expect(noticeRemainingLabel(0, 'serving'), '0 days remaining');
      expect(noticeRemainingLabel(0, 'completed'), 'Notice completed');
      expect(noticeRemainingLabel(null, 'serving'), '—');
      expect(noticeRemainingLabel(null, null), '—');
    });

    test('dates as "D Mon YYYY", from the server value without shifting', () {
      expect(formatNoticeDate('2026-11-17'), '17 Nov 2026');
      expect(formatNoticeDate('2026-10-30T11:36:02.123456+05:30'), '30 Oct 2026');
      expect(formatNoticeDate('2026-01-01T00:30:00+05:30'), '1 Jan 2026');
      expect(formatNoticeDate(null), '—');
      expect(formatNoticeDate(''), '—');
    });
  });

  group('Employee dashboard card', () {
    testWidgets('serving notice: countdown, dates, type and status from the server', (tester) async {
      await pumpHome(tester, notice: serving());
      expect(find.byType(EmployeeDashboardView), findsOneWidget);
      expect(card, findsOneWidget);
      expect(inCard(find.text('Notice Period')), findsOneWidget);
      expect(inCard(find.text('Serving notice')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('notice-figure'))).data, '12');
      expect(tester.widget<Text>(find.byKey(const Key('notice-remaining'))).data, '12 days remaining');
      expect(inCard(find.text('30 Oct 2026')), findsOneWidget);
      expect(inCard(find.text('17 Nov 2026')), findsOneWidget);
      expect(inCard(find.text('Resignation')), findsOneWidget);
      // Right after the console, above Quick Access (web order).
      expect(tester.getTopLeft(card).dy, lessThan(tester.getTopLeft(find.byType(QuickAccessCard)).dy));
      expect(backend.count(noticePath), 1);
      await unmount(tester);
    });

    testWidgets('one day left uses the singular', (tester) async {
      await pumpHome(tester, notice: serving(days: 1));
      expect(tester.widget<Text>(find.byKey(const Key('notice-remaining'))).data, '1 day remaining');
      await unmount(tester);
    });

    testWidgets('View details opens that separation request', (tester) async {
      await pumpHome(tester, notice: serving());
      await tester.ensureVisible(find.byKey(const Key('notice-view-details')));
      await tester.tap(find.byKey(const Key('notice-view-details')));
      await settleSome(tester);
      expect(find.text('Separation detail 7d0c1e2a-0000-4000-8000-000000000001'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('completed notice: Done, Notice completed, Completed badge', (tester) async {
      await pumpHome(tester, notice: {...serving(days: 0), 'notice_status': 'completed'});
      expect(tester.widget<Text>(find.byKey(const Key('notice-figure'))).data, 'Done');
      expect(tester.widget<Text>(find.byKey(const Key('notice-remaining'))).data, 'Notice completed');
      expect(inCard(find.text('Completed')), findsOneWidget);
      expect(inCard(find.text('Serving notice')), findsNothing);
      await unmount(tester);
    });

    testWidgets('not serving notice (null): no card at all', (tester) async {
      await pumpHome(tester, notice: null);
      expect(find.byType(EmployeeDashboardView), findsOneWidget);
      expect(card, findsNothing);
      expect(find.text('Notice Period'), findsNothing);
      expect(backend.count(noticePath), 1);
      await unmount(tester);
    });

    testWidgets('missing fields show "—" and no View details', (tester) async {
      await pumpHome(tester, notice: {'notice_status': 'serving'});
      expect(card, findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('notice-figure'))).data, '—');
      expect(tester.widget<Text>(find.byKey(const Key('notice-remaining'))).data, '—');
      expect(inCard(find.text('—')), findsWidgets);
      expect(find.byKey(const Key('notice-view-details')), findsNothing);
      await unmount(tester);
    });

    testWidgets('while loading nothing is shown; then the card appears', (tester) async {
      await pumpHome(tester, notice: serving(), setup: (b) => b.hold = Completer<void>());
      expect(card, findsNothing);
      backend.hold!.complete();
      await settleSome(tester);
      expect(card, findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a server error shows the card with Retry; Retry loads it', (tester) async {
      await pumpHome(tester, notice: serving(), setup: (b) => b.noticeStatus = 500);
      expect(card, findsOneWidget);
      expect(inCard(find.text('Server error. Please try again later.')), findsOneWidget);
      expect(inCard(find.text('Retry')), findsOneWidget);
      backend.noticeStatus = 200;
      await tester.tap(inCard(find.text('Retry')));
      await settleSome(tester);
      expect(inCard(find.text('Serving notice')), findsOneWidget);
      expect(backend.count(noticePath), 2);
      await unmount(tester);
    });

    testWidgets('a refusal or not-found (403/404/401) hides the card', (tester) async {
      for (final status in [403, 404, 401]) {
        await pumpHome(tester, notice: serving(), setup: (b) => b.noticeStatus = status);
        expect(card, findsNothing, reason: '$status');
        await unmount(tester);
      }
    });

    testWidgets('ordinary rebuilds do not ask again; a dashboard refresh does', (tester) async {
      await pumpHome(tester, notice: serving());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -200));
      await settleSome(tester);
      expect(backend.count(noticePath), 1);
      // Coming back to the dashboard refreshes every section, this one too.
      container.read(dashboardRevisitProvider.notifier).state++;
      await settleSome(tester);
      expect(backend.count(noticePath), 2);
      await unmount(tester);
    });
  });

  group('other dashboards are unchanged', () {
    testWidgets('manager, HR and admin never show the card or call its endpoint', (tester) async {
      for (final (u, view) in [
        (user(manager: true), ManagerDashboardView),
        (user(perms: ['employees.view']), HrDashboardView),
        (user(superuser: true), AdminDashboardView),
      ]) {
        await pumpHome(tester, notice: serving(), as: u);
        expect(find.byType(view), findsOneWidget, reason: '$view');
        expect(find.byType(EmpNoticePeriodCard), findsNothing);
        expect(card, findsNothing);
        expect(backend.count(noticePath), 0, reason: '$view');
        await unmount(tester);
      }
    });
  });
}
