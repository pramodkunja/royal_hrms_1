import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/features/leave/data/models/leave_models.dart';
import 'package:mobile_app/features/leave/presentation/widgets/leave_cancellation_panel.dart';

import 'secondary_tabs_harness.dart';

// Task 101 — Approvals → Leave Cancellations (web LeaveCancellationsSection.tsx)
// and the cancellation panel in the leave detail (LeaveCancellationPanel.tsx).

const _list = ApiConstants.leaveCancellations;
String _decide(String id) => ApiConstants.leaveCancellationDecision(id);

Map<String, dynamic> _row(String id, {String name = 'Asha Rao'}) => {
      'id': id,
      'employee_name': name,
      'employee_code': 'E-001',
      'leave_type': 'casual',
      'leave_type_display': 'Casual Leave',
      'start_date': '2026-09-05',
      'end_date': '2026-09-07',
      'total_days': '3.0',
      'status': 'approved',
      'cancellation_status': 'requested',
      'cancellation_reason': 'Plans changed',
      'can_decide_cancellation': true,
    };

FakeServer _server({List<Map<String, dynamic>>? rows}) {
  final s = FakeServer();
  s.on('GET $_list', (_) => ok(rows ?? [_row('r1')]));
  s.on('POST ${_decide('r1')}', (_) => ok(_row('r1')));
  return s;
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.text('OK'));
  await settle(tester);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('web strings and web date format', (tester) async {
    await pumpTab(tester, const LeaveCancellationsTab(), _server());
    expect(find.text('Leave cancellation requests'), findsOneWidget);
    expect(find.text('Approved leave the employee wants to cancel before it starts.'), findsOneWidget);
    expect(find.textContaining('Asha Rao'), findsOneWidget);
    expect(find.text('Casual Leave'), findsOneWidget);
    expect(find.text('5 Sept 2026 – 7 Sept 2026'), findsOneWidget);
    expect(find.text('3 day(s)'), findsOneWidget);
    expect(find.text('Reason: “Plans changed”'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Approve cancellation'), findsOneWidget);
  });

  testWidgets('loading, empty, error with retry', (tester) async {
    final s = _server()..holdKeys.add('GET $_list');
    await pumpTab(tester, const LeaveCancellationsTab(), s);
    expect(find.text('Loading…'), findsOneWidget);
    s.release();
    await settle(tester);

    await pumpTab(tester, const LeaveCancellationsTab(), _server(rows: []));
    expect(find.text('No cancellation requests waiting for you.'), findsOneWidget);

    final e = _server();
    var fails = true;
    e.on('GET $_list', (_) => fails ? refuse(500, 'Server exploded') : ok([_row('r1')]));
    await pumpTab(tester, const LeaveCancellationsTab(), e);
    expect(find.text('Server exploded'), findsOneWidget);
    fails = false;
    await tester.tap(find.text('Retry'));
    await settle(tester);
    expect(find.textContaining('Asha Rao'), findsOneWidget);
  });

  testWidgets('approve confirms with the web text, sends the exact payload, shows the web message', (tester) async {
    final s = _server();
    await pumpTab(tester, const LeaveCancellationsTab(), s);
    await tapKey(tester, 'leave-cancellation-row-approve-r1');
    expect(find.text("Cancel Asha Rao's approved leave and return the days?"), findsOneWidget);
    await _confirm(tester);
    expect(s.bodies('POST ${_decide('r1')}'), [
      {'action': 'approve', 'remarks': ''}
    ]);
    expect(find.text('Leave cancelled and balance restored.'), findsOneWidget);
  });

  testWidgets('reject needs a reason, sends it, shows the web message', (tester) async {
    final s = _server();
    await pumpTab(tester, const LeaveCancellationsTab(), s);
    await tapKey(tester, 'leave-cancellation-row-reject-r1');
    expect(find.text('Reason for rejecting *'), findsOneWidget);
    final submit = tester.widget<FilledButton>(byKey('leave-cancellation-row-confirm-reject-r1'));
    expect(submit.onPressed, isNull);
    await tester.enterText(byKey('leave-cancellation-row-remarks-r1'), 'Team is short that week');
    await settle(tester);
    await tapKey(tester, 'leave-cancellation-row-confirm-reject-r1');
    expect(s.bodies('POST ${_decide('r1')}'), [
      {'action': 'reject', 'remarks': 'Team is short that week'}
    ]);
    expect(find.text('Cancellation rejected.'), findsOneWidget);
  });

  testWidgets('server message is shown, fallback is the web text', (tester) async {
    final s = _server();
    s.on('POST ${_decide('r1')}', (_) => refuse(400, 'Leave already started.'));
    await pumpTab(tester, const LeaveCancellationsTab(), s);
    await tapKey(tester, 'leave-cancellation-row-approve-r1');
    await _confirm(tester);
    expect(find.text('Leave already started.'), findsOneWidget);

    s.on('POST ${_decide('r1')}', (_) => refuse(500));
    await tapKey(tester, 'leave-cancellation-row-approve-r1');
    await _confirm(tester);
    expect(find.text('Failed to save the decision.'), findsOneWidget);
  });

  testWidgets('double tap opens one confirm and sends exactly one request', (tester) async {
    final s = _server()..holdKeys.add('POST ${_decide('r1')}');
    await pumpTab(tester, const LeaveCancellationsTab(), s);
    await tester.ensureVisible(byKey('leave-cancellation-row-approve-r1'));
    await tester.tap(byKey('leave-cancellation-row-approve-r1'));
    await tester.tap(byKey('leave-cancellation-row-approve-r1'), warnIfMissed: false);
    await settle(tester);
    expect(find.text('OK'), findsOneWidget);
    await _confirm(tester);
    // While saving the buttons are disabled.
    expect(tester.widget<FilledButton>(byKey('leave-cancellation-row-approve-r1')).onPressed, isNull);
    await tester.tap(byKey('leave-cancellation-row-approve-r1'), warnIfMissed: false);
    await settle(tester);
    expect(s.count('POST ${_decide('r1')}'), 1);
    s.release();
    await settle(tester);
    expect(s.count('POST ${_decide('r1')}'), 1);
  });

  testWidgets('detail panel: success notice uses the web text and the payload is exact', (tester) async {
    final s = FakeServer();
    s.on('POST ${_decide('r1')}', (_) => ok(_row('r1')));
    await pumpTab(tester, LeaveCancellationPanel(request: LeaveRequestModel.fromJson(_row('r1'))), s);
    await tapKey(tester, 'leave-cancellation-approve');
    expect(s.bodies('POST ${_decide('r1')}'), [
      {'action': 'approve', 'remarks': ''}
    ]);
    expect(find.text('Cancellation approved — the days are back in the balance.'), findsOneWidget);

    s.on('POST ${_decide('r1')}', (_) => refuse(500));
    await tapKey(tester, 'leave-cancellation-approve');
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
  });

  for (final (name, size, scale) in responsiveCases) {
    testWidgets('responsive $name: no overflow', (tester) async {
      const long = 'Venkata Subramaniam Ramachandran Iyer-Krishnamurthy the Third';
      await pumpTab(tester, const LeaveCancellationsTab(), _server(rows: [_row('r1', name: long)]),
          size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'leave-cancellation-row-reject-r1');
      expect(tester.takeException(), isNull);
      expect(find.text('Reject cancellation'), findsOneWidget);

      await pumpTab(
          tester,
          SingleChildScrollView(child: LeaveCancellationPanel(request: LeaveRequestModel.fromJson(_row('r1')))),
          _server(),
          size: size,
          textScale: scale);
      expect(tester.takeException(), isNull);
    });
  }
}
