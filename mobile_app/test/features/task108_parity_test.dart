// Task 108: My Referrals (unsupported bonus breakdown removed), My Attendance → View All
// Corrections, and Expenses summary cards against GET /expenses/stats/. Stand-in API only.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/attendance/data/models/attendance_models.dart';
import 'package:mobile_app/features/attendance/presentation/screens/my_attendance_screen.dart' show recentCorrections;
import 'package:mobile_app/features/expenses/data/models/expense_model.dart';
import 'package:mobile_app/features/expenses/presentation/screens/expense_screen.dart';
import 'package:mobile_app/features/my_requests/presentation/providers/my_requests_providers.dart';
import 'package:mobile_app/features/my_requests/presentation/screens/my_requests_screen.dart';

import '../visual/task108_visual_test.dart' as v;

Finder _k(String k) => find.byKey(Key(k));
v.T108Server get _s => v.last;

/// Where the router is now, including a pushed page (the base `uri` stays the page underneath).
Uri _here(GoRouter r) {
  final last = r.routerDelegate.currentConfiguration.last;
  return last is ImperativeRouteMatch ? last.matches.uri : r.routerDelegate.currentConfiguration.uri;
}

String _text(WidgetTester t, String key) {
  final self = _k(key).evaluate();
  if (self.isNotEmpty && self.first.widget is Text) return (self.first.widget as Text).data ?? '';
  final f = find.descendant(of: _k(key), matching: find.byType(Text));
  return [for (final e in f.evaluate()) (e.widget as Text).data ?? ''].join('|');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ───────────────────────────── Referrals ─────────────────────────────
  group('My Referrals', () {
    testWidgets('the unsupported Referral Bonus Breakdown is gone; the rules are still listed', (t) async {
      await v.open(t, 'referrals', size: const Size(393, 1400), shots: false);
      await v.tapText(t, 'Referral Rules');
      for (final gone in [
        'Referral Bonus Breakdown',
        'REFERRAL BONUS BREAKDOWN',
        '₹10,000',
        '90-Day Milestone',
        'Candidate Selected',
        'Referral Accepted'
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);
      expect(find.text('Eligibility'), findsOneWidget);
      expect(find.text('Bonus'), findsOneWidget);
      expect(find.textContaining('probation period'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    test('the source has no breakdown panel or hardcoded stage data left', () {
      final card = File('lib/features/referrals/presentation/widgets/referral_rule_card.dart').readAsStringSync();
      final screen = File('lib/features/referrals/presentation/screens/referrals_screen.dart').readAsStringSync();
      for (final src in [card, screen]) {
        expect(src.contains('ReferralBonusBreakdownPanel'), isFalse);
        expect(src.contains('_BreakdownStageBox'), isFalse);
        expect(src.contains('10,000'), isFalse);
      }
    });

    testWidgets('supported content stays: my referrals, the stats and the Refer Someone action', (t) async {
      await v.open(t, 'referrals', shots: false);
      expect(find.text('Riya Sen'), findsOneWidget);
      expect(find.text('Refer Someone'), findsOneWidget);
      expect(_s.count('GET', '/recruitment/referrals/'), 1);
    });

    testWidgets('no rules: the empty state; failed rules: an error with Retry that reloads', (t) async {
      await v.open(t, 'referrals', shots: false, server: v.T108Server()..noRules = true);
      await v.tapText(t, 'Referral Rules');
      expect(find.text('No rules configured'), findsOneWidget);
      final s = v.T108Server()..rulesStatus = 500;
      await v.open(t, 'referrals', shots: false, server: s);
      await v.tapText(t, 'Referral Rules');
      expect(find.text('Retry'), findsOneWidget);
      s.rulesStatus = 200;
      await v.tapText(t, 'Retry');
      expect(find.text('Eligibility'), findsOneWidget);
    });

    for (final (w, sc) in [(320.0, 2.0), (360.0, 1.0), (430.0, 1.0), (600.0, 1.0), (1000.0, 1.0)]) {
      testWidgets('rules tab fits at ${w.toInt()}dp @ $sc×, no gap or overflow where the section was', (t) async {
        await v.open(t, 'referrals', size: Size(w, 1800), scale: sc, shots: false);
        await v.tapText(t, 'Referral Rules');
        expect(t.takeException(), isNull);
      });
    }
  });

  // ──────────────────────── My Attendance → corrections ────────────────────────
  group('Attendance corrections', () {
    List<Map<String, dynamic>> eight() => [
          for (var i = 1; i <= 8; i++)
            v.T108Server.correction('$i', '2026-11-0$i 09:00:00',
                reason: 'reason-$i',
                status: i == 4 ? 'l2_pending' : (i % 3 == 0 ? 'approved' : (i == 2 ? 'rejected' : 'pending'))),
          v.T108Server.correction('9', '2026-11-09 09:00:00', reason: 'late-row', kind: 'late_justification'),
        ];

    Future<void> corrTab(WidgetTester t, {v.T108Server? s, Size size = const Size(393, 2600), double scale = 1}) async {
      await v.open(t, 'attendance', size: size, scale: scale, shots: false, server: s);
      while (t.takeException() != null) {} // the Attendance tab overflows at 2x on its own (pre-existing)
      await v.tapText(t, 'Attendance Corrections');
    }

    testWidgets('View All Corrections is on the corrections tab only, with web’s card title', (t) async {
      await v.open(t, 'attendance', size: const Size(393, 2600), shots: false);
      expect(_k('corrections-view-all'), findsNothing); // Attendance tab
      await v.tapText(t, 'Attendance Corrections');
      expect(_k('corrections-view-all'), findsOneWidget);
      expect(find.text('View All Corrections'), findsOneWidget);
      expect(find.text('Recent Correction Requests'), findsOneWidget);
      expect(t.getSize(_k('corrections-view-all')).height, greaterThanOrEqualTo(44));
    });

    testWidgets(
        'the card shows only the latest five punch corrections, newest first; the history lives behind View All',
        (t) async {
      await corrTab(t, s: v.T108Server()..corrections = eight());
      for (final shown in [8, 7, 6, 5, 4]) {
        expect(find.text('reason-$shown'), findsOneWidget, reason: 'reason-$shown');
      }
      for (final hidden in [3, 2, 1]) {
        expect(find.text('reason-$hidden'), findsNothing, reason: 'reason-$hidden');
      }
      expect(t.getTopLeft(find.text('reason-8')).dy, lessThan(t.getTopLeft(find.text('reason-4')).dy));
    });

    testWidgets('counts cover every punch correction, not just the five shown', (t) async {
      await corrTab(t, s: v.T108Server()..corrections = eight());
      // 8 punch rows: 2 rejected? ids: 2 rejected; 3,6 approved; 4 l2_pending; rest pending → pending 5? (1,4,5,7,8)
      expect(_text(t, 'correction-count-pending'), '5');
      expect(_text(t, 'correction-count-approved'), '2');
      expect(_text(t, 'correction-count-rejected'), '1');
    });

    testWidgets('status badges: l2_pending reads Pending; approved and rejected as such', (t) async {
      await corrTab(t, s: v.T108Server()..corrections = eight());
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Approved'), findsWidgets);
    });

    testWidgets('View All pushes My Requests on its Attendance Correction tab, which lists the corrections', (t) async {
      final router = await v.open(t, 'attendance', size: const Size(393, 2600), shots: false);
      await v.tapText(t, 'Attendance Corrections');
      await v.tapKey(t, 'corrections-view-all');
      expect(_here(router).path, '/dashboard/my-requests');
      expect(_here(router).queryParameters['tab'], 'attendance_correction');
      expect(find.text('My Requests'), findsOneWidget);
      final container = ProviderScope.containerOf(t.element(find.byType(MyRequestsScreen)));
      expect(container.read(myRequestsTypeTabProvider), MyRequestsTypeTab.attendanceCorrection);
      // the expenses the stand-in also returns are not in this tab
      expect(find.textContaining('Client visit'), findsNothing);
      expect(find.textContaining('AC-'), findsWidgets);
    });

    testWidgets('Back returns to My Attendance', (t) async {
      final router = await v.open(t, 'attendance', size: const Size(393, 2600), shots: false);
      await v.tapText(t, 'Attendance Corrections');
      await v.tapKey(t, 'corrections-view-all');
      expect(router.canPop(), isTrue);
      router.pop();
      await v.settle(t);
      expect(find.text('My Requests'), findsNothing);
      expect(_k('corrections-view-all'), findsOneWidget);
      expect(_here(router).path, '/attendance');
    });

    testWidgets('data scoping: one request to the my-corrections endpoint, with no employee parameter', (t) async {
      await corrTab(t);
      final calls = _s.where('GET', '/attendance/corrections/my/');
      expect(calls, isNotEmpty);
      expect(calls.first.query, {'page_size': 100});
      expect(
          _s.requests
              .where((r) => r.path.contains('/attendance/corrections/') && r.path != '/attendance/corrections/my/'),
          isEmpty);
    });

    testWidgets('visible whatever the permissions (web has no condition)', (t) async {
      await v.open(t, 'attendance', size: const Size(393, 2600), shots: false, as: v.t108User(const []));
      await v.tapText(t, 'Attendance Corrections');
      expect(_k('corrections-view-all'), findsOneWidget);
    });

    testWidgets('no corrections: the empty message with View All still there; failed load: error with Retry, no card',
        (t) async {
      await corrTab(t, s: v.T108Server()..corrections = []);
      expect(find.text('No correction requests yet.'), findsOneWidget);
      expect(_k('corrections-view-all'), findsOneWidget);
      final s = v.T108Server()..correctionsStatus = 500;
      await corrTab(t, s: s);
      expect(find.text('Retry'), findsOneWidget);
      expect(_k('corrections-view-all'), findsNothing);
      s.correctionsStatus = 200;
      await v.tapText(t, 'Retry');
      expect(_k('corrections-view-all'), findsOneWidget);
    });

    test('?tab= maps like web: leave | expense | wfh | attendance_correction, anything else → All', () {
      expect(myRequestsTabFromQuery('attendance_correction'), MyRequestsTypeTab.attendanceCorrection);
      expect(myRequestsTabFromQuery('leave'), MyRequestsTypeTab.leave);
      expect(myRequestsTabFromQuery('expense'), MyRequestsTypeTab.expense);
      expect(myRequestsTabFromQuery('wfh'), MyRequestsTypeTab.wfh);
      expect(myRequestsTabFromQuery('nonsense'), MyRequestsTypeTab.all);
      expect(myRequestsTabFromQuery(null), MyRequestsTypeTab.all);
    });

    test('latest-five helper: newest first, ties and bad dates do not throw', () {
      final list = [
        for (final (id, c) in [
          ('a', '2026-11-01 10:00:00'),
          ('b', 'garbage'),
          ('c', '2026-11-03 10:00:00'),
          ('d', '2026-11-02 10:00:00')
        ])
          MyCorrectionModel.fromJson(v.T108Server.correction(id, c)),
      ];
      expect(recentCorrections(list, count: 3).map((r) => r.id).toList(), ['c', 'd', 'a']);
    });

    for (final (w, sc) in [(320.0, 2.0), (360.0, 1.5), (393.0, 1.0), (600.0, 1.0), (1000.0, 1.0)]) {
      testWidgets('corrections tab at ${w.toInt()}dp @ $sc× fits (cards, counts, View All)', (t) async {
        await corrTab(t, s: v.T108Server()..corrections = eight(), size: Size(w, 4200), scale: sc);
        expect(t.takeException(), isNull);
        expect(t.getRect(_k('corrections-view-all')).right, lessThanOrEqualTo(w));
      });
    }
  });

  // ──────────────────────────── Expenses statistics ────────────────────────────
  group('Expense statistics', () {
    testWidgets('mapping: every card shows its backend field, formatted as web does', (t) async {
      await v.open(t, 'expenses', size: const Size(393, 1400), shots: false);
      expect(_text(t, 'expense-stat-total'), '12|Total Claims');
      expect(_text(t, 'expense-stat-pending'), '3|Pending|₹18,250');
      expect(_text(t, 'expense-stat-approved'), '7|Approved|₹96,000.75');
      expect(_text(t, 'expense-stat-rejected'), '2|Rejected');
      expect(_text(t, 'expense-stat-amount'), '₹1.5L|Total Claimed Amount');
    });

    testWidgets('the summary endpoint is called once with no parameters (server scopes it)', (t) async {
      await v.open(t, 'expenses', shots: false);
      final calls = _s.where('GET', '/expenses/stats/');
      expect(calls.length, 1);
      expect(calls.single.query, isEmpty);
    });

    testWidgets('totals do not come from the list: 3 rows listed, 12 claims in the summary', (t) async {
      await v.open(t, 'expenses', size: const Size(393, 1400), shots: false);
      expect(find.textContaining('Client visit'), findsNWidgets(3));
      expect(_text(t, 'expense-stat-total'), startsWith('12'));
    });

    testWidgets('real zeros are shown as 0 and ₹0, with no sub-amounts', (t) async {
      await v.open(t, 'expenses',
          size: const Size(393, 1400),
          shots: false,
          server: v.T108Server()
            ..emptyExpenses = true
            ..stats = {
              'total': 0,
              'pending': 0,
              'approved': 0,
              'rejected': 0,
              'total_amount': 0.0,
              'pending_amount': 0.0,
              'approved_amount': 0.0,
            });
      expect(_text(t, 'expense-stat-total'), '0|Total Claims');
      expect(_text(t, 'expense-stat-pending'), '0|Pending');
      expect(_text(t, 'expense-stat-amount'), '₹0|Total Claimed Amount');
    });

    testWidgets('missing or non-numeric fields are unknown (—), never 0', (t) async {
      await v.open(t, 'expenses',
          size: const Size(393, 1400),
          shots: false,
          server: v.T108Server()..statsBody = {'total': 5, 'pending': 'many', 'total_amount': null});
      expect(_text(t, 'expense-stat-total'), '5|Total Claims');
      expect(_text(t, 'expense-stat-pending'), '—|Pending');
      expect(_text(t, 'expense-stat-approved'), '—|Approved');
      expect(_text(t, 'expense-stat-rejected'), '—|Rejected');
      expect(_text(t, 'expense-stat-amount'), '—|Total Claimed Amount');
    });

    testWidgets('a response that is not an object is an error, not zeros', (t) async {
      await v.open(t, 'expenses',
          size: const Size(393, 1400), shots: false, server: v.T108Server()..statsBody = 'oops');
      expect(_k('expense-stats-error'), findsOneWidget);
      expect(_text(t, 'expense-stat-total'), '—|Total Claims');
    });

    testWidgets('server error / 404: a visible error with Retry, cards show —, and Retry reloads', (t) async {
      for (final status in [500, 404]) {
        final s = v.T108Server()..statsStatus = status;
        await v.open(t, 'expenses', size: const Size(393, 1400), shots: false, server: s);
        expect(_k('expense-stats-error'), findsOneWidget, reason: '$status');
        expect(find.text('Could not load the summary'), findsOneWidget);
        expect(_text(t, 'expense-stat-total'), '—|Total Claims');
        expect(_text(t, 'expense-stat-amount'), '—|Total Claimed Amount');
        s.statsStatus = 200;
        await v.tapText(t, 'Retry');
        expect(_k('expense-stats-error'), findsNothing);
        expect(_text(t, 'expense-stat-total'), '12|Total Claims');
      }
    });

    testWidgets('permission denied (403): access denied with the server’s message, no Retry, no zeros', (t) async {
      await v.open(t, 'expenses', size: const Size(393, 1400), shots: false, server: v.T108Server()..statsStatus = 403);
      expect(find.text('Access denied'), findsOneWidget);
      expect(find.text('You do not have permission.'), findsOneWidget);
      expect(_text(t, 'expense-stat-total'), '—|Total Claims');
    });

    testWidgets('partial failure: summary fails but the list still shows; list fails but the summary still shows',
        (t) async {
      await v.open(t, 'expenses', size: const Size(393, 1400), shots: false, server: v.T108Server()..statsStatus = 500);
      expect(find.textContaining('Client visit'), findsNWidgets(3));
      expect(_k('expense-stats-error'), findsOneWidget);
      await v.open(t, 'expenses', size: const Size(393, 1400), shots: false, server: v.T108Server()..listStatus = 500);
      expect(find.text('Failed to load expenses'), findsOneWidget);
      expect(_text(t, 'expense-stat-total'), '12|Total Claims');
      expect(_k('expense-stats-error'), findsNothing);
    });

    testWidgets('while loading the cards show — (no stale or placeholder numbers), then the real values', (t) async {
      final gate = Completer<void>();
      final s = v.T108Server()..statsHold = gate;
      await v.open(t, 'expenses', size: const Size(393, 1400), shots: false, server: s);
      expect(_text(t, 'expense-stat-total'), '—|Total Claims');
      expect(_text(t, 'expense-stat-amount'), '—|Total Claimed Amount');
      gate.complete();
      await v.settle(t);
      expect(_text(t, 'expense-stat-total'), '12|Total Claims');
    });

    testWidgets('pull to refresh re-requests the summary, and shows — rather than stale values meanwhile', (t) async {
      final s = v.T108Server();
      await v.open(t, 'expenses', size: const Size(393, 900), shots: false, server: s);
      expect(s.count('GET', '/expenses/stats/'), 1);
      s.stats = {...s.stats, 'total': 13};
      final gate = Completer<void>();
      s.statsHold = gate;
      await t.dragFrom(const Offset(200, 300), const Offset(0, 400));
      for (var i = 0; i < 40 && s.count('GET', '/expenses/stats/') < 2; i++) {
        await t.pump(const Duration(milliseconds: 100)); // the indicator settles, then onRefresh runs
      }
      await t.pump(const Duration(milliseconds: 100));
      expect(s.count('GET', '/expenses/stats/'), 2);
      expect(_text(t, 'expense-stat-total'), '—|Total Claims');
      gate.complete();
      await v.settle(t);
      expect(_text(t, 'expense-stat-total'), '13|Total Claims');
    });

    testWidgets('pull to refresh also works with no claims (short content)', (t) async {
      final s = v.T108Server()..emptyExpenses = true;
      await v.open(t, 'expenses', size: const Size(393, 3000), shots: false, server: s);
      expect(s.count('GET', '/expenses/stats/'), 1);
      await t.dragFrom(const Offset(200, 300), const Offset(0, 1000));
      for (var i = 0; i < 40 && s.count('GET', '/expenses/stats/') < 2; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await v.settle(t);
      expect(s.count('GET', '/expenses/stats/'), 2);
    });

    testWidgets(
        'changing the category filter filters the list only: the summary is not re-requested, and a note says so',
        (t) async {
      await v.open(t, 'expenses', size: const Size(393, 1400), shots: false);
      expect(_k('expense-stats-scope-note'), findsNothing);
      await v.tapText(t, 'Travel');
      expect(_s.where('GET', '/expenses/').last.query['category'], 'travel');
      expect(_s.count('GET', '/expenses/stats/'), 1);
      expect(_k('expense-stats-scope-note'), findsOneWidget);
      await t.drag(find.text('Travel').first, const Offset(500, 0)); // the chip row scrolled sideways
      await v.settle(t);
      await v.tapText(t, 'All Claims');
      expect(_k('expense-stats-scope-note'), findsNothing);
      expect(_s.count('GET', '/expenses/stats/'), 1);
    });

    testWidgets('a successful submit refreshes the summary; a cancelled form does not', (t) async {
      await v.open(t, 'expenses', size: const Size(393, 1400), shots: false);
      expect(_s.count('GET', '/expenses/stats/'), 1);
      await t.tap(find.byType(FloatingActionButton));
      await v.settle(t);
      while (t.takeException() != null) {} // the form's own layout is not under test (test font is wider than Poppins)
      Navigator.of(t.element(find.byType(ExpenseScreen)), rootNavigator: true).pop(false); // cancelled
      await v.settle(t);
      expect(_s.count('GET', '/expenses/stats/'), 1);
      await t.tap(find.byType(FloatingActionButton));
      await v.settle(t);
      while (t.takeException() != null) {}
      Navigator.of(t.element(find.byType(ExpenseScreen)), rootNavigator: true).pop(true); // saved
      await v.settle(t);
      expect(_s.count('GET', '/expenses/stats/'), 2);
    });

    test('formatting: web formatAmount for the total, en-IN with decimals for the sub-amounts', () {
      expect(formatExpenseTotal(0), '₹0');
      expect(formatExpenseTotal(999.5), '₹999.5'); // not rounded to ₹1000
      expect(formatExpenseTotal(500), '₹500');
      expect(formatExpenseTotal(1000), '₹1.0K');
      expect(formatExpenseTotal(12500), '₹12.5K');
      expect(formatExpenseTotal(100000), '₹1.0L');
      expect(formatExpenseTotal(152340.5), '₹1.5L');
    });

    test('model: null/odd values stay unknown, real zeros stay zero, strings are parsed', () {
      final a = ExpenseStats.fromJson({'total': 0, 'total_amount': 0.0});
      expect((a.total, a.totalAmount, a.pending), (0, 0.0, null));
      final b = ExpenseStats.fromJson({'total': '7', 'total_amount': '10.50', 'approved': 2.0, 'rejected': 1.5});
      expect((b.total, b.totalAmount, b.approved, b.rejected), (7, 10.5, 2, null));
    });

    for (final (w, sc) in [
      (320.0, 2.0),
      (320.0, 1.0),
      (360.0, 1.5),
      (393.0, 1.0),
      (430.0, 1.0),
      (600.0, 1.0),
      (1000.0, 1.0)
    ]) {
      testWidgets('cards at ${w.toInt()}dp @ $sc×: no overflow, amounts whole and unclipped', (t) async {
        await v.open(t, 'expenses',
            size: Size(w, 2600), scale: sc, shots: false, server: v.T108Server()..emptyExpenses = true);
        expect(t.takeException(), isNull);
        for (final k in ['total', 'pending', 'approved', 'rejected', 'amount']) {
          final r = t.getRect(_k('expense-stat-$k'));
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(w));
        }
        expect(_text(t, 'expense-stat-approved'), contains('₹96,000.75'));
      });
    }

    testWidgets('dark theme renders the cards and the error strip', (t) async {
      await v.open(t, 'expenses',
          size: const Size(393, 1400), shots: false, dark: true, server: v.T108Server()..statsStatus = 500);
      expect(t.takeException(), isNull);
      expect(_k('expense-stats-error'), findsOneWidget);
    });
  });
}
