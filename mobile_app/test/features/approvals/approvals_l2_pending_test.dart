import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/approvals/presentation/providers/approvals_providers.dart';
import 'package:mobile_app/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/delegations_tab.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// Task 80: level-2 pending items in the Approvals inbox.
// Web approvals/_data.ts toDisplayStatus: pending | l2_pending |
// stage2_pending → "pending"; approved; rejected; anything else →
// "cancelled". TeamApprovalsSection filters, counts and gates actions on that
// display status (default filter "pending"), over one fetch per kind
// (page_size 100, every status — the backend is not asked to filter).
// Mobile compared the RAW status with the filter, so every `l2_pending`
// leave / WFH / correction row vanished under the default Pending filter —
// a level-2 (HR) approver saw an empty inbox while the Pending count said
// otherwise. Synthetic people; a stand-in server records every request.

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _page(List<Object> rows, {int? count, int pages = 1}) => _json({
      'status': 'success',
      'message': 'ok',
      'data': {'count': count ?? rows.length, 'page': 1, 'page_size': 100, 'total_pages': pages, 'results': rows},
    });

Map<String, dynamic> leave(String id, String name, String status, {bool canApprove = true}) => {
      'id': id,
      'employee_name': name,
      'employee_code': 'EMP-$id',
      'leave_type': 'casual',
      'leave_type_display': 'Casual Leave',
      'start_date': '2026-11-20',
      'end_date': '2026-11-20',
      'status': status,
      'reason': 'Family function',
      'created_at': '2026-11-13T09:00:00Z',
      'can_approve': canApprove,
    };

Map<String, dynamic> wfh(String id, String name, String status) => {
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
      'created_at': '2026-11-14T09:00:00Z',
      'can_approve': true,
      'can_cancel': false,
    };

Map<String, dynamic> correction(String id, String name, String status, {bool canAction = true}) => {
      'id': id,
      'name': name,
      'employee_id': 'EMP-$id',
      'department': 'QA',
      'branch': 'North',
      'date': '2026-11-12',
      'kind': 'correction',
      'punch_type': 'clock_in',
      'reason': 'forgot',
      'reason_label': 'Forgot to punch',
      'explanation': 'Missed the device',
      'requested_in': '09:00',
      'requested_out': null,
      'original_in': null,
      'original_out': null,
      'status': status,
      'has_document': false,
      'created_at': '2026-11-12T10:00:00Z',
      'can_action': canAction,
    };

class Server implements HttpClientAdapter {
  Server({List<Map<String, dynamic>>? leaves, this.wfhs = const [], this.corrections = const [], this.leaveCount}) {
    this.leaves = leaves ?? const [];
  }
  late final List<Map<String, dynamic>> leaves;
  final List<Map<String, dynamic>> wfhs;
  final List<Map<String, dynamic>> corrections;
  final int? leaveCount; // when the server reports more rows than page 1
  final gets = <(String, Map<String, dynamic>)>[];
  final writes = <(String, String, Object?)>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') {
      writes.add((o.method, o.path, o.data));
      return _json({'status': 'success', 'message': 'ok', 'data': {}});
    }
    gets.add((o.path, Map.of(o.queryParameters)));
    if (o.path == '/leave/requests/') {
      return _page(leaves, count: leaveCount, pages: leaveCount == null ? 1 : 2);
    }
    if (o.path == '/wfh/requests/') return _page(wfhs);
    if (o.path == '/attendance/corrections/') return _page(corrections);
    if (o.path == '/approvals/delegations/') return _json({'status': 'success', 'message': 'ok', 'data': <Object>[]});
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

class TestAuth extends AuthNotifier {
  TestAuth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

UserEntity user(List<String> perms, {bool team = false, List<String>? modules}) => UserEntity(
      id: 'u1',
      email: 'u@example.test',
      fullName: 'Test User',
      role: 'r',
      roleDisplay: 'Role',
      mustChangePassword: false,
      permissions: perms,
      canManageTeam: team,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

/// HR, the second approval level: approves leave and WFH, reviews corrections.
final hrL2 = user(['leave.approve', 'wfh.approve', 'attendance.create', 'attendance.edit']);
final managerL1 = user(['leave.approve'], team: true);
final employee = user(['leave.view', 'leave.create', 'attendance.view']);

/// A mixed inbox: level 1, level 2 (actionable and not), and finished rows.
Server mixed() => Server(
      leaves: [
        leave('l1', 'Lena Pending', 'pending'),
        leave('l2', 'Hari Leveltwo', 'l2_pending'),
        leave('l3', 'Nina Waiting', 'l2_pending', canApprove: false), // another approver's turn
        leave('l4', 'Ava Approved', 'approved', canApprove: false),
        leave('l5', 'Rex Rejected', 'rejected', canApprove: false),
        leave('l6', 'Cal Cancelled', 'cancelled', canApprove: false),
      ],
      wfhs: [wfh('w1', 'Wendy Workhome', 'l2_pending')],
      corrections: [
        correction('c1', 'Cora Correction', 'l2_pending'),
        correction('c2', 'Rae Resubmit', 'resubmit', canAction: false),
      ],
    );

late Server server;
late ProviderContainer container;

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> pump(WidgetTester tester, UserEntity u, Server s, {Size size = const Size(1080, 4000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = s;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => TestAuth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      approvalsTodayProvider.overrideWithValue(() => DateTime(2026, 11, 16, 10)),
    ],
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
            ? const SizedBox()
            : const Scaffold(body: ApprovalsScreen()),
      ),
    ),
  ));
  await settle(tester);
  final screen = find.byType(ApprovalsScreen);
  if (screen.evaluate().isNotEmpty) container = ProviderScope.containerOf(tester.element(screen));
}

Future<void> setStatus(WidgetTester tester, String status) async {
  container.read(approvalsStatusFilterProvider.notifier).state = status;
  await settle(tester);
}

/// One inbox row (approvals_list.dart's private _ApprovalCard).
final approvalCard = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ApprovalCard');

List<String> shown(List<String> names) => [for (final n in names) if (find.text(n).evaluate().isNotEmpty) n];

const everyone = [
  'Lena Pending', 'Hari Leveltwo', 'Nina Waiting', 'Ava Approved', 'Rex Rejected', 'Cal Cancelled', //
  'Wendy Workhome', 'Cora Correction', 'Rae Resubmit',
];
const pendingOnes = ['Lena Pending', 'Hari Leveltwo', 'Nina Waiting', 'Wendy Workhome', 'Cora Correction'];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('display status mirrors web toDisplayStatus', () {
    expect(approvalDisplayStatus('pending'), 'pending');
    expect(approvalDisplayStatus('l2_pending'), 'pending');
    expect(approvalDisplayStatus('stage2_pending'), 'pending');
    expect(approvalDisplayStatus('approved'), 'approved');
    expect(approvalDisplayStatus('rejected'), 'rejected');
    expect(approvalDisplayStatus('cancelled'), 'cancelled');
    expect(approvalDisplayStatus('resubmit'), 'cancelled');
    expect(approvalDisplayStatus(''), 'cancelled');
  });

  group('Pending filter (default)', () {
    testWidgets('mixed statuses: level 1 and level 2 rows shown; finished and resubmit rows hidden', (tester) async {
      await pump(tester, hrL2, mixed());
      expect(container.read(approvalsStatusFilterProvider), 'pending');
      expect(shown(everyone), pendingOnes);
      // Count and list agree (web counts display-status pending).
      expect(container.read(approvalsSummaryCountsProvider).pendingTotal, 5);
    });

    testWidgets('L2 approver with no L1 items: the inbox is not empty', (tester) async {
      await pump(
          tester,
          hrL2,
          Server(
            leaves: [leave('l2', 'Hari Leveltwo', 'l2_pending')],
            wfhs: [wfh('w1', 'Wendy Workhome', 'l2_pending')],
            corrections: [correction('c1', 'Cora Correction', 'l2_pending')],
          ));
      expect(shown(everyone), ['Hari Leveltwo', 'Wendy Workhome', 'Cora Correction']);
      expect(find.text('No requests match the current filters.'), findsNothing);
      expect(find.text('Pending HR'), findsWidgets); // the badge still names the stage
    });

    testWidgets('L1 approver: level-1 items still shown', (tester) async {
      await pump(tester, managerL1, Server(leaves: [leave('l1', 'Lena Pending', 'pending')]));
      expect(shown(everyone), ['Lena Pending']);
    });

    testWidgets('status options match web: All / Pending / Approved / Rejected (no separate "Pending HR")', (tester) async {
      await pump(tester, hrL2, mixed());
      await tester.tap(find.byKey(const Key('approvals-filters')));
      await settle(tester);
      for (final k in ['all', 'pending', 'approved', 'rejected']) {
        expect(find.byKey(Key('approvals-status-$k')), findsOneWidget, reason: k);
      }
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.textContaining('Pending HR')), findsNothing);
    });
  });

  group('other filters', () {
    testWidgets('Approved / Rejected / All; changing the filter sends no request', (tester) async {
      await pump(tester, hrL2, mixed());
      final before = server.gets.length;
      await setStatus(tester, 'approved');
      expect(shown(everyone), ['Ava Approved']);
      await setStatus(tester, 'rejected');
      expect(shown(everyone), ['Rex Rejected']);
      await setStatus(tester, 'all');
      expect(shown(everyone), everyone);
      await setStatus(tester, 'pending');
      expect(shown(everyone), pendingOnes);
      expect(server.gets.length, before); // filtering is local over the fetched set, as web
    });

    testWidgets('pull-to-refresh refetches; level-2 rows still shown', (tester) async {
      await pump(tester, hrL2, mixed());
      final before = server.gets.where((g) => g.$1 == '/leave/requests/').length;
      final done = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator).first).onRefresh();
      await settle(tester);
      await done;
      await settle(tester);
      expect(server.gets.where((g) => g.$1 == '/leave/requests/').length, greaterThan(before));
      expect(shown(everyone), pendingOnes);
    });
  });

  group('actions', () {
    testWidgets('Approve/Reject only where the server says canAction', (tester) async {
      await pump(tester, hrL2, mixed());
      // Lena, Hari, Wendy, Cora are actionable; Nina is someone else's turn.
      Finder rowOf(String name) => find.ancestor(of: find.text(name), matching: approvalCard).first;
      bool hasApprove(String name) =>
          find.descendant(of: rowOf(name), matching: find.text('Approve')).evaluate().isNotEmpty;
      expect(hasApprove('Hari Leveltwo'), isTrue);
      expect(hasApprove('Wendy Workhome'), isTrue);
      expect(hasApprove('Lena Pending'), isTrue);
      expect(hasApprove('Nina Waiting'), isFalse);
    });

    testWidgets('approving a level-2 leave sends the same request as before', (tester) async {
      await pump(tester, hrL2, mixed());
      final row = find.ancestor(of: find.text('Hari Leveltwo'), matching: approvalCard).first;
      final approve = find.descendant(of: row, matching: find.text('Approve'));
      await tester.ensureVisible(approve);
      await tester.tap(approve);
      await settle(tester);
      await tester.tap(find.text('Confirm Approval')); // the remarks dialog
      await settle(tester);
      expect(server.writes, hasLength(1));
      expect(server.writes.single.$2, contains('l2'));
      // Task 81: the remarks field now travels too (empty here, as web sends it).
      expect(server.writes.single.$3, {'action': 'approve', 'remarks': ''});
    });
  });

  group('requests, paging and access', () {
    testWidgets('one fetch per kind with every status (page_size 100, no status filter), as web', (tester) async {
      await pump(tester, hrL2, Server(leaves: [leave('l2', 'Hari Leveltwo', 'l2_pending')], leaveCount: 150));
      final q = server.gets.firstWhere((g) => g.$1 == '/leave/requests/').$2;
      expect(q['scope'], 'team');
      expect(q['page_size'], 100);
      expect(q.containsKey('status'), isFalse);
      expect(shown(everyone), ['Hari Leveltwo']);
    });

    testWidgets('ordinary employee: no approval permissions, no queue requested', (tester) async {
      expect(canAccessPath(employee, AppRoutes.approvals), isFalse);
      await pump(tester, employee, mixed());
      expect(find.text('You have no approval permissions.'), findsOneWidget);
      expect(server.gets.where((g) => g.$1 != '/approvals/delegations/'), isEmpty);
    });

    testWidgets('leave module off: leave queue not fetched; level-2 WFH still shown', (tester) async {
      await pump(tester, user(hrL2.permissions, modules: const ['wfh', 'attendance']), mixed());
      expect(server.gets.where((g) => g.$1 == '/leave/requests/'), isEmpty);
      expect(shown(everyone), ['Wendy Workhome', 'Cora Correction']);
    });
  });
}
