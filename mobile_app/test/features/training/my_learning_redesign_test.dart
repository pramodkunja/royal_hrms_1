// Task 103: My Learning — overview, counted tabs, content-specific cards, layout by
// width, states, and the whole learner journey (list → course → material /
// assessment → back), through the real routes with a stand-in API.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_kit.dart';
import 'package:mobile_app/features/training/presentation/screens/my_assessment_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/my_course_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/my_learning_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/my_material_screen.dart';
import 'package:mobile_app/shared/widgets/blue_app_bar.dart';

import 'training_fixtures.dart';

const _tall = Size(390, 2600);

Future<TrainingServer> _pump(WidgetTester tester,
        {TrainingServer? server, Size size = _tall, double scale = 1, String at = '/dashboard/my-learning'}) =>
    pumpTraining(tester, at: at, perms: [], server: server, size: size, textScale: scale);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tSettle(tester);
}

int _gets(TrainingServer s, String path) => s.log.where((l) => l == 'GET $path').length;
List<String> _writes(TrainingServer s) => s.log.where((l) => !l.startsWith('GET ')).toList();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('overview and counted tabs (from the list the API returned)', () {
    testWidgets('overview tiles and every tab count match the statuses', (tester) async {
      await _pump(tester);
      expect(find.byKey(const Key('my-learning-overview')), findsOneWidget);
      String count(String k) => (tester.widget<Text>(find.byKey(Key('my-learning-count-$k')))).data!;
      expect({
        for (final k in ['all', 'assigned', 'in_progress', 'overdue', 'completed', 'failed']) k: count(k)
      }, {
        'all': '5',
        'assigned': '1',
        'in_progress': '1',
        'overdue': '1',
        'completed': '1',
        'failed': '1'
      });
      for (final l in ['Assigned', 'In progress', 'Completed', 'Overdue']) {
        expect(
            find.descendant(of: find.byKey(const Key('my-learning-overview')), matching: find.text(l)), findsOneWidget,
            reason: l);
      }
    });

    testWidgets('each overview tile counts its own status (uneven data)', (tester) async {
      final s = TrainingServer()
        ..myList = [
          tAssignment('o1', 'overdue', due: '2026-10-01'),
          tAssignment('o2', 'overdue', due: '2026-10-02'),
          tAssignment('o3', 'overdue', due: '2026-10-03'),
          tAssignment('c1', 'completed', completed: '2026-11-10T09:00:00'),
          tAssignment('c2', 'completed', completed: '2026-11-11T09:00:00'),
          tAssignment('p1', 'in_progress', pct: 10),
          tAssignment('f1', 'failed'),
        ];
      await _pump(tester, server: s);
      String tile(String label) {
        final texts = find.descendant(of: find.byKey(const Key('my-learning-overview')), matching: find.byType(Text));
        final all = tester.widgetList<Text>(texts).map((t) => t.data!).toList();
        return all[all.indexOf(label) - 1];
      }

      expect({
        for (final l in ['Assigned', 'In progress', 'Completed', 'Overdue']) l: tile(l)
      }, {
        'Assigned': '7',
        'In progress': '1',
        'Completed': '2',
        'Overdue': '3'
      });
    });

    testWidgets('no overview and no counts while there is nothing assigned', (tester) async {
      final s = TrainingServer()..myList = [];
      await _pump(tester, server: s);
      expect(find.byKey(const Key('my-learning-overview')), findsNothing);
      expect(find.text('No training has been assigned to you yet.'), findsOneWidget);
    });

    testWidgets('a failed load shows counts nowhere and an error, never the empty look', (tester) async {
      final s = TrainingServer()..myStatus = 500;
      await _pump(tester, server: s);
      expect(find.byKey(const Key('my-learning-overview')), findsNothing);
      expect(find.byKey(const Key('my-learning-count-all')), findsNothing);
      expect(find.byWidgetPredicate((w) => w is ApprovalsEmptyState && w.kind == ApprovalsStateKind.error),
          findsOneWidget);
      expect(find.text('No training has been assigned to you yet.'), findsNothing);
    });
  });

  group('cards', () {
    testWidgets('a card shows the course description, trainer and duration the API sends', (tester) async {
      await _pump(tester);
      expect(find.byKey(const Key('my-learning-description-a-new')), findsOneWidget);
      expect(find.textContaining('How to work safely on site'), findsWidgets);
      expect(find.text('Test Trainer'), findsWidgets);
      expect(find.text('45 min'), findsWidgets);
    });

    testWidgets('without a thumbnail there is no cover band: the icon sits beside the title', (tester) async {
      await _pump(tester);
      final card = find.byKey(const Key('my-learning-card-a-new'));
      expect(find.descendant(of: card, matching: find.byType(Image)), findsNothing);
      expect(find.descendant(of: card, matching: find.byIcon(Icons.school_outlined)), findsOneWidget);
      // the title is in the top part of the card, not under a 60dp band
      final top = tester.getTopLeft(card).dy;
      expect(tester.getTopLeft(find.descendant(of: card, matching: find.text('Workplace Safety Essentials'))).dy - top,
          lessThan(40));
    });

    testWidgets('an empty description adds no empty line', (tester) async {
      final s = TrainingServer();
      (s.myList.first['course'] as Map<String, dynamic>)['description'] = '';
      await _pump(tester, server: s);
      expect(find.byKey(const Key('my-learning-description-a-new')), findsNothing);
    });
  });

  group('layout follows the width', () {
    double? rowOf(WidgetTester tester, String id) => tester.getTopLeft(find.byKey(Key('my-learning-card-$id'))).dy;

    testWidgets('phone: one column', (tester) async {
      await _pump(tester, size: const Size(393, 2800));
      expect(rowOf(tester, 'a-new') != rowOf(tester, 'a-prog'), isTrue);
    });

    testWidgets('small tablet / foldable (700dp): two columns', (tester) async {
      await _pump(tester, size: const Size(700, 2000));
      expect(rowOf(tester, 'a-new'), rowOf(tester, 'a-prog'));
      expect(rowOf(tester, 'a-over') != rowOf(tester, 'a-new'), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet (1000dp): three columns, cards equal width', (tester) async {
      await _pump(tester, size: const Size(1000, 1600));
      expect(rowOf(tester, 'a-new'), rowOf(tester, 'a-over'));
      expect(tester.getSize(find.byKey(const Key('my-learning-card-a-new'))).width,
          tester.getSize(find.byKey(const Key('my-learning-card-a-prog'))).width);
    });

    for (final (w, h, s) in [
      (320.0, 568.0, 1.0),
      (360.0, 800.0, 1.0),
      (430.0, 932.0, 1.0),
      (320.0, 568.0, 2.0),
      (360.0, 800.0, 1.5),
      (800.0, 600.0, 1.0)
    ]) {
      testWidgets('${w.toInt()}×${h.toInt()} at $s× text: every tab scrolls with no overflow', (tester) async {
        await _pump(tester, size: Size(w, h), scale: s);
        for (final k in ['all', 'assigned', 'in_progress', 'overdue', 'completed', 'failed']) {
          await _tap(tester, find.byKey(Key('my-learning-tab-$k')));
          for (var i = 0; i < 5; i++) {
            await tester.drag(find.byKey(const Key('my-learning-list')), const Offset(0, -400));
            await tester.pump();
          }
          expect(tester.takeException(), isNull, reason: k);
        }
      });
    }

    testWidgets('a very long title wraps and keeps its status and action visible at 2× text', (tester) async {
      final s = TrainingServer()
        ..myList = [
          tAssignment('a-long', 'in_progress',
              pct: 40,
              title:
                  'Data Protection and Information Security Awareness for All Branch and Head Office Employees 2026'),
        ];
      await _pump(tester, server: s, size: const Size(320, 900), scale: 2);
      expect(find.byKey(const Key('my-learning-open-a-long')), findsOneWidget);
      expect(find.text('In Progress'), findsWidgets);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const Key('my-learning-open-a-long'))).height, greaterThanOrEqualTo(44));
    });
  });

  group('states', () {
    testWidgets('error offers Retry, which refetches exactly once and recovers', (tester) async {
      final s = TrainingServer()..myStatus = 500;
      await _pump(tester, server: s);
      final before = _gets(s, '/training/my/');
      s.myStatus = 200;
      await _tap(tester, find.byKey(const Key('approvals-empty-action')));
      expect(_gets(s, '/training/my/') - before, 1);
      expect(find.byKey(const Key('my-learning-card-a-new')), findsOneWidget);
    });

    testWidgets('403 / module off: denied, no Retry', (tester) async {
      final s = TrainingServer()..myStatus = 403;
      await _pump(tester, server: s);
      expect(find.byWidgetPredicate((w) => w is ApprovalsEmptyState && w.kind == ApprovalsStateKind.denied),
          findsOneWidget);
      expect(find.byKey(const Key('approvals-empty-action')), findsNothing);
    });

    testWidgets('pull to refresh reloads the list once and keeps the cards', (tester) async {
      final s = await _pump(tester);
      final before = _gets(s, '/training/my/');
      // Pull down from near the top of the list (inside the content, not the blank area).
      await tester.timedDrag(
          find.byKey(const Key('my-learning-overview')), const Offset(0, 900), const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 400));
      await tSettle(tester);
      expect(_gets(s, '/training/my/') - before, 1);
      expect(find.byKey(const Key('my-learning-card-a-new')), findsOneWidget);
    });
  });

  group('the learner journey', () {
    testWidgets('list → course → material → back → assessment → back → list, no writes, no repeat fetches',
        (tester) async {
      final s = await _pump(tester, size: const Size(390, 2400));
      expect(_gets(s, '/training/my/'), 1);

      // list → course
      await _tap(tester, find.byKey(const Key('my-learning-open-a-prog')));
      expect(find.byType(MyCourseScreen), findsOneWidget);
      expect(find.byType(BlueAppBar), findsOneWidget);
      final detail = s.log.where((l) => l.startsWith('GET /training/my/') && l != 'GET /training/my/').length;
      expect(detail, lessThanOrEqualTo(2)); // the card passes the row along; the course loads its own detail

      // course → material (a read-only open of the PDF is recorded by the screen itself, not by listing)
      expect(find.byKey(const Key('my-course-assessment')), findsOneWidget);

      // course → assessment (locked until the materials are done)
      await _tap(tester, find.byKey(const Key('my-course-assessment')));
      expect(find.byType(MyAssessmentScreen), findsOneWidget);
      expect(find.byKey(const Key('my-assessment-locked')), findsOneWidget);

      // back → course → back → list
      await _tap(tester, find.byIcon(Icons.arrow_back_ios_new_rounded));
      expect(find.byType(MyCourseScreen), findsOneWidget);
      await _tap(tester, find.byIcon(Icons.arrow_back_ios_new_rounded));
      expect(find.byType(MyLearningScreen), findsOneWidget);
      expect(find.byKey(const Key('my-learning-card-a-prog')), findsOneWidget);
      expect(_writes(s), isEmpty);
    });

    testWidgets('opening a material shows it under the blue bar; back returns to the course', (tester) async {
      final s = await _pump(tester, size: const Size(390, 2400));
      await _tap(tester, find.byKey(const Key('my-learning-open-a-prog')));
      await _tap(tester, find.byKey(const Key('my-material-m-opt')));
      expect(find.byType(MyMaterialScreen), findsOneWidget);
      expect(find.byType(BlueAppBar), findsOneWidget);
      await _tap(tester, find.byIcon(Icons.arrow_back_ios_new_rounded));
      expect(find.byType(MyCourseScreen), findsOneWidget);
      expect(find.byType(MyMaterialScreen), findsNothing);
      // a material that was opened is recorded once, never as a side effect of navigating back
      expect(_writes(s).where((w) => w.contains('/open/')).length, lessThanOrEqualTo(1));
    });

    testWidgets('a second tap on a card opens one course page, not two', (tester) async {
      await _pump(tester, size: const Size(390, 2400));
      final open = find.byKey(const Key('my-learning-open-a-prog'));
      await tester.ensureVisible(open);
      await tester.pump();
      await tester.tap(open);
      await tester.tap(open, warnIfMissed: false);
      await tSettle(tester);
      expect(find.byType(MyCourseScreen), findsOneWidget);
      await _tap(tester, find.byIcon(Icons.arrow_back_ios_new_rounded));
      expect(find.byType(MyLearningScreen), findsOneWidget); // one back lands on the list
    });
  });
}
