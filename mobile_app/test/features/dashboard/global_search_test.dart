import 'dart:async';
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
import 'package:mobile_app/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:mobile_app/features/dashboard/presentation/search/global_search_controller.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/app_top_bar.dart';

// Task 8: Global Search — web components/dashboard/GlobalSearch.tsx (header
// "Search anything…" in DashboardShell). Employees: GET /employees/
// ?search=<trimmed>&page_size=5 after 300 ms, only with employees.view;
// failures show no employees. Pages: the user's own sidebar items whose label
// contains the query, first five. EMPLOYEES group first, then PAGES; picking
// one clears the search and opens /dashboard/employees/<id> or the page.
// The real DashboardShell inside a small router; a stand-in server;
// synthetic people only.

Map<String, dynamic> emp(String code, String name, {String dept = 'QA', String designation = 'Tester'}) => {
      'id': code, // the backend's `id` is the employee code
      'uuid': 'uuid-$code',
      'employee_id': code,
      'full_name': name,
      'first_name': name.split(' ').first,
      'last_name': name.split(' ').last,
      'email': '${code.toLowerCase()}@example.test',
      'department': dept,
      'designation': designation,
      'status': 'active',
    };

class SearchServer implements HttpClientAdapter {
  /// trimmed query → results.
  final results = <String, List<Map<String, dynamic>>>{
    'ann': [emp('EMP-7', 'Test Ann'), emp('EMP-9', 'Test Annika', designation: '')],
    'bob': [emp('EMP-3', 'Test Bob')],
    'cat': [emp('EMP-4', 'Test Cat')],
    'leave': [],
    'zzz': [],
  };
  final searches = <Map<String, dynamic>>[];
  final holds = <String, Completer<void>>{};
  int? failWith;
  bool dropNext = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == ApiConstants.employees && o.method == 'GET') {
      searches.add(Map.of(o.queryParameters));
      final q = '${o.queryParameters['search'] ?? ''}';
      final gate = holds[q];
      if (gate != null) await gate.future;
      if (dropNext) {
        dropNext = false;
        throw DioException.connectionError(requestOptions: o, reason: 'offline');
      }
      if (failWith != null) {
        return _json({'status': 'error', 'message': 'You do not have permission to perform this action.'}, failWith!);
      }
      final list = results[q] ?? [];
      return _json({
        'status': 'success',
        'message': 'Employees retrieved.',
        'data': {'count': list.length, 'page': 1, 'page_size': 5, 'total_pages': 1, 'results': list},
      }, 200);
    }
    return _json({
      'status': 'success',
      'message': 'ok',
      'data': {'results': [], 'count': 0, 'unread_count': 0}
    }, 200);
  }

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

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

  /// Session over (sign-out or expiry) without touching any server.
  void endSession() => state = const AsyncData(AuthState());
}

UserEntity user(List<String> perms, {String id = 'u1'}) => UserEntity(
      id: id,
      email: 'user@example.test',
      fullName: 'Test User',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final hr = user(['employees.view', 'leave.view']);
final staff = user(['leave.view']);

late SearchServer server;
late ProviderContainer container;

Future<void> pumpShell(WidgetTester tester, {UserEntity? as}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = SearchServer();
  Widget page(String text) => Center(child: Text(text));
  final router = GoRouter(initialLocation: '/dashboard', routes: [
    ShellRoute(
      builder: (_, __, child) => DashboardShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => page('Home')),
        GoRoute(
            path: '/dashboard/employees/:employeeId',
            builder: (_, s) => page('Employee ${s.pathParameters['employeeId']}')),
        GoRoute(path: '/dashboard/:section', builder: (_, s) => page('Section ${s.pathParameters['section']}')),
      ],
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => TestAuth(as ?? hr)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  container = ProviderScope.containerOf(tester.element(find.byType(DashboardShell)));
  await container.read(authStateProvider.future);
  await tester.pumpAndSettle();
}

Future<void> openSearch(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('global-search-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('global-search')), findsOneWidget);
}

final input = find.byKey(const Key('global-search-input'));

/// Types [text] and lets the debounce and request finish.
Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(input, text);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

/// Types [text] and lets the debounce fire, without settling (a held
/// request keeps the spinner running).
Future<void> searchHeld(WidgetTester tester, String text) async {
  await tester.enterText(input, text);
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Visible result labels, top to bottom (group headers included).
List<String> shown(WidgetTester tester) {
  final texts = find.descendant(of: find.byType(ListView), matching: find.byType(Text));
  final items = texts.evaluate().map((e) => (e.widget as Text).data ?? '').toList();
  return items;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules', () {
    test('employee search needs employees.view itself, as web checks it', () {
      expect(canSearchEmployees(hr), isTrue);
      expect(canSearchEmployees(staff), isFalse);
      expect(canSearchEmployees(user(['settings.edit'])), isFalse); // web: includes("employees.view")
      expect(canSearchEmployees(null), isFalse);
    });

    test('6. pages: own sidebar items containing the query, sidebar order, first five', () {
      expect(matchingPages(staff, '  ').map((p) => p.label), isEmpty);
      final my = matchingPages(staff, 'MY');
      expect(my, hasLength(kGlobalSearchPageLimit));
      expect(my.map((p) => p.label), ['My Attendance', 'My Payslips', 'My Assessments', 'My Referrals', 'My Requests']);
      expect(matchingPages(staff, 'employ'), isEmpty); // no employees.view → no Employees page
      expect(matchingPages(hr, 'employ').map((p) => p.path), ['/dashboard/employees']);
    });
  });

  group('search screen', () {
    testWidgets('1/15. the top bar has Search for every signed-in user; the other actions stay', (tester) async {
      await pumpShell(tester, as: staff);
      expect(find.byKey(const Key('global-search-button')), findsOneWidget);
      expect(find.byTooltip('Sign out'), findsOneWidget);
      expect(find.byTooltip('Menu'), findsOneWidget);
      await openSearch(tester);
      expect(find.text('Search anything...'), findsOneWidget);
    });

    testWidgets('15. AppTopBar without a search callback shows no Search button', (tester) async {
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
        home: Scaffold(
          appBar: AppTopBar(
            title: 'T',
            onMenuTap: () {},
            onLogoutTap: () {},
            onThemeToggleTap: () {},
            isDarkMode: false,
            isBlueTheme: false,
          ),
        ),
      )));
      expect(find.byKey(const Key('global-search-button')), findsNothing);
    });

    testWidgets('2/4/5/6. results: request contract, EMPLOYEES then PAGES, rows as web', (tester) async {
      await pumpShell(tester);
      await openSearch(tester);
      await search(tester, '  ann ');
      expect(server.searches, [
        {'page': 1, 'page_size': 5, 'search': 'ann'}
      ]);
      expect(shown(tester), [
        'EMPLOYEES', 'Test Ann', 'EMP-7 · QA · Tester', 'Test Annika', 'EMP-9 · QA', //
        'PAGES', 'Announcements',
      ]);
      await search(tester, 'leave');
      expect(shown(tester), ['PAGES', 'Leave Management']);
    });

    testWidgets('2. empty or blank query: nothing shown, nothing sent; one letter searches', (tester) async {
      await pumpShell(tester);
      await openSearch(tester);
      await search(tester, '   ');
      expect(find.byType(ListView), findsNothing);
      expect(find.byKey(const Key('global-search-empty')), findsNothing);
      expect(server.searches, isEmpty);
      await search(tester, 'a');
      expect(server.searches.single['search'], 'a');
    });

    testWidgets('3. debounce: quick typing sends one request, 300 ms after the last change', (tester) async {
      await pumpShell(tester);
      await openSearch(tester);
      await tester.enterText(input, 'a');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(input, 'an');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(input, 'ann');
      await tester.pump(const Duration(milliseconds: 299));
      expect(server.searches, isEmpty);
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pumpAndSettle();
      expect(server.searches.map((s) => s['search']), ['ann']);
    });

    testWidgets('7. no match anywhere: “No results for “zzz”.”', (tester) async {
      await pumpShell(tester);
      await openSearch(tester);
      await search(tester, 'zzz');
      expect(find.text('No results for “zzz”.'), findsOneWidget);
    });

    testWidgets('8. loading shows “Searching…” until the employees arrive', (tester) async {
      await pumpShell(tester);
      await openSearch(tester);
      server.holds['ann'] = Completer();
      await tester.enterText(input, 'ann');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.byKey(const Key('global-search-loading')), findsOneWidget);
      server.holds['ann']!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-search-loading')), findsNothing);
      expect(find.text('Test Ann'), findsOneWidget);
    });

    testWidgets('9/10. server error, offline or 403: no employees, pages still shown (as web)', (tester) async {
      await pumpShell(tester);
      await openSearch(tester);
      server.failWith = 500;
      await search(tester, 'bob');
      expect(find.text('Test Bob'), findsNothing);
      expect(find.text('No results for “bob”.'), findsOneWidget);
      server.failWith = 403;
      await search(tester, 'employ');
      expect(shown(tester), ['PAGES', 'Employees']);
      server.failWith = null;
      server.dropNext = true;
      await search(tester, 'cat');
      expect(find.text('Test Cat'), findsNothing);
      expect(find.text('No results for “cat”.'), findsOneWidget);
    });

    testWidgets('1/10. without employees.view no request is ever sent; pages still work', (tester) async {
      await pumpShell(tester, as: staff);
      await openSearch(tester);
      await search(tester, 'my');
      expect(server.searches, isEmpty);
      expect(shown(tester).first, 'PAGES');
      expect(find.text('My Attendance'), findsOneWidget);
    });

    testWidgets('11. a slow older search never replaces newer results', (tester) async {
      await pumpShell(tester);
      await openSearch(tester);
      server.holds['ann'] = Completer();
      await searchHeld(tester, 'ann'); // request out, held
      await search(tester, 'bob'); // answered at once
      expect(find.text('Test Bob'), findsOneWidget);
      server.holds['ann']!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Test Bob'), findsOneWidget);
      expect(find.text('Test Ann'), findsNothing);
    });

    testWidgets('11. clearing during a search drops its late answer', (tester) async {
      await pumpShell(tester);
      await openSearch(tester);
      server.holds['ann'] = Completer();
      await searchHeld(tester, 'ann');
      await tester.tap(find.byKey(const Key('global-search-clear')));
      await tester.pumpAndSettle();
      server.holds['ann']!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
      expect((tester.widget<TextField>(input)).controller!.text, '');
    });

    testWidgets('12. the same query is not fetched twice (in flight or already shown)', (tester) async {
      await pumpShell(tester);
      await openSearch(tester);
      server.holds['ann'] = Completer();
      await searchHeld(tester, 'ann');
      await searchHeld(tester, 'ann '); // same trimmed query while the first is running
      expect(server.searches, hasLength(1));
      server.holds['ann']!.complete();
      await tester.pumpAndSettle();
      await search(tester, ' ann'); // already showing
      expect(server.searches, hasLength(1));
      expect(find.text('Test Ann'), findsOneWidget);
    });

    testWidgets('13. an employee opens /dashboard/employees/<code>; search closes and clears', (tester) async {
      await pumpShell(tester);
      await openSearch(tester);
      await search(tester, 'ann');
      await tester.tap(find.text('Test Ann'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-search')), findsNothing);
      expect(find.text('Employee EMP-7'), findsOneWidget);
      await openSearch(tester);
      expect(tester.widget<TextField>(input).controller!.text, '');
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('13. a page result opens its section', (tester) async {
      await pumpShell(tester);
      await openSearch(tester);
      await search(tester, 'leave');
      await tester.tap(find.text('Leave Management'));
      await tester.pumpAndSettle();
      expect(find.text('Section leave'), findsOneWidget);
    });

    testWidgets('14. session end closes the search and its results go with it', (tester) async {
      await pumpShell(tester);
      await openSearch(tester);
      await search(tester, 'ann');
      expect(find.text('Test Ann'), findsOneWidget);
      (container.read(authStateProvider.notifier) as TestAuth).endSession();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-search')), findsNothing);
      expect(find.text('Test Ann'), findsNothing);
    });
  });
}
