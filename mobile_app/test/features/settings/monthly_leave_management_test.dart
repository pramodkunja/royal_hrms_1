import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import 'package:mobile_app/features/settings/data/models/monthly_leave_models.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/leave_policy_screen.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/monthly_leave/monthly_leave_providers.dart';

// Task 10: Settings → Leave Policy → Monthly Leave Management — web
// MonthlyLeaveTab.tsx / MonthlyAssignmentsSection.tsx / lib/monthlyLeave.ts
// over /leave/monthly-credits/ (assignments, single save, bulk with dry_run,
// multipart import with dry_run, sample). Tab and every call need
// leave.approve (web usePermission: superuser or the permission). "Today" is
// 6 Nov 2026. A stand-in server, synthetic people; nothing is sent anywhere.

final today = DateTime(2026, 11, 6, 10);

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> ok(Object data, [String message = 'ok']) =>
    {'status': 'success', 'message': message, 'data': data};

Map<String, dynamic> emp(String code, String name, {bool active = true, String branch = 'Test Branch'}) => {
      'id': code,
      'uuid': 'uuid-$code',
      'employee_id': code,
      'full_name': name,
      'department': 'QA',
      'designation': 'Tester',
      'branch': branch,
      'is_active': active,
      'status': active ? 'active' : 'inactive',
    };

Map<String, dynamic> planRow(int row, String code, String status,
        {String type = 'casual', Object credit = 1.5, Object? previous = 0.0, Object? delta = 1.5}) =>
    {
      'row': row,
      'employee_code': code,
      'employee_name': 'Test $code',
      'leave_type': type,
      'leave_type_label': type == 'casual' ? 'Casual Leave' : 'Earned Leave',
      'credit': credit,
      'previous': previous,
      'delta': delta,
      'status': status,
      'message': status == 'error' ? 'Employee not found.' : 'Adds 1.5 day(s).',
    };

Map<String, dynamic> plan(List<Map<String, dynamic>> rows, {int month = 11}) => {
      'year': 2026,
      'month': month,
      'rows': rows,
      'counts': {
        for (final s in ['new', 'update', 'unchanged', 'duplicate', 'error'])
          s: rows.where((r) => r['status'] == s).length,
      },
      'annual_entitlements': {'casual': 12.0},
    };

Map<String, dynamic> applied(List<Map<String, dynamic>> rows) => {
      'year': 2026,
      'month': 11,
      'rows': rows,
      'summary': {
        'created': rows.where((r) => r['status'] == 'new').length,
        'updated': rows.where((r) => r['status'] == 'update').length,
        'skipped': 0,
        'failed': rows.where((r) => r['status'] == 'error').length,
        'total': rows.length,
      },
      'annual_entitlements': {'casual': 12.0},
    };

class Server implements HttpClientAdapter {
  final log = <String>[];
  final bodies = <String, List<Object?>>{};
  final holds = <String, Completer<void>>{};

  /// path → (status, message) for the next call.
  final refuse = <String, ({int status, String message})>{};

  List<Map<String, dynamic>> assignments = [
    {
      'employee_id': 'EMP-7',
      'employee_name': 'Test Ann',
      'branch': 'Test Branch',
      'is_active': true,
      'leave_type': 'casual',
      'leave_type_label': 'Casual Leave',
      'year': 2026,
      'month': 11,
      'credit': 1.5,
      'last_updated': '2026-11-05T12:24:26+00:00',
    },
    {
      'employee_id': 'EMP-8',
      'employee_name': 'Test Gone',
      'branch': '',
      'is_active': false,
      'leave_type': 'earned',
      'leave_type_label': 'Earned Leave',
      'year': 2026,
      'month': 11,
      'credit': 2.0,
      'last_updated': '2026-11-01T04:00:00+00:00',
    },
  ];
  List<Map<String, dynamic>> employees = [
    emp('EMP-1', 'Test Me'),
    emp('EMP-7', 'Test Ann'),
    emp('EMP-8', 'Test Gone', active: false),
    emp('EMP-9', 'Test Bob'),
  ];
  Map<String, dynamic> nextPlan =
      plan([planRow(1, 'EMP-7', 'new'), planRow(2, 'EMP-9', 'update', previous: 1.0, delta: 0.5)]);
  Map<String, dynamic> nextResult = applied([planRow(1, 'EMP-7', 'new'), planRow(2, 'EMP-9', 'update')]);

  int count(String method, String path) => log.where((l) => l == '$method $path').length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    final key = '${o.method} ${o.path}';
    log.add(key);
    bodies.putIfAbsent(key, () => []).add(o.method == 'GET' ? Map.of(o.queryParameters) : o.data);
    final gate = holds[key];
    if (gate != null) await gate.future;
    final r = refuse.remove(key);
    if (r != null) return _json({'status': 'error', 'message': r.message}, r.status);

    switch (key) {
      case 'GET ${ApiConstants.leaveTypes}':
        return _json(ok([
          {
            'id': 1,
            'leave_type': 'casual',
            'leave_type_display': 'Casual Leave',
            'annual_days': '12.0',
            'is_active': true
          },
          {
            'id': 2,
            'leave_type': 'earned',
            'leave_type_display': 'Earned Leave',
            'annual_days': '0',
            'is_active': true
          },
          {
            'id': 3,
            'leave_type': 'lwp',
            'leave_type_display': 'Leave Without Pay',
            'annual_days': '0',
            'is_active': true
          },
          {'id': 4, 'leave_type': 'sick', 'leave_type_display': 'Sick Leave', 'annual_days': '6', 'is_active': false},
        ]));
      case 'GET ${ApiConstants.employees}':
        return _json(
            ok({'count': employees.length, 'page': 1, 'page_size': 50, 'total_pages': 1, 'results': employees}));
      case 'GET ${ApiConstants.leaveMonthlyAssignments}':
        final month = int.parse('${o.queryParameters['month']}');
        final rows = month == 11 ? assignments : <Map<String, dynamic>>[];
        return _json(ok({
          'year': 2026,
          'month': month,
          'assignments': rows,
          'summary': {'employees': rows.length, 'entries': rows.length, 'total_days': month == 11 ? 3.5 : 0},
        }));
      case 'POST ${ApiConstants.leaveMonthlyCredits}':
        return _json(ok({'status': 'updated', 'previous': 1.5, 'value': 2.0, 'delta': 0.5, 'leave_types': []},
            'Monthly leave credit updated.'));
      case 'POST ${ApiConstants.leaveMonthlyCreditsBulk}':
        final dry = (o.data as Map)['dry_run'] == true;
        return _json(ok(dry ? nextPlan : nextResult));
      case 'POST ${ApiConstants.leaveMonthlyCreditsImport}':
        final dry = (o.data as FormData).fields.any((f) => f.key == 'dry_run' && f.value == 'true');
        return _json(ok(dry ? nextPlan : nextResult));
      case 'GET ${ApiConstants.leaveMonthlyCreditsSample}':
        return ResponseBody.fromBytes(utf8.encode('Employee Code,Leave Type,Monthly Leave Credit\r\n'), 200);
    }
    return _json(ok({'results': [], 'count': 0}));
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

UserEntity user(List<String> perms, {bool superuser = false}) => UserEntity(
      id: 'uuid-EMP-1',
      employeeId: 'EMP-1',
      email: 'hr@example.test',
      fullName: 'Test Me',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final approver = user(['settings.view', 'leave.approve']);
final viewer = user(['settings.view']);

late Server server;
late ProviderContainer container;
PickedFile? nextFile;
final saved = <String, Uint8List>{};

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      monthlyLeaveClockProvider.overrideWithValue(() => today),
      monthlyImportFilePickerProvider.overrideWithValue(() async => nextFile),
      monthlySampleSaverProvider.overrideWithValue((name, bytes) async {
        saved[name] = bytes;
        return '/tmp/$name';
      }),
    ];

PickedFile file(String name, {int? size}) {
  final bytes = Uint8List.fromList(utf8.encode('Employee Code,Leave Type,Monthly Leave Credit\nEMP-7,casual,1.5\n'));
  return (name: name, bytes: bytes, size: size ?? bytes.length);
}

Future<void> pump(WidgetTester tester, {UserEntity? as}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  saved.clear();
  nextFile = null;
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? approver),
    child: MaterialApp.router(
      routerConfig: GoRouter(initialLocation: '/settings/leave-policy', routes: [
        GoRoute(
          path: '/settings/leave-policy',
          // As in the app, the screen opens once the user is signed in.
          builder: (_, __) => Consumer(
            builder: (context, ref, _) =>
                ref.watch(authStateProvider).valueOrNull?.user == null ? const SizedBox() : const LeavePolicyScreen(),
          ),
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
  container = ProviderScope.containerOf(tester.element(find.byType(LeavePolicyScreen)));
}

Future<void> openTab(WidgetTester tester) async {
  await tester.tap(find.text('Monthly Leave Management'));
  await tester.pumpAndSettle();
}

Future<void> openCard(WidgetTester tester, String key) async {
  await tester.tap(find.descendant(of: find.byKey(Key('monthly-card-$key')), matching: find.byType(InkWell)).first);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String alert(WidgetTester tester, String key) =>
    tester.widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text))).data!;

bool enabled(WidgetTester tester, String key) {
  final w = tester.widget(find.byKey(Key(key)));
  return switch (w) {
    ButtonStyleButton() => w.onPressed != null,
    _ => throw StateError('$w'),
  };
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules (web lib/monthlyLeave.ts)', () {
    test('validateMonthlyCredit: web messages, 0–31, one decimal', () {
      expect(validateMonthlyCredit(' '), "Enter a monthly leave credit (0 removes the month's credit).");
      expect(validateMonthlyCredit('-1'), 'Monthly leave credit cannot be negative.');
      expect(validateMonthlyCredit('1.25'), 'Use a number with at most one decimal place, e.g. 1 or 1.5.');
      expect(validateMonthlyCredit('abc'), 'Use a number with at most one decimal place, e.g. 1 or 1.5.');
      expect(validateMonthlyCredit('31.1'), 'Monthly leave credit cannot exceed 31 days.');
      for (final ok in ['0', '1', '1.5', ' 31 ', '31.0']) {
        expect(validateMonthlyCredit(ok), isNull, reason: ok);
      }
    });

    test('creditYears, describeChange, numbers as JavaScript prints them', () {
      expect(creditYears(today), [2026, 2025, 2024]);
      expect(describeChange(1.5, 1.5), 'No change.');
      expect(
          describeChange(1.5, 0), "Removes this month's credit: 1.5 day(s) will be taken off the employee's balance.");
      expect(describeChange(1, 2.5), "Changes 1 → 2.5 day(s): 1.5 day(s) will be added to the employee's balance.");
      expect(describeChange(2, 1.5), "Changes 2 → 1.5 day(s): 0.5 day(s) will be taken off the employee's balance.");
      expect([fmtNum(2.0), fmtNum(1.5), fmtNum(-2)], ['2', '1.5', '-2']);
    });

    test('permission is web usePermission: superuser or leave.approve (no settings.edit bypass)', () {
      expect(canManageMonthlyCredits(approver), isTrue);
      expect(canManageMonthlyCredits(viewer), isFalse);
      expect(canManageMonthlyCredits(user(['settings.edit'])), isFalse);
      expect(canManageMonthlyCredits(user([], superuser: true)), isTrue);
      expect(canManageMonthlyCredits(null), isFalse);
    });

    test('parsing: plan, result, assignments; malformed values are safe', () {
      final p = MonthlyPlan.fromJson(
          plan([planRow(1, 'EMP-7', 'new'), planRow(2, 'X', 'error', previous: null, delta: null)]));
      expect([p.year, p.month, p.applicable, p.count('error')], [2026, 11, 1, 1]);
      final r = p.rows.first;
      expect([r.credit, r.previousText, r.deltaText, r.statusLabel, r.typeLabel],
          ['1.5', '0', '+1.5', 'New', 'Casual Leave']);
      expect([p.rows[1].previousText, p.rows[1].deltaText], ['—', '—']);
      expect(annualWarningTypes(p.rows, p.annualEntitlements), ['Casual Leave (12 days/year)']);
      final res = MonthlyApplyResult.fromJson(applied([planRow(1, 'EMP-7', 'new')]));
      expect([res.created, res.updated, res.failed, res.total], [1, 0, 0, 1]);
      final odd = MonthlyPlan.fromJson({'rows': 'x', 'counts': null, 'month': '3'});
      expect([odd.rows, odd.applicable, odd.month], [isEmpty, 0, 3]);
      final a = MonthlyAssignments.fromJson({
        'assignments': [
          {'employee_id': 'E', 'credit': '2.5', 'leave_type': 'casual', 'last_updated': 'bad'}
        ],
        'summary': {'total_days': '2.5'},
      });
      expect([a.assignments.single.credit, a.assignments.single.leaveTypeLabel, a.totalDays], [2.5, 'casual', 2.5]);
      expect(formatMonthlyWhen('bad'), '—');
      expect(formatMonthlyWhen('2026-11-05T12:24:26+00:00', viewerOffset: const Duration(hours: 5, minutes: 30)),
          '05 Nov 2026, 05:54 pm');
      expect(formatMonthlyWhen('2026-09-01T03:35:00Z', viewerOffset: const Duration(hours: 5, minutes: 30)),
          '01 Sept 2026, 09:05 am');
    });
  });

  group('access', () {
    testWidgets('the tab is shown with leave.approve and after Carry Forward/Credit Rules', (tester) async {
      await pump(tester);
      expect(find.text('Monthly Leave Management'), findsOneWidget);
      expect(find.text('Credit Rules'), findsOneWidget);
      await openTab(tester);
      expect(find.text('Monthly Leave Import'), findsOneWidget);
      expect(find.text('Manual Monthly Leave Entry'), findsOneWidget);
      expect(find.text('Monthly Leave Assignments'), findsOneWidget);
      // All collapsed: nothing requested yet.
      expect(server.log.where((l) => l.contains('monthly-credits')), isEmpty);
      expect(server.count('GET', ApiConstants.employees), 0);
    });

    testWidgets('no leave.approve: no tab', (tester) async {
      await pump(tester, as: viewer);
      expect(find.text('Monthly Leave Management'), findsNothing);
      expect(find.text('Leave Types'), findsOneWidget);
    });

    test('below the UI: without leave.approve every call is refused before any request', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(viewer));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final s = c.read(monthlyLeaveServiceProvider);
      await expectLater(s.assignments(2026, 11), throwsA(isA<MonthlyLeaveDenied>()));
      await expectLater(s.bulkApply(['EMP-7'], 'casual', 2026, 11, '1'), throwsA(isA<MonthlyLeaveDenied>()));
      await expectLater(s.importApply(file('a.csv'), 2026, 11), throwsA(isA<MonthlyLeaveDenied>()));
      await expectLater(s.sample('csv'), throwsA(isA<MonthlyLeaveDenied>()));
      expect(server.log, isEmpty);
    });

    test('a 403 from the server shows its message', () async {
      server = Server()
        ..refuse['GET ${ApiConstants.leaveMonthlyAssignments}'] = (status: 403, message: 'Permission denied.');
      final c = ProviderContainer(overrides: overrides(approver));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      try {
        await c.read(monthlyLeaveServiceProvider).assignments(2026, 11);
        fail('expected a refusal');
      } catch (e) {
        expect(monthlyLeaveError(e, 'fallback'), 'Permission denied.');
      }
    });
  });

  group('assignments', () {
    testWidgets('loads the current month on open: summary, rows, inactive without Edit', (tester) async {
      await pump(tester);
      await openTab(tester);
      await openCard(tester, 'assignments');
      expect(server.bodies['GET ${ApiConstants.leaveMonthlyAssignments}'], [
        {'year': 2026, 'month': 11}
      ]);
      expect(tester.widget<Text>(find.byKey(const Key('assign-stat-Employees assigned'))).data, '2');
      expect(tester.widget<Text>(find.byKey(const Key('assign-stat-Total days credited'))).data, '3.5');
      expect(find.text('Test Ann'), findsOneWidget);
      expect(find.text('Test Gone (inactive)'), findsOneWidget);
      expect(find.byKey(const Key('assignment-edit-EMP-7-casual')), findsOneWidget);
      expect(find.byKey(const Key('assignment-edit-EMP-8-earned')), findsNothing);
    });

    testWidgets('another month: new request; empty month shows web text', (tester) async {
      await pump(tester);
      await openTab(tester);
      await openCard(tester, 'assignments');
      await tester.tap(find.byKey(const Key('assign-month')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('March').last);
      await tester.pumpAndSettle();
      expect(server.bodies['GET ${ApiConstants.leaveMonthlyAssignments}']!.last, {'year': 2026, 'month': 3});
      expect(
          find.text(
              'No monthly leave assignments found for March 2026. Use the import or manual entry above to add them.'),
          findsOneWidget);
    });

    testWidgets('load error with Retry', (tester) async {
      await pump(tester);
      server.refuse['GET ${ApiConstants.leaveMonthlyAssignments}'] = (status: 500, message: 'Server exploded.');
      await openTab(tester);
      await openCard(tester, 'assignments');
      expect(alert(tester, 'assign-error'), 'Server exploded.');
      await tap(tester, 'assign-retry');
      expect(find.text('Test Ann'), findsOneWidget);
    });

    testWidgets('edit: validation, review, confirm sends the save; success shows the server message and reloads',
        (tester) async {
      await pump(tester);
      await openTab(tester);
      await openCard(tester, 'assignments');
      await tap(tester, 'assignment-edit-EMP-7-casual');
      expect(enabled(tester, 'edit-review'), isFalse); // unchanged (1.5)
      await tester.enterText(find.byKey(const Key('edit-credit')), '1.25');
      await tester.pump();
      expect(find.text('Use a number with at most one decimal place, e.g. 1 or 1.5.'), findsOneWidget);
      expect(enabled(tester, 'edit-review'), isFalse);
      await tester.enterText(find.byKey(const Key('edit-credit')), '2');
      await tester.pump();
      await tap(tester, 'edit-review');
      expect(alert(tester, 'edit-confirm-text'), contains("Changes 1.5 → 2 day(s): 0.5 day(s) will be added"));
      expect(server.count('POST', ApiConstants.leaveMonthlyCredits), 0); // nothing sent before Confirm
      await tap(tester, 'edit-confirm');
      expect(server.bodies['POST ${ApiConstants.leaveMonthlyCredits}'], [
        {'employee_id': 'EMP-7', 'leave_type': 'casual', 'year': 2026, 'month': 11, 'credit': '2'}
      ]);
      expect(find.byKey(const Key('edit-monthly-credit')), findsNothing);
      expect(alert(tester, 'assign-ok'), 'Monthly leave credit updated.');
      expect(server.count('GET', ApiConstants.leaveMonthlyAssignments), 2); // reloaded
    });

    testWidgets('edit: a refusal returns to editing with the value kept; no success shown', (tester) async {
      await pump(tester);
      await openTab(tester);
      await openCard(tester, 'assignments');
      await tap(tester, 'assignment-edit-EMP-7-casual');
      await tester.enterText(find.byKey(const Key('edit-credit')), '0');
      await tester.pump();
      await tap(tester, 'edit-review');
      expect(alert(tester, 'edit-confirm-text'), contains("Removes this month's credit"));
      server.refuse['POST ${ApiConstants.leaveMonthlyCredits}'] =
          (status: 409, message: 'This would leave less than the used plus pending leave.');
      await tap(tester, 'edit-confirm');
      expect(alert(tester, 'edit-error'), 'This would leave less than the used plus pending leave.');
      expect(tester.widget<TextField>(find.byKey(const Key('edit-credit'))).controller!.text, '0');
      expect(server.count('GET', ApiConstants.leaveMonthlyAssignments), 1); // not reloaded
    });

    testWidgets('edit: Confirm can\'t be sent twice', (tester) async {
      await pump(tester);
      await openTab(tester);
      await openCard(tester, 'assignments');
      await tap(tester, 'assignment-edit-EMP-7-casual');
      await tester.enterText(find.byKey(const Key('edit-credit')), '3');
      await tester.pump();
      await tap(tester, 'edit-review');
      server.holds['POST ${ApiConstants.leaveMonthlyCredits}'] = Completer();
      await tester.tap(find.byKey(const Key('edit-confirm')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Saving…'), findsOneWidget);
      expect(enabled(tester, 'edit-confirm'), isFalse);
      await tester.tap(find.byKey(const Key('edit-confirm')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      server.holds['POST ${ApiConstants.leaveMonthlyCredits}']!.complete();
      await tester.pumpAndSettle();
      expect(server.count('POST', ApiConstants.leaveMonthlyCredits), 1);
    });
  });

  group('manual entry', () {
    Future<void> openManual(WidgetTester tester) async {
      await pump(tester);
      await openTab(tester);
      await openCard(tester, 'manual');
    }

    testWidgets('employees load once on open (page_size 50); self and inactive cannot be ticked', (tester) async {
      await openManual(tester);
      expect(server.bodies['GET ${ApiConstants.employees}'], [
        {'page': 1, 'page_size': 50}
      ]);
      CheckboxListTile tile(String code) => tester.widget(find.byKey(Key('manual-employee-$code')));
      expect(tile('EMP-1').onChanged, isNull);
      expect(find.textContaining('you (cannot change your own credits)'), findsOneWidget);
      expect(tile('EMP-8').onChanged, isNull);
      expect(tile('EMP-7').onChanged, isNotNull);
      await tap(tester, 'manual-select-all');
      expect(tester.widget<Text>(find.byKey(const Key('manual-selected-count'))).data, '2 selected');
      expect(find.text('Select all shown (2)'), findsOneWidget);
    });

    testWidgets('leave types: active only, no LWP; annual warning; credit validation gates Review', (tester) async {
      await openManual(tester);
      await tap(tester, 'manual-leave-type');
      expect(find.text('Casual Leave').last, findsOneWidget);
      expect(find.text('Earned Leave').last, findsOneWidget);
      expect(find.text('Leave Without Pay'), findsNothing);
      expect(find.text('Sick Leave'), findsNothing);
      await tester.tap(find.text('Casual Leave').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('monthly-annual-warning')), findsOneWidget);
      await tap(tester, 'manual-employee-EMP-7');
      await tester.enterText(find.byKey(const Key('manual-credit')), '32');
      await tester.pump();
      expect(find.text('Monthly leave credit cannot exceed 31 days.'), findsOneWidget);
      expect(enabled(tester, 'manual-review'), isFalse);
      await tester.enterText(find.byKey(const Key('manual-credit')), '1.5');
      await tester.pump();
      expect(enabled(tester, 'manual-review'), isTrue);
    });

    Future<void> fill(WidgetTester tester) async {
      await tap(tester, 'manual-employee-EMP-7');
      await tap(tester, 'manual-employee-EMP-9');
      await tap(tester, 'manual-leave-type');
      await tester.tap(find.text('Casual Leave').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('manual-credit')), ' 1.5 ');
      await tester.pump();
    }

    testWidgets('review (dry_run) then confirm: exact bodies, result, assignments refreshed', (tester) async {
      await openManual(tester);
      await fill(tester);
      await tap(tester, 'manual-review');
      expect(server.bodies['POST ${ApiConstants.leaveMonthlyCreditsBulk}'], [
        {
          'employee_ids': ['EMP-7', 'EMP-9'],
          'leave_type': 'casual',
          'year': 2026,
          'month': 11,
          'credit': '1.5',
          'dry_run': true
        }
      ]);
      expect(alert(tester, 'manual-review-summary'),
          contains('set Casual Leave to 1.5 day(s) for November 2026 — 1 new, 1 update'));
      expect(find.text('Confirm for 2 employee(s)'), findsOneWidget);
      await tap(tester, 'manual-confirm');
      expect(server.bodies['POST ${ApiConstants.leaveMonthlyCreditsBulk}']!.last, {
        'employee_ids': ['EMP-7', 'EMP-9'],
        'leave_type': 'casual',
        'year': 2026,
        'month': 11,
        'credit': '1.5'
      });
      expect(alert(tester, 'manual-result'), startsWith('November 2026: 1 added, 1 updated'));
      expect(container.read(monthlyLeaveRefreshProvider), 1);
    });

    testWidgets('changing anything after a review drops it; nothing applicable disables Confirm', (tester) async {
      await openManual(tester);
      await fill(tester);
      server.nextPlan = plan([planRow(1, 'EMP-7', 'unchanged'), planRow(2, 'EMP-9', 'error')]);
      await tap(tester, 'manual-review');
      expect(enabled(tester, 'manual-confirm'), isFalse);
      await tester.enterText(find.byKey(const Key('manual-credit')), '2');
      await tester.pump();
      expect(find.byKey(const Key('manual-review-summary')), findsNothing);
      expect(find.byKey(const Key('manual-review')), findsOneWidget);
    });

    testWidgets('a failed save keeps the review and form values and shows the server message', (tester) async {
      await openManual(tester);
      await fill(tester);
      await tap(tester, 'manual-review');
      server.refuse['POST ${ApiConstants.leaveMonthlyCreditsBulk}'] =
          (status: 400, message: 'Select at most 500 employees at a time.');
      await tap(tester, 'manual-confirm');
      expect(alert(tester, 'manual-error'), 'Select at most 500 employees at a time.');
      expect(find.byKey(const Key('manual-result')), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const Key('manual-credit'))).controller!.text, ' 1.5 ');
      expect(tester.widget<Text>(find.byKey(const Key('manual-selected-count'))).data, '2 selected');
      expect(container.read(monthlyLeaveRefreshProvider), 0);
    });

    testWidgets('employee list error shows its message', (tester) async {
      await pump(tester);
      server.refuse['GET ${ApiConstants.employees}'] =
          (status: 403, message: 'You do not have permission to perform this action.');
      await openTab(tester);
      await openCard(tester, 'manual');
      expect(tester.widget<Text>(find.byKey(const Key('manual-list-error'))).data,
          'You do not have permission to perform this action.');
    });
  });

  group('import', () {
    Future<void> openImport(WidgetTester tester) async {
      await pump(tester);
      await openTab(tester);
      await openCard(tester, 'import');
    }

    testWidgets('wrong type or over 5 MB is refused before any request', (tester) async {
      await openImport(tester);
      nextFile = file('credits.pdf');
      await tap(tester, 'import-choose-file');
      expect(alert(tester, 'import-error'), 'Upload a .csv or .xlsx file.');
      nextFile = file('credits.csv', size: kMonthlyImportMaxBytes + 1);
      await tap(tester, 'import-choose-file');
      expect(alert(tester, 'import-error'), 'File must not exceed 5 MB.');
      expect(enabled(tester, 'import-preview'), isFalse);
      expect(server.log.where((l) => l.contains('import')), isEmpty);
    });

    testWidgets('preview (dry_run) then confirm: multipart fields, summaries, refresh', (tester) async {
      await openImport(tester);
      nextFile = file('Credits.XLSX');
      await tap(tester, 'import-choose-file');
      expect(find.text('Credits.XLSX'), findsOneWidget);
      await tap(tester, 'import-preview');
      final form = server.bodies['POST ${ApiConstants.leaveMonthlyCreditsImport}']!.single as FormData;
      expect({for (final f in form.fields) f.key: f.value}, {'year': '2026', 'month': '11', 'dry_run': 'true'});
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'Credits.XLSX');
      expect(
          alert(tester, 'import-preview-summary'),
          'Preview for November 2026 (nothing saved yet): 1 new, 1 update, 0 unchanged, 0 duplicate, 0 error. '
          'Only new and update rows will be applied.');
      expect(find.byKey(const Key('monthly-annual-warning')), findsOneWidget);
      await tap(tester, 'import-confirm');
      final form2 = server.bodies['POST ${ApiConstants.leaveMonthlyCreditsImport}']!.last as FormData;
      expect({for (final f in form2.fields) f.key: f.value}, {'year': '2026', 'month': '11'});
      expect(alert(tester, 'import-result'), startsWith('Import for November 2026 finished: 1 added, 1 updated'));
      expect(container.read(monthlyLeaveRefreshProvider), 1);
      await tap(tester, 'import-another');
      expect(find.byKey(const Key('import-result')), findsNothing);
      expect(find.text('Credits.XLSX'), findsNothing);
    });

    testWidgets('preview refused: server message, nothing applied', (tester) async {
      await openImport(tester);
      nextFile = file('credits.csv');
      await tap(tester, 'import-choose-file');
      server.refuse['POST ${ApiConstants.leaveMonthlyCreditsImport}'] =
          (status: 400, message: 'Credits can only be adjusted for the current or a past calendar year.');
      await tap(tester, 'import-preview');
      expect(alert(tester, 'import-error'), 'Credits can only be adjusted for the current or a past calendar year.');
      expect(find.byKey(const Key('import-preview-summary')), findsNothing);
    });

    testWidgets('Confirm import can\'t be sent twice', (tester) async {
      await openImport(tester);
      nextFile = file('credits.csv');
      await tap(tester, 'import-choose-file');
      await tap(tester, 'import-preview');
      server.holds['POST ${ApiConstants.leaveMonthlyCreditsImport}'] = Completer();
      await tester.tap(find.byKey(const Key('import-confirm')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Importing…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('import-confirm')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      server.holds['POST ${ApiConstants.leaveMonthlyCreditsImport}']!.complete();
      await tester.pumpAndSettle();
      expect(server.count('POST', ApiConstants.leaveMonthlyCreditsImport), 2); // one preview + one import
    });

    testWidgets('sample files download and save under web\'s names', (tester) async {
      await openImport(tester);
      await tap(tester, 'import-sample-csv');
      await tap(tester, 'import-sample-xlsx');
      expect(server.bodies['GET ${ApiConstants.leaveMonthlyCreditsSample}'], [
        {'format': 'csv'},
        {'format': 'xlsx'}
      ]);
      expect(saved.keys, ['monthly_leave_credit_sample.csv', 'monthly_leave_credit_sample.xlsx']);
    });
  });
}
