import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'monthly_leave_management_test.dart' as h;

// Task 87 — HO-35. Settings › Leave Policy › Credit Rules used to show a
// seed list of "accrual rules" with Add / Edit / Delete that only changed
// local state (no backend model or endpoint) and reset on leaving. Now: the
// real "Credit Leave Balances" card and its Credit All Employees action stay;
// the unsupported editor is gone and an explicit "not available" notice
// replaces it. Nothing is credited in these tests (the confirmation is
// cancelled); the stand-in server records every call.
Future<void> openCreditRules(WidgetTester tester) async {
  await tester.tap(find.text('Credit Rules'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('real Credit All Employees action present and enabled', (tester) async {
    await h.pump(tester);
    await openCreditRules(tester);
    expect(find.text('Credit Leave Balances'), findsOneWidget);
    final btn = tester.widget<ButtonStyleButton>(find.ancestor(of: find.text('Credit All Employees'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
    expect(btn.onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Credit All Employees still asks to confirm; Cancel sends nothing', (tester) async {
    await h.pump(tester);
    await openCreditRules(tester);
    final before = h.server.log.length;
    await tester.tap(find.text('Credit All Employees'));
    await tester.pumpAndSettle();
    expect(find.text('Credit annual leave balances for all active employees for ${DateTime.now().year}?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.server.log.skip(before).where((l) => !l.startsWith('GET')), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unsupported accrual editor removed: no seed rules, no Add Rule, no edit/delete; notice shown', (tester) async {
    await h.pump(tester);
    await openCreditRules(tester);
    expect(find.byKey(const Key('accrual-rules-unavailable')), findsOneWidget);
    expect(find.text('Automatic accrual rules — not available'), findsOneWidget);
    expect(find.text('AUTOMATION COMING SOON'), findsNothing);
    expect(find.text('ACCRUAL RULES'), findsNothing);
    expect(find.text('Add Rule'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.textContaining('changes here reset'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('other Leave Policy tabs keep their FAB (Leave Types: Add Leave Type)', (tester) async {
    await h.pump(tester);
    expect(find.text('Add Leave Type'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
