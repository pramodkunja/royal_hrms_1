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
import 'package:mobile_app/features/notifications/data/models/notification_model.dart';
import 'package:mobile_app/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:mobile_app/features/notifications/presentation/widgets/notification_panel.dart';

// Task 75: holiday notification navigation.
// Backend: Notification.notification_type / module 'holiday' exists (a
// leave-module notification, apps/tenants/access.py NOTIFICATION_MODULES),
// with reference_id; no current backend code sends one, so rows come from
// older data or a future sender. Web NotificationBell.tsx routes by module
// only — holiday → /dashboard/attendance (HR Attendance), unknown →
// /dashboard — marks the row read first, and relies on proxy.ts, which
// sends anyone without attendance.edit / settings.edit back to /dashboard
// (where the Upcoming Holidays card is). Mobile now decides that up front
// with the router's own rule, so it never navigates into a blocked screen.
// The in-app bell panel is the only notification entry point (no push,
// local-notification or deep-link handling exists in this app).
// Synthetic users and notifications; a stand-in server records requests.

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> note(String id, String module, {String type = '', String title = '', Object? reference = 'h-1'}) => {
      'id': id,
      'title': title.isEmpty ? 'Note $id' : title,
      'message': 'Synthetic message $id',
      'notification_type': type.isEmpty ? module : type,
      'module': module,
      if (reference != null) 'reference_id': reference,
      'is_read': false,
      'created_at': '2026-11-15T09:00:00Z',
    };

NotificationModel model(Map<String, dynamic> j) => NotificationModel.fromJson(j);

class Server implements HttpClientAdapter {
  Server(this.rows);
  final List<Map<String, dynamic>> rows;
  final gets = <String>[];
  final writes = <(String, String)>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') {
      writes.add((o.method, o.path));
      return _json({'status': 'success', 'message': 'ok', 'data': {}});
    }
    gets.add(o.path);
    if (o.path == '/notifications/') {
      return _json({
        'status': 'success',
        'message': 'ok',
        'data': {'count': rows.length, 'page': 1, 'total_pages': 1, 'unread_count': rows.length, 'results': rows},
      });
    }
    if (o.path == '/notifications/unread-count/') {
      return _json({'status': 'success', 'message': 'ok', 'data': {'unread_count': rows.length}});
    }
    return _json({'status': 'success', 'message': 'ok', 'data': {}});
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

class TestAuth extends AuthNotifier {
  TestAuth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

UserEntity user(List<String> perms, {bool superuser = false, bool team = false, List<String>? modules}) => UserEntity(
      id: 'u1',
      email: 'u@example.test',
      fullName: 'Test User',
      role: 'r',
      roleDisplay: 'Role',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      canManageTeam: team,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final employee = user(['leave.view', 'leave.create', 'attendance.view', 'attendance.create']);
final hr = user(['leave.view', 'attendance.view', 'attendance.create', 'attendance.edit', 'employees.view']);
final manager = user(['leave.view', 'leave.approve', 'attendance.view'], team: true);
final superuserOnly = user(const [], superuser: true);
final settingsAdmin = user(['settings.view', 'settings.edit']); // older session, no flag
final attendanceViewOnly = user(['attendance.view']);
final attendanceEditOnly = user(['attendance.edit']);

const screens = {
  AppRoutes.dashboard: 'HOME',
  AppRoutes.attendance: 'HR ATTENDANCE',
  AppRoutes.myAttendance: 'MY ATTENDANCE',
  AppRoutes.leave: 'LEAVE',
  AppRoutes.announcements: 'ANNOUNCEMENTS',
  AppRoutes.profile: 'PROFILE',
};

late Server server;
late GoRouter router;
final built = <String>[];

Future<void> pumpApp(WidgetTester tester, UserEntity u, List<Map<String, dynamic>> rows,
    {Size size = const Size(1080, 2400), double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server(rows);
  built.clear();
  router = GoRouter(
    initialLocation: AppRoutes.dashboard,
    // The app's own guard (AppRouter): blocked paths go to the dashboard.
    redirect: (_, s) => resolveAuthRedirect(authState: AuthState(user: u), path: s.uri.path),
    routes: [
      for (final MapEntry(key: path, value: label) in screens.entries)
        GoRoute(
          path: path,
          builder: (_, __) {
            built.add(label);
            return Scaffold(
              // Stand-in screen: the bell in the app bar, the label in the body.
              appBar: AppBar(actions: const [NotificationBellButton()]),
              body: Text('$label BODY'),
            );
          },
        ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => TestAuth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    // As in the app (AppRouter watches it), the signed-in state is loaded
    // and kept alive.
    child: Consumer(builder: (context, ref, _) {
      ref.watch(authStateProvider);
      return MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      );
    }),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapNotification(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('Notifications'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox()); // stops the unread-count poll
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('destination rule (holiday)', () {
    final holiday = model(note('n1', 'holiday'));
    for (final (label, u, dest) in [
      ('ordinary employee', employee, AppRoutes.dashboard),
      ('HR with attendance.edit', hr, AppRoutes.attendance),
      ('manager (no attendance.edit)', manager, AppRoutes.dashboard),
      ('superuser', superuserOnly, AppRoutes.attendance),
      ('settings.edit admin, no flag', settingsAdmin, AppRoutes.attendance),
      ('attendance.view only', attendanceViewOnly, AppRoutes.dashboard),
      ('attendance.edit only', attendanceEditOnly, AppRoutes.attendance),
      ('HR with the attendance module off', user(hr.permissions, modules: const ['leave']), AppRoutes.dashboard),
      ('superuser with the attendance module off', user(const [], superuser: true, modules: const ['leave']), AppRoutes.dashboard),
    ]) {
      test('$label → $dest', () => expect(notificationDestination(holiday, u), dest));
    }

    test('missing or odd payload data: never a crash, never a blocked screen', () {
      // No reference id / date: the destination doesn't depend on it (web ignores it too).
      expect(notificationDestination(model(note('n2', 'holiday', reference: null)), hr), AppRoutes.attendance);
      expect(notificationDestination(model(note('n3', 'holiday', reference: null)), employee), AppRoutes.dashboard);
      // Unknown / missing / differently-cased module → dashboard, as web's fallback.
      for (final m in ['', 'HOLIDAY', 'holidays', 'something_new']) {
        expect(notificationDestination(model(note('n4', m)), superuserOnly), AppRoutes.dashboard, reason: m);
      }
      // Malformed JSON values parse to safe defaults.
      final odd = NotificationModel.fromJson({'id': 7, 'module': null, 'title': null, 'is_read': null});
      expect(notificationDestination(odd, employee), AppRoutes.dashboard);
      expect(notificationDestination(model(note('n5', 'holiday')), null), AppRoutes.dashboard); // signed out
    });

    test('other modules unchanged for users who can open them', () {
      expect(notificationDestination(model(note('a', 'leave')), employee), AppRoutes.leave);
      expect(notificationDestination(model(note('b', 'permission')), employee), AppRoutes.leave);
      expect(notificationDestination(model(note('c', 'attendance')), employee), AppRoutes.myAttendance);
      expect(notificationDestination(model(note('d', 'regularization')), employee), AppRoutes.myAttendance);
      expect(notificationDestination(model(note('e', 'announcement')), employee), AppRoutes.announcements);
      // …and the dashboard when they can't (the router would send them there anyway).
      expect(notificationDestination(model(note('f', 'leave')), user(const ['attendance.view'], modules: const ['attendance'])),
          AppRoutes.dashboard);
    });
  });

  // Task 78: promotion. Backend notifications/signals.py notifies only the
  // promoted employee (module / type 'promotion'; reference_id = the
  // PromotionRecord id, not an employee). Web NotificationBell.tsx:
  // promotion → /dashboard/profile, the signed-in user's own profile —
  // self-service, no permission. 'role_change' has no web route → dashboard.
  group('promotion → own profile', () {
    final promotion = model(note('p1', 'promotion', title: 'Congratulations on Your Promotion!', reference: 'pr-77'));
    for (final (label, u) in [
      ('ordinary employee', employee),
      ('manager', manager),
      ('HR', hr),
      ('superuser', superuserOnly),
      ('settings.edit admin, no flag', settingsAdmin),
      ('module list limited (profile is core)', user(['leave.view'], modules: const ['leave'])),
    ]) {
      test('$label → own profile', () => expect(notificationDestination(promotion, u), AppRoutes.profile));
    }

    test('reference missing / malformed: still the own profile (it is never used); signed out → dashboard', () {
      expect(notificationDestination(model(note('p2', 'promotion', reference: null)), employee), AppRoutes.profile);
      expect(notificationDestination(model(note('p3', 'promotion', reference: 'not-an-id')), employee), AppRoutes.profile);
      expect(notificationDestination(model(note('p4', 'promotion')), null), AppRoutes.dashboard);
    });

    test('role_change (no web route) → dashboard; holiday unchanged', () {
      expect(notificationDestination(model(note('r1', 'role_change')), employee), AppRoutes.dashboard);
      expect(notificationDestination(model(note('h1', 'holiday')), employee), AppRoutes.dashboard);
      expect(notificationDestination(model(note('h2', 'holiday')), hr), AppRoutes.attendance);
    });

    for (final (label, u) in [('employee', employee), ('manager', manager), ('HR', hr), ('admin', superuserOnly)]) {
      testWidgets('$label taps a promotion notification: own profile, marked read, no employee lookup', (tester) async {
        await pumpApp(tester, u, [note('p1', 'promotion', title: 'Congratulations on Your Promotion!', reference: 'pr-77')]);
        await tapNotification(tester, 'Congratulations on Your Promotion!');
        expect(find.text('PROFILE BODY'), findsOneWidget);
        expect(server.writes, [('PATCH', '/notifications/p1/read/')]);
        // Never another employee's record: no /employees/<id> request.
        expect(server.gets.where((p) => p.startsWith('/employees')), isEmpty);
        await unmount(tester);
      });
    }
  });

  group('in-app notification panel (the only entry point)', () {
    testWidgets('employee taps a holiday notification: dashboard, marked read, HR Attendance never built', (tester) async {
      await pumpApp(tester, employee, [note('n1', 'holiday', title: 'Diwali holiday')]);
      await tapNotification(tester, 'Diwali holiday');
      expect(find.text('HOME BODY'), findsOneWidget);
      expect(built, isNot(contains('HR ATTENDANCE')));
      expect(router.canPop(), isFalse); // no second dashboard stacked, no loop
      expect(server.writes, [('PATCH', '/notifications/n1/read/')]);
      expect(server.gets.where((p) => p.startsWith('/attendance')), isEmpty);
      await unmount(tester);
    });

    for (final (label, u) in [('HR', hr), ('superuser', superuserOnly), ('settings.edit admin', settingsAdmin)]) {
      testWidgets('$label taps a holiday notification: HR Attendance, as web', (tester) async {
        await pumpApp(tester, u, [note('n1', 'holiday', title: 'Diwali holiday')]);
        await tapNotification(tester, 'Diwali holiday');
        expect(find.text('HR ATTENDANCE BODY'), findsOneWidget);
        expect(server.writes, [('PATCH', '/notifications/n1/read/')]);
        await unmount(tester);
      });
    }

    testWidgets('manager: dashboard (no attendance.edit)', (tester) async {
      await pumpApp(tester, manager, [note('n1', 'holiday', title: 'Diwali holiday')]);
      await tapNotification(tester, 'Diwali holiday');
      expect(find.text('HOME BODY'), findsOneWidget);
      expect(built, isNot(contains('HR ATTENDANCE')));
      await unmount(tester);
    });

    testWidgets('already-read notification: not marked again', (tester) async {
      await pumpApp(tester, employee, [
        {...note('n1', 'holiday', title: 'Diwali holiday'), 'is_read': true}
      ]);
      await tapNotification(tester, 'Diwali holiday');
      expect(server.writes, isEmpty);
      expect(find.text('HOME BODY'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('malformed module: dashboard', (tester) async {
      await pumpApp(tester, employee, [note('n9', 'not_a_module', title: 'Odd one')]);
      await tapNotification(tester, 'Odd one');
      expect(find.text('HOME BODY'), findsOneWidget);
      expect(router.canPop(), isFalse);
      await unmount(tester);
    });

    for (final (module, screen) in [
      ('leave', 'LEAVE BODY'),
      ('attendance', 'MY ATTENDANCE BODY'),
      ('announcement', 'ANNOUNCEMENTS BODY'),
    ]) {
      testWidgets('existing $module notification still opens its screen', (tester) async {
        await pumpApp(tester, employee, [note('n1', module, title: 'About $module')]);
        await tapNotification(tester, 'About $module');
        expect(find.text(screen), findsOneWidget);
        await unmount(tester);
      });
    }

    testWidgets('narrow screen, large text: panel opens and the tap still works', (tester) async {
      await pumpApp(tester, employee, [note('n1', 'holiday', title: 'Diwali holiday')],
          size: const Size(360, 780), textScale: 2.0);
      expect(tester.takeException(), isNull);
      await tapNotification(tester, 'Diwali holiday');
      expect(tester.takeException(), isNull);
      expect(find.text('HOME BODY'), findsOneWidget);
      await unmount(tester);
    });
  });
}
