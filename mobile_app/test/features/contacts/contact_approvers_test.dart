import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/contacts/data/models/contact_approvers.dart';
import 'package:mobile_app/features/contacts/presentation/widgets/contact_approvers_section.dart';

// Task 94 / HO-42: Contacts → "My Approvers" / "Employee Approvers" (web
// app/dashboard/contacts/_components/ApproversSection.tsx + lib/contactMatrix.ts;
// backend ContactApproversView, read-only GET
// /company-contacts/approvers/?workflow=). Synthetic people only.

const _workflows = [
  {'value': 'leave', 'label': 'Leave Request'},
  {'value': 'expense', 'label': 'Expense Claim'},
  {'value': 'attendance_correction', 'label': 'Attendance Correction'},
];

Map<String, dynamic> _person(String name, {String email = '', String phone = ''}) =>
    {'name': name, 'email': email, 'phone': phone};

class FakeApproversServer implements HttpClientAdapter {
  final queries = <Map<String, dynamic>>[];
  bool withTeam = true;
  int failNext = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    expect(o.path, ApiConstants.companyContactApprovers);
    expect(o.method, 'GET');
    queries.add(Map.of(o.queryParameters));
    if (failNext != 0) {
      final s = failNext;
      failNext = 0;
      return ResponseBody.fromString(jsonEncode({'status': 'error', 'message': 'Server error.', 'data': {}}), s,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
    }
    final wf = '${o.queryParameters['workflow']}';
    final expense = wf == 'expense';
    return ResponseBody.fromString(
      jsonEncode({
        'status': 'success',
        'message': 'ok',
        'data': {
          'workflow': wf,
          'workflows': _workflows,
          'me': {
            'employee_id': 'EMP-001',
            'name': 'Test Self',
            'department': 'QA',
            'branch': 'North',
            'l1': _person(expense ? 'Expense Lead' : 'Lead One', email: 'lead@example.test', phone: '+10000000001'),
            'l2': expense ? null : _person('Head Two'),
          },
          'team': withTeam
              ? [
                  {
                    'employee_id': 'EMP-101',
                    'name': 'Alpha Person',
                    'department': 'Sales',
                    'branch': 'North',
                    'l1': _person('Lead One', email: 'lead@example.test'),
                    'l2': null,
                  },
                  {
                    'employee_id': 'EMP-102',
                    'name': 'Beta Person',
                    'department': 'QA',
                    'branch': 'South',
                    'l1': null,
                    'l2': null,
                  },
                ]
              : null,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

late FakeApproversServer server;
late List<Uri> launched;

Future<void> pumpSection(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  launched = [];
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: ContactApproversSection(onLaunch: (u) async => launched.add(u))),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder inCard(String key, Finder f) => find.descendant(of: find.byKey(Key(key)), matching: f);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => server = FakeApproversServer());

  test('filterApproverRows: name, ID, department, branch; trimmed and case-insensitive', () {
    const rows = [
      ApproverRow(employeeId: 'EMP-1', name: 'Alpha', department: 'Sales', branch: 'North'),
      ApproverRow(employeeId: 'EMP-2', name: 'Beta', department: 'QA', branch: 'South'),
    ];
    expect(filterApproverRows(rows, '  ').length, 2);
    expect(filterApproverRows(rows, 'ALPHA').single.name, 'Alpha');
    expect(filterApproverRows(rows, 'emp-2').single.name, 'Beta');
    expect(filterApproverRows(rows, 'qa').single.name, 'Beta');
    expect(filterApproverRows(rows, 'north').single.name, 'Alpha');
    expect(filterApproverRows(rows, 'nobody'), isEmpty);
    expect(rows.first.subtitle, 'EMP-1 · Sales · North');
  });

  testWidgets('My Approvers: leave by default; L1 with email/phone links, L2 "No email" / "No phone"',
      (tester) async {
    await pumpSection(tester);
    expect(server.queries, [
      {'workflow': 'leave'}
    ]);
    expect(find.text('My Approvers'), findsOneWidget);
    expect(find.text('Leave Request'), findsOneWidget);
    expect(inCard('my-approvers', find.text('L1 Approver')), findsOneWidget);
    expect(find.text('Lead One'), findsWidgets);
    expect(find.text('Head Two'), findsOneWidget);
    expect(find.text('No email'), findsWidgets);
    expect(find.text('No phone'), findsWidgets);
    expect(find.byKey(const Key('approvers-expense-note')), findsNothing);

    await tester.tap(inCard('my-approvers', find.text('lead@example.test')));
    await tester.tap(inCard('my-approvers', find.text('+10000000001')));
    expect(launched, [Uri(scheme: 'mailto', path: 'lead@example.test'), Uri(scheme: 'tel', path: '+10000000001')]);
  });

  testWidgets('switching to Expense refetches with ?workflow=expense, shows the note and "Not Assigned"',
      (tester) async {
    await pumpSection(tester);
    await tester.tap(find.byKey(const Key('approvers-workflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expense Claim').last);
    await tester.pumpAndSettle();
    expect(server.queries.last, {'workflow': 'expense'});
    expect(find.text('Expense Lead'), findsOneWidget);
    expect(inCard('my-approvers', find.text(kApproverNotAssigned)), findsOneWidget);
    expect(
        find.text('Expense claims are approved in one step by the reporting manager or assigned HR; '
            'the approvers above are the configured Expense approval rule.'),
        findsOneWidget);
  });

  testWidgets('Employee Approvers: rows with subtitles; search filters; empty messages', (tester) async {
    await pumpSection(tester);
    expect(find.text('Employee Approvers'), findsOneWidget);
    expect(find.byKey(const Key('approvers-row-EMP-101')), findsOneWidget);
    expect(find.text('EMP-102 · QA · South'), findsOneWidget);
    // Beta has neither approver.
    expect(
        find.descendant(of: find.byKey(const Key('approvers-row-EMP-102')), matching: find.text(kApproverNotAssigned)),
        findsNWidgets(2));

    await tester.enterText(find.byKey(const Key('approvers-search')), 'sales');
    await tester.pump();
    expect(find.byKey(const Key('approvers-row-EMP-101')), findsOneWidget);
    expect(find.byKey(const Key('approvers-row-EMP-102')), findsNothing);

    await tester.enterText(find.byKey(const Key('approvers-search')), 'nobody');
    await tester.pump();
    expect(find.text('No matching employees.'), findsOneWidget);
    expect(server.queries.length, 1, reason: 'search is local, as on web');
  });

  testWidgets('no team (no employees.view): the Employee Approvers card is hidden', (tester) async {
    server.withTeam = false;
    await pumpSection(tester);
    expect(find.text('My Approvers'), findsOneWidget);
    expect(find.byKey(const Key('employee-approvers')), findsNothing);
  });

  testWidgets('an empty team says "No employees in your scope."', (tester) async {
    server = _EmptyTeamServer();
    await pumpSection(tester);
    expect(find.text('No employees in your scope.'), findsOneWidget);
  });

  testWidgets('a failed request shows the error banner and no approver rows', (tester) async {
    server.failNext = 500;
    await pumpSection(tester);
    expect(find.byKey(const Key('approvers-error')), findsOneWidget);
    expect(find.text('L1 Approver'), findsNothing);
    expect(find.byKey(const Key('employee-approvers')), findsNothing);
    // The workflow picker still offers the web fallback.
    expect(find.text('Leave Request'), findsOneWidget);
  });
}

class _EmptyTeamServer extends FakeApproversServer {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    final r = await super.fetch(o, s, c);
    final body = jsonDecode(await utf8.decodeStream(r.stream)) as Map<String, dynamic>;
    (body['data'] as Map)['team'] = <Object>[];
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }
}
