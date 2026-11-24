import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/attendance/presentation/providers/month_view_providers.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/month_view_widgets.dart';

import '../../visual/month_view_visual_test.dart' hide main;

// Task 111 / Area 2: HR Attendance -> Employee Month View on the web's data
// (GET /attendance/employee-calendar/?employee_id&month, EmployeeMonthView.tsx).
// Stand-in API, synthetic data.

String iso(DateTime m) => monthViewIso(m);
DateTime thisMonth() => DateTime(DateTime.now().year, DateTime.now().month, 1);
DateTime prevMonth() => DateTime(thisMonth().year, thisMonth().month - 1, 1);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('no employee: prompt, no calendar request', (t) async {
    final s = MonthServer();
    await openMonthView(t, server: s, select: false, shots: false);
    expect(find.byKey(const Key('month-select-prompt')), findsOneWidget);
    expect(find.text('Search for an employee to view their monthly attendance calendar.'), findsOneWidget);
    expect(s.calendarCalls, isEmpty);
  });

  testWidgets('employee picked: web request params, overview figures and day records', (t) async {
    final s = MonthServer();
    await openMonthView(t, server: s, shots: false);
    expect(s.calendarCalls.single, {'employee_id': 'uuid-anika', 'month': iso(thisMonth())});
    final p = monthPayload(iso(thisMonth()));
    final st = p['stats'] as Map;
    expect(t.widget<Text>(find.byKey(const Key('month-stat-Present'))).data, '${st['present']}');
    expect(t.widget<Text>(find.byKey(const Key('month-stat-LOP'))).data, '${st['lop_days']}');
    expect(t.widget<Text>(find.byKey(const Key('month-stat-Total Hrs'))).data, '${(st['total_hours'] as num) == (st['total_hours'] as num).truncate() ? (st['total_hours'] as num).truncate() : st['total_hours']}h');
    for (final l in ['Present', 'Late', 'Half Day', 'Absent', 'On Leave', 'LOP', 'Total Hrs']) {
      expect(find.text(l), findsWidgets, reason: l);
    }
    expect(find.text('EMP-0042 · Senior Software Engineer · Engineering'), findsOneWidget);
    // Day records: status label from the server, in - out, hours; the Day 11 absence is flagged.
    expect(find.byKey(Key('month-day-${iso(thisMonth())}-02')), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(Key('month-day-${iso(thisMonth())}-11')), 400, scrollable: find.byType(Scrollable).last);
    expect(find.text('Absent'), findsWidgets);
    expect(find.text('Flagged'), findsWidgets);
    expect(find.text('Late Arrival'), findsWidgets);
    expect(find.textContaining('10:25 – '), findsWidgets);
  });

  testWidgets('month navigation: previous loads that month; next is disabled at the current month', (t) async {
    final s = MonthServer();
    await openMonthView(t, server: s, shots: false);
    expect(t.widget<IconButton>(find.byKey(const Key('month-next'))).onPressed, isNull);
    expect(find.text(monthViewLabel(thisMonth())), findsOneWidget);
    await t.tap(find.byKey(const Key('month-prev')));
    await settleMv(t);
    expect(find.text(monthViewLabel(prevMonth())), findsOneWidget);
    expect(s.calendarCalls.last['month'], iso(prevMonth()));
    expect(t.widget<IconButton>(find.byKey(const Key('month-next'))).onPressed, isNotNull);
    await t.tap(find.byKey(const Key('month-next')));
    await settleMv(t);
    expect(find.text(monthViewLabel(thisMonth())), findsOneWidget);
  });

  testWidgets('stale reply: a slow earlier month never replaces the displayed month', (t) async {
    final s = MonthServer();
    final slow = Completer<void>();
    s.gates[iso(prevMonth())] = slow;
    // Distinguishable data per month: the previous month claims 99 present days.
    s.payloadFor[iso(prevMonth())] = monthPayload(iso(prevMonth()), marker: 88);
    await openMonthView(t, server: s, shots: false);
    final current = t.widget<Text>(find.byKey(const Key('month-stat-Present'))).data;
    await t.tap(find.byKey(const Key('month-prev'))); // held
    await settleMv(t, 4);
    expect(find.text('Loading attendance data…'), findsOneWidget);
    await t.tap(find.byKey(const Key('month-next'))); // back to the current month before the reply
    await settleMv(t);
    slow.complete();
    await settleMv(t);
    expect(find.text(monthViewLabel(thisMonth())), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('month-stat-Present'))).data, current);
    expect(find.text('Loading attendance data…'), findsNothing);
  });

  testWidgets('error: message with Retry that refetches', (t) async {
    final s = MonthServer()..status = 500;
    await openMonthView(t, server: s, shots: false);
    expect(find.text('Retry'), findsOneWidget);
    s.status = 200;
    await t.tap(find.text('Retry'));
    await settleMv(t);
    expect(find.byKey(const Key('month-overview')), findsOneWidget);
    expect(s.calendarCalls.length, 2);
  });

  testWidgets('403: access denied, no Retry', (t) async {
    await openMonthView(t, server: MonthServer()..status = 403..message = 'Permission denied.', shots: false);
    expect(find.text('Access denied'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('search with no match: inline message, nothing requested', (t) async {
    final s = MonthServer()..noEmployees = true;
    await openMonthView(t, server: s, shots: false);
    expect(find.byKey(const Key('month-no-match')), findsOneWidget);
    expect(s.calendarCalls, isEmpty);
  });

  testWidgets('day with a record opens its detail (read-only record sheet)', (t) async {
    final s = MonthServer();
    await openMonthView(t, server: s, size: const Size(393, 3200), shots: false);
    final withRecord = find.byKey(Key('month-day-${iso(thisMonth())}-02'));
    await t.ensureVisible(withRecord);
    await t.tap(withRecord);
    await settleMv(t);
    expect(find.text('Attendance — ${iso(thisMonth())}-02'), findsOneWidget);
    expect(find.text('9h 10m'), findsOneWidget);
  });

  for (final (label, size, scale) in [
    ('320dp', const Size(320, 4000), 1.0),
    ('320dp 2x text', const Size(320, 8000), 2.0),
    ('tablet', const Size(1000, 1400), 1.0),
  ]) {
    testWidgets('$label: no overflow (selection, overview, records)', (t) async {
      await openMonthView(t, size: size, scale: scale, shots: false);
      expect(find.byKey(const Key('month-overview')), findsOneWidget);
      expect(find.byType(MonthViewDayCard), findsWidgets);
    });
  }
}
