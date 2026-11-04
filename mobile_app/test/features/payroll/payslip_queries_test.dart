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
import 'package:mobile_app/features/payroll/data/models/payslip_query_model.dart';
import 'package:mobile_app/features/payroll/presentation/screens/my_payslip_screen.dart';

// Phase 6 (B): payslip queries on My Payslips. The fake applies the
// production PayslipQueryListView rules: GET ?mine=1 returns the caller's
// own queries; POST {payslip, description} needs the caller's own payslip in
// "sent"/"acknowledged", before query_deadline, description 1–2000 chars,
// and moves the payslip to "queried".

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object? data) => _json(200, {'status': 'success', 'message': 'ok', 'data': data});
ResponseBody _fail(int status, String message) => _json(status, {'status': 'error', 'message': message, 'data': {}});

Map<String, dynamic> payslip(String id, String cycleStart, {String status = 'sent', String? deadline}) => {
      'id': id,
      'cycle_start': cycleStart,
      'cycle_end': cycleStart.replaceRange(8, 10, '28'),
      'pay_date': cycleStart.replaceRange(8, 10, '28'),
      'employee_name': 'Pat',
      'employee_id_code': 'EMP-1',
      'net_pay': '45000.00',
      'gross_earnings': '50000.00',
      'total_deductions': '5000.00',
      'status': status,
      'query_deadline': deadline,
    };

class FakePayrollServer implements HttpClientAdapter {
  FakePayrollServer(this.payslips, {List<Map<String, dynamic>>? queries}) : queries = queries ?? [];
  final List<Map<String, dynamic>> payslips;
  final List<Map<String, dynamic>> queries;
  final calls = <({String method, String path, Map<String, dynamic> query, Object? body})>[];
  bool canViewOwn = true;
  bool dropNextPost = false;
  bool failQueries = false;
  Completer<void>? holdPost;
  int _n = 1;

  int count(String method, String path) => calls.where((c) => c.method == method && c.path == path).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: o.queryParameters, body: o.data));
    if (o.path == '/payroll/my-payslips/' && o.method == 'GET') {
      return _ok({'count': payslips.length, 'results': payslips});
    }
    if (o.path == '/payroll/queries/' && o.method == 'GET') {
      if (failQueries) return _fail(500, 'Server error.');
      // Without mine=1 an HR user would get the HR queue — the app must ask for its own.
      if ('${o.queryParameters['mine']}' != '1') return _ok([]);
      return _ok(queries);
    }
    if (o.path == '/payroll/queries/' && o.method == 'POST') {
      if (holdPost != null) await holdPost!.future;
      if (dropNextPost) {
        dropNextPost = false;
        throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      }
      if (!canViewOwn) return _fail(403, 'You do not have permission to view payslips.');
      final body = (o.data as Map).cast<String, dynamic>();
      final id = body['payslip'];
      final text = '${body['description'] ?? ''}'.trim();
      if (id == null || text.isEmpty) return _fail(400, 'payslip and description are required.');
      if (text.length > 2000) return _fail(400, 'Please keep the query under 2000 characters.');
      final slip = payslips.where((p) => p['id'] == id).firstOrNull;
      if (slip == null) return _fail(404, 'Not found.');
      if (slip['status'] != 'sent' && slip['status'] != 'acknowledged') {
        return _fail(400, 'Queries can only be raised on sent payslips.');
      }
      final deadline = slip['query_deadline'] == null ? null : DateTime.parse(slip['query_deadline']);
      if (deadline != null && DateTime.now().isAfter(deadline)) {
        return _fail(400, 'The query window for this payslip has closed.');
      }
      final q = {
        'id': 'q${_n++}',
        'payslip': id,
        'description': text,
        'status': 'open',
        'resolution_note': '',
        'resolved_by_name': null,
        'resolved_at': null,
        'cycle_start': slip['cycle_start'],
        'created_at': '2026-11-04T10:0$_n:00Z',
      };
      queries.insert(0, q);
      slip['status'] = 'queried';
      return _json(201, {'status': 'success', 'message': 'Query raised.', 'data': q});
    }
    return _fail(404, 'Not found');
  }

  @override
  void close({bool force = false}) {}
}

class _NullSecureStorage extends SecureStorageService {
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
          email: 'e@example.com',
          fullName: 'Pat',
          role: 'employee',
          roleDisplay: 'Employee',
          mustChangePassword: false,
          permissions: ['payroll.view_own'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete'));
}

late FakePayrollServer server;

Future<void> pumpPayslips(WidgetTester tester, FakePayrollServer s) async {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = s;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullSecureStorage()),
      authStateProvider.overrideWith(_Auth.new),
    ],
    child: const MaterialApp(home: Scaffold(body: MyPayslipScreen())),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Map<String, dynamic> resolvedQuery() => {
      'id': 'q9',
      'payslip': 'p1',
      'description': 'Bonus missing',
      'status': 'resolved',
      'resolution_note': 'Bonus is paid next cycle.',
      'resolved_by_name': 'Hema HR',
      'resolved_at': '2026-11-03T12:00:00Z',
      'cycle_start': '2026-10-01',
      'created_at': '2026-11-02T09:00:00Z',
    };

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules (web lib/payslipQuery.ts)', () {
    test('parses a query row', () {
      final q = PayslipQueryModel.fromJson(resolvedQuery());
      expect((q.id, q.payslipId, q.status, q.isResolved, q.resolvedByName), ('q9', 'p1', 'resolved', true, 'Hema HR'));
      expect(q.resolutionNote, 'Bonus is paid next cycle.');
      expect(payslipQueryStatusLabel('open'), 'Open');
    });

    test('eligibility follows the payslip status and the query window', () {
      final now = DateTime.utc(2026, 11, 4);
      expect(canRaisePayslipQuery('sent', null, now: now).allowed, isTrue);
      expect(canRaisePayslipQuery('acknowledged', '2026-11-10T00:00:00Z', now: now).allowed, isTrue);
      expect(canRaisePayslipQuery('queried', null, now: now).reason, 'A query on this payslip is already open.');
      expect(canRaisePayslipQuery('draft', null, now: now).allowed, isFalse);
      expect(canRaisePayslipQuery('sent', '2026-11-01T00:00:00Z', now: now).reason,
          'The query window for this payslip has closed.');
    });

    test('text validation and per-payslip ordering', () {
      expect(validatePayslipQueryText('  '), 'Please describe your query.');
      expect(validatePayslipQueryText('x' * 2001), 'Please keep the query under 2000 characters.');
      expect(validatePayslipQueryText('Short'), isNull);
      final rows = [
        PayslipQueryModel.fromJson({...resolvedQuery(), 'id': 'a', 'created_at': '2026-11-01T00:00:00Z'}),
        PayslipQueryModel.fromJson({...resolvedQuery(), 'id': 'b', 'created_at': '2026-11-03T00:00:00Z'}),
        PayslipQueryModel.fromJson({...resolvedQuery(), 'id': 'c', 'payslip': 'p2'}),
      ];
      expect(queriesForPayslip(rows, 'p1').map((q) => q.id), ['b', 'a']);
    });
  });

  group('viewing', () {
    testWidgets('own queries are requested with mine=1 and shown with the HR response', (tester) async {
      await pumpPayslips(
          tester, FakePayrollServer([payslip('p1', '2026-10-01', status: 'resolved')], queries: [resolvedQuery()]));
      final get = server.calls.firstWhere((c) => c.method == 'GET' && c.path == '/payroll/queries/');
      expect(get.query, {'mine': 1});
      expect(find.text('Bonus missing'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.textContaining('Hema HR'), findsOneWidget);
      expect(find.text('Bonus is paid next cycle.'), findsOneWidget);
      expect(find.byKey(const Key('raise-query')), findsNothing); // resolved payslip
    });

    testWidgets('a payslip without queries says so, with the window', (tester) async {
      await pumpPayslips(tester, FakePayrollServer([payslip('p1', '2026-10-01', deadline: '2099-01-01T00:00:00Z')]));
      expect(find.textContaining('No queries on this payslip. You can raise one until'), findsOneWidget);
      expect(find.byKey(const Key('raise-query')), findsOneWidget);
    });

    testWidgets('queries belong to their payslip', (tester) async {
      await pumpPayslips(
          tester,
          FakePayrollServer([payslip('p2', '2026-11-01'), payslip('p1', '2026-10-01', status: 'resolved')],
              queries: [resolvedQuery()]));
      expect(find.text('Bonus missing'), findsNothing); // November selected first
      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
      expect(find.text('Bonus missing'), findsOneWidget);
    });

    testWidgets('no Raise Query where the server would refuse', (tester) async {
      await pumpPayslips(tester, FakePayrollServer([payslip('p1', '2026-10-01', deadline: '2020-01-01T00:00:00Z')]));
      expect(find.byKey(const Key('raise-query')), findsNothing);
      expect(find.text('The query window for this payslip has closed.'), findsOneWidget);
    });

    testWidgets('a failed load is shown with Retry', (tester) async {
      final s = FakePayrollServer([payslip('p1', '2026-10-01')])..failQueries = true;
      await pumpPayslips(tester, s);
      expect(find.text('Server error.'), findsOneWidget);
      s.failQueries = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No queries on this payslip'), findsOneWidget);
    });

    testWidgets('the payslip itself stays display-only', (tester) async {
      await pumpPayslips(tester, FakePayrollServer([payslip('p1', '2026-10-01')]));
      expect(find.byType(TextField), findsNothing); // nothing editable on the payslip
    });
  });

  group('raising a query', () {
    Future<void> openSheet(WidgetTester tester, [FakePayrollServer? s]) async {
      await pumpPayslips(tester, s ?? FakePayrollServer([payslip('p1', '2026-10-01')]));
      await tapKey(tester, 'raise-query');
    }

    testWidgets('sends exactly {payslip, description}, then lists it and locks further queries', (tester) async {
      await openSheet(tester);
      await tester.enterText(find.byKey(const Key('payslip-query-text')), '  PF deduction looks too high  ');
      await tester.pump();
      await tapKey(tester, 'payslip-query-send');
      final post = server.calls.firstWhere((c) => c.method == 'POST');
      expect(post.body, {'payslip': 'p1', 'description': 'PF deduction looks too high'});
      expect(find.text('Your query has been sent to HR.'), findsOneWidget);
      expect(find.text('PF deduction looks too high'), findsOneWidget); // reloaded list
      expect(find.text('Open'), findsOneWidget);
      expect(server.count('GET', '/payroll/my-payslips/'), 2); // payslip reloaded → queried
      expect(find.byKey(const Key('raise-query')), findsNothing);
    });

    testWidgets('empty text cannot be sent', (tester) async {
      await openSheet(tester);
      final send = find.byKey(const Key('payslip-query-send'));
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('payslip-query-text')), '   ');
      await tester.pump();
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      expect(server.count('POST', '/payroll/queries/'), 0);
    });

    testWidgets('a server refusal is shown in the sheet and the text is kept', (tester) async {
      final s = FakePayrollServer([payslip('p1', '2026-10-01')]);
      await openSheet(tester, s);
      s.payslips.single['status'] = 'queried'; // e.g. raised from another device meanwhile
      await tester.enterText(find.byKey(const Key('payslip-query-text')), 'Wrong LOP days');
      await tester.pump();
      await tapKey(tester, 'payslip-query-send');
      expect(find.text('Queries can only be raised on sent payslips.'), findsOneWidget);
      expect(find.text('Wrong LOP days'), findsOneWidget);
      expect(find.text('Your query has been sent to HR.'), findsNothing);
    });

    testWidgets('permission refusal is shown as sent by the server', (tester) async {
      final s = FakePayrollServer([payslip('p1', '2026-10-01')])..canViewOwn = false;
      await openSheet(tester, s);
      await tester.enterText(find.byKey(const Key('payslip-query-text')), 'Question');
      await tester.pump();
      await tapKey(tester, 'payslip-query-send');
      expect(find.text('You do not have permission to view payslips.'), findsOneWidget);
    });

    testWidgets('connection failure keeps the text for another try', (tester) async {
      final s = FakePayrollServer([payslip('p1', '2026-10-01')])..dropNextPost = true;
      await openSheet(tester, s);
      await tester.enterText(find.byKey(const Key('payslip-query-text')), 'Allowance missing');
      await tester.pump();
      await tapKey(tester, 'payslip-query-send');
      expect(find.text('No internet connection. Check your connection and try again.'), findsOneWidget);
      expect(find.text('Allowance missing'), findsOneWidget);
      await tapKey(tester, 'payslip-query-send');
      expect(server.count('POST', '/payroll/queries/'), 2);
      expect(find.text('Your query has been sent to HR.'), findsOneWidget);
    });

    testWidgets('repeat taps while sending send once', (tester) async {
      final s = FakePayrollServer([payslip('p1', '2026-10-01')])..holdPost = Completer<void>();
      await openSheet(tester, s);
      await tester.enterText(find.byKey(const Key('payslip-query-text')), 'HRA wrong');
      await tester.pump();
      await tester.tap(find.byKey(const Key('payslip-query-send')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('payslip-query-send')), warnIfMissed: false);
      await tester.pump();
      s.holdPost!.complete();
      await tester.pumpAndSettle();
      expect(server.count('POST', '/payroll/queries/'), 1);
    });
  });
}
