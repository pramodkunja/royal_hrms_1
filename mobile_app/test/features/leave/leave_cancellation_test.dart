import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/leave/data/models/leave_models.dart';
import 'package:mobile_app/features/leave/presentation/providers/leave_providers.dart';
import 'package:mobile_app/features/leave/presentation/widgets/leave_cancellation_panel.dart';
import 'package:mobile_app/features/leave/presentation/widgets/leave_request_detail_sheet.dart';

// Task 64: cancelling an APPROVED leave, as web LeaveCancellationPanel (leave
// detail) and Approvals → Leave Cancellations (LeaveCancellationsSection) over
// backend hrms views/leave_cancellation.py. The stand-in server applies the
// backend's rules (own approved leave not started, one request at a time,
// reason ≥ 5 chars, remarks required to reject, decided by the approver only)
// and its accounting (approval cancels the leave, used days go back).
// Synthetic people and leave; nothing real is changed.

const empId = 'emp-1';
const mgrId = 'mgr-1';
final future = DateTime.now().add(const Duration(days: 10));
final past = DateTime.now().subtract(const Duration(days: 2));
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One leave as the server holds it.
class Leave {
  Leave(this.id, {this.status = 'approved', DateTime? start, this.employee = empId, this.days = 2})
      : start = start ?? future;
  final String id;
  String status;
  final DateTime start;
  final String employee;
  final int days;
  String cancellationStatus = '';
  String cancellationReason = '';
  String cancellationRemarks = '';

  Map<String, dynamic> json(String viewer) {
    final own = viewer == employee;
    final startsLater = ymd(start).compareTo(ymd(DateTime.now())) > 0;
    return {
      'id': id,
      'employee_name': employee == empId ? 'Esha Test' : 'Other Person',
      'employee_code': employee == empId ? 'EMP-1' : 'EMP-9',
      'employee_branch': 'North',
      'employee_dept': 'QA',
      'leave_type': 'CL',
      'leave_type_display': 'Casual Leave',
      'duration_display': 'Full Day',
      'start_date': ymd(start),
      'end_date': ymd(start.add(Duration(days: days - 1))),
      'total_days': '$days.0',
      'status': status,
      'reason': 'Family function',
      'created_at': '2026-11-01T10:00:00Z',
      'can_approve': false,
      'can_cancel': own && (status == 'pending' || status == 'l2_pending'),
      'cancellation_status': cancellationStatus,
      'cancellation_reason': cancellationReason,
      'cancellation_requested_at': cancellationStatus == '' ? null : '2026-11-12T09:00:00Z',
      'cancellation_remarks': cancellationRemarks,
      'can_request_cancellation': own && status == 'approved' && startsLater && cancellationStatus != 'requested',
      'can_decide_cancellation': viewer == mgrId && status == 'approved' && cancellationStatus == 'requested',
    };
  }
}

class Server implements HttpClientAdapter {
  Server(this.viewer);
  final String viewer;
  final leaves = <String, Leave>{};
  double usedDays = 2;
  int balanceGets = 0;
  int cancellationListGets = 0;
  int? listStatus;
  int? decisionStatus;
  String? requestRefusal; // forces a 400 with this message on the request call
  final posts = <(String, Map<String, dynamic>)>[];
  final patches = <String>[];

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
  ResponseBody _ok(Object data, [String message = 'ok']) =>
      _json(200, {'status': 'success', 'message': message, 'data': data});
  ResponseBody _err(int status, String message, [Map<String, dynamic>? data]) =>
      _json(status, {'status': 'error', 'message': message, 'data': data ?? {}});

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    final path = o.uri.path.replaceFirst('/api', '');
    final detail = RegExp(r'^/leave/requests/([^/]+)/$').firstMatch(path);
    if (o.method == 'GET' && detail != null) {
      final l = leaves[detail.group(1)];
      return l == null ? _err(404, 'Leave request not found.') : _ok(l.json(viewer));
    }
    if (o.method == 'PATCH' && detail != null) {
      patches.add(detail.group(1)!);
      leaves[detail.group(1)]!.status = 'cancelled';
      return _ok(leaves[detail.group(1)]!.json(viewer));
    }
    final req = RegExp(r'^/leave/requests/([^/]+)/cancellation/$').firstMatch(path);
    if (o.method == 'POST' && req != null) {
      final body = Map<String, dynamic>.from(o.data as Map);
      posts.add((path, body));
      final l = leaves[req.group(1)];
      if (l == null || l.employee != viewer) return _err(404, 'Leave request not found.');
      if (requestRefusal != null) return _err(400, requestRefusal!);
      if (l.status != 'approved') {
        return _err(400, 'Only an approved leave needs a cancellation request — cancel a pending one directly.');
      }
      if (ymd(l.start).compareTo(ymd(DateTime.now())) <= 0) {
        return _err(400, 'This leave has already started. Contact HR to change it.');
      }
      if (l.cancellationStatus == 'requested') {
        return _err(400, 'A cancellation request is already waiting for approval.');
      }
      final reason = '${body['reason'] ?? ''}'.trim();
      if (reason.length < 5) {
        return _err(400, 'Give a reason for cancelling.', {
          'reason': ['Give a reason (at least 5 characters).']
        });
      }
      l
        ..cancellationStatus = 'requested'
        ..cancellationReason = reason
        ..cancellationRemarks = '';
      return _ok(l.json(viewer), 'Cancellation requested. You will be notified once it is decided.');
    }
    final dec = RegExp(r'^/leave/requests/([^/]+)/cancellation/decision/$').firstMatch(path);
    if (o.method == 'POST' && dec != null) {
      final body = Map<String, dynamic>.from(o.data as Map);
      posts.add((path, body));
      if (decisionStatus != null) return _err(decisionStatus!, 'You are not authorised to decide this cancellation.');
      final action = body['action'];
      final remarks = '${body['remarks'] ?? ''}'.trim();
      if (action == 'reject' && remarks.isEmpty) {
        return _err(400, 'Give a reason for rejecting — it is shown to the employee.');
      }
      final l = leaves[dec.group(1)];
      if (l == null || l.cancellationStatus != 'requested' || l.status != 'approved') {
        return _err(404, 'No cancellation request waiting for a decision.');
      }
      if (viewer != mgrId) return _err(403, 'You are not authorised to decide this cancellation.');
      l.cancellationRemarks = remarks;
      if (action == 'approve') {
        l
          ..cancellationStatus = 'approved'
          ..status = 'cancelled';
        usedDays -= l.days;
      } else {
        l.cancellationStatus = 'rejected';
      }
      return _ok(l.json(viewer));
    }
    if (o.method == 'GET' && path == '/leave/cancellations/') {
      cancellationListGets++;
      if (listStatus != null) return _err(listStatus!, 'Server error. Please try again later.');
      if (viewer != mgrId) return _ok(<Object>[]);
      return _ok([
        for (final l in leaves.values)
          if (l.status == 'approved' && l.cancellationStatus == 'requested' && l.employee != viewer) l.json(viewer)
      ]);
    }
    if (o.method == 'GET' && path == '/leave/balance/') {
      balanceGets++;
      return _ok([
        {'leave_type': 'CL', 'leave_type_display': 'Casual Leave', 'used_days': usedDays, 'total_days': 12}
      ]);
    }
    if (o.method == 'GET') return _ok(<Object>[]);
    return _err(404, 'Not found');
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

UserEntity user(String id, List<String> perms, {bool superuser = false, List<String>? modules}) => UserEntity(
      id: id,
      email: '$id@example.test',
      fullName: id,
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final employee = user(empId, ['leave.view']);
final approver = user(mgrId, ['leave.view', 'leave.approve']);

late Server server;
Finder byKey(String k) => find.byKey(Key(k));

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

/// Opens the leave detail sheet for [leaveId] as [as]. A balance line stays
/// on screen, so a refresh of the balance is visible (and counted).
Future<void> openDetail(WidgetTester tester, UserEntity as, String leaveId) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as),
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          ref.watch(authStateProvider);
          final bal = ref.watch(leaveBalancesProvider).valueOrNull;
          return Column(children: [
            Text('Used: ${bal == null || bal.isEmpty ? '?' : bal.first.used}', key: const Key('balance')),
            ElevatedButton(
              onPressed: () async {
                final l = LeaveRequestModel.fromJson(server.leaves[leaveId]!.json(as.id));
                await showLeaveRequestDetailSheet(context, initial: l);
              },
              child: const Text('open'),
            ),
          ]);
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

String? text(WidgetTester tester, String key) {
  final f = byKey(key);
  if (f.evaluate().isEmpty) return null;
  final w = tester.widget(f);
  if (w is Text) return w.data;
  return tester.widgetList<Text>(find.descendant(of: f, matching: find.byType(Text))).first.data;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules (pure)', () {
    test('web messages and badges', () {
      expect(cancellationReasonError('abcd'), 'Give a reason (at least 5 characters).');
      expect(cancellationReasonError('  abcde '), isNull);
      expect(rejectRemarksError('  '), 'Give a reason for rejecting — it is shown to the employee.');
      expect(rejectRemarksError('no'), isNull);
      expect(cancellationBadge('requested')!.$1, 'Cancellation pending');
      expect(cancellationBadge('approved')!.$1, 'Cancellation approved');
      expect(cancellationBadge('rejected')!.$1, 'Cancellation rejected');
      expect(cancellationBadge(''), isNull);
    });

    test('model reads the cancellation fields; older servers without them read as none', () {
      final l = Leave('l1')
        ..cancellationStatus = 'rejected'
        ..cancellationReason = 'Plans changed'
        ..cancellationRemarks = 'Peak season';
      final m = LeaveRequestModel.fromJson(l.json(empId));
      expect((m.cancellationStatus, m.cancellationReason, m.cancellationRemarks, m.canRequestCancellation),
          ('rejected', 'Plans changed', 'Peak season', true));
      final old = LeaveRequestModel.fromJson(const {'id': 'x', 'status': 'approved'});
      expect((old.cancellationStatus, old.canRequestCancellation, old.canDecideCancellation), ('', false, false));
    });

    test('6/11. reviewer tab: superuser flag or leave.approve, with the leave module; not settings.edit alone', () {
      expect(canReviewLeaveCancellations(approver), isTrue);
      expect(canReviewLeaveCancellations(user('s', const [], superuser: true)), isTrue);
      expect(canReviewLeaveCancellations(user('h', ['settings.edit'])), isFalse);
      expect(canReviewLeaveCancellations(employee), isFalse);
      expect(canReviewLeaveCancellations(user(mgrId, ['leave.approve'], modules: ['attendance'])), isFalse);
      expect(canReviewLeaveCancellations(user(mgrId, ['leave.approve'], modules: ['leave'])), isTrue);
    });
  });

  group('employee (leave detail)', () {
    testWidgets('1/2/9. eligible: request with a reason → web payload; pending badge; no second request',
        (tester) async {
      server = Server(empId)..leaves['l1'] = Leave('l1');
      await openDetail(tester, employee, 'l1');
      expect(byKey('leave-cancellation-panel'), findsOneWidget);
      await tapKey(tester, 'leave-cancellation-request');
      expect(find.text('Why do you want to cancel this leave? *'), findsOneWidget);
      expect(
          find.text('The leave stays approved until your approver accepts the cancellation; '
              'the days then return to your balance.'),
          findsOneWidget);
      await tester.enterText(byKey('leave-cancellation-text'), 'Plans changed');
      await tester.pump();
      await tapKey(tester, 'leave-cancellation-submit');
      expect(server.posts.single.$1, '/leave/requests/l1/cancellation/');
      expect(server.posts.single.$2, {'reason': 'Plans changed'});
      expect(text(tester, 'leave-cancellation-badge'), 'Cancellation pending');
      expect(find.text('Reason: “Plans changed”'), findsOneWidget);
      expect(byKey('leave-cancellation-request'), findsNothing, reason: 'the server says one is already waiting');
      expect(server.leaves['l1']!.status, 'approved', reason: 'stays approved until decided');
    });

    testWidgets('3. reason under 5 characters: web hint, Send disabled, nothing sent', (tester) async {
      server = Server(empId)..leaves['l1'] = Leave('l1');
      await openDetail(tester, employee, 'l1');
      await tapKey(tester, 'leave-cancellation-request');
      final send = byKey('leave-cancellation-submit');
      expect(tester.widget<FilledButton>(send).onPressed, isNull, reason: 'empty');
      expect(byKey('leave-cancellation-input-error'), findsNothing, reason: 'web shows the rule once typing starts');
      await tester.enterText(byKey('leave-cancellation-text'), 'abc');
      await tester.pump();
      expect(text(tester, 'leave-cancellation-input-error'), 'Give a reason (at least 5 characters).');
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      await tapKey(tester, 'leave-cancellation-back');
      expect(server.posts, isEmpty);
      expect(byKey('leave-cancellation-request'), findsOneWidget);
    });

    testWidgets('1. not eligible: started, pending, or someone else\'s leave — no request offered', (tester) async {
      server = Server(empId)
        ..leaves['started'] = Leave('started', start: past)
        ..leaves['pending'] = Leave('pending', status: 'pending')
        ..leaves['other'] = Leave('other', employee: 'emp-9');
      for (final id in ['started', 'pending', 'other']) {
        await openDetail(tester, employee, id);
        expect(byKey('leave-cancellation-request'), findsNothing, reason: id);
        expect(byKey('leave-cancellation-panel'), findsNothing, reason: '$id: no status, nothing to show');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('4/8. a request that is no longer allowed (already waiting): the server message', (tester) async {
      server = Server(empId)
        ..leaves['l1'] = Leave('l1')
        ..requestRefusal = 'A cancellation request is already waiting for approval.';
      await openDetail(tester, employee, 'l1');
      await tapKey(tester, 'leave-cancellation-request');
      await tester.enterText(byKey('leave-cancellation-text'), 'Plans changed');
      await tester.pump();
      await tapKey(tester, 'leave-cancellation-submit');
      expect(text(tester, 'leave-cancellation-error'), 'A cancellation request is already waiting for approval.');
      expect(byKey('leave-cancellation-text'), findsOneWidget, reason: 'the reason stays for another try');
    });

    testWidgets('5. history: a rejected request shows the decision note; the leave can be asked again', (tester) async {
      server = Server(empId)
        ..leaves['l1'] = (Leave('l1')
          ..cancellationStatus = 'rejected'
          ..cancellationReason = 'Plans changed'
          ..cancellationRemarks = 'Peak season, sorry');
      await openDetail(tester, employee, 'l1');
      expect(text(tester, 'leave-cancellation-badge'), 'Cancellation rejected');
      expect(find.text('Decision note: “Peak season, sorry”'), findsOneWidget);
      expect(byKey('leave-cancellation-request'), findsOneWidget);
      // Only the server's can_decide_cancellation offers decisions — never the requester.
      expect(byKey('leave-cancellation-approve'), findsNothing);
      expect(byKey('leave-cancellation-reject'), findsNothing);
    });

    testWidgets('5. history: an approved cancellation — the leave is cancelled', (tester) async {
      server = Server(empId)
        ..leaves['l1'] = (Leave('l1', status: 'cancelled')
          ..cancellationStatus = 'approved'
          ..cancellationReason = 'Plans changed');
      await openDetail(tester, employee, 'l1');
      expect(text(tester, 'leave-cancellation-badge'), 'Cancellation approved');
      expect(byKey('leave-cancellation-request'), findsNothing);
      expect(byKey('leave-cancellation-approve'), findsNothing);
    });

    testWidgets('12. a pending leave still has the existing Cancel Request (direct cancel)', (tester) async {
      server = Server(empId)..leaves['p1'] = Leave('p1', status: 'pending');
      await openDetail(tester, employee, 'p1');
      await tester.tap(find.text('Cancel Request'));
      await tester.pumpAndSettle();
      expect(server.patches, ['p1']);
      expect(server.posts, isEmpty);
    });
  });

  group('approver (leave detail)', () {
    Leave requested() => Leave('l1')
      ..cancellationStatus = 'requested'
      ..cancellationReason = 'Plans changed';

    testWidgets('7/9/10. approve: web payload; leave cancelled; the balance is re-read from the server',
        (tester) async {
      server = Server(mgrId)..leaves['l1'] = requested();
      await openDetail(tester, approver, 'l1');
      expect(text(tester, 'balance'), 'Used: 2.0');
      final balanceGets = server.balanceGets;
      await tapKey(tester, 'leave-cancellation-approve');
      expect(server.posts.single.$1, '/leave/requests/l1/cancellation/decision/');
      expect(server.posts.single.$2, {'action': 'approve', 'remarks': ''});
      expect(text(tester, 'leave-cancellation-badge'), 'Cancellation approved');
      expect(server.balanceGets, greaterThan(balanceGets));
      expect(text(tester, 'balance'), 'Used: 0.0', reason: 'the server returned the days; nothing computed here');
    });

    testWidgets('7. reject: remarks required (web hint), then sent; the leave stays approved', (tester) async {
      server = Server(mgrId)..leaves['l1'] = requested();
      await openDetail(tester, approver, 'l1');
      await tapKey(tester, 'leave-cancellation-reject');
      expect(find.text('Reason for rejecting *'), findsOneWidget);
      expect(tester.widget<FilledButton>(byKey('leave-cancellation-submit')).onPressed, isNull);
      await tester.enterText(byKey('leave-cancellation-text'), 'Peak season');
      await tester.pump();
      await tapKey(tester, 'leave-cancellation-submit');
      expect(server.posts.single.$2, {'action': 'reject', 'remarks': 'Peak season'});
      expect(text(tester, 'leave-cancellation-badge'), 'Cancellation rejected');
      expect(server.leaves['l1']!.status, 'approved');
    });

    testWidgets('6/8. not this leave\'s approver (403): the server message', (tester) async {
      server = Server(mgrId)
        ..leaves['l1'] = requested()
        ..decisionStatus = 403;
      await openDetail(tester, approver, 'l1');
      await tapKey(tester, 'leave-cancellation-approve');
      expect(text(tester, 'leave-cancellation-error'), 'You are not authorised to decide this cancellation.');
    });

    testWidgets('6. the employee never gets decision buttons on their own request', (tester) async {
      server = Server(empId)..leaves['l1'] = requested();
      await openDetail(tester, employee, 'l1');
      expect(text(tester, 'leave-cancellation-badge'), 'Cancellation pending');
      expect(byKey('leave-cancellation-approve'), findsNothing);
      expect(byKey('leave-cancellation-reject'), findsNothing);
    });
  });

  group('Approvals → Leave Cancellations', () {
    Future<void> pumpTab(WidgetTester tester, UserEntity as) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: overrides(as),
        child: const MaterialApp(home: Scaffold(body: LeaveCancellationsTab())),
      ));
      await tester.pumpAndSettle();
    }

    Server withRequests() => Server(mgrId)
      ..leaves['l1'] = (Leave('l1')
        ..cancellationStatus = 'requested'
        ..cancellationReason = 'Plans changed')
      ..leaves['l2'] = (Leave('l2', days: 1)
        ..cancellationStatus = 'requested'
        ..cancellationReason = 'Trip postponed');

    testWidgets('list: web title, rows with employee, dates, days and reason', (tester) async {
      server = withRequests();
      await pumpTab(tester, approver);
      expect(find.text('Leave cancellation requests'), findsOneWidget);
      expect(find.text('Approved leave the employee wants to cancel before it starts.'), findsOneWidget);
      final row = byKey('leave-cancellation-row-l1');
      expect(find.descendant(of: row, matching: find.text('Reason: “Plans changed”')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.textContaining('Casual Leave · ')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.textContaining('2 day(s)')), findsOneWidget);
      expect(find.text('Esha Test (EMP-1)', findRichText: true), findsNWidgets(2));
    });

    testWidgets('7/9/10. approve asks first (Cancel sends nothing), then sends; message; list refreshed',
        (tester) async {
      server = withRequests();
      await pumpTab(tester, approver);
      final gets = server.cancellationListGets;
      await tapKey(tester, 'leave-cancellation-row-approve-l1');
      expect(find.text("Cancel Esha Test's approved leave and return the days?"), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(server.posts, isEmpty);
      await tapKey(tester, 'leave-cancellation-row-approve-l1');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(server.posts.single.$2, {'action': 'approve', 'remarks': ''});
      expect(find.text('Leave cancelled and balance restored.'), findsOneWidget);
      expect(server.cancellationListGets, greaterThan(gets));
      expect(byKey('leave-cancellation-row-l1'), findsNothing);
      expect(byKey('leave-cancellation-row-l2'), findsOneWidget);
    });

    testWidgets('7. reject needs remarks; then sent; "Cancellation rejected."', (tester) async {
      server = withRequests();
      await pumpTab(tester, approver);
      await tapKey(tester, 'leave-cancellation-row-reject-l2');
      final confirm = byKey('leave-cancellation-row-confirm-reject-l2');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(byKey('leave-cancellation-row-remarks-l2'), 'Busy week');
      await tester.pump();
      await tapKey(tester, 'leave-cancellation-row-confirm-reject-l2');
      expect(server.posts.single.$2, {'action': 'reject', 'remarks': 'Busy week'});
      expect(find.text('Cancellation rejected.'), findsOneWidget);
    });

    testWidgets('8. a refused decision: the server message', (tester) async {
      server = withRequests()..decisionStatus = 403;
      await pumpTab(tester, approver);
      await tapKey(tester, 'leave-cancellation-row-approve-l1');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('You are not authorised to decide this cancellation.'), findsOneWidget);
    });

    testWidgets('empty, and a failed load with Retry', (tester) async {
      server = Server(mgrId)..listStatus = 500;
      await pumpTab(tester, approver);
      expect(byKey('leave-cancellations-error'), findsOneWidget);
      server.listStatus = null;
      await tapKey(tester, 'leave-cancellations-retry');
      expect(find.text('No cancellation requests waiting for you.'), findsOneWidget);
    });
  });

  group('Approvals screen tab', () {
    Future<List<String>> tabsFor(WidgetTester tester, UserEntity as) async {
      server = Server(as.id);
      await tester.pumpWidget(ProviderScope(
        overrides: overrides(as),
        child: const MaterialApp(home: ApprovalsScreen()),
      ));
      await tester.pumpAndSettle();
      final labels = tester.widgetList<Tab>(find.byType(Tab)).map((t) => t.text ?? '').toList();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      return labels;
    }

    testWidgets('6/11. shown for leave.approve with the leave module; hidden otherwise', (tester) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      expect(
          await tabsFor(tester, user(mgrId, ['leave.approve', 'expenses.approve'])), contains('Leave Cancellations'));
      expect(await tabsFor(tester, user(mgrId, ['leave.approve', 'expenses.approve'], modules: ['expenses'])),
          isNot(contains('Leave Cancellations')));
      expect(await tabsFor(tester, user('h', ['settings.edit', 'expenses.approve'])),
          isNot(contains('Leave Cancellations')));
    });
  });
}
