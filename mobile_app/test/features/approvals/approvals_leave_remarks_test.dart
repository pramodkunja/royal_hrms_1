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
import 'package:mobile_app/features/approvals/presentation/providers/approvals_providers.dart';
import 'package:mobile_app/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/delegations_tab.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// Task 81 (audit APR-08): leave approval remarks.
// Web approvals/_components/TeamApprovalsSection.tsx:
//   single: POST /leave/requests/<id>/approve/ {action, remarks, template_name,
//           extra_context}; bulk: {action, remarks}. ApprovalModal: remarks
//   optional to approve, required (non-blank) to reject; sent as typed.
// Backend hrms/views/leave.py LeaveApprovalView.post: reads `remarks` (or
//   `reason`), .strip()s it, stores it on l1_remarks / l2_remarks for
//   whichever stage is open (TextField, no length limit); same payload at
//   both levels; backend itself does not require remarks to reject.
// Mobile's approveLeave sent only {action: approve}, dropping the remarks
// the approver typed. WFH and correction payloads are untouched.
// Synthetic people; a stand-in server records every request body.

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _page(List<Object> rows) => _json({
      'status': 'success',
      'message': 'ok',
      'data': {'count': rows.length, 'page': 1, 'page_size': 100, 'total_pages': 1, 'results': rows},
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

Map<String, dynamic> wfh(String id, String name) => {
      'id': id,
      'employee_name': name,
      'employee_code': 'EMP-$id',
      'employee_dept': 'QA',
      'employee_branch': 'North',
      'start_date': '2026-11-21',
      'end_date': '2026-11-21',
      'status': 'l2_pending',
      'reason': 'Plumber visit',
      'location_label': 'Home',
      'is_medical': false,
      'created_at': '2026-11-14T09:00:00Z',
      'can_approve': true,
      'can_cancel': false,
    };

Map<String, dynamic> correction(String id, String name) => {
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
      'status': 'l2_pending',
      'has_document': false,
      'created_at': '2026-11-12T10:00:00Z',
      'can_action': true,
    };

class Server implements HttpClientAdapter {
  final writes = <(String, String, Object?)>[];
  String? refuse; // 400 with this message on writes
  int failNext = 0; // network failures before succeeding
  Completer<void>? hold; // keep writes in flight

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') {
      writes.add((o.method, o.path, o.data));
      if (hold != null) await hold!.future;
      if (failNext > 0) {
        failNext--;
        throw DioException(requestOptions: o, type: DioExceptionType.connectionError, message: 'offline');
      }
      if (refuse != null) return _json({'status': 'error', 'message': refuse, 'data': {}}, 400);
      return _json({'status': 'success', 'message': 'Request approved.', 'data': {}});
    }
    if (o.path == '/leave/requests/') {
      return _page([
        leave('l1', 'Lena Levelone', 'pending'),
        leave('l2', 'Hari Leveltwo', 'l2_pending'),
        leave('l9', 'Nina Waiting', 'l2_pending', canApprove: false),
      ]);
    }
    if (o.path == '/wfh/requests/') return _page([wfh('w1', 'Wendy Workhome')]);
    if (o.path == '/attendance/corrections/') return _page([correction('c1', 'Cora Correction')]);
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

/// Approves leave (both levels as the server decides), WFH and corrections.
const approver = UserEntity(
  id: 'u1',
  email: 'u@example.test',
  fullName: 'Test Approver',
  role: 'r',
  roleDisplay: 'Role',
  mustChangePassword: false,
  permissions: ['leave.approve', 'wfh.approve', 'attendance.create', 'attendance.edit'],
  canManageTeam: true,
  onboardingStatus: 'complete',
  assessmentStatus: 'complete',
);

late Server server;
late ProviderContainer container;
final approvalCard = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ApprovalCard');

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> pump(WidgetTester tester, {void Function(Server)? setup}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => TestAuth(approver)),
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
  container = ProviderScope.containerOf(tester.element(find.byType(ApprovalsScreen)));
}

/// Requests as plain lists, so map bodies compare by value.
List<List<Object?>> sent() => [for (final w in server.writes) [w.$1, w.$2, w.$3]];

Finder rowOf(String name) => find.ancestor(of: find.text(name), matching: approvalCard).first;
Finder buttonIn(String name, String label) => find.descendant(of: rowOf(name), matching: find.text(label));

/// Approve or Reject [name]'s row, type [remarks] (null = leave blank), confirm.
Future<void> act(WidgetTester tester, String name, {required bool approve, String? remarks}) async {
  final b = buttonIn(name, approve ? 'Approve' : 'Reject');
  await tester.ensureVisible(b);
  await tester.tap(b);
  await settle(tester);
  if (remarks != null) await tester.enterText(find.byType(TextField).last, remarks);
  await tester.tap(find.text(approve ? 'Confirm Approval' : 'Submit Rejection'));
  await settle(tester);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('leave approve / reject payloads', () {
    testWidgets('1. approve with remarks: remarks sent', (tester) async {
      await pump(tester);
      await act(tester, 'Lena Levelone', approve: true, remarks: 'Covered by Ravi');
      expect(sent(), [
        ['POST', '/leave/requests/l1/approve/', {'action': 'approve', 'remarks': 'Covered by Ravi'}]
      ]);
    });

    testWidgets('2. reject with remarks: remarks sent', (tester) async {
      await pump(tester);
      await act(tester, 'Lena Levelone', approve: false, remarks: 'Peak week');
      expect(server.writes.single.$3, {'action': 'reject', 'remarks': 'Peak week'});
    });

    testWidgets('3. approve without remarks: allowed; remarks sent empty (as web)', (tester) async {
      await pump(tester);
      await act(tester, 'Lena Levelone', approve: true);
      expect(server.writes.single.$3, {'action': 'approve', 'remarks': ''});
    });

    testWidgets('4. reject without remarks: blocked in the dialog (web rule); nothing sent', (tester) async {
      await pump(tester);
      await act(tester, 'Lena Levelone', approve: false, remarks: '   ');
      expect(find.text('Please provide a reason.'), findsOneWidget);
      expect(server.writes, isEmpty);
    });

    testWidgets('5. level 1 and level 2: same payload shape, server picks the stage', (tester) async {
      await pump(tester);
      await act(tester, 'Lena Levelone', approve: true, remarks: 'L1 ok');
      await act(tester, 'Hari Leveltwo', approve: true, remarks: 'L2 ok');
      expect(sent(), [
        ['POST', '/leave/requests/l1/approve/', {'action': 'approve', 'remarks': 'L1 ok'}],
        ['POST', '/leave/requests/l2/approve/', {'action': 'approve', 'remarks': 'L2 ok'}],
      ]);
    });

    testWidgets('6. whitespace trimmed; special characters kept exactly', (tester) async {
      await pump(tester);
      const text = 'Approved — "half-day" ✓ <ok> & 50% 😀';
      await act(tester, 'Hari Leveltwo', approve: true, remarks: '   $text  \n');
      expect(server.writes.single.$3, {'action': 'approve', 'remarks': text});
    });
  });

  group('failures, retry and double submission', () {
    testWidgets('7. backend validation error is shown; remarks were sent', (tester) async {
      await pump(tester, setup: (s) => s.refuse = 'You are not authorised to act on this request at the L2 stage.');
      await act(tester, 'Hari Leveltwo', approve: true, remarks: 'Fine');
      expect(server.writes.single.$3, {'action': 'approve', 'remarks': 'Fine'});
      expect(find.text('You are not authorised to act on this request at the L2 stage.'), findsOneWidget);
      expect(find.text('Hari Leveltwo'), findsOneWidget); // still in the inbox
    });

    testWidgets('8. network failure, then retry: the retry carries the remarks', (tester) async {
      await pump(tester, setup: (s) => s.failNext = 1);
      await act(tester, 'Hari Leveltwo', approve: true, remarks: 'Retry note');
      expect(server.writes, hasLength(1));
      expect(find.byType(SnackBar), findsOneWidget); // failure reported
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      await act(tester, 'Hari Leveltwo', approve: true, remarks: 'Retry note');
      expect(server.writes, hasLength(2));
      expect(server.writes.last.$3, {'action': 'approve', 'remarks': 'Retry note'});
    });

    testWidgets('9. double tap: one request while the first is in flight', (tester) async {
      await pump(tester, setup: (s) => s.hold = Completer<void>());
      await act(tester, 'Hari Leveltwo', approve: true, remarks: 'Once');
      expect(server.writes, hasLength(1));
      // While in flight, the row's actions are disabled.
      final approveBtn = find.byKey(const Key('approval-approve-l2'));
      expect(tester.widget<FilledButton>(approveBtn).onPressed, isNull);
      await tester.tap(approveBtn, warnIfMissed: false);
      await settle(tester);
      expect(find.text('Confirm Approval'), findsNothing);
      expect(server.writes, hasLength(1));
      server.hold!.complete();
      await settle(tester);
    });

    testWidgets('10. not this approver\'s turn: no Approve/Reject on the row', (tester) async {
      await pump(tester);
      expect(buttonIn('Nina Waiting', 'Approve'), findsNothing);
      expect(buttonIn('Nina Waiting', 'Reject'), findsNothing);
    });

    testWidgets('11. Task 80 Pending filter still shows level 1 and level 2', (tester) async {
      await pump(tester);
      expect(container.read(approvalsStatusFilterProvider), 'pending');
      for (final n in ['Lena Levelone', 'Hari Leveltwo', 'Nina Waiting', 'Wendy Workhome', 'Cora Correction']) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
    });
  });

  group('bulk and other queues', () {
    testWidgets('bulk approve: each leave carries the shared remarks (web bulk {action, remarks})', (tester) async {
      await pump(tester);
      final items = container
          .read(unifiedTeamApprovalsProvider)
          .requireValue
          .where((i) => i.kind == UnifiedApprovalKind.leave && i.canAction)
          .toList();
      await tester.runAsync(() =>
          container.read(unifiedTeamApprovalsProvider.notifier).bulkAction(items, approve: true, remarks: 'Bulk ok'));
      expect({for (final w in server.writes) w.$2: w.$3}, {
        '/leave/requests/l1/approve/': {'action': 'approve', 'remarks': 'Bulk ok'},
        '/leave/requests/l2/approve/': {'action': 'approve', 'remarks': 'Bulk ok'},
      });
    });

    testWidgets('12. WFH and attendance-correction payloads unchanged', (tester) async {
      await pump(tester);
      await act(tester, 'Wendy Workhome', approve: true, remarks: 'Fine');
      await act(tester, 'Cora Correction', approve: true, remarks: 'Fine');
      expect(server.writes[0].$2, contains('w1'));
      expect(server.writes[0].$3, {'action': 'approve', 'remarks': 'Fine'});
      expect(server.writes[1].$2, contains('c1'));
      expect(server.writes[1].$3, {'action': 'approve', 'remarks': 'Fine'});
    });
  });
}
