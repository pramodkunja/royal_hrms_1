import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/training_models.dart';
import '../providers/training_providers.dart';
import '../widgets/training_assign_panel.dart';
import '../widgets/training_course_form.dart';
import '../widgets/training_materials_editor.dart';
import '../widgets/training_widgets.dart';

/// Opens an external video link. A provider so tests need no platform channel.
final trainingLinkLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// One course (web /dashboard/training/<id>): Details, Materials, Assign
/// (training.assign, not archived) and Progress, plus Delete
/// (training.delete, not archived). Details and Materials are read-only on
/// mobile in this batch; editing stays on web.
class TrainingCourseScreen extends ConsumerStatefulWidget {
  const TrainingCourseScreen({super.key, required this.courseId, this.initial});
  final String courseId;
  final TrainingCourse? initial;

  @override
  ConsumerState<TrainingCourseScreen> createState() => _TrainingCourseScreenState();
}

class _TrainingCourseScreenState extends ConsumerState<TrainingCourseScreen> with TickerProviderStateMixin {
  TabController? _tabs;
  int _tabCount = 0;
  bool _deleting = false;

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  TabController _controllerFor(int count) {
    if (_tabs == null || _tabCount != count) {
      final previous = _tabs?.index ?? 0;
      _tabs?.dispose();
      _tabs = TabController(length: count, vsync: this, initialIndex: previous.clamp(0, count - 1));
      _tabCount = count;
    }
    return _tabs!;
  }

  void _snack(String msg, {bool ok = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));

  Future<void> _delete(TrainingCourse c) async {
    final ok = await confirmTrainingAction(
      context,
      title: 'Delete course?',
      message: 'Delete "${c.title}"? Courses with training history are archived instead.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    try {
      final msg = await ref.read(trainingAdminActionsProvider).deleteCourse(c);
      if (!mounted) return;
      ref.invalidate(trainingCoursesProvider);
      ref.invalidate(trainingDashboardProvider);
      _snack(msg, ok: true);
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) _snack(userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = TrainingAccess(ref.watch(authStateProvider).valueOrNull?.user);
    final courseAsync = ref.watch(trainingCourseProvider(widget.courseId));
    final course = courseAsync.valueOrNull;
    final shown = course ?? widget.initial;

    if (course == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(shown?.title ?? 'Training Course', overflow: TextOverflow.ellipsis)),
        body: courseAsync.hasError
            ? AppErrorState.forError(courseAsync.error!,
                onRetry: () => ref.invalidate(trainingCourseProvider(widget.courseId)))
            : Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final showAssign = access.canAssign && !course.archived;
    final tabs = <(String, Widget)>[
      (
        'Details',
        access.canEdit && !course.archived
            ? TrainingCourseEditor(course: course, onSaved: () {}, onContinue: () => _tabs?.animateTo(1))
            : _DetailsTab(course: course),
      ),
      (
        'Materials (${course.materials?.length ?? 0})',
        TrainingMaterialsTab(
          course: course,
          canEdit: access.canEdit && !course.archived,
          launcher: ref.read(trainingLinkLauncherProvider),
        ),
      ),
      if (showAssign)
        (
          'Assign',
          TrainingAssignPanel(
            course: course,
            onAssigned: () => _tabs?.animateTo(_tabCount - 1), // Progress is last
          ),
        ),
      ('Progress', _ProgressTab(course: course, access: access)),
    ];
    final controller = _controllerFor(tabs.length);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(course.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (access.canDelete && !course.archived)
            IconButton(
              key: const Key('training-course-delete'),
              tooltip: 'Delete course',
              onPressed: _deleting ? null : () => _delete(course),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
        bottom: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final (label, _) in tabs) Tab(key: Key('training-course-tab-${label.split(' ').first}'), text: label)
          ],
        ),
      ),
      body: TabBarView(controller: controller, children: [for (final (_, body) in tabs) body]),
    );
  }
}

// ── Details (read-only) ─────────────────────────────────────────────────────

class _DetailsTab extends ConsumerWidget {
  const _DetailsTab({required this.course});
  final TrainingCourse course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = course;
    final rows = <(String, String)>[
      ('Status', [c.stateLabel, c.isMandatory ? 'Mandatory' : 'Optional'].join(' · ')),
      if (c.category.isNotEmpty) ('Category', c.category),
      if (c.trainerLabel.isNotEmpty) ('Trainer / owner', c.trainerLabel),
      if (c.durationMinutes != null) ('Duration', '${c.durationMinutes} minutes'),
      ('Start date', c.startDate ?? '—'),
      ('Deadline', c.deadline ?? '—'),
      (
        'Linked assessment',
        c.assessment == null ? 'None' : '${c.assessment!.title} (pass mark ${c.assessment!.passPercentage}%)'
      ),
      if (c.assessment != null)
        ('Videos optional', c.videosOptional ? 'Yes — passing the assessment completes it' : 'No'),
      (
        'New joiners',
        c.autoAssignNewJoiners
            ? 'Assigned automatically, due within ${c.newJoinerDeadlineDays} day(s)'
            : 'Not assigned automatically'
      ),
      if (c.autoAssignNewJoiners)
        ('New-joiner branches', c.newJoinerBranches.isEmpty ? 'All' : c.newJoinerBranches.join(', ')),
      if (c.autoAssignNewJoiners)
        ('New-joiner departments', c.newJoinerDepartments.isEmpty ? 'All' : c.newJoinerDepartments.join(', ')),
    ];
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(trainingCourseProvider(course.id)),
      child: ListView(
        key: const Key('training-details'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (c.description.isNotEmpty)
            TrainingCard(child: Text(c.description, style: TextStyle(fontSize: 14, color: AppColors.textPrimary))),
          TrainingCard(
            child: Column(
              children: [
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HO-46: fixed gap so a long label ("Linked assessment") never
                        // touches its value; the label wraps inside its column.
                        Expanded(
                          flex: 2,
                          child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Text(value,
                              style:
                                  TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress ────────────────────────────────────────────────────────────────

class _ProgressTab extends ConsumerStatefulWidget {
  const _ProgressTab({required this.course, required this.access});
  final TrainingCourse course;
  final TrainingAccess access;

  @override
  ConsumerState<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<_ProgressTab> {
  final _busy = <String>{};

  Future<void> _act(TrainingAssignmentRow r, {required bool reset}) async {
    if (_busy.contains(r.id)) return;
    final ok = await confirmTrainingAction(
      context,
      title: reset ? 'Reset attempts?' : 'Remove assignment?',
      message: reset
          ? 'Give ${r.employee.name} a fresh set of assessment attempts?'
          : 'Remove this course from ${r.employee.name}?',
      confirmLabel: reset ? 'Reset' : 'Remove',
      destructive: !reset,
    );
    if (!ok || !mounted) return;
    setState(() => _busy.add(r.id));
    try {
      final actions = ref.read(trainingAdminActionsProvider);
      final msg = reset ? await actions.resetAttempts(r) : await actions.removeAssignment(r);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      ref.invalidate(trainingProgressProvider(widget.course.id));
      ref.invalidate(trainingCoursesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(userFriendlyMessage(e)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(trainingProgressProvider(widget.course.id));
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(trainingProgressProvider(widget.course.id));
        await ref.read(trainingProgressProvider(widget.course.id).future).catchError((_) => <TrainingAssignmentRow>[]);
      },
      child: ListView(
        key: const Key('training-progress'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: progressAsync.when(
          skipLoadingOnRefresh: true,
          loading: () => [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ),
          ],
          error: (e, _) => [
            AppErrorState.forError(e, onRetry: () => ref.invalidate(trainingProgressProvider(widget.course.id))),
          ],
          data: (rows) => [
            if (rows.isEmpty)
              const TrainingNote('No one in your scope has this course yet.', icon: Icons.groups_outlined),
            for (final r in rows)
              TrainingAssignmentCard(
                key: Key('training-progress-${r.id}'),
                row: r,
                actions: [
                  if (widget.access.canResetAttempts && r.canResetAttempts)
                    TextButton(
                      key: Key('training-reset-${r.id}'),
                      onPressed: _busy.contains(r.id) ? null : () => _act(r, reset: true),
                      child: const Text('Reset attempts'),
                    ),
                  if (widget.access.canAssign && r.canRemove)
                    TextButton(
                      key: Key('training-remove-${r.id}'),
                      onPressed: _busy.contains(r.id) ? null : () => _act(r, reset: false),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      child: const Text('Remove'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
