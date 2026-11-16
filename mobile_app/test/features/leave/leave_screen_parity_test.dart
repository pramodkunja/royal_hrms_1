import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/leave/presentation/providers/leave_providers.dart' show leaveDashboardClockProvider;
import 'package:mobile_app/features/leave/presentation/screens/leave_screen.dart';

// Tasks 71d / 71d.1 (audit finding M3): the Leave screen and its Dashboard
// as web leave/_client.tsx and LeaveDashboard.tsx — Dashboard, Apply Leave,
// Team Calendar, Analytics for everyone; the Dashboard shows the user's own
// balances and requests only. No Approvals tab, no branch filter and no
// "Pending Approvals" queue with Approve / Reject (approvals live in the
// Approvals screen); nothing is decided by role name.
// Task 72: web's four summary cards — Casual, Sick, Earned, Loss of Pay
// (LOP) — and no mobile-only "My Pending" card. LOP, in days: an `lwp`
// balance row gives Available (total − used) / Used / Total; without one,
// Available "—", Used = own-scope stats lop_days
// (GET /leave/stats/?year=<calendar year>&scope=own; 0 when absent) and
// Total "No cap".
// Task 72.1: the Casual / Sick / Earned cards as web — Available = total −
// used (may be negative), "Used: x", "Total: y", bar at round(used / total
// × 100)% (0 for a zero total), zeros for a missing row — and balances and
// stats both for web's year: getLeaveYear() = the calendar year
// (GET /leave/balance/?year=…). Synthetic users and leave; a stand-in
// server records requests.

ResponseBody _json(Object data) => ResponseBody.fromString(
      jsonEncode({'status': 'success', 'message': 'ok', 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );

Map<String, dynamic> request(String id, String status, String from, String to, {bool canCancel = false}) => {
      'id': id,
      'employee_name': 'Test User',
      'leave_type': 'casual',
      'leave_type_display': 'Casual Leave',
      'start_date': from,
      'end_date': to,
      'days': 2,
      'status': status,
      'reason': 'Family function $id',
      'created_at': '2026-11-13T09:00:00Z',
      'can_approve': false,
      'can_request_cancellation': canCancel,
    };

/// What /leave/stats/ answers with: a lop_days value, an explicit null, the
/// key left out, or a server error.
enum Lop { value, nullValue, missing, error }

class Server implements HttpClientAdapter {
  final gets = <(String, Map<String, dynamic>)>[];
  final writes = <(String, String)>[];
  Map<String, dynamic>? lwp; // an lwp balance row, when set
  /// Balance rows by type; a null entry leaves that type out.
  Map<String, Map<String, dynamic>?> rows = {
    'casual': {'leave_type': 'casual', 'leave_type_display': 'Casual Leave', 'used_days': 2, 'total_days': 12},
    'sick': {'leave_type': 'sick', 'leave_type_display': 'Sick Leave', 'used_days': 0, 'total_days': 7},
    'earned': {'leave_type': 'earned', 'leave_type_display': 'Earned Leave', 'used_days': 4, 'total_days': 15},
  };
  bool balanceFails = false;

  Iterable<Map<String, dynamic>> get balanceQueries => gets.where((g) => g.$1 == '/leave/balance/').map((g) => g.$2);
  Lop lop = Lop.value;
  Object lopDays = 2.5;

  Iterable<Map<String, dynamic>> get statsQueries => gets.where((g) => g.$1 == '/leave/stats/').map((g) => g.$2);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') writes.add((o.method, o.path));
    gets.add((o.path, Map.of(o.queryParameters)));
    if (o.path == '/leave/requests/L2/cancellation/' && o.method == 'POST') {
      return _json(request('L2', 'approved', '2026-12-01', '2026-12-02'));
    }
    if (o.path == '/leave/balance/') {
      if (balanceFails) {
        return ResponseBody.fromString(jsonEncode({'status': 'error', 'message': 'Balances unavailable.', 'data': {}}), 500,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            });
      }
      return _json([
        for (final r in rows.values)
          if (r != null) r,
        if (lwp != null) lwp!,
      ]);
    }
    if (o.path == '/leave/stats/') {
      if (lop == Lop.error) {
        return ResponseBody.fromString(jsonEncode({'status': 'error', 'message': 'boom', 'data': {}}), 500,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            });
      }
      return _json({
        'total': 2, 'pending': 1, 'approved': 1, 'rejected': 0, 'cancelled': 0, 'year': 2026, 'balances': <Object>[],
        'lop_requests': 1,
        if (lop == Lop.value) 'lop_days': lopDays,
        if (lop == Lop.nullValue) 'lop_days': null,
      });
    }
    if (o.path == '/leave/requests/L2/') {
      return _json(request('L2', 'approved', '2026-12-01', '2026-12-02', canCancel: true));
    }
    if (o.path == '/leave/requests/') {
      if (o.queryParameters['scope'] == 'team') return _json({'count': 0, 'results': <Object>[]});
      return _json({
        'count': 2,
        'page': 1,
        'total_pages': 1,
        'results': [
          request('L1', 'pending', '2026-11-20', '2026-11-21'),
          request('L2', 'approved', '2026-12-01', '2026-12-02', canCancel: true),
        ],
      });
    }
    return _json({'count': 0, 'page': 1, 'page_size': 20, 'total_pages': 1, 'results': <Object>[]});
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

UserEntity user(String role, List<String> perms, {bool superuser = false, bool team = false, List<String>? modules}) =>
    UserEntity(
      id: 'u1',
      email: 'u@example.test',
      fullName: 'Test User',
      role: role,
      roleDisplay: role,
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      canManageTeam: team,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final roles = <String, UserEntity>{
  'employee': user('employee', ['leave.view', 'leave.create']),
  'hr_admin': user('hr_admin', ['leave.view', 'leave.create', 'leave.approve', 'employees.view']),
  'manager': user('manager', ['leave.view', 'leave.create', 'leave.approve'], team: true),
  'system_admin': user('system_admin', ['leave.view', 'settings.view', 'settings.edit'], superuser: true),
};

late Server server;

/// What the dashboard's clock reads (web: new Date()).
DateTime now = DateTime(2026, 11, 16, 10);

Future<void> pump(WidgetTester tester, UserEntity u,
    {Size size = const Size(1080, 2400), double textScale = 1, void Function(Server)? setup, DateTime? at}) async {
  now = at ?? DateTime(2026, 11, 16, 10);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      leaveDashboardClockProvider.overrideWithValue(() => now),
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Consumer(
        builder: (context, ref, _) =>
            ref.watch(authStateProvider).valueOrNull?.user == null ? const SizedBox() : const LeaveScreen(),
      ),
    ),
  ));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// The summary cards' types, left to right.
List<String> cardOrder(WidgetTester tester) {
  final cards = [
    for (final k in ['casual', 'sick', 'earned', 'lop'])
      (k, tester.getTopLeft(find.byKey(Key('leave-balance-card-$k'))).dx),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final c in cards) c.$1];
}

/// A balance card's (Available, Used, Total) texts.
(String, String, String) card(WidgetTester tester, String code) {
  String t(String part) => tester
      .widget<Text>(find.descendant(of: find.byKey(Key('leave-balance-card-$code')), matching: find.byKey(ValueKey(part))))
      .data!;
  return (t('available'), t('used'), t('total'));
}

String lopText(WidgetTester tester, String part) => tester.widget<Text>(find.byKey(Key('leave-lop-$part'))).data!;

/// The status label on own request [id]'s card.
String statusOf(WidgetTester tester, String id) =>
    tester.widget<Text>(find.byKey(Key('leave-request-status-$id'))).data!.toLowerCase();

List<String> tabLabels(WidgetTester tester) => [
      for (final t in tester.widgetList<Tab>(find.descendant(of: find.byType(TabBar), matching: find.byType(Tab))))
        t.text ?? ''
    ];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final MapEntry(key: role, value: u) in roles.entries) {
    testWidgets('$role: web\'s four tabs and own-leave Dashboard; no approval controls, branch filter or team queue',
        (tester) async {
      await pump(tester, u);
      expect(tabLabels(tester), ['Dashboard', 'Apply Leave', 'Team Calendar', 'Analytics']);
      expect(find.widgetWithText(Tab, 'Approvals'), findsNothing);
      expect(find.text('All Branches'), findsNothing);
      expect(find.text('Apply for leave and track your own requests'), findsOneWidget);
      // Dashboard: web's four cards, in web's order; no My Pending card.
      expect(cardOrder(tester), ['casual', 'sick', 'earned', 'lop']);
      expect(find.text('My Pending'), findsNothing);
      expect(find.text('Awaiting approval'), findsNothing);
      expect(find.text('Pending Approvals'), findsNothing);
      for (final l in ['Casual Leave', 'Sick Leave', 'Earned Leave', 'Loss of Pay (LOP)']) {
        expect(find.descendant(of: find.byKey(const Key('leave-balance-cards')), matching: find.text(l)), findsOneWidget,
            reason: l);
      }
      // Casual 12 / used 2, Sick 7 / 0, Earned 15 / 4 — web's three lines.
      expect(card(tester, 'casual'), ('10', 'Used: 2', 'Total: 12'));
      expect(card(tester, 'sick'), ('7', 'Used: 0', 'Total: 7'));
      expect(card(tester, 'earned'), ('11', 'Used: 4', 'Total: 15'));
      expect(find.text('Available'), findsNWidgets(4));
      expect(find.textContaining('days left'), findsNothing);
      // LOP without an lwp balance row: "—", used from own stats, no cap.
      expect(lopText(tester, 'available'), '—');
      expect(lopText(tester, 'used'), 'Used: 2.5');
      expect(lopText(tester, 'total'), 'Total: No cap');
      // Balances and own-scope stats for the same calendar year — as web;
      // never team figures.
      expect(server.balanceQueries, [
        {'year': 2026}
      ]);
      expect(server.statsQueries, [
        {'year': 2026, 'scope': 'own'}
      ]);
      expect(find.text('My Leave Requests'), findsOneWidget);
      expect(find.text('20 Nov – 21 Nov'), findsOneWidget); // own pending request
      expect(find.text('1 Dec – 2 Dec'), findsOneWidget); // own approved request
      expect(statusOf(tester, 'L1'), 'pending');
      expect(statusOf(tester, 'L2'), 'approved');
      expect(find.widgetWithText(FilledButton, 'Approve'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Reject'), findsNothing);
      // Requests: own list only — no team approval queue, no branches.
      expect(server.gets.where((g) => g.$1 == '/leave/requests/' && g.$2['scope'] == 'team'), isEmpty);
      expect(server.gets.where((g) => g.$1.contains('/branch/')), isEmpty);
      // Only the dashboard's own data: balances, own requests, own stats.
      expect(server.gets.map((g) => g.$1).toSet(), {'/leave/balance/', '/leave/requests/', '/leave/stats/'});
      expect(server.writes, isEmpty);
      // Apply Leave and tab switching.
      await tester.tap(find.text('Apply My Leave'));
      await settle(tester);
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
      await tester.tap(find.text('Team Calendar'));
      await settle(tester);
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 2);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('own approved leave: details open with cancellation (Task 64) still available', (tester) async {
    await pump(tester, roles['hr_admin']!);
    final req = find.text('1 Dec – 2 Dec');
    await tester.ensureVisible(req);
    await tester.tap(req);
    await settle(tester);
    expect(find.byKey(const Key('leave-cancellation-panel')), findsOneWidget);
    expect(find.byKey(const Key('leave-cancellation-request')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  group('layout: no overflow (balance strip sizes to its content)', () {
    for (final (label, size, scale) in [
      ('narrow phone 360 dp', const Size(360, 780), 1.0),
      ('narrow phone, text ×1.3', const Size(360, 780), 1.3),
      ('narrow phone, text ×2.0', const Size(360, 780), 2.0),
      ('regular phone, text ×1.5', const Size(412, 915), 1.5),
    ]) {
      testWidgets(label, (tester) async {
        // With an lwp row the LOP card shows its longest footer.
        await pump(tester, roles['employee']!, size: size, textScale: scale,
            setup: (s) => s.lwp = {'leave_type': 'lwp', 'leave_type_display': 'Leave Without Pay', 'used_days': 12.5, 'total_days': 30});
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('leave-balance-card-lop')), findsOneWidget);
        expect(find.text('My Pending'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('Loss of Pay card (web LeaveDashboard.tsx)', () {
    testWidgets('lwp balance row: Available = total − used, Used, Total', (tester) async {
      await pump(tester, roles['employee']!,
          setup: (s) => s.lwp = {'leave_type': 'lwp', 'leave_type_display': 'Leave Without Pay', 'used_days': 3, 'total_days': 10});
      expect(lopText(tester, 'available'), '7');
      expect(lopText(tester, 'used'), 'Used: 3');
      expect(lopText(tester, 'total'), 'Total: 10');
      final bar = tester.widget<LinearProgressIndicator>(
          find.descendant(of: find.byKey(const Key('leave-balance-card-lop')), matching: find.byType(LinearProgressIndicator)));
      expect(bar.value, closeTo(0.3, 1e-9)); // used / total, as web
    });

    testWidgets('lwp row with no cap (total 0): Available 0 − used, empty bar', (tester) async {
      await pump(tester, roles['employee']!,
          setup: (s) => s.lwp = {'leave_type': 'lwp', 'leave_type_display': 'Leave Without Pay', 'used_days': 2, 'total_days': 0});
      expect(lopText(tester, 'available'), '-2'); // web: total − used, unclamped
      expect(lopText(tester, 'total'), 'Total: 0');
      final bar = tester.widget<LinearProgressIndicator>(
          find.descendant(of: find.byKey(const Key('leave-balance-card-lop')), matching: find.byType(LinearProgressIndicator)));
      expect(bar.value, 0);
    });

    for (final (label, lop, days, expected) in [
      ('stats lop_days 0', Lop.value, 0 as Object, 'Used: 0'),
      ('stats lop_days as a decimal string', Lop.value, '1.5' as Object, 'Used: 1.5'),
      ('stats lop_days null', Lop.nullValue, 0 as Object, 'Used: 0'),
      ('stats lop_days missing', Lop.missing, 0 as Object, 'Used: 0'),
      ('stats request failed', Lop.error, 0 as Object, 'Used: 0'),
    ]) {
      testWidgets('no lwp row, $label → "—" / $expected / No cap', (tester) async {
        await pump(tester, roles['employee']!, setup: (s) {
          s.lop = lop;
          s.lopDays = days;
        });
        expect(lopText(tester, 'available'), '—');
        expect(lopText(tester, 'used'), expected);
        expect(lopText(tester, 'total'), 'Total: No cap');
        // The other cards are unaffected.
        expect(card(tester, 'casual'), ('10', 'Used: 2', 'Total: 12'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('approver (hr_admin): stats still own scope, never team', (tester) async {
      await pump(tester, roles['hr_admin']!);
      expect(server.statsQueries.single, {'year': 2026, 'scope': 'own'});
    });
  });

  group('Casual / Sick / Earned cards (web LeaveDashboard.tsx)', () {
    double bar(WidgetTester tester, String code) => tester
        .widget<LinearProgressIndicator>(find.descendant(
            of: find.byKey(Key('leave-balance-card-$code')), matching: find.byType(LinearProgressIndicator)))
        .value!;

    testWidgets('labels and bars: used / total, rounded to a whole percent', (tester) async {
      await pump(tester, roles['employee']!);
      for (final (code, label) in [('casual', 'Casual Leave'), ('sick', 'Sick Leave'), ('earned', 'Earned Leave')]) {
        expect(find.descendant(of: find.byKey(Key('leave-balance-card-$code')), matching: find.text(label)), findsOneWidget);
      }
      expect(bar(tester, 'casual'), 0.17); // round(2 / 12 × 100) = 17%
      expect(bar(tester, 'sick'), 0.0);
      expect(bar(tester, 'earned'), 0.27); // round(4 / 15 × 100) = 27%
    });

    testWidgets('zero total: Available 0, empty bar, no division error', (tester) async {
      await pump(tester, roles['employee']!,
          setup: (s) => s.rows['sick'] = {'leave_type': 'sick', 'used_days': 0, 'total_days': 0});
      expect(card(tester, 'sick'), ('0', 'Used: 0', 'Total: 0'));
      expect(bar(tester, 'sick'), 0.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('negative available kept (used beyond total); bar full', (tester) async {
      await pump(tester, roles['employee']!,
          setup: (s) => s.rows['casual'] = {'leave_type': 'casual', 'used_days': '6.5', 'total_days': '5.0'});
      expect(card(tester, 'casual'), ('-1.5', 'Used: 6.5', 'Total: 5'));
      expect(bar(tester, 'casual'), 1.0); // 130%, clipped by the bar as on web
    });

    testWidgets('fractional values printed as web Number(): 1.25, not rounded', (tester) async {
      await pump(tester, roles['employee']!,
          setup: (s) => s.rows['earned'] = {'leave_type': 'earned', 'used_days': 1.25, 'total_days': 15});
      expect(card(tester, 'earned'), ('13.75', 'Used: 1.25', 'Total: 15'));
    });

    testWidgets('missing row and null values: zeros, as web', (tester) async {
      await pump(tester, roles['employee']!, setup: (s) {
        s.rows['sick'] = null;
        s.rows['earned'] = {'leave_type': 'earned', 'used_days': null, 'total_days': null};
      });
      expect(card(tester, 'sick'), ('0', 'Used: 0', 'Total: 0'));
      expect(card(tester, 'earned'), ('0', 'Used: 0', 'Total: 0'));
      expect(cardOrder(tester), ['casual', 'sick', 'earned', 'lop']);
    });

    testWidgets('balance request fails: web\'s zero cards, plus the error named', (tester) async {
      await pump(tester, roles['employee']!, setup: (s) => s.balanceFails = true);
      expect(card(tester, 'casual'), ('0', 'Used: 0', 'Total: 0'));
      expect(lopText(tester, 'available'), '—');
      expect(find.byKey(const Key('leave-balance-error')), findsOneWidget);
      expect(cardOrder(tester), ['casual', 'sick', 'earned', 'lop']);
    });
  });

  group('reporting year: web getLeaveYear() = calendar year, for balances and stats', () {
    for (final (label, at, year) in [
      ('1 January', DateTime(2027, 1, 1, 9), 2027),
      ('mid-February (financial year still 2026)', DateTime(2027, 2, 10, 9), 2027),
      ('31 March', DateTime(2027, 3, 31, 23), 2027),
      ('1 April', DateTime(2026, 4, 1, 9), 2026),
      ('31 December', DateTime(2026, 12, 31, 23), 2026),
    ]) {
      testWidgets('$label → $year', (tester) async {
        await pump(tester, roles['employee']!, at: at);
        expect(server.balanceQueries.single, {'year': year});
        expect(server.statsQueries.single, {'year': year, 'scope': 'own'});
      });
    }

    testWidgets('pull-to-refresh refetches; after New Year it asks for the new year', (tester) async {
      await pump(tester, roles['employee']!, at: DateTime(2026, 12, 31, 23, 59));
      now = DateTime(2027, 1, 1, 0, 1);
      await tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
      await settle(tester);
      expect(server.balanceQueries.toList(), [
        {'year': 2026},
        {'year': 2027}
      ]);
      expect(server.statsQueries.last, {'year': 2027, 'scope': 'own'});
      expect(server.gets.where((g) => g.$1 == '/leave/requests/').length, greaterThan(1));
    });

    for (final role in ['hr_admin', 'manager', 'system_admin']) {
      testWidgets('$role: own balances and stats only (no employee_id, no team scope)', (tester) async {
        await pump(tester, roles[role]!);
        expect(server.balanceQueries.single, {'year': 2026});
        expect(server.statsQueries.single, {'year': 2026, 'scope': 'own'});
      });
    }

    testWidgets('cancellation request refreshes the dashboard\'s balances and stats', (tester) async {
      await pump(tester, roles['employee']!);
      final req = find.text('1 Dec – 2 Dec');
      await tester.ensureVisible(req);
      await tester.tap(req);
      await settle(tester);
      Future<void> tapKey(String k) async {
        await tester.ensureVisible(find.byKey(Key(k)));
        await tester.tap(find.byKey(Key(k)));
        await settle(tester);
      }

      await tapKey('leave-cancellation-request');
      await tester.enterText(find.byKey(const Key('leave-cancellation-text')), 'Plans changed');
      await tester.pump();
      await tapKey('leave-cancellation-submit');
      expect(server.writes, [('POST', '/leave/requests/L2/cancellation/')]);
      expect(server.balanceQueries.length, 2);
      expect(server.balanceQueries.every((q) => q['year'] == 2026), isTrue);
      expect(server.statsQueries.length, 2);
    });
  });

  group('navigation', () {
    test('Leave stays reachable by leave.view; approvals stay on the Approvals screen', () {
      expect(canAccessPath(roles['employee'], AppRoutes.leave), isTrue);
      expect(canAccessPath(roles['employee'], AppRoutes.approvals), isFalse);
      expect(canAccessPath(roles['manager'], AppRoutes.approvals), isTrue);
      expect(canAccessPath(roles['hr_admin'], AppRoutes.approvals), isTrue);
      expect(canAccessPath(roles['system_admin'], AppRoutes.approvals), isTrue);
    });

    test('leave module off: Leave screen not reachable', () {
      final u = user('hr_admin', ['leave.view', 'leave.approve'], modules: const ['attendance']);
      expect(canAccessPath(u, AppRoutes.leave), isFalse);
      expect(resolveAuthRedirect(authState: AuthState(user: u), path: AppRoutes.leave), AppRoutes.dashboard);
    });
  });
}
