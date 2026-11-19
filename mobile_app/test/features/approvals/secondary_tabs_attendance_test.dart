import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/attendance_approval_tab.dart';

import 'secondary_tabs_harness.dart';

// Task 101 — Approvals → Attendance Approval against web
// AttendanceApprovalTab.tsx / EmployeeAttendanceRow.tsx.

const _pendingPath = ApiConstants.payrollPendingApproval;
String _sum(String id) => ApiConstants.payrollAttendanceSummary(id);
String _daily(String id, String e) => ApiConstants.payrollEmployeeDailyAttendance(id, e);
String _approve(String id) => ApiConstants.payrollApproveAttendance(id);

Map<String, dynamic> _cycle(String id, String start, String payDate) => {
      'id': id,
      'cycle_start': start,
      'cycle_end': '2026-09-30',
      'pay_date': payDate,
      'status': 'attendance_pending',
    };

Map<String, dynamic> _summary({
  bool pending = true,
  String? l1,
  String? l2,
  List<Map<String, dynamic>>? employees,
  String longName = 'Asha Rao',
}) =>
    {
      'cycle': {
        'id': 'c1',
        'cycle_start': '2026-09-01',
        'cycle_end': '2026-09-30',
        'pay_date': '2026-10-05',
        'status': 'attendance_pending',
        'l1_approver': l1,
        'l2_approver': l2,
        'manager_approvals': [
          {'id': 'm1', 'manager_name': 'Ravi Menon', 'approved_at': '2026-11-05T15:07:00', 'self_approved_at': null},
          {'id': 'm2', 'manager_name': 'Meera Joshi', 'approved_at': null, 'self_approved_at': null},
        ],
        'mgr_approved_count': 1,
        'mgr_total_count': 2,
        'mgr_all_approved': false,
        'current_user_pending': pending,
      },
      'employees': employees ??
          [
            {
              'employee_id': 'E-001',
              'employee_uuid': 'u1',
              'full_name': longName,
              'department': 'Engineering',
              'designation': 'Developer',
              'present_days': 20,
              'late_days': 0,
              'half_days': 1,
              'absent_days': 2,
              'on_leave_days': 0,
              'lop_days': 2,
              'working_hours': 160.0,
            }
          ],
    };

Map<String, dynamic> _dailyBody() => {
      'employee_id': 'E-001',
      'full_name': 'Asha Rao',
      'days': [
        {
          'date': '2026-09-05',
          'day': 'Sat',
          'status': 'absent',
          'status_label': 'Absent',
          'working_hours': 0,
          'is_flagged': true
        },
        {
          'date': '2026-09-07',
          'day': 'Mon',
          'status': 'present',
          'status_label': 'Present',
          'working_hours': 8.0,
          'is_flagged': false
        },
        {
          'date': '2026-09-13',
          'day': 'Sun',
          'status': 'weekly_off',
          'status_label': 'Weekly Off',
          'working_hours': 0,
          'is_flagged': false
        },
      ],
    };

FakeServer _server({Map<String, dynamic>? summary, List<Map<String, dynamic>>? cycles}) {
  final s = FakeServer();
  s.on('GET $_pendingPath', (_) => ok(cycles ?? [_cycle('c1', '2026-09-01', '2026-10-05')]));
  s.on('GET ${_sum('c1')}', (_) => ok(summary ?? _summary()));
  s.on('GET ${_daily('c1', 'u1')}', (_) => ok(_dailyBody()));
  s.on('POST ${_approve('c1')}', (_) => ok({'id': 'c1', 'cycle_start': '2026-09-01'}));
  return s;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('web strings: picker heading, pay date sub-line, header, pills, sign-offs, approve block',
      (tester) async {
    final s = _server();
    await pumpTab(tester, const AttendanceApprovalTab(), s);
    expect(find.text('Select Payroll Period'), findsOneWidget);
    // Web always shows the picker, even for a single cycle.
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Pay date: 05 Oct 2026'), findsOneWidget);
    expect(find.text('Attendance — September 2026'), findsOneWidget);
    expect(find.text('01 Sept 2026 → 30 Sept 2026  ·  Pay date 05 Oct 2026'), findsOneWidget);
    expect(find.text('L1 1/2 managers'), findsOneWidget);
    expect(find.text('L2 Waiting'), findsOneWidget);
    expect(find.text('Manager Sign-offs (1/2 approved)'), findsOneWidget);
    expect(find.text('05 Nov, 03:07 pm'), findsOneWidget);
    expect(find.text('Your sign-off is required — review your team\'s attendance and approve'), findsOneWidget);
    expect(find.text('Add approval note (optional)…'), findsOneWidget);
    expect(find.text('Approve L1 Attendance'), findsOneWidget);
    // Web columns: LOP chip while collapsed, "LOP Days", "Hrs Worked" as "160h", no Incomplete.
    expect(find.text('2 LOP'), findsOneWidget);
    expect(find.textContaining('Incomplete'), findsNothing);
    expect(find.textContaining('160h'), findsOneWidget);
    expect(find.text('E-001'), findsOneWidget);
    expect(find.textContaining('Engineering'), findsOneWidget);
  });

  testWidgets('loading strings', (tester) async {
    final s = _server()..holdKeys.add('GET $_pendingPath');
    await pumpTab(tester, const AttendanceApprovalTab(), s);
    expect(find.text('Loading pending approval cycles…'), findsOneWidget);
    s.release();
    s.holdKeys.clear();
    await settle(tester);

    final s2 = _server()..holdKeys.add('GET ${_sum('c1')}');
    await pumpTab(tester, const AttendanceApprovalTab(), s2);
    expect(find.text('Loading attendance data…'), findsOneWidget);
    s2.release();
    await settle(tester);
  });

  testWidgets('empty cycles and empty employees', (tester) async {
    await pumpTab(tester, const AttendanceApprovalTab(), _server(cycles: []));
    expect(find.text('No payroll cycles pending your attendance approval.'), findsOneWidget);

    await pumpTab(tester, const AttendanceApprovalTab(), _server(summary: _summary(employees: [])));
    expect(find.text('No attendance records found for this period.'), findsOneWidget);
  });

  testWidgets('load error shows Retry and recovers', (tester) async {
    final s = _server();
    var fails = true;
    s.on('GET $_pendingPath', (_) => fails ? refuse(500, 'Boom') : ok([_cycle('c1', '2026-09-01', '2026-10-05')]));
    await pumpTab(tester, const AttendanceApprovalTab(), s);
    expect(find.text('Retry'), findsOneWidget);
    fails = false;
    await tester.tap(find.text('Retry'));
    await settle(tester);
    expect(find.text('Attendance — September 2026'), findsOneWidget);
  });

  testWidgets('daily breakdown: header, flagged count, zero hours as dash, short dates', (tester) async {
    await pumpTab(tester, const AttendanceApprovalTab(), _server());
    await tapKey(tester, 'attendance-employee-u1');
    expect(find.text('Daily Breakdown — Asha Rao'), findsOneWidget);
    expect(find.text('1 day flagged'), findsOneWidget);
    expect(find.text('05 Sept'), findsOneWidget);
    expect(find.text('Absent'), findsWidgets);
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('8h'), findsOneWidget);
    // LOP chip hides while expanded (web).
    expect(find.text('2 LOP'), findsNothing);
  });

  testWidgets('daily empty message', (tester) async {
    final s = _server();
    s.on('GET ${_daily('c1', 'u1')}', (_) => ok({'employee_id': 'E-001', 'full_name': 'Asha Rao', 'days': []}));
    await pumpTab(tester, const AttendanceApprovalTab(), s);
    await tapKey(tester, 'attendance-employee-u1');
    expect(find.text('No attendance records found for this period.'), findsOneWidget);
  });

  testWidgets('approve sends the exact payload and shows the web success text', (tester) async {
    final s = _server();
    await pumpTab(tester, const AttendanceApprovalTab(), s);
    await tester.ensureVisible(byKey('attendance-comment'));
    await tester.enterText(byKey('attendance-comment'), 'Looks right');
    await tapKey(tester, 'attendance-self-approve');
    await tapKey(tester, 'attendance-approve');
    expect(s.bodies('POST ${_approve('c1')}'), [
      {'level': 'L1', 'comment': 'Looks right', 'self_approve': true}
    ]);
    expect(find.text('L1 attendance approval recorded.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('L1 attendance approval recorded.'), findsNothing);
  });

  testWidgets('server message is shown, fallback is the web text', (tester) async {
    final s = _server();
    s.on('POST ${_approve('c1')}', (_) => refuse(400, 'Cycle is locked.'));
    await pumpTab(tester, const AttendanceApprovalTab(), s);
    await tapKey(tester, 'attendance-approve');
    expect(find.text('Cycle is locked.'), findsOneWidget);

    s.on('POST ${_approve('c1')}', (_) => refuse(500));
    await tapKey(tester, 'attendance-approve');
    expect(find.text('Approval failed. Please try again.'), findsOneWidget);
    expect(find.text('Cycle is locked.'), findsNothing);
  });

  testWidgets('double tap sends exactly one request and shows Approving…', (tester) async {
    final s = _server()..holdKeys.add('POST ${_approve('c1')}');
    await pumpTab(tester, const AttendanceApprovalTab(), s);
    await tester.ensureVisible(byKey('attendance-approve'));
    await tester.tap(byKey('attendance-approve'));
    await tester.tap(byKey('attendance-approve'), warnIfMissed: false);
    await settle(tester);
    expect(find.text('Approving…'), findsOneWidget);
    expect(s.count('POST ${_approve('c1')}'), 1);
    s.release();
    await settle(tester);
    expect(s.count('POST ${_approve('c1')}'), 1);
  });

  testWidgets('L2 step and fully approved text', (tester) async {
    await pumpTab(tester, const AttendanceApprovalTab(), _server(summary: _summary(pending: false, l1: 'Ravi Menon')));
    expect(find.text('HR (L2) — Final sign-off on attendance'), findsOneWidget);
    expect(find.text('Approve L2 Attendance'), findsOneWidget);

    await pumpTab(tester, const AttendanceApprovalTab(),
        _server(summary: _summary(pending: false, l1: 'Ravi Menon', l2: 'Hema HR')));
    expect(find.text('Attendance fully approved — L1 and L2 sign-off complete.'), findsOneWidget);
    expect(find.text('L2 ✓ Hema HR'), findsOneWidget);
  });

  testWidgets('several cycles: picker switches the panel', (tester) async {
    final s = _server(cycles: [_cycle('c1', '2026-09-01', '2026-10-05'), _cycle('c2', '2026-10-01', '2026-11-05')]);
    s.on(
        'GET ${_sum('c2')}',
        (_) => ok({
              'cycle': {..._summary()['cycle'] as Map<String, dynamic>, 'id': 'c2', 'cycle_start': '2026-10-01'},
              'employees': <Object>[],
            }));
    await pumpTab(tester, const AttendanceApprovalTab(), s);
    expect(find.text('Attendance — September 2026'), findsOneWidget);
    await tapKey(tester, 'attendance-cycle-c2');
    expect(find.text('Attendance — October 2026'), findsOneWidget);
  });

  for (final (name, size, scale) in responsiveCases) {
    testWidgets('responsive $name: no overflow, long names wrap', (tester) async {
      const long = 'Venkata Subramaniam Ramachandran Iyer-Krishnamurthy the Third';
      final s = _server(summary: _summary(longName: long));
      await pumpTab(tester, const AttendanceApprovalTab(), s, size: size, textScale: scale);
      await tapKey(tester, 'attendance-employee-u1');
      await tester.ensureVisible(byKey('attendance-approve'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Approve L1 Attendance'), findsOneWidget);
    });
  }
}
