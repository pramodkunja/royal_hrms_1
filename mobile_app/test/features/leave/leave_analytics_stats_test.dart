// Task 109: Leave → Analytics against web LeaveAnalytics.tsx and backend LeaveStatsView
// (GET /leave/stats/?year=). Stand-in API only; no live data.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/leave/data/models/leave_models.dart';
import 'package:mobile_app/features/leave/presentation/providers/leave_providers.dart';

import '../../visual/task109_visual_test.dart' as v;

Finder _k(String k) => find.byKey(Key(k));
T109 get _s => v.last;
typedef T109 = v.T109Server;

/// All the text inside a card, joined with "|" (value, label, sub).
String _card(String key) => [
      for (final e in find.descendant(of: _k(key), matching: find.byType(Text)).evaluate())
        (e.widget as Text).data ?? ''
    ].join('|');

Future<void> _pullToRefresh(WidgetTester t) async {
  await t.dragFrom(const Offset(200, 300), const Offset(0, 400));
  for (var i = 0; i < 40; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => v.clock = DateTime(2026, 11, 20, 10));

  group('mapping: every card shows its backend field', () {
    testWidgets('the five cards and their subtitles', (t) async {
      await v.openAnalytics(t, shots: false);
      expect(_card('leave-stat-total'), '14|Total Requests|This year (2026)');
      expect(_card('leave-stat-approved'), '9|Approved|This year (2026)');
      expect(_card('leave-stat-pending'), '3|Pending Approval|This year (2026)');
      expect(_card('leave-stat-rejected'), '2|Rejected|This year (2026)');
      expect(_card('leave-stat-lop'), '2.5|Loss of Pay (LOP)|2 requests in 2026');
    });

    testWidgets('one LOP request reads "1 request" (web pluralisation)', (t) async {
      await v.openAnalytics(t,
          shots: false, server: T109()..custom = {...T109().body(), 'lop_days': 1, 'lop_requests': 1});
      expect(_card('leave-stat-lop'), '1|Loss of Pay (LOP)|1 request in 2026');
    });

    testWidgets('balance breakdown and status distribution come from the same response', (t) async {
      await v.openAnalytics(t, shots: false);
      expect(find.text('Casual Leave'), findsOneWidget);
      expect(find.text('3 used / 12 total'), findsOneWidget);
      expect(find.text('9 remaining'), findsOneWidget);
      expect(find.text('10.5 used / 18 total'), findsOneWidget);
      expect(find.text('7.5 remaining'), findsOneWidget);
      // 14 total: approved 9 (64%), pending 3 (21%), rejected 2 (14%), cancelled 0 (0%)
      expect(find.text('9 (64%)'), findsOneWidget);
      expect(find.text('3 (21%)'), findsOneWidget);
      expect(find.text('2 (14%)'), findsOneWidget);
      expect(find.text('0 (0%)'), findsOneWidget);
    });

    testWidgets('the card labels and meanings are web’s', (t) async {
      await v.openAnalytics(t, shots: false);
      for (final (key, label) in [
        ('total', 'Total Requests'),
        ('approved', 'Approved'),
        ('pending', 'Pending Approval'),
        ('rejected', 'Rejected'),
        ('lop', 'Loss of Pay (LOP)'),
      ]) {
        expect(_card('leave-stat-$key').split('|')[1], label);
      }
    });
  });

  group('request', () {
    testWidgets('GET /leave/stats/ once, for the calendar year', (t) async {
      await v.openAnalytics(t, shots: false);
      expect(_s.requests, [
        {'year': 2026}
      ]);
    });

    testWidgets('the year follows the clock (New Year)', (t) async {
      v.clock = DateTime(2027, 1, 3);
      await v.openAnalytics(t, shots: false, server: T109()..custom = {...T109().body(), 'year': 2027});
      expect(_s.requests.single, {'year': 2027});
      expect(_card('leave-stat-total'), contains('This year (2027)'));
    });

    testWidgets('the period shown is the one the server answered for', (t) async {
      await v.openAnalytics(t, shots: false, server: T109()..custom = {...T109().body(), 'year': 2025});
      expect(_card('leave-stat-total'), '14|Total Requests|This year (2025)');
      expect(_card('leave-stat-lop'), '2.5|Loss of Pay (LOP)|2 requests in 2025');
    });
  });

  group('numbers: parsing, zero versus unavailable', () {
    test('model: ints, doubles and numeric strings parse; a real 0 stays 0', () {
      final m = LeaveStatsModel.fromJson({
        'total': '7',
        'pending': 2.0,
        'approved': 4,
        'rejected': 0,
        'cancelled': 1,
        'lop_days': '1.5',
        'lop_requests': 1,
        'year': 2026,
        'balances': <Object>[],
      });
      expect((m.total, m.pending, m.approved, m.rejected, m.cancelled), (7, 2, 4, 0, 1));
      expect((m.lopDays, m.lopRequests, m.year), (1.5, 1, 2026));
      expect(m.unavailable, isEmpty);
    });

    test('model: absent, null, non-numeric or fractional counts are unavailable, not 0', () {
      final m =
          LeaveStatsModel.fromJson({'total': null, 'pending': 'many', 'approved': 2.5, 'rejected': 0, 'lop_days': 'x'});
      expect(m.unavailable, {'total', 'pending', 'approved', 'cancelled', 'year', 'lop_days', 'lop_requests'});
      expect(m.rejected, 0);
      expect(m.unavailable.contains('rejected'), isFalse);
    });

    test('model: balances that are not a list are ignored without throwing', () {
      expect(LeaveStatsModel.fromJson({'total': 1, 'balances': 'oops'}).balances, isEmpty);
    });

    testWidgets('a response with real zeros shows 0 on every card (and 0 requests in 2026)', (t) async {
      await v.openAnalytics(t,
          shots: false,
          server: T109()
            ..custom = {
              'total': 0,
              'pending': 0,
              'approved': 0,
              'rejected': 0,
              'cancelled': 0,
              'lop_days': 0.0,
              'lop_requests': 0,
              'year': 2026,
              'balances': <Object>[],
            });
      expect(_card('leave-stat-total'), '0|Total Requests|This year (2026)');
      expect(_card('leave-stat-lop'), '0|Loss of Pay (LOP)|0 requests in 2026');
      expect(find.text('Request Status Distribution'), findsNothing); // nothing to distribute
      expect(find.textContaining('No leave balance data for 2026'), findsOneWidget); // employee, no balances
    });

    testWidgets('fields the server did not send as numbers show — and "Unavailable", never a made-up 0', (t) async {
      await v.openAnalytics(t,
          shots: false, server: T109()..custom = {'total': 5, 'pending': 'many', 'approved': 2, 'year': 2026});
      expect(_card('leave-stat-total'), '5|Total Requests|This year (2026)');
      expect(_card('leave-stat-pending'), '—|Pending Approval|Unavailable');
      expect(_card('leave-stat-rejected'), '—|Rejected|Unavailable');
      expect(_card('leave-stat-lop'), '—|Loss of Pay (LOP)|Unavailable');
      // the distribution shows what it knows and — for what it does not
      expect(find.text('2 (40%)'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('an unknown total hides the distribution instead of guessing it', (t) async {
      await v.openAnalytics(t,
          shots: false, server: T109()..custom = {'approved': 2, 'pending': 1, 'rejected': 0, 'cancelled': 0});
      expect(_card('leave-stat-total'), '—|Total Requests|Unavailable');
      expect(find.text('Request Status Distribution'), findsNothing);
    });
  });

  group('failures', () {
    testWidgets('a body that is not an object is an error, not zeros', (t) async {
      await v.openAnalytics(t, shots: false, server: T109()..custom = 'oops');
      expect(_k('leave-analytics-error'), findsOneWidget);
      expect(find.text('The leave statistics response was not in the expected format.'), findsOneWidget);
      expect(_k('leave-stat-total'), findsNothing);
    });

    for (final status in [404, 500]) {
      testWidgets('HTTP $status: an error with Retry, no cards, and Retry reloads', (t) async {
        final s = T109()..status = status;
        await v.openAnalytics(t, shots: false, server: s);
        expect(find.text('Failed to load leave analytics.'), findsOneWidget);
        expect(_k('leave-stat-total'), findsNothing); // no zero-filled cards
        s.status = 200;
        await t.tap(find.text('Retry'));
        await v.settle(t);
        expect(_k('leave-analytics-error'), findsNothing);
        expect(_card('leave-stat-total'), startsWith('14'));
        expect(s.count, 2);
      });
    }

    testWidgets('HTTP 403: Access denied with the server’s message, no Retry, no cards', (t) async {
      await v.openAnalytics(t, shots: false, server: T109()..status = 403);
      expect(find.text('Access denied'), findsOneWidget);
      expect(find.text('You do not have permission.'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(_k('leave-stat-total'), findsNothing);
      expect(_s.count, 1); // no retries on its own
    });

    testWidgets('a failed refresh never shows the previous numbers as current', (t) async {
      final s = T109();
      final c = await v.openAnalytics(t, shots: false, server: s);
      expect(_card('leave-stat-total'), startsWith('14'));
      s.status = 500;
      c.invalidate(leaveStatsProvider);
      await v.settle(t);
      expect(find.text('Failed to load leave analytics.'), findsOneWidget);
      expect(find.text('14'), findsNothing);
      expect(_k('leave-stat-total'), findsNothing);
    });
  });

  group('loading and refresh', () {
    testWidgets('loading shows placeholders (no numbers), then the figures', (t) async {
      final s = T109()..gates.add(Completer<void>());
      await v.openAnalytics(t, shots: false, server: s, settleFirst: false);
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('…'), findsNWidgets(5));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      s.gates.single.complete();
      await v.settle(t);
      expect(find.text('…'), findsNothing);
      expect(_card('leave-stat-total'), startsWith('14'));
    });

    testWidgets('pull to refresh re-requests, shows placeholders meanwhile, then the new figures', (t) async {
      final s = T109();
      await v.openAnalytics(t, shots: false, server: s, size: const Size(393, 900));
      expect(s.count, 1);
      final gate = Completer<void>();
      s.gates.add(Completer<void>()); // index 0 already used
      s.gates.add(gate); // the refresh
      s.bodies
        ..add(null)
        ..add({...s.body(), 'total': 15});
      await t.dragFrom(const Offset(200, 300), const Offset(0, 400));
      for (var i = 0; i < 40 && s.count < 2; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(s.count, 2);
      expect(_card('leave-stat-total'), startsWith('…')); // not the stale 14
      gate.complete();
      await v.settle(t);
      expect(_card('leave-stat-total'), startsWith('15'));
    });

    testWidgets('a leave action elsewhere (approve / cancel / apply invalidate the stats) refetches once', (t) async {
      final c = await v.openAnalytics(t, shots: false);
      c.invalidate(leaveStatsProvider);
      await v.settle(t);
      expect(_s.count, 2);
    });

    testWidgets('refresh re-reads the year, so a tab left open over New Year asks for the new one', (t) async {
      final s = T109();
      await v.openAnalytics(t, shots: false, server: s, size: const Size(393, 900));
      v.clock = DateTime(2027, 1, 1, 0, 5);
      s.custom = {...s.body(), 'year': 2027};
      await _pullToRefresh(t);
      expect(s.requests, [
        {'year': 2026},
        {'year': 2027}
      ]);
      expect(_card('leave-stat-total'), contains('This year (2027)'));
    });
  });

  group('rapid requests: an old response never overwrites a newer one', () {
    testWidgets('the older request answering last is ignored', (t) async {
      final s = T109();
      final first = Completer<void>();
      final second = Completer<void>();
      s.gates
        ..add(first)
        ..add(second);
      s.bodies
        ..add({...s.body(), 'total': 111})
        ..add({...s.body(), 'total': 222});
      final c = await v.openAnalytics(t, shots: false, server: s, settleFirst: false);
      await t.pump(const Duration(milliseconds: 50));
      c.invalidate(leaveStatsProvider); // a second request while the first is in flight
      await t.pump(const Duration(milliseconds: 50));
      await t.pump(const Duration(milliseconds: 50)); // the rebuild runs on the next frame
      expect(s.count, 2);
      second.complete(); // the newer one answers first…
      await v.settle(t);
      expect(_card('leave-stat-total'), startsWith('222'));
      first.complete(); // …then the older one
      await v.settle(t);
      expect(_card('leave-stat-total'), startsWith('222'));
      expect(find.text('111'), findsNothing);
    });

    testWidgets('three quick refreshes: one final state, the last response', (t) async {
      final s = T109();
      final c = await v.openAnalytics(t, shots: false, server: s);
      for (var i = 0; i < 3; i++) {
        s.custom = {...s.body(), 'total': 100 + i};
        c.invalidate(leaveStatsProvider);
        await t.pump(const Duration(milliseconds: 10));
      }
      await v.settle(t);
      expect(_card('leave-stat-total'), startsWith('102'));
    });
  });

  group('permission scope (web: employee = no leave.approve, no team, no branch)', () {
    testWidgets('an employee with no balances sees the HR hint; with balances sees the breakdown', (t) async {
      await v.openAnalytics(t, shots: false, server: T109()..custom = {...T109().body(), 'balances': <Object>[]});
      expect(find.textContaining('Contact HR to credit your annual leave'), findsOneWidget);
      await v.openAnalytics(t, shots: false);
      expect(find.text('Leave Balance Breakdown'), findsOneWidget);
      expect(find.textContaining('Contact HR'), findsNothing);
    });

    testWidgets('an approver (leave.approve) gets team figures and never the "contact HR" hint', (t) async {
      await v.openAnalytics(t,
          shots: false,
          as: v.u109(role: 'hr_admin', perms: ['leave.approve']),
          server: T109()
            ..custom = {
              'total': 120,
              'pending': 14,
              'approved': 90,
              'rejected': 10,
              'cancelled': 6,
              'lop_days': 31.5,
              'lop_requests': 12,
              'year': 2026,
              'balances': <Object>[],
            });
      expect(_card('leave-stat-total'), '120|Total Requests|This year (2026)');
      expect(_card('leave-stat-lop'), '31.5|Loss of Pay (LOP)|12 requests in 2026');
      expect(find.textContaining('Contact HR'), findsNothing);
      expect(find.text('Leave Balance Breakdown'), findsNothing);
    });

    testWidgets('a custom role without leave.approve is still an employee (decided by permissions, not the role name)',
        (t) async {
      await v.openAnalytics(t,
          shots: false,
          as: v.u109(role: 'custom_role'),
          server: T109()..custom = {...T109().body(), 'balances': <Object>[]});
      expect(find.textContaining('Contact HR'), findsOneWidget);
    });

    testWidgets('someone who manages a team or branch is not shown the employee hint', (t) async {
      for (final u in [v.u109(team: true), v.u109(branch: true)]) {
        await v.openAnalytics(t,
            shots: false, as: u, server: T109()..custom = {...T109().body(), 'balances': <Object>[]});
        expect(find.textContaining('Contact HR'), findsNothing);
      }
    });

    testWidgets('the cards use the same backend scope as before (no employee or team parameters are sent)', (t) async {
      await v.openAnalytics(t, shots: false);
      expect(_s.requests.single.keys, ['year']);
    });
  });

  group('layout', () {
    for (final (w, sc) in [
      (320.0, 2.0),
      (320.0, 1.0),
      (360.0, 1.5),
      (393.0, 1.0),
      (430.0, 1.0),
      (600.0, 1.0),
      (1000.0, 1.0),
    ]) {
      testWidgets('${w.toInt()}dp @ $sc×: every card whole, inside the width, no overflow', (t) async {
        await v.openAnalytics(t,
            shots: false,
            size: Size(w, 3200),
            scale: sc,
            server: T109()..custom = {...T109().body(), 'lop_days': 1234.5, 'total': 123456});
        expect(t.takeException(), isNull);
        for (final k in ['total', 'approved', 'pending', 'rejected', 'lop']) {
          final r = t.getRect(_k('leave-stat-$k'));
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(w));
        }
        expect(_card('leave-stat-lop'), startsWith('1234.5'));
      });
    }

    testWidgets('error and loading and denied states fit at 320dp @ 2×', (t) async {
      for (final s in [T109()..status = 500, T109()..status = 403]) {
        await v.openAnalytics(t, shots: false, size: const Size(320, 1400), scale: 2, server: s);
        expect(t.takeException(), isNull);
      }
      await v.openAnalytics(t,
          shots: false,
          size: const Size(320, 1400),
          scale: 2,
          server: T109()..gates.add(Completer<void>()),
          settleFirst: false);
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
    });

    testWidgets('dark theme renders the cards and the error state', (t) async {
      await v.openAnalytics(t, shots: false, dark: true);
      expect(t.takeException(), isNull);
      await v.openAnalytics(t, shots: false, dark: true, server: T109()..status = 500);
      expect(t.takeException(), isNull);
    });
  });
}
