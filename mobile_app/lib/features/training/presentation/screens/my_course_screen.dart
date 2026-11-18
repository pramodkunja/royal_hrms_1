import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../data/models/training_models.dart';
import '../providers/training_providers.dart';
import '../widgets/training_widgets.dart';
import 'my_assessment_screen.dart';
import 'my_material_screen.dart';

/// Strict web parity switch (Task 90 batch 3 proposal) — OFF.
///
/// Web (my-learning/[id]/page.tsx) selects the first unfinished material as
/// soon as the course page loads and shows it, and MaterialViewer then
/// records "open" — so merely visiting a course starts it (status assigned →
/// in progress). Mobile currently records nothing until a material is
/// tapped. Turning this on makes mobile behave like web on a phone: the
/// first unfinished material opens automatically (once per visit) and its
/// viewer records "open" exactly as a tap would. Both settings are covered by
/// tests against a mocked API (test/features/training/training_batch3_test.dart);
/// flip it only after the product owner approves and staging confirms.
const bool kMyLearningAutoOpenFirstMaterial = false;

/// Web: the first material not yet completed, else the first one; null when
/// the course is not open yet, is closed, or has no materials.
TrainingMaterial? myLearningAutoOpenTarget(MyTraining t) {
  final mats = t.materials ?? const <TrainingMaterial>[];
  if (mats.isEmpty || t.startsOn != null || t.isClosed) return null;
  return mats.firstWhere((m) => !m.isCompleted, orElse: () => mats.first);
}

/// One assigned course (web /dashboard/my-learning/<id>): status, progress,
/// the ordered materials and the linked assessment.
///
/// With [autoOpenFirstMaterial] off (default, kMyLearningAutoOpenFirstMaterial)
/// this page only READS (GET my/<id>/); nothing is recorded until the
/// employee taps a material. See kMyLearningAutoOpenFirstMaterial for the
/// web-parity alternative.
class MyCourseScreen extends ConsumerStatefulWidget {
  const MyCourseScreen({
    super.key,
    required this.assignmentId,
    this.initial,
    this.autoOpenFirstMaterial = kMyLearningAutoOpenFirstMaterial,
  });
  final String assignmentId;
  final MyTraining? initial;
  final bool autoOpenFirstMaterial;

  @override
  ConsumerState<MyCourseScreen> createState() => _MyCourseScreenState();
}

class _MyCourseScreenState extends ConsumerState<MyCourseScreen> {
  bool _autoOpened = false;

  String get assignmentId => widget.assignmentId;

  void _refresh() {
    ref.invalidate(myTrainingDetailProvider(assignmentId));
    ref.invalidate(myTrainingListProvider);
  }

  void _maybeAutoOpen(MyTraining t) {
    if (!widget.autoOpenFirstMaterial || _autoOpened) return;
    final target = myLearningAutoOpenTarget(t);
    _autoOpened = true;
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MyMaterialScreen(training: t, material: target),
      ));
      if (mounted) _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(myTrainingDetailProvider(assignmentId));
    final t = detailAsync.valueOrNull;
    if (t != null) _maybeAutoOpen(t);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar:
          AppBar(title: Text((t ?? widget.initial)?.course.title ?? 'My Learning', overflow: TextOverflow.ellipsis)),
      body: t == null
          ? (detailAsync.hasError
              ? AppErrorState.forError(detailAsync.error!,
                  onRetry: () => ref.invalidate(myTrainingDetailProvider(assignmentId)))
              : Center(child: CircularProgressIndicator(color: AppColors.primary)))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                _refresh();
                await ref.read(myTrainingDetailProvider(assignmentId).future).catchError((_) => t);
              },
              child: _Body(training: t, onChanged: _refresh),
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.training, required this.onChanged});
  final MyTraining training;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = training;
    final materials = t.materials ?? const <TrainingMaterial>[];
    final a = t.assessment;
    final notOpen = t.startsOn != null;

    Future<void> openMaterial(TrainingMaterial m) async {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MyMaterialScreen(training: t, material: m),
      ));
      onChanged(); // progress may have changed
    }

    Future<void> openAssessment() async {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MyAssessmentScreen(assignmentId: t.id, courseTitle: t.course.title),
      ));
      onChanged();
    }

    return ListView(
      key: const Key('my-course'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        TrainingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        t.course.category,
                        if (t.row.dueDate != null) 'Due ${t.row.dueDate}',
                        '${t.progressPercent}% complete',
                      ].where((p) => p.isNotEmpty).join(' · '),
                      key: const Key('my-course-summary'),
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TrainingBadge.status(t.status),
                ],
              ),
              if (t.course.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(t.course.description, style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              ],
            ],
          ),
        ),
        if (t.isClosed)
          _Alert(
            key: const Key('my-course-closed'),
            text: 'You have used all assessment attempts without passing. HR can reset your attempts.',
            color: AppColors.error,
            background: AppColors.errorContainer,
            icon: Icons.block,
          ),
        if (notOpen)
          _Alert(
            key: const Key('my-course-not-open'),
            text: 'This course starts on ${t.startsOn}. The materials and the assessment open on that date.',
            color: AppColors.info,
            background: AppColors.infoContainer,
            icon: Icons.event_outlined,
          ),
        if (materials.isEmpty) const TrainingNote('No materials yet.', icon: Icons.folder_open_outlined),
        for (final (i, m) in materials.indexed)
          _MaterialRow(
            index: i,
            material: m,
            enabled: !notOpen,
            onTap: () => openMaterial(m),
          ),
        if (a != null && a.required)
          TrainingCard(
            key: const Key('my-course-assessment'),
            onTap: notOpen ? null : openAssessment,
            child: Row(
              children: [
                Icon(
                  a.passed == true ? Icons.check_circle : (a.unlocked ? Icons.fact_check_outlined : Icons.lock_outline),
                  color: a.passed == true ? AppColors.success : AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assessment',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text(a.rowHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (!notOpen) Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
      ],
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({required this.index, required this.material, required this.enabled, required this.onTap});
  final int index;
  final TrainingMaterial material;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = material;
    final done = m.isCompleted;
    final icon = done
        ? Icons.check_circle
        : (m.isDocument
            ? Icons.description_outlined
            : (m.isUploadedVideo ? Icons.videocam_outlined : Icons.smart_display_outlined));
    return TrainingCard(
      key: Key('my-material-${m.id}'),
      onTap: enabled ? onTap : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: done ? AppColors.success : AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${index + 1}. ${m.title}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${m.kindLabel}${m.isRequired ? '' : ' · optional'} · ${trainingMaterialHint(m)}',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (enabled) Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({super.key, required this.text, required this.color, required this.background, required this.icon});
  final String text;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: AppColors.textPrimary))),
          ],
        ),
      );
}
