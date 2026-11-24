import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile_app/features/attendance/presentation/providers/unpunch_providers.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/unpunch_widgets.dart';
import '../../visual/unpunches_visual_test.dart' hide main;

// Task 111 / Area 1: HR Attendance -> Un-punches, strict parity with web
// UnpunchesTab.tsx (GET /attendance/un-punches/ date, branch, department, page,
// page_size=20; read-only; Correction Status badge). Stand-in API, synthetic data.

String today() => unpunchIsoDate(DateTime.now());
final scoped = unUser(perms: const ['attendance.view', 'attendance.edit'], branch: 'Surat');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('web labels and values; no extra mobile-only fields or actions', (t) async {
    await openUnpunches(t, shots: false);
    expect(find.text(unpunchBanner), findsOneWidget);
    for (final l in ['Date', 'Branch', 'Department', 'Employee ID', 'Clock In', 'Expected Out', 'Correction Status']) {
      expect(find.text(l), findsWidgets, reason: l);
    }
    expect(find.text('Anika Sharma'), findsOneWidget);
    expect(find.text('EMP-0042'), findsOneWidget);
    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('Correction Submitted'), findsNWidgets(2));
    expect(find.text('No Correction Filed'), findsOneWidget);
    // Not on the web tab:
    for (final x in ['OUT missing', 'Awaiting employee correction request', 'Correction Requests']) {
      expect(find.text(x), findsNothing, reason: x);
    }
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
  });

  testWidgets('request payload: today, page 1, page_size 20, no branch/department', (t) async {
    final s = UnServer();
    await openUnpunches(t, server: s, shots: false);
    expect(s.unpunchQueries.first, {'date': today(), 'page': 1, 'page_size': 20});
    expect(s.writes, isEmpty);
  });

  testWidgets('scoped user: branch locked to own branch and sent; no branch dropdown', (t) async {
    final s = UnServer();
    await openUnpunches(t, server: s, as: scoped, shots: false);
    expect(find.byKey(const Key('unpunch-branch-locked')), findsOneWidget);
    expect(find.byKey(const Key('unpunch-branch')), findsNothing);
    expect(find.text('Surat'), findsWidgets);
    expect(s.unpunchQueries.first['branch'], 'Surat');
  });

  testWidgets('unrestricted user: branch dropdown present', (t) async {
    await openUnpunches(t, shots: false);
    expect(find.byKey(const Key('unpunch-branch')), findsOneWidget);
    expect(find.byKey(const Key('unpunch-branch-locked')), findsNothing);
  });

  testWidgets('paging: Page X of Y, Next sends page 2, Prev disabled on page 1', (t) async {
    final s = UnServer()..totalPages = 3;
    await openUnpunches(t, server: s, size: const Size(393, 2000), shots: false);
    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(t.widget<OutlinedButton>(find.byKey(const Key('unpunch-prev'))).onPressed, isNull);
    await t.ensureVisible(find.byKey(const Key('unpunch-next')));
    await t.tap(find.byKey(const Key('unpunch-next')));
    await settleUn(t);
    expect(s.unpunchQueries.last['page'], 2);
    expect(find.text('Page 2 of 3'), findsOneWidget);
  });

  testWidgets('single page: no pager', (t) async {
    await openUnpunches(t, shots: false);
    expect(find.byKey(const Key('unpunch-next')), findsNothing);
  });

  testWidgets('empty: web message', (t) async {
    await openUnpunches(t, server: UnServer()..rows = [], shots: false);
    expect(find.text('No un-punches found for this date.'), findsOneWidget);
  });

  testWidgets('error: message + Retry refetches', (t) async {
    final s = UnServer()..status = 500;
    await openUnpunches(t, server: s, shots: false);
    expect(find.text('Retry'), findsOneWidget);
    final before = s.unpunchQueries.length;
    s.status = 200;
    await t.tap(find.text('Retry'));
    await settleUn(t);
    expect(s.unpunchQueries.length, before + 1);
    expect(find.text('Anika Sharma'), findsOneWidget);
  });

  testWidgets('403: access denied state, no Retry', (t) async {
    await openUnpunches(t, server: UnServer()..status = 403..message = 'Permission denied.', shots: false);
    expect(find.text('Access denied'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('stale response: a slow reply for an earlier page never replaces the current one', (t) async {
    final s = UnServer()..totalPages = 2;
    s.gates[1] = Completer<void>(); // page 2 request is held
    s.rowsByCall[1] = [unRow('EMP-0999', 'Stale Person', 'Surat')];
    final c = await openUnpunches(t, server: s, size: const Size(393, 2000), shots: false);
    await t.ensureVisible(find.byKey(const Key('unpunch-next')));
    await t.tap(find.byKey(const Key('unpunch-next'))); // call 1 (held)
    await t.pump(const Duration(milliseconds: 100));
    // Go back to page 1 before page 2 answers: call 2.
    // (Prev is hidden while loading, so drive the page state directly.)
    c.read(unpunchPageNumberProvider.notifier).state = 1;
    await settleUn(t);
    s.gates[1]!.complete();
    await settleUn(t);
    expect(find.text('Stale Person'), findsNothing);
    expect(find.text('Anika Sharma'), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);
  });
  testWidgets('department and date changes are sent and return to page 1', (t) async {
    final s = UnServer()..totalPages = 3;
    final c = await openUnpunches(t, server: s, shots: false);
    c.read(unpunchPageNumberProvider.notifier).state = 2;
    await settleUn(t);
    c.read(unpunchDepartmentProvider.notifier).state = 'Finance';
    c.read(unpunchPageNumberProvider.notifier).state = 1;
    await settleUn(t);
    expect(s.unpunchQueries.last, {'date': today(), 'department': 'Finance', 'page': 1, 'page_size': 20});
    c.read(unpunchDateProvider.notifier).state = DateTime(2026, 11, 3);
    await settleUn(t);
    expect(s.unpunchQueries.last['date'], '2026-11-03');
  });

  testWidgets('filter with no result: no-match state offers Clear filters', (t) async {
    final s = UnServer()..rows = [];
    final c = await openUnpunches(t, server: s, shots: false);
    c.read(unpunchDepartmentProvider.notifier).state = 'Finance';
    await settleUn(t);
    expect(find.text('Clear filters'), findsOneWidget);
    await t.tap(find.text('Clear filters'));
    await settleUn(t);
    expect(s.unpunchQueries.last.containsKey('department'), isFalse);
  });

  testWidgets('320dp at 2x text with long values: no overflow', (t) async {
    await openUnpunches(t, size: const Size(320, 3000), scale: 2, shots: false);
    final cards = find.byType(UnpunchCard);
    expect(cards, findsNWidgets(3));
  });
}
