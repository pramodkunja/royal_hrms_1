import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/monthly_leave/monthly_leave_tab.dart';

import 'monthly_leave_management_test.dart' as m;

// Task 106: Monthly Leave Management must fit every phone and tablet width and
// text scale: no overflow, no clipped action, ≥44dp targets, one scroll
// view (no nested scrolling in the employee checklist), keyboard-safe fields.
// MonthlyLeaveTab is mounted directly (not through the Leave Policy route).

const longName = 'Venkatasubramanian Ramachandran Iyer-Krishnamurthy of the Southern Regional Operations';
const longType = 'Earned Leave (Privilege Leave, Accumulating Quarterly, Carried Forward With Cap)';
const longMessage = 'Adds 1.5 day(s). This is a deliberately long details message that has to wrap onto several '
    'lines on a narrow phone without pushing the status badge or the figures off the screen.';
const longFile = 'monthly_credits_november_2026_regional_operations_final_version_v3_approved.csv';

ResponseBody _json(Object body) => ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

/// The existing stand-in with long names, a long leave type and long messages.
class LongServer extends m.Server {
  LongServer() {
    employees = [
      m.emp('EMP-1', 'Test Me'),
      m.emp('EMP-7', longName, branch: 'Southern Regional Operations Centre, Bengaluru'),
      m.emp('EMP-8', 'Test Gone', active: false),
      m.emp('EMP-9', 'Test Bob'),
    ];
    assignments = [
      {
        ...assignments.first,
        'employee_name': longName,
        'branch': 'Southern Regional Operations Centre, Bengaluru',
        'credit': 1234.5,
      },
      assignments.last,
      {...assignments.first, 'employee_id': 'EMP-9', 'employee_name': 'Test Bob', 'leave_type': 'earned'},
    ];
    final rows = [
      {...m.planRow(1, 'EMP-7', 'new'), 'employee_name': longName, 'message': longMessage},
      {...m.planRow(2, 'EMP-9', 'update', previous: 1.0, delta: 0.5), 'leave_type_label': longType},
      m.planRow(3, 'EMP-8', 'error'),
      m.planRow(4, 'EMP-9', 'duplicate'),
      m.planRow(5, 'EMP-9', 'unchanged'),
    ];
    nextPlan = m.plan(rows);
    nextResult = m.applied(rows);
  }

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if ('${o.method} ${o.path}' == 'GET ${ApiConstants.leaveTypes}') {
      log.add('GET ${o.path}');
      return _json(m.ok([
        {'id': 1, 'leave_type': 'casual', 'leave_type_display': longType, 'annual_days': '12.0', 'is_active': true},
        {'id': 2, 'leave_type': 'earned', 'leave_type_display': 'Earned Leave', 'annual_days': '0', 'is_active': true},
      ]));
    }
    return super.fetch(o, s, c);
  }
}

Future<void> mount(WidgetTester tester, Size size, double scale, {m.Server? server, double keyboard = 0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(() {
    tester.view.reset();
    tester.view.resetViewInsets();
  });
  m.server = server ?? LongServer();
  m.saved.clear();
  m.nextFile = m.file(longFile);
  await tester.pumpWidget(ProviderScope(
    overrides: m.overrides(m.approver),
    child: MaterialApp(
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      // As in the app, the tab appears once the user is signed in.
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) =>
              ref.watch(authStateProvider).valueOrNull?.user == null ? const SizedBox() : const MonthlyLeaveTab(),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// No overflow or other exception so far.
void clean(WidgetTester tester, String where) {
  final e = tester.takeException();
  expect(e, isNull, reason: where);
  if (e != null) debugPrint('$e');
}

/// Scrolls the control into view (the tab builds lazily), whichever way it is.
Future<void> show(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    final scrollable =
        find.descendant(of: find.byKey(const Key('monthly-leave-tab')), matching: find.byType(Scrollable)).first;
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(0);
    await tester.pump();
    while (f.evaluate().isEmpty && position.pixels < position.maxScrollExtent) {
      position.jumpTo((position.pixels + 200).clamp(0, position.maxScrollExtent));
      await tester.pump();
    }
  }
  expect(f, findsOneWidget, reason: 'not found anywhere in the tab: $key');
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

/// The control is fully inside the screen width; actions are at least 44dp high.
Future<void> reachable(WidgetTester tester, String key, Size size, String where, {bool action = true}) async {
  await show(tester, key);
  final f = find.byKey(Key(key));
  expect(f, findsOneWidget, reason: '$where: $key');
  final r = tester.getRect(f);
  expect(r.left, greaterThanOrEqualTo(-0.5), reason: '$where: $key left');
  expect(r.right, lessThanOrEqualTo(size.width + 0.5), reason: '$where: $key right ${r.right} > ${size.width}');
  if (action) expect(r.height, greaterThanOrEqualTo(43.9), reason: '$where: $key height');
}

/// Opens a card, scrolling the tab to it first (the list builds lazily).
Future<void> openCard(WidgetTester tester, String key) async {
  final card = find.byKey(Key('monthly-card-$key'));
  await show(tester, 'monthly-card-$key');
  await tester.tap(find.descendant(of: card, matching: find.byType(InkWell)).first);
  await tester.pumpAndSettle();
}

/// Scroll the control into view, let the scroll settle, then tap it.
Future<void> step(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

const sizes = [Size(320, 568), Size(360, 800), Size(393, 852), Size(430, 932), Size(700, 1000), Size(1000, 800)];
const scales = [1.0, 1.5, 2.0];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final size in sizes) {
    for (final scale in scales) {
      final tag = '${size.width.toInt()}x${size.height.toInt()} @${scale}x';

      testWidgets('every card and state fits: $tag', (tester) async {
        await mount(tester, size, scale);
        clean(tester, 'initial');

        // Manual entry: selection, review, result.
        await openCard(tester, 'manual');
        clean(tester, 'manual open');
        expect(find.descendant(of: find.byKey(const Key('manual-employee-list')), matching: find.byType(Scrollable)),
            findsNothing,
            reason: 'checklist must not scroll on its own');
        expect(
          find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical),
          findsOneWidget,
          reason: 'only the tab scrolls vertically',
        );
        await step(tester, 'manual-select-all');
        clean(tester, 'select all');
        await reachable(tester, 'manual-clear-selection', size, 'clear selection');
        await step(tester, 'manual-employee-EMP-7');
        await step(tester, 'manual-employee-EMP-7');
        await step(tester, 'manual-leave-type');
        await tester.tap(find.text(longType).last);
        await tester.pumpAndSettle();
        clean(tester, 'long leave type chosen');
        await tester.enterText(find.byKey(const Key('manual-credit')), '1.5');
        await tester.pumpAndSettle();
        await reachable(tester, 'manual-review', size, 'review');
        await step(tester, 'manual-review');
        clean(tester, 'manual review');
        await reachable(tester, 'manual-confirm', size, 'manual confirm');
        expect(find.byKey(const Key('monthly-row-1')), findsOneWidget);
        await step(tester, 'manual-confirm');
        clean(tester, 'manual result');
        expect(find.byKey(const Key('manual-result')), findsOneWidget);

        // Import: file chosen, preview, result.
        await openCard(tester, 'import');
        clean(tester, 'import open');
        await reachable(tester, 'import-sample-csv', size, 'sample csv');
        await reachable(tester, 'import-sample-xlsx', size, 'sample xlsx');
        await reachable(tester, 'import-choose-file', size, 'choose');
        await step(tester, 'import-choose-file');
        clean(tester, 'file chosen');
        await reachable(tester, 'import-file-name', size, 'file name', action: false);
        await reachable(tester, 'import-preview', size, 'preview');
        await step(tester, 'import-preview');
        clean(tester, 'import preview');
        await reachable(tester, 'import-confirm', size, 'import confirm');
        await step(tester, 'import-confirm');
        clean(tester, 'import result');
        await reachable(tester, 'import-another', size, 'import another');

        // Assignments: list, edit sheet, confirm step.
        await openCard(tester, 'assignments');
        clean(tester, 'assignments open');
        await reachable(tester, 'assignment-edit-EMP-7-casual', size, 'edit');
        await step(tester, 'assignment-edit-EMP-7-casual');
        clean(tester, 'edit sheet');
        await tester.enterText(find.byKey(const Key('edit-credit')), '3');
        await tester.pumpAndSettle();
        await reachable(tester, 'edit-review', size, 'review change');
        await reachable(tester, 'edit-back', size, 'edit cancel');
        await step(tester, 'edit-review');
        clean(tester, 'edit confirm step');
        await reachable(tester, 'edit-confirm', size, 'edit confirm');
        await reachable(tester, 'edit-back', size, 'edit back');
      });
    }
  }

  testWidgets('empty states fit at 320dp / 2x (no assignments, employee list error)', (tester) async {
    final server = LongServer()..assignments = [];
    server.refuse['GET ${ApiConstants.employees}'] = (
      status: 500,
      message: 'Employees could not be loaded. $longMessage',
    );
    const size = Size(320, 568);
    await mount(tester, size, 2, server: server);
    await openCard(tester, 'manual');
    expect(find.byKey(const Key('manual-list-error')), findsOneWidget);
    clean(tester, 'employee error');
    await openCard(tester, 'assignments');
    expect(find.byKey(const Key('assign-empty')), findsOneWidget);
    clean(tester, 'assignments empty');
  });

  testWidgets('error states fit at 320dp / 2x (assignments error, no employees)', (tester) async {
    final bad = LongServer()
      ..refuse['GET ${ApiConstants.leaveMonthlyAssignments}'] = (status: 500, message: longMessage)
      ..employees = [];
    const size = Size(320, 568);
    await mount(tester, size, 2, server: bad);
    await openCard(tester, 'manual');
    expect(find.text('No employees found.'), findsOneWidget);
    await openCard(tester, 'assignments');
    expect(find.byKey(const Key('assign-error')), findsOneWidget);
    await reachable(tester, 'assign-retry', size, 'retry');
    clean(tester, 'assignments error');
  });

  testWidgets('keyboard open on 320x568: the credit field stays reachable', (tester) async {
    const size = Size(320, 568);
    await mount(tester, size, 1.5);
    await openCard(tester, 'manual');
    await show(tester, 'manual-credit');
    await tester.tap(find.byKey(const Key('manual-credit')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    final r = tester.getRect(find.byKey(const Key('manual-credit')));
    // The input itself (≥48dp; its helper text may sit lower) is above the keyboard.
    expect(r.top + 48, lessThanOrEqualTo(size.height - 280 + 0.5), reason: 'field hidden by the keyboard');
    expect(r.top, greaterThanOrEqualTo(0));
    clean(tester, 'keyboard');
  });

  testWidgets('keyboard open: the edit sheet scrolls and keeps its actions reachable', (tester) async {
    const size = Size(320, 568);
    await mount(tester, size, 2, keyboard: 280);
    await openCard(tester, 'assignments');
    await step(tester, 'assignment-edit-EMP-7-casual');
    await tester.enterText(find.byKey(const Key('edit-credit')), '3');
    await tester.pumpAndSettle();
    clean(tester, 'sheet with keyboard');
    // The sheet content scrolls above the keyboard: the action can be brought into view.
    await tester.ensureVisible(find.byKey(const Key('edit-review')));
    await tester.pumpAndSettle();
    final r = tester.getRect(find.byKey(const Key('edit-review')));
    expect(r.bottom, lessThanOrEqualTo(size.height - 280 + 0.5));
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(size.width));
    await tester.tap(find.byKey(const Key('edit-review')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit-confirm-text')), findsOneWidget);
  });

  testWidgets('tablet: centred column ≤ 720dp, assignment and record cards in two columns', (tester) async {
    await mount(tester, const Size(1000, 2400), 1);
    await openCard(tester, 'assignments');
    final card = tester.getRect(find.byKey(const Key('monthly-card-assignments')));
    expect(card.width, lessThanOrEqualTo(720.5));
    expect(card.center.dx, closeTo(500, 1));
    final a = tester.getTopLeft(find.byKey(const Key('assignment-EMP-7-casual')));
    final b = tester.getTopLeft(find.byKey(const Key('assignment-EMP-8-earned')));
    expect(a.dy, closeTo(b.dy, 0.5), reason: 'two columns on a tablet');
    expect(a.dx, isNot(closeTo(b.dx, 1)));

    await openCard(tester, 'manual');
    await step(tester, 'manual-employee-EMP-7');
    await step(tester, 'manual-leave-type');
    await tester.tap(find.text(longType).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('manual-credit')), '1');
    await tester.pumpAndSettle();
    await step(tester, 'manual-review');
    final r1 = tester.getTopLeft(find.byKey(const Key('monthly-row-1')));
    final r2 = tester.getTopLeft(find.byKey(const Key('monthly-row-2')));
    expect(r1.dy, closeTo(r2.dy, 0.5));
    clean(tester, 'tablet');
  });

  testWidgets('phone: assignment and record cards stack in one column', (tester) async {
    await mount(tester, const Size(393, 3000), 1);
    await openCard(tester, 'assignments');
    final a = tester.getTopLeft(find.byKey(const Key('assignment-EMP-7-casual')));
    final b = tester.getTopLeft(find.byKey(const Key('assignment-EMP-8-earned')));
    expect(b.dy, greaterThan(a.dy + 20));
    expect(b.dx, closeTo(a.dx, 0.5));
    clean(tester, 'phone');
  });

  testWidgets('narrow or large text stacks the primary action above the secondary', (tester) async {
    await mount(tester, const Size(360, 3000), 1);
    await openCard(tester, 'import');
    await step(tester, 'import-choose-file');
    await step(tester, 'import-preview');
    final confirm = tester.getRect(find.byKey(const Key('import-confirm')));
    final cancel = tester.getRect(find.text('Cancel'));
    expect(confirm.bottom, lessThanOrEqualTo(cancel.top), reason: 'primary on top when stacked');
    expect(confirm.width, greaterThan(250), reason: 'full width when stacked');
  });
}
