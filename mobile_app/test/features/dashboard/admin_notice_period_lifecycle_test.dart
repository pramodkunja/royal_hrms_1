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
import 'package:mobile_app/features/dashboard/data/models/admin_dashboard_models.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/admin_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/dashboard_section.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/hr_notice_period_row.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';
import 'package:mobile_app/features/separation/presentation/notice_period.dart' show debugNoticeDateOffset;

// Task 11: Admin Dashboard → Employee Lifecycle → Notice Period tab — web
// components/dashboard/EmployeeLifecycleTabs.tsx + NoticePeriodRow.tsx over
// GET /dashboard/system-admin/employee-lifecycle/ (SystemAdminEmployeeLifecycleView,
// settings.edit; people.py _notice_period_data(None): company-wide, approved
// separations with last working day ≥ today, active employees, ordered by
// last working day then name). Synthetic data; a stand-in server; read-only.

Map<String, dynamic> noticeEmp(
  String id,
  String name, {
  Object? approvedAt = '2026-10-20T18:45:00+05:30',
  Object? lastDay = '2026-11-20',
  Object? days = 15,
  Object? status = 'serving',
  String department = 'QA',
  String branch = 'North',
}) =>
    {
      'employee_id': id,
      'full_name': name,
      'department': department,
      'branch': branch,
      'request_id': 'req-$id',
      'approved_at': approvedAt,
      'last_working_day': lastDay,
      'days_remaining': days,
      'notice_status': status,
    };

Map<String, dynamic> lifecycle(List<Map<String, dynamic>> notice) => {
      'new_joiners': {
        'count': 1,
        'employees': [
          {
            'employee_id': 'EMP-100',
            'full_name': 'Test Joiner',
            'department': 'Ops',
            'branch': 'North',
            'date_of_joining': '2026-10-01',
          }
        ],
      },
      'notice_period': {'count': notice.length, 'employees': notice},
      'work_anniversaries': {
        'count': 1,
        'employees': [
          {
            'employee_id': 'EMP-200',
            'full_name': 'Test Veteran',
            'department': 'Finance',
            'branch': 'South',
            'date_of_joining': '2020-11-03',
            'years': 6,
          }
        ],
      },
    };

final defaultNotice = [
  // server order: last working day, then name — deliberately not alphabetical
  noticeEmp('EMP-7', 'Zara Leaver', lastDay: '2026-11-12', days: 3, branch: 'South'),
  noticeEmp('EMP-3', 'Amit Leaver', lastDay: '2026-11-20', days: 11, department: 'Sales'),
  noticeEmp('EMP-9', 'Mona Leaver', approvedAt: null, lastDay: '2026-11-09', days: 0, status: 'completed'),
];

class Server implements HttpClientAdapter {
  Server([List<Map<String, dynamic>>? notice]) : body = lifecycle(notice ?? defaultNotice);
  Map<String, dynamic> body;
  int failLifecycle = 0; // the next N lifecycle requests answer 500
  Completer<void>? hold;
  final requests = <RequestOptions>[];

  int count(String path) => requests.where((r) => r.path == path).length;

  ResponseBody _json(Object b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    requests.add(o);
    if (o.path == ApiConstants.dashboardSystemAdminEmployeeLifecycle) {
      final gate = hold;
      if (gate != null) await gate.future;
      if (failLifecycle > 0) {
        failLifecycle--;
        return _json({'status': 'error', 'message': 'An unexpected error occurred. Please try again later.', 'data': {}}, 500);
      }
      return _json({'status': 'success', 'message': 'Employee lifecycle retrieved.', 'data': body});
    }
    return _json({'status': 'success', 'data': {}});
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

UserEntity user(List<String> perms, {bool superuser = false, bool manager = false}) => UserEntity(
      id: 'a1',
      email: 'admin@example.test',
      fullName: 'Test Admin',
      role: 'system_admin',
      roleDisplay: 'Admin',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      canManageTeam: manager,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final superAdmin = user(const [], superuser: true);
final settingsAdmin = user(const ['settings.view', 'settings.edit', 'employees.view']);
final hrOnly = user(const ['employees.view']);
final employee = user(const []);

late Server server;
String? openedPath;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pumpDashboard(WidgetTester tester, {Server? with_, UserEntity? as, bool settle = true}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  openedPath = null;
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? superAdmin),
    child: MaterialApp.router(
      routerConfig: GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Consumer(builder: (context, ref, _) {
            ref.watch(authStateProvider);
            return const Scaffold(body: HomeScreen());
          }),
        ),
        GoRoute(
          path: '/dashboard/employees/:employeeId',
          builder: (_, s) {
            openedPath = s.uri.path;
            return Scaffold(body: Text('Employee ${s.pathParameters['employeeId']}'));
          },
        ),
      ]),
    ),
  ));
  if (settle) await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));
Finder rowOf(String name) => find.ancestor(of: find.text(name), matching: find.byType(HrNoticePeriodRow));
String textIn(WidgetTester tester, String name, String key) =>
    tester.widget<Text>(find.descendant(of: rowOf(name), matching: find.byKey(Key(key)))).data!;

Future<void> openNoticeTab(WidgetTester tester) async {
  final tab = find.text('Notice Period').first;
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  // Fix the viewer in India (+05:30) so dates don't depend on the machine.
  setUp(() => debugNoticeDateOffset = (_) => const Duration(hours: 5, minutes: 30));
  tearDown(() => debugNoticeDateOffset = null);

  group('parsing (people.py _notice_period_data)', () {
    test('notice fields are kept exactly as the server sent them', () {
      final e = AdminLifecycleEmployee.fromJson(noticeEmp('EMP-7', 'Test Leaver', days: 0, status: 'completed'));
      expect([e.employeeId, e.fullName, e.department, e.branch, e.requestId, e.approvedAt, e.lastWorkingDay, e.daysRemaining, e.noticeStatus], [
        'EMP-7', 'Test Leaver', 'QA', 'North', 'req-EMP-7', '2026-10-20T18:45:00+05:30', '2026-11-20', 0, 'completed', //
      ]);
    });

    test('null, blank and wrong-typed notice values read as missing', () {
      final e = AdminLifecycleEmployee.fromJson(
          noticeEmp('EMP-8', 'Test Odd', approvedAt: '  ', lastDay: 20261120, days: '15', status: 42));
      expect([e.approvedAt, e.lastWorkingDay, e.daysRemaining, e.noticeStatus], [null, null, null, null]);
      expect(AdminLifecycleEmployee.fromJson(noticeEmp('a', 'b', days: -1)).daysRemaining, isNull);
      expect(AdminLifecycleEmployee.fromJson(noticeEmp('a', 'b', days: 1.5)).daysRemaining, isNull);
      expect(AdminLifecycleEmployee.fromJson(noticeEmp('a', 'b', days: 4.0)).daysRemaining, 4);
    });

    test('groups keep the server order and count; other tabs parse as before', () {
      final l = AdminEmployeeLifecycle.fromJson(lifecycle(defaultNotice));
      expect(l.noticePeriod.count, 3);
      expect(l.noticePeriod.employees.map((e) => e.fullName), ['Zara Leaver', 'Amit Leaver', 'Mona Leaver']);
      final joiner = l.newJoiners.employees.single;
      expect([joiner.dateOfJoining, joiner.approvedAt, joiner.lastWorkingDay, joiner.daysRemaining], ['2026-10-01', null, null, null]);
      expect(l.workAnniversaries.employees.single.years, 6);
      expect(AdminEmployeeLifecycle.fromJson(const {}).noticePeriod.employees, isEmpty);
    });
  });

  group('who sees it', () {
    test('admin dashboard (and so this tab) is for superusers and settings.edit holders only', () {
      expect(resolveDashboardCategory(superAdmin), 'admin');
      expect(resolveDashboardCategory(settingsAdmin), 'admin');
      expect(resolveDashboardCategory(hrOnly), 'hr');
      expect(resolveDashboardCategory(employee), 'employee');
      expect(resolveDashboardCategory(user(const [], manager: true)), 'manager');
    });

    testWidgets('a settings.edit admin gets the tab', (tester) async {
      await pumpDashboard(tester, as: settingsAdmin);
      expect(find.byType(AdminDashboardView), findsOneWidget);
      await openNoticeTab(tester);
      expect(rowOf('Zara Leaver'), findsOneWidget);
    });

    testWidgets('HR and employees never call the system-admin endpoint', (tester) async {
      for (final u in [hrOnly, employee]) {
        await pumpDashboard(tester, as: u);
        expect(find.byType(AdminDashboardView), findsNothing);
        expect(server.count(ApiConstants.dashboardSystemAdminEmployeeLifecycle), 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
    });
  });

  group('Notice Period tab (web NoticePeriodRow)', () {
    testWidgets('each row shows id · department · branch, approval date, last day and countdown', (tester) async {
      await pumpDashboard(tester);
      await openNoticeTab(tester);
      expect(textIn(tester, 'Amit Leaver', 'notice-row-meta'), 'EMP-3 · Sales · North');
      expect(textIn(tester, 'Amit Leaver', 'notice-row-approved'), 'Approved 20 Oct 2026');
      expect(textIn(tester, 'Amit Leaver', 'notice-row-last-day'), 'Last day: 20 Nov 2026');
      expect(textIn(tester, 'Amit Leaver', 'notice-row-remaining'), '11 days remaining');
      expect(textIn(tester, 'Zara Leaver', 'notice-row-meta'), 'EMP-7 · QA · South');
      expect(textIn(tester, 'Zara Leaver', 'notice-row-remaining'), '3 days remaining');
      // missing approval → "—"; completed → web label
      expect(textIn(tester, 'Mona Leaver', 'notice-row-approved'), 'Approved —');
      expect(textIn(tester, 'Mona Leaver', 'notice-row-remaining'), 'Notice completed');
    });

    testWidgets('company-wide: no branch filter is sent and every branch is listed', (tester) async {
      await pumpDashboard(tester);
      final req = server.requests.singleWhere((r) => r.path == ApiConstants.dashboardSystemAdminEmployeeLifecycle);
      expect(req.method, 'GET');
      expect(req.queryParameters, isEmpty);
      await openNoticeTab(tester);
      expect(find.byType(HrNoticePeriodRow), findsNWidgets(3));
    });

    testWidgets('rows keep the server order (last working day, then name)', (tester) async {
      await pumpDashboard(tester);
      await openNoticeTab(tester);
      final ys = ['Zara Leaver', 'Amit Leaver', 'Mona Leaver'].map((n) => tester.getTopLeft(rowOf(n)).dy).toList();
      expect(ys, [...ys]..sort());
    });

    testWidgets('the tab badge shows the server count', (tester) async {
      await pumpDashboard(tester);
      final tab = find.ancestor(of: find.text('Notice Period').first, matching: find.byType(LifecycleTabButton));
      expect(find.descendant(of: tab, matching: find.text('3')), findsOneWidget);
    });

    testWidgets('no one serving notice → "No records"', (tester) async {
      await pumpDashboard(tester, with_: Server(const []));
      await openNoticeTab(tester);
      expect(find.byType(HrNoticePeriodRow), findsNothing);
      expect(find.text('No records'), findsOneWidget);
    });

    testWidgets('tapping a row opens that employee', (tester) async {
      await pumpDashboard(tester);
      await openNoticeTab(tester);
      await tester.tap(rowOf('Amit Leaver'));
      await tester.pumpAndSettle();
      expect(openedPath, '/dashboard/employees/EMP-3');
      expect(find.text('Employee EMP-3'), findsOneWidget);
    });

    testWidgets('a row without an employee id is not tappable', (tester) async {
      await pumpDashboard(tester, with_: Server([noticeEmp('', 'Ghost Leaver')]));
      await openNoticeTab(tester);
      await tester.tap(rowOf('Ghost Leaver'));
      await tester.pumpAndSettle();
      expect(openedPath, isNull);
      expect(textIn(tester, 'Ghost Leaver', 'notice-row-meta'), 'QA · North');
    });
  });

  group('loading, error and retry', () {
    testWidgets('loading shows the card skeleton until the server answers', (tester) async {
      final s = Server()..hold = Completer();
      await pumpDashboard(tester, with_: s, settle: false);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final card = find.ancestor(of: find.text('Employee Lifecycle'), matching: find.byType(SectionCard));
      // SectionMessage('Loading…') renders the shared shimmer skeleton.
      final loading = find.descendant(of: card, matching: find.byType(SectionMessage));
      expect(loading, findsOneWidget);
      expect(tester.widget<SectionMessage>(loading).label, 'Loading…');
      expect(find.byType(HrNoticePeriodRow), findsNothing);
      s.hold!.complete();
      await tester.pumpAndSettle();
      await openNoticeTab(tester);
      expect(rowOf('Zara Leaver'), findsOneWidget);
    });

    testWidgets('a server error shows Retry; retry reloads only this card', (tester) async {
      final s = Server()..failLifecycle = 1;
      await pumpDashboard(tester, with_: s);
      expect(find.text('Retry'), findsWidgets);
      final otherBefore = s.requests.where((r) => r.path != ApiConstants.dashboardSystemAdminEmployeeLifecycle).length;
      final card = find.ancestor(of: find.text('Employee Lifecycle'), matching: find.byType(SectionCard));
      final retry = find.descendant(of: card, matching: find.text('Retry'));
      await tester.ensureVisible(retry.first);
      await tester.tap(retry.first);
      await tester.pumpAndSettle();
      expect(s.count(ApiConstants.dashboardSystemAdminEmployeeLifecycle), 2);
      expect(s.requests.where((r) => r.path != ApiConstants.dashboardSystemAdminEmployeeLifecycle).length, otherBefore,
          reason: 'no full-dashboard reload');
      await openNoticeTab(tester);
      expect(rowOf('Amit Leaver'), findsOneWidget);
    });

    testWidgets('switching tabs makes no new requests', (tester) async {
      await pumpDashboard(tester);
      final before = server.requests.length;
      await openNoticeTab(tester);
      await tester.tap(find.text('Anniversaries').first);
      await tester.pumpAndSettle();
      await openNoticeTab(tester);
      expect(server.requests.length, before);
    });
  });

  group('regression: other lifecycle tabs unchanged', () {
    testWidgets('New Joiners and Anniversaries keep their existing rows', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Test Joiner'), findsOneWidget);
      expect(find.text('— · Ops'), findsOneWidget);
      expect(find.text('2026-10-01'), findsOneWidget);
      expect(find.byType(HrNoticePeriodRow), findsNothing);
      await tester.tap(find.text('Anniversaries').first);
      await tester.pumpAndSettle();
      expect(find.text('Test Veteran'), findsOneWidget);
      expect(find.text('6 yrs'), findsOneWidget);
      expect(find.byType(HrNoticePeriodRow), findsNothing);
    });

    testWidgets('an empty Joiners tab still reads "No data"', (tester) async {
      final s = Server()..body = {...lifecycle(defaultNotice), 'new_joiners': {'count': 0, 'employees': <Object>[]}};
      await pumpDashboard(tester, with_: s);
      expect(find.text('No data'), findsWidgets);
    });
  });
}
