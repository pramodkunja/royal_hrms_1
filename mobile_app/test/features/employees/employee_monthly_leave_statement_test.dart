import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/data/models/employee_leave_breakdown.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';
import 'package:mobile_app/features/employees/presentation/widgets/employee_leave_tab.dart';
import 'package:mobile_app/features/employees/presentation/widgets/monthly_leave_statement.dart';
import 'package:mobile_app/features/leave/data/datasources/leave_remote_datasource.dart';
import 'package:mobile_app/features/leave/data/models/leave_models.dart';
import 'package:mobile_app/features/leave/domain/entities/leave_entity.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/leave/presentation/providers/leave_providers.dart';
import 'package:mobile_app/features/leave/presentation/widgets/leave_type_presentation.dart';
import 'package:mobile_app/features/settings/data/models/leave_policy_model.dart';

// Employee Profile → Leave → Monthly Leave Statement (web LeaveTab.tsx,
// components/leave/MonthlyLeaveStatement.tsx, lib/leaveStatement.ts) against a
// stand-in for production LeaveStatsView (GET /leave/stats/?employee_id=&year=,
// balances[].credit_schedule / statement from
// services_monthly_statement.statement_payload). Synthetic data only.

const code = 'EMP-7';
final now = DateTime.now();
final thisYear = now.year;
const _short = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> month(int m, int year,
        {double credit = 1.5,
        double used = 0,
        double pending = 0,
        double carriedIn = 0,
        double expired = 0,
        bool carryOff = true,
        bool? closed,
        double creditLeft = 0,
        double closing = 0}) =>
    {
      'month': m,
      'label': '${_short[m - 1]} $year',
      'carry_off': carryOff,
      'closed': closed ?? (year < thisYear || m < now.month),
      'carried_in': carriedIn,
      'credit': credit,
      'used': used,
      'pending': pending,
      'expired': expired,
      'credit_left': creditLeft,
      'closing': closing,
    };

/// No-carry Monthly EL for the current year: Jan has usage + expiry, the
/// current month is open with credit still usable this month only.
Map<String, dynamic> noCarryStatement() => {
      'opening': 2.0,
      'adjustments': 0.0,
      'used_not_itemised': 0.5,
      'months': [
        for (var m = 1; m <= now.month; m++)
          month(m, thisYear,
              used: m == 1 ? 1.0 : 0,
              pending: m == now.month ? 0.5 : 0,
              carriedIn: m > 1 ? 0.25 : 0,
              expired: m == 1 && now.month > 1 ? 0.5 : 0,
              creditLeft: m == now.month ? 1.0 : 0,
              closing: 2.0 + m),
      ],
      'total_credited': 1.5 * now.month,
      'total_expired': now.month > 1 ? 0.5 : 0.0,
      'total_pending': 0.5,
      'monthly_carry_forward': false,
      'monthly_rules_from': '$thisYear-03-05',
      'reconciled': false,
    };

Map<String, dynamic> carryStatement(int year, int lastMonth) => {
      'opening': 0.0,
      'adjustments': 0.0,
      'used_not_itemised': 0.0,
      'months': [for (var m = 1; m <= lastMonth; m++) month(m, year, credit: 1, carryOff: false, closing: m * 1.0)],
      'total_credited': lastMonth * 1.0,
      'total_expired': 0.0,
      'total_pending': 0.0,
      'monthly_carry_forward': true,
      'monthly_rules_from': null,
      'reconciled': true,
    };

Map<String, dynamic> bal(String type, String display, String? schedule,
        {double total = 12, double used = 2, Object? statement}) =>
    {
      'leave_type': type,
      'leave_type_display': display,
      'total_days': total,
      'used_days': used,
      'available': total - used,
      'credit_schedule': schedule,
      'statement': statement,
    };

class FakeServer implements HttpClientAdapter {
  /// Balances per requested year.
  Map<int, List<Map<String, dynamic>>> balances = {
    thisYear: [
      bal('earned', 'Earned Leave', 'annual', total: 15, used: 3),
      bal('casual', 'Casual Leave', 'annual'),
      bal('lwp', 'Leave Without Pay', 'annual'),
      bal('monthly_el', 'Monthly EL', 'monthly', total: 1.5 * now.month + 2, used: 1, statement: noCarryStatement()),
      // A monthly type whose statement the backend withheld (viewer out of scope).
      bal('monthly_cl', 'Monthly CL', 'monthly', total: 6, used: 0),
      bal('special', 'Special Leave', null, total: 4, used: 0),
    ],
    thisYear - 1: [
      bal('monthly_el', 'Monthly EL', 'monthly', total: 12, used: 0, statement: carryStatement(thisYear - 1, 12)),
    ],
  };
  int? statsStatus;
  /// GET /leave/policy/ (LeavePolicySerializer rows) and an optional failure.
  List<Map<String, dynamic>> policies = [];
  int? policyStatus;
  Completer<void>? holdStats;
  final calls = <({String method, String path, Map<String, dynamic> query})>[];

  List<Map<String, dynamic>> statsCalls() =>
      calls.where((c) => c.path == '/leave/stats/').map((c) => c.query).toList();

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: Map.of(o.queryParameters)));
    if (o.path == '/leave/stats/' && o.method == 'GET') {
      final gate = holdStats;
      if (gate != null) await gate.future;
      final st = statsStatus;
      if (st != null) return _json(st, {'status': 'error', 'message': 'Server exploded.', 'data': {}});
      final year = int.parse('${o.queryParameters['year']}');
      return _json(200, {
        'status': 'success',
        'message': 'Stats retrieved.',
        'data': {
          'total': 0,
          'pending': 1,
          'approved': 0,
          'rejected': 0,
          'cancelled': 0,
          'lop_days': 0,
          'lop_requests': 0,
          'year': year,
          'balances': balances[year] ?? [],
        },
      });
    }
    if (o.path == '/leave/policy/' && o.method == 'GET') {
      final st = policyStatus;
      if (st != null) return _json(st, {'status': 'error', 'message': 'Policy service down.', 'data': {}});
      return _json(200, {'status': 'success', 'message': 'Leave policies retrieved.', 'data': policies});
    }
    if (o.path == '/leave/requests/' && o.method == 'GET') {
      return _json(200, {
        'status': 'success',
        'data': {'count': 0, 'results': [], 'page': 1, 'total_pages': 1},
      });
    }
    if (o.path == '/employees/$code/' && o.method == 'GET') {
      return _json(200, {
        'status': 'success',
        'data': {
          'id': 'u7',
          'employee_id': code,
          'first_name': 'Pat',
          'last_name': 'Kumar',
          'full_name': 'Pat Kumar',
          'email': 'pat.kumar@example.test',
          'role': 'employee',
          'is_active': true,
          'status': 'active',
          'documents': [],
          'profile': {},
        },
      });
    }
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
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

const hr = UserEntity(
  id: 'hr1',
  email: 'hr@example.test',
  fullName: 'Hema Iyer',
  role: 'hr',
  roleDisplay: 'HR',
  mustChangePassword: false,
  permissions: ['employees.view', 'leave.view'],
  isSuperuser: false,
  onboardingStatus: 'complete',
  assessmentStatus: 'complete',
);

late FakeServer server;

Dio _dio(FakeServer s) => Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s;

Future<void> pumpLeaveTab(WidgetTester tester, {FakeServer? with_}) async {
  tester.view.physicalSize = const Size(1080, 8000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? FakeServer();
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(hr)),
      dioProvider.overrideWithValue(_dio(server)),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: const MaterialApp(home: EmployeeProfileScreen(employeeId: code)),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Leave'));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

String richText(WidgetTester tester, Finder of) => tester
    .widgetList<RichText>(find.descendant(of: of, matching: find.byType(RichText)))
    .map((t) => t.text.toPlainText())
    .join(' | ');

Future<void> openMonthly(WidgetTester tester) async {
  await tester.ensureVisible(byKey('employee-leave-view-monthly'));
  await tester.tap(byKey('employee-leave-view-monthly'));
  await tester.pumpAndSettle();
}

Future<void> prevYear(WidgetTester tester, {bool settle = true}) async {
  // The profile's pinned tab bar covers the navigator once the tab has
  // scrolled, so press it directly.
  tester.widget<IconButton>(byKey('employee-leave-year-prev')).onPressed!();
  if (settle) await tester.pumpAndSettle();
}

Future<void> pickMonth(WidgetTester tester, String label) async {
  await tester.ensureVisible(byKey('monthly-credits-month'));
  await tester.tap(byKey('monthly-credits-month'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

const _long = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ── Model ──────────────────────────────────────────────────────────────────

  group('model', () {
    test('a stats balance carries credit_schedule and the monthly statement', () {
      final m = LeaveStatsModel.fromJson({
        'pending': 0,
        'balances': [
          bal('monthly_el', 'Monthly EL', 'monthly', statement: noCarryStatement()),
          bal('earned', 'Earned Leave', 'annual'),
          bal('special', 'Special Leave', null),
          {'leave_type': 'old', 'leave_type_display': 'Old', 'total_days': '3.0', 'used_days': '1.0', 'available': '2.0'},
        ],
      });
      final el = m.balances[0];
      expect(el.creditSchedule, 'monthly');
      expect(el.statement, isNotNull);
      expect(el.statement!.months, hasLength(now.month));
      expect(el.statement!.opening, 2.0);
      expect(el.statement!.monthlyCarryForward, isFalse);
      expect(el.statement!.monthlyRulesFrom, '$thisYear-03-05');
      expect(el.statement!.reconciled, isFalse);
      expect(el.statement!.months.first.label, 'Jan $thisYear');
      expect(el.statement!.months.first.carryOff, isTrue);
      expect(m.balances[1].creditSchedule, 'annual');
      expect(m.balances[1].statement, isNull);
      expect(m.balances[2].creditSchedule, isNull, reason: 'no policy: never guessed');
      // Older payloads without the fields (and Decimal strings) still parse.
      expect(m.balances[3].creditSchedule, isNull);
      expect(m.balances[3].statement, isNull);
      expect(m.balances[3].available, 2.0);
    });
  });

  // ── Datasource / provider ──────────────────────────────────────────────────

  group('datasource and provider', () {
    test('GET /leave/stats/ with this employee code and year; statement parsed', () async {
      final s = FakeServer();
      final stats = await LeaveRemoteDataSource(_dio(s)).fetchEmployeeLeaveStats(employeeId: code, year: thisYear);
      expect(s.statsCalls().single, {'employee_id': code, 'year': thisYear});
      expect(stats.balances.firstWhere((b) => b.leaveTypeCode == 'monthly_el').statement, isNotNull);
      expect(stats.balances.firstWhere((b) => b.leaveTypeCode == 'monthly_cl').statement, isNull);
    });

    test('the provider is keyed by employee and year — each key fetches its own figures', () async {
      final s = FakeServer();
      final c = ProviderContainer(overrides: [
        dioProvider.overrideWithValue(_dio(s)),
        cookieJarProvider.overrideWithValue(CookieJar()),
        secureStorageProvider.overrideWithValue(_NullStorage()),
      ]);
      addTearDown(c.dispose);
      final subs = [
        c.listen(employeeLeaveStatsProvider((code, thisYear)), (_, __) {}),
        c.listen(employeeLeaveStatsProvider((code, thisYear - 1)), (_, __) {}),
        c.listen(employeeLeaveStatsProvider(('EMP-8', thisYear)), (_, __) {}),
      ];
      final a = await c.read(employeeLeaveStatsProvider((code, thisYear)).future);
      final b = await c.read(employeeLeaveStatsProvider((code, thisYear - 1)).future);
      await c.read(employeeLeaveStatsProvider(('EMP-8', thisYear)).future);
      expect(a.balances.length, 6);
      expect(b.balances.single.statement!.months, hasLength(12));
      expect(s.statsCalls(), [
        {'employee_id': code, 'year': thisYear},
        {'employee_id': code, 'year': thisYear - 1},
        {'employee_id': 'EMP-8', 'year': thisYear},
      ]);
      for (final x in subs) {
        x.close();
      }
    });
  });

  // ── Display helpers (web lib/leaveStatement.ts) ────────────────────────────

  group('helpers', () {
    LeaveStatement stmt(Map<String, dynamic> j) => LeaveStatement.fromJson(j)!;

    test('monthLines: carried in / pending only when non-zero, expired only for no-carry months', () {
      final full = LeaveStatementMonth.fromJson(
          month(2, 2026, carriedIn: 0.5, used: 1, pending: 0.5, expired: 0.5, closing: 3, carryOff: true));
      expect(statementMonthLines(full).map((l) => l.key),
          ['carried_in', 'credit', 'used', 'pending', 'expired', 'closing']);
      expect(statementMonthLines(full).map((l) => l.label),
          ['Carried in', 'Credited', 'Used', 'Pending', 'Expired', 'Balance']);
      expect(statementMonthLines(full)[4].tone, StatementTone.error);
      expect(statementMonthLines(full).last.tone, StatementTone.strong);
      final bare = LeaveStatementMonth.fromJson(month(2, 2026, carryOff: false, closing: 1.5));
      expect(statementMonthLines(bare).map((l) => l.key), ['credit', 'used', 'closing']);
      final noExpiry = LeaveStatementMonth.fromJson(month(2, 2026, carryOff: true));
      expect(statementMonthLines(noExpiry).firstWhere((l) => l.key == 'expired').tone, StatementTone.normal);
    });

    test('scheduleChip', () {
      expect(statementScheduleChip(stmt(noCarryStatement())), 'Monthly · unused credit expires at month end');
      expect(statementScheduleChip(stmt(carryStatement(2025, 1))), 'Monthly · unused credit carries forward');
      expect(statementScheduleChip(stmt({...carryStatement(2025, 1), 'monthly_carry_forward': null})),
          'Monthly · unused credit carries forward', reason: 'only an explicit false means expiry');
    });

    test('statementNotes: every web note, in web order; en-IN date', () {
      expect(statementNotes(stmt(noCarryStatement()), thisYear), [
        '2 day(s) from opening balance, carry forward or adjustments are included and never expire.',
        "The current monthly rules apply from 5 Mar $thisYear; earlier months aren't recalculated.",
        "0.5 day(s) used aren't linked to a month (for example, an imported opening balance).",
        'Month-end processing for a past month is still due; the yearly balance is current.',
      ]);
      final none = {
        ...carryStatement(2025, 2),
        'months': [month(1, 2025, credit: 0, carryOff: false)],
        'monthly_rules_from': '2027-01-01',
      };
      expect(statementNotes(stmt(none), 2025), [
        'No monthly credits are recorded for 2025.',
        'Monthly rules apply from 2027; this year follows the balance as it was recorded.',
      ]);
      // Rules from January of the year, or from an earlier year: no note.
      expect(statementNotes(stmt({...carryStatement(2025, 1), 'monthly_rules_from': '2025-01-01'}), 2025), isEmpty);
      expect(statementNotes(stmt({...carryStatement(2025, 1), 'monthly_rules_from': '2024-06-01'}), 2025), isEmpty);
      // en-IN prints September as "Sept".
      expect(statementNotes(stmt({...carryStatement(2025, 1), 'monthly_rules_from': '2025-09-15'}), 2025).single,
          "The current monthly rules apply from 15 Sept 2025; earlier months aren't recalculated.");
    });

    test('splitBySchedule keeps unknown schedules apart', () {
      const rows = [
        BalanceSummaryEntity(
            leaveTypeCode: 'a', leaveTypeDisplay: 'A', totalDays: 1, usedDays: 0, available: 1, creditSchedule: 'annual'),
        BalanceSummaryEntity(
            leaveTypeCode: 'm', leaveTypeDisplay: 'M', totalDays: 1, usedDays: 0, available: 1, creditSchedule: 'monthly'),
        BalanceSummaryEntity(leaveTypeCode: 'x', leaveTypeDisplay: 'X', totalDays: 1, usedDays: 0, available: 1),
        BalanceSummaryEntity(
            leaveTypeCode: 'y', leaveTypeDisplay: 'Y', totalDays: 1, usedDays: 0, available: 1, creditSchedule: 'weekly'),
      ];
      final g = splitBySchedule(rows);
      expect(g.annual.map((r) => r.leaveTypeCode), ['a']);
      expect(g.monthly.map((r) => r.leaveTypeCode), ['m']);
      expect(g.unclassified.map((r) => r.leaveTypeCode), ['x', 'y']);
    });

    test('defaultMonth, monthOf and month option labels', () {
      final today = DateTime(2026, 11, 11);
      expect(defaultStatementMonth(2026, today), 11);
      expect(defaultStatementMonth(2025, today), 12);
      expect(defaultStatementMonth(2027, today), 1);
      final s = stmt(carryStatement(2025, 3));
      expect(statementMonthOf(s, 2)!.label, 'Feb 2025');
      expect(statementMonthOf(s, 7), isNull);
      expect(statementMonthOf(null, 1), isNull);
      expect(statementMonthOptionLabel(2026, 10), 'October 2026');
      expect(statementMonthOptionLabel(2026, 1), 'January 2026');
    });
  });

  // ── Widget: Employee Profile → Leave ───────────────────────────────────────

  group('Leave tab', () {
    testWidgets('1. annual view by default: annual types only, LWP excluded, counts, unclassified warning',
        (tester) async {
      await pumpLeaveTab(tester);
      expect(find.text('Annual leave (2)'), findsOneWidget);
      expect(find.text('Monthly leave (2)'), findsOneWidget);
      expect(find.text("Grouped by each leave type's credit schedule in Leave Policy."), findsOneWidget);
      expect(byKey('employee-leave-card-earned'), findsOneWidget);
      expect(byKey('employee-leave-card-casual'), findsOneWidget);
      expect(byKey('employee-leave-card-lwp'), findsNothing, reason: 'LOP has its own card');
      expect(byKey('employee-leave-card-monthly_el'), findsNothing);
      expect(find.text('of 15 days left'), findsOneWidget);
      expect(
          find.text("No leave policy found for: Special Leave (4 available). These aren't shown as annual or monthly — "
              'check Settings → Leave Management → Leave Types.'),
          findsOneWidget);
      expect(byKey('monthly-credits-table'), findsNothing);
      expect(byKey('leave-statement-monthly_el'), findsNothing);
      expect(find.text('Awaiting approval'), findsOneWidget);
    });

    testWidgets('2. monthly view: cards, Monthly Leave Credits for the current month, statements', (tester) async {
      await pumpLeaveTab(tester);
      await openMonthly(tester);
      final cur = now.month;
      final curLabel = '${_short[cur - 1]} $thisYear';

      expect(byKey('employee-leave-card-earned'), findsNothing);
      expect(byKey('employee-leave-card-monthly_el'), findsOneWidget);
      expect(
          tester
              .widget<Text>(find.descendant(
                  of: byKey('employee-leave-card-monthly_el'), matching: byKey('employee-leave-monthly-sub')))
              .data,
          'available now · 1.5 credited in $curLabel · ${formatLeaveNumber(1.5 * cur)} in $thisYear');
      expect(
          tester
              .widget<Text>(find.descendant(
                  of: byKey('employee-leave-card-monthly_cl'), matching: byKey('employee-leave-monthly-sub')))
              .data,
          'available now',
          reason: 'no statement: no month credit, no yearly credited figure');

      // Month selector defaults to the current month.
      expect(find.text('${_long[cur - 1]} $thisYear'), findsOneWidget);
      final row = byKey('monthly-credits-row-monthly_el');
      String cells(Finder r) =>
          tester.widgetList<Text>(find.descendant(of: r, matching: find.byType(Text))).map((t) => t.data).join(',');
      expect(cells(row),
          'Monthly EL,${cur > 1 ? '0.25' : '—'},1.5,—,0.5,—,${formatLeaveNumber(2.0 + cur)}');
      expect(find.text("Monthly breakdown isn't available to you for this employee."), findsOneWidget);
      expect(byKey('monthly-credits-message-monthly_cl'), findsOneWidget);

      // Statements: only for types with one; the first open by default.
      expect(byKey('leave-statement-monthly_el'), findsOneWidget);
      expect(byKey('leave-statement-monthly_cl'), findsNothing);
      expect(find.text('Monthly EL — $thisYear'), findsOneWidget);
      expect(find.text('Monthly · unused credit expires at month end'), findsOneWidget);
      expect(find.text('Month-end processing for a past month is still due; the yearly balance is current.'),
          findsOneWidget);
      for (var m = 1; m <= cur; m++) {
        expect(find.byKey(ValueKey('leave-statement-month-$m')), findsOneWidget);
      }
      // The open (current) month: "open" marker and "usable this month only".
      expect(richText(tester, find.byKey(ValueKey('leave-statement-month-$cur'))), contains('$curLabel  open'));
      expect(find.text('1 usable this month only'), findsOneWidget);
      expect(find.byKey(ValueKey('leave-statement-line-$cur-pending')), findsOneWidget);
      expect(find.byKey(ValueKey('leave-statement-line-$cur-expired')), findsOneWidget, reason: 'no-carry month');

      final total = 1.5 * cur + 2;
      expect(
          richText(tester, byKey('leave-statement-footer')),
          'Yearly balance $thisYear: credited ${formatLeaveNumber(1.5 * cur)}'
          '${cur > 1 ? ', expired 0.5' : ''}, total ${formatLeaveNumber(total)}, used 1, '
          'available ${formatLeaveNumber(total - 1)} (0.5 pending).');

      // The annual-only Manage Leave Credits section isn't part of this view.
      expect(byKey('leave-credits-section'), findsNothing);
    });

    testWidgets('3. choosing a month shows that month; a month with nothing recorded says so', (tester) async {
      await pumpLeaveTab(tester);
      await openMonthly(tester);
      if (now.month > 1) {
        await pickMonth(tester, 'January $thisYear');
        final row = byKey('monthly-credits-row-monthly_el');
        expect(
            tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))).map((t) => t.data).join(','),
            'Monthly EL,—,1.5,1,—,0.5,3');
        expect(
            tester
                .widget<Text>(find.descendant(
                    of: byKey('employee-leave-card-monthly_el'), matching: byKey('employee-leave-monthly-sub')))
                .data,
            startsWith('available now · 1.5 credited in Jan $thisYear'));
      }
      if (now.month < 12) {
        await pickMonth(tester, 'December $thisYear');
        expect(find.text('Nothing recorded for this month in $thisYear.'), findsOneWidget);
      }
      // No server call for a month change: the month is read from the statement.
      expect(server.statsCalls(), hasLength(1));
    });

    testWidgets('4. statement card collapses and expands', (tester) async {
      await pumpLeaveTab(tester);
      await openMonthly(tester);
      expect(byKey('leave-statement-footer'), findsOneWidget);
      await tester.ensureVisible(byKey('leave-statement-toggle-monthly_el'));
      await tester.tap(byKey('leave-statement-toggle-monthly_el'));
      await tester.pumpAndSettle();
      expect(byKey('leave-statement-footer'), findsNothing);
      expect(find.byKey(const ValueKey('leave-statement-month-1')), findsNothing);
      await tester.tap(byKey('leave-statement-toggle-monthly_el'));
      await tester.pumpAndSettle();
      expect(byKey('leave-statement-footer'), findsOneWidget);
    });

    testWidgets('5. previous year: refetches for that year, no stale figures while loading, December by default',
        (tester) async {
      await pumpLeaveTab(tester);
      await openMonthly(tester);
      final gate = server.holdStats = Completer<void>();
      await prevYear(tester, settle: false);
      await tester.pump();
      // Loading the new year: nothing of the current year is still shown.
      expect(byKey('monthly-credits-table'), findsNothing);
      expect(byKey('leave-statement-monthly_el'), findsNothing);
      expect(find.text('Monthly EL — $thisYear'), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(server.statsCalls().last, {'employee_id': code, 'year': thisYear - 1});
      // The view is kept; the month defaults to December for a past year.
      expect(find.text('Monthly leave (1)'), findsOneWidget);
      expect(find.text('December ${thisYear - 1}'), findsOneWidget);
      expect(find.text('Monthly EL — ${thisYear - 1}'), findsOneWidget);
      expect(find.text('Monthly · unused credit carries forward'), findsOneWidget);
      final row = byKey('monthly-credits-row-monthly_el');
      expect(
          tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))).map((t) => t.data).join(','),
          'Monthly EL,—,1,—,—,n/a,12',
          reason: 'carry-forward months have no expiry: n/a');
      expect(find.byKey(const ValueKey('leave-statement-month-12')), findsOneWidget);
      expect(find.byKey(const ValueKey('leave-statement-line-12-expired')), findsNothing);
      expect(richText(tester, find.byKey(const ValueKey('leave-statement-month-12'))), isNot(contains('open')));
      expect(find.textContaining('usable this month only'), findsNothing);
      expect(richText(tester, byKey('leave-statement-footer')),
          'Yearly balance ${thisYear - 1}: credited 12, total 12, used 0, available 12.');
    });

    testWidgets('6. a chosen month is kept across years (web keeps the month state)', (tester) async {
      await pumpLeaveTab(tester);
      await openMonthly(tester);
      await pickMonth(tester, 'March $thisYear');
      await prevYear(tester);
      await tester.pumpAndSettle();
      expect(find.text('March ${thisYear - 1}'), findsOneWidget);
      expect(
          tester
              .widget<Text>(find.descendant(
                  of: byKey('employee-leave-card-monthly_el'), matching: byKey('employee-leave-monthly-sub')))
              .data,
          'available now · 1 credited in Mar ${thisYear - 1} · 12 in ${thisYear - 1}');
    });

    testWidgets('7. empty states: no monthly types; no annual types; a statement with no months', (tester) async {
      final s = FakeServer()
        ..balances = {
          thisYear: [bal('earned', 'Earned Leave', 'annual')],
          thisYear - 1: [
            bal('monthly_el', 'Monthly EL', 'monthly',
                statement: {...carryStatement(thisYear - 1, 0), 'months': <Object>[]}),
          ],
        };
      await pumpLeaveTab(tester, with_: s);
      await openMonthly(tester);
      expect(find.text('No monthly leave types'), findsOneWidget);
      expect(
          find.text('No leave type for this employee is set to the Monthly credit schedule. Set one in Settings → '
              'Leave Management → Leave Policy → Monthly Credit Settings.'),
          findsOneWidget);
      expect(byKey('monthly-credits-table'), findsNothing);

      await prevYear(tester);
      await tester.pumpAndSettle();
      expect(find.text('No months to show for ${thisYear - 1} yet.'), findsOneWidget);
      expect(find.text('No monthly credits are recorded for ${thisYear - 1}.'), findsOneWidget);
      expect(find.text('Nothing recorded for this month in ${thisYear - 1}.'), findsOneWidget);

      await tester.ensureVisible(byKey('employee-leave-view-annual'));
      await tester.tap(byKey('employee-leave-view-annual'));
      await tester.pumpAndSettle();
      expect(find.text('No annual leave types'), findsOneWidget);
      expect(
          find.text('Every leave type for this employee is on the Monthly credit schedule — see the Monthly leave view.'),
          findsOneWidget);
    });

    testWidgets('8. stats error: web\'s alert with the server message replaces the leave sections; Retry recovers',
        (tester) async {
      final s = FakeServer()..statsStatus = 500;
      await pumpLeaveTab(tester, with_: s);
      expect(byKey('employee-leave-stats-error'), findsOneWidget);
      expect(tester.widget<Text>(byKey('employee-leave-stats-error-message')).data, 'Server exploded.');
      // Like web, nothing that depends on the stats is shown (no zero counts,
      // no empty-state claims, no credits/monthly sections)...
      expect(byKey('employee-leave-view-annual'), findsNothing);
      expect(find.textContaining('No annual leave types'), findsNothing);
      expect(byKey('leave-credits-section'), findsNothing);
      expect(byKey('monthly-credits-table'), findsNothing);
      // ...but the year navigator and the separately loaded requests stay.
      expect(byKey('employee-leave-year-prev'), findsOneWidget);
      expect(find.text('Leave Requests'), findsOneWidget);
      expect(find.text('No leave requests found for $thisYear.'), findsOneWidget);

      final before = s.statsCalls().length;
      s.statsStatus = null;
      final gate = s.holdStats = Completer<void>();
      await tester.tap(byKey('employee-leave-stats-retry'));
      await tester.pump();
      // While the retry is on its way: an indicator instead of the button.
      expect(byKey('employee-leave-stats-retrying'), findsOneWidget);
      expect(byKey('employee-leave-stats-retry'), findsNothing);
      gate.complete();
      s.holdStats = null;
      await tester.pumpAndSettle();
      expect(s.statsCalls().length, before + 1);
      expect(byKey('employee-leave-stats-error'), findsNothing);
      await openMonthly(tester);
      expect(byKey('monthly-credits-table'), findsOneWidget);
      expect(byKey('leave-statement-monthly_el'), findsOneWidget);
    });

    testWidgets('8b. a failed year shows the error; going back to a good year shows its figures', (tester) async {
      await pumpLeaveTab(tester);
      server.statsStatus = 500;
      await prevYear(tester);
      expect(byKey('employee-leave-stats-error'), findsOneWidget);
      expect(byKey('employee-leave-card-earned'), findsNothing, reason: 'no figures from the other year');
      server.statsStatus = null;
      tester.widget<IconButton>(byKey('employee-leave-year-next')).onPressed!();
      await tester.pumpAndSettle();
      expect(byKey('employee-leave-stats-error'), findsNothing);
      expect(byKey('employee-leave-card-earned'), findsOneWidget);
    });

    testWidgets('9. viewer the backend withholds statements from: every monthly row says so, no statement cards',
        (tester) async {
      final s = FakeServer();
      s.balances[thisYear] = [
        for (final b in s.balances[thisYear]!) {...b, 'statement': null},
      ];
      await pumpLeaveTab(tester, with_: s);
      await openMonthly(tester);
      expect(find.text("Monthly breakdown isn't available to you for this employee."), findsNWidgets(2));
      expect(byKey('leave-statement-monthly_el'), findsNothing);
      expect(byKey('leave-statement-footer'), findsNothing);
    });

    testWidgets('10. several statements: only the first is open by default', (tester) async {
      final s = FakeServer();
      s.balances[thisYear] = [
        bal('monthly_el', 'Monthly EL', 'monthly', statement: noCarryStatement()),
        bal('monthly_sl', 'Monthly SL', 'monthly', statement: carryStatement(thisYear, now.month)),
      ];
      await pumpLeaveTab(tester, with_: s);
      await openMonthly(tester);
      expect(byKey('leave-statement-monthly_el'), findsOneWidget);
      expect(byKey('leave-statement-monthly_sl'), findsOneWidget);
      expect(byKey('leave-statement-footer'), findsOneWidget, reason: 'second card collapsed');
      expect(find.descendant(of: byKey('leave-statement-monthly_el'), matching: byKey('leave-statement-footer')),
          findsOneWidget);
      await tester.ensureVisible(byKey('leave-statement-toggle-monthly_sl'));
      await tester.tap(byKey('leave-statement-toggle-monthly_sl'));
      await tester.pumpAndSettle();
      expect(byKey('leave-statement-footer'), findsNWidgets(2));
    });

    testWidgets('11. another employee: fetched by their code, the chosen month resets', (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      server = FakeServer();
      EmployeeModel emp(String c) => EmployeeModel.fromJson(
          {'id': 'u-$c', 'employee_id': c, 'first_name': 'A', 'last_name': 'B', 'full_name': 'A B', 'email': ''});
      final current = ValueNotifier(emp(code));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => _Auth(hr)),
          dioProvider.overrideWithValue(_dio(server)),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullStorage()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<EmployeeModel>(
              valueListenable: current,
              builder: (_, e, __) => EmployeeLeaveTab(employee: e),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await openMonthly(tester);
      final other = now.month == 3 ? 'April' : 'March';
      await pickMonth(tester, '$other $thisYear');
      expect(find.text('$other $thisYear'), findsOneWidget);
      // Same balances for the other code in this stand-in; what matters is the
      // request and the reset selection.
      current.value = emp('EMP-8');
      await tester.pumpAndSettle();
      expect(server.statsCalls().last, {'employee_id': 'EMP-8', 'year': thisYear});
      expect(find.text('${_long[now.month - 1]} $thisYear'), findsOneWidget);
    });

    // ── Leave type presentation (web buildLeaveTypesList / LeaveTab) ──────────

    FakeServer customServer() => FakeServer()
      ..balances = {
        thisYear: [
          bal('casual', 'Casual Leave', 'annual'),
          bal('maternity', 'Maternity Leave', 'annual', total: 90, used: 0),
          // Production LeaveBalance.get_leave_type_display() returns the raw
          // code for custom types (not in LEAVE_TYPE_CHOICES).
          bal('mestrual_leave', 'mestrual_leave', 'annual', total: 6, used: 1),
          bal('old_custom', 'old_custom', 'annual', total: 2, used: 0),
          bal('comp_off', 'comp_off', 'monthly', total: 3, used: 0, statement: carryStatement(thisYear, now.month)),
          bal('floater', 'floater', null, total: 1, used: 0),
        ],
      }
      ..policies = [
        {'id': 1, 'leave_type': 'casual', 'leave_type_display': 'Renamed Casual', 'is_active': true},
        {'id': 2, 'leave_type': 'mestrual_leave', 'leave_type_display': 'Pink Leave', 'is_active': true},
        {'id': 3, 'leave_type': 'old_custom', 'leave_type_display': 'Retired Leave', 'is_active': false},
        {'id': 4, 'leave_type': 'comp_off', 'leave_type_display': 'Compensatory Off', 'is_active': true,
          'credit_schedule': 'monthly'},
      ];

    Icon cardIcon(WidgetTester tester, String type) => tester.widget<Icon>(find
        .descendant(of: byKey('employee-leave-card-$type'), matching: find.byType(Icon))
        .last);

    testWidgets('12. custom types: Leave Policy label, web\'s neutral icon and colour; built-ins keep theirs',
        (tester) async {
      final s = customServer();
      await pumpLeaveTab(tester, with_: s);
      expect(s.calls.where((c) => c.path == '/leave/policy/'), isNotEmpty, reason: 'web fetches API.leave.policy');
      Finder label(String type, String text) =>
          find.descendant(of: byKey('employee-leave-card-$type'), matching: find.text(text));
      // Built-in: the built-in label wins over a policy rename (web LEAVE_TYPE_CONFIG first).
      expect(label('casual', 'Casual Leave'), findsOneWidget);
      expect(cardIcon(tester, 'casual').icon, Icons.check_circle_outline);
      expect(cardIcon(tester, 'casual').color, AppColors.success);
      expect(label('maternity', 'Maternity Leave'), findsOneWidget);
      expect(cardIcon(tester, 'maternity').icon, Icons.favorite_outline);
      expect(cardIcon(tester, 'maternity').color, const Color(0xFFAD95CF));
      // Active custom policy: its configured label; neutral custom styling.
      expect(label('mestrual_leave', 'Pink Leave'), findsOneWidget);
      expect(cardIcon(tester, 'mestrual_leave').icon, kCustomLeaveTypeIcon);
      expect(cardIcon(tester, 'mestrual_leave').color, kCustomLeaveTypeColor);
      // Inactive custom policy: not in web's list → the balance's own name.
      expect(label('old_custom', 'old_custom'), findsOneWidget);
      expect(cardIcon(tester, 'old_custom').color, kCustomLeaveTypeColor);
      // No policy at all: unclassified, named from the balance.
      expect(find.textContaining('No leave policy found for: floater (1 available).'), findsOneWidget);

      await openMonthly(tester);
      expect(find.descendant(of: byKey('monthly-credits-row-comp_off'), matching: find.text('Compensatory Off')),
          findsOneWidget);
      expect(find.text('Compensatory Off — $thisYear'), findsOneWidget);
      expect(cardIcon(tester, 'comp_off').icon, kCustomLeaveTypeIcon);
    });

    testWidgets('13. policy list unavailable: names fall back to the balance (as web), the tab still works',
        (tester) async {
      final s = customServer()..policyStatus = 500;
      await pumpLeaveTab(tester, with_: s);
      expect(find.descendant(of: byKey('employee-leave-card-mestrual_leave'), matching: find.text('mestrual_leave')),
          findsOneWidget);
      expect(cardIcon(tester, 'mestrual_leave').color, kCustomLeaveTypeColor);
      expect(find.descendant(of: byKey('employee-leave-card-maternity'), matching: find.text('Maternity Leave')),
          findsOneWidget);
      expect(byKey('employee-leave-stats-error'), findsNothing);
    });
  });

  group('MonthlyCreditsTable layout', () {
    testWidgets('at phone width a message row wraps inside the visible table; rows share the full width',
        (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final m = LeaveStatementMonth.fromJson(month(1, 2026, used: 1, closing: 3));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MonthlyCreditsTable(
              rows: [
                MonthlyCreditsRow(leaveType: 'a', label: 'Monthly EL', month: m, hasStatement: true),
                const MonthlyCreditsRow(leaveType: 'b', label: 'Comp Off', month: null, hasStatement: true),
                const MonthlyCreditsRow(leaveType: 'c', label: 'Monthly CL', month: null, hasStatement: false),
              ],
              year: 2026,
              month: 1,
              onMonth: (_) {},
            ),
          ),
        ),
      ));
      final table = tester.getRect(byKey('monthly-credits-table'));
      for (final k in ['b', 'c']) {
        final msg = tester.getRect(byKey('monthly-credits-message-$k'));
        expect(msg.right, lessThanOrEqualTo(table.right), reason: 'message $k is not cut off by the screen edge');
      }
      final widths = ['a', 'b', 'c'].map((k) => tester.getSize(find.byKey(ValueKey('monthly-credits-row-$k'))).width);
      expect(widths.toSet(), hasLength(1), reason: 'row dividers span the whole table');
      expect(tester.takeException(), isNull);
    });
  });

  group('resolveLeaveTypePresentation', () {
    LeavePolicyModel policy(String type, String display, {bool active = true}) =>
        LeavePolicyModel.fromJson({'id': 1, 'leave_type': type, 'leave_type_display': display, 'is_active': active});

    test('built-in, active custom, inactive custom, unknown, empty names', () {
      final policies = [
        policy('sick', 'Renamed Sick'),
        policy('pink', 'Pink Leave'),
        policy('gone', 'Gone Leave', active: false),
        policy('blank', ''),
      ];
      final sick = resolveLeaveTypePresentation(code: 'sick', balanceDisplay: 'x', policies: policies);
      expect((sick.label, sick.builtin, sick.color), ('Sick Leave', true, const Color(0xFF0E7C86)));
      final pink = resolveLeaveTypePresentation(code: 'pink', balanceDisplay: 'pink', policies: policies);
      expect((pink.label, pink.builtin, pink.icon, pink.color),
          ('Pink Leave', false, kCustomLeaveTypeIcon, kCustomLeaveTypeColor));
      expect(resolveLeaveTypePresentation(code: 'gone', balanceDisplay: 'gone', policies: policies).label, 'gone');
      expect(resolveLeaveTypePresentation(code: 'blank', balanceDisplay: 'Blank', policies: policies).label, 'blank',
          reason: 'web: policy.leave_type_display || policy.leave_type');
      expect(resolveLeaveTypePresentation(code: 'x', balanceDisplay: '', policies: null).label, 'x');
      expect(resolveLeaveTypePresentation(code: 'x', balanceDisplay: 'X Leave').label, 'X Leave');
      expect(pink.background, kCustomLeaveTypeColor.withValues(alpha: 0.1));
      // Web CUSTOM_LEAVE_TYPE_DEFAULTS.color "#6b7280".
      expect(kCustomLeaveTypeColor, const Color(0xFF6B7280));
    });
  });
}
