import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/approvals/data/approval_workflows.dart';
import 'package:mobile_app/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:mobile_app/core/router/access_control.dart' show canDelegateApprovals;
import 'package:mobile_app/features/approvals/presentation/widgets/delegations_tab.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/presentation/approval_rules/escalation_settings_card.dart';

// Task 68: approval delegation and automatic escalation — web
// approvals/_components/DelegationsSection.tsx, settings/approval-rules
// EscalationSettingsCard.tsx and lib/approvalWorkflows.ts over backend
// apps/approvals (views.py, services.py). The stand-in server applies the
// backend's rules (eligible = same branch and same approval right, never
// oneself; no overlap; only the delegator / creator / admin may revoke;
// settings.edit to change escalation). "Today" is 13 Nov 2026. Synthetic
// people only; nothing real is delegated.

final today = DateTime(2026, 11, 13);

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object data, [String message = 'ok', int status = 200]) =>
    _json(status, {'status': 'success', 'message': message, 'data': data});
ResponseBody _err(int status, String message, [Object? data]) =>
    _json(status, {'status': 'error', 'message': message, 'data': data ?? {}});

Map<String, dynamic> person(String id, String name, {String code = '', String branch = 'North'}) =>
    {'id': id, 'name': name, 'employee_id': code, 'branch': branch};

Map<String, dynamic> delegation(String id,
        {required Map<String, dynamic> delegator,
        required Map<String, dynamic> delegate,
        String start = '2026-11-10',
        String end = '2026-11-20',
        List<String> workflows = const ['leave'],
        String reason = '',
        bool revoked = false,
        bool canRevoke = true,
        bool given = true}) =>
    {
      'id': id,
      'delegator': delegator,
      'delegate': delegate,
      'start_date': start,
      'end_date': end,
      'workflows': workflows,
      'reason': reason,
      'active': !revoked,
      'revoked': revoked,
      'revoked_at': revoked ? '2026-11-12T10:00:00Z' : null,
      'can_revoke': canRevoke,
      'given': given,
      'received': !given,
      'created_at': '2026-11-01T10:00:00Z',
    };

final me = person('u-me', 'Mira Manager', code: 'EMP-1');
final asha = person('u-asha', 'Asha Approver', code: 'EMP-2');
final ravi = person('u-ravi', 'Ravi Reviewer', code: 'EMP-3');

class Backend implements HttpClientAdapter {
  List<Map<String, dynamic>> rows = [];
  Map<String, List<Map<String, dynamic>>> eligible = {
    'leave': [asha, ravi],
    'attendance': [ravi],
  };
  Map<String, dynamic> escalation = {
    'is_enabled': true,
    'reminder_after_days': 1,
    'first_escalation_after_days': 2,
    'second_escalation_after_days': 3,
    'escalation_head': person('u-head', 'Hari Head', code: 'EMP-9'),
    'applies_to_leave': true,
    'applies_to_attendance': true,
    'can_edit': true,
  };
  int escalationStatus = 200;
  int listStatus = 200;
  final calls = <(String, String, Object?, Map<String, dynamic>)>[]; // method, path, body, query
  ({int status, String message})? refuseNext;
  Completer<void>? hold;

  int count(String method, String path) => calls.where((c) => c.$1 == method && c.$2 == path).length;
  List<Object?> bodies(String method, String path) => [
        for (final c in calls)
          if (c.$1 == method && c.$2 == path) c.$3
      ];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((o.method, o.path, o.data, Map.of(o.queryParameters)));
    final p = o.path;
    if (p == ApiConstants.approvalsDelegations && o.method == 'GET') {
      if (listStatus != 200) return _err(listStatus, 'Server error.');
      return _ok(rows, 'Delegations.');
    }
    if (p == ApiConstants.approvalsDelegationsEligible) {
      return _ok(eligible['${o.queryParameters['workflow']}'] ?? const [], 'Eligible delegates.');
    }
    if (p == ApiConstants.approvalsDelegations && o.method == 'POST') {
      if (hold != null) await hold!.future;
      final r = refuseNext;
      if (r != null) {
        refuseNext = null;
        return _err(r.status, r.message);
      }
      final b = Map<String, dynamic>.from(o.data as Map);
      final d = delegation('d-new',
          delegator: me,
          delegate: [...eligible['leave']!, ...eligible['attendance']!].firstWhere((x) => x['id'] == b['delegate']),
          start: b['start_date'] as String,
          end: b['end_date'] as String,
          workflows: List<String>.from(b['workflows'] as List),
          reason: b['reason'] as String);
      rows = [d, ...rows];
      return _ok(d, 'Delegation created.', 201);
    }
    final revoke = RegExp(r'^/approvals/delegations/([^/]+)/revoke/$').firstMatch(p);
    if (revoke != null && o.method == 'POST') {
      final r = refuseNext;
      if (r != null) {
        refuseNext = null;
        return _err(r.status, r.message);
      }
      final row = rows.where((x) => x['id'] == revoke.group(1)).firstOrNull;
      if (row == null) return _err(404, 'Delegation not found.');
      row['revoked'] = true;
      row['can_revoke'] = false;
      return _ok(row, 'Delegation revoked.');
    }
    if (p == ApiConstants.approvalsEscalationSettings && o.method == 'GET') {
      if (escalationStatus != 200) return _err(escalationStatus, 'Permission denied.');
      return _ok(escalation, 'Escalation settings.');
    }
    if (p == ApiConstants.approvalsEscalationSettings && o.method == 'PUT') {
      final r = refuseNext;
      if (r != null) {
        refuseNext = null;
        return _err(r.status, r.message);
      }
      escalation = {...escalation, ...Map<String, dynamic>.from(o.data as Map)};
      return _ok(escalation, 'Escalation settings saved.');
    }
    if (p == ApiConstants.approvalsEscalationHeadCandidates) {
      return _ok([person('u-head', 'Hari Head', code: 'EMP-9'), person('u-hr2', 'Hema HR', code: 'EMP-8')]);
    }
    return _ok({'count': 0, 'page': 1, 'page_size': 100, 'total_pages': 1, 'results': <Object>[]});
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

UserEntity user(List<String> perms, {bool superuser = false, bool team = false, bool branch = false, List<String>? modules}) =>
    UserEntity(
      id: 'u-me',
      email: 'm@example.test',
      fullName: 'Mira Manager',
      role: 'manager',
      roleDisplay: 'Manager',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      canManageTeam: team,
      canManageBranch: branch,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final leaveApprover = user(['leave.approve', 'leave.view']);

late Backend server;
DateTime? nextDate;
Finder byKey(String k) => find.byKey(Key(k));

Future<void> pump(WidgetTester tester, Widget child, {UserEntity? as, void Function(Backend)? setup}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Backend();
  setup?.call(server);
  nextDate = null;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? leaveApprover)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      approvalsTodayProvider.overrideWithValue(() => today),
      delegationDatePickerProvider.overrideWithValue((context, initial, first, last) async => nextDate),
    ],
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) =>
            ref.watch(authStateProvider).valueOrNull?.user == null ? const SizedBox() : Scaffold(body: child),
      ),
    ),
  ));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await settle(tester);
}

Future<void> chooseDelegate(WidgetTester tester, String label) async {
  await tester.ensureVisible(byKey('delegation-delegate'));
  await tester.tap(byKey('delegation-delegate'));
  await settle(tester);
  await tester.tap(find.text(label).last);
  await settle(tester);
}

Future<void> pickDate(WidgetTester tester, String key, DateTime d) async {
  nextDate = d;
  await tapKey(tester, key);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules (web lib/approvalWorkflows.ts)', () {
    test('who may delegate: leave.approve, or attendance.create held by attendance staff', () {
      expect(canDelegateApprovals(leaveApprover), isTrue);
      expect(canDelegateApprovals(user(['attendance.create', 'attendance.edit'])), isTrue);
      expect(canDelegateApprovals(user(['attendance.create'], team: true)), isTrue);
      expect(canDelegateApprovals(user(['attendance.create'], branch: true)), isTrue);
      expect(canDelegateApprovals(user(const [], superuser: true)), isTrue);
      expect(canDelegateApprovals(user(['attendance.create'])), isFalse); // not attendance staff
      expect(canDelegateApprovals(user(['expenses.approve', 'wfh.approve'])), isFalse);
      // Task 71g: settings.edit counts, as in the backend's has_perm
      // (can_approve_workflow), also for an older session without the flag.
      expect(canDelegateApprovals(user(['settings.edit'])), isTrue);
      expect(canDelegateApprovals(null), isFalse);
    });

    test('delegation form checks (messages as web)', () {
      const t = '2026-11-13';
      expect(validateDelegation(const DelegationForm(workflows: []), t), {
        'delegate': 'Choose who approves in your place.',
        'workflows': 'Choose Leave and/or Attendance requests.',
        'start_date': 'Choose a start date.',
        'end_date': 'Choose an end date.',
      });
      DelegationForm f(String s, String e, [String reason = '']) =>
          DelegationForm(delegate: 'x', startDate: s, endDate: e, reason: reason);
      expect(validateDelegation(f('2026-11-15', '2026-11-14'), t)['end_date'],
          'The end date must be on or after the start date.');
      expect(validateDelegation(f('2026-11-01', '2026-11-12'), t)['end_date'], 'The end date is in the past.');
      expect(validateDelegation(f('2026-11-13', '2027-05-11'), t), isEmpty); // 180 days
      expect(validateDelegation(f('2026-11-13', '2027-05-12'), t)['end_date'], 'A delegation can last at most 180 days.');
      expect(validateDelegation(f('2026-11-13', '2026-11-13', 'x' * 301), t)['reason'],
          'Keep the reason under 300 characters.');
      expect(
          const DelegationForm(
                  delegate: 'u-asha', startDate: '2026-11-13', endDate: '2026-11-20', workflows: ['leave'], reason: 'Away')
              .toPayload(),
          {
            'delegate': 'u-asha',
            'start_date': '2026-11-13',
            'end_date': '2026-11-20',
            'workflows': ['leave'],
            'reason': 'Away'
          });
    });

    test('state from the server\'s dates: active / scheduled / ended / revoked', () {
      Delegation d(String s, String e, {bool revoked = false}) =>
          Delegation.fromJson(delegation('1', delegator: me, delegate: asha, start: s, end: e, revoked: revoked));
      const t = '2026-11-13';
      expect(delegationState(d('2026-11-10', '2026-11-13'), t), 'active');
      expect(delegationState(d('2026-11-14', '2026-11-20'), t), 'scheduled');
      expect(delegationState(d('2026-11-01', '2026-11-12'), t), 'ended');
      expect(delegationState(d('2026-11-10', '2026-11-20', revoked: true), t), 'revoked');
    });

    test('escalation checks and the described timeline (web)', () {
      EscalationForm f({int? r = 1, int? a = 2, int? b = 3, bool on = true, bool leave = true, bool att = true}) =>
          EscalationForm(
              isEnabled: on,
              reminderAfterDays: r,
              firstEscalationAfterDays: a,
              secondEscalationAfterDays: b,
              escalationHead: '',
              appliesToLeave: leave,
              appliesToAttendance: att);
      expect(validateEscalation(f()), isEmpty);
      expect(validateEscalation(f(r: 31))['reminder_after_days'], 'Enter 0–30 working days (0 = no reminder).');
      expect(validateEscalation(f(a: 0))['first_escalation_after_days'], 'Enter 1–30 working days.');
      expect(validateEscalation(f(b: null))['second_escalation_after_days'],
          'Enter 0–30 working days (0 = no second escalation).');
      expect(validateEscalation(f(r: 2, a: 2))['reminder_after_days'], 'The reminder must come before the first escalation.');
      expect(validateEscalation(f(r: 0, a: 1)), isEmpty);
      expect(validateEscalation(f(leave: false, att: false))['applies_to_leave'], 'Choose at least one request type.');
      expect(validateEscalation(f(on: false, leave: false, att: false)), isEmpty);
      expect(escalationTimeline(f(), 'Hari Head'), [
        (1, 'Reminder to the current approver (and their delegate)'),
        (2, "Escalated to the approver's reporting manager (next higher approver)"),
        (5, 'Escalated to Hari Head (escalation head)'),
      ]);
      expect(escalationTimeline(f(r: 0, b: 2)).last, (4, 'Escalation head not set — this step is skipped'));
      expect(escalationTimeline(f(b: 0)).length, 2);
    });
  });

  group('Approvals → Delegation', () {
    testWidgets('tab shown for approvers who can delegate; not for others', (tester) async {
      await pump(tester, const ApprovalsScreen());
      expect(find.text('Delegation'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, const ApprovalsScreen(), as: user(['expenses.approve']));
      expect(find.text('Delegation'), findsNothing);
      expect(server.count('GET', ApiConstants.approvalsDelegations), 0);
    });

    testWidgets('lists: by me / to me, server states, Revoke only where the server allows', (tester) async {
      await pump(tester, const DelegationsTab(), setup: (s) {
        s.rows = [
          delegation('a', delegator: me, delegate: asha, reason: 'Annual leave'),
          delegation('b', delegator: me, delegate: ravi, start: '2026-11-20', end: '2026-11-25', workflows: ['leave', 'attendance']),
          delegation('c', delegator: me, delegate: asha, start: '2026-10-01', end: '2026-10-05', canRevoke: false),
          delegation('d', delegator: me, delegate: ravi, revoked: true, canRevoke: false),
          delegation('e', delegator: person('u-x', 'Xena Lead'), delegate: me, given: false, canRevoke: false),
        ];
      });
      expect(find.text('Delegated by me'), findsOneWidget);
      String state(String id) =>
          tester.widget<Text>(find.descendant(of: byKey('delegation-state-$id'), matching: find.byType(Text))).data!;
      expect(state('a'), 'Active');
      expect(state('b'), 'Scheduled');
      expect(state('c'), 'Ended');
      expect(state('d'), 'Revoked');
      expect(find.text('Annual leave'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget); // workflow chips: Leave, Attendance
      expect(byKey('delegation-revoke-a'), findsOneWidget);
      expect(byKey('delegation-revoke-c'), findsNothing);
      expect(byKey('delegation-revoke-d'), findsNothing);
      expect(byKey('delegation-revoke-e'), findsNothing); // the delegate can't revoke on web
      expect(find.descendant(of: byKey('delegation-row-e'), matching: find.text('Xena Lead')), findsOneWidget);
    });

    testWidgets('empty lists: web texts', (tester) async {
      await pump(tester, const DelegationsTab());
      expect(find.text("You haven't delegated your approvals."), findsOneWidget);
      expect(find.text('No one has delegated approvals to you.'), findsOneWidget);
    });

    testWidgets('create: checks before sending; eligible people from the server; exact payload; refresh',
        (tester) async {
      await pump(tester, const DelegationsTab());
      await tapKey(tester, 'delegation-create');
      expect(find.text('Choose who approves in your place.'), findsOneWidget);
      expect(find.text('Choose an end date.'), findsOneWidget);
      expect(server.count('POST', ApiConstants.approvalsDelegations), 0);
      // Eligible list is the server's (never oneself) for the first chosen workflow.
      expect(server.calls.where((c) => c.$2 == ApiConstants.approvalsDelegationsEligible).last.$4, {'workflow': 'leave'});
      await tester.tap(byKey('delegation-delegate'));
      await settle(tester);
      expect(find.text('Asha Approver (EMP-2)'), findsWidgets);
      expect(find.text('Mira Manager (EMP-1)'), findsNothing);
      await tester.tap(find.text('Asha Approver (EMP-2)').last);
      await settle(tester);
      await pickDate(tester, 'delegation-end', DateTime(2026, 11, 20));
      await tester.enterText(byKey('delegation-reason'), 'Annual leave');
      await tapKey(tester, 'delegation-workflow-attendance');
      final listsBefore = server.count('GET', ApiConstants.approvalsDelegations);
      await tapKey(tester, 'delegation-create');
      expect(server.bodies('POST', ApiConstants.approvalsDelegations).single, {
        'delegate': 'u-asha',
        'start_date': '2026-11-13',
        'end_date': '2026-11-20',
        'workflows': ['leave', 'attendance'],
        'reason': 'Annual leave',
      });
      expect(find.text('Delegation created. The delegate has been notified.'), findsOneWidget);
      expect(server.count('GET', ApiConstants.approvalsDelegations), listsBefore + 1);
      expect(byKey('delegation-row-d-new'), findsOneWidget);
      // Form reset: start today, no end, Leave only.
      expect(find.descendant(of: byKey('delegation-start'), matching: find.text('2026-11-13')), findsOneWidget);
      expect(find.descendant(of: byKey('delegation-end'), matching: find.text('—')), findsOneWidget);
    });

    testWidgets('attendance only: eligible people asked for "attendance"', (tester) async {
      await pump(tester, const DelegationsTab());
      await tapKey(tester, 'delegation-workflow-attendance');
      await tapKey(tester, 'delegation-workflow-leave');
      expect(server.calls.where((c) => c.$2 == ApiConstants.approvalsDelegationsEligible).last.$4,
          {'workflow': 'attendance'});
      await tester.tap(byKey('delegation-delegate'));
      await settle(tester);
      expect(find.text('Asha Approver (EMP-2)'), findsNothing); // can't approve attendance
      expect(find.text('Ravi Reviewer (EMP-3)'), findsWidgets);
      await tester.tap(find.text('Ravi Reviewer (EMP-3)').last);
      await settle(tester);
      await tapKey(tester, 'delegation-workflow-attendance');
      await tapKey(tester, 'delegation-create');
      expect(find.text('Choose Leave and/or Attendance requests.'), findsOneWidget);
      expect(server.count('POST', ApiConstants.approvalsDelegations), 0);
    });

    testWidgets('server refusal (overlap / other branch): its message; the form is kept', (tester) async {
      await pump(tester, const DelegationsTab());
      await chooseDelegate(tester, 'Ravi Reviewer (EMP-3)');
      await pickDate(tester, 'delegation-end', DateTime(2026, 11, 18));
      server.refuseNext = (status: 400, message: 'These dates overlap another active delegation — revoke it first.');
      await tapKey(tester, 'delegation-create');
      expect(find.text('These dates overlap another active delegation — revoke it first.'), findsOneWidget);
      expect(find.descendant(of: byKey('delegation-end'), matching: find.text('2026-11-18')), findsOneWidget);
      server.refuseNext = (status: 400, message: 'The delegate must be in the same branch as the approver.');
      await tapKey(tester, 'delegation-create');
      expect(find.text('The delegate must be in the same branch as the approver.'), findsOneWidget);
      server.refuseNext = (status: 500, message: '');
      await tapKey(tester, 'delegation-create');
      expect(find.text('Failed to create the delegation.'), findsOneWidget);
    });

    testWidgets('one create at a time', (tester) async {
      await pump(tester, const DelegationsTab());
      await chooseDelegate(tester, 'Ravi Reviewer (EMP-3)');
      await pickDate(tester, 'delegation-end', DateTime(2026, 11, 18));
      server.hold = Completer<void>();
      await tester.tap(byKey('delegation-create'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tap(byKey('delegation-create'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      server.hold!.complete();
      await settle(tester);
      expect(server.count('POST', ApiConstants.approvalsDelegations), 1);
    });

    testWidgets('revoke: confirm, POST …/revoke/, list reloaded; Cancel sends nothing; refusal shown', (tester) async {
      await pump(tester, const DelegationsTab(), setup: (s) {
        s.rows = [delegation('a', delegator: me, delegate: asha)];
      });
      await tapKey(tester, 'delegation-revoke-a');
      expect(find.text('Revoke the delegation to Asha Approver?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(server.count('POST', ApiConstants.approvalsDelegationRevoke('a')), 0);
      server.refuseNext = (status: 403, message: 'Only the approver or an administrator can revoke this delegation.');
      await tapKey(tester, 'delegation-revoke-a');
      await tapKey(tester, 'delegation-revoke-confirm');
      expect(find.text('Only the approver or an administrator can revoke this delegation.'), findsOneWidget);
      await tapKey(tester, 'delegation-revoke-a');
      await tapKey(tester, 'delegation-revoke-confirm');
      expect(server.count('POST', ApiConstants.approvalsDelegationRevoke('a')), 2);
      expect(find.text('Delegation revoked.'), findsOneWidget);
      expect(byKey('delegation-revoke-a'), findsNothing);
      expect(
          tester.widget<Text>(find.descendant(of: byKey('delegation-state-a'), matching: find.byType(Text))).data, 'Revoked');
    });

    testWidgets('list failure: the server message and Retry', (tester) async {
      await pump(tester, const DelegationsTab(), setup: (s) => s.listStatus = 500);
      expect(find.text('Server error.'), findsOneWidget);
      expect(find.text('Delegated by me'), findsNothing);
      server.listStatus = 200;
      server.rows = [delegation('a', delegator: me, delegate: asha)];
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(byKey('delegation-row-a'), findsOneWidget);
    });
  });

  group('Settings → Approval Rules → escalation', () {
    testWidgets('shown with the server values and the described steps; edit sends web\'s payload', (tester) async {
      await pump(tester, const SingleChildScrollView(child: EscalationSettingsCard()));
      expect(find.text('Automatic Reminders & Escalation'), findsOneWidget);
      expect(find.textContaining('Day 5:', findRichText: true), findsOneWidget);
      expect(find.textContaining('Escalated to Hari Head (escalation head)', findRichText: true), findsOneWidget);
      expect(server.count('GET', ApiConstants.approvalsEscalationHeadCandidates), 1);
      await tester.enterText(byKey('esc-reminder_after_days'), '2');
      await settle(tester);
      expect(find.text('The reminder must come before the first escalation.'), findsOneWidget);
      expect(tester.widget<FilledButton>(byKey('esc-save')).onPressed, isNull);
      await tester.enterText(byKey('esc-reminder_after_days'), '0');
      await tester.enterText(byKey('esc-second_escalation_after_days'), '4');
      await settle(tester);
      await tester.tap(byKey('esc-head'));
      await settle(tester);
      await tester.tap(find.text('— Not set (second escalation skipped) —').last);
      await settle(tester);
      expect(find.textContaining('Escalation head not set — this step is skipped', findRichText: true), findsOneWidget);
      await tapKey(tester, 'esc-attendance');
      await tapKey(tester, 'esc-save');
      expect(server.bodies('PUT', ApiConstants.approvalsEscalationSettings).single, {
        'is_enabled': true,
        'reminder_after_days': 0,
        'first_escalation_after_days': 2,
        'second_escalation_after_days': 4,
        'escalation_head': null,
        'applies_to_leave': true,
        'applies_to_attendance': false,
      });
      expect(byKey('esc-saved'), findsOneWidget);
    });

    testWidgets('enabled with no request type: refused before sending', (tester) async {
      await pump(tester, const SingleChildScrollView(child: EscalationSettingsCard()));
      await tapKey(tester, 'esc-leave');
      await tapKey(tester, 'esc-attendance');
      expect(find.text('Choose at least one request type.'), findsOneWidget);
      expect(tester.widget<FilledButton>(byKey('esc-save')).onPressed, isNull);
      expect(server.count('PUT', ApiConstants.approvalsEscalationSettings), 0);
    });

    testWidgets('save refused: the server message', (tester) async {
      await pump(tester, const SingleChildScrollView(child: EscalationSettingsCard()));
      await tapKey(tester, 'esc-enabled');
      server.refuseNext = (status: 400, message: 'Escalation head not found.');
      await tapKey(tester, 'esc-save');
      expect(find.text('Escalation head not found.'), findsOneWidget);
      expect(byKey('esc-saved'), findsNothing);
    });

    testWidgets('read only (no settings.edit): no Save, no candidate list fetched, fields locked', (tester) async {
      await pump(tester, const SingleChildScrollView(child: EscalationSettingsCard()),
          setup: (s) => s.escalation = {...s.escalation, 'can_edit': false});
      expect(byKey('esc-save'), findsNothing);
      expect(server.count('GET', ApiConstants.approvalsEscalationHeadCandidates), 0);
      expect(tester.widget<Switch>(byKey('esc-enabled')).onChanged, isNull);
      expect(tester.widget<TextField>(byKey('esc-reminder_after_days')).enabled, isFalse);
      expect(find.textContaining('Hari Head'), findsWidgets); // saved head still shown
    });

    testWidgets('no settings access (403): nothing shown', (tester) async {
      await pump(tester, const SingleChildScrollView(child: EscalationSettingsCard()),
          setup: (s) => s.escalationStatus = 403);
      expect(byKey('escalation-settings'), findsNothing);
      expect(byKey('escalation-load-error'), findsNothing);
    });
  });
}
