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
import 'package:mobile_app/features/dashboard/presentation/screens/home_screen.dart';

// Employee dashboard → Leave Balances → Month-by-month (web
// EmpLeaveBalances.tsx MonthlyBreakdown/StatementTable, lib/leaveBreakdown.ts)
// from GET /dashboard/employee/leave-balances/ (production
// EmployeeLeaveBalanceView). Synthetic data only.

const balancesPath = '/dashboard/employee/leave-balances/';

/// An annual type with recorded monthly movements (no statement).
Map<String, dynamic> casual({List<Map<String, dynamic>>? months, double notItemised = 1.5}) => {
      'leave_type': 'casual',
      'total_days': 12.0,
      'used_days': 3.5,
      'remaining': 8.5,
      'carried_forward': 2.0,
      'leave_type_label': 'Casual Leave',
      'credit_schedule': 'annual',
      'monthly_carry_forward': true,
      'monthly': {
        'months': months ??
            [
              {'month': 1, 'label': 'Jan 2026', 'monthly_credit': 1.0, 'other_adjustments': 0.0, 'used': 0.0},
              {'month': 2, 'label': 'Feb 2026', 'monthly_credit': 1.0, 'other_adjustments': 0.5, 'used': 1.0},
              {'month': 3, 'label': 'Mar 2026', 'monthly_credit': 0.0, 'other_adjustments': -2.0, 'used': 1.0},
            ],
        'used_not_itemised': notItemised,
      },
      'statement': null,
    };

/// A monthly-credited type with its full statement.
Map<String, dynamic> earned({bool reconciled = true, double opening = 2.0}) => {
      'leave_type': 'el_monthly',
      'total_days': 6.0,
      'used_days': 1.0,
      'remaining': 5.0,
      'carried_forward': 0.0,
      'leave_type_label': 'Earned Leave (Monthly)',
      'credit_schedule': 'monthly',
      'monthly_carry_forward': false,
      'monthly': {
        'months': [
          {'month': 1, 'label': 'Jan 2026', 'monthly_credit': 1.0, 'other_adjustments': 0.0, 'used': 1.0},
        ],
        'used_not_itemised': 0.0,
      },
      'statement': {
        'opening': opening,
        'adjustments': 0.0,
        'used_not_itemised': 0.0,
        'months': [
          {
            'month': 1,
            'label': 'Jan 2026',
            'carry_off': true,
            'closed': true,
            'carried_in': 2.0,
            'credit': 1.0,
            'used': 1.0,
            'pending': 0.0,
            'expired': 0.5,
            'credit_left': 0.0,
            'closing': 1.5,
          },
          {
            'month': 2,
            'label': 'Feb 2026',
            'carry_off': true,
            'closed': false,
            'carried_in': 1.5,
            'credit': 1.0,
            'used': 0.0,
            'pending': 0.5,
            'expired': 0.0,
            'credit_left': 1.0,
            'closing': 2.0,
          },
        ],
        'total_credited': 2.0,
        'total_expired': 0.5,
        'total_pending': 0.5,
        'monthly_carry_forward': false,
        'monthly_rules_from': '2026-01-01',
        'reconciled': reconciled,
      },
    };

/// LWP: the server always sends an empty breakdown.
Map<String, dynamic> lwp() => {
      'leave_type': 'lwp',
      'total_days': 0.0,
      'used_days': 0.0,
      'remaining': 0.0,
      'carried_forward': 0.0,
      'leave_type_label': 'Leave Without Pay',
      'credit_schedule': 'annual',
      'monthly_carry_forward': true,
      'monthly': {'months': [], 'used_not_itemised': 0.0},
      'statement': null,
    };

class Backend implements HttpClientAdapter {
  Backend(this.balances);
  List<Map<String, dynamic>> balances;
  int status = 200;
  final paths = <String>[];

  int count(String p) => paths.where((x) => x == p).length;

  ResponseBody _r(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    paths.add(o.path);
    if (o.path == balancesPath) {
      if (status != 200) return _r(status, {'status': 'error', 'message': 'Server error.', 'data': {}});
      return _r(200, {
        'status': 'success',
        'message': 'Leave balances retrieved.',
        'data': {'year': DateTime.now().year, 'balances': balances, 'lop_days': 0.0},
      });
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
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'u1',
          email: 'emp@example.test',
          fullName: 'Test Employee',
          role: 'employee',
          roleDisplay: 'Employee',
          mustChangePassword: false,
          permissions: ['leave.view'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

late Backend backend;
final year = DateTime.now().year;

Future<void> pumpDashboard(WidgetTester tester, List<Map<String, dynamic>> balances,
    {void Function(Backend)? setup}) async {
  tester.view.physicalSize = const Size(1080, 7000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  backend = Backend(balances);
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
      authStateProvider.overrideWith(_Auth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = backend),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// The dashboard starts periodic timers; unmount before the test ends.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

final toggle = find.byKey(const Key('leave-breakdown-toggle'));

Future<void> openBreakdown(WidgetTester tester) async {
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await settle(tester);
}

Future<void> chooseType(WidgetTester tester, String type) async {
  final chip = find.byKey(Key('leave-breakdown-type-$type'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await settle(tester);
}

/// The texts of one table row, in column order.
List<String> rowTexts(WidgetTester tester, String rowKey) {
  final table = tester.widgetList<Table>(find.byType(Table)).firstWhere(
      (t) => t.children.any((r) => r.key == ValueKey(rowKey)),
      orElse: () => throw StateError('no row $rowKey'));
  final row = table.children.firstWhere((r) => r.key == ValueKey(rowKey));
  final out = <String>[];
  for (final cell in row.children) {
    final finder = find.descendant(of: find.byWidget(cell), matching: find.byType(Text));
    out.add(tester.widgetList<Text>(finder).map((t) => t.data ?? '').join(' | '));
  }
  return out;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('parsing', () {
    test('1. a complete balance: label, schedule, monthly rows and the statement', () {
      final b = EmployeeLeaveBalance.fromJson(earned());
      expect(b.leaveTypeLabel, 'Earned Leave (Monthly)');
      expect(b.creditSchedule, 'monthly');
      expect(b.monthlyCarryForward, isFalse);
      expect(b.monthly!.months.single.monthlyCredit, 1.0);
      final s = b.statement!;
      expect(s.opening, 2.0);
      expect(s.months.map((m) => m.label), ['Jan 2026', 'Feb 2026']);
      expect(s.months[0].carriedIn, 2.0);
      expect(s.months[0].expired, 0.5);
      expect(s.months[1].creditLeft, 1.0);
      expect(s.months[1].showUsableThisMonthOnly, isTrue);
      expect(s.months[0].showUsableThisMonthOnly, isFalse); // closed
      expect(s.reconciled, isTrue);
      expect(s.totalCredited, 2.0);
      expect(s.monthlyRulesFrom, '2026-01-01');
      expect(b.hasMonthlyBreakdown, isTrue);
      expect(b.scheduleLabel, 'Credited monthly · no carry forward');

      final c = EmployeeLeaveBalance.fromJson(casual());
      expect(c.statement, isNull);
      expect(c.monthly!.months.map((m) => m.label), ['Jan 2026', 'Feb 2026', 'Mar 2026']);
      expect(c.monthly!.usedNotItemised, 1.5);
      expect(c.scheduleLabel, 'Credited annually');
    });

    test('2. missing, null or odd monthly fields are safe; unknown fields kept', () {
      final old = EmployeeLeaveBalance.fromJson({
        'leave_type': 'sick',
        'total_days': 7,
        'used_days': 1,
        'remaining': 6,
        'carried_forward': 0,
        'future_field': 'kept',
      });
      expect(old.leaveTypeLabel, isNull);
      expect(old.creditSchedule, isNull);
      expect(old.monthly, isNull);
      expect(old.statement, isNull);
      expect(old.hasMonthlyBreakdown, isFalse);
      expect(old.scheduleLabel, 'Credited annually');
      expect(old.raw['future_field'], 'kept');

      final odd = EmployeeLeaveBalance.fromJson({
        'leave_type': 'x',
        'leave_type_label': '  ',
        'credit_schedule': 'monthly',
        'monthly': 'not an object',
        'statement': {
          'months': [
            {'month': '2', 'label': null, 'credit': '1.5', 'closing': null},
            'junk',
          ],
        },
      });
      expect(odd.leaveTypeLabel, isNull);
      expect(odd.monthly, isNull);
      expect(odd.statement!.months, hasLength(1));
      expect(odd.statement!.months.single.month, 2);
      expect(odd.statement!.months.single.credit, 1.5);
      expect(odd.statement!.months.single.closing, 0);
      expect(odd.statement!.reconciled, isFalse);
      expect(odd.scheduleLabel, 'Credited monthly · carries forward'); // carry-forward unknown → web default
      expect(EmployeeLeaveBalance.fromJson(lwp()).hasMonthlyBreakdown, isFalse);
    });

    test('web helpers: totals to one decimal, signed numbers, dashes for zero', () {
      final totals = leaveMonthTotals([
        const LeaveMonthRow(month: 1, label: 'a', monthlyCredit: 0.1, otherAdjustments: 0.2, used: 0.0),
        const LeaveMonthRow(month: 2, label: 'b', monthlyCredit: 0.2, otherAdjustments: -0.5, used: 1.25),
      ]);
      expect(totals.monthlyCredit, 0.3);
      expect(totals.otherAdjustments, -0.3);
      expect(totals.used, 1.3);
      expect(signedLeaveNumber(1.5), '+1.5');
      expect(signedLeaveNumber(-2), '-2');
      expect(signedLeaveNumber(0), '0');
      expect(leaveCell(0), '—');
      expect(leaveCell(2.0), '2');
      expect(formatLeaveNumber(1.25), '1.25');
    });
  });

  group('dashboard', () {
    testWidgets('collapsed by default; opens to the first type with monthly data', (tester) async {
      await pumpDashboard(tester, [casual(), earned(), lwp()]);
      expect(find.text('Month-by-month — $year'), findsOneWidget);
      expect(find.byKey(const Key('leave-monthly-table')), findsNothing);
      await openBreakdown(tester);
      // LWP has nothing to show, so no chip for it.
      expect(find.byKey(const Key('leave-breakdown-type-casual')), findsOneWidget);
      expect(find.byKey(const Key('leave-breakdown-type-el_monthly')), findsOneWidget);
      expect(find.byKey(const Key('leave-breakdown-type-lwp')), findsNothing);
      expect(find.byKey(const Key('leave-monthly-table')), findsOneWidget);
      expect(find.text('Credited annually'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('3–5. monthly credit, signed adjustments and leave used per month, and the totals', (tester) async {
      await pumpDashboard(tester, [casual()]);
      await openBreakdown(tester);
      expect(rowTexts(tester, 'leave-monthly-month-1'), ['Jan 2026', '1', '—', '—']);
      expect(rowTexts(tester, 'leave-monthly-month-2'), ['Feb 2026', '1', '+0.5', '1']);
      expect(rowTexts(tester, 'leave-monthly-month-3'), ['Mar 2026', '—', '-2', '1']);
      expect(rowTexts(tester, 'leave-monthly-total'), ['Total recorded', '2', '-1.5', '2']);
      expect(find.byKey(const Key('leave-not-itemised-note')), findsOneWidget);
      expect(find.textContaining("1.5 day(s) used aren't linked to a specific month"), findsOneWidget);
      expect(find.textContaining("Month-end balances aren't calculated for this leave type"), findsOneWidget);
      expect(find.textContaining('Yearly balance $year:'), findsOneWidget);
      expect(find.textContaining('total 12, used 3.5, available 8.5'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('6. monthly-credited type: carried in, expiry, "usable this month only", opening note', (tester) async {
      await pumpDashboard(tester, [casual(), earned()]);
      await openBreakdown(tester);
      await chooseType(tester, 'el_monthly');
      expect(find.byKey(const Key('leave-statement-table')), findsOneWidget);
      expect(find.byKey(const Key('leave-monthly-table')), findsNothing);
      expect(find.text('Credited monthly · no carry forward'), findsOneWidget);
      expect(find.textContaining('Opening 2 day(s) (opening balance, carried forward and adjustments) never expire.'),
          findsOneWidget);
      expect(rowTexts(tester, 'leave-statement-month-1'), ['Jan 2026', '2', '1', '1', '—', '0.5', '1.5']);
      expect(rowTexts(tester, 'leave-statement-month-2'),
          ['Feb 2026 | 1 usable this month only', '1.5', '1', '—', '0.5', '—', '2']);
      expect(find.textContaining('total 6, used 1, available 5'), findsOneWidget);
      expect(find.text('The month-end figures add up to this yearly balance (after pending leave).'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a statement not yet reconciled says so; zero opening has no note', (tester) async {
      await pumpDashboard(tester, [earned(reconciled: false, opening: 0)]);
      await openBreakdown(tester);
      expect(find.text('Month-end processing for a past month is still due; the yearly figure is current.'),
          findsOneWidget);
      expect(find.byKey(const Key('leave-opening-note')), findsNothing);
      await unmount(tester);
    });

    testWidgets('7. months appear in the server order with the server labels', (tester) async {
      await pumpDashboard(tester, [
        casual(months: [
          {'month': 10, 'label': 'Oct 2026', 'monthly_credit': 1.0, 'other_adjustments': 0.0, 'used': 0.0},
          {'month': 11, 'label': 'Nov 2026', 'monthly_credit': 1.0, 'other_adjustments': 0.0, 'used': 0.0},
          {'month': 12, 'label': 'Dec 2026', 'monthly_credit': 1.0, 'other_adjustments': 0.0, 'used': 0.0},
        ])
      ]);
      await openBreakdown(tester);
      final ys = [
        for (final l in ['Oct 2026', 'Nov 2026', 'Dec 2026'])
          tester
              .getTopLeft(find.descendant(of: find.byKey(const Key('leave-monthly-table')), matching: find.text(l)))
              .dy
      ];
      expect(ys[0], lessThan(ys[1]));
      expect(ys[1], lessThan(ys[2]));
      await unmount(tester);
    });

    testWidgets('8. no monthly data anywhere: no breakdown section at all', (tester) async {
      await pumpDashboard(tester, [
        lwp(),
        {...casual(), 'monthly': null},
        {'leave_type': 'sick', 'total_days': 7, 'used_days': 0, 'remaining': 7, 'carried_forward': 0},
      ]);
      expect(toggle, findsNothing);
      expect(find.textContaining('Month-by-month'), findsNothing);
      // Nothing extra: no notice about unitemised use either.
      expect(find.byKey(const Key('leave-not-itemised-note')), findsNothing);
      await unmount(tester);
    });

    testWidgets('9. a failed load shows Retry; Retry loads the balances and the breakdown', (tester) async {
      await pumpDashboard(tester, [casual()], setup: (b) => b.status = 500);
      expect(toggle, findsNothing);
      final retry = find.descendant(
          of: find.ancestor(of: find.textContaining('Leave Balances'), matching: find.byType(Container)).first,
          matching: find.text('Retry'));
      expect(retry, findsOneWidget);
      backend.status = 200;
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await settle(tester);
      expect(toggle, findsOneWidget);
      expect(backend.count(balancesPath), 2);
      await unmount(tester);
    });

    testWidgets('10. the balance cards are unchanged, now with the server label for custom types', (tester) async {
      await pumpDashboard(tester, [
        casual(),
        {
          'leave_type': 'wellness',
          'total_days': 4.0,
          'used_days': 0.0,
          'remaining': 4.0,
          'carried_forward': 0.0,
          'leave_type_label': 'Wellness Leave',
        },
      ]);
      expect(find.text('Casual Leave'), findsOneWidget);
      expect(find.text('8.5'), findsOneWidget);
      expect(find.text('of 12 days'), findsOneWidget);
      expect(find.text('3.5 used · 2 carried forward'), findsOneWidget);
      expect(find.text('Wellness Leave'), findsOneWidget);
      expect(find.text('wellness'), findsNothing);
      // One request for the card; opening the breakdown asks for nothing more.
      await openBreakdown(tester);
      expect(backend.count(balancesPath), 1);
      await unmount(tester);
    });
  });
}
