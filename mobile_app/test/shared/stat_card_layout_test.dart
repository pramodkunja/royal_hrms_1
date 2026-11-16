import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/approvals/presentation/providers/approvals_providers.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_summary_cards.dart';
import 'package:mobile_app/features/branches/data/models/branch_model.dart';
import 'package:mobile_app/features/branches/presentation/widgets/branch_stats_row.dart';
import 'package:mobile_app/features/documents/domain/entities/document_entity.dart';
import 'package:mobile_app/features/documents/presentation/widgets/document_stats_row.dart';
import 'package:mobile_app/shared/widgets/stat_card.dart';

// Task 78: shared StatCard at large text sizes. Consumers (17 files):
//  - StatCardRow (fixed 88 px before): attendance, my attendance, holiday
//    calendar, email templates, departments, leave policy, assessments,
//    referrals, interview list, employees, employee attendance tab,
//    approvals summary (ApprovalsSummaryCards);
//  - GridView.count, 2 columns, childAspectRatio 2.5: expenses,
//    BranchStatsRow, DocumentStatsRow; 2.2: candidate review;
//  - Row + Expanded (natural height): announcements.
// Each layout at 360 dp with text ×1.0 / ×1.5 / ×2.0: no overflow, and the
// numeric value never cut off.

StatCard card(int i, {int? count, String? value, String? label}) => StatCard(
      icon: Icons.people_outline,
      count: value == null ? (count ?? 1234) : null,
      valueText: value,
      label: label ?? 'Pending approvals $i',
      color: Colors.blue,
    );

Future<void> pumpAt(WidgetTester tester, Widget child, double scale, {List<Override> overrides = const []}) async {
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ));
  await tester.pump();
}

/// No layout errors; every text of every StatCard lies inside its card
/// (nothing spills out or is clipped away); every value text shown in full.
void expectFits(WidgetTester tester, List<String> values) {
  expect(tester.takeException(), isNull);
  for (final c in find.byType(StatCard).evaluate()) {
    final cardRect = tester.getRect(find.byWidget(c.widget));
    for (final t in find.descendant(of: find.byWidget(c.widget), matching: find.byType(Text)).evaluate()) {
      final r = tester.getRect(find.byWidget(t.widget).first);
      expect(cardRect.inflate(0.5).contains(r.topLeft) && cardRect.inflate(0.5).contains(r.bottomRight), isTrue,
          reason: '"${(t.widget as Text).data}" $r outside its card $cardRect');
    }
  }
  for (final v in values) {
    final f = find.text(v);
    expect(f, findsWidgets, reason: v);
    for (final e in f.evaluate()) {
      final p = e.renderObject as RenderParagraph;
      expect(p.didExceedMaxLines, isFalse, reason: '$v cut off');
    }
  }
}

final branches = [
  for (var i = 0; i < 6; i++)
    BranchModel.fromJson({
      'id': i + 1,
      'branch_code': 'B$i',
      'branch_name': 'Branch $i',
      'address': '',
      'state': 1,
      'state_name': 'S',
      'city': 1,
      'city_name': 'C',
      'status': i.isEven ? 'active' : 'inactive',
      'is_headquarter': i == 0,
      'employees_count': 1200 + i,
      'geofencing_enabled': i.isEven,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    }),
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final (label, scale) in [('×1.0', 1.0), ('×1.5', 1.5), ('×2.0', 2.0)]) {
    group('360 dp, text $label', () {
      testWidgets('StatCardRow (12 screens): fits; value whole', (tester) async {
        await pumpAt(tester, StatCardRow(cards: [for (var i = 0; i < 4; i++) card(i)]), scale);
        expectFits(tester, ['1234']);
      });

      testWidgets('StatCardRow with a wide text value (e.g. ₹ amount)', (tester) async {
        await pumpAt(tester, StatCardRow(cards: [card(0, value: '₹12,34,567'), card(1)]), scale);
        expectFits(tester, ['₹12,34,567', '1234']);
      });

      for (final ratio in [2.5, 2.2]) {
        testWidgets('2-column grid, aspect $ratio (expenses / candidate review): fits', (tester) async {
          await pumpAt(
              tester,
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: ratio,
                children: [for (var i = 0; i < 4; i++) card(i)],
              ),
              scale);
          expectFits(tester, ['1234']);
        });
      }

      testWidgets('Row + Expanded (announcements): fits', (tester) async {
        await pumpAt(
            tester,
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [Expanded(child: card(0)), const SizedBox(width: 12), Expanded(child: card(1))]),
            ),
            scale);
        expectFits(tester, ['1234']);
      });

      testWidgets('BranchStatsRow: fits', (tester) async {
        await pumpAt(tester, BranchStatsRow(branches: branches), scale);
        expectFits(tester, const []);
      });

      testWidgets('DocumentStatsRow: fits; values whole', (tester) async {
        await pumpAt(tester,
            const DocumentStatsRow(stats: DocumentStatsEntity(total: 12345, policy: 234, form: 56, template: 7, other: 8)), scale);
        expectFits(tester, ['12345', '234']);
      });

      testWidgets('ApprovalsSummaryCards (Team Approvals): fits', (tester) async {
        await pumpAt(tester, const ApprovalsSummaryCards(), scale, overrides: [
          approvalsSummaryCountsProvider.overrideWithValue(const ApprovalsSummaryCounts(
            pendingTotal: 1234,
            leavePending: 456,
            expensePending: 78,
            correctionPending: 9,
            wfhPending: 10,
            separationPending: 11,
            payslipPending: 12,
          )),
        ]);
        expectFits(tester, ['1234', '456']);
      });
    });
  }

  group('normal text unchanged', () {
    testWidgets('StatCardRow keeps its 88 px height and one-line labels', (tester) async {
      await pumpAt(tester, StatCardRow(cards: [card(0, label: 'A rather long label that will not fit')]), 1.0);
      expect(tester.getSize(find.byType(StatCardRow)).height, 88);
      final label = tester.widget<Text>(find.text('A rather long label that will not fit'));
      expect(label.maxLines, 1);
    });

    testWidgets('larger text: the row grows (capped) and labels may wrap', (tester) async {
      await pumpAt(tester, StatCardRow(cards: [card(0, label: 'A rather long label that will not fit')]), 1.5);
      expect(tester.getSize(find.byType(StatCardRow)).height, 132);
      expect(tester.widget<Text>(find.text('A rather long label that will not fit')).maxLines, 2);
      await pumpAt(tester, StatCardRow(cards: [card(0)]), 3.0);
      expect(tester.getSize(find.byType(StatCardRow)).height, 160);
    });
  });
}
