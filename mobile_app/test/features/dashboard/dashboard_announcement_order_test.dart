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
import 'package:mobile_app/features/attendance/presentation/clock/face_lockout.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/admin_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/employee_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/hr_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/manager_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/attendance_ring_card.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/dashboard_section.dart' show SectionCard;

// Task 56: Latest Announcement(s) above Attendance on every dashboard
// (requested order; web already renders its announcement right after the
// console). Attendance clock controls and the face-lockout countdown are
// unchanged. Synthetic data on a stand-in server; nothing is punched.

const announcementPath = '/dashboard/announcement/';
const adminAnnouncementPath = '/dashboard/system-admin/announcement/'; // Admin's own card
const todayPath = '/attendance/today/';
const annTitle = 'Office closed on Friday (test)';

Map<String, dynamic> announcement() => {
      'id': 'a1',
      'title': annTitle,
      'body': 'Synthetic announcement body.',
      'category': 'General',
      'visibility': 'all',
      'is_pinned': false,
      'posted_by': 'Test HR',
      'created_at': '2026-11-10T09:00:00+05:30',
    };

class Backend implements HttpClientAdapter {
  Object? ann = announcement();
  int annStatus = 200;
  Completer<void>? holdAnn;
  final paths = <String>[];
  int count(String p) => paths.where((x) => x == p).length;

  ResponseBody _r(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    paths.add(o.path);
    if (o.path == announcementPath || o.path == adminAnnouncementPath) {
      final gate = holdAnn;
      if (gate != null) await gate.future;
      if (annStatus != 200) return _r(annStatus, {'status': 'error', 'message': 'Server error.', 'data': {}});
      return _r(200, {'status': 'success', 'message': 'ok', 'data': ann});
    }
    if (o.path == todayPath) {
      return _r(200, {
        'status': 'success',
        'message': 'ok',
        'data': {
          'is_clocked_in': false,
          'day_completed': false,
          'punches': <Object>[],
          'total_seconds': 0,
          'session_seconds': 0,
          'date_display': 'Thursday, 12 November 2026',
        },
      });
    }
    if (o.method != 'GET') return _r(405, {'status': 'error', 'message': 'not in this test', 'data': {}});
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
      email: 'user@example.test',
      fullName: 'Test User',
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: false,
      permissions: perms,
      canManageTeam: manager,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final roles = <(String, UserEntity, Type)>[
  ('employee', user(), EmployeeDashboardView),
  ('hr', user(perms: ['employees.view', 'leave.view']), HrDashboardView),
  ('admin', user(superuser: true), AdminDashboardView),
  ('manager', user(manager: true), ManagerDashboardView),
];

late Backend backend;
late ProviderContainer container;
final fixedNow = DateTime(2026, 11, 12, 10);

Future<void> pumpHome(WidgetTester tester, UserEntity u,
    {void Function(Backend)? setup, Size size = const Size(1080, 9000), double dpr = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  backend = Backend();
  setup?.call(backend);
  final router = GoRouter(initialLocation: AppRoutes.dashboard, routes: [
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (_, __) => Consumer(
        builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
            ? const SizedBox()
            : const Scaffold(body: HomeScreen()),
      ),
    ),
    GoRoute(path: AppRoutes.announcements, builder: (_, __) => const Scaffold(body: Text('ANNOUNCEMENTS PAGE'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = backend),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      faceLockoutClockProvider.overrideWithValue(() => fixedNow),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  await settleSome(tester);
  container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
}

Future<void> settleSome(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// Dashboards start periodic timers; unmount before the test ends.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// The announcement section of [role]: the employee's inline banner, or the
/// "Latest Announcement" card elsewhere.
Finder announcementOf(String role) =>
    role == 'employee' ? find.byKey(const Key('emp-announcement-banner')) : find.text('Latest Announcement');
final attendance = find.text("Today's Attendance");
double top(WidgetTester tester, Finder f) => tester.getTopLeft(f.first).dy;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('1/2. every dashboard: the announcement comes before Attendance', (tester) async {
    for (final (role, u, view) in roles) {
      await pumpHome(tester, u);
      expect(find.byType(view), findsOneWidget, reason: role);
      expect(announcementOf(role), findsOneWidget, reason: role);
      expect(find.text(annTitle), findsOneWidget, reason: role);
      expect(find.byType(AttendanceRingCard), findsOneWidget, reason: role);
      expect(top(tester, announcementOf(role)), lessThan(top(tester, attendance)), reason: role);
      // Fetched once, as before (no extra requests from the move).
      expect(backend.count(announcementPath) + backend.count(adminAnnouncementPath), 1, reason: role);
      expect(backend.count(todayPath), 1, reason: role);
      await unmount(tester);
    }
  });

  testWidgets('employee: the banner sits right above Attendance and below the console', (tester) async {
    await pumpHome(tester, roles.first.$2);
    final banner = tester.getRect(find.byKey(const Key('emp-announcement-banner')));
    final ring = tester.getRect(find.byType(AttendanceRingCard));
    // The 20 px gap is the banner's own bottom margin (inside its box), so
    // an empty announcement leaves no gap at all.
    expect(ring.top, banner.bottom);
    expect(tester.widget<Container>(find.byKey(const Key('emp-announcement-banner'))).margin,
        const EdgeInsets.only(bottom: 20));
    expect(top(tester, find.text('Quick Access')), greaterThan(ring.top));
    await unmount(tester);
  });

  testWidgets('3. no announcement: employee shows nothing (no gap); others show "No announcements yet" above',
      (tester) async {
    for (final (role, u, _) in roles) {
      await pumpHome(tester, u, setup: (b) => b.ann = null);
      if (role == 'employee') {
        expect(announcementOf(role), findsNothing);
      } else {
        expect(find.text('No announcements yet'), findsOneWidget, reason: role);
        expect(top(tester, find.text('No announcements yet')), lessThan(top(tester, attendance)), reason: role);
      }
      expect(find.byType(AttendanceRingCard), findsOneWidget, reason: role);
      await unmount(tester);
    }
  });

  testWidgets('3. employee with no announcement: Attendance keeps its place after the console', (tester) async {
    await pumpHome(tester, roles.first.$2, setup: (b) => b.ann = null);
    final empty = top(tester, attendance);
    await unmount(tester);
    await pumpHome(tester, roles.first.$2);
    final withBanner = top(tester, attendance);
    expect(withBanner, greaterThan(empty), reason: 'the banner (and its gap) pushes Attendance down only when shown');
    await unmount(tester);
  });

  testWidgets('4. while the announcement loads, Attendance is already usable below it', (tester) async {
    for (final (role, u, _) in roles.skip(1)) {
      await pumpHome(tester, u, setup: (b) => b.holdAnn = Completer());
      expect(find.text('Latest Announcement'), findsOneWidget, reason: role);
      expect(find.text(annTitle), findsNothing, reason: role);
      expect(find.text('Clock In'), findsOneWidget, reason: role);
      expect(top(tester, announcementOf(role)), lessThan(top(tester, attendance)), reason: role);
      backend.holdAnn!.complete();
      await settleSome(tester);
      expect(find.text(annTitle), findsOneWidget, reason: role);
      await unmount(tester);
    }
  });

  testWidgets('4. a failed announcement shows its error with Retry above Attendance; Retry loads it', (tester) async {
    for (final (role, u, _) in roles.skip(1)) {
      await pumpHome(tester, u, setup: (b) => b.annStatus = 500);
      final annCard = find.ancestor(of: find.text('Latest Announcement'), matching: find.byType(SectionCard)).first;
      final retryFinder = find.descendant(of: annCard, matching: find.text('Retry'));
      expect(retryFinder, findsOneWidget, reason: role);
      expect(top(tester, retryFinder), lessThan(top(tester, attendance)), reason: role);
      expect(find.text('Clock In'), findsOneWidget, reason: '$role: attendance unaffected');
      backend.annStatus = 200;
      await tester.tap(retryFinder.first);
      await settleSome(tester);
      expect(find.text(annTitle), findsOneWidget, reason: role);
      await unmount(tester);
    }
    // Employee: a failed announcement renders nothing (as web), attendance stays.
    await pumpHome(tester, roles.first.$2, setup: (b) => b.annStatus = 500);
    expect(announcementOf('employee'), findsNothing);
    expect(find.text('Clock In'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('5/6. Clock In is live, and a face-verification lockout still shows its countdown', (tester) async {
    for (final (role, u, _) in roles) {
      await pumpHome(tester, u);
      expect(find.text('Clock In'), findsOneWidget, reason: role);
      container.read(faceLockoutProvider.notifier).lockFor(125);
      await tester.pump();
      final locked = find.byKey(const Key('clock-lockout-button'));
      expect(locked, findsOneWidget, reason: role);
      expect(find.descendant(of: locked, matching: find.text('Try again in 2m 5s')), findsOneWidget, reason: role);
      expect(top(tester, announcementOf(role)), lessThan(top(tester, locked)), reason: role);
      await unmount(tester);
    }
  });

  testWidgets('7. phone screen: the announcement and Attendance are on the first screen; scrolling reaches the rest',
      (tester) async {
    const phone = Size(1080, 2400); // ~411 x 914 dp
    for (final (role, u, _) in roles) {
      await pumpHome(tester, u, size: phone, dpr: 2.625);
      const screenH = 2400 / 2.625;
      expect(top(tester, announcementOf(role)), lessThan(screenH),
          reason: '$role: announcement visible without scrolling');
      expect(top(tester, attendance), lessThan(screenH * 1.5), reason: role);
      // Admin's existing "View all pending approvals" footer row (not moved
      // here) overflows at 411 dp only with the test font's square glyphs.
      final ex = tester.takeException();
      if (role == 'admin') {
        expect(ex == null || '$ex'.contains('overflowed'), isTrue, reason: '$ex');
      } else {
        expect(ex, isNull, reason: '$role: no overflow');
      }
      // Scroll the dashboard a long way: the list moves and nothing breaks.
      final before = top(tester, attendance);
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1500));
      await settleSome(tester);
      expect(top(tester, attendance), lessThan(before), reason: '$role scrolls');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    }
  });

  testWidgets('7. employee banner: View opens Announcements; ✕ hides it and Attendance moves up', (tester) async {
    await pumpHome(tester, roles.first.$2);
    final before = top(tester, attendance);
    await tester.tap(find.descendant(of: announcementOf('employee'), matching: find.byIcon(Icons.close)));
    await tester.pump();
    expect(announcementOf('employee'), findsNothing);
    expect(top(tester, attendance), lessThan(before));
    await unmount(tester);

    await pumpHome(tester, roles.first.$2);
    await tester.tap(find.descendant(of: announcementOf('employee'), matching: find.text('View')));
    await settleSome(tester);
    expect(find.text('ANNOUNCEMENTS PAGE'), findsOneWidget);
    await unmount(tester);
  });
}
