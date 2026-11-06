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
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/attendance/data/models/weekly_off_assignment_models.dart';
import 'package:mobile_app/features/attendance/presentation/providers/weekly_off_assignment_providers.dart';
import 'package:mobile_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// Task 13: HR Attendance → Weekly Off Assignment — web
// WeeklyOffAssignmentTab.tsx over GET/POST /attendance/weekly-off-assignments/,
// POST .../bulk/ and the active patterns from GET /attendance/weekly-days/.
// List needs attendance.view; assigning needs attendance.create; branch-
// restricted users are locked to their own branch; the server scopes
// everything again. "Today" is 6 Nov 2026. Stand-in server, synthetic people.

final today = DateTime(2026, 11, 6, 9);

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
Map<String, dynamic> ok(Object data, [String message = 'ok']) =>
    {'status': 'success', 'message': message, 'data': data};

Map<String, dynamic> row(String code, String name,
        {String? patternId, String? patternName, String? from, String branch = 'North Wing'}) =>
    {
      'employee_id': code,
      'employee_name': name,
      'department': 'QA',
      'branch': branch,
      'pattern_id': patternId,
      'pattern_name': patternName,
      'effective_from': from,
      'effective_to': null,
      'status': patternId != null ? 'Assigned' : 'Not Assigned',
    };

class Server implements HttpClientAdapter {
  final lists = <Map<String, dynamic>>[];
  final posts = <({String path, Map<String, dynamic> body})>[];
  final listHolds = <int, Completer<void>>{}; // by list call number
  Completer<void>? hold;
  ({int status, String message})? refuseNext;
  bool failList = false;
  int totalPages = 1;
  List<Map<String, dynamic>> rows = [
    row('EMP-7', 'Test Ann', patternId: 'p1', patternName: 'Sat-Sun Off', from: '2026-10-01'),
    row('EMP-9', 'Test Bob'),
  ];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == ApiConstants.attendanceWeeklyDayPolicies) {
      return _json(ok({
        'count': 2,
        'results': [
          {'id': 'p1', 'name': 'Sat-Sun Off', 'policy_code': 'SS'},
          {'id': 'p2', 'name': 'Sunday Only', 'policy_code': 'SU'},
        ],
      }));
    }
    if (o.path == ApiConstants.attendanceWeeklyOffAssignments && o.method == 'GET') {
      lists.add(Map.of(o.queryParameters));
      final gate = listHolds[lists.length];
      if (gate != null) await gate.future;
      if (failList) return _json({'status': 'error', 'message': 'Permission denied.'}, 403);
      final status = o.queryParameters['status'];
      final shown = rows.where((r) => status == null || (status == 'assigned') == (r['pattern_id'] != null)).toList();
      return _json(ok({
        'count': shown.length,
        'page': o.queryParameters['page'],
        'page_size': 20,
        'total_pages': totalPages,
        'results': shown,
      }));
    }
    if (o.method == 'POST' &&
        (o.path == ApiConstants.attendanceWeeklyOffAssignments ||
            o.path == ApiConstants.attendanceWeeklyOffAssignmentsBulk)) {
      posts.add((path: o.path, body: Map<String, dynamic>.from(o.data as Map)));
      if (hold != null) await hold!.future;
      final r = refuseNext;
      if (r != null) {
        refuseNext = null;
        return _json({'status': 'error', 'message': r.message, 'data': {}}, r.status);
      }
      if (o.path == ApiConstants.attendanceWeeklyOffAssignmentsBulk) {
        return _json(ok({'count': 7}, 'Weekly off pattern assigned to 7 employee(s).'));
      }
      return _json(ok({'employee_id': (o.data as Map)['employee_id']}, 'Weekly off pattern assigned.'), 201);
    }
    if (o.path == ApiConstants.employees) {
      return _json(ok({
        'count': 2,
        'page': 1,
        'total_pages': 1,
        'results': [
          {
            'id': 'EMP-7',
            'employee_id': 'EMP-7',
            'full_name': 'Test Ann',
            'department': 'QA',
            'branch': 'North Wing',
            'is_active': true
          },
          {
            'id': 'EMP-9',
            'employee_id': 'EMP-9',
            'full_name': 'Test Bob',
            'department': 'Ops',
            'branch': 'South Wing',
            'is_active': true
          },
        ],
      }));
    }
    return _json(ok({'results': [], 'count': 0, 'summary_chips': <String, int>{}}));
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

UserEntity user(List<String> perms, {String? branch}) => UserEntity(
      id: 'u1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      branch: branch,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final orgHr = user(['attendance.view', 'attendance.create', 'settings.edit']);
final branchHr = user(['attendance.view', 'attendance.create'], branch: 'North Wing');
final viewer = user(['attendance.view'], branch: 'North Wing');

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      weeklyOffClockProvider.overrideWithValue(() => today),
    ];

Future<void> pump(WidgetTester tester, {UserEntity? as, void Function(Server)? setup, bool open = true}) async {
  // Wide enough for all six attendance tabs to be on screen.
  tester.view.physicalSize = const Size(1600, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? orgHr),
    child: const MaterialApp(home: Scaffold(body: AttendanceScreen())),
  ));
  await tester.pumpAndSettle();
  if (open) {
    await tester.tap(find.text('Weekly Off Assignment'));
    await tester.pumpAndSettle();
  }
}

/// Filters are on screen already; other pickers live in sheets.
Future<void> pick(WidgetTester tester, String key, String option) async {
  if (!key.startsWith('wo-filter-')) await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

bool enabled(WidgetTester tester, String key) =>
    (tester.widget(find.byKey(Key(key))) as ButtonStyleButton).onPressed != null;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules and contract', () {
    test('rows, page and query: pattern fields, status fallback, empty filters dropped, page reset', () {
      final a = WeeklyOffAssignmentRow.fromJson(row('E1', 'A', patternId: 'p1', patternName: 'SS', from: '2026-10-01'));
      expect([a.isAssigned, a.patternId, a.patternName, a.effectiveFrom, a.effectiveTo],
          [true, 'p1', 'SS', '2026-10-01', null]);
      final b = WeeklyOffAssignmentRow.fromJson({'employee_id': 'E2'});
      expect([b.isAssigned, b.status, b.patternName], [false, 'Not Assigned', null]);
      final p = WeeklyOffAssignmentPage.fromJson({'results': null, 'count': '4'});
      expect([p.rows, p.count, p.totalPages], [isEmpty, 4, 1]);
      const q = WeeklyOffQuery(page: 3);
      expect(q.params(), {'page': 3, 'page_size': 20});
      expect(q.copyWith(pattern: 'p2').params(), {'pattern': 'p2', 'page': 1, 'page_size': 20});
      expect(kWeeklyOffStatusOptions.map((o) => o.label), ['All', 'Assigned', 'Not Assigned']);
    });

    test('below the UI: without attendance.create nothing is sent', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(viewer));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final s = c.read(weeklyOffServiceProvider);
      final r = WeeklyOffAssignmentRow.fromJson(row('EMP-9', 'Test Bob'));
      await expectLater(s.assign(r, 'p1', today), throwsA(isA<WeeklyOffAssignDenied>()));
      await expectLater(s.bulkAssign(patternId: 'p1', from: today, branch: 'North Wing', department: ''),
          throwsA(isA<WeeklyOffAssignDenied>()));
      expect(server.posts, isEmpty);
    });
  });

  group('tab and list', () {
    testWidgets('the tab sits before Shift Assignment (web order) and loads nothing until opened', (tester) async {
      await pump(tester, open: false);
      final tabs = tester.widgetList<Tab>(find.byType(Tab)).map((t) => t.text).whereType<String>().toList();
      expect(tabs.indexOf('Weekly Off Assignment'), tabs.indexOf('Shift Assignment') - 1);
      expect(server.lists, isEmpty);
    });

    testWidgets('rows as web: pattern or "—", dates, status; Change / Assign; Bulk Assign', (tester) async {
      await pump(tester);
      expect(server.lists.first, {'page': 1, 'page_size': 20});
      expect(find.text('Sat-Sun Off'), findsWidgets);
      expect(find.descendant(of: find.byKey(const Key('wo-row-EMP-9')), matching: find.text('—')), findsOneWidget);
      expect(find.text('Effective From 2026-10-01 · Effective To -'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Change'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Assign'), findsOneWidget);
      expect(find.byKey(const Key('wo-bulk-open')), findsOneWidget);
    });

    testWidgets('attendance.view only: the list, but no Assign / Bulk Assign', (tester) async {
      await pump(tester, as: viewer);
      expect(find.text('Test Ann'), findsOneWidget);
      expect(find.byKey(const Key('wo-bulk-open')), findsNothing);
      expect(find.byKey(const Key('wo-assign-EMP-7')), findsNothing);
    });

    testWidgets('branch-restricted user: own branch requested, picker locked', (tester) async {
      await pump(tester, as: branchHr);
      expect(server.lists.first['branch'], 'North Wing');
      final picker = tester.widget<DropdownButtonFormField<String>>(find.descendant(
          of: find.byKey(const Key('wo-filter-branch')), matching: find.byType(DropdownButtonFormField<String>)));
      expect(picker.onChanged, isNull);
    });

    testWidgets('filters (branch, pattern, status) are sent, page resets; Next keeps the filters', (tester) async {
      await pump(tester, setup: (s) => s.totalPages = 2);
      await pick(tester, 'wo-filter-branch', 'South Wing');
      await pick(tester, 'wo-filter-pattern', 'Sunday Only');
      await pick(tester, 'wo-filter-status', 'Not Assigned');
      expect(server.lists.last,
          {'branch': 'South Wing', 'pattern': 'p2', 'status': 'unassigned', 'page': 1, 'page_size': 20});
      expect(find.text('Test Bob'), findsOneWidget);
      expect(find.text('Test Ann'), findsNothing);
      await tap(tester, 'wo-next');
      expect(server.lists.last['page'], 2);
      expect(server.lists.last['pattern'], 'p2');
    });

    testWidgets('a slow older page never replaces the newer one', (tester) async {
      await pump(tester, setup: (s) => s.listHolds[1] = Completer());
      expect(find.byKey(const Key('wo-loading')), findsOneWidget);
      server.rows = [row('EMP-9', 'Test Bob')];
      await pick(tester, 'wo-filter-status', 'Not Assigned');
      expect(find.text('Test Bob'), findsOneWidget);
      server.rows = [row('EMP-7', 'Test Ann', patternId: 'p1', patternName: 'Sat-Sun Off')];
      server.listHolds[1]!.complete(); // the first (all-status) request answers late
      await tester.pumpAndSettle();
      expect(find.text('Test Bob'), findsOneWidget);
      expect(find.text('Test Ann'), findsNothing);
    });

    testWidgets('empty, and error with Retry', (tester) async {
      await pump(tester, setup: (s) => s.failList = true);
      expect(find.text('Permission denied.'), findsOneWidget);
      server
        ..failList = false
        ..rows = [];
      await tap(tester, 'wo-retry');
      expect(find.byKey(const Key('wo-empty')), findsOneWidget);
    });
  });

  group('assign one employee', () {
    testWidgets('Change: current pattern pre-selected, today, exact request, message, reload', (tester) async {
      await pump(tester);
      await tap(tester, 'wo-assign-EMP-7');
      expect(find.textContaining('Test Ann (EMP-7) — currently Sat-Sun Off, effective 2026-10-01'), findsOneWidget);
      expect(find.text('2026-11-06'), findsOneWidget);
      expect(enabled(tester, 'wo-assign-submit'), isTrue); // current pattern already selected
      await pick(tester, 'wo-assign-pattern', 'Sunday Only');
      final lists = server.lists.length;
      await tap(tester, 'wo-assign-submit');
      expect(server.posts.single.path, ApiConstants.attendanceWeeklyOffAssignments);
      expect(server.posts.single.body, {'employee_id': 'EMP-7', 'pattern': 'p2', 'effective_from': '2026-11-06'});
      expect(find.byKey(const Key('wo-assign-sheet')), findsNothing);
      expect(find.text('Weekly off pattern assigned to Test Ann.'), findsOneWidget);
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor, AppColors.success);
      expect(server.lists.length, lists + 1);
    });

    testWidgets('Assign: no pattern yet keeps the button off; no global-default text', (tester) async {
      await pump(tester);
      await tap(tester, 'wo-assign-EMP-9');
      expect(find.textContaining('global default'), findsNothing);
      expect(enabled(tester, 'wo-assign-submit'), isFalse);
      await pick(tester, 'wo-assign-pattern', 'Sat-Sun Off');
      expect(enabled(tester, 'wo-assign-submit'), isTrue);
    });

    testWidgets('a refusal stays in the sheet with the server message and the choice kept', (tester) async {
      await pump(tester);
      await tap(tester, 'wo-assign-EMP-9');
      await pick(tester, 'wo-assign-pattern', 'Sunday Only');
      server.refuseNext = (status: 404, message: 'Weekly off pattern not found.');
      final lists = server.lists.length;
      await tap(tester, 'wo-assign-submit');
      expect(find.text('Weekly off pattern not found.'), findsOneWidget);
      expect(find.byKey(const Key('wo-assign-sheet')), findsOneWidget);
      expect(find.text('Sunday Only'), findsWidgets);
      expect(enabled(tester, 'wo-assign-submit'), isTrue);
      expect(find.byType(SnackBar), findsNothing);
      expect(server.lists.length, lists);
    });

    testWidgets('Assign can\'t be sent twice', (tester) async {
      await pump(tester);
      await tap(tester, 'wo-assign-EMP-7');
      server.hold = Completer();
      await tester.tap(find.byKey(const Key('wo-assign-submit')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Assigning…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wo-assign-submit')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      server.hold!.complete();
      await tester.pumpAndSettle();
      expect(server.posts, hasLength(1));
    });
  });

  group('bulk assign', () {
    testWidgets('unrestricted: pattern plus branch or department; exact request; server count', (tester) async {
      await pump(tester);
      await tap(tester, 'wo-bulk-open');
      await pick(tester, 'wo-bulk-pattern', 'Sunday Only');
      expect(enabled(tester, 'wo-bulk-submit'), isFalse);
      await pick(tester, 'wo-bulk-branch', 'South Wing');
      expect(enabled(tester, 'wo-bulk-submit'), isTrue);
      final lists = server.lists.length;
      await tap(tester, 'wo-bulk-submit');
      expect(server.posts.single.path, ApiConstants.attendanceWeeklyOffAssignmentsBulk);
      expect(server.posts.single.body,
          {'pattern': 'p2', 'effective_from': '2026-11-06', 'branch': 'South Wing', 'department': ''});
      expect(find.text('Weekly off pattern assigned to 7 employee(s).'), findsOneWidget);
      expect(server.lists.length, lists + 1);
    });

    testWidgets('branch-restricted: own branch locked and sent', (tester) async {
      await pump(tester, as: branchHr);
      await tap(tester, 'wo-bulk-open');
      await pick(tester, 'wo-bulk-pattern', 'Sat-Sun Off');
      expect(enabled(tester, 'wo-bulk-submit'), isTrue);
      await tap(tester, 'wo-bulk-submit');
      expect(server.posts.single.body,
          {'pattern': 'p1', 'effective_from': '2026-11-06', 'branch': 'North Wing', 'department': ''});
    });

    testWidgets('a refusal keeps the form; Assign can\'t be sent twice', (tester) async {
      await pump(tester);
      await tap(tester, 'wo-bulk-open');
      await pick(tester, 'wo-bulk-department', 'Ops');
      await pick(tester, 'wo-bulk-pattern', 'Sat-Sun Off');
      server.refuseNext = (status: 422, message: 'Enter a valid date.');
      await tap(tester, 'wo-bulk-submit');
      expect(find.text('Enter a valid date.'), findsOneWidget);
      expect(find.byKey(const Key('wo-bulk-sheet')), findsOneWidget);
      expect(enabled(tester, 'wo-bulk-submit'), isTrue);
      server.hold = Completer();
      await tester.tap(find.byKey(const Key('wo-bulk-submit')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('wo-bulk-submit')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      server.hold!.complete();
      await tester.pumpAndSettle();
      expect(server.posts, hasLength(2)); // the refused one + one retry
      expect(find.text('Weekly off pattern assigned to 7 employee(s).'), findsOneWidget);
    });
  });
}
