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
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:mobile_app/features/leave/presentation/providers/leave_providers.dart';
import 'package:mobile_app/features/leave/presentation/widgets/leave_analytics_tab.dart';

// Task 83 (audit LV-18): Leave Analytics and the Home dashboard's leave
// figures ask for web's year — lib/fiscalYear.ts getLeaveYear() =
// `new Date().getFullYear()`, the calendar year, re-read on every render.
//   • Analytics: web LeaveAnalytics.tsx → GET /leave/stats/?year=<year>
//     (no year picker). The backend's own default for a missing year is the
//     financial-year start year, i.e. LAST year from January to March.
//   • Home (Employee dashboard): web EmpLeaveBalances.tsx →
//     GET /dashboard/employee/leave-balances/?year=<year>.
// The year comes from leaveDashboardClockProvider (overridden here). All
// users, data and servers are synthetic.

const statsPath = '/leave/stats/';
const homeBalancesPath = '/dashboard/employee/leave-balances/';

ResponseBody _r(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

ResponseBody _ok(Object data) => _r(200, {'status': 'success', 'message': 'ok', 'data': data});

class Server implements HttpClientAdapter {
  final gets = <(String, Map<String, dynamic>)>[];
  int statsStatus = 200;
  int homeStatus = 200;
  Completer<void>? hold; // when set, /leave/stats/ waits for it

  List<Map<String, dynamic>> queries(String path) => [
        for (final g in gets)
          if (g.$1 == path) g.$2
      ];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    gets.add((o.path, Map.of(o.queryParameters)));
    final year = int.tryParse('${o.queryParameters['year']}') ?? 1999;
    if (o.path == statsPath) {
      if (hold != null) await hold!.future;
      if (statsStatus != 200) {
        return _r(statsStatus, {'status': 'error', 'message': 'Not allowed.', 'data': {}});
      }
      return _ok({
        'total': 7, 'pending': 2, 'approved': 4, 'rejected': 1, 'cancelled': 0, 'year': year, //
        'balances': [
          {'leave_type': 'casual', 'leave_type_display': 'Casual Leave', 'total_days': 12, 'used_days': 3, 'available': 9},
        ],
      });
    }
    if (o.path == homeBalancesPath) {
      if (homeStatus != 200) return _r(homeStatus, {'status': 'error', 'message': 'Server error.', 'data': {}});
      return _ok({
        'year': year,
        'lop_days': 0.0,
        'balances': [
          {
            'leave_type': 'casual', 'leave_type_label': 'Casual Leave', 'total_days': 12.0, 'used_days': 3.0, //
            'remaining': 9.0, 'carried_forward': 0.0, 'credit_schedule': 'annual',
          },
        ],
      });
    }
    if (o.path == '/leave/balance/') return _ok(<Object>[]);
    return _ok({});
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

UserEntity user(String role, List<String> perms, {bool team = false, List<String>? modules}) => UserEntity(
      id: 'u1',
      email: 'u@example.test',
      fullName: 'Test User',
      role: role,
      roleDisplay: role,
      mustChangePassword: false,
      permissions: perms,
      canManageTeam: team,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final employee = user('employee', ['leave.view', 'leave.create']);
final approver = user('hr_admin', ['leave.view', 'leave.create', 'leave.approve']);

late Server server;
DateTime now = DateTime(2026, 11, 17, 10);

List<Override> overrides(UserEntity u) => [
      leaveDashboardClockProvider.overrideWithValue(() => now),
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

// ── Analytics harness ─────────────────────────────────────────────────────────

/// Toggles the Analytics tab off (another screen) and back on.
final showAnalytics = ValueNotifier<bool>(true);

Future<void> pumpAnalytics(WidgetTester tester, {UserEntity? u, DateTime? at, void Function(Server)? setup}) async {
  now = at ?? DateTime(2026, 11, 17, 10);
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  showAnalytics.value = true;
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(u ?? employee),
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
            ? const SizedBox()
            : ValueListenableBuilder<bool>(
                valueListenable: showAnalytics,
                builder: (_, show, __) =>
                    Scaffold(body: show ? const LeaveAnalyticsTab() : const Text('Somewhere else')),
              ),
      ),
    ),
  ));
  await settle(tester);
}

Future<void> pullToRefresh(WidgetTester tester) async {
  await tester.widget<RefreshIndicator>(find.byType(RefreshIndicator).first).onRefresh();
  await settle(tester);
}

List<Object?> statsYears() => [for (final q in server.queries(statsPath)) q['year']];

// ── Home harness ──────────────────────────────────────────────────────────────

Future<void> pumpHome(WidgetTester tester, {DateTime? at, UserEntity? u, void Function(Server)? setup}) async {
  now = at ?? DateTime(2026, 11, 17, 10);
  tester.view.physicalSize = const Size(1080, 7000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  final router = GoRouter(initialLocation: AppRoutes.dashboard, routes: [
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (_, __) => Consumer(
        builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
            ? const SizedBox()
            : const Scaffold(body: HomeScreen()),
      ),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(overrides: overrides(u ?? employee), child: MaterialApp.router(routerConfig: router)));
  await settle(tester);
}

// The dashboard starts periodic timers; unmount before the test ends.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

List<Object?> homeYears() => [for (final q in server.queries(homeBalancesPath)) q['year']];

ProviderContainer containerOf(WidgetTester tester, Type t) => ProviderScope.containerOf(tester.element(find.byType(t)));

/// Calendar dates and the year web's getLeaveYear() gives for each — the
/// backend's FY default (April start) would be last year for Jan–Mar.
final calendar = <(String, DateTime, int)>[
  ('1 January', DateTime(2027, 1, 1, 0, 0, 1), 2027),
  ('mid-January', DateTime(2027, 1, 15, 9), 2027),
  ('February', DateTime(2027, 2, 14, 9), 2027),
  ('29 February (leap year)', DateTime(2028, 2, 29, 12), 2028),
  ('31 March', DateTime(2027, 3, 31, 23, 59), 2027),
  ('1 April', DateTime(2027, 4, 1, 8), 2027),
  ('31 December', DateTime(2026, 12, 31, 23, 59, 59), 2026),
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Leave Analytics', () {
    for (final (label, at, year) in calendar) {
      testWidgets('$label: one GET /leave/stats/?year=$year (calendar year), figures for that year', (tester) async {
        await pumpAnalytics(tester, at: at);
        expect(server.queries(statsPath), [
          {'year': year}
        ]);
        expect(find.text('This year ($year)'), findsNWidgets(4));
        expect(find.text('7'), findsWidgets); // Total Requests from the response
      });
    }

    testWidgets('approver: same year, scope still left to the backend (no scope param, as before)', (tester) async {
      await pumpAnalytics(tester, u: approver, at: DateTime(2027, 2, 1));
      expect(server.queries(statsPath), [
        {'year': 2027}
      ]);
    });

    testWidgets('no year picker on web or mobile: the year follows the clock only', (tester) async {
      await pumpAnalytics(tester, at: DateTime(2027, 3, 3));
      expect(find.byType(DropdownButton<int>), findsNothing);
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      expect(find.textContaining('2026'), findsNothing);
    });

    testWidgets('refresh keeps the year and fetches exactly once more', (tester) async {
      await pumpAnalytics(tester, at: DateTime(2027, 1, 20));
      await pullToRefresh(tester);
      expect(statsYears(), [2027, 2027]);
      await pullToRefresh(tester);
      expect(statsYears(), [2027, 2027, 2027]);
    });

    testWidgets('31 December → 1 January: refresh asks for the new year, once', (tester) async {
      await pumpAnalytics(tester, at: DateTime(2026, 12, 31, 23, 59, 59));
      expect(statsYears(), [2026]);
      now = DateTime(2027, 1, 1, 0, 0, 1);
      await pullToRefresh(tester);
      expect(statsYears(), [2026, 2027]);
      expect(find.text('This year (2027)'), findsNWidgets(4));
    });

    testWidgets('navigating away and back refetches once with the current year', (tester) async {
      await pumpAnalytics(tester, at: DateTime(2027, 3, 10));
      showAnalytics.value = false;
      await settle(tester);
      expect(find.text('Somewhere else'), findsOneWidget);
      showAnalytics.value = true;
      await settle(tester);
      expect(statsYears(), [2027, 2027]);
      // Away over New Year → back asks for the new year.
      showAnalytics.value = false;
      await settle(tester);
      now = DateTime(2028, 1, 2);
      showAnalytics.value = true;
      await settle(tester);
      expect(statsYears(), [2027, 2027, 2028]);
    });

    testWidgets('loading state shows placeholders, then the year\'s figures', (tester) async {
      await pumpAnalytics(tester, at: DateTime(2027, 2, 2), setup: (s) => s.hold = Completer());
      expect(find.text('…'), findsNWidgets(5)); // Task 109: five cards now (Loss of Pay joined the four)
      expect(statsYears(), [2027]);
      server.hold!.complete();
      await settle(tester);
      expect(find.text('…'), findsNothing);
      expect(find.text('This year (2027)'), findsNWidgets(4));
      expect(statsYears(), [2027]);
    });

    testWidgets('failure shows the error; Retry refetches once with the same year', (tester) async {
      await pumpAnalytics(tester, at: DateTime(2027, 1, 5), setup: (s) => s.statsStatus = 500);
      expect(find.text('Failed to load leave analytics.'), findsOneWidget);
      server.statsStatus = 200;
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('Failed to load leave analytics.'), findsNothing);
      expect(statsYears(), [2027, 2027]);
    });

    testWidgets('unauthorised (403): error state, still the calendar year, no retries on its own', (tester) async {
      await pumpAnalytics(tester, at: DateTime(2027, 3, 1), setup: (s) => s.statsStatus = 403);
      // Task 109: a refusal reads "Access denied" (with the server's message), not a generic failure.
      expect(find.text('Access denied'), findsOneWidget);
      expect(statsYears(), [2027]);
    });

    testWidgets('leave module disabled: the Leave screen (and its Analytics tab) is not reachable', (tester) async {
      final off = user('employee', ['leave.view', 'leave.create'], modules: const ['attendance']);
      expect(canAccessPath(off, AppRoutes.leave), isFalse);
      expect(canAccessPath(employee, AppRoutes.leave), isTrue);
    });

    testWidgets('other invalidations (apply / cancellation) refetch once, keeping the year', (tester) async {
      await pumpAnalytics(tester, at: DateTime(2027, 2, 10));
      containerOf(tester, LeaveAnalyticsTab).invalidate(leaveStatsProvider);
      await settle(tester);
      expect(statsYears(), [2027, 2027]);
    });
  });

  group('Home dashboard (Employee) leave balances', () {
    for (final (label, at, year) in calendar) {
      testWidgets('$label: one GET leave-balances?year=$year, card titled with that year', (tester) async {
        await pumpHome(tester, at: at);
        expect(server.queries(homeBalancesPath), [
          {'year': year}
        ]);
        expect(find.text('Leave Balances — $year'), findsOneWidget);
        expect(find.text('Casual Leave'), findsWidgets); // balances unchanged
        expect(server.queries(statsPath), isEmpty);
        await unmount(tester);
      });
    }

    testWidgets('pull-to-refresh keeps the year and refetches once; over New Year it moves on', (tester) async {
      await pumpHome(tester, at: DateTime(2026, 12, 31, 23, 59));
      await tester.widget<RefreshIndicator>(find.byType(RefreshIndicator).first).onRefresh();
      await settle(tester);
      expect(homeYears(), [2026, 2026]);
      now = DateTime(2027, 1, 1, 0, 1);
      await tester.widget<RefreshIndicator>(find.byType(RefreshIndicator).first).onRefresh();
      await settle(tester);
      expect(homeYears(), [2026, 2026, 2027]);
      expect(find.text('Leave Balances — 2027'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('returning to the dashboard refetches once with the current year', (tester) async {
      await pumpHome(tester, at: DateTime(2027, 3, 31));
      final c = containerOf(tester, HomeScreen);
      c.read(dashboardRevisitProvider.notifier).state++;
      await settle(tester);
      expect(homeYears(), [2027, 2027]);
      await unmount(tester);
    });

    testWidgets('failure: section error, Retry refetches once with the year', (tester) async {
      await pumpHome(tester, at: DateTime(2027, 1, 10), setup: (s) => s.homeStatus = 500);
      expect(find.text('Retry'), findsWidgets);
      server.homeStatus = 200;
      final before = homeYears().length;
      // The leave card's own Retry (other sections answer normally).
      final retry = find.descendant(
          of: find
              .ancestor(
                  of: find.text('Leave Balances — 2027'),
                  matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'SectionCard'))
              .first,
          matching: find.text('Retry'));
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await settle(tester);
      expect(homeYears().length, before + 1);
      expect(homeYears().toSet(), {2027});
      await unmount(tester);
    });

    testWidgets('leave module disabled: leave balances are not fetched', (tester) async {
      await pumpHome(tester, u: user('employee', ['leave.view'], modules: const ['announcements']));
      expect(server.queries(homeBalancesPath), isEmpty);
      expect(server.queries(statsPath), isEmpty);
      await unmount(tester);
    });
  });

  group('Apply Leave year handling (unchanged, same source)', () {
    for (final (label, at, year) in calendar) {
      test('$label: own balances ask for $year, the same year as Analytics', () async {
        now = at;
        server = Server();
        final c = ProviderContainer(overrides: overrides(employee));
        addTearDown(c.dispose);
        final sub = c.listen(myLeaveBalancesProvider, (_, __) {});
        final sub2 = c.listen(leaveStatsProvider, (_, __) {});
        await c.read(myLeaveBalancesProvider.future);
        await c.read(leaveStatsProvider.future);
        expect(server.queries('/leave/balance/'), [
          {'year': year}
        ]);
        expect(statsYears(), [year]);
        sub.close();
        sub2.close();
      });
    }
  });
}
