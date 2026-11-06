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
import 'package:mobile_app/features/attendance/data/models/shift_assignment_models.dart';
import 'package:mobile_app/features/attendance/presentation/providers/shift_assignment_providers.dart';
import 'package:mobile_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// Task 12: HR Attendance → Shift Assignment — web ShiftAssignmentTab.tsx over
// GET/POST /attendance/shift-assignments/, POST .../bulk/ and the active
// shift masters from GET /attendance/working-hours/. List needs
// attendance.view; assigning needs attendance.create (web usePermission);
// branch-restricted users are locked to their own branch (web
// getEffectiveBranch) and the server scopes everything again. "Today" is
// 6 Nov 2026. Stand-in server, synthetic people; nothing is sent anywhere.

final today = DateTime(2026, 11, 6, 9);

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
Map<String, dynamic> ok(Object data, [String message = 'ok']) =>
    {'status': 'success', 'message': message, 'data': data};

Map<String, dynamic> row(String code, String name,
        {String? shiftId, String? shiftName, String? from, String branch = 'North Wing'}) =>
    {
      'employee_id': code,
      'employee_name': name,
      'department': 'QA',
      'branch': branch,
      'shift_id': shiftId,
      'shift_name': shiftName,
      'effective_from': from,
      'effective_to': null,
      'status': shiftId != null ? 'Assigned' : 'Not Assigned',
    };

class Server implements HttpClientAdapter {
  final lists = <Map<String, dynamic>>[];
  final posts = <({String path, Map<String, dynamic> body})>[];
  Completer<void>? hold;
  ({int status, String message})? refuseNext;
  bool failList = false;
  Completer<void>? holdList;
  int totalPages = 1;
  List<Map<String, dynamic>> rows = [
    row('EMP-7', 'Test Ann', shiftId: 's1', shiftName: 'General 9-6', from: '2026-10-01'),
    row('EMP-9', 'Test Bob'),
  ];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == ApiConstants.attendanceWorkingHoursPolicies) {
      return _json(ok({
        'count': 2,
        'results': [
          {'id': 's1', 'name': 'General 9-6', 'policy_code': 'GEN'},
          {'id': 's2', 'name': 'Night 10-6', 'policy_code': 'NGT'},
        ],
      }));
    }
    if (o.path == ApiConstants.attendanceShiftAssignments && o.method == 'GET') {
      lists.add(Map.of(o.queryParameters));
      if (holdList != null) await holdList!.future;
      if (failList) return _json({'status': 'error', 'message': 'Permission denied.'}, 403);
      final status = o.queryParameters['status'];
      final shown = rows.where((r) => status == null || (status == 'assigned') == (r['shift_id'] != null)).toList();
      return _json(ok({
        'count': shown.length,
        'page': o.queryParameters['page'],
        'page_size': 20,
        'total_pages': totalPages,
        'results': shown,
      }));
    }
    if (o.method == 'POST' &&
        (o.path == ApiConstants.attendanceShiftAssignments || o.path == ApiConstants.attendanceShiftAssignmentsBulk)) {
      posts.add((path: o.path, body: Map<String, dynamic>.from(o.data as Map)));
      if (hold != null) await hold!.future;
      final r = refuseNext;
      if (r != null) {
        refuseNext = null;
        return _json({'status': 'error', 'message': r.message, 'data': {}}, r.status);
      }
      if (o.path == ApiConstants.attendanceShiftAssignmentsBulk) {
        return _json(ok({'count': 12}, 'Shift assigned to 12 employee(s).'));
      }
      return _json(ok({'employee_id': (o.data as Map)['employee_id']}, 'Shift assigned.'), 201);
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
      shiftAssignmentClockProvider.overrideWithValue(() => today),
    ];

Future<void> pump(WidgetTester tester, {UserEntity? as, void Function(Server)? setup}) async {
  // Wide enough for all six attendance tabs to be on screen without scrolling the tab bar.
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
  // Tapped in place: scrolling the screen first would collapse its header.
  await tester.tap(find.text('Shift Assignment'));
  await tester.pumpAndSettle();
}

/// Picks [option] from a dropdown. The tab's own filters are already on
/// screen; scrolling them would tuck them under the pinned tab bar.
Future<void> pick(WidgetTester tester, String key, String option) async {
  if (!key.startsWith('shift-filter-')) await tester.ensureVisible(find.byKey(Key(key)));
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
    test('rows: web status and fallbacks; query drops empty filters; a filter change goes back to page 1', () {
      final a = ShiftAssignmentRow.fromJson(row('E1', 'A', shiftId: 's1', shiftName: 'G', from: '2026-10-01'));
      expect([a.isAssigned, a.shiftName, a.effectiveFrom, a.effectiveTo], [true, 'G', '2026-10-01', null]);
      final b = ShiftAssignmentRow.fromJson({'employee_id': 'E2', 'shift_id': ''});
      expect([b.isAssigned, b.status, b.shiftId], [false, 'Not Assigned', null]);
      final p = ShiftAssignmentPage.fromJson({'results': 'x', 'total_pages': '3'});
      expect([p.rows, p.totalPages, p.page], [isEmpty, 3, 1]);
      const q = ShiftAssignmentQuery(page: 4);
      expect(q.params(), {'page': 4, 'page_size': 20});
      expect(q.copyWith(status: 'unassigned').params(), {'status': 'unassigned', 'page': 1, 'page_size': 20});
      expect(isoDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('permissions as web: attendance.create to assign; settings.edit or superuser are branch-unrestricted', () {
      expect(canAssignShifts(branchHr), isTrue);
      expect(canAssignShifts(viewer), isFalse);
      expect(canAssignShifts(user(['settings.edit'])), isFalse); // web usePermission has no settings.edit bypass
      expect([isUnrestrictedBranchUser(orgHr), isUnrestrictedBranchUser(branchHr)], [true, false]);
      expect([effectiveBranch(orgHr), effectiveBranch(branchHr)], ['', 'North Wing']);
    });

    test('below the UI: without attendance.create nothing is sent', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(viewer));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final s = c.read(shiftAssignmentServiceProvider);
      final r = ShiftAssignmentRow.fromJson(row('EMP-9', 'Test Bob'));
      await expectLater(s.assign(r, 's1', today), throwsA(isA<ShiftAssignDenied>()));
      await expectLater(s.bulkAssign(shiftId: 's1', from: today, branch: 'North Wing', department: ''),
          throwsA(isA<ShiftAssignDenied>()));
      expect(server.posts, isEmpty);
    });
  });

  group('list', () {
    testWidgets('rows as web: shift or "General / Default", dates, status; Change / Assign buttons', (tester) async {
      await pump(tester);
      expect(server.lists.first, {'page': 1, 'page_size': 20});
      expect(find.text('General 9-6'), findsWidgets);
      expect(find.text('General / Default'), findsOneWidget);
      expect(find.text('Effective From 2026-10-01 · Effective To -'), findsOneWidget);
      expect(find.text('Effective From — · Effective To -'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Change'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Assign'), findsOneWidget);
      expect(find.byKey(const Key('shift-bulk-open')), findsOneWidget);
    });

    testWidgets('attendance.view only: the list, but no Assign / Bulk Assign', (tester) async {
      await pump(tester, as: viewer);
      expect(find.text('Test Ann'), findsOneWidget);
      expect(find.byKey(const Key('shift-bulk-open')), findsNothing);
      expect(find.byKey(const Key('shift-assign-EMP-7')), findsNothing);
    });

    testWidgets('a branch-restricted user always asks for their own branch (picker locked)', (tester) async {
      await pump(tester, as: branchHr);
      expect(server.lists.first['branch'], 'North Wing');
      final picker = tester.widget<DropdownButtonFormField<String>>(find.descendant(
          of: find.byKey(const Key('shift-filter-branch')), matching: find.byType(DropdownButtonFormField<String>)));
      expect(picker.onChanged, isNull);
    });

    testWidgets('filters: branch, shift and status are sent; any change returns to page 1', (tester) async {
      await pump(tester, setup: (s) => s.totalPages = 3);
      await pick(tester, 'shift-filter-branch', 'South Wing');
      expect(server.lists.last, {'branch': 'South Wing', 'page': 1, 'page_size': 20});
      await pick(tester, 'shift-filter-shift', 'Night 10-6');
      await pick(tester, 'shift-filter-status', 'Not Assigned (Global Default)');
      expect(server.lists.last,
          {'branch': 'South Wing', 'shift': 's2', 'status': 'unassigned', 'page': 1, 'page_size': 20});
      expect(find.text('Test Ann'), findsNothing);
      expect(find.text('Test Bob'), findsOneWidget);
      expect(find.text('Page 1 of 3 · 1 employees'), findsOneWidget);
      await tap(tester, 'shift-next');
      expect(server.lists.last,
          {'branch': 'South Wing', 'shift': 's2', 'status': 'unassigned', 'page': 2, 'page_size': 20});
    });

    testWidgets('loading, then empty: "No employees found."', (tester) async {
      await pump(tester, setup: (s) {
        s.rows = [];
        s.holdList = Completer();
      });
      expect(find.byKey(const Key('shift-loading')), findsOneWidget);
      server.holdList!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shift-empty')), findsOneWidget);
    });

    testWidgets('error with Retry', (tester) async {
      await pump(tester, setup: (s) => s.failList = true);
      expect(find.text('Permission denied.'), findsOneWidget);
      server.failList = false;
      await tap(tester, 'shift-retry');
      expect(find.text('Test Ann'), findsOneWidget);
    });
  });

  group('assign one employee', () {
    testWidgets('Change: current shift pre-selected, today as Effective From, exact request, reload', (tester) async {
      await pump(tester);
      await tap(tester, 'shift-assign-EMP-7');
      expect(find.textContaining('Test Ann (EMP-7) — currently General 9-6, effective 2026-10-01'), findsOneWidget);
      expect(find.text('2026-11-06'), findsOneWidget);
      await pick(tester, 'assign-shift-shift', 'Night 10-6');
      final lists = server.lists.length;
      await tap(tester, 'assign-shift-submit');
      expect(server.posts.single.path, ApiConstants.attendanceShiftAssignments);
      expect(server.posts.single.body, {'employee_id': 'EMP-7', 'shift': 's2', 'effective_from': '2026-11-06'});
      expect(find.byKey(const Key('assign-shift-sheet')), findsNothing);
      expect(find.text('Shift assigned to Test Ann.'), findsOneWidget);
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor, AppColors.success);
      expect(server.lists.length, lists + 1); // list reloaded
    });

    testWidgets('Assign: no shift yet means the button stays off (global-default note shown)', (tester) async {
      await pump(tester);
      await tap(tester, 'shift-assign-EMP-9');
      expect(find.textContaining('currently on the global default schedule'), findsOneWidget);
      expect(enabled(tester, 'assign-shift-submit'), isFalse);
      await pick(tester, 'assign-shift-shift', 'General 9-6');
      expect(enabled(tester, 'assign-shift-submit'), isTrue);
    });

    testWidgets('a refusal stays in the sheet with the server message and the choice kept', (tester) async {
      await pump(tester);
      await tap(tester, 'shift-assign-EMP-9');
      await pick(tester, 'assign-shift-shift', 'Night 10-6');
      server.refuseNext = (status: 422, message: 'Enter a valid date.');
      final lists = server.lists.length;
      await tap(tester, 'assign-shift-submit');
      expect(find.text('Enter a valid date.'), findsOneWidget);
      expect(find.byKey(const Key('assign-shift-sheet')), findsOneWidget);
      expect(find.text('Night 10-6'), findsWidgets);
      expect(find.byType(SnackBar), findsNothing);
      expect(server.lists.length, lists); // nothing reloaded
    });

    testWidgets('Assign can\'t be sent twice', (tester) async {
      await pump(tester);
      await tap(tester, 'shift-assign-EMP-7');
      server.hold = Completer();
      await tester.tap(find.byKey(const Key('assign-shift-submit')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Assigning…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('assign-shift-submit')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      server.hold!.complete();
      await tester.pumpAndSettle();
      expect(server.posts, hasLength(1));
    });
  });

  group('bulk assign', () {
    testWidgets('unrestricted: needs shift and a branch or department; exact request; count shown', (tester) async {
      await pump(tester);
      await tap(tester, 'shift-bulk-open');
      await pick(tester, 'bulk-shift-shift', 'Night 10-6');
      expect(enabled(tester, 'bulk-shift-submit'), isFalse); // no branch/department yet
      await pick(tester, 'bulk-shift-department', 'Ops');
      expect(enabled(tester, 'bulk-shift-submit'), isTrue);
      await tap(tester, 'bulk-shift-submit');
      expect(server.posts.single.path, ApiConstants.attendanceShiftAssignmentsBulk);
      expect(
          server.posts.single.body, {'shift': 's2', 'effective_from': '2026-11-06', 'branch': '', 'department': 'Ops'});
      expect(find.text('Shift assigned to 12 employee(s).'), findsOneWidget);
    });

    testWidgets('branch-restricted: own branch locked and sent; no extra filter needed', (tester) async {
      await pump(tester, as: branchHr);
      await tap(tester, 'shift-bulk-open');
      await pick(tester, 'bulk-shift-shift', 'General 9-6');
      expect(enabled(tester, 'bulk-shift-submit'), isTrue);
      await tap(tester, 'bulk-shift-submit');
      expect(server.posts.single.body,
          {'shift': 's1', 'effective_from': '2026-11-06', 'branch': 'North Wing', 'department': ''});
    });

    testWidgets('a refusal keeps the form and shows the server message', (tester) async {
      await pump(tester);
      await tap(tester, 'shift-bulk-open');
      await pick(tester, 'bulk-shift-branch', 'South Wing');
      await pick(tester, 'bulk-shift-shift', 'General 9-6');
      server.refuseNext = (status: 404, message: 'Shift not found.');
      await tap(tester, 'bulk-shift-submit');
      expect(find.text('Shift not found.'), findsOneWidget);
      expect(find.byKey(const Key('bulk-shift-sheet')), findsOneWidget);
      expect(enabled(tester, 'bulk-shift-submit'), isTrue); // values kept, can retry
    });
  });
}
