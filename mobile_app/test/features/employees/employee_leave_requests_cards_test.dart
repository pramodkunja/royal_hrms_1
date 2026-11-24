// Task 110: Employee Profile → Leave → Leave Requests cards (web LeaveTab.tsx +
import 'dart:async';

// LeaveRequestDetailModal.tsx), against a stand-in for GET /leave/requests/. Synthetic data only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/employees/presentation/widgets/employee_leave_request_cards.dart';
import 'package:mobile_app/features/leave/presentation/widgets/leave_request_detail_sheet.dart';

import '../../visual/employee_leave_cards_harness.dart';

Finder k(String key) => find.byKey(Key(key));

String textOf(WidgetTester t, String key) => (t.widget(k(key)) as Text).data!;

String allText(WidgetTester t, Finder of) => t
    .widgetList<RichText>(find.descendant(of: of, matching: find.byType(RichText)))
    .map((r) => r.text.toPlainText())
    .join(' | ');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('formatting', () {
    test('date range: single day, same year, across years', () {
      expect(formatLeaveRange('2026-03-10', '2026-03-10'), '10 Mar 2026');
      expect(formatLeaveRange('2026-03-10', '2026-03-11'), '10 Mar – 11 Mar 2026');
      expect(formatLeaveRange('2026-12-30', '2027-01-02'), '30 Dec 2026 – 2 Jan 2027');
      expect(formatLeaveRange('', ''), '—');
    });
    test('days keep fractions and pluralise like web', () {
      expect(formatLeaveDays(1), '1 day');
      expect(formatLeaveDays(0.5), '0.5 days');
      expect(formatLeaveDays(2), '2 days');
      expect(formatLeaveDays(2.5), '2.5 days');
    });
    test('status labels are web STATUS_LABEL', () {
      expect(leaveStatusLabel('pending'), 'Pending Manager Approval');
      expect(leaveStatusLabel('l2_pending'), 'Pending HR Approval');
      expect(leaveStatusLabel('cancelled'), 'Cancelled');
    });
  });

  group('cards', () {
    testWidgets('1. request: employee_id/year/page sent; one card per row with web status wording', (t) async {
      await pumpLeaveRequests(t);
      expect(lastServer.requestCalls().first, {'employee_id': empCode, 'year': thisYear, 'page': 1});
      for (final id in ['r1', 'r2', 'r3', 'r4', 'r5']) {
        expect(k('leave-request-card-$id'), findsOneWidget);
      }
      expect(allText(t, k('leave-request-status-r1')), 'Pending Manager Approval');
      expect(allText(t, k('leave-request-status-r2')), 'Pending HR Approval');
      expect(allText(t, k('leave-request-status-r3')), 'Approved');
      expect(allText(t, k('leave-request-status-r4')), 'Rejected');
      expect(allText(t, k('leave-request-status-r5')), 'Cancelled');
      // No raw status codes leak.
      expect(find.text('l2_pending'), findsNothing);
    });

    testWidgets('2. dates, day counts (half day kept as 0.5), LOP, reason in full', (t) async {
      await pumpLeaveRequests(t);
      expect(textOf(t, 'leave-request-dates-r1'), '10 Mar – 11 Mar $thisYear');
      expect(allText(t, k('leave-request-days-r1')), '2 days');
      expect(textOf(t, 'leave-request-dates-r3'), '5 Feb $thisYear');
      expect(allText(t, k('leave-request-days-r3')), '0.5 days');
      expect(find.text('Half Day (Morning)'), findsOneWidget);
      expect(allText(t, k('leave-request-days-r5')), '1 day');
      expect(find.text('Full Day'), findsNothing);
      expect(allText(t, k('leave-request-lop-r4')), 'LOP 1.5d');
      expect(k('leave-request-lop-r1'), findsNothing);
      expect(textOf(t, 'leave-request-reason-r1'), 'Family function out of town, travelling by road on the 10th.');
      final tw = t.widget<Text>(k('leave-request-reason-r1'));
      expect(tw.maxLines, isNull);
      expect(tw.overflow, isNull);
    });

    testWidgets('3. approval levels are shown separately; L2 only when an HR approver exists', (t) async {
      await pumpLeaveRequests(t);
      expect(k('leave-approval-l1-r2'), findsOneWidget);
      expect(k('leave-approval-l2-r2'), findsOneWidget);
      expect(textOf(t, 'leave-approval-l1-r2-status'), 'Approved');
      expect(textOf(t, 'leave-approval-l2-r2-status'), 'Pending');
      expect(allText(t, k('leave-approval-l1-r2')), contains('Meera Nair'));
      expect(allText(t, k('leave-approval-l1-r2')), contains('“Fine with the plan.”'));
      expect(allText(t, k('leave-approval-l2-r2')), contains('Hema Iyer'));
      // Single-level request: no HR row.
      expect(k('leave-approval-l1-r1'), findsOneWidget);
      expect(k('leave-approval-l2-r1'), findsNothing);
      // Rejection note comes from the level that rejected.
      expect(textOf(t, 'leave-approval-l1-r4-status'), 'Rejected');
      expect(allText(t, k('leave-approval-l1-r4')), contains('Month-end closing, please reschedule.'));
      // Final approver line (web "Approver" column).
      expect(textOf(t, 'leave-request-final-r1'), 'Not yet actioned');
      expect(textOf(t, 'leave-request-final-r3'), 'Final decision: Meera Nair · 3 Feb $thisYear');
    });

    testWidgets('4. permission-gated entry points', (t) async {
      final s = LeaveCardsServer()
        ..pages = {
          1: [
            reqJson('a', status: 'pending', canApprove: true, l1Status: 'pending'),
            reqJson('b', status: 'pending', canCancel: true, l1Status: 'pending'),
            reqJson('c', status: 'approved', canRequestCancellation: true, l1Status: 'approved'),
            reqJson('d', status: 'approved', canApprove: true, l1Status: 'approved'),
            reqJson('e', status: 'pending', l1Status: 'pending'),
            reqJson('f', status: 'approved', cancellationStatus: 'requested', l1Status: 'approved'),
          ],
        };
      await pumpLeaveRequests(t, server: s, height: 4000);
      String label(String id) =>
          t.widget<Text>(find.descendant(of: k('leave-request-open-$id'), matching: find.byType(Text))).data!;
      expect(label('a'), 'Review request');
      expect(label('b'), 'View / cancel');
      expect(label('c'), 'View / cancel');
      expect(label('d'), 'View details', reason: 'canApprove only counts while the request is pending');
      expect(label('e'), 'View details');
      expect(k('leave-request-action-a'), findsOneWidget);
      expect(k('leave-request-action-d'), findsNothing);
      expect(k('leave-request-action-e'), findsNothing);
      expect(k('leave-request-cancelreq-f'), findsOneWidget);
    });

    testWidgets('5. tapping a card or its button opens the request detail sheet', (t) async {
      await pumpLeaveRequests(t);
      await t.tap(k('leave-request-open-r1'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(LeaveRequestDetailSheet), findsOneWidget);
      expect(t.widget<LeaveRequestDetailSheet>(find.byType(LeaveRequestDetailSheet)).initial.id, 'r1');
      await t.pumpAndSettle(const Duration(seconds: 1));
    });

    testWidgets('6. actions are at least 44dp', (t) async {
      await pumpLeaveRequests(t);
      expect(t.getSize(k('leave-request-open-r1')).height, greaterThanOrEqualTo(44));
    });
  });

  group('pagination and year', () {
    testWidgets('7. Prev disabled on page 1; Next fetches page 2; Prev returns', (t) async {
      final s = LeaveCardsServer()
        ..pages = {
          1: [reqJson('p1')],
          2: [reqJson('p2', reason: 'Second page reason')],
        };
      await pumpLeaveRequests(t, server: s);
      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(t.widget<OutlinedButton>(k('employee-leave-requests-prev')).onPressed, isNull);
      await t.ensureVisible(k('employee-leave-requests-next'));
      await t.tap(k('employee-leave-requests-next'));
      await settleFrames(t);
      expect(s.requestCalls().last, {'employee_id': empCode, 'year': thisYear, 'page': 2});
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(k('leave-request-card-p2'), findsOneWidget);
      expect(t.widget<OutlinedButton>(k('employee-leave-requests-next')).onPressed, isNull);
      await t.tap(k('employee-leave-requests-prev'));
      await settleFrames(t);
      expect(k('leave-request-card-p1'), findsOneWidget);
    });

    testWidgets('8. year arrows refetch for that year and reset to page 1', (t) async {
      final s = LeaveCardsServer()
        ..pages = {
          1: [reqJson('p1')],
          2: [reqJson('p2')]
        };
      await pumpLeaveRequests(t, server: s);
      await t.ensureVisible(k('employee-leave-requests-next'));
      await t.tap(k('employee-leave-requests-next'));
      await settleFrames(t);
      t.widget<IconButton>(k('employee-leave-year-prev')).onPressed!();
      await settleFrames(t);
      expect(s.requestCalls().last, {'employee_id': empCode, 'year': thisYear - 1, 'page': 1});
    });
  });

  group('states', () {
    testWidgets('9. no requests for the year: calm empty state, no cards, no pagination', (t) async {
      await pumpLeaveRequests(t, server: LeaveCardsServer()..pages = {1: []});
      expect(k('employee-leave-requests-empty'), findsOneWidget);
      expect(find.text('No leave requests found for $thisYear.'), findsOneWidget);
      expect(find.textContaining('Couldn’t load'), findsNothing);
      expect(find.byWidgetPredicate((w) => w.key.toString().contains('leave-request-card-')), findsNothing);
    });

    testWidgets('10. API failure: error state with the server message and a working Retry', (t) async {
      final s = LeaveCardsServer()..requestsStatus = 500;
      await pumpLeaveRequests(t, server: s);
      expect(k('employee-leave-requests-empty'), findsNothing);
      expect(find.text('Couldn’t load leave requests'), findsOneWidget);
      expect(find.text('Server exploded.'), findsOneWidget);
      final before = s.requestCalls().length;
      s.requestsStatus = null;
      await t.ensureVisible(find.text('Retry'));
      await t.tap(find.text('Retry'));
      await settleFrames(t);
      expect(s.requestCalls().length, greaterThan(before));
      expect(k('leave-request-card-r1'), findsOneWidget);
      expect(find.text('Couldn’t load leave requests'), findsNothing);
    });

    testWidgets('11. loading shows a spinner, not the empty state', (t) async {
      final s = LeaveCardsServer();
      s.holdRequests = Completer<void>();
      await pumpLeaveRequests(t, server: s, settle: false);
      await t.pump(const Duration(milliseconds: 200));
      expect(k('employee-leave-requests-empty'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      s.holdRequests!.complete();
      await settleFrames(t);
      expect(k('leave-request-card-r1'), findsOneWidget);
    });
  });

  group('responsive', () {
    final multi = LeaveCardsServer()
      ..pages = {
        1: [
          reqJson('m1',
              status: 'l2_pending',
              display: 'Extraordinary Long Named Special Compensatory Leave Type For Testing',
              reason: 'A very long reason ' * 20,
              totalDays: '10.5',
              lopDays: '2.5',
              documentUrl: 'https://files.example.test/a.pdf',
              canApprove: true,
              cancellationStatus: 'requested',
              l1Status: 'approved',
              l1Remarks: 'Long approval remark ' * 8,
              l1At: '$thisYear-03-20T10:00:00+05:30',
              l2Name: 'Hema Iyer With A Rather Long Display Name',
              l2Status: 'pending'),
          reqJson('m2',
              status: 'approved',
              duration: 'half_afternoon',
              durationDisplay: 'Half Day (Afternoon)',
              totalDays: '0.5'),
          reqJson('m3', status: 'rejected', l1Status: 'rejected', l1Remarks: 'No'),
        ],
        2: [],
      };
    const sizes = [
      Size(320, 568),
      Size(360, 800),
      Size(393, 852),
      Size(430, 932),
      Size(600, 900),
      Size(800, 1000),
      Size(1000, 1000)
    ];
    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final sz in sizes) {
          testWidgets('12. no overflow ${sz.width.toInt()}w ${scale}x ${dark ? 'dark' : 'light'}', (t) async {
            await pumpLeaveRequests(t, server: multi, width: sz.width, height: sz.height, scale: scale, dark: dark);
            final scrollable = find.byType(Scrollable).first;
            for (final id in ['m1', 'm2', 'm3']) {
              await t.scrollUntilVisible(k('leave-request-card-$id'), 200, scrollable: scrollable);
              await t.pump();
              expect(t.takeException(), isNull);
            }
          });
        }
      }
    }

    testWidgets('13. one column on phones, two from 600dp, centred max width on large screens', (t) async {
      await pumpLeaveRequests(t, server: multi, width: 393, height: 3000);
      expect(t.getTopLeft(k('leave-request-card-m1')).dx, t.getTopLeft(k('leave-request-card-m2')).dx);
      await pumpLeaveRequests(t, server: multi, width: 800, height: 3000);
      expect(t.getTopLeft(k('leave-request-card-m1')).dx, isNot(t.getTopLeft(k('leave-request-card-m2')).dx));
      await pumpLeaveRequests(t, server: multi, width: 1600, height: 3000);
      final left = t.getTopLeft(k('leave-request-card-m1')).dx;
      final right = t.getTopRight(k('leave-request-card-m2')).dx;
      expect(right - left, lessThanOrEqualTo(960));
    });

    testWidgets('14. at large text the header stacks (status under the title)', (t) async {
      await pumpLeaveRequests(t, server: multi, width: 360, height: 3000, scale: 1.5);
      expect(t.getTopLeft(k('leave-request-status-m1')).dy,
          greaterThan(t.getBottomLeft(k('leave-request-type-m1')).dy - 1));
    });
  });
}
