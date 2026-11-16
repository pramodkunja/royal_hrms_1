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
import 'package:mobile_app/features/separation/presentation/screens/separation_screen.dart';

// Task 73 (audit L8): Separation list "Filter by employee code…", as web
// separation/page.tsx — shown to canPickEmployee || canApprove
// (useAnyPermission employees.view / separation.approve / settings.edit),
// sent as employee_id=<trimmed text> with page 1 on every change, together
// with scope. Backend SeparationRequestListCreateView.get: exact
// (case-sensitive) match on User.employee_id; employees.view or
// separation.approve required; unknown or out-of-branch code → 404
// "Employee not found."; scope ignored while employee_id is set; status still
// applies. Mobile sends after a short typing pause (or Enter / Clear) rather
// than on every keystroke. Synthetic people; a stand-in server applies the
// backend's rules.

const debounce = Duration(milliseconds: 450);

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> sep(String id, String code, String name, String status) => {
      'id': id,
      'request_ref': 'SEP-$id',
      'separation_type': 'resignation',
      'separation_type_display': 'Resignation',
      'reason': 'better_opportunity',
      'reason_display': 'Better opportunity',
      'request_date': '2026-11-01',
      'proposed_last_working_day': '2026-12-01',
      'notice_period_days': 30,
      'comments': '',
      'status': status,
      'status_display': status,
      'employee_name': name,
      'employee_code': code,
      'employee_department': 'QA',
      'employee_designation': 'Tester',
      'reporting_manager': null,
      'document_url': null,
      'created_by_name': name,
      'approval_stages': <Object>[],
      'can_approve': false,
      'can_cancel': false,
      'can_edit': false,
      'can_delete': false,
      'is_own': false,
      'created_at': '2026-11-01T09:00:00Z',
      'assigned_notice_period_days': 30,
      'expected_last_working_day': '2026-12-01',
    };

class Server implements HttpClientAdapter {
  final gets = <Map<String, dynamic>>[];
  int writes = 0;

  /// Employees the caller may see (same branch). EMP-T2 exists but is in
  /// another branch; EMP-T3 is visible with no requests.
  final visible = {
    'EMP-T1': [
      sep('a1', 'EMP-T1', 'Asha Leaver', 'approved'),
      sep('a2', 'EMP-T1', 'Asha Leaver', 'cancelled'),
      sep('a3', 'EMP-T1', 'Asha Leaver', 'pending'),
    ],
    'EMP-T3': <Map<String, dynamic>>[],
  };
  final own = [sep('m1', 'EMP-ME', 'Test User', 'pending')];

  /// Team queue spans two pages (for the pagination reset).
  List<Map<String, dynamic>> team(int page) =>
      [for (var i = 0; i < 20; i++) sep('t$page-$i', 'EMP-Q$i', 'Queue Person $i', 'pending')];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') {
      writes++;
      return _json(200, {'status': 'success', 'message': 'ok', 'data': {}});
    }
    if (o.path != '/separation/requests/') {
      return _json(200, {'status': 'success', 'message': 'ok', 'data': <Object>[]});
    }
    final q = Map<String, dynamic>.of(o.queryParameters);
    gets.add(q);
    final page = int.tryParse('${q['page'] ?? 1}') ?? 1;
    List<Map<String, dynamic>> rows;
    var pages = 1;
    final code = q['employee_id'] as String?;
    if (code != null) {
      if (!visible.containsKey(code)) {
        return _json(404, {'status': 'error', 'message': 'Employee not found.', 'data': {}});
      }
      rows = visible[code]!; // scope ignored, as the backend
    } else if (q['scope'] == 'team') {
      rows = team(page);
      pages = 2;
    } else {
      rows = own;
    }
    final status = q['status'] as String?;
    if (status != null) {
      final allowed = status.split(',');
      rows = rows.where((r) => allowed.contains(r['status'])).toList();
    }
    return _json(200, {
      'status': 'success',
      'message': 'ok',
      'data': {'count': rows.length, 'page': page, 'page_size': 20, 'total_pages': pages, 'results': rows},
    });
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

final employee = user(['leave.view', 'attendance.view']);
final hr = user(['employees.view', 'leave.approve']);
final manager = user(['separation.approve']);
final superuserOnly = user(const [], superuser: true);
final olderAdmin = user(['settings.view', 'settings.edit']);

late Server server;
final field = find.byKey(const Key('separation-employee-filter'));

Future<void> pump(WidgetTester tester, UserEntity u, {Size size = const Size(1080, 2400), double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  final router = GoRouter(initialLocation: AppRoutes.separation, routes: [
    GoRoute(path: AppRoutes.separation, builder: (_, __) => const SeparationScreen()),
    GoRoute(
      path: '/dashboard/separation/:id',
      builder: (context, s) => Scaffold(
        body: Column(children: [
          Text('DETAIL ${s.pathParameters['id']}'),
          TextButton(onPressed: () => context.pop(), child: const Text('Back')),
        ]),
      ),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => TestAuth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(field, text);
  await tester.pump(debounce);
  await tester.pumpAndSettle();
}

Map<String, dynamic> get last => server.gets.last;
Iterable<Map<String, dynamic>> get filtered => server.gets.where((g) => g.containsKey('employee_id'));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('who gets the filter (web: canPickEmployee || canApprove)', () {
    for (final (label, u, shown) in [
      ('ordinary employee', employee, false),
      ('HR with employees.view', hr, true),
      ('manager with separation.approve', manager, true),
      ('superuser', superuserOnly, true),
      ('older settings.edit session', olderAdmin, true),
    ]) {
      testWidgets('$label → ${shown ? 'shown' : 'hidden'}', (tester) async {
        await pump(tester, u);
        expect(field, shown ? findsOneWidget : findsNothing);
        if (shown) expect(find.text('Filter by employee code…'), findsOneWidget);
        // The first load never carries employee_id.
        expect(server.gets.single.containsKey('employee_id'), isFalse);
        expect(server.writes, 0);
      });
    }
  });

  group('matching (backend: exact employee_id, server-side)', () {
    testWidgets('exact code: one request after typing pauses, page 1, that employee\'s requests', (tester) async {
      await pump(tester, hr);
      for (final partial in ['E', 'EM', 'EMP', 'EMP-', 'EMP-T']) {
        await tester.enterText(field, partial);
        await tester.pump(const Duration(milliseconds: 100)); // still typing
      }
      await type(tester, 'EMP-T1');
      expect(filtered.toList(), [
        {'page': 1, 'employee_id': 'EMP-T1'}
      ]);
      for (final id in ['a1', 'a2', 'a3']) {
        expect(find.text('SEP-$id'), findsOneWidget);
      }
      expect(find.text('Asha Leaver · EMP-T1'), findsNWidgets(3)); // another employee's: named
    });

    testWidgets('surrounding spaces are trimmed, as web', (tester) async {
      await pump(tester, hr);
      await type(tester, '  EMP-T1  ');
      expect(last['employee_id'], 'EMP-T1');
    });

    for (final (label, code) in [('partial code', 'EMP-T'), ('different case', 'emp-t1')]) {
      testWidgets('$label: sent as typed; the backend\'s exact match says "Employee not found."', (tester) async {
        await pump(tester, hr);
        await type(tester, code);
        expect(last['employee_id'], code);
        expect(find.text('Employee not found.'), findsOneWidget);
        expect(find.text('SEP-a1'), findsNothing);
      });
    }

    testWidgets('code in another branch: the server refuses (404), nothing shown', (tester) async {
      await pump(tester, hr);
      await type(tester, 'EMP-T2');
      expect(find.text('Employee not found.'), findsOneWidget);
      expect(find.textContaining('SEP-'), findsNothing);
    });

    testWidgets('employee with no requests: empty state names the code', (tester) async {
      await pump(tester, hr);
      await type(tester, 'EMP-T3');
      expect(find.text('No requests for employee EMP-T3.'), findsOneWidget);
    });

    testWidgets('empty / blank input and Clear: back to the unfiltered list', (tester) async {
      await pump(tester, hr);
      await type(tester, 'EMP-T1');
      await type(tester, '   ');
      expect(last.containsKey('employee_id'), isFalse);
      expect(find.text('SEP-m1'), findsOneWidget);
      await type(tester, 'EMP-T1');
      await tester.tap(find.byKey(const Key('separation-employee-filter-clear')));
      await tester.pumpAndSettle();
      expect(last.containsKey('employee_id'), isFalse);
      expect(tester.widget<TextField>(field).controller!.text, '');
    });

    testWidgets('Enter sends at once', (tester) async {
      await pump(tester, hr);
      await tester.enterText(field, 'EMP-T1');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(last['employee_id'], 'EMP-T1');
    });
  });

  group('combinations, paging, refresh, navigation', () {
    testWidgets('status chip and employee code combine (server applies both)', (tester) async {
      await pump(tester, hr);
      await type(tester, 'EMP-T1');
      await tester.tap(find.text('Approved'));
      await tester.pumpAndSettle();
      expect(last, {'page': 1, 'status': 'approved', 'employee_id': 'EMP-T1'});
      expect(find.text('SEP-a1'), findsOneWidget);
      expect(find.text('SEP-a2'), findsNothing);
      await type(tester, 'EMP-T3');
      expect(find.text('No requests for employee EMP-T3 with this status.'), findsOneWidget);
    });

    testWidgets('Team scope plus code: both sent, as web (server lists that employee)', (tester) async {
      await pump(tester, manager);
      await tester.tap(find.text('Team Requests'));
      await tester.pumpAndSettle();
      await type(tester, 'EMP-T1');
      expect(last, {'page': 1, 'scope': 'team', 'employee_id': 'EMP-T1'});
      expect(find.text('SEP-a3'), findsOneWidget);
    });

    testWidgets('a new code starts again from page 1', (tester) async {
      await pump(tester, manager);
      await tester.tap(find.text('Team Requests'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(server.gets.where((g) => g['scope'] == 'team').map((g) => g['page']), [1, 2]);
      await type(tester, 'EMP-T1');
      expect(last['page'], 1);
      expect(find.text('SEP-a1'), findsOneWidget);
    });

    testWidgets('pull-to-refresh keeps the code', (tester) async {
      await pump(tester, hr);
      await type(tester, 'EMP-T1');
      final before = filtered.length;
      // Not awaited: the refresh completes as frames are pumped.
      final done = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
      await tester.pumpAndSettle();
      await done;
      expect(filtered.length, before + 1);
      expect(last, {'page': 1, 'employee_id': 'EMP-T1'});
    });

    testWidgets('detail and back: the filter and its results stay', (tester) async {
      await pump(tester, hr);
      await type(tester, 'EMP-T1');
      await tester.tap(find.text('SEP-a1'));
      await tester.pumpAndSettle();
      expect(find.text('DETAIL a1'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'EMP-T1');
      expect(find.text('SEP-a1'), findsOneWidget);
      expect(last['employee_id'], 'EMP-T1');
    });
  });

  group('access and layout', () {
    test('Separation module off: list refused even for a superuser', () {
      final off = user(const [], superuser: true, modules: const ['leave']);
      expect(canAccessPath(off, AppRoutes.separation), isFalse);
      expect(resolveAuthRedirect(authState: AuthState(user: off), path: AppRoutes.separation), AppRoutes.dashboard);
      expect(canAccessPath(user(const [], superuser: true, modules: const ['separation']), AppRoutes.separation), isTrue);
    });

    testWidgets('employee: no field, so employee_id is never sent', (tester) async {
      await pump(tester, employee);
      await tester.tap(find.text('Approved'));
      await tester.pumpAndSettle();
      expect(server.gets, everyElement(isNot(contains('employee_id'))));
    });

    for (final (label, size, scale) in [
      ('360 dp', const Size(360, 780), 1.0),
      ('360 dp, text ×1.5', const Size(360, 780), 1.5),
      ('360 dp, text ×2.0', const Size(360, 780), 2.0),
    ]) {
      testWidgets('layout: $label, no overflow', (tester) async {
        await pump(tester, manager, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        await type(tester, 'EMP-T1');
        expect(tester.takeException(), isNull);
        expect(field, findsOneWidget);
      });
    }
  });
}
