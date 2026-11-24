// Task 110 Part C: Employee Profile → Attendance → calendar, against web's CalendarAndHistory /
// AttendanceCalendar (read-only) and the backend's calendar day record (clockIn / clockOut are plain
// "HH:MM" wall-clock strings; no date, no timezone). Stand-in API only; synthetic data.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/attendance/data/models/attendance_models.dart';
import 'package:mobile_app/features/employees/presentation/widgets/employee_attendance_calendar.dart';
import 'package:mobile_app/shared/formatters/en_in_format.dart';

import '../../visual/employee_attendance_calendar_visual_test.dart' as v;

Finder _k(String k) => v.byKey(k);
v.CalServer get _s => v.last;

/// All text inside a keyed widget, joined.
String _in(String key) => [
      for (final e in find.descendant(of: _k(key), matching: find.byType(Text)).evaluate())
        (e.widget as Text).data ?? ''
    ].join('|');

String _two(int n) => n.toString().padLeft(2, '0');

/// A month where day 3 carries a per-month marker (so a reply for another month is recognisable).
Map<String, Map<String, dynamic>> Function(int, int) _marked() => (y, m) => {
      ...v.sampleMonth(y, m),
      '3': v.day('Present', clockIn: '${_two(m)}:11', clockOut: '18:00', hours: '8h 00m'),
    };

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final now = DateTime.now();

  group('backend field mapping', () {
    test('a calendar day maps clockIn / clockOut / hours / note / holiday_name / color / flags exactly', () {
      final m = CalendarDayModel.fromJson(v.day('Late',
          clockIn: '09:47', clockOut: '18:30', hours: '8h 43m', note: 'Traffic', lateStatus: 'pending', canReg: true));
      expect((m.status, m.clockIn, m.clockOut, m.hours, m.note), ('Late', '09:47', '18:30', '8h 43m', 'Traffic'));
      expect((m.color, m.canRegularize, m.lateJustificationStatus), ('#f59e0b', true, 'pending'));
    });

    test('a missing clock-out stays null (never filled in); a holiday carries its name', () {
      final open = CalendarDayModel.fromJson(v.day('Missing Clock Out', clockIn: '09:12'));
      expect((open.clockIn, open.clockOut), ('09:12', null));
      expect(CalendarDayModel.fromJson(v.day('Holiday', holiday: 'Founders Day')).holidayName, 'Founders Day');
    });

    test('the month is keyed by day number; keys that are not numbers are ignored', () {
      final cal = AttendanceCalendarModel.fromJson({
        'month': 11,
        'year': 2026,
        'calendar': {
          'days': {'3': v.day('Present', clockIn: '09:00', clockOut: '18:00'), 'x': v.day('Absent')}
        },
        'history': <Object>[],
      });
      expect(cal.days.keys, [3]);
      expect((cal.month, cal.year), (11, 2026));
    });

    test('colours: the backend hex wins, then the status, then neutral; bad hex is ignored', () {
      expect(attendanceColorFromHex('#22c55e'), const Color(0xFF22C55E));
      expect(attendanceColorFromHex('22c55e'), const Color(0xFF22C55E));
      expect(attendanceColorFromHex('green'), isNull);
      expect(attendanceColorFromHex(null), isNull);
      expect(attendanceDayColor('Present', '#123456'), const Color(0xFF123456));
      expect(attendanceDayColor('Present', 'nope'), kAttendanceStatusColors['Present']);
      expect(attendanceDayColor('Something Else', null), AppColors.textHint);
    });

    test('every status the backend can send has a colour and a short code (Late (Excused), Missing Clock Out included)',
        () {
      for (final s in [
        'Present',
        'Late',
        'Late (Excused)',
        'Absent',
        'Half Day',
        'Weekly Off',
        'Holiday',
        'On Leave',
        'Incomplete',
        'Missing Clock Out'
      ]) {
        expect(kAttendanceStatusColors.containsKey(s), isTrue, reason: s);
        expect(kAttendanceStatusCodes.containsKey(s), isTrue, reason: s);
      }
      expect(kAttendanceStatusCodes['Late (Excused)'], 'LE');
      expect(kAttendanceStatusCodes['Missing Clock Out'], '!');
    });
  });

  group('requests', () {
    testWidgets('stats, summary and calendar are each requested once for this employee and month', (t) async {
      await v.openTab(t, shots: false);
      for (final path in [
        ApiConstants.attendanceStats,
        ApiConstants.attendanceSummary,
        ApiConstants.attendanceCalendar
      ]) {
        final calls = _s.to(path);
        expect(calls, hasLength(1), reason: path);
        expect(calls.single.query, {'employee_id': 'EMP-0007', 'month': now.month, 'year': now.year});
      }
    });
  });

  group('selected-day details show what the server sent', () {
    testWidgets('a complete day: Clock In, Clock Out, working hours and the status — verbatim', (t) async {
      await v.openTab(t, shots: false);
      await v.tapDay(t, 3);
      expect(_in('emp-att-status'), 'Late');
      expect(_in('emp-att-clock-in'), 'Clock In|09:47');
      expect(_in('emp-att-clock-out'), 'Clock Out|18:30');
      expect(_in('emp-att-day-hours'), 'Working hours|8h 43m');
    });

    testWidgets('the date line is the selected date in en-IN form', (t) async {
      await v.openTab(t, shots: false);
      await v.tapDay(t, 3);
      final d = DateTime(now.year, now.month, 3);
      const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      expect(
          (_k('emp-att-date').evaluate().single.widget as Text).data, '${names[d.weekday - 1]}, ${formatEnInDate(d)}');
    });

    testWidgets('a missing clock-out reads "Not clocked out" — nothing is made up', (t) async {
      await v.openTab(t, shots: false);
      await v.tapDay(t, 18);
      expect(_in('emp-att-status'), 'Missing Clock Out');
      expect(_in('emp-att-clock-in'), 'Clock In|09:12');
      expect(_in('emp-att-clock-out'), 'Clock Out|Not clocked out');
      expect(_k('emp-att-day-hours'), findsNothing);
    });

    testWidgets(
        'an overnight record shows the two times as the server sent them (clock-out earlier than clock-in), hours not recomputed',
        (t) async {
      await v.openTab(t, shots: false);
      await v.tapDay(t, 20);
      expect(_in('emp-att-clock-in'), 'Clock In|22:00');
      expect(_in('emp-att-clock-out'), 'Clock Out|06:05');
      expect(_in('emp-att-day-hours'), 'Working hours|8h 05m');
      expect(_in('emp-att-note'), 'Note|Night shift');
    });

    testWidgets('an absent day has no times: both are an empty dash', (t) async {
      await v.openTab(t, shots: false);
      await v.tapDay(t, 9);
      expect(_in('emp-att-status'), 'Absent');
      expect(_in('emp-att-clock-in'), 'Clock In|—');
      expect(_in('emp-att-clock-out'), 'Clock Out|—');
    });

    testWidgets('holiday and weekly off: times are hidden (web NON_WORKING); the holiday name is shown', (t) async {
      await v.openTab(t, shots: false);
      await v.tapDay(t, 12);
      expect(_k('emp-att-clock-in'), findsNothing);
      expect(_in('emp-att-holiday'), 'Holiday|Founders Day');
      // the first Sunday of the month is a weekly off in the sample
      final sunday = [for (var d = 1; d <= 7; d++) d]
          .firstWhere((d) => DateTime(now.year, now.month, d).weekday == DateTime.sunday);
      await v.tapDay(t, sunday);
      expect(_in('emp-att-status'), 'Weekly Off');
      expect(_k('emp-att-clock-in'), findsNothing);
      expect(find.text('No punches are expected on this day.'), findsOneWidget);
    });

    testWidgets('a day the server has no record for says so', (t) async {
      await v.openTab(t,
          shots: false,
          server: v.CalServer()..daysFor = (y, m) => {'5': v.day('Present', clockIn: '09:00', clockOut: '18:00')});
      await v.tapDay(t, 6);
      expect(_k('emp-att-no-record'), findsOneWidget);
    });

    testWidgets('late-justification status is shown the way web words it', (t) async {
      await v.openTab(t,
          shots: false,
          server: v.CalServer()
            ..daysFor = (y, m) => {'4': v.day('Late', clockIn: '10:05', clockOut: '18:00', lateStatus: 'resubmit')});
      await v.tapDay(t, 4);
      expect(_in('emp-att-late-hint'), 'Late arrival|Resubmit reason');
    });

    testWidgets('read-only: no Regularize or Explain action even when the server says canRegularize', (t) async {
      await v.openTab(t, shots: false);
      await v.tapDay(t, 3);
      expect(find.text('Regularize'), findsNothing);
      expect(find.text('Explain'), findsNothing);
    });
  });

  group('the grid', () {
    testWidgets('statuses the old calendar left blank now show their code: Late (Excused) = LE, Missing Clock Out = !',
        (t) async {
      await v.openTab(t, shots: false);
      expect(find.descendant(of: _k('emp-att-day-22'), matching: find.text('LE')), findsOneWidget);
      expect(find.descendant(of: _k('emp-att-day-18'), matching: find.text('!')), findsOneWidget);
      expect(find.descendant(of: _k('emp-att-day-3'), matching: find.text('L')), findsOneWidget);
      expect(find.descendant(of: _k('emp-att-day-9'), matching: find.text('A')), findsOneWidget);
      expect(find.descendant(of: _k('emp-att-day-12'), matching: find.text('Ho')), findsOneWidget);
    });

    testWidgets('cells stay uncluttered: day number and a short code, no clock times', (t) async {
      await v.openTab(t, shots: false);
      expect(find.descendant(of: _k('emp-att-day-3'), matching: find.text('09:47')), findsNothing);
    });

    testWidgets('the selected day is distinct, only one at a time', (t) async {
      await v.openTab(t, shots: false);
      await v.tapDay(t, 9);
      await v.tapDay(t, 14);
      expect(_in('emp-att-status'), 'On Leave');
      expect(find.descendant(of: _k('emp-att-details'), matching: find.text('Absent')), findsNothing);
    });

    testWidgets('the legend names every colour in web order', (t) async {
      await v.openTab(t, shots: false);
      for (final l in ['Present', 'Late', 'Absent', 'On Leave', 'Half Day', 'Weekly Off', 'Holiday']) {
        expect(find.descendant(of: _k('emp-att-legend'), matching: find.text(l)), findsOneWidget, reason: l);
      }
    });

    testWidgets('an empty month says so; the grid is still there', (t) async {
      await v.openTab(t, shots: false, server: v.CalServer()..daysFor = (y, m) => {});
      expect(_k('emp-att-empty'), findsOneWidget);
      expect(_k('emp-att-grid'), findsOneWidget);
    });

    testWidgets('touch targets: month buttons, tabs and day cells are tall enough', (t) async {
      await v.openTab(t, shots: false);
      for (final k in ['emp-att-prev', 'emp-att-next', 'emp-att-tab-calendar', 'emp-att-tab-history']) {
        expect(t.getSize(_k(k)).height, greaterThanOrEqualTo(44), reason: k);
      }
      expect(t.getSize(_k('emp-att-day-3')).height, greaterThanOrEqualTo(48));
    });
  });

  group('month navigation', () {
    testWidgets('today is selected on the current month; a past month starts with nothing selected', (t) async {
      await v.openTab(t, shots: false);
      expect(_k('emp-att-date'), findsOneWidget); // today
      await t.tap(_k('emp-att-prev'));
      await v.settle(t);
      expect(_k('emp-att-select-hint'), findsOneWidget);
      expect(_k('emp-att-date'), findsNothing);
    });

    testWidgets('Previous loads that month (employee, month, year) and the title follows', (t) async {
      await v.openTab(t, shots: false);
      await t.tap(_k('emp-att-prev'));
      await v.settle(t);
      final prev = DateTime(now.year, now.month - 1, 1);
      final calls = _s.to(ApiConstants.attendanceCalendar);
      expect(calls.last.query, {'employee_id': 'EMP-0007', 'month': prev.month, 'year': prev.year});
      expect((_k('emp-att-month').evaluate().single.widget as Text).data, endsWith('${prev.year}'));
      // the stats and summary follow the same month
      expect(_s.to(ApiConstants.attendanceStats).last.query['month'], prev.month);
      expect(_s.to(ApiConstants.attendanceSummary).last.query['month'], prev.month);
    });

    testWidgets('Today returns to the current month and selects today; Next is not offered on the current month',
        (t) async {
      await v.openTab(t, shots: false);
      expect(_k('emp-att-today'), findsNothing);
      expect(t.widget<IconButton>(_k('emp-att-next')).onPressed, isNull);
      await t.tap(_k('emp-att-prev'));
      await v.settle(t);
      expect(_k('emp-att-today'), findsOneWidget);
      expect(t.widget<IconButton>(_k('emp-att-next')).onPressed, isNotNull);
      await t.tap(_k('emp-att-today'));
      await v.settle(t);
      expect(_k('emp-att-today'), findsNothing);
      expect(_k('emp-att-date'), findsOneWidget);
    });

    testWidgets('a selected day never carries over to the next month: selection resets', (t) async {
      await v.openTab(t, shots: false);
      await t.tap(_k('emp-att-prev'));
      await v.settle(t);
      await v.tapDay(t, 28);
      expect(_k('emp-att-date'), findsOneWidget);
      await t.tap(_k('emp-att-prev'));
      await v.settle(t);
      expect(_k('emp-att-select-hint'), findsOneWidget);
    });
  });

  group('stale responses', () {
    testWidgets('each month shows its own data (a marker on day 3)', (t) async {
      await v.openTab(t, shots: false, server: v.CalServer()..daysFor = _marked());
      await v.tapDay(t, 3);
      expect(_in('emp-att-clock-in'), 'Clock In|${_two(now.month)}:11');
      await t.tap(_k('emp-att-prev'));
      await v.settle(t);
      await v.tapDay(t, 3);
      final prev = DateTime(now.year, now.month - 1, 1);
      expect(_in('emp-att-clock-in'), 'Clock In|${_two(prev.month)}:11');
    });

    testWidgets('a slow reply for a month the user already left never replaces the month on screen', (t) async {
      final s = v.CalServer()..daysFor = _marked();
      final prev = DateTime(now.year, now.month - 1, 1);
      final gate = Completer<void>();
      s.gates['${prev.year}-${prev.month}'] = gate;
      await v.openTab(t, shots: false, server: s);
      await t.tap(_k('emp-att-prev')); // previous month starts loading and is held
      await t.pump(const Duration(milliseconds: 100));
      expect(_k('emp-att-loading'), findsOneWidget);
      await t.tap(find.byKey(const Key('emp-att-next'))); // back to the current month before it answers
      await v.settle(t);
      await v.tapDay(t, 3);
      expect(_in('emp-att-clock-in'), 'Clock In|${_two(now.month)}:11');
      gate.complete(); // the old reply lands now
      await v.settle(t);
      expect((_k('emp-att-month').evaluate().single.widget as Text).data, startsWith(_monthName(now.month)));
      expect(_in('emp-att-clock-in'), 'Clock In|${_two(now.month)}:11');
    });

    testWidgets('three quick Previous taps end on the third month back with its own data', (t) async {
      await v.openTab(t, shots: false, server: v.CalServer()..daysFor = _marked());
      for (var i = 0; i < 3; i++) {
        await t.tap(_k('emp-att-prev'));
        await t.pump(const Duration(milliseconds: 20));
      }
      await v.settle(t);
      final m3 = DateTime(now.year, now.month - 3, 1);
      await v.tapDay(t, 3);
      expect(_in('emp-att-clock-in'), 'Clock In|${_two(m3.month)}:11');
    });
  });

  group('loading, error, history', () {
    testWidgets('loading: the header and legend stay, a spinner replaces the grid', (t) async {
      final s = v.CalServer();
      s.gates['${now.year}-${now.month}'] = Completer<void>();
      await v.openTab(t, shots: false, server: s, settleFirst: false);
      await t.pump(const Duration(milliseconds: 200));
      expect(_k('emp-att-loading'), findsOneWidget);
      expect(_k('emp-att-legend'), findsOneWidget);
      expect(_k('emp-att-grid'), findsNothing);
      s.gates.values.single.complete();
      await v.settle(t);
      expect(_k('emp-att-grid'), findsOneWidget);
    });

    testWidgets('a failed load shows the message with Retry, which reloads', (t) async {
      final s = v.CalServer()..calendarStatus = 500;
      await v.openTab(t, shots: false, server: s);
      expect(_k('emp-att-error'), findsOneWidget);
      expect(find.text('Server error.'), findsOneWidget);
      s.calendarStatus = 200;
      await t.tap(find.text('Retry'));
      await v.settle(t);
      expect(_k('emp-att-error'), findsNothing);
      expect(_k('emp-att-grid'), findsOneWidget);
    });

    testWidgets('a permission refusal shows Access denied and no Retry', (t) async {
      await v.openTab(t, shots: false, server: v.CalServer()..calendarStatus = 403);
      expect(find.text('Access denied'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('History lists the same clock times, and marks only a status of Late (no invented 09:15 rule)',
        (t) async {
      final s = v.CalServer()
        ..daysFor = (y, m) => {
              '4':
                  v.day('Present', clockIn: '10:30', clockOut: '19:00', hours: '8h 30m'), // late-looking time, not Late
              '5': v.day('Late', clockIn: '09:05', clockOut: '18:00', hours: '8h 55m'), // Late by the server
            };
      await v.openTab(t, shots: false, server: s);
      await t.tap(_k('emp-att-tab-history'));
      await v.settle(t);
      Color? colorOf(String text) => (find.text(text).evaluate().first.widget as Text).style?.color;
      expect(colorOf('10:30'), AppColors.textPrimary);
      expect(colorOf('09:05'), AppColors.error);
    });
  });

  group('layout', () {
    for (final (w, h, sc) in [
      (320.0, 568.0, 2.0),
      (320.0, 568.0, 1.0),
      (360.0, 800.0, 1.5),
      (393.0, 852.0, 1.0),
      (430.0, 932.0, 1.0),
      (600.0, 900.0, 1.0),
      (800.0, 1000.0, 1.0),
      (1000.0, 800.0, 1.0),
    ]) {
      testWidgets('${w.toInt()}×${h.toInt()} @ $sc×: calendar, selected-day card and tiles fit, nothing overflows',
          (t) async {
        final s = v.CalServer()
          ..daysFor = (y, m) => {
                ...v.sampleMonth(y, m),
                '20': v.day('Present',
                    clockIn: '22:00',
                    clockOut: '06:05',
                    hours: '8h 05m',
                    note:
                        'Overnight shift covering the quarter-end release and the production cut-over for the Hyderabad branch'),
                '12': v.day('Holiday', holiday: 'Founders Day and the Annual Company Foundation Celebration Holiday'),
              };
        await v.openTab(t, shots: false, size: Size(w, 6000), scale: sc, server: s);
        await v.tapDay(t, 20);
        expect(t.takeException(), isNull);
        final card = t.getRect(_k('emp-att-calendar-card'));
        expect(card.right, lessThanOrEqualTo(w));
        for (final k in ['emp-att-clock-in', 'emp-att-clock-out']) {
          expect(t.getRect(_k(k)).right, lessThanOrEqualTo(w), reason: k);
        }
        await v.tapDay(t, 12);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('on a wide screen the grid and the details sit side by side', (t) async {
      await v.openTab(t, shots: false, size: const Size(1000, 2000));
      await v.tapDay(t, 3);
      expect(t.getTopLeft(_k('emp-att-details')).dx, greaterThan(t.getTopRight(_k('emp-att-grid')).dx - 1));
    });

    testWidgets('on a phone the details are below the grid', (t) async {
      await v.openTab(t, shots: false, size: const Size(393, 3000));
      await v.tapDay(t, 3);
      expect(t.getTopLeft(_k('emp-att-details')).dy, greaterThan(t.getBottomLeft(_k('emp-att-grid')).dy));
    });

    testWidgets('dark theme: grid, details and the error state draw without overflow', (t) async {
      await v.openTab(t, shots: false, dark: true);
      await v.tapDay(t, 18);
      expect(t.takeException(), isNull);
      await v.openTab(t, shots: false, dark: true, server: v.CalServer()..calendarStatus = 500);
      expect(t.takeException(), isNull);
    });
  });
}

String _monthName(int m) => const [
      'January', 'February', 'March', 'April', 'May', 'June', //
      'July', 'August', 'September', 'October', 'November', 'December',
    ][m - 1];
