import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/training/training_fixtures.dart';
import 'shot_harness.dart';

// Task 103 — render evidence for My Learning, through the real routes under the
// dashboard's real blue AppTopBar. Runs only with T1011_SHOTS=1 (output
// T1011_OUT, prefix T1011_PREFIX, e.g. `t103_`).

const _phone = Size(393, 852);
const _tall = Size(393, 1700);
const _ml = '/dashboard/my-learning';

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f.first);
  await t.tap(f.first, warnIfMissed: false);
  await tSettle(t);
}

void shot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

TrainingServer _completedCourse() {
  final s = TrainingServer();
  s.myDetail = {
    ...tAssignment('a-done', 'completed',
        pct: 100, completed: '2026-11-10T09:00:00', title: 'Code of Conduct', best: 92),
    'materials': [
      tMat('m-pdf', 'document',
          title: 'Policy Handbook',
          format: 'pdf',
          progress: tProg(opened: '2026-11-08T10:00:00Z', completed: '2026-11-08T10:05:00Z')),
      tMat('m-yt', 'external_video',
          title: 'Awareness Video',
          provider: 'youtube',
          embed: 'abcdefghijk',
          url: 'https://www.youtube.com/watch?v=abcdefghijk',
          tracked: true,
          duration: 100,
          progress: tProg(opened: '2026-11-09T10:00:00Z', completed: '2026-11-09T10:05:00Z', watched: 100)),
    ],
    'assessment': tAssess(passed: true, best: 92, used: 1),
  };
  return s;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  shot('01_home_populated', (t) => pumpTraining(t, at: _ml, perms: [], size: _tall));
  for (final (key, name) in const [
    ('assigned', '02_tab_not_started'),
    ('in_progress', '03_tab_in_progress'),
    ('overdue', '04_tab_overdue'),
    ('completed', '05_tab_completed'),
    ('failed', '06_tab_failed'),
  ]) {
    shot(name, (t) async {
      await pumpTraining(t, at: _ml, perms: [], size: const Size(393, 900));
      await _tap(t, find.byKey(Key('my-learning-tab-$key')));
    });
  }
  // Every tab with no rows: one assigned course only, so the others are empty.
  for (final (key, name) in const [
    ('in_progress', '07_empty_in_progress'),
    ('overdue', '08_empty_overdue'),
    ('completed', '09_empty_completed'),
    ('failed', '10_empty_failed'),
  ]) {
    shot(name, (t) async {
      final s = TrainingServer()..myList = [tAssignment('a-new', 'assigned', title: 'Workplace Safety Essentials')];
      await pumpTraining(t, at: _ml, perms: [], size: _phone, server: s);
      await _tap(t, find.byKey(Key('my-learning-tab-$key')));
    });
  }
  shot('11_empty_not_started', (t) async {
    final s = TrainingServer()
      ..myList = [tAssignment('a-prog', 'in_progress', pct: 50, title: 'Data Protection Awareness')];
    await pumpTraining(t, at: _ml, perms: [], size: _phone, server: s);
    await _tap(t, find.byKey(const Key('my-learning-tab-assigned')));
  });
  shot('12_empty_nothing_assigned',
      (t) => pumpTraining(t, at: _ml, perms: [], size: _phone, server: TrainingServer()..myList = []));
  shot('13_error', (t) => pumpTraining(t, at: _ml, perms: [], size: _phone, server: TrainingServer()..myStatus = 500));
  shot('14_denied', (t) => pumpTraining(t, at: _ml, perms: [], size: _phone, server: TrainingServer()..myStatus = 403));
  shot('15_loading', (t) async {
    await pumpTraining(t, at: _ml, perms: [], size: _phone, settle: false);
    await t.pump(const Duration(milliseconds: 1));
  });

  shot('16_course_in_progress', (t) async {
    await pumpTraining(t, at: _ml, perms: [], size: _tall);
    await _tap(t, find.byKey(const Key('my-learning-open-a-prog')));
  });
  shot('17_course_completed', (t) async {
    await pumpTraining(t, at: _ml, perms: [], size: const Size(393, 1100), server: _completedCourse());
    await _tap(t, find.byKey(const Key('my-learning-tab-completed')));
    await _tap(t, find.byKey(const Key('my-learning-open-a-done')));
  });
  shot('18_material_video', (t) async {
    await pumpTraining(t, at: _ml, perms: [], size: _tall);
    await _tap(t, find.byKey(const Key('my-learning-open-a-prog')));
    await _tap(t, find.byKey(const Key('my-material-m-yt')));
  });
  shot('19_assessment_locked', (t) async {
    await pumpTraining(t, at: _ml, perms: [], size: const Size(393, 1100));
    await _tap(t, find.byKey(const Key('my-learning-open-a-prog')));
    await _tap(t, find.byKey(const Key('my-course-assessment')));
  });
  shot('20_assessment_questions', (t) async {
    final s = TrainingServer();
    s.myDetail = {...s.myDetail, 'assessment': tAssess()};
    await pumpTraining(t, at: _ml, perms: [], size: const Size(393, 1100), server: s);
    await _tap(t, find.byKey(const Key('my-learning-open-a-prog')));
    await _tap(t, find.byKey(const Key('my-course-assessment')));
    await _tap(t, find.byKey(const Key('my-assessment-start')));
  });

  shot('30_320dp_2x_home', (t) => pumpTraining(t, at: _ml, perms: [], size: const Size(320, 3200), textScale: 2));
  shot('31_320dp_2x_course', (t) async {
    await pumpTraining(t, at: _ml, perms: [], size: const Size(320, 3200), textScale: 2);
    await _tap(t, find.byKey(const Key('my-learning-open-a-prog')));
  });
  shot('32_foldable_700', (t) => pumpTraining(t, at: _ml, perms: [], size: const Size(700, 1500)));
  shot('33_tablet_1000', (t) => pumpTraining(t, at: _ml, perms: [], size: const Size(1000, 1000)));
  shot('34_landscape_800x393', (t) => pumpTraining(t, at: _ml, perms: [], size: const Size(800, 393)));
}
