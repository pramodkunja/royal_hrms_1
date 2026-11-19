import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_kit.dart';
import 'package:mobile_app/features/profile/presentation/widgets/profile_widgets.dart' show ProfileDisplayField;
import 'package:mobile_app/features/approvals/presentation/widgets/attendance_approval_tab.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/delegations_tab.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/face_registration_approvals_tab.dart';
import 'package:mobile_app/features/leave/presentation/widgets/leave_cancellation_panel.dart';

import '../features/approvals/secondary_tabs_harness.dart';
import 'shot_harness.dart';

// Task 101.1 — render evidence for the four secondary Approvals tabs (see
// shot_harness.dart; the shots only run with T1011_SHOTS=1). The same pumps
// also run in the normal suite as structure tests (shot-free): every tab must
// be built from ApprovalsRequestCard, keep 44 dp actions and not overflow.

Map<String, dynamic> _person(String id, String name, String code) =>
    {'id': id, 'name': name, 'employee_id': code, 'branch': 'Surat'};

Map<String, dynamic> _emp(String uuid, String id, String name, String dept, String desig,
        {int present = 21, int late = 0, int half = 0, int leave = 0, int absent = 0, int lop = 0, double hrs = 168}) =>
    {
      'employee_id': id,
      'employee_uuid': uuid,
      'full_name': name,
      'department': dept,
      'designation': desig,
      'present_days': present,
      'late_days': late,
      'half_days': half,
      'absent_days': absent,
      'on_leave_days': leave,
      'lop_days': lop,
      'working_hours': hrs,
    };

FakeServer attendanceServer() {
  final s = FakeServer();
  s.on(
      'GET ${ApiConstants.payrollPendingApproval}',
      (_) => ok([
            {
              'id': 'c1',
              'cycle_start': '2026-10-01',
              'cycle_end': '2026-10-31',
              'pay_date': '2026-11-05',
              'status': 'attendance_pending'
            },
            {
              'id': 'c2',
              'cycle_start': '2026-09-01',
              'cycle_end': '2026-09-30',
              'pay_date': '2026-10-05',
              'status': 'attendance_pending'
            },
          ]));
  s.on(
      'GET ${ApiConstants.payrollAttendanceSummary('c1')}',
      (_) => ok({
            'cycle': {
              'id': 'c1',
              'cycle_start': '2026-10-01',
              'cycle_end': '2026-10-31',
              'pay_date': '2026-11-05',
              'status': 'attendance_pending',
              'l1_approver': null,
              'l2_approver': null,
              'manager_approvals': [
                {
                  'id': 'm1',
                  'manager_name': 'Rohan Mehta',
                  'approved_at': '2026-11-03T15:07:00',
                  'self_approved_at': null
                },
                {'id': 'm2', 'manager_name': 'Kavya Iyer', 'approved_at': null, 'self_approved_at': null},
              ],
              'mgr_approved_count': 1,
              'mgr_total_count': 2,
              'mgr_all_approved': false,
              'current_user_pending': true,
            },
            'employees': [
              _emp('u1', 'EMP-0042', 'Anika Sharma', 'Engineering', 'Senior Engineer',
                  late: 2, half: 1, lop: 2, absent: 2),
              _emp('u2', 'EMP-0057', 'Imran Qureshi', 'Operations', 'Analyst', leave: 3, hrs: 150.5),
              _emp('u3', 'EMP-0063', 'Sneha Patel', 'Finance', 'Accountant'),
            ],
          }));
  s.on(
      'GET ${ApiConstants.payrollEmployeeDailyAttendance('c1', 'u1')}',
      (_) => ok({
            'employee_id': 'EMP-0042',
            'full_name': 'Anika Sharma',
            'days': [
              {
                'date': '2026-10-01',
                'day': 'Thu',
                'status': 'present',
                'status_label': 'Present',
                'working_hours': 8.5,
                'is_flagged': false
              },
              {
                'date': '2026-10-02',
                'day': 'Fri',
                'status': 'late',
                'status_label': 'Late',
                'working_hours': 7.75,
                'is_flagged': false
              },
              {
                'date': '2026-10-03',
                'day': 'Sat',
                'status': 'absent',
                'status_label': 'Absent',
                'working_hours': 0,
                'is_flagged': true
              },
              {
                'date': '2026-10-04',
                'day': 'Sun',
                'status': 'weekly_off',
                'status_label': 'Weekly Off',
                'working_hours': 0,
                'is_flagged': false
              },
              {
                'date': '2026-10-05',
                'day': 'Mon',
                'status': 'incomplete',
                'status_label': 'Incomplete',
                'working_hours': 3,
                'is_flagged': true
              },
              {
                'date': '2026-10-06',
                'day': 'Tue',
                'status': 'half_day',
                'status_label': 'Half Day',
                'working_hours': 4.5,
                'is_flagged': false
              },
            ],
          }));
  return s;
}

FakeServer faceServer() {
  final s = FakeServer();
  s.on(
      'GET ${ApiConstants.faceRegistrationPending}',
      (_) => ok({
            'count': 2,
            'page': 1,
            'page_size': 20,
            'total_pages': 1,
            'results': [
              {
                'id': 'f1',
                'employee_name': 'Anika Sharma',
                'employee_email': 'anika.sharma@example.test',
                'liveness_passed': true,
                'liveness_score': 0.923,
                'status': 'pending',
                'created_at': '2026-11-17T10:00:00'
              },
              {
                'id': 'f2',
                'employee_name': 'Rohan Mehta',
                'employee_email': 'rohan.mehta@example.test',
                'liveness_passed': false,
                'liveness_score': 0.41,
                'status': 'pending',
                'created_at': '2026-11-18T09:30:00'
              },
            ],
          }));
  return s;
}

FakeServer delegationServer() {
  final s = FakeServer();
  Map<String, dynamic> d(String id, String name, String code,
          {bool given = true,
          String reason = '',
          String start = '2026-11-10',
          String end = '2026-11-20',
          bool revoked = false,
          List<String> wf = const ['leave', 'attendance']}) =>
      {
        'id': id,
        'delegator': given ? _person('u-me', 'Priya Natarajan', 'EMP-0042') : _person('u-x', name, code),
        'delegate': given ? _person('u-d', name, code) : _person('u-me', 'Priya Natarajan', 'EMP-0042'),
        'start_date': start,
        'end_date': end,
        'workflows': wf,
        'reason': reason,
        'revoked': revoked,
        'can_revoke': !revoked,
        'given': given,
        'received': !given,
      };
  s.on(
      'GET ${ApiConstants.approvalsDelegations}',
      (_) => ok([
            d('d1', 'Rohan Mehta', 'EMP-0057', reason: 'Annual leave'),
            d('d2', 'Kavya Iyer', 'EMP-0063', start: '2026-12-01', end: '2026-12-05', wf: ['leave']),
            d('d3', 'Anika Sharma', 'EMP-0011',
                given: false, start: '2026-11-12', end: '2026-11-15', reason: 'Conference travel'),
          ]));
  s.on('GET ${ApiConstants.approvalsDelegationsEligible}', (_) => ok([_person('u-d', 'Rohan Mehta', 'EMP-0057')]));
  return s;
}

FakeServer cancellationServer() {
  final s = FakeServer();
  Map<String, dynamic> r(
          String id, String name, String code, String type, String from, String to, String days, String reason) =>
      {
        'id': id,
        'employee_name': name,
        'employee_code': code,
        'leave_type': 'casual',
        'leave_type_display': type,
        'start_date': from,
        'end_date': to,
        'total_days': days,
        'status': 'approved',
        'cancellation_status': 'requested',
        'cancellation_reason': reason,
        'can_decide_cancellation': true,
      };
  s.on(
      'GET ${ApiConstants.leaveCancellations}',
      (_) => ok([
            r('r1', 'Anika Sharma', 'EMP-0042', 'Casual Leave', '2026-11-24', '2026-11-26', '3.0',
                'Family function was postponed'),
            r('r2', 'Imran Qureshi', 'EMP-0057', 'Earned Leave', '2026-12-02', '2026-12-02', '1.0', 'Plans changed'),
          ]));
  return s;
}

Future<void> _pump(WidgetTester tester, Widget child, FakeServer server,
    {Size size = const Size(390, 1500),
    double scale = 1,
    bool shots = false,
    List<Override> overrides = const []}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (shots) await tester.runAsync(loadShotFonts);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(NullStorage()),
      ...overrides,
    ],
    child: shotFrame(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(false),
      builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: w!),
      home: Scaffold(
        appBar: shotAppBar('Team Approvals'),
        backgroundColor: const Color(0xFFF7F9FC),
        body: child,
      ),
    )),
  ));
  await settle(tester);
}

final _delegOverrides = <Override>[
  approvalsTodayProvider.overrideWithValue(() => DateTime(2026, 11, 13)),
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ── Evidence shots (T1011_SHOTS=1) ─────────────────────────────────────────
  testWidgets('shot: attendance approval', (tester) async {
    await _pump(tester, const AttendanceApprovalTab(), attendanceServer(), size: const Size(390, 1900), shots: true);
    await shoot(tester, '07_attendance_approval');
  }, skip: !shotsEnabled);

  testWidgets('shot: attendance daily breakdown', (tester) async {
    await _pump(tester, const AttendanceApprovalTab(), attendanceServer(), size: const Size(390, 2300), shots: true);
    await tapKey(tester, 'attendance-employee-u1');
    await shoot(tester, '07b_attendance_daily_breakdown');
  }, skip: !shotsEnabled);

  testWidgets('shot: face registration', (tester) async {
    await _pump(tester, const FaceRegistrationApprovalsTab(), faceServer(), size: const Size(390, 900), shots: true);
    await shoot(tester, '08_face_registration');
  }, skip: !shotsEnabled);

  testWidgets('shot: delegation', (tester) async {
    await _pump(tester, const DelegationsTab(), delegationServer(),
        size: const Size(390, 1800), shots: true, overrides: _delegOverrides);
    await shoot(tester, '09_delegation');
  }, skip: !shotsEnabled);

  testWidgets('shot: leave cancellations', (tester) async {
    await _pump(tester, const LeaveCancellationsTab(), cancellationServer(), size: const Size(390, 1000), shots: true);
    await shoot(tester, '10_leave_cancellations');
  }, skip: !shotsEnabled);

  // ── Empty / error / denied shots ───────────────────────────────────────────
  testWidgets('shot: attendance empty', (tester) async {
    final s = attendanceServer()..on('GET ${ApiConstants.payrollPendingApproval}', (_) => ok([]));
    await _pump(tester, const AttendanceApprovalTab(), s, size: const Size(390, 760), shots: true);
    await shoot(tester, '07e_attendance_empty');
  }, skip: !shotsEnabled);

  testWidgets('shot: face empty', (tester) async {
    final s = faceServer()
      ..on('GET ${ApiConstants.faceRegistrationPending}',
          (_) => ok({'count': 0, 'page': 1, 'page_size': 20, 'total_pages': 1, 'results': []}));
    await _pump(tester, const FaceRegistrationApprovalsTab(), s, size: const Size(390, 760), shots: true);
    await shoot(tester, '08e_face_empty');
  }, skip: !shotsEnabled);

  testWidgets('shot: face denied', (tester) async {
    final s = faceServer()..on('GET ${ApiConstants.faceRegistrationPending}', (_) => refuse(403));
    await _pump(tester, const FaceRegistrationApprovalsTab(), s, size: const Size(390, 760), shots: true);
    await shoot(tester, '08d_face_denied');
  }, skip: !shotsEnabled);

  testWidgets('shot: delegation empty', (tester) async {
    final s = delegationServer()..on('GET ${ApiConstants.approvalsDelegations}', (_) => ok([]));
    await _pump(tester, const DelegationsTab(), s,
        size: const Size(390, 1500), shots: true, overrides: _delegOverrides);
    await shoot(tester, '09e_delegation_empty');
  }, skip: !shotsEnabled);

  testWidgets('shot: cancellations empty', (tester) async {
    final s = cancellationServer()..on('GET ${ApiConstants.leaveCancellations}', (_) => ok([]));
    await _pump(tester, const LeaveCancellationsTab(), s, size: const Size(390, 760), shots: true);
    await shoot(tester, '10e_cancellations_empty');
  }, skip: !shotsEnabled);

  testWidgets('shot: cancellations error', (tester) async {
    final s = cancellationServer()
      ..on('GET ${ApiConstants.leaveCancellations}', (_) => refuse(500, 'The server could not be reached right now.'));
    await _pump(tester, const LeaveCancellationsTab(), s, size: const Size(390, 760), shots: true);
    await shoot(tester, '10x_cancellations_error');
  }, skip: !shotsEnabled);

  // ── Composition: the inbox kit, no label/value form boxes ──────────────────
  double h(WidgetTester t, String key) => t.getSize(byKey(key)).height;
  ApprovalsStateKind kindOf(WidgetTester t) => t.widget<ApprovalsEmptyState>(find.byType(ApprovalsEmptyState)).kind;

  testWidgets('attendance: employee cards use the kit (stat strip, hours key figure); actions >= 44 dp',
      (tester) async {
    await _pump(tester, const AttendanceApprovalTab(), attendanceServer(), size: const Size(390, 2400));
    expect(find.byType(ApprovalsCardShell), findsNWidgets(3));
    expect(find.byType(ProfileDisplayField), findsNothing);
    expect(find.byType(ApprovalsKeyFigure), findsNWidgets(3));
    expect(find.text('21 Present'), findsNWidgets(3));
    expect(find.text('2 Late'), findsOneWidget);
    expect(find.text('1 Half day'), findsOneWidget);
    expect(find.text('3 On leave'), findsOneWidget);
    expect(find.text('168h'), findsNWidgets(2));
    expect(find.text('150.5h'), findsOneWidget);
    expect(h(tester, 'attendance-approve'), greaterThanOrEqualTo(44));
    expect(h(tester, 'attendance-cycle-c1'), greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('face: verification card (chip, score figure, progress bar), Approve before Reject, 44 dp',
      (tester) async {
    await _pump(tester, const FaceRegistrationApprovalsTab(), faceServer());
    expect(find.byType(ApprovalsCardShell), findsNWidgets(2));
    expect(find.byType(ProfileDisplayField), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    expect(find.byType(ApprovalsKeyFigure), findsNWidgets(2));
    expect(find.text('Passed'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(h(tester, 'face-approve-f1'), greaterThanOrEqualTo(44));
    expect(h(tester, 'face-reject-f1'), greaterThanOrEqualTo(44));
    expect(tester.getTopLeft(byKey('face-approve-f1')).dx < tester.getTopLeft(byKey('face-reject-f1')).dx, isTrue);
  });

  testWidgets('delegation: sentence cards with chips; quiet Revoke >= 44 dp, not full width', (tester) async {
    await _pump(tester, const DelegationsTab(), delegationServer(),
        size: const Size(390, 2400), overrides: _delegOverrides);
    expect(find.byType(ApprovalsCardShell), findsNWidgets(3));
    expect(find.byType(ProfileDisplayField), findsNothing);
    expect(find.text('Rohan Mehta covers for you'), findsOneWidget);
    expect(find.text('You cover for Anika Sharma'), findsOneWidget);
    expect(find.text('10 Nov 2026 – 20 Nov 2026'), findsOneWidget);
    expect(h(tester, 'delegation-revoke-d1'), greaterThanOrEqualTo(44));
    expect(tester.getSize(byKey('delegation-revoke-d1')).width, lessThan(200));
    expect(h(tester, 'delegation-create'), greaterThanOrEqualTo(44));
  });

  testWidgets('cancellations: headline, strong dates, quoted reason, 44 dp actions', (tester) async {
    await _pump(tester, const LeaveCancellationsTab(), cancellationServer(), size: const Size(390, 1600));
    expect(find.byType(ApprovalsCardShell), findsNWidgets(2));
    expect(find.byType(ProfileDisplayField), findsNothing);
    expect(find.byType(ApprovalsHeadline), findsNWidgets(2));
    expect(find.byType(ApprovalsQuote), findsNWidgets(2));
    expect(find.text('24 Nov 2026 – 26 Nov 2026'), findsOneWidget);
    expect(h(tester, 'leave-cancellation-row-approve-r1'), greaterThanOrEqualTo(44));
    expect(h(tester, 'leave-cancellation-row-reject-r1'), greaterThanOrEqualTo(44));
  });

  testWidgets('empty states: heading + web message, kind empty', (tester) async {
    await _pump(tester, const AttendanceApprovalTab(),
        attendanceServer()..on('GET ${ApiConstants.payrollPendingApproval}', (_) => ok([])));
    expect(find.text('No payroll cycles to approve'), findsOneWidget);
    expect(find.text('No payroll cycles pending your attendance approval.'), findsOneWidget);
    expect(kindOf(tester), ApprovalsStateKind.empty);

    await _pump(
        tester,
        const FaceRegistrationApprovalsTab(),
        faceServer()
          ..on('GET ${ApiConstants.faceRegistrationPending}',
              (_) => ok({'count': 0, 'page': 1, 'page_size': 20, 'total_pages': 1, 'results': []})));
    expect(find.text('No face registrations to review'), findsOneWidget);
    expect(find.text('No pending face registration requests.'), findsOneWidget);
    expect(kindOf(tester), ApprovalsStateKind.empty);

    await _pump(tester, const LeaveCancellationsTab(),
        cancellationServer()..on('GET ${ApiConstants.leaveCancellations}', (_) => ok([])));
    expect(find.text('No cancellation requests'), findsOneWidget);
    expect(find.text('No cancellation requests waiting for you.'), findsOneWidget);
    expect(kindOf(tester), ApprovalsStateKind.empty);

    await _pump(tester, const DelegationsTab(),
        delegationServer()..on('GET ${ApiConstants.approvalsDelegations}', (_) => ok([])),
        size: const Size(390, 2000), overrides: _delegOverrides);
    expect(find.text('No delegations given'), findsOneWidget);
    expect(find.text("You haven't delegated your approvals."), findsOneWidget);
    expect(find.text('No delegations received'), findsOneWidget);
    expect(find.text('No one has delegated approvals to you.'), findsOneWidget);
  });

  testWidgets('a failed load is an error (Retry), never the empty look; 403 is denied without Retry', (tester) async {
    await _pump(tester, const LeaveCancellationsTab(),
        cancellationServer()..on('GET ${ApiConstants.leaveCancellations}', (_) => refuse(500, 'Down for maintenance')));
    expect(kindOf(tester), ApprovalsStateKind.error);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Down for maintenance'), findsOneWidget);
    expect(find.text('No cancellation requests waiting for you.'), findsNothing);

    await _pump(tester, const FaceRegistrationApprovalsTab(),
        faceServer()..on('GET ${ApiConstants.faceRegistrationPending}', (_) => refuse(403)));
    expect(kindOf(tester), ApprovalsStateKind.denied);
    expect(find.text("You don't have permission to review face registration requests."), findsOneWidget);
    expect(find.text('Retry'), findsNothing);

    await _pump(
        tester,
        const AttendanceApprovalTab(),
        attendanceServer()
          ..on('GET ${ApiConstants.payrollPendingApproval}', (_) => refuse(500, 'Payroll is unavailable')));
    expect(kindOf(tester), ApprovalsStateKind.error);
    expect(find.text('Retry'), findsOneWidget);
  });

  for (final (name, size, scale) in responsiveCases) {
    testWidgets('responsive $name: all four redesigned tabs, no overflow', (tester) async {
      final tall = Size(size.width, size.height < 700 ? 3000 : size.height);
      await _pump(tester, const AttendanceApprovalTab(), attendanceServer(), size: tall, scale: scale);
      await tapKey(tester, 'attendance-employee-u1');
      expect(tester.takeException(), isNull);
      await _pump(tester, const FaceRegistrationApprovalsTab(), faceServer(), size: tall, scale: scale);
      expect(tester.takeException(), isNull);
      await _pump(tester, const DelegationsTab(), delegationServer(),
          size: tall, scale: scale, overrides: _delegOverrides);
      expect(tester.takeException(), isNull);
      await _pump(tester, const LeaveCancellationsTab(), cancellationServer(), size: tall, scale: scale);
      await tapKey(tester, 'leave-cancellation-row-reject-r1');
      expect(tester.takeException(), isNull);
    });
  }
}
