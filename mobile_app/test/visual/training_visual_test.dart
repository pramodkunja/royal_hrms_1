import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/training/training_fixtures.dart';
import 'shot_harness.dart';

// Task 102 — render evidence for Training & Learning (see shot_harness.dart;
// runs only with T1011_SHOTS=1, output T1011_OUT, file prefix T1011_PREFIX:
// `before_t102_` for the old UI, `t102_` for the redesign). Real widgets, real
// Poppins, the dashboard's real blue AppTopBar around the two shell screens.

const _phone = Size(390, 844);
const _tall = Size(390, 1500);

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

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ── Training (admin) ──────────────────────────────────────────────────────
  shot('01_training_list', (t) => pumpTraining(t, size: _tall));
  shot('02_training_reports', (t) async {
    await pumpTraining(t, size: _tall);
    await _tap(t, find.byKey(const Key('training-tab-reports')));
  });
  shot('03_course_details_editor', (t) => pumpTraining(t, at: '/dashboard/training/$tC1', size: const Size(390, 2400)));
  shot('03b_course_details_readonly',
      (t) => pumpTraining(t, perms: ['training.view'], at: '/dashboard/training/$tC1', size: _tall));
  shot('04_course_materials', (t) async {
    await pumpTraining(t, at: '/dashboard/training/$tC1', size: const Size(390, 2000));
    await _tap(t, find.byKey(const Key('training-course-tab-Materials')));
  });
  shot('04b_course_add_material', (t) async {
    await pumpTraining(t, at: '/dashboard/training/$tC1', size: const Size(390, 2400));
    await _tap(t, find.byKey(const Key('training-course-tab-Materials')));
    await _tap(t, find.byKey(const Key('add-material-toggle')));
  });
  shot('05_course_assign', (t) async {
    await pumpTraining(t, at: '/dashboard/training/$tC1', size: const Size(390, 1100));
    await _tap(t, find.byKey(const Key('training-course-tab-Assign')));
  });
  shot('06_course_progress', (t) async {
    await pumpTraining(t, at: '/dashboard/training/$tC1', size: const Size(390, 1500));
    await _tap(t, find.byKey(const Key('training-course-tab-Progress')));
  });
  shot('07_dialog_new_course', (t) async {
    await pumpTraining(t);
    await _tap(t, find.byKey(const Key('training-new-course')));
  });
  shot('07b_dialog_new_course_keyboard', (t) async {
    await pumpTraining(t, keyboard: 300);
    await _tap(t, find.byKey(const Key('training-new-course')));
  });
  shot('08_dialog_delete_course', (t) async {
    await pumpTraining(t, at: '/dashboard/training/$tC1');
    await _tap(t, find.byKey(const Key('training-course-delete')));
  });
  shot('09_dialog_reset_attempts', (t) async {
    await pumpTraining(t, at: '/dashboard/training/$tC1', size: const Size(390, 1500));
    await _tap(t, find.byKey(const Key('training-course-tab-Progress')));
    await _tap(t, find.byKey(const Key('training-reset-p2')));
  });
  shot('10_dialog_remove_assignment', (t) async {
    await pumpTraining(t, at: '/dashboard/training/$tC1', size: const Size(390, 1500));
    await _tap(t, find.byKey(const Key('training-course-tab-Progress')));
    await _tap(t, find.byKey(const Key('training-remove-p1')));
  });

  // ── My Learning ───────────────────────────────────────────────────────────
  shot('20_my_learning_all', (t) => pumpTraining(t, at: '/dashboard/my-learning', perms: [], size: _tall));
  for (final (key, name) in const [
    ('assigned', '21_my_not_started'),
    ('in_progress', '22_my_in_progress'),
    ('overdue', '23_my_overdue'),
    ('completed', '24_my_completed'),
    ('failed', '25_my_failed'),
  ]) {
    shot(name, (t) async {
      await pumpTraining(t, at: '/dashboard/my-learning', perms: [], size: const Size(390, 900));
      await _tap(t, find.byKey(Key('my-learning-tab-$key')));
    });
  }
  shot('26_my_course', (t) async {
    await pumpTraining(t, at: '/dashboard/my-learning', perms: [], size: _tall);
    await _tap(t, find.byKey(const Key('my-learning-card-a-prog')));
  });
  shot('27_my_material_video', (t) async {
    await pumpTraining(t, at: '/dashboard/my-learning', perms: [], size: _tall);
    await _tap(t, find.byKey(const Key('my-learning-card-a-prog')));
    await _tap(t, find.byKey(const Key('my-material-m-yt')));
  });
  shot('28_my_assessment_locked', (t) async {
    await pumpTraining(t, at: '/dashboard/my-learning', perms: [], size: _phone);
    await _tap(t, find.byKey(const Key('my-learning-card-a-prog')));
    await _tap(t, find.byKey(const Key('my-course-assessment')));
  });
  shot('29_my_assessment_questions', (t) async {
    final s = TrainingServer();
    s.myDetail = {...s.myDetail, 'assessment': tAssess()};
    await pumpTraining(t, at: '/dashboard/my-learning', perms: [], size: const Size(390, 1100), server: s);
    await _tap(t, find.byKey(const Key('my-learning-card-a-prog')));
    await _tap(t, find.byKey(const Key('my-course-assessment')));
    await _tap(t, find.byKey(const Key('my-assessment-start')));
  });

  // ── States ────────────────────────────────────────────────────────────────
  shot('30_list_empty', (t) => pumpTraining(t, server: TrainingServer()..courses = []));
  shot('31_list_no_match', (t) async {
    await pumpTraining(t);
    await t.enterText(find.byKey(const Key('training-search')), 'zzzz');
    await tSettle(t);
  });
  shot('32_list_error', (t) => pumpTraining(t, server: TrainingServer()..coursesStatus = 500));
  shot(
      '33_list_denied',
      (t) => pumpTraining(t,
          server: TrainingServer()
            ..coursesStatus = 403
            ..dashboardStatus = 403));
  shot('34_reports_empty', (t) async {
    await pumpTraining(t, server: TrainingServer()..reports = []);
    await _tap(t, find.byKey(const Key('training-tab-reports')));
  });
  shot('35_reports_error', (t) async {
    await pumpTraining(t, server: TrainingServer()..reportsStatus = 500);
    await _tap(t, find.byKey(const Key('training-tab-reports')));
  });
  shot('36_progress_empty', (t) async {
    await pumpTraining(t, at: '/dashboard/training/$tC1', server: TrainingServer()..progress = []);
    await _tap(t, find.byKey(const Key('training-course-tab-Progress')));
  });
  shot('37_progress_error', (t) async {
    await pumpTraining(t, at: '/dashboard/training/$tC1', server: TrainingServer()..progressStatus = 500);
    await _tap(t, find.byKey(const Key('training-course-tab-Progress')));
  });
  shot('38_my_empty',
      (t) => pumpTraining(t, at: '/dashboard/my-learning', perms: [], server: TrainingServer()..myList = []));
  shot('39_my_completed_empty', (t) async {
    final s = TrainingServer();
    s.myList = [tAssignment('a-new', 'assigned', title: 'Workplace Safety Essentials')];
    await pumpTraining(t, at: '/dashboard/my-learning', perms: [], server: s);
    await _tap(t, find.byKey(const Key('my-learning-tab-completed')));
  });
  shot('40_my_error',
      (t) => pumpTraining(t, at: '/dashboard/my-learning', perms: [], server: TrainingServer()..myStatus = 500));
  shot('41_my_module_disabled',
      (t) => pumpTraining(t, at: '/dashboard/my-learning', perms: [], server: TrainingServer()..myStatus = 403));
  shot('42_course_load_error',
      (t) => pumpTraining(t, at: '/dashboard/training/$tC1', server: TrainingServer()..courseStatus = 500));

  // ── 320 dp wide at 2.0x text ──────────────────────────────────────────────
  shot('50_list_320_2x', (t) => pumpTraining(t, size: const Size(320, 2600), textScale: 2));
  shot('51_progress_320_2x', (t) async {
    await pumpTraining(t, at: '/dashboard/training/$tC1', size: const Size(320, 2600), textScale: 2);
    await _tap(t, find.byKey(const Key('training-course-tab-Progress')));
  });
  shot('52_my_learning_320_2x',
      (t) => pumpTraining(t, at: '/dashboard/my-learning', perms: [], size: const Size(320, 2600), textScale: 2));
  shot('53_dialog_320_2x', (t) async {
    await pumpTraining(t, size: const Size(320, 700), textScale: 2);
    await _tap(t, find.byKey(const Key('training-new-course')));
  });
}
