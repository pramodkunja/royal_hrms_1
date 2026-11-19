import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/delegations_tab.dart';

import 'secondary_tabs_harness.dart';

// Task 101 — Approvals → Delegation against web DelegationsSection.tsx.
// "Today" is 13 Nov 2026.

const _list = ApiConstants.approvalsDelegations;
const _eligible = ApiConstants.approvalsDelegationsEligible;
String _revoke(String id) => ApiConstants.approvalsDelegationRevoke(id);

final _today = DateTime(2026, 11, 13);

Map<String, dynamic> _person(String id, String name, String code) =>
    {'id': id, 'name': name, 'employee_id': code, 'branch': 'North'};

Map<String, dynamic> _delegation(String id,
        {bool given = true, String name = 'Ravi Menon', bool canRevoke = true, String reason = 'Annual leave'}) =>
    {
      'id': id,
      'delegator': _person('u-me', 'Mira Manager', 'E-100'),
      'delegate': _person('u-ravi', name, 'E-002'),
      'start_date': '2026-11-10',
      'end_date': '2026-11-20',
      'workflows': ['leave', 'attendance'],
      'reason': reason,
      'revoked': false,
      'can_revoke': canRevoke,
      'given': given,
      'received': !given,
    };

FakeServer _server({List<Map<String, dynamic>>? rows}) {
  final s = FakeServer();
  s.on('GET $_list', (_) => ok(rows ?? [_delegation('d1')]));
  s.on('GET $_eligible', (_) => ok([_person('u-asha', 'Asha Rao', 'E-001'), _person('u-ravi', 'Ravi Menon', 'E-002')]));
  s.on('POST $_list', (_) => ok(_delegation('d2')));
  s.on('POST ${_revoke('d1')}', (_) => ok({}));
  return s;
}

DateTime? _next;

List<Override> get _overrides => [
      approvalsTodayProvider.overrideWithValue(() => _today),
      delegationDatePickerProvider.overrideWithValue((context, initial, first, last) async => _next),
    ];

Future<void> _pump(WidgetTester tester, FakeServer s, {Size size = const Size(420, 2400), double scale = 1}) =>
    pumpTab(tester, const DelegationsTab(), s, size: size, textScale: scale, overrides: _overrides);

Future<void> _fillForm(WidgetTester tester) async {
  await tapKey(tester, 'delegation-delegate');
  await tester.tap(find.text('Asha Rao (E-001)').last);
  await settle(tester);
  _next = DateTime(2026, 11, 25);
  await tapKey(tester, 'delegation-end');
  await tester.enterText(byKey('delegation-reason'), 'Conference');
  await settle(tester);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('web strings, lists and badges', (tester) async {
    await _pump(
        tester, _server(rows: [_delegation('d1'), _delegation('d3', given: false, name: 'Sunil', canRevoke: false)]));
    expect(find.text('Delegate my approvals'), findsOneWidget);
    expect(find.text('Delegate *'), findsOneWidget);
    expect(find.text('From *'), findsOneWidget);
    expect(find.text('To *'), findsOneWidget);
    expect(find.text('Leave requests'), findsOneWidget);
    expect(find.text('Attendance requests'), findsOneWidget);
    expect(find.text('Delegate'), findsOneWidget);
    expect(find.text('Delegated by me'), findsOneWidget);
    expect(find.text('Delegated to me'), findsOneWidget);
    expect(find.text('10 Nov 2026 – 20 Nov 2026'), findsNWidgets(2));
    expect(find.text('Attendance'), findsNWidgets(2));
    expect(find.text('Ravi Menon covers for you'), findsOneWidget);
    expect(find.text('Active'), findsNWidgets(2));
    expect(find.text('Revoke'), findsOneWidget);
  });

  testWidgets('loading and empty lists', (tester) async {
    final s = _server()..holdKeys.add('GET $_list');
    await _pump(tester, s);
    expect(find.text('Loading delegations…'), findsOneWidget);
    s.release();
    await settle(tester);

    await _pump(tester, _server(rows: []));
    expect(find.text("You haven't delegated your approvals."), findsOneWidget);
    expect(find.text('No one has delegated approvals to you.'), findsOneWidget);
  });

  testWidgets('list error shows a banner and Retry', (tester) async {
    final s = _server();
    var fails = true;
    s.on('GET $_list', (_) => fails ? refuse(500, 'Server exploded') : ok([_delegation('d1')]));
    await _pump(tester, s);
    expect(find.text('Server exploded'), findsOneWidget);
    fails = false;
    await tester.tap(find.text('Retry'));
    await settle(tester);
    expect(find.text('Delegated by me'), findsOneWidget);
  });

  testWidgets('create sends the exact payload and resets the form', (tester) async {
    final s = _server();
    await _pump(tester, s);
    await _fillForm(tester);
    await tapKey(tester, 'delegation-create');
    expect(s.bodies('POST $_list'), [
      {
        'delegate': 'u-asha',
        'start_date': '2026-11-13',
        'end_date': '2026-11-25',
        'workflows': ['leave'],
        'reason': 'Conference',
      }
    ]);
    expect(find.text('Delegation created. The delegate has been notified.'), findsOneWidget);
  });

  testWidgets('validation text shows after the first attempt and sends nothing', (tester) async {
    final s = _server();
    await _pump(tester, s);
    await tapKey(tester, 'delegation-create');
    expect(find.text('Choose who approves in your place.'), findsOneWidget);
    expect(find.text('Choose an end date.'), findsOneWidget);
    expect(s.count('POST $_list'), 0);
  });

  testWidgets('server message is shown, fallback is the web text', (tester) async {
    final s = _server();
    s.on('POST $_list', (_) => refuse(400, 'You already have a delegation for those dates.'));
    await _pump(tester, s);
    await _fillForm(tester);
    await tapKey(tester, 'delegation-create');
    expect(find.text('You already have a delegation for those dates.'), findsOneWidget);

    s.on('POST $_list', (_) => refuse(500));
    await tapKey(tester, 'delegation-create');
    expect(find.text('Failed to create the delegation.'), findsOneWidget);
  });

  testWidgets('double tap on Delegate sends exactly one request and shows Saving…', (tester) async {
    final s = _server()..holdKeys.add('POST $_list');
    await _pump(tester, s);
    await _fillForm(tester);
    await tester.ensureVisible(byKey('delegation-create'));
    await tester.pump();
    await tester.tap(byKey('delegation-create'));
    await tester.tap(byKey('delegation-create'), warnIfMissed: false);
    await settle(tester);
    expect(find.text('Saving…'), findsOneWidget);
    expect(s.count('POST $_list'), 1);
    s.release();
    await settle(tester);
    expect(s.count('POST $_list'), 1);
  });

  testWidgets('revoke confirms with the web text, posts once, shows the web message', (tester) async {
    final s = _server();
    await _pump(tester, s);
    await tapKey(tester, 'delegation-revoke-d1');
    expect(find.text('Revoke the delegation to Ravi Menon?'), findsOneWidget);
    await tester.tap(byKey('delegation-revoke-confirm'));
    await settle(tester);
    expect(s.count('POST ${_revoke('d1')}'), 1);
    expect(find.text('Delegation revoked.'), findsOneWidget);

    s.on('POST ${_revoke('d1')}', (_) => refuse(500));
    await tapKey(tester, 'delegation-revoke-d1');
    await tester.tap(byKey('delegation-revoke-confirm'));
    await settle(tester);
    expect(find.text('Failed to revoke the delegation.'), findsOneWidget);
  });

  testWidgets('double tap on Revoke opens one confirm', (tester) async {
    final s = _server();
    await _pump(tester, s);
    await tester.ensureVisible(byKey('delegation-revoke-d1'));
    await tester.pump();
    await tester.tap(byKey('delegation-revoke-d1'));
    await tester.tap(byKey('delegation-revoke-d1'), warnIfMissed: false);
    await settle(tester);
    expect(byKey('delegation-revoke-confirm'), findsOneWidget);
  });

  for (final (name, size, scale) in responsiveCases) {
    testWidgets('responsive $name: no overflow with long names', (tester) async {
      const long = 'Venkata Subramaniam Ramachandran Iyer-Krishnamurthy the Third';
      final s = _server(rows: [_delegation('d1', name: long, reason: 'A very long reason that keeps going and going')]);
      s.on('GET $_eligible', (_) => ok([_person('u-asha', long, 'E-001')]));
      await _pump(tester, s, size: size, scale: scale);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(byKey('delegation-create'), 200, scrollable: find.byType(Scrollable).first);
      await tapKey(tester, 'delegation-create');
      expect(tester.takeException(), isNull);
    });
  }
}
