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
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/data/models/hr_dashboard_models.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/employee_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/hr_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/hr_notice_period_row.dart';
import 'package:mobile_app/features/separation/presentation/notice_period.dart' show debugNoticeDateOffset;

// Task 7: HR dashboard "Employee Lifecycle" → Notice Period tab — web
// components/dashboard/hr/HrEmployeeLifecycleTabs.tsx + NoticePeriodRow.tsx
// over GET /dashboard/hr/employee-lifecycle/ (people.py _notice_period_data:
// approved_at ISO datetime | null, last_working_day YYYY-MM-DD,
// days_remaining int ≥ 0, notice_status "serving" | "completed"). Dates via
// web formatNoticeDate ("5 Nov 2026", "—"); countdown via
// noticeRemainingLabel. Synthetic data; a stand-in server; read-only.

Map<String, dynamic> noticeEmp(
  String id,
  String name, {
  Object? approvedAt = '2026-10-20T18:45:00+05:30',
  Object? lastDay = '2026-11-20',
  Object? days = 15,
  Object? status = 'serving',
  String department = 'QA',
  String branch = 'Test Branch',
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
            'department': 'QA',
            'designation': 'Tester',
            'date_of_joining': '2026-10-01',
          }
        ],
      },
      'notice_period': {'count': notice.length, 'employees': notice},
      'work_anniversaries': {'count': 0, 'employees': []},
    };

class Backend implements HttpClientAdapter {
  Backend(this.body);
  Map<String, dynamic> body;
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    requests.add('${o.method} ${o.path}');
    final data = o.path == ApiConstants.dashboardHrEmployeeLifecycle ? body : <String, dynamic>{};
    return ResponseBody.fromString(jsonEncode({'status': 'success', 'message': 'ok', 'data': data}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
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

class _Auth extends AuthNotifier {
  _Auth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

UserEntity user(String role, List<String> perms) => UserEntity(
      id: 'u1',
      email: 'user@example.test',
      fullName: 'Test User',
      role: role,
      roleDisplay: role,
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final hr = user('hr', ['employees.view']);

late Backend backend;

Future<void> pumpHr(WidgetTester tester, List<Map<String, dynamic>> notice, {UserEntity? as}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  backend = Backend(lifecycle(notice));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? hr)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = backend),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: const MaterialApp(home: Scaffold(body: HomeScreen())),
  ));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Future<void> openNoticeTab(WidgetTester tester) async {
  final tab = find.text('Notice Period').first;
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await settle(tester);
}

Finder rowOf(String name) => find.ancestor(of: find.text(name), matching: find.byType(HrNoticePeriodRow));
String textIn(WidgetTester tester, String name, String key) =>
    tester.widget<Text>(find.descendant(of: rowOf(name), matching: find.byKey(Key(key)))).data!;

HrLifecycleEmployee parse(Map<String, dynamic> json) => HrLifecycleEmployee.fromJson(json);

Future<void> pumpRow(WidgetTester tester, Map<String, dynamic> json) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: HrNoticePeriodRow(employee: parse(json)))));
}

String rowText(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  // Timestamps are shown on the viewer's calendar day; fix the viewer in
  // India (+05:30) so results don't depend on the machine's time zone.
  setUp(() => debugNoticeDateOffset = (_) => const Duration(hours: 5, minutes: 30));
  tearDown(() => debugNoticeDateOffset = null);

  group('parsing (people.py _notice_period_data)', () {
    test('12. all notice fields kept as the server sent them', () {
      final e = parse(noticeEmp('EMP-7', 'Test Leaver', days: 0, status: 'completed'));
      expect([
        e.employeeId,
        e.branch,
        e.requestId,
        e.approvedAt,
        e.lastWorkingDay,
        e.daysRemaining,
        e.noticeStatus
      ], [
        'EMP-7', 'Test Branch', 'req-EMP-7', '2026-10-20T18:45:00+05:30', '2026-11-20', 0, 'completed', //
      ]);
    });

    test('6/12. null, empty and wrong-typed values read as missing; other tabs unaffected', () {
      final e =
          parse(noticeEmp('EMP-8', 'Test Odd', approvedAt: '', lastDay: 20261120, days: '15', status: 42, branch: ''));
      expect(
          [e.approvedAt, e.lastWorkingDay, e.daysRemaining, e.noticeStatus, e.branch], [null, null, null, null, null]);
      expect(parse(noticeEmp('a', 'b', days: -3)).daysRemaining, isNull);
      expect(parse(noticeEmp('a', 'b', days: 2.5)).daysRemaining, isNull);
      expect(parse(noticeEmp('a', 'b', days: 4.0)).daysRemaining, 4);
      final joiner = HrEmployeeLifecycle.fromJson(lifecycle([])).newJoiners.employees.single;
      expect([joiner.fullName, joiner.designation, joiner.dateOfJoining], ['Test Joiner', 'Tester', '2026-10-01']);
      expect([joiner.approvedAt, joiner.lastWorkingDay, joiner.daysRemaining, joiner.noticeStatus],
          [null, null, null, null]);
    });
  });

  group('notice row (web NoticePeriodRow)', () {
    testWidgets('1/8/9. all four fields: Approved date, red Last day, countdown', (tester) async {
      await pumpRow(tester, noticeEmp('EMP-7', 'Test Leaver'));
      expect(rowText(tester, 'notice-row-meta'), 'EMP-7 · QA · Test Branch');
      expect(rowText(tester, 'notice-row-approved'), 'Approved 20 Oct 2026');
      expect(rowText(tester, 'notice-row-last-day'), 'Last day: 20 Nov 2026');
      expect(tester.widget<Text>(find.byKey(const Key('notice-row-last-day'))).style?.color, AppColors.error);
      expect(rowText(tester, 'notice-row-remaining'), '15 days remaining');
      expect(tester.widget<Text>(find.byKey(const Key('notice-row-remaining'))).style?.color, AppColors.textSecondary);
    });

    testWidgets('8. status labels: one day, last day (0), completed', (tester) async {
      await pumpRow(tester, noticeEmp('a', 'Test One', days: 1));
      expect(rowText(tester, 'notice-row-remaining'), '1 day remaining');
      await pumpRow(tester, noticeEmp('a', 'Test Zero', days: 0));
      expect(rowText(tester, 'notice-row-remaining'), '0 days remaining');
      await pumpRow(tester, noticeEmp('a', 'Test Done', days: 0, status: 'completed'));
      expect(rowText(tester, 'notice-row-remaining'), 'Notice completed');
    });

    testWidgets('2. missing approval date: "Approved —"', (tester) async {
      await pumpRow(tester, noticeEmp('a', 'Test', approvedAt: null));
      expect(rowText(tester, 'notice-row-approved'), 'Approved —');
    });

    testWidgets('3. missing last working day: "Last day: —"', (tester) async {
      await pumpRow(tester, noticeEmp('a', 'Test', lastDay: null));
      expect(rowText(tester, 'notice-row-last-day'), 'Last day: —');
    });

    testWidgets('4. missing days remaining: "—" while serving, "Notice completed" when completed', (tester) async {
      await pumpRow(tester, noticeEmp('a', 'Test', days: null));
      expect(rowText(tester, 'notice-row-remaining'), '—');
      await pumpRow(tester, noticeEmp('a', 'Test', days: null, status: 'completed'));
      expect(rowText(tester, 'notice-row-remaining'), 'Notice completed');
    });

    testWidgets('5/7. missing or unknown status: the server count is shown, never a local guess', (tester) async {
      await pumpRow(tester, noticeEmp('a', 'Test', status: null, days: 9));
      expect(rowText(tester, 'notice-row-remaining'), '9 days remaining');
      await pumpRow(tester, noticeEmp('a', 'Test', status: 'on_hold', days: 3));
      expect(rowText(tester, 'notice-row-remaining'), '3 days remaining');
      await pumpRow(tester, noticeEmp('a', 'Test', status: 'on_hold', days: null));
      expect(rowText(tester, 'notice-row-remaining'), '—');
    });

    testWidgets('6. invalid date strings show "—"; meta falls back to "—" when empty', (tester) async {
      await pumpRow(tester, {
        ...noticeEmp('', 'Test', approvedAt: 'not a date', lastDay: '20/11/2026', department: '', branch: ''),
      });
      expect(rowText(tester, 'notice-row-approved'), 'Approved —');
      expect(rowText(tester, 'notice-row-last-day'), 'Last day: —');
      expect(rowText(tester, 'notice-row-meta'), '—');
    });
  });

  group('HR dashboard lifecycle card', () {
    testWidgets('1/10. Notice Period tab lists every row with its details; other tabs unchanged', (tester) async {
      await pumpHr(tester, [
        noticeEmp('EMP-7', 'Test Leaver'),
        noticeEmp('EMP-8', 'Test Finisher', approvedAt: null, lastDay: '2026-11-05', days: 0, status: 'serving'),
      ]);
      expect(find.byType(HrDashboardView), findsOneWidget);
      // New Joiners (default tab) keeps its existing row.
      expect(find.text('Test Joiner'), findsOneWidget);
      expect(find.text('QA · Tester'), findsOneWidget);
      expect(find.byType(HrNoticePeriodRow), findsNothing);
      await openNoticeTab(tester);
      expect(find.byType(HrNoticePeriodRow), findsNWidgets(2));
      expect(textIn(tester, 'Test Leaver', 'notice-row-approved'), 'Approved 20 Oct 2026');
      expect(textIn(tester, 'Test Leaver', 'notice-row-last-day'), 'Last day: 20 Nov 2026');
      expect(textIn(tester, 'Test Leaver', 'notice-row-remaining'), '15 days remaining');
      expect(textIn(tester, 'Test Finisher', 'notice-row-approved'), 'Approved —');
      expect(textIn(tester, 'Test Finisher', 'notice-row-remaining'), '0 days remaining');
      // Read-only: one lifecycle request, GETs only.
      expect(backend.requests.where((r) => r.endsWith(ApiConstants.dashboardHrEmployeeLifecycle)), hasLength(1));
      expect(backend.requests.where((r) => !r.startsWith('GET ')), isEmpty);
      await unmount(tester);
    });

    testWidgets('empty Notice Period tab: web’s "No employees currently serving notice"', (tester) async {
      await pumpHr(tester, []);
      await openNoticeTab(tester);
      expect(find.text('No employees currently serving notice'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('11. visibility unchanged: an employee gets no HR lifecycle card or request', (tester) async {
      await pumpHr(tester, [noticeEmp('EMP-7', 'Test Leaver')], as: user('employee', ['leave.view']));
      expect(find.byType(EmployeeDashboardView), findsOneWidget);
      expect(find.byType(HrNoticePeriodRow), findsNothing);
      expect(backend.requests.where((r) => r.contains('/dashboard/hr/')), isEmpty);
      await unmount(tester);
    });
  });
}
