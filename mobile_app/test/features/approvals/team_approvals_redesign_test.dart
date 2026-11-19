import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/profile/presentation/widgets/profile_widgets.dart' show ProfileDisplayField;
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/approvals/presentation/providers/approvals_providers.dart';
import '../../visual/shot_harness.dart';
import 'package:mobile_app/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/approval_detail_sheet.dart' show ApprovalDetailSheet;
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_list.dart' show ApprovalsList;
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_ui.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_kit.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// Task 101 — Team Approvals inbox: web TeamApprovalsSection / ApprovalsTable /
// ApprovalsToolbar / SummaryCards / BulkConfirmModal / RequestDetailDrawer.
// Synthetic people; a stand-in server that changes state on writes and records
// every request. Nothing real is called.

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

ResponseBody _page(List<Object> rows) => _json({
      'status': 'success',
      'message': 'ok',
      'data': {'count': rows.length, 'page': 1, 'page_size': 100, 'total_pages': 1, 'results': rows},
    });

Map<String, dynamic> leave(String id, String name,
        {String status = 'pending',
        bool canApprove = true,
        String start = '2026-11-20',
        String end = '2026-11-21',
        String created = '2026-11-13T09:00:00Z',
        int lop = 0,
        String reason = 'Family function'}) =>
    {
      'id': id,
      'employee_name': name,
      'employee_code': 'EMP-$id',
      'employee_dept': 'Ops',
      'leave_type': 'casual',
      'leave_type_display': 'Casual Leave',
      'duration_display': 'Full Day',
      'start_date': start,
      'end_date': end,
      'total_days': 2,
      'lop_days': lop,
      'status': status,
      'reason': reason,
      'created_at': created,
      'can_approve': canApprove,
      'l1_status': 'pending',
      'l1_approver_name': 'Mona Manager',
    };

Map<String, dynamic> expense(int n, String name,
        {String status = 'pending', String created = '2026-11-14T09:00:00Z'}) =>
    {
      'expense_number': n,
      'title': 'Client lunch',
      'category': 'travel',
      'amount': 1234.5,
      'expense_date': '2026-11-10',
      'description': 'Lunch with client',
      'status': status,
      'employee_name': name,
      'branch_name': 'North',
      'receipts': <Object>[],
      'created_at': created,
    };

Map<String, dynamic> correction(String id, String name, {String status = 'pending'}) => {
      'id': id,
      'name': name,
      'employee_id': 'EMP-$id',
      'department': 'QA',
      'branch': 'North',
      'date': '2026-11-12',
      'kind': 'punch',
      'punch_type': 'IN',
      'reason': 'forgot',
      'reason_label': 'Forgot to punch',
      'requested_in': '09:00',
      'requested_out': null,
      'original_in': null,
      'original_out': null,
      'status': status,
      'has_document': false,
      'created_at': '2026-11-12T10:00:00Z',
      'can_action': true,
    };

Map<String, dynamic> wfh(String id, String name, {String status = 'pending'}) => {
      'id': id,
      'employee_name': name,
      'employee_code': 'EMP-$id',
      'employee_dept': 'QA',
      'employee_branch': 'North',
      'start_date': '2026-11-21',
      'end_date': '2026-11-21',
      'status': status,
      'reason': 'Plumber visit',
      'location_label': 'Home',
      'is_medical': false,
      'created_at': '2026-11-15T09:00:00Z',
      'can_approve': true,
      'can_cancel': false,
    };

class Server implements HttpClientAdapter {
  Server({this.leaves = const [], this.expenses = const [], this.corrections = const [], this.wfhs = const []});
  final List<Map<String, dynamic>> leaves;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> corrections;
  final List<Map<String, dynamic>> wfhs;
  final writes = <(String, String, Object?)>[];
  int listStatus = 200;
  int writeStatus = 200;
  String writeMessage = 'Server said no.';
  Completer<void>? holdWrite;
  Completer<void>? holdGets;
  final failIds = <String>{};
  int gets = 0;

  /// A write really changes what the next list returns, as the backend does.
  void _apply(String path, Object? data) {
    final action = data is Map ? (data['action'] ?? data['status']) : null;
    final status = (action == 'approve' || action == 'approved') ? 'approved' : 'rejected';
    for (final list in [leaves, wfhs, corrections]) {
      for (final r in list) {
        if (path.contains('/${r['id']}/')) r['status'] = status;
      }
    }
    for (final r in expenses) {
      if (path.contains('/expenses/${r['expense_number']}/')) r['status'] = status;
    }
  }

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') {
      writes.add((o.method, o.path, o.data));
      final gate = holdWrite;
      if (gate != null) await gate.future;
      if (failIds.any(o.path.contains)) {
        return _json({'status': 'error', 'message': writeMessage, 'data': {}}, 400);
      }
      if (writeStatus != 200) return _json({'status': 'error', 'message': writeMessage, 'data': {}}, writeStatus);
      _apply(o.path, o.data);
      return _json({'status': 'success', 'message': 'ok', 'data': {}});
    }
    gets++;
    final gate = holdGets;
    if (gate != null) await gate.future;
    if (listStatus != 200) return _json({'status': 'error', 'message': 'Server error.', 'data': {}}, listStatus);
    switch (o.path) {
      case '/leave/requests/':
        return _page(leaves);
      case '/expenses/':
        return _page(expenses);
      case '/wfh/requests/':
        return _page(wfhs);
      case '/attendance/corrections/':
        return _page(corrections);
    }
    return _page(const []);
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

UserEntity user(List<String> perms, {List<String>? modules}) => UserEntity(
      id: 'u1',
      email: 'u@example.test',
      fullName: 'Test User',
      role: 'r',
      roleDisplay: 'Role',
      mustChangePassword: false,
      permissions: perms,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final approver = user(['leave.approve', 'expenses.approve', 'attendance.create', 'wfh.approve']);

late Server server;
late ProviderContainer container;

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> pump(
  WidgetTester tester,
  UserEntity u,
  Server s, {
  Size size = const Size(412, 4000),
  double textScale = 1,
  bool wait = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = s;
  if (shotsEnabled) await tester.runAsync(loadShotFonts); // real Poppins for render evidence only
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: shotFrame(MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Consumer(
        builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
            ? const SizedBox()
            : Scaffold(appBar: shotAppBar('Team Approvals'), body: const ApprovalsScreen()),
      ),
    )),
  ));
  if (!wait) return;
  await settle(tester);
  final screen = find.byType(ApprovalsScreen);
  if (screen.evaluate().isNotEmpty) container = ProviderScope.containerOf(tester.element(screen));
}

final card = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ApprovalCard');
Finder inCard(String name, Finder what) =>
    find.descendant(of: find.ancestor(of: find.text(name), matching: card).first, matching: what);

/// Scrolls the inbox list until [f] is built and on screen (the list is lazy).
Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 150,
      scrollable: find.descendant(of: find.byType(ApprovalsList), matching: find.byType(Scrollable)).first);
  await tester.pump();
}

Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

/// Taps a control pinned to the screen (the bulk bar): it is always on screen, so
/// no scrolling — ensureVisible would ask the section PageView to move.
Future<void> tapPinned(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await settle(tester);
}

/// Bulk actions start from selection mode (Select, or a long press on a card).
Future<void> enterSelectMode(WidgetTester tester) async {
  await tap(tester, find.byKey(const Key('approvals-select-mode')));
}

Future<void> confirmRemarks(WidgetTester tester, {required bool approve, String? remarks}) async {
  if (remarks != null) await tester.enterText(find.byType(TextField).last, remarks);
  await tester.tap(find.text(approve ? 'Confirm Approval' : 'Submit Rejection'));
  await settle(tester);
}

List<String> names(WidgetTester tester, List<String> candidates) => [
      for (final n in candidates)
        if (find.text(n).evaluate().isNotEmpty) n
    ];

/// Opens the filter sheet.
Future<void> openFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('approvals-filters')));
  await settle(tester);
}

Future<void> closeFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('approvals-sheet-done')));
  await settle(tester);
}

/// Picks a status in the filter sheet (all / pending / approved / rejected).
Future<void> setStatus(WidgetTester tester, String key) async {
  await openFilters(tester);
  await tester.tap(find.byKey(Key('approvals-status-$key')));
  await settle(tester);
  await closeFilters(tester);
}

/// Picks a sort in the filter sheet (web handleSort: same key flips direction).
Future<void> sortBy(WidgetTester tester, String key) async {
  await openFilters(tester);
  await tester.tap(find.byKey(Key('approvals-sort-$key')));
  await settle(tester);
  await closeFilters(tester);
}

Server mixed() => Server(
      leaves: [leave('l1', 'Lena Leave'), leave('l2', 'Hari Leveltwo', status: 'l2_pending')],
      expenses: [expense(7, 'Eli Expense')],
      corrections: [correction('c1', 'Cora Correction')],
      wfhs: [wfh('w1', 'Wendy Workhome')],
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('shell', () {
    testWidgets('title, subtitle and the real pending total', (tester) async {
      await pump(tester, approver, mixed());
      expect(find.text('Approvals'), findsOneWidget);
      expect(find.text('Items waiting on your action'), findsOneWidget);
      expect(find.text('5 pending'), findsOneWidget); // 2 leave + 1 expense + 1 correction + 1 WFH
    });

    testWidgets('the section tab bar is shown even for a single section (as web)', (tester) async {
      await pump(tester, approver, mixed());
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Team Approvals'), findsOneWidget);
    });

    testWidgets('summary cards: web labels and counts', (tester) async {
      await pump(tester, approver, mixed());
      for (final l in ['Pending Requests', 'Leave Requests', 'Expense Requests', 'Attendance Corrections']) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
      expect(find.text('WFH'), findsNothing); // web has no WFH card
    });

    testWidgets('a module the company lacks drops its card and tab', (tester) async {
      await pump(tester, user(['leave.approve', 'expenses.approve'], modules: ['leave']), mixed());
      expect(find.text('Leave Requests'), findsOneWidget);
      expect(find.text('Expense Requests'), findsNothing);
      expect(find.text('Attendance Corrections'), findsNothing);
      expect(find.byKey(const ValueKey('approvals-type-expense')), findsNothing);
      expect(find.byKey(const ValueKey('approvals-type-leave')), findsOneWidget);
    });

    testWidgets('type tabs follow web order and labels, each with its pending count', (tester) async {
      await pump(tester, approver, mixed());
      final order = ['all', 'leave', 'wfh', 'expense', 'attendanceCorrection']
          .map((k) => tester.getTopLeft(find.byKey(ValueKey('approvals-type-$k'))).dx)
          .toList();
      expect(order, [...order]..sort());
      for (final l in ['All Requests', 'Leave', 'Work From Home', 'Expense', 'Attendance Correction']) {
        expect(find.descendant(of: find.byType(SingleChildScrollView), matching: find.text(l)), findsWidgets,
            reason: l);
      }
      expect(container.read(approvalsTypeTabCountsProvider)[ApprovalsTypeTab.all], 5);
      expect(container.read(approvalsTypeTabCountsProvider)[ApprovalsTypeTab.leave], 2);
    });

    testWidgets('no approval permission: the empty explanation, nothing fetched', (tester) async {
      await pump(tester, user(['leave.view']), mixed());
      expect(find.text('You have no approval permissions.'), findsOneWidget);
      expect(server.gets, 0);
    });
  });

  group('request rows (web _data.ts)', () {
    testWidgets('leave: type, dates, days, submitted date, employee id and department', (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Lena Leave', lop: 1)]));
      expect(find.text('Casual Leave'), findsOneWidget);
      expect(find.text('Full Day'), findsOneWidget);
      expect(find.text('20 Nov 2026 - 21 Nov 2026'), findsOneWidget);
      expect(find.text('2 Days'), findsOneWidget);
      expect(find.text('1 LOP'), findsOneWidget);
      expect(find.text('Submitted 13 Nov 2026'), findsOneWidget);
      expect(find.textContaining('EMP-l1'), findsOneWidget);
      expect(find.textContaining('Ops'), findsOneWidget);
      expect(find.text('Leave'), findsWidgets);
    });

    testWidgets('September is "Sept" (web en-IN)', (tester) async {
      await pump(
          tester,
          approver,
          Server(leaves: [
            leave('l1', 'Lena Leave', start: '2026-09-05', end: '2026-09-06', created: '2026-09-02T09:00:00Z')
          ]));
      expect(find.text('5 Sept 2026 - 6 Sept 2026'), findsOneWidget);
      expect(find.text('Submitted 02 Sept 2026'), findsOneWidget);
    });

    testWidgets('expense: title, ₹ with Indian grouping, category, no employee id', (tester) async {
      await pump(tester, approver, Server(expenses: [expense(7, 'Eli Expense')]));
      expect(find.text('Client lunch'), findsOneWidget);
      expect(find.text('₹1,234.5'), findsOneWidget);
      expect(find.text('travel'), findsOneWidget);
      expect(find.byType(ApprovalsIdChip), findsNothing); // an expense has no employee id: no empty chip
    });

    testWidgets('attendance correction: web label, original → requested, date', (tester) async {
      await pump(tester, approver, Server(corrections: [correction('c1', 'Cora Correction')]));
      expect(find.text('Check-in Correction'), findsOneWidget);
      expect(find.text('— → 09:00 AM'), findsOneWidget);
      expect(find.text('12 Nov 2026'), findsOneWidget);
    });

    testWidgets('work from home: web label and day count', (tester) async {
      await pump(tester, approver, Server(wfhs: [wfh('w1', 'Wendy Workhome')]));
      expect(find.text('Work From Home'), findsWidgets);
      expect(find.text('21 Nov 2026 - 21 Nov 2026'), findsOneWidget);
      expect(find.text('1 Day'), findsOneWidget);
    });

    testWidgets('level 2 reads "Pending HR" and still counts as pending', (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l2', 'Hari Leveltwo', status: 'l2_pending')]));
      expect(find.text('Pending HR'), findsOneWidget);
      expect(find.text('Hari Leveltwo'), findsOneWidget);
    });
  });

  group('filters, sort and paging', () {
    testWidgets('toolbar copy follows web', (tester) async {
      await pump(tester, approver, mixed());
      expect(find.widgetWithText(TextField, 'Search employee name or ID…'), findsOneWidget);
      await openFilters(tester);
      expect(find.text('Submitted from'), findsOneWidget);
      expect(find.text('Submitted to'), findsOneWidget);
      for (final o in ['All Statuses', 'Pending', 'Approved', 'Rejected']) {
        expect(find.text(o), findsWidgets, reason: o);
      }
      for (final o in ['Employee', 'Submitted Date', 'Status']) {
        expect(find.text(o), findsWidgets, reason: o);
      }
    });

    testWidgets('search by name or employee id', (tester) async {
      await pump(tester, approver, mixed());
      await tester.enterText(find.byKey(const Key('approvals-search')), 'cora');
      await settle(tester);
      expect(names(tester, ['Cora Correction', 'Lena Leave', 'Eli Expense']), ['Cora Correction']);
      await tester.enterText(find.byKey(const Key('approvals-search')), 'EMP-l2');
      await settle(tester);
      expect(names(tester, ['Hari Leveltwo', 'Lena Leave']), ['Hari Leveltwo']);
    });

    testWidgets('submitted-date range', (tester) async {
      await pump(tester, approver, mixed());
      container.read(approvalsDateFromProvider.notifier).state = DateTime(2026, 11, 14);
      container.read(approvalsDateToProvider.notifier).state = DateTime(2026, 11, 14);
      await settle(tester);
      expect(names(tester, ['Eli Expense', 'Lena Leave', 'Cora Correction']), ['Eli Expense']);
      // both ends show as removable chips in web's date format
      expect(find.text('From 14 Nov 2026'), findsOneWidget);
      expect(find.text('To 14 Nov 2026'), findsOneWidget);
    });

    testWidgets('type tab narrows the list; counts do not change', (tester) async {
      await pump(tester, approver, mixed());
      await tap(tester, find.byKey(const ValueKey('approvals-type-expense')));
      expect(names(tester, ['Eli Expense', 'Lena Leave', 'Wendy Workhome']), ['Eli Expense']);
      expect(container.read(approvalsSummaryCountsProvider).pendingTotal, 5);
    });

    testWidgets('sort: newest first by default; Employee toggles A–Z / Z–A; Status', (tester) async {
      await pump(
          tester,
          approver,
          Server(leaves: [
            leave('l1', 'Bea', created: '2026-11-10T09:00:00Z'),
            leave('l2', 'Cal', created: '2026-11-12T09:00:00Z'),
            leave('l3', 'Abe', created: '2026-11-11T09:00:00Z', status: 'approved'),
          ]));
      await setStatus(tester, 'all');
      double y(String n) => tester.getTopLeft(find.text(n)).dy;
      expect(y('Cal') < y('Abe') && y('Abe') < y('Bea'), isTrue); // submitted, newest first

      await sortBy(tester, 'employee');
      expect(y('Abe') < y('Bea') && y('Bea') < y('Cal'), isTrue); // A–Z
      await sortBy(tester, 'employee');
      expect(y('Cal') < y('Bea') && y('Bea') < y('Abe'), isTrue); // Z–A

      await sortBy(tester, 'status');
      expect(y('Abe') < y('Bea'), isTrue); // "approved" sorts before "pending"
    });

    testWidgets('pagination: 10 per page, Showing a–b of n, Next/Prev, window of pages', (tester) async {
      final s = Server(leaves: [
        for (var i = 1; i <= 23; i++)
          leave('p$i', 'Person ${i.toString().padLeft(2, '0')}', created: '2026-11-0${(i % 9) + 1}T09:00:00Z'),
      ]);
      await pump(tester, approver, s, size: const Size(412, 9000));
      expect(card, findsNWidgets(10));
      expect(find.text('Showing 1–10 of 23'), findsOneWidget);
      await tap(tester, find.byKey(const Key('approvals-next')));
      expect(card, findsNWidgets(10));
      expect(find.text('Showing 11–20 of 23'), findsOneWidget);
      await tap(tester, find.byKey(const Key('approvals-page-3')));
      expect(card, findsNWidgets(3));
      expect(find.text('Showing 21–23 of 23'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('approvals-next'))).onPressed, isNull);
      await tap(tester, find.byKey(const Key('approvals-prev')));
      expect(find.text('Showing 11–20 of 23'), findsOneWidget);
    });

    testWidgets('a filter change returns to page 1; one page shows no pager', (tester) async {
      final s = Server(leaves: [for (var i = 1; i <= 12; i++) leave('p$i', 'Person $i')]);
      await pump(tester, approver, s, size: const Size(412, 9000));
      await tap(tester, find.byKey(const Key('approvals-next')));
      expect(find.text('Showing 11–12 of 12'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('approvals-search')), 'Person 1');
      await settle(tester);
      expect(container.read(approvalsPageProvider), 1);
      await tester.enterText(find.byKey(const Key('approvals-search')), 'Person 12');
      await settle(tester);
      expect(find.byKey(const Key('approvals-showing')), findsNothing);
    });

    testWidgets('pure helper: pages for a count', (tester) async {
      expect([0, 1, 10, 11, 20, 21].map(ApprovalsPager.pagesFor), [1, 1, 1, 2, 2, 3]);
    });
  });

  group('selection and bulk actions', () {
    Server three() => Server(leaves: [leave('l1', 'Ann'), leave('l2', 'Ben'), leave('l3', 'Cy')]);

    testWidgets('select page, select all, clear; counts shown', (tester) async {
      await pump(tester, approver, three());
      await enterSelectMode(tester);
      await tap(tester, find.byKey(const Key('approvals-select-page')));
      expect(find.text('3 selected'), findsOneWidget);
      expect(find.byKey(const Key('approvals-select-all')), findsNothing); // everything is selected
      await tapPinned(tester, find.byKey(const Key('approvals-clear')));
      expect(find.text('3 selected'), findsNothing);
    });

    testWidgets('select all covers every filtered row across pages', (tester) async {
      final s = Server(leaves: [for (var i = 1; i <= 14; i++) leave('p$i', 'Person $i')]);
      await pump(tester, approver, s, size: const Size(412, 9000));
      await enterSelectMode(tester);
      await tap(tester, find.byKey(const Key('approvals-select-page')));
      expect(find.text('10 selected'), findsOneWidget);
      await tapPinned(tester, find.byKey(const Key('approvals-select-all')));
      expect(find.text('14 selected'), findsOneWidget);
    });

    testWidgets('bulk approve: web dialog text, each request sent with the remarks, web message, then refetch',
        (tester) async {
      await pump(tester, approver, three());
      await enterSelectMode(tester);
      await tap(tester, find.byKey(const Key('approvals-select-page')));
      final getsBefore = server.gets;
      await tapPinned(tester, find.byKey(const Key('approvals-bulk-approve')));
      expect(find.text('Approve 3 requests'), findsOneWidget);
      expect(find.text("You're about to approve 3 selected requests. Employees will be notified."), findsOneWidget);
      expect(find.text('Optional notes for the record…'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('bulk-remarks')), 'All good');
      await tester.tap(find.byKey(const Key('bulk-confirm')));
      await settle(tester);
      expect(server.writes, hasLength(3));
      for (final w in server.writes) {
        expect(w.$1, 'POST');
        expect(w.$3, {'action': 'approve', 'remarks': 'All good'});
      }
      expect(find.text('3 requests approved.'), findsOneWidget);
      expect(server.gets, greaterThan(getsBefore)); // lists reloaded
      expect(find.text('You’re all caught up!'), findsOneWidget);
      expect(container.read(approvalsSelectedIdsProvider), isEmpty);
    });

    testWidgets('bulk reject needs a reason: button disabled until typed', (tester) async {
      await pump(tester, approver, three());
      await enterSelectMode(tester);
      await tap(tester, find.byKey(const Key('approvals-select-page')));
      await tapPinned(tester, find.byKey(const Key('approvals-bulk-reject')));
      expect(find.text('Reject 3 requests'), findsOneWidget);
      expect(find.text('Reason for rejection (required)'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('bulk-confirm'))).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('bulk-remarks')), '   ');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('bulk-confirm'))).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('bulk-remarks')), 'Not eligible');
      await tester.pump();
      await tester.tap(find.byKey(const Key('bulk-confirm')));
      await settle(tester);
      expect(
          server.writes.every((w) => (w.$3 as Map)['remarks'] == 'Not eligible' && (w.$3 as Map)['action'] == 'reject'),
          isTrue);
      expect(find.text('3 requests rejected.'), findsOneWidget);
    });

    testWidgets('cancelling the bulk dialog sends nothing', (tester) async {
      await pump(tester, approver, three());
      await enterSelectMode(tester);
      await tap(tester, find.byKey(const Key('approvals-select-page')));
      await tapPinned(tester, find.byKey(const Key('approvals-bulk-approve')));
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(server.writes, isEmpty);
      expect(find.text('3 selected'), findsOneWidget);
    });

    testWidgets('partial failure: web message, failed rows stay pending and selectable again', (tester) async {
      final s = three()..failIds.add('/l2/');
      await pump(tester, approver, s);
      await enterSelectMode(tester);
      await tap(tester, find.byKey(const Key('approvals-select-page')));
      await tapPinned(tester, find.byKey(const Key('approvals-bulk-approve')));
      await tester.tap(find.byKey(const Key('bulk-confirm')));
      await settle(tester);
      expect(find.text('2 approved, 1 failed — please retry those individually.'), findsOneWidget);
      expect(names(tester, ['Ann', 'Ben', 'Cy']), ['Ben']); // only the failed one is still pending
    });

    testWidgets('a second tap on Approve Selected starts one batch only', (tester) async {
      final s = three()..holdWrite = Completer<void>();
      await pump(tester, approver, s);
      await enterSelectMode(tester);
      await tap(tester, find.byKey(const Key('approvals-select-page')));
      await tapPinned(tester, find.byKey(const Key('approvals-bulk-approve')));
      await tester.tap(find.byKey(const Key('bulk-confirm')));
      await tester.pump(const Duration(milliseconds: 100));
      // The bar is busy: neither button is live while the batch is in flight.
      expect(tester.widget<FilledButton>(find.byKey(const Key('approvals-bulk-approve'))).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('approvals-bulk-reject'))).onPressed, isNull);
      s.holdWrite!.complete();
      await settle(tester);
      expect(s.writes, hasLength(3));
    });

    testWidgets('a row the server says you cannot action has no checkbox action and no buttons', (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Ann', canApprove: false)]));
      expect(find.text('Ann'), findsOneWidget);
      expect(find.byKey(const Key('approval-approve-l1')), findsNothing);
      expect(find.byKey(const Key('approvals-select-page')), findsNothing);
    });
  });

  group('single approve / reject', () {
    testWidgets(
        'leave approve: optional remarks, payload, web message, not shown as approved before the server answers',
        (tester) async {
      final s = Server(leaves: [leave('l1', 'Ann')])..holdWrite = Completer<void>();
      await pump(tester, approver, s);
      await tap(tester, find.byKey(const Key('approval-approve-l1')));
      expect(find.text('Approve — Ann’s leave'), findsOneWidget);
      await confirmRemarks(tester, approve: true, remarks: 'Enjoy');
      // In flight: still pending, nothing marked approved yet.
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Approved'), findsNothing);
      expect(s.writes.single.$3, {'action': 'approve', 'remarks': 'Enjoy'});
      s.holdWrite!.complete();
      await settle(tester);
      expect(find.text('Request approved.'), findsOneWidget);
      expect(find.text('Ann'), findsNothing); // gone from the pending queue once the server says approved
    });

    testWidgets('leave reject: a reason is mandatory; nothing sent without one', (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Ann')]));
      await tap(tester, find.byKey(const Key('approval-reject-l1')));
      await confirmRemarks(tester, approve: false);
      expect(find.text('Please provide a reason.'), findsOneWidget);
      expect(server.writes, isEmpty);
      await confirmRemarks(tester, approve: false, remarks: 'Clash with release');
      expect(server.writes.single.$3, {'action': 'reject', 'remarks': 'Clash with release'});
      expect(find.text('Request rejected.'), findsOneWidget);
    });

    testWidgets('expense: confirm-only (the backend stores no remarks), PUT status, web message', (tester) async {
      await pump(tester, approver, Server(expenses: [expense(7, 'Eli Expense')]));
      await tap(tester, find.byKey(const Key('approval-approve-7')));
      expect(find.byType(TextField), findsOneWidget); // only the search field: no remarks box
      await tester.tap(find.text('Approve').last);
      await settle(tester);
      expect(server.writes.single.$1, 'PUT');
      expect(server.writes.single.$2, '/expenses/7/');
      expect(server.writes.single.$3, {'status': 'approved'});
      expect(find.text('Request approved.'), findsOneWidget);
    });

    testWidgets('correction and WFH use web’s own success messages', (tester) async {
      await pump(tester, approver,
          Server(corrections: [correction('c1', 'Cora Correction')], wfhs: [wfh('w1', 'Wendy Workhome')]));
      await tap(tester, find.byKey(const Key('approval-approve-c1')));
      await confirmRemarks(tester, approve: true);
      expect(find.text('Correction approved. Attendance record updated.'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
      await settle(tester);
      await tap(tester, find.byKey(const Key('approval-reject-w1')));
      await confirmRemarks(tester, approve: false, remarks: 'Office day');
      expect(find.text('Work from home request rejected.'), findsOneWidget);
    });

    testWidgets('a server refusal is shown verbatim and the row stays pending', (tester) async {
      final s = Server(leaves: [leave('l1', 'Ann')])
        ..writeStatus = 403
        ..writeMessage = 'You are not authorised to act on this request at the L2 stage.';
      await pump(tester, approver, s);
      await tap(tester, find.byKey(const Key('approval-approve-l1')));
      await confirmRemarks(tester, approve: true);
      expect(find.text('You are not authorised to act on this request at the L2 stage.'), findsOneWidget);
      expect(find.text('Ann'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
    });

    testWidgets('a double tap sends one request and opens one dialog', (tester) async {
      final s = Server(leaves: [leave('l1', 'Ann')])..holdWrite = Completer<void>();
      await pump(tester, approver, s);
      final b = find.byKey(const Key('approval-approve-l1'));
      await tester.ensureVisible(b);
      await tester.tap(b);
      await tester.tap(b, warnIfMissed: false);
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await confirmRemarks(tester, approve: true);
      // Request in flight: the button is disabled and a tap opens nothing.
      expect(tester.widget<FilledButton>(b).onPressed, isNull);
      await tester.tap(b, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AlertDialog), findsNothing);
      expect(s.writes, hasLength(1));
      s.holdWrite!.complete();
      await settle(tester);
      expect(s.writes, hasLength(1));
    });
  });

  group('card layout and selection mode (Task 101.1)', () {
    testWidgets('every request is one card: avatar, ID chip, status badge, divided zones, label/value facts',
        (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Ann'), leave('l2', 'Ben')]));
      expect(find.byType(ApprovalsCardShell), findsNWidgets(2));
      expect(find.byType(ApprovalsAvatar), findsNWidgets(2));
      expect(find.byType(ApprovalsBadge), findsWidgets);
      final one = find.byType(ApprovalsCardShell).first;
      // the decision footer is separated from the body by one hairline
      expect(find.descendant(of: one, matching: find.byType(Divider)), findsOneWidget);
      // an inbox item, not a form: no label-over-value fields inside the card
      expect(find.descendant(of: one, matching: find.byType(ProfileDisplayField)), findsNothing);
      expect(find.descendant(of: one, matching: find.byType(ApprovalsQuote)), findsOneWidget);
      expect(find.descendant(of: one, matching: find.text('Reason')), findsNothing);
    });

    testWidgets('the avatar uses the My Profile palette, keyed by the first letter', (tester) async {
      expect(approvalsAvatarColor('Anika'), approvalsAvatarColor('Abe')); // same first letter
      expect(approvalsAvatarColor('Anika'), isNot(approvalsAvatarColor('Bea')));
      expect(approvalsAvatarColor(''), const Color(0xFF1E4E8C));
      expect([
        approvalsInitials('Anika Sharma'),
        approvalsInitials('Bo'),
        approvalsInitials('  '),
        approvalsInitials('a b c')
      ], [
        'AS',
        'B',
        '?',
        'AC'
      ]);
    });

    testWidgets('the footer: Submitted date, a Details action, then Reject / Approve', (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Ann')]));
      expect(find.text('Submitted 13 Nov 2026'), findsOneWidget);
      await tap(tester, find.byKey(const Key('approval-details-l1')));
      expect(find.byType(ApprovalDetailSheet), findsOneWidget);
    });

    testWidgets('selection mode: Select shows checkboxes and hides the per-card actions; Done leaves and clears',
        (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Ann'), leave('l2', 'Ben')]));
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byKey(const Key('approval-approve-l1')), findsOneWidget);
      await enterSelectMode(tester);
      expect(find.byType(Checkbox), findsWidgets);
      expect(find.byKey(const Key('approval-approve-l1')), findsNothing);
      expect(find.byKey(const Key('approval-details-l1')), findsNothing);
      await tap(tester, find.byKey(const Key('approvals-select-page')));
      expect(find.text('2 selected'), findsOneWidget);
      await tap(tester, find.byKey(const Key('approvals-select-done')));
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('2 selected'), findsNothing);
      expect(container.read(approvalsSelectedIdsProvider), isEmpty);
      expect(find.byKey(const Key('approval-approve-l1')), findsOneWidget);
    });

    testWidgets('in selection mode tapping a card selects it (it does not open details)', (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Ann'), leave('l2', 'Ben')]));
      await enterSelectMode(tester);
      await tap(tester, find.text('Ann'));
      expect(find.byType(ApprovalDetailSheet), findsNothing);
      expect(find.text('1 selected'), findsOneWidget);
      await tap(tester, find.text('Ann'));
      expect(find.text('1 selected'), findsNothing); // toggled off
    });

    testWidgets('a long press on a card starts selection mode with that card selected', (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Ann'), leave('l2', 'Ben')]));
      await tester.ensureVisible(find.text('Ann'));
      await tester.longPress(find.text('Ann'));
      await settle(tester);
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.byKey(const Key('approvals-select-done')), findsOneWidget);
      expect(find.byKey(const Key('approval-approve-l1')), findsNothing);
    });

    testWidgets('a card the user cannot action can be neither long-pressed nor selected into the batch',
        (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Ann', canApprove: false)]));
      await tester.longPress(find.text('Ann'));
      await settle(tester);
      expect(find.text('1 selected'), findsNothing);
      expect(container.read(approvalsSelectionModeProvider), isFalse);
    });

    testWidgets('level 2 shows a "Pending HR" badge on the card header', (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l2', 'Hari', status: 'l2_pending')]));
      expect(find.descendant(of: find.byType(ApprovalsCardShell), matching: find.text('Pending HR')), findsOneWidget);
    });

    testWidgets('card actions and filters use the app primary colour, not the theme purple', (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Ann')]));
      final details = tester.widget<TextButton>(find.byKey(const Key('approval-details-l1')));
      expect(details.style?.foregroundColor?.resolve({}), AppColors.primary);
      final approve = tester.widget<FilledButton>(find.byKey(const Key('approval-approve-l1')));
      expect(approve.style?.backgroundColor?.resolve({}), AppColors.primary);
    });
  });

  group('request details sheet', () {
    testWidgets('web drawer sections, labels, timeline, and an approve that confirms', (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Ann', lop: 1)]));
      await tap(tester, find.byKey(const Key('approval-details-l1')));
      final sheet = find.byType(ApprovalDetailSheet);
      for (final l in ['Request Details', 'Reason', 'Approval Timeline']) {
        expect(find.descendant(of: sheet, matching: find.text(l)), findsOneWidget, reason: l);
      }
      for (final l in ['Leave Type', 'Duration', 'Dates', 'Total Days', 'LOP Days', 'Submitted', 'Manager Approval']) {
        expect(find.text(l), findsWidgets, reason: l);
      }
      expect(find.text('Full Day'), findsWidgets);
      expect(find.text('13 Nov 2026'), findsWidgets); // timeline "Submitted"
      expect(find.descendant(of: find.byType(ApprovalDetailSheet), matching: find.text('Family function')),
          findsOneWidget);
      await tester.tap(find.text('Approve').last);
      await settle(tester);
      await confirmRemarks(tester, approve: true);
      expect(server.writes.single.$3, containsPair('action', 'approve'));
      expect(find.text('Request approved.'), findsOneWidget);
    });

    testWidgets('correction details: type, date and original → requested per punch', (tester) async {
      await pump(tester, approver, Server(corrections: [correction('c1', 'Cora Correction')]));
      await tap(tester, find.byKey(const Key('approval-details-c1')));
      expect(find.text('Correction Type'), findsOneWidget);
      expect(find.text('Check-in'), findsOneWidget);
      expect(find.text('— → 09:00 AM'), findsWidgets);
      expect(find.text('Check-out'), findsNothing);
    });
  });

  group('states', () {
    testWidgets('loading shows a spinner and no stale rows', (tester) async {
      final s = mixed()..holdWrite = null;
      await pump(tester, approver, s, wait: false);
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Lena Leave'), findsNothing);
      await settle(tester);
      expect(find.text('Lena Leave'), findsOneWidget);
    });

    testWidgets('a failed load shows the server message with Retry; retry recovers', (tester) async {
      final s = mixed()..listStatus = 500;
      await pump(tester, approver, s);
      expect(find.text('Server error.'), findsOneWidget);
      expect(find.text('Lena Leave'), findsNothing);
      s.listStatus = 200;
      await tap(tester, find.text('Retry'));
      expect(find.text('Lena Leave'), findsOneWidget);
    });

    testWidgets('while a reload is in flight the rows stay on screen (nothing is blanked)', (tester) async {
      final s = mixed();
      await pump(tester, approver, s);
      s.holdGets = Completer<void>();
      unawaited(container.read(unifiedTeamApprovalsProvider.notifier).refresh());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Lena Leave'), findsOneWidget);
      s.holdGets!.complete();
      await settle(tester);
      expect(find.text('Lena Leave'), findsOneWidget);
    });

    testWidgets('a refresh that fails keeps the rows on screen and says why', (tester) async {
      final s = mixed();
      await pump(tester, approver, s);
      s.listStatus = 500;
      unawaited(container.read(unifiedTeamApprovalsProvider.notifier).refresh()); // pumped, not awaited: fake async
      await settle(tester);
      expect(find.text('Lena Leave'), findsOneWidget);
      expect(find.byKey(const Key('approvals-refresh-error')), findsOneWidget);
    });

    testWidgets('nothing pending: web’s "all caught up"; a filter that matches nothing says so', (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Ann', status: 'approved', canApprove: false)]));
      expect(find.text('You’re all caught up!'), findsOneWidget);
      expect(find.text('No approval requests are waiting for your action.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('approvals-search')), 'zzz');
      await settle(tester);
      expect(find.text('No requests match the current filters.'), findsOneWidget);
    });

    testWidgets('the Refresh button reloads every queue', (tester) async {
      await pump(tester, approver, mixed());
      final before = server.gets;
      await tap(tester, find.byKey(const Key('approvals-refresh')));
      expect(server.gets, greaterThan(before));
    });
  });

  group('responsive layout', () {
    Server crowded() => Server(
          leaves: [
            leave('l1', 'Alexandria Wilhelmina Montgomery-Featherstonehaugh',
                reason:
                    'A very long reason that keeps going and going so that it must wrap across several lines on a narrow phone'),
            leave('l2', 'Bo', status: 'l2_pending'),
          ],
          expenses: [expense(7, 'Eli Expense')],
          corrections: [correction('c1', 'Cora Correction')],
          wfhs: [wfh('w1', 'Wendy Workhome')],
        );

    Future<void> noOverflow(WidgetTester tester) async {
      expect(tester.takeException(), isNull);
      // Scroll the whole inbox and the controls: nothing may overflow.
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'scroll step $i');
      }
    }

    for (final (label, size, scale) in [
      ('320×568', const Size(320, 568), 1.0),
      ('320×568 at 2.0× text', const Size(320, 568), 2.0),
      ('360×640 at 1.5× text', const Size(360, 640), 1.5),
      ('430×932', const Size(430, 932), 1.0),
      ('tablet 1000×800', const Size(1000, 800), 1.0),
    ]) {
      testWidgets('$label: no overflow with long names and reasons', (tester) async {
        await pump(tester, approver, crowded(), size: size, textScale: scale);
        await noOverflow(tester);
      });
    }

    testWidgets('action buttons stay whole at 2.0× text (stacked, never clipped)', (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Ann')]), size: const Size(320, 700), textScale: 2);
      final approve = find.byKey(const Key('approval-approve-l1'));
      final reject = find.byKey(const Key('approval-reject-l1'));
      await scrollTo(tester, approve);
      final a = tester.getRect(approve);
      final r = tester.getRect(reject);
      expect(a.right, lessThanOrEqualTo(320));
      expect(r.right, lessThanOrEqualTo(320));
      expect(a.top, greaterThanOrEqualTo(r.bottom)); // stacked: Reject, then Approve
      expect(a.height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
    });

    testWidgets('side by side when there is room', (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Ann')]), size: const Size(1000, 800));
      final a = tester.getRect(find.byKey(const Key('approval-approve-l1')));
      final r = tester.getRect(find.byKey(const Key('approval-reject-l1')));
      expect(a.top, r.top);
    });

    testWidgets('the remarks dialog stays reachable with the keyboard open on a small screen', (tester) async {
      await pump(tester, approver, Server(leaves: [leave('l1', 'Ann')]), size: const Size(320, 568));
      await scrollTo(tester, find.byKey(const Key('approval-reject-l1')));
      await tap(tester, find.byKey(const Key('approval-reject-l1')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'Reason');
      await tester.ensureVisible(find.text('Submit Rejection'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text('Submit Rejection')).bottom, lessThanOrEqualTo(568 - 280 + 1));
      tester.view.resetViewInsets();
      await settle(tester);
    });

    testWidgets('summary cards stack to one column on a very narrow, large-text screen', (tester) async {
      await pump(tester, approver, mixed(), size: const Size(320, 568), textScale: 2);
      final a = tester.getTopLeft(find.text('Pending Requests'));
      final b = tester.getTopLeft(find.text('Leave Requests'));
      expect(b.dy, greaterThan(a.dy));
      expect(b.dx, a.dx);
    });
  });
}
