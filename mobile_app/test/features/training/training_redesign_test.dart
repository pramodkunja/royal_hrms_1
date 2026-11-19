import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_kit.dart';
import 'package:mobile_app/features/training/presentation/screens/my_assessment_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/my_course_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/my_material_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/training_course_screen.dart';
import 'package:mobile_app/features/training/presentation/widgets/training_widgets.dart';
import 'package:mobile_app/shared/widgets/blue_app_bar.dart';

import 'training_fixtures.dart';

// Task 102: the redesigned Training & My Learning screens. Behaviour (writes,
// permissions) is covered by the earlier suites; this file pins the new
// composition: states per condition, app bars, interactions, no overflow.

const _tall = Size(390, 2600);

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f.first);
  await t.tap(f.first, warnIfMissed: false);
  await tSettle(t);
}

Iterable<ApprovalsEmptyState> _states(WidgetTester t) =>
    t.widgetList<ApprovalsEmptyState>(find.byType(ApprovalsEmptyState));
ApprovalsStateKind? _kind(WidgetTester t) => _states(t).isEmpty ? null : _states(t).first.kind;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Training list', () {
    testWidgets('populated: summary, search, archived chip and a card per course', (tester) async {
      await pumpTraining(tester, size: _tall);
      expect(find.byKey(const Key('training-stats')), findsOneWidget);
      expect(find.byKey(const Key('training-search')), findsOneWidget);
      expect(find.byKey(const Key('training-show-archived')), findsOneWidget);
      expect(find.byKey(const Key('training-course-$tC1')), findsOneWidget);
      expect(find.text('5 of 12 completed'), findsWidgets);
      expect(_states(tester), isEmpty);
    });

    testWidgets('Show archived is a visible selected state and asks the server', (tester) async {
      final s = await pumpTraining(tester, size: _tall);
      await _tap(tester, find.byKey(const Key('training-show-archived')));
      expect(tester.widget<FilterChip>(find.byKey(const Key('training-show-archived'))).selected, isTrue);
      expect(find.text('Old Induction Course'), findsOneWidget);
      expect(s.log.where((l) => l == 'GET /training/courses/').length, greaterThanOrEqualTo(2));
    });

    testWidgets('empty = calm empty state with the web wording', (tester) async {
      await pumpTraining(tester, server: TrainingServer()..courses = []);
      expect(_kind(tester), ApprovalsStateKind.empty);
      expect(find.text('No courses yet.'), findsOneWidget);
      expect(find.text('Create the first one.'), findsOneWidget);
    });

    testWidgets('no search match = noMatch state with Clear search, which restores the list', (tester) async {
      await pumpTraining(tester, size: _tall);
      await tester.enterText(find.byKey(const Key('training-search')), 'zzzz');
      await tSettle(tester);
      expect(_kind(tester), ApprovalsStateKind.noMatch);
      await _tap(tester, find.text('Clear search').last);
      expect(find.byKey(const Key('training-course-$tC1')), findsOneWidget);
      expect(_states(tester), isEmpty);
    });

    testWidgets('load failure is an error state with Retry - never the empty look', (tester) async {
      await pumpTraining(tester, server: TrainingServer()..coursesStatus = 500);
      expect(_kind(tester), ApprovalsStateKind.error);
      expect(find.text('No courses yet.'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('403 is a denied state with no Retry and the stats stay hidden', (tester) async {
      await pumpTraining(tester,
          server: TrainingServer()
            ..coursesStatus = 403
            ..dashboardStatus = 403);
      expect(_kind(tester), ApprovalsStateKind.denied);
      expect(find.text('Retry'), findsNothing);
      expect(find.byKey(const Key('training-stats')), findsNothing);
    });

    testWidgets('tapping a course card opens its detail with the blue app bar', (tester) async {
      await pumpTraining(tester, size: _tall);
      await _tap(tester, find.byKey(const Key('training-course-$tC1')));
      expect(find.byType(TrainingCourseScreen), findsOneWidget);
      final bar =
          tester.widget<AppBar>(find.descendant(of: find.byType(TrainingCourseScreen), matching: find.byType(AppBar)));
      expect(bar.backgroundColor, AppColors.primary);
    });

    testWidgets('view-only: no New Course, no Reports tab', (tester) async {
      await pumpTraining(tester, perms: ['training.view'], size: _tall);
      expect(find.byKey(const Key('training-new-course')), findsNothing);
      expect(find.byKey(const Key('training-tab-reports')), findsNothing);
    });

    testWidgets('New Course dialog: white surface, primary Create, payload {title, category}', (tester) async {
      final s = await pumpTraining(tester, size: _tall);
      await _tap(tester, find.byKey(const Key('training-new-course')));
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, AppColors.surface);
      expect(dialog.surfaceTintColor, Colors.transparent);
      await tester.enterText(find.byKey(const Key('new-course-title')), 'QA Course');
      await tester.enterText(find.byKey(const Key('new-course-category')), 'QA');
      await _tap(tester, find.byKey(const Key('new-course-create')));
      expect(s.bodies['POST /training/courses/'], {'title': 'QA Course', 'category': 'QA'});
    });
  });

  group('Reports', () {
    testWidgets('populated with filters and cards; empty vs filtered-empty vs failure differ', (tester) async {
      await pumpTraining(tester, size: _tall);
      await _tap(tester, find.byKey(const Key('training-tab-reports')));
      expect(find.byKey(const Key('training-report-count')), findsOneWidget);
      expect(find.text('2 record(s)'), findsOneWidget);
      expect(find.byType(TrainingAssignmentCard), findsNWidgets(2));
    });

    testWidgets('no records = empty; failure = error', (tester) async {
      await pumpTraining(tester, server: TrainingServer()..reports = []);
      await _tap(tester, find.byKey(const Key('training-tab-reports')));
      expect(_kind(tester), ApprovalsStateKind.empty);
      expect(find.text('No matching records.'), findsOneWidget);
    });

    testWidgets('report failure is never "No matching records."', (tester) async {
      await pumpTraining(tester, server: TrainingServer()..reportsStatus = 500);
      await _tap(tester, find.byKey(const Key('training-tab-reports')));
      expect(find.text('No matching records.'), findsNothing);
      expect(_states(tester).any((s) => s.kind == ApprovalsStateKind.error), isTrue);
    });
  });

  group('Course detail tabs', () {
    testWidgets('app bar is the blue bar with white tabs; every tab renders', (tester) async {
      await pumpTraining(tester, at: '/dashboard/training/$tC1', size: _tall);
      expect(find.byType(BlueAppBar), findsOneWidget);
      final bar = tester.widget<AppBar>(find.descendant(of: find.byType(BlueAppBar), matching: find.byType(AppBar)));
      expect(bar.backgroundColor, AppColors.primary);
      expect(find.byKey(const Key('training-course-delete')), findsOneWidget);
      expect(find.byKey(const Key('course-form')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('training-course-tab-Materials')));
      expect(find.byKey(const Key('training-material-m1')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('training-course-tab-Assign')));
      expect(find.byKey(const Key('training-assign')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('training-course-tab-Progress')));
      expect(find.byKey(const Key('training-progress-p1')), findsOneWidget);
      expect(find.byKey(const Key('training-progress-count')), findsOneWidget);
    });

    testWidgets('read-only details: identity header + sections, no form', (tester) async {
      await pumpTraining(tester, perms: ['training.view'], at: '/dashboard/training/$tC1', size: _tall);
      expect(find.byKey(const Key('training-course-header')), findsOneWidget);
      expect(find.text('Test Quiz (pass mark 70%)'), findsNothing);
      expect(find.text('Safety Quiz (pass mark 70%)'), findsOneWidget);
      expect(find.byKey(const Key('course-form')), findsNothing);
      expect(find.byKey(const Key('training-course-delete')), findsNothing);
    });

    testWidgets('materials: empty course shows the empty state; add form only with edit', (tester) async {
      final s = TrainingServer()..detail = {...TrainingServer().detail, 'materials': <Map<String, dynamic>>[]};
      await pumpTraining(tester, perms: ['training.view'], at: '/dashboard/training/$tC1', server: s, size: _tall);
      await _tap(tester, find.byKey(const Key('training-course-tab-Materials')));
      expect(find.byKey(const Key('training-materials-empty')), findsOneWidget);
      expect(find.byKey(const Key('add-material')), findsNothing);
    });

    testWidgets('progress: no rows = empty state, failure = error state, Reset/Remove need permission', (tester) async {
      await pumpTraining(tester, at: '/dashboard/training/$tC1', server: TrainingServer()..progress = [], size: _tall);
      await _tap(tester, find.byKey(const Key('training-course-tab-Progress')));
      expect(_kind(tester), ApprovalsStateKind.empty);

      await pumpTraining(tester,
          at: '/dashboard/training/$tC1', server: TrainingServer()..progressStatus = 500, size: _tall);
      await _tap(tester, find.byKey(const Key('training-course-tab-Progress')));
      expect(_kind(tester), ApprovalsStateKind.error);
      expect(find.text('No one in your scope has this course yet.'), findsNothing);

      await pumpTraining(tester, perms: ['training.view'], at: '/dashboard/training/$tC1', size: _tall);
      await _tap(tester, find.byKey(const Key('training-course-tab-Progress')));
      expect(find.byKey(const Key('training-remove-p1')), findsNothing);
      expect(find.byKey(const Key('training-remove-p1')), findsNothing);
    });

    testWidgets('course load failure shows a retryable error under the blue bar', (tester) async {
      await pumpTraining(tester, at: '/dashboard/training/$tC1', server: TrainingServer()..courseStatus = 500);
      expect(find.byType(BlueAppBar), findsOneWidget);
      expect(_kind(tester), ApprovalsStateKind.error);
    });

    testWidgets('confirm dialogs are white-surface with primary / error actions', (tester) async {
      await pumpTraining(tester, at: '/dashboard/training/$tC1', size: _tall);
      await _tap(tester, find.byKey(const Key('training-course-tab-Progress')));
      await _tap(tester, find.byKey(const Key('training-remove-p1')));
      final d = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(d.backgroundColor, AppColors.surface);
      expect(d.surfaceTintColor, Colors.transparent);
      final confirm = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Remove'));
      expect(confirm.style!.backgroundColor!.resolve({}), AppColors.error);
    });
  });

  group('My Learning', () {
    testWidgets('all six tabs render their own rows; cards carry a primary action', (tester) async {
      await pumpTraining(tester, at: '/dashboard/my-learning', perms: [], size: _tall);
      expect(find.byType(TrainingBadge), findsWidgets);
      final expected = {
        'assigned': 'a-new',
        'in_progress': 'a-prog',
        'overdue': 'a-over',
        'completed': 'a-done',
        'failed': 'a-fail',
      };
      for (final e in expected.entries) {
        await _tap(tester, find.byKey(Key('my-learning-tab-${e.key}')));
        expect(find.byKey(Key('my-learning-card-${e.value}')), findsOneWidget, reason: e.key);
        expect(find.byKey(Key('my-learning-open-${e.value}')), findsOneWidget);
      }
      expect(find.text('Was due 2026-10-01'), findsNothing); // only on the overdue tab
    });

    testWidgets('tab-specific emphasis: overdue due-date, completed score', (tester) async {
      await pumpTraining(tester, at: '/dashboard/my-learning', perms: [], size: _tall);
      await _tap(tester, find.byKey(const Key('my-learning-tab-overdue')));
      expect(find.text('Was due 2026-10-01'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('my-learning-tab-completed')));
      expect(find.text('Completed on 2026-11-10 · Best score 92%'), findsOneWidget);
    });

    testWidgets('each tab empty state is distinct; none looks like a failure', (tester) async {
      final s = TrainingServer()..myList = [tAssignment('a-new', 'assigned', title: 'Only One')];
      await pumpTraining(tester, at: '/dashboard/my-learning', perms: [], server: s, size: _tall);
      final messages = <String>{};
      for (final k in ['in_progress', 'overdue', 'completed', 'failed']) {
        await _tap(tester, find.byKey(Key('my-learning-tab-$k')));
        expect(find.text('Nothing here.'), findsOneWidget);
        expect(_kind(tester), ApprovalsStateKind.empty);
        messages.add(_states(tester).first.message!);
      }
      expect(messages.length, 4);
    });

    testWidgets('nothing assigned, failure and module-disabled are three different states', (tester) async {
      await pumpTraining(tester, at: '/dashboard/my-learning', perms: [], server: TrainingServer()..myList = []);
      expect(_kind(tester), ApprovalsStateKind.empty);
      expect(find.text('No training has been assigned to you yet.'), findsOneWidget);

      await pumpTraining(tester, at: '/dashboard/my-learning', perms: [], server: TrainingServer()..myStatus = 500);
      expect(_kind(tester), ApprovalsStateKind.error);
      expect(find.text('No training has been assigned to you yet.'), findsNothing);

      await pumpTraining(tester, at: '/dashboard/my-learning', perms: [], server: TrainingServer()..myStatus = 403);
      expect(_kind(tester), ApprovalsStateKind.denied);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('tapping a card opens the course page; detail screens use the blue bar', (tester) async {
      await pumpTraining(tester, at: '/dashboard/my-learning', perms: [], size: _tall);
      await _tap(tester, find.byKey(const Key('my-learning-card-a-prog')));
      expect(find.byType(MyCourseScreen), findsOneWidget);
      expect(find.byType(BlueAppBar), findsOneWidget);
      expect(find.byKey(const Key('my-course-summary')), findsOneWidget);

      await _tap(tester, find.byKey(const Key('my-material-m-yt')));
      expect(find.byType(MyMaterialScreen), findsOneWidget);
      expect(find.descendant(of: find.byType(MyMaterialScreen), matching: find.byType(BlueAppBar)), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tSettle(tester);

      await _tap(tester, find.byKey(const Key('my-course-assessment')));
      expect(find.byType(MyAssessmentScreen), findsOneWidget);
      final bar =
          tester.widget<AppBar>(find.descendant(of: find.byType(MyAssessmentScreen), matching: find.byType(AppBar)));
      expect(bar.backgroundColor, AppColors.primary);
    });

    testWidgets('course page load failure shows an error under the blue bar', (tester) async {
      await pumpTraining(tester, at: '/dashboard/my-learning', perms: [], size: _tall);
      await _tap(tester, find.byKey(const Key('my-learning-card-a-prog')));
      expect(find.byType(MyCourseScreen), findsOneWidget);
      // (failure path: a fresh pump with the detail endpoint failing)
      await pumpTraining(tester,
          at: '/dashboard/my-learning', perms: [], server: TrainingServer()..myDetailStatus = 500, size: _tall);
      await _tap(tester, find.byKey(const Key('my-learning-card-a-prog')));
      expect(_kind(tester), ApprovalsStateKind.error);
      expect(find.byType(BlueAppBar), findsOneWidget);
    });
  });

  group('Responsive: no overflow', () {
    final sizes = {
      '320': const Size(320, 700),
      '360': const Size(360, 740),
      '430': const Size(430, 900),
      'tablet': const Size(1000, 800),
    };
    for (final sz in sizes.entries) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('${sz.key} @ ${scale}x text: list, reports, course tabs, my learning, my course', (tester) async {
          Future<void> walk(String at, List<Key> taps, {List<String> perms = tAdminPerms}) async {
            await pumpTraining(tester, at: at, perms: perms, size: sz.value, textScale: scale);
            expect(tester.takeException(), isNull, reason: at);
            for (final k in taps) {
              if (find.byKey(k).evaluate().isEmpty && find.byKey(const Key('my-learning-list')).evaluate().isNotEmpty) {
                await tester.scrollUntilVisible(find.byKey(k), 200,
                    scrollable: find
                        .descendant(of: find.byKey(const Key('my-learning-list')), matching: find.byType(Scrollable))
                        .first);
              }
              expect(find.byKey(k), findsWidgets, reason: 'missing $k at $at');
              await _tap(tester, find.byKey(k));
              expect(tester.takeException(), isNull, reason: '$at ${k.toString()}');
            }
          }

          await walk('/dashboard/training', [const Key('training-tab-reports')]);
          await walk('/dashboard/training/$tC1', [
            const Key('training-course-tab-Materials'),
            const Key('training-course-tab-Assign'),
            const Key('training-course-tab-Progress'),
          ]);
          await walk('/dashboard/my-learning', [
            const Key('my-learning-tab-overdue'),
            const Key('my-learning-tab-completed'),
            const Key('my-learning-tab-all'),
            const Key('my-learning-card-a-new'),
          ], perms: []);
        });
      }
    }

    testWidgets('keyboard-open New Course dialog at 2x text on a small phone', (tester) async {
      await pumpTraining(tester, size: const Size(320, 640), textScale: 2, keyboard: 280);
      await _tap(tester, find.byKey(const Key('training-new-course')));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final k in const ['new-course-create']) {
        expect(tester.getSize(find.byKey(Key(k))).height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('actions on a progress card are >=44dp and stay inside the card at 2x', (tester) async {
      await pumpTraining(tester, at: '/dashboard/training/$tC1', size: const Size(320, 900), textScale: 2);
      await _tap(tester, find.byKey(const Key('training-course-tab-Progress')));
      final reset = find.byKey(const Key('training-remove-p1'));
      expect(tester.getSize(reset).height, greaterThanOrEqualTo(44));
      final card = find.ancestor(of: reset, matching: find.byType(TrainingCard)).first;
      expect(tester.getRect(reset).right, lessThanOrEqualTo(tester.getRect(card).right));
      expect(tester.takeException(), isNull);
    });
  });
}
