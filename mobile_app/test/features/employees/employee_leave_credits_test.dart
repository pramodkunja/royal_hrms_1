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
import 'package:mobile_app/features/employees/presentation/providers/leave_credit_providers.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';
import 'package:mobile_app/features/employees/presentation/widgets/leave_credits_section.dart';

// HR Employee Detail → Leave → Manage Leave Credits (web LeaveCreditsSection.tsx)
// against a stand-in for production LeaveCreditOverviewView / AdjustView /
// ReverseView (backend apps/hrms/views/leave_credits.py). Synthetic data only.

const code = 'EMP-7';
const overviewPath = '/leave/credits/$code/';
const adjustPath = '/leave/credits/$code/adjust/';
String reversePath(String id) => '/leave/credits/$code/transactions/$id/reverse/';
final thisYear = DateTime.now().year;

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> row(String type, String label, {String schedule = 'annual', num adj = 0}) => {
      'leave_type': type,
      'leave_type_label': label,
      'credit_schedule': schedule,
      'opening_or_allocated': 12.0,
      'carried_forward': 2.5,
      'manual_adjustments': adj,
      'total_credits': 14.5 + adj,
      'used': 3.0,
      'pending': 1.0,
      'remaining': 11.5 + adj,
      'available_after_pending': 10.5 + adj,
    };

Map<String, dynamic> txn(String id, num amount,
        {String type = 'adjustment', String? reverses, String? reversedBy, bool? canReverse}) =>
    {
      'id': id,
      'leave_type': 'earned',
      'year': thisYear,
      'txn_type': type,
      'month': null,
      'amount': amount,
      'total_before': 14.5,
      'total_after': 14.5 + amount,
      'reason': 'Reason for $id',
      'created_by_name': 'Hema Iyer',
      'created_at': '$thisYear-03-04T10:15:00+05:30',
      'reverses': reverses,
      'reversed_by': reversedBy,
      'can_reverse': canReverse ?? (type == 'adjustment' && reversedBy == null),
    };

class FakeServer implements HttpClientAdapter {
  List<Map<String, dynamic>> summaries = [
    row('earned', 'Earned Leave', adj: 2),
    row('casual', 'Casual Leave'),
    row('monthly_el', 'Monthly EL', schedule: 'monthly'),
  ];
  List<Map<String, dynamic>> transactions = [
    txn('aaaaaaaa-1111', 2),
    txn('bbbbbbbb-2222', -1, reversedBy: 'cccccccc-3333'),
    txn('cccccccc-3333', 1, type: 'reversal', reverses: 'bbbbbbbb-2222'),
  ];
  int currentYear = thisYear;
  int? overviewStatus;
  Completer<void>? holdOverview;
  Completer<void>? holdWrite;
  ({int status, String message})? refuseNextWrite;
  final calls = <({String method, String path, Map<String, dynamic> query, Object? body})>[];

  List<({String method, String path, Map<String, dynamic> query, Object? body})> of(String method, String path) =>
      calls.where((c) => c.method == method && c.path == path).toList();

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: Map.of(o.queryParameters), body: o.data));
    if (o.path == overviewPath && o.method == 'GET') {
      final gate = holdOverview;
      if (gate != null) await gate.future;
      final st = overviewStatus;
      if (st != null) {
        return _json(st, {
          'status': 'error',
          'message': st == 403
              ? 'Permission denied.'
              : st == 404
                  ? 'Employee not found.'
                  : 'Server exploded.',
          'data': {}
        });
      }
      final year = int.parse('${o.queryParameters['year']}');
      final type = o.queryParameters['leave_type'] as String? ??
          (summaries.isEmpty ? null : summaries.first['leave_type'] as String);
      final label = summaries.where((s) => s['leave_type'] == type).firstOrNull?['leave_type_label'] ?? type;
      return _json(200, {
        'status': 'success',
        'message': 'Leave credits retrieved.',
        'data': {
          'employee': {'employee_id': code, 'full_name': 'Pat Kumar'},
          'year': year,
          'current_year': currentYear,
          'summaries': summaries,
          'leave_type': type,
          'monthly': type == null
              ? null
              : {
                  'leave_type': type,
                  'leave_type_label': label,
                  'months': [
                    {'month': 1, 'label': 'Jan', 'credit_adjustments': 2.0, 'used': 0.0},
                    {'month': 2, 'label': 'Feb', 'credit_adjustments': 0.0, 'used': 1.5},
                  ],
                  'credit_adjustments_outside_year': 0.0,
                  'used_in_next_year_months': 0.0,
                  'used_not_itemised': 0.5,
                  'total_credit_adjustments': 2.0,
                  'total_used': 2.0,
                  'approximated_requests': 1,
                },
          'transactions': transactions.where((t) => t['leave_type'] == type).toList(),
          'assignable_leave_types': [
            {'value': 'casual', 'label': 'Casual Leave', 'credit_schedule': 'annual'},
            {'value': 'earned', 'label': 'Earned Leave', 'credit_schedule': 'annual'},
            {'value': 'sick', 'label': 'Sick Leave', 'credit_schedule': 'annual'},
            {'value': 'monthly_el', 'label': 'Monthly EL', 'credit_schedule': 'monthly'},
          ],
        },
      });
    }
    if (o.method == 'POST' && (o.path == adjustPath || o.path.endsWith('/reverse/'))) {
      final gate = holdWrite;
      if (gate != null) await gate.future;
      final refusal = refuseNextWrite;
      if (refusal != null) {
        refuseNextWrite = null;
        return _json(refusal.status, {'status': 'error', 'message': refusal.message, 'data': {}});
      }
      final adjust = o.path == adjustPath;
      return _json(201, {
        'status': 'success',
        'message': adjust ? 'Leave credits adjusted.' : 'Adjustment reversed.',
        'data': {'transaction': txn('dddddddd-4444', 1), 'duplicate': false},
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
    if (o.path == '/leave/stats/' && o.method == 'GET') {
      return _json(200, {
        'status': 'success',
        'data': {'balances': [], 'pending': 0, 'lop_days': 0, 'lop_requests': 0},
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

UserEntity user(List<String> perms, {bool superuser = false}) => UserEntity(
      id: 'hr1',
      email: 'hr@example.test',
      fullName: 'Hema Iyer',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final approver = user(['employees.view', 'leave.view', 'leave.approve']);
final viewer = user(['employees.view', 'leave.view']);

late FakeServer server;
late ProviderContainer container;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

/// The section alone, as the Leave tab mounts it (annual schedule).
Future<void> pumpSection(WidgetTester tester, {UserEntity? as, FakeServer? with_, bool settle = true}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? FakeServer();
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? approver),
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          // Mounted once the signed-in user is known, as on the real screen.
          if (ref.watch(authStateProvider).valueOrNull == null) return const SizedBox();
          return const SingleChildScrollView(child: LeaveCreditsSection(employeeId: code));
        }),
      ),
    ),
  ));
  container = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  if (settle) await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

String confirmText(WidgetTester tester) => tester
    .widget<RichText>(find.descendant(of: byKey('leave-credit-confirm-text'), matching: find.byType(RichText)))
    .text
    .toPlainText();

Future<void> fillAdjust(WidgetTester tester, {String? type, required String amount, required String reason}) async {
  if (type != null) {
    await tester.tap(byKey('leave-credit-type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(type).last);
    await tester.pumpAndSettle();
  }
  await tester.enterText(byKey('leave-credit-amount'), amount);
  await tester.enterText(byKey('leave-credit-reason'), reason);
  await tester.tap(byKey('leave-credit-review'));
  await tester.pumpAndSettle();
}

Future<void> openHistory(WidgetTester tester) async {
  await tester.tap(byKey('leave-credit-history-toggle'));
  await tester.pumpAndSettle();
}

String message(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: byKey('leave-credit-message'), matching: find.byType(Text)))
    .map((t) => t.data)
    .join();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('statement', () {
    testWidgets('1. loads the credit statement for this employee code and the current year', (tester) async {
      await pumpSection(tester);
      final gets = server.of('GET', overviewPath);
      expect(gets, hasLength(1));
      expect(gets.single.query, {'year': thisYear});
      expect(byKey('leave-credits-section'), findsOneWidget);
      expect(find.text('Manage Leave Credits'), findsOneWidget);
      // Annual view only, as web's schedule="annual" filter.
      expect(byKey('leave-credit-row-earned'), findsOneWidget);
      expect(byKey('leave-credit-row-casual'), findsOneWidget);
      expect(byKey('leave-credit-row-monthly_el'), findsNothing);
      final earned = byKey('leave-credit-row-earned');
      for (final v in ['Earned Leave', '12', '2.5', '+2', '16.5', '3', '1', '13.5']) {
        expect(find.descendant(of: earned, matching: find.text(v)), findsOneWidget, reason: v);
      }
      expect(find.textContaining('* Credited before adjustment history began'), findsOneWidget);
      // Next year is not reachable past the server's current year.
      expect(tester.widget<IconButton>(byKey('leave-credit-year-next')).onPressed, isNull);
    });

    testWidgets('2. loading state while the statement is on its way', (tester) async {
      final s = FakeServer()..holdOverview = Completer();
      await pumpSection(tester, with_: s, settle: false);
      await tester.pump();
      expect(byKey('leave-credit-loading'), findsOneWidget);
      expect(byKey('leave-credit-adjust-form'), findsNothing);
      s.holdOverview!.complete();
      await tester.pumpAndSettle();
      expect(byKey('leave-credit-loading'), findsNothing);
      expect(byKey('leave-credit-row-earned'), findsOneWidget);
    });

    testWidgets('3. empty states: no balances, and no annual types', (tester) async {
      await pumpSection(tester, with_: FakeServer()..summaries = []);
      expect(find.text('No leave balances for $thisYear.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpSection(tester,
          with_: FakeServer()..summaries = [row('monthly_el', 'Monthly EL', schedule: 'monthly')]);
      expect(find.text('No annual leave types for $thisYear.'), findsOneWidget);
    });

    testWidgets('4. error state shows the server message; Retry fetches again', (tester) async {
      final s = FakeServer()..overviewStatus = 500;
      await pumpSection(tester, with_: s);
      expect(find.descendant(of: byKey('leave-credit-load-error'), matching: find.text('Server exploded.')),
          findsOneWidget);
      s.overviewStatus = null;
      await tester.tap(byKey('leave-credit-retry'));
      await tester.pumpAndSettle();
      expect(server.of('GET', overviewPath), hasLength(2));
      expect(byKey('leave-credit-row-earned'), findsOneWidget);
    });

    testWidgets('5. previous year and row selection refetch with year / leave_type', (tester) async {
      await pumpSection(tester);
      await tester.tap(byKey('leave-credit-row-casual'));
      await tester.pumpAndSettle();
      expect(server.of('GET', overviewPath).last.query, {'year': thisYear, 'leave_type': 'casual'});
      expect(find.text('Adjustment history — Casual Leave, $thisYear'), findsOneWidget);
      await tester.tap(byKey('leave-credit-year-prev'));
      await tester.pumpAndSettle();
      expect(server.of('GET', overviewPath).last.query, {'year': thisYear - 1, 'leave_type': 'casual'});
      expect(tester.widget<IconButton>(byKey('leave-credit-year-next')).onPressed, isNotNull);
    });

    testWidgets('6. monthly view lists months, extra rows, total and the approximation note', (tester) async {
      await pumpSection(tester);
      await tester.tap(byKey('leave-credit-monthly-toggle'));
      await tester.pumpAndSettle();
      final table = byKey('leave-credit-monthly-table');
      for (final t in [
        'Jan',
        '+2',
        'Feb',
        '1.5',
        'Used before history / not linked to a leave request',
        '0.5',
        'Total'
      ]) {
        expect(find.descendant(of: table, matching: find.text(t)), findsWidgets, reason: t);
      }
      expect(find.textContaining('1 leave request(s) no longer fall on any working day'), findsOneWidget);
    });
  });

  group('permissions', () {
    testWidgets('7. without leave.approve the section is hidden and nothing is requested', (tester) async {
      await pumpSection(tester, as: viewer);
      expect(byKey('leave-credits-section'), findsNothing);
      expect(server.of('GET', overviewPath), isEmpty);
      // settings.edit alone does not pass the server's has_perm('leave.approve').
      await tester.pumpWidget(const SizedBox());
      await pumpSection(tester, as: user(['settings.edit', 'employees.view']));
      expect(byKey('leave-credits-section'), findsNothing);
      expect(server.of('GET', overviewPath), isEmpty);
      // A superuser passes.
      await tester.pumpWidget(const SizedBox());
      await pumpSection(tester, as: user([], superuser: true));
      expect(byKey('leave-credits-section'), findsOneWidget);
    });

    testWidgets('8. a 403 or 404 from the server hides the section, as web', (tester) async {
      for (final st in [403, 404]) {
        await pumpSection(tester, with_: FakeServer()..overviewStatus = st);
        expect(server.of('GET', overviewPath), hasLength(1));
        expect(byKey('leave-credits-section'), findsNothing, reason: '$st');
        expect(byKey('leave-credit-adjust-form'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    });

    test('9. the service refuses adjust and reverse without leave.approve, before any request', () async {
      for (final u in [
        viewer,
        user(['settings.edit'])
      ]) {
        server = FakeServer();
        final c = ProviderContainer(overrides: overrides(u));
        addTearDown(c.dispose);
        await c.read(authStateProvider.future);
        final svc = c.read(leaveCreditServiceProvider);
        await expectLater(
          svc.adjust(
              employeeId: code, leaveType: 'earned', year: thisYear, amount: 2, reason: 'x', idempotencyKey: 'k1'),
          throwsA(isA<LeaveCreditDenied>()),
        );
        await expectLater(
          svc.reverse(employeeId: code, txnId: 'aaaaaaaa-1111', reason: 'x', idempotencyKey: 'k2'),
          throwsA(isA<LeaveCreditDenied>()),
        );
        expect(server.calls, isEmpty);
        expect(leaveCreditError(const LeaveCreditDenied()), 'Permission denied.');
      }
    });

    test('10. one write at a time: a second call while one runs is refused before any request', () async {
      server = FakeServer()..holdWrite = Completer();
      final c = ProviderContainer(overrides: overrides(approver));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final svc = c.read(leaveCreditServiceProvider);
      final first = svc.adjust(
          employeeId: code, leaveType: 'earned', year: thisYear, amount: 2, reason: 'x', idempotencyKey: 'k1');
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        svc.reverse(employeeId: code, txnId: 'aaaaaaaa-1111', reason: 'x', idempotencyKey: 'k2'),
        throwsA(isA<LeaveCreditBusy>()),
      );
      server.holdWrite!.complete();
      expect(await first, 'Leave credits adjusted.');
      expect(server.calls.where((x) => x.method == 'POST'), hasLength(1));
    });

    testWidgets(
        '11. the adjust form hides for a year after the server\'s current year; ineligible rows never '
        'offer Reverse', (tester) async {
      await pumpSection(tester);
      expect(byKey('leave-credit-adjust-form'), findsOneWidget);
      await openHistory(tester);
      expect(byKey('leave-credit-reverse-aaaaaaaa-1111'), findsOneWidget);
      // Already reversed, and the reversal itself: badges, no Reverse.
      expect(byKey('leave-credit-reverse-bbbbbbbb-2222'), findsNothing);
      expect(byKey('leave-credit-reverse-cccccccc-3333'), findsNothing);
      expect(find.text('Reversed'), findsOneWidget);
      expect(find.text('Reversal of bbbbbbbb'), findsOneWidget);
      // can_reverse false from the server is honoured even for an adjustment.
      await tester.pumpWidget(const SizedBox());
      await pumpSection(tester, with_: FakeServer()..transactions = [txn('eeeeeeee-5555', 1, canReverse: false)]);
      await openHistory(tester);
      expect(byKey('leave-credit-reverse-eeeeeeee-5555'), findsNothing);
      // Server says the shown year is in the future: no adjust form, no Reverse.
      await tester.pumpWidget(const SizedBox());
      await pumpSection(tester, with_: FakeServer()..currentYear = thisYear - 1);
      expect(byKey('leave-credit-adjust-form'), findsNothing);
      await openHistory(tester);
      expect(byKey('leave-credit-reverse-aaaaaaaa-1111'), findsNothing);
    });
  });

  group('adjust', () {
    testWidgets('12. client validation, as web, sends nothing', (tester) async {
      await pumpSection(tester);
      await fillAdjust(tester, amount: '', reason: 'x');
      expect(message(tester), 'Enter a non-zero number of days, e.g. 2 or -1.5.');
      await fillAdjust(tester, amount: '0', reason: 'x');
      expect(message(tester), 'Enter a non-zero number of days, e.g. 2 or -1.5.');
      await fillAdjust(tester, amount: 'two', reason: 'x');
      expect(message(tester), 'Enter a non-zero number of days, e.g. 2 or -1.5.');
      await fillAdjust(tester, amount: '2', reason: '   ');
      expect(message(tester), 'A reason is required.');
      expect(byKey('leave-credit-confirm-panel'), findsNothing);
      expect(server.calls.where((c) => c.method == 'POST'), isEmpty);
    });

    testWidgets('13. review → confirm sends web\'s exact payload, then refreshes and clears the form', (tester) async {
      await pumpSection(tester);
      await fillAdjust(tester, type: 'Sick Leave', amount: '-1.50', reason: '  Correction  ');
      expect(confirmText(tester), 'Record -1.5 day(s) of Sick Leave for Pat Kumar in $thisYear?\nReason: Correction');
      // Review locks the form; nothing sent yet.
      expect(tester.widget<TextField>(byKey('leave-credit-amount')).enabled, isFalse);
      expect(server.calls.where((c) => c.method == 'POST'), isEmpty);
      final getsBefore = server.of('GET', overviewPath).length;

      await tester.tap(byKey('leave-credit-confirm'));
      await tester.pumpAndSettle();
      final post = server.of('POST', adjustPath).single;
      final body = Map<String, dynamic>.from(post.body as Map);
      expect(body.keys.toSet(), {'leave_type', 'year', 'amount', 'reason', 'idempotency_key'});
      expect(body['leave_type'], 'sick');
      expect(body['year'], thisYear);
      expect(body['amount'], '-1.5');
      expect(body['reason'], 'Correction');
      expect(body['idempotency_key'], matches(RegExp(r'^[0-9a-f]{32}$')));

      expect(message(tester), '-1.5 day(s) recorded for Sick Leave.');
      expect(byKey('leave-credit-confirm-panel'), findsNothing);
      expect(server.of('GET', overviewPath).length, getsBefore + 1);
      expect(tester.widget<TextField>(byKey('leave-credit-amount')).controller!.text, isEmpty);
      expect(tester.widget<TextField>(byKey('leave-credit-reason')).controller!.text, isEmpty);
    });

    testWidgets('14. defaults to the selected leave type; a positive amount is signed', (tester) async {
      await pumpSection(tester);
      await fillAdjust(tester, amount: '2', reason: 'Bonus');
      expect(confirmText(tester), startsWith('Record +2 day(s) of Earned Leave for Pat Kumar'));
      await tester.tap(byKey('leave-credit-confirm'));
      await tester.pumpAndSettle();
      final body = server.of('POST', adjustPath).single.body as Map;
      expect(body['leave_type'], 'earned');
      expect(body['amount'], '2');
      expect(message(tester), '+2 day(s) recorded for Earned Leave.');
    });

    testWidgets('15. a server validation error is shown; the retry reuses the same key and nothing refreshes',
        (tester) async {
      final s = FakeServer()..refuseNextWrite = (status: 400, message: 'Total credits cannot go below zero.');
      await pumpSection(tester, with_: s);
      await fillAdjust(tester, amount: '-50', reason: 'Too much');
      final getsBefore = s.of('GET', overviewPath).length;
      await tester.tap(byKey('leave-credit-confirm'));
      await tester.pumpAndSettle();
      expect(message(tester), 'Total credits cannot go below zero.');
      expect(byKey('leave-credit-confirm-panel'), findsOneWidget);
      expect(s.of('GET', overviewPath).length, getsBefore);
      await tester.tap(byKey('leave-credit-confirm'));
      await tester.pumpAndSettle();
      final posts = s.of('POST', adjustPath);
      expect(posts, hasLength(2));
      expect((posts[1].body as Map)['idempotency_key'], (posts[0].body as Map)['idempotency_key']);
      expect(message(tester), '-50 day(s) recorded for Earned Leave.');
    });

    testWidgets('16. a server permission error is shown', (tester) async {
      final s = FakeServer()..refuseNextWrite = (status: 403, message: 'Permission denied.');
      await pumpSection(tester, with_: s);
      await fillAdjust(tester, amount: '1', reason: 'x');
      await tester.tap(byKey('leave-credit-confirm'));
      await tester.pumpAndSettle();
      expect(message(tester), 'Permission denied.');
    });

    testWidgets('17. double-tapping Confirm sends one request; the button shows Saving…', (tester) async {
      final s = FakeServer()..holdWrite = Completer();
      await pumpSection(tester, with_: s);
      await fillAdjust(tester, amount: '1', reason: 'x');
      await tester.tap(byKey('leave-credit-confirm'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      expect(tester.widget<FilledButton>(byKey('leave-credit-confirm')).onPressed, isNull);
      await tester.tap(byKey('leave-credit-confirm'), warnIfMissed: false);
      await tester.pump();
      s.holdWrite!.complete();
      await tester.pumpAndSettle();
      expect(s.of('POST', adjustPath), hasLength(1));
    });

    testWidgets('18. Cancel on the review sends nothing and unlocks the form', (tester) async {
      await pumpSection(tester);
      await fillAdjust(tester, amount: '1', reason: 'x');
      await tester.tap(byKey('leave-credit-cancel'));
      await tester.pumpAndSettle();
      expect(byKey('leave-credit-confirm-panel'), findsNothing);
      expect(tester.widget<TextField>(byKey('leave-credit-amount')).enabled, isTrue);
      expect(server.calls.where((c) => c.method == 'POST'), isEmpty);
    });
  });

  group('reverse', () {
    Future<void> startReverse(WidgetTester tester, String reason) async {
      await openHistory(tester);
      await tester.tap(byKey('leave-credit-reverse-aaaaaaaa-1111'));
      await tester.pumpAndSettle();
      expect(find.text('Reason for reversing +2 day(s)'), findsOneWidget);
      await tester.enterText(byKey('leave-credit-reverse-reason'), reason);
      await tester.tap(byKey('leave-credit-reverse-review'));
      await tester.pumpAndSettle();
    }

    testWidgets('19. reason is required, nothing sent', (tester) async {
      await pumpSection(tester);
      await startReverse(tester, '  ');
      expect(message(tester), 'A reason is required to reverse an adjustment.');
      expect(server.calls.where((c) => c.method == 'POST'), isEmpty);
    });

    testWidgets('20. confirm posts to the transaction\'s reverse path with web\'s payload, then refreshes',
        (tester) async {
      await pumpSection(tester);
      await startReverse(tester, ' Entered twice ');
      expect(
          confirmText(tester),
          'Reverse the +2 day(s) adjustment from ${leaveCreditDateTime('$thisYear-03-04T10:15:00+05:30')}? '
          'This records a -2 day(s) entry; the original stays in history.\nReason: Entered twice');
      final getsBefore = server.of('GET', overviewPath).length;
      await tester.tap(byKey('leave-credit-confirm'));
      await tester.pumpAndSettle();
      final post = server.of('POST', reversePath('aaaaaaaa-1111')).single;
      final body = Map<String, dynamic>.from(post.body as Map);
      expect(body.keys.toSet(), {'reason', 'idempotency_key'});
      expect(body['reason'], 'Entered twice');
      expect(body['idempotency_key'], matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(message(tester), 'Adjustment reversed.');
      expect(byKey('leave-credit-reverse-reason'), findsNothing);
      expect(server.of('GET', overviewPath).length, getsBefore + 1);
    });

    testWidgets('21. a refused reversal (already reversed) shows the server message; retry keeps the key',
        (tester) async {
      final s = FakeServer()..refuseNextWrite = (status: 400, message: 'This adjustment has already been reversed.');
      await pumpSection(tester, with_: s);
      await startReverse(tester, 'Dup');
      await tester.tap(byKey('leave-credit-confirm'));
      await tester.pumpAndSettle();
      expect(message(tester), 'This adjustment has already been reversed.');
      await tester.tap(byKey('leave-credit-confirm'));
      await tester.pumpAndSettle();
      final posts = s.of('POST', reversePath('aaaaaaaa-1111'));
      expect(posts, hasLength(2));
      expect((posts[1].body as Map)['idempotency_key'], (posts[0].body as Map)['idempotency_key']);
    });

    testWidgets('21b. cancelling the review and reviewing the same reversal again keeps its key (web reverseKeyRef)',
        (tester) async {
      final s = FakeServer()..refuseNextWrite = (status: 409, message: 'Conflict.');
      await pumpSection(tester, with_: s);
      await startReverse(tester, 'Dup');
      await tester.tap(byKey('leave-credit-confirm'));
      await tester.pumpAndSettle();
      expect(message(tester), 'Conflict.');
      await tester.tap(byKey('leave-credit-cancel'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('leave-credit-reverse-review'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('leave-credit-confirm'));
      await tester.pumpAndSettle();
      final posts = s.of('POST', reversePath('aaaaaaaa-1111'));
      expect(posts, hasLength(2));
      expect((posts[1].body as Map)['idempotency_key'], (posts[0].body as Map)['idempotency_key']);
      expect(message(tester), 'Adjustment reversed.');
    });
  });

  group('Employee Detail', () {
    Future<void> pumpDetail(WidgetTester tester, UserEntity u) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // The existing balance cards (employee_leave_tab.dart _BalanceCard,
      // fixed 116px row, not part of this change) overflow by a few pixels
      // under the test font. Only that overflow is tolerated here.
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        final info = d.informationCollector?.call().map((n) => n.toStringDeep()).join() ?? '';
        if (d.exceptionAsString().contains('A RenderFlex overflowed') && info.contains('_BalanceCard')) return;
        original?.call(d);
      };
      addTearDown(() => FlutterError.onError = original);
      server = FakeServer();
      await tester.pumpWidget(ProviderScope(
        overrides: overrides(u),
        child: const MaterialApp(home: EmployeeProfileScreen(employeeId: code)),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
    }

    testWidgets('22. the Leave tab carries the section; a confirmed adjustment also reloads the tab', (tester) async {
      await pumpDetail(tester, approver);
      expect(byKey('leave-credits-section'), findsOneWidget);
      final statsBefore = server.of('GET', '/leave/stats/').length;
      expect(statsBefore, greaterThan(0));
      await fillAdjust(tester, amount: '1', reason: 'x');
      await tester.tap(byKey('leave-credit-confirm'));
      await tester.pumpAndSettle();
      expect(server.of('POST', adjustPath), hasLength(1));
      expect(server.of('GET', '/leave/stats/').length, greaterThan(statsBefore));
    });

    testWidgets('23. a viewer without leave.approve sees the Leave tab without the section', (tester) async {
      await pumpDetail(tester, viewer);
      expect(find.text('Leave Requests'), findsOneWidget);
      expect(byKey('leave-credits-section'), findsNothing);
      expect(server.of('GET', overviewPath), isEmpty);
    });
  });
}
