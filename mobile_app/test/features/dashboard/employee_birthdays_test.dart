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
import 'package:mobile_app/features/dashboard/data/models/employee_dashboard_models.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/admin_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/employee_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/hr_dashboard_view.dart';

// P1-3: today's birthdays on the Employee dashboard, as web
// EmpBirthdayAnnouncement, from GET /dashboard/employee/birthdays/today/
// (production EmployeeBirthdayTodayView: IsAuthenticated +
// HasCompletedOnboarding, no employees.view). /birthdays/ (BirthdayView)
// still requires employees.view, so the Employee dashboard must not call it.
// Synthetic data only.

const empPath = '/dashboard/employee/birthdays/today/';
const hrmsPath = '/birthdays/';
const hrPath = '/dashboard/hr/birthdays/today/';
const adminPath = '/dashboard/system-admin/birthdays/today/';

Map<String, dynamic> person(String id, String name,
        {String designation = 'Analyst', String department = 'Finance', String message = ''}) =>
    {
      'employee_id': id,
      'full_name': name,
      'email': '${id.toLowerCase()}@example.test',
      'department': department,
      'designation': designation,
      'branch': 'North',
      'date_of_birth': '1990-11-06',
      'days_until': 0,
      'message': message,
    };

class Backend implements HttpClientAdapter {
  List<Map<String, dynamic>> birthdays = [];
  int empStatus = 200;
  Completer<void>? hold;
  final paths = <String>[];

  int count(String p) => paths.where((x) => x == p).length;

  ResponseBody _r(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    paths.add(o.path);
    if (o.path == empPath) {
      final gate = hold;
      if (gate != null) await gate.future;
      if (empStatus != 200) {
        return _r(empStatus, {'status': 'error', 'message': 'Refused.', 'data': {}});
      }
      return _r(200, {
        'status': 'success',
        'message': "Today's birthdays retrieved.",
        'data': {'count': birthdays.length, 'birthdays': birthdays},
      });
    }
    if (o.path == hrPath || o.path == adminPath) {
      // The HR/admin endpoints return the bare list (no message).
      return _r(200, {
        'status': 'success',
        'message': "Today's birthdays retrieved.",
        'data': [for (final b in birthdays) Map.of(b)..remove('message')],
      });
    }
    if (o.path == hrmsPath) {
      return _r(403, {'status': 'error', 'message': 'You do not have permission to perform this action.', 'data': {}});
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

UserEntity user({bool superuser = false, List<String> perms = const ['leave.view']}) => UserEntity(
      id: 'u1',
      email: 'emp@example.test',
      fullName: 'Test Employee',
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

late Backend backend;
late ProviderContainer container;

Future<void> pumpHome(WidgetTester tester, {UserEntity? as, void Function(Backend)? setup}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 1;
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
  await settleSome(tester);
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

final card = find.byKey(const Key('emp-birthdays-today'));
Finder inCard(Finder f) => find.descendant(of: card, matching: f);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('the response keeps only what web shows (no email, no date of birth)', () {
    final list = EmployeeBirthdayToday.listFrom({
      'count': 1,
      'birthdays': [person('TST01', 'Asha Rao', message: 'Wish them well!')],
    });
    final b = list.single;
    expect([b.employeeId, b.fullName, b.designation, b.department, b.message],
        ['TST01', 'Asha Rao', 'Analyst', 'Finance', 'Wish them well!']);
    expect(EmployeeBirthdayToday.listFrom(null), isEmpty);
    expect(EmployeeBirthdayToday.listFrom({'birthdays': 'x'}), isEmpty);
    expect(EmployeeBirthdayToday.listFrom([1, 2]), isEmpty);
  });

  group('Employee dashboard (no employees.view)', () {
    testWidgets('1. one birthday: "Happy Birthday, <name>!", the banner message and designation · department',
        (tester) async {
      await pumpHome(tester, setup: (b) => b.birthdays = [person('TST01', 'Asha Rao', message: 'Wish them well!')]);
      expect(find.byType(EmployeeDashboardView), findsOneWidget);
      expect(backend.count(empPath), 1);
      expect(inCard(find.text('Happy Birthday, Asha Rao!')), findsOneWidget);
      expect(inCard(find.text('Wish them well!')), findsOneWidget);
      expect(inCard(find.text('Asha Rao')), findsOneWidget);
      expect(inCard(find.text('Analyst · Finance')), findsOneWidget);
      // Nothing beyond what web shows.
      expect(find.textContaining('Turning'), findsNothing);
      expect(find.textContaining('tst01@example.test'), findsNothing);
      expect(find.textContaining('1990'), findsNothing);
      await unmount(tester);
    });

    testWidgets('2. several birthdays: "Today\'s Birthdays" with every person, no single-person message',
        (tester) async {
      await pumpHome(tester, setup: (b) {
        b.birthdays = [
          person('TST01', 'Asha Rao', message: 'Wish them well!'),
          person('TST02', 'Ravi Menon', designation: '', department: 'Sales', message: 'Wish them well!'),
        ];
      });
      expect(inCard(find.text("Today's Birthdays")), findsOneWidget);
      expect(inCard(find.text('Asha Rao')), findsOneWidget);
      expect(inCard(find.text('Ravi Menon')), findsOneWidget);
      expect(inCard(find.text('Sales')), findsOneWidget);
      expect(inCard(find.text('Wish them well!')), findsNothing);
      await unmount(tester);
    });

    testWidgets('3. hidden while loading and when nobody has a birthday today', (tester) async {
      final gate = Completer<void>();
      await pumpHome(tester, setup: (b) {
        b.birthdays = [person('TST01', 'Asha Rao')];
        b.hold = gate;
      });
      expect(card, findsNothing);
      gate.complete();
      await settleSome(tester);
      expect(card, findsOneWidget);
      await unmount(tester);

      await pumpHome(tester);
      expect(backend.count(empPath), 1);
      expect(card, findsNothing);
      expect(find.byType(EmployeeDashboardView), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('4. a 403, 404 or 500 hides the card quietly; the rest of the dashboard stays', (tester) async {
      for (final st in [403, 404, 500]) {
        await pumpHome(tester, setup: (b) {
          b.birthdays = [person('TST01', 'Asha Rao')];
          b.empStatus = st;
        });
        expect(backend.count(empPath), 1, reason: '$st');
        expect(card, findsNothing, reason: '$st');
        expect(find.textContaining('Refused.'), findsNothing, reason: '$st');
        expect(find.byType(EmployeeDashboardView), findsOneWidget);
        await unmount(tester);
      }
    });

    testWidgets('5. only the employee birthday endpoint: never /birthdays/ or the HR / admin endpoints',
        (tester) async {
      await pumpHome(tester, setup: (b) => b.birthdays = [person('TST01', 'Asha Rao')]);
      expect(backend.count(empPath), 1);
      expect(backend.count(hrmsPath), 0);
      expect(backend.count(hrPath), 0);
      expect(backend.count(adminPath), 0);
      expect(backend.paths.where((p) => p.startsWith('/employees/')), isEmpty);
      // Web's Team / Manager birthday cards use /dashboard/birthdays/mine/,
      // which is also open to every onboarded employee.
      expect(
          backend.paths.where(
              (p) => p.contains('/birthdays/') && p != empPath && p != '/dashboard/birthdays/mine/'),
          isEmpty);
      await unmount(tester);
    });

    testWidgets('6. a dashboard revisit fetches today\'s birthdays again', (tester) async {
      await pumpHome(tester, setup: (b) => b.birthdays = [person('TST01', 'Asha Rao')]);
      container.read(dashboardRevisitProvider.notifier).state++;
      await settleSome(tester);
      expect(backend.count(empPath), 2);
      await unmount(tester);
    });
  });

  group('other dashboards are unchanged', () {
    testWidgets('7. employees.view → HR dashboard and its own birthday endpoint', (tester) async {
      await pumpHome(tester,
          as: user(perms: ['employees.view', 'leave.view']), setup: (b) => b.birthdays = [person('TST01', 'Asha Rao')]);
      expect(find.byType(HrDashboardView), findsOneWidget);
      expect(backend.count(hrPath), greaterThan(0));
      expect(backend.count(empPath), 0);
      expect(find.text('Asha Rao'), findsWidgets);
      expect(card, findsNothing);
      await unmount(tester);
    });

    testWidgets('8. superuser → Admin dashboard and the system-admin birthday endpoint', (tester) async {
      await pumpHome(tester,
          as: user(superuser: true, perms: const []), setup: (b) => b.birthdays = [person('TST01', 'Asha Rao')]);
      expect(find.byType(AdminDashboardView), findsOneWidget);
      expect(backend.count(adminPath), greaterThan(0));
      expect(backend.count(empPath), 0);
      expect(backend.count(hrmsPath), 0);
      expect(find.text('Asha Rao'), findsWidgets);
      expect(card, findsNothing);
      await unmount(tester);
    });
  });
}
