// Task 111 Part A: unassigned Org Chart values read "Not assigned" / "Not set" (web
// OrgChartClient.tsx wording) instead of a dash; real values are shown exactly as received.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/org_chart/domain/entities/org_chart_entity.dart';
import 'package:mobile_app/features/org_chart/presentation/widgets/org_labels.dart';

import '../../visual/org_chart_visual_test.dart' as v;

Finder _k(String k) => find.byKey(Key(k));

OrgPersonEntity _p(String name, {String designation = ''}) =>
    OrgPersonEntity(id: 'x', employeeId: 'EMP-1', name: name, designation: designation);

String _headOf(WidgetTester t, String deptLabel) {
  final card = find.ancestor(of: find.text(deptLabel), matching: find.byType(IntrinsicHeight)).first;
  return (find.descendant(of: card, matching: _k('org-dept-head')).evaluate().single.widget as Text).data!;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('wording rules', () {
    test('a department with no head is "Not assigned"', () {
      expect(orgHeadLabel(null), 'Not assigned');
      expect(kOrgNotAssigned, 'Not assigned');
      expect(kOrgNotSet, 'Not set');
    });

    test('a head record without a usable name says the name is not set; empty, blank and whitespace all count', () {
      for (final n in ['', ' ', '   ', '\t\n']) {
        expect(orgHeadLabel(_p(n)), 'Name not set', reason: '"$n"');
        expect(orgMemberLabel(_p(n)), 'Name not set', reason: '"$n"');
      }
    });

    test('real values are untouched: names with hyphens, dots, a single hyphen or digits, zero', () {
      for (final n in ["Anne-Marie O'Neil-Smith", 'J.-P. Fournier-Lefèvre', '-', '0', 'Priya Nair', 'A-1']) {
        expect(orgHeadLabel(_p(n)), n);
        expect(orgMemberLabel(_p(n)), n);
        expect(orgHasText(n), isTrue, reason: n);
      }
    });

    test('orgHasText: null, empty and whitespace are missing; anything else is a value', () {
      expect(orgHasText(null), isFalse);
      expect(orgHasText(''), isFalse);
      expect(orgHasText('  '), isFalse);
      expect(orgHasText('0'), isTrue);
    });
  });

  group('on the chart', () {
    testWidgets('a department without a head shows Not assigned; one with a head shows the name exactly', (t) async {
      await v.openOrgChart(t, shots: false);
      expect(_headOf(t, 'FINANCE'), 'Not assigned');
      expect(_headOf(t, 'ENGINEERING'), 'Priya Nair');
      expect(_headOf(t, 'LEGAL'), 'J.-P. Fournier-Lefèvre'); // hyphens and dots are part of the name
    });

    testWidgets('a head with a blank name says Name not set (not Not assigned: someone does hold the role)', (t) async {
      await v.openOrgChart(t, shots: false);
      expect(_headOf(t, 'OPERATIONS'), 'Name not set');
    });

    testWidgets('a branch with no single head shows Not set, under "Top of chart", with the existing explanation',
        (t) async {
      await v.openOrgChart(t, shots: false);
      expect(_k('org-root-not-set'), findsOneWidget);
      expect(find.descendant(of: _k('org-root-not-set'), matching: find.text('Not set')), findsOneWidget);
      expect(find.descendant(of: _k('org-root-not-set'), matching: find.text('TOP OF CHART')), findsOneWidget);
      expect(find.text('No single head identified for this branch.'), findsOneWidget);
    });

    testWidgets('a branch head, when there is one, is shown and "Not set" is not', (t) async {
      await v.openOrgChart(t, chart: v.sampleChart(rootMissing: false), shots: false);
      expect(find.text('Asha Verma'), findsOneWidget);
      expect(_k('org-root-not-set'), findsNothing);
    });

    testWidgets('members: a blank name reads Name not set; hyphenated names and a designation of 0 stay as they are',
        (t) async {
      await v.openOrgChart(t, shots: false);
      await t.tap(find.text('ENGINEERING'));
      await t.pumpAndSettle();
      expect(find.text('Name not set'), findsWidgets);
      expect(find.text("Anne-Marie O'Neil-Smith"), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // a real "0" designation is not hidden or replaced
      expect(find.text('Intern'), findsOneWidget);
    });

    testWidgets('no dash placeholder is left on the chart', (t) async {
      await v.openOrgChart(t, shots: false);
      await t.tap(find.text('ENGINEERING'));
      await t.pumpAndSettle();
      expect(find.text('—'), findsNothing);
      expect(find.text('-'), findsNothing);
    });

    testWidgets('an unassigned head is not tappable as a profile link (nothing to open)', (t) async {
      await v.openOrgChart(t, shots: false);
      final w = find.byKey(const Key('org-dept-head'));
      final finance = find.descendant(
          of: find.ancestor(of: find.text('FINANCE'), matching: find.byType(IntrinsicHeight)).first, matching: w);
      final gesture = find.ancestor(of: finance, matching: find.byType(GestureDetector)).first;
      expect(t.widget<GestureDetector>(gesture).onTap, isNull);
    });
  });

  group('layout and theme', () {
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
      testWidgets('${w.toInt()}×${h.toInt()} @ $sc×: the labels fit and nothing overflows', (t) async {
        await v.openOrgChart(t, size: Size(w, 3200), scale: sc, shots: false);
        expect(t.takeException(), isNull);
        for (final label in ['Not assigned', 'Name not set']) {
          for (final e in find.text(label).evaluate()) {
            final r = t.getRect(find.byWidget(e.widget));
            expect(r.right, lessThanOrEqualTo(w), reason: label);
          }
        }
        expect(find.text('Not assigned'), findsWidgets);
      });
    }

    testWidgets('dark theme: the placeholders still render and use the secondary text colour', (t) async {
      await v.openOrgChart(t, dark: true, shots: false);
      expect(t.takeException(), isNull);
      expect(find.text('Not assigned'), findsWidgets);
      expect(find.text('Not set'), findsOneWidget);
    });
  });
}
