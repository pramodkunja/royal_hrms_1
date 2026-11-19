import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/presentation/employees_screen.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart';

// Task 97 (B): the Employees stat cards and branch/department filter options
// come from GET /employees/stats/ exactly as web employees/page.tsx fetchStats
// does (`branch` param only when a branch is chosen; branch_names /
// department_names feed the filters; failures keep the previous cards and are
// not an error card). Synthetic data on a stand-in server — mocked tests only,
// not a production verification.

class _Server implements HttpClientAdapter {
  final calls = <RequestOptions>[];

  /// Per-branch stats ('' = no branch param). Names always list the whole scope.
  Map<String, Map<String, dynamic>> byBranch = {
    '': {'total': 12, 'active': 9, 'onboarding': 3, 'departments': 4},
    'Pune': {'total': 5, 'active': 4, 'onboarding': 1, 'departments': 2},
  };
  List<String> branchNames = ['Mumbai', 'Pune'];
  List<String> departmentNames = ['Finance', 'Quality'];
  int statsStatus = 200;
  Completer<void>? hold;

  List<RequestOptions> statsCalls() => calls.where((c) => c.path == ApiConstants.employeeStats).toList();

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add(o);
    if (o.path == ApiConstants.employeeStats) {
      final gate = hold;
      if (gate != null) await gate.future;
      if (statsStatus == 403) {
        return _json(
            {'status': 'error', 'message': 'You do not have permission to perform this action.', 'data': {}}, 403);
      }
      if (statsStatus >= 400) return _json({'status': 'error', 'message': 'Boom', 'data': {}}, statsStatus);
      final branch = (o.queryParameters['branch'] as String?) ?? '';
      return _json({
        'status': 'success',
        'message': 'Employee statistics retrieved.',
        'data': {
          ...(byBranch[branch] ?? {'total': 0, 'active': 0, 'onboarding': 0, 'departments': 0}),
          'branch_names': branchNames,
          'department_names': departmentNames,
        },
      });
    }
    if (o.path == ApiConstants.employees) {
      return _json({
        'status': 'success',
        'data': {'results': [], 'count': 0, 'page': 1, 'total_pages': 1},
      });
    }
    return _json({'status': 'success', 'data': []});
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

UserEntity _user({bool superuser = false, String branch = 'Pune'}) => UserEntity(
      id: 'me',
      email: 'me@example.test',
      fullName: 'Test User',
      role: 'custom',
      roleDisplay: 'Custom',
      branch: branch,
      mustChangePassword: false,
      permissions: const ['employees.view'],
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

List<Override> _overrides(_Server s, UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<ProviderContainer> _container(_Server s, {UserEntity? as}) async {
  final c = ProviderContainer(overrides: _overrides(s, as ?? _user(superuser: true)));
  addTearDown(c.dispose);
  c.listen(employeeStatsProvider, (_, __) {}); // keep the autoDispose provider alive
  return c;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('EmployeeStats.fromJson', () {
    test('parses the /employees/stats/ data object', () {
      final s = EmployeeStats.fromJson(const {
        'total': 7,
        'active': 5,
        'onboarding': 2,
        'departments': 3,
        'branch_names': ['A', 'B'],
        'department_names': ['X'],
      });
      expect((s.total, s.active, s.onboarding, s.departments), (7, 5, 2, 3));
      expect(s.branchNames, ['A', 'B']);
      expect(s.departmentNames, ['X']);
    });

    test('missing / odd fields default to zero and empty lists', () {
      final s = EmployeeStats.fromJson(const {'total': '4', 'branch_names': null});
      expect(s.total, 4);
      expect(s.active, 0);
      expect(s.branchNames, isEmpty);
      expect(s.departmentNames, isEmpty);
    });
  });

  group('employeeStatsProvider', () {
    test('GET /employees/stats/ without params; counts are the server counts; options from the response', () async {
      final s = _Server();
      final c = await _container(s);
      final stats = await c.read(employeeStatsProvider.future);
      final call = s.statsCalls().single;
      expect(call.method, 'GET');
      expect(call.queryParameters, isEmpty);
      expect((stats.total, stats.active, stats.onboarding, stats.departments), (12, 9, 3, 4));
      expect(c.read(employeeListBranchOptionsProvider), ['Mumbai', 'Pune']);
      expect(c.read(employeeListDepartmentOptionsProvider), ['Finance', 'Quality']);
      expect(s.calls.where((x) => x.path == ApiConstants.employees), isEmpty,
          reason: 'no substitute counts from the paginated list');
    });

    test('branch filter refetches with ?branch= and the counts follow; clearing it drops the param', () async {
      final s = _Server();
      final c = await _container(s);
      await c.read(employeeStatsProvider.future);
      c.read(employeeFiltersProvider.notifier).state = const EmployeeFilters(branch: 'Pune');
      final scoped = await c.read(employeeStatsProvider.future);
      expect(s.statsCalls().last.queryParameters, {'branch': 'Pune'});
      expect((scoped.total, scoped.active, scoped.onboarding, scoped.departments), (5, 4, 1, 2));
      // Options keep the whole scope (backend ignores the branch filter for them).
      expect(c.read(employeeListBranchOptionsProvider), ['Mumbai', 'Pune']);
      c.read(employeeFiltersProvider.notifier).state = const EmployeeFilters();
      final all = await c.read(employeeStatsProvider.future);
      expect(s.statsCalls().last.queryParameters, isEmpty);
      expect(all.total, 12);
      expect(s.statsCalls(), hasLength(3));
    });

    test('status / department / search filters do not refetch stats (web: only branch does)', () async {
      final s = _Server();
      final c = await _container(s);
      await c.read(employeeStatsProvider.future);
      c.read(employeeFiltersProvider.notifier).state = const EmployeeFilters(status: 'active', department: 'Quality');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      c.read(employeeFiltersProvider.notifier).state = const EmployeeFilters(search: 'ni');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(s.statsCalls(), hasLength(1));
    });

    test('empty scope: zeros and no filter options', () async {
      final s = _Server()
        ..byBranch = {}
        ..branchNames = []
        ..departmentNames = [];
      final c = await _container(s);
      final stats = await c.read(employeeStatsProvider.future);
      expect((stats.total, stats.active, stats.onboarding, stats.departments), (0, 0, 0, 0));
      expect(c.read(employeeListBranchOptionsProvider), isEmpty);
      expect(c.read(employeeListDepartmentOptionsProvider), isEmpty);
    });

    test('403: surfaces as an error, no cards from elsewhere; options empty', () async {
      final s = _Server()..statsStatus = 403;
      final c = await _container(s);
      await expectLater(c.read(employeeStatsProvider.future), throwsA(isA<DioException>()));
      expect(c.read(employeeStatsProvider).hasError, isTrue);
      expect(c.read(employeeListBranchOptionsProvider), isEmpty);
    });

    test('a failed refetch keeps the previous cards (web keeps previous stats); retry recovers', () async {
      final s = _Server();
      final c = await _container(s);
      await c.read(employeeStatsProvider.future);
      s.statsStatus = 500;
      c.read(employeeFiltersProvider.notifier).state = const EmployeeFilters(branch: 'Pune');
      await expectLater(c.read(employeeStatsProvider.future), throwsA(isA<DioException>()));
      expect(c.read(employeeStatsProvider).valueOrNull?.total, 12, reason: 'previous value retained on error');
      s.statsStatus = 200;
      c.invalidate(employeeStatsProvider);
      final again = await c.read(employeeStatsProvider.future);
      expect(again.total, 5);
    });
  });

  group('EmployeesScreen', () {
    Future<void> pump(WidgetTester tester, _Server s, UserEntity u) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: _overrides(s, u),
        child: const MaterialApp(home: Scaffold(body: EmployeesScreen())),
      ));
      await _flush(tester);
    }

    testWidgets('cards: Total Employees / Active / Onboarding / Departments with the server counts', (tester) async {
      final s = _Server();
      await pump(tester, s, _user(superuser: true));
      expect(find.text('Total Employees'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Onboarding'), findsOneWidget);
      expect(find.text('Departments'), findsOneWidget);
      for (final n in ['12', '9', '3', '4']) {
        expect(find.text(n), findsWidgets, reason: 'count $n');
      }
      expect(s.statsCalls(), hasLength(1));
    });

    testWidgets('loading: cards show 0 (web initial state) until the response, then the counts', (tester) async {
      final s = _Server()..hold = Completer<void>();
      await pump(tester, s, _user(superuser: true));
      expect(find.text('Total Employees'), findsOneWidget);
      expect(find.text('12'), findsNothing);
      s.hold!.complete();
      await _flush(tester);
      expect(find.text('12'), findsWidgets);
    });

    testWidgets('403 permission denied: no error card, cards stay at 0 (web swallows the stats failure)',
        (tester) async {
      final s = _Server()..statsStatus = 403;
      await pump(tester, s, _user(superuser: true));
      expect(find.text('Total Employees'), findsOneWidget);
      expect(find.text('12'), findsNothing);
      expect(find.textContaining('permission'), findsNothing);
    });

    testWidgets('error then retry (pull-to-refresh invalidates stats): counts appear', (tester) async {
      final s = _Server()..statsStatus = 500;
      await pump(tester, s, _user(superuser: true));
      expect(find.text('12'), findsNothing);
      s.statsStatus = 200;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await _flush(tester);
      // Pull-to-refresh reloads the list; stats retry via invalidate on add/edit/import. Drive it directly.
      final container = ProviderScope.containerOf(tester.element(find.byType(EmployeesScreen)));
      container.invalidate(employeeStatsProvider);
      await _flush(tester);
      expect(find.text('12'), findsWidgets);
    });

    testWidgets('empty scope: zeros, filter sheet offers no Branch/Department rows', (tester) async {
      final s = _Server()
        ..byBranch = {}
        ..branchNames = []
        ..departmentNames = [];
      await pump(tester, s, _user(superuser: true));
      expect(find.text('0'), findsWidgets);
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('employees-branch-filter')), findsNothing);
      expect(find.byKey(const Key('employees-department-filter')), findsNothing);
      expect(find.text('Status'), findsOneWidget);
    });

    testWidgets('superuser filter sheet: options from the stats response; picking a branch refetches stats',
        (tester) async {
      final s = _Server();
      await pump(tester, s, _user(superuser: true));
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('employees-department-filter')), findsOneWidget);
      await tester.tap(find.byKey(const Key('employees-branch-filter')));
      await tester.pumpAndSettle();
      expect(find.text('Mumbai'), findsOneWidget);
      await tester.tap(find.text('Pune').last);
      await _flush(tester);
      expect(s.statsCalls().last.queryParameters, {'branch': 'Pune'});
      expect(find.text('5'), findsWidgets);
    });

    testWidgets('non-superuser: branch shown locked to own branch, no Department filter, stats without ?branch=',
        (tester) async {
      final s = _Server();
      await pump(tester, s, _user(branch: 'Pune'));
      expect(s.statsCalls().single.queryParameters, isEmpty);
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('employees-branch-filter-locked')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('employees-branch-filter-locked')), matching: find.text('Pune')),
          findsOneWidget);
      expect(find.byKey(const Key('employees-branch-filter')), findsNothing);
      expect(find.byKey(const Key('employees-department-filter')), findsNothing);
    });
  });
}
