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
import 'package:mobile_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/navigation/nav_config.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';

// Task 71c (audit findings M2, L2): HR Attendance.
//  - Menu and route: web navConfig.ts / proxy.ts — attendance.edit or
//    settings.edit. attendance.view / .create alone are My Attendance rights
//    (backend apps/attendance/access.py; non-staff get only their own rows).
//  - OT Entry: web OtEntryTab shows "Add OT Entry" only for
//    usePermission("attendance.create"); form and records stay visible.
//  - Invalid Punches: web InvalidPunchesTab shows Assign / Convert / Discard
//    only for usePermission("attendance.edit"); the server additionally needs
//    attendance staff + attendance.create (hr_audit_actions.py).
// usePermission = superuser flag or the permission = mobile userHasPermission
// (which also passes settings.edit, as the backend's has_perm does).

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object data) => _json(200, {'status': 'success', 'message': 'ok', 'data': data});

class Server implements HttpClientAdapter {
  final writes = <(String, String, Object?)>[];
  String? refuse;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') {
      writes.add((o.method, o.path, o.data));
      if (refuse != null) return _json(403, {'status': 'error', 'message': refuse, 'data': {}});
      return _ok(<String, dynamic>{});
    }
    if (o.path == '/attendance/invalid-punches/') {
      return _ok([
        {
          'id': 'ip1',
          'device_id': 'DEV-7',
          'raw_time': '09:02',
          'biometric_id': 'B-99',
          'issue': 'Unknown card',
          'issue_type': 'unknown_card',
          'suggested_match': '—',
          'branch': 'North',
        }
      ]);
    }
    return _ok({'count': 0, 'page': 1, 'page_size': 20, 'total_pages': 1, 'results': <Object>[]});
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

UserEntity user(List<String> perms, {bool superuser = false, List<String>? modules}) => UserEntity(
      id: 'u1',
      email: 'u@example.test',
      fullName: 'Test User',
      role: 'r',
      roleDisplay: 'Role',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final editOnly = user(['attendance.view', 'attendance.edit']);
final createOnly = user(['attendance.create']);
final viewOnly = user(['attendance.view']);
final settingsAdmin = user(['settings.view', 'settings.edit'], superuser: true);
final settingsAdminNoFlag = user(['settings.view', 'settings.edit']);
final superuserOnly = user(const [], superuser: true);
final employee = user(['attendance.view', 'attendance.create', 'leave.view', 'leave.create']);
final staff = user(['attendance.view', 'attendance.create', 'attendance.edit']);

List<String> navPaths(UserEntity u) => [for (final e in buildNav(u)) if (e is NavItem) e.path];
List<String> tilePaths(UserEntity u) => [for (final i in visibleQuickItems(kQuickItemsAdmin, u)) i.path];

late Server server;

Future<void> pumpScreen(WidgetTester tester, UserEntity u, String tab) async {
  tester.view.physicalSize = const Size(2400, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
            ? const SizedBox()
            : const Scaffold(body: AttendanceScreen()),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text(tab));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('menu, route and dashboard tile (web: attendance.edit or settings.edit)', () {
    final cases = <(String, UserEntity, bool)>[
      ('attendance.edit', editOnly, true),
      ('attendance staff (create + edit)', staff, true),
      ('settings.edit admin, no attendance codenames', settingsAdmin, true),
      ('settings.edit admin from an older session (no flag)', settingsAdminNoFlag, true),
      ('explicit superuser, no codenames', superuserOnly, true),
      ('attendance.create only', createOnly, false),
      ('attendance.view only', viewOnly, false),
      ('ordinary employee (view + create)', employee, false),
    ];
    for (final (label, u, allowed) in cases) {
      test('$label → ${allowed ? 'HR Attendance' : 'no HR Attendance'}', () {
        expect(navPaths(u).contains('/dashboard/attendance'), allowed, reason: 'menu');
        expect(canAccessPath(u, '/dashboard/attendance'), allowed, reason: 'route');
        expect(
            resolveAuthRedirect(authState: AuthState(user: u), path: '/dashboard/attendance'),
            allowed ? isNull : AppRoutes.dashboard,
            reason: 'direct navigation');
        expect(tilePaths(u).contains('/dashboard/attendance'), allowed, reason: 'quick tile');
        // My Attendance stays for everyone (attendance module on).
        expect(canAccessPath(u, '/dashboard/my-attendance'), isTrue);
      });
    }

    test('attendance module off: hidden even for staff and admins', () {
      for (final u in [user(staff.permissions, modules: const ['leave']), user(const ['settings.edit'], superuser: true, modules: const [])]) {
        expect(navPaths(u), isNot(contains('/dashboard/attendance')));
        expect(canAccessPath(u, '/dashboard/attendance'), isFalse);
        expect(resolveAuthRedirect(authState: AuthState(user: u), path: '/dashboard/attendance'), AppRoutes.dashboard);
      }
    });

    test('manager dashboard tiles follow the same route rule', () {
      expect(requiredPermissionsFor('/dashboard/attendance'), ['attendance.edit', 'settings.edit']);
    });
  });

  group('OT Entry: "Add OT Entry" needs attendance.create (web OtEntryTab)', () {
    testWidgets('attendance.edit without create: form and records shown, no Add button, nothing sent', (tester) async {
      await pumpScreen(tester, editOnly, 'OT Entry');
      expect(find.text('OT Records'), findsWidgets);
      expect(find.byKey(const Key('ot-add-entry')), findsNothing); // ("Add OT Entry" is also the card title)
      expect(server.writes, isEmpty);
    });

    for (final (label, u) in [('attendance staff', staff), ('settings.edit admin', settingsAdmin), ('superuser', superuserOnly)]) {
      testWidgets('$label: Add OT Entry shown', (tester) async {
        await pumpScreen(tester, u, 'OT Entry');
        expect(find.byKey(const Key('ot-add-entry')), findsOneWidget);
      });
    }
  });

  group('Invalid Punches: Assign / Convert / Discard need attendance.edit (web)', () {
    testWidgets('attendance.create without edit: punch shown, no actions, nothing sent', (tester) async {
      await pumpScreen(tester, createOnly, 'Invalid Punches');
      expect(find.text('DEV-7'), findsOneWidget);
      expect(find.byKey(const Key('invalid-punch-no-actions')), findsOneWidget);
      for (final a in ['Assign', 'Convert', 'Discard']) {
        expect(find.widgetWithText(OutlinedButton, a), findsNothing, reason: a);
      }
      expect(server.writes, isEmpty);
    });

    for (final (label, u) in [('attendance.edit', editOnly), ('settings.edit admin', settingsAdmin), ('superuser', superuserOnly)]) {
      testWidgets('$label: all three actions shown', (tester) async {
        await pumpScreen(tester, u, 'Invalid Punches');
        for (final a in ['Assign', 'Convert', 'Discard']) {
          expect(find.widgetWithText(OutlinedButton, a), findsOneWidget, reason: a);
        }
      });
    }

    testWidgets('authorised Discard: same request as before; a server refusal is shown', (tester) async {
      await pumpScreen(tester, editOnly, 'Invalid Punches');
      server.refuse = 'Permission denied.';
      await tester.tap(find.widgetWithText(OutlinedButton, 'Discard'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Duplicate swipe');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(server.writes.single.$1, 'POST');
      expect(server.writes.single.$2, '/attendance/invalid-punches/ip1/discard/');
      expect(find.text('Permission denied.'), findsOneWidget);
    });
  });
}
