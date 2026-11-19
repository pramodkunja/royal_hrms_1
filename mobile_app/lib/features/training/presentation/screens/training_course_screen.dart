import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_app_bar.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart';
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
        appBar: BlueAppBar(title: shown?.title ?? 'Training Course'),
        body: courseAsync.hasError
            ? ListView(children: [
                TrainingStateView.error(courseAsync.error!,
                    what: 'this course', onRetry: () => ref.invalidate(trainingCourseProvider(widget.courseId)))
              ])
            : const TrainingLoading('Loading course…'),
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
      appBar: BlueAppBar(
        title: course.title,
        actions: [
          if (access.canDelete && !course.archived)
            IconButton(
              key: const Key('training-course-delete'),
              tooltip: 'Delete course',
              onPressed: _deleting ? null : () => _delete(course),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
        // The tabs sit on the blue bar: white selected label + indicator,
        // 70% white for the rest (readable, and one continuous header).
        bottom: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          dividerColor: Colors.transparent,
          labelStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500),
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

/// Course identity: icon, full title, state / category chips and figures.
class TrainingCourseHeader extends StatelessWidget {
  const TrainingCourseHeader({super.key, required this.course});
  final TrainingCourse course;

  @override
  Widget build(BuildContext context) {
    final c = course;
    final tone = c.archived ? ApprovalsTone.neutral : (c.isActive ? ApprovalsTone.success : ApprovalsTone.warning);
    return TrainingCard(
      key: const Key('training-course-header'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!trainingCompact(context)) ...[
                const ApprovalsIconBox(Icons.school_outlined, size: 44),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title, style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700, height: 1.3)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      TrainingBadge(label: c.stateLabel, color: approvalsToneColor(tone)),
                      if (c.category.isNotEmpty) ApprovalsChip(c.category, icon: Icons.sell_outlined),
                      ApprovalsChip(c.isMandatory ? 'Mandatory' : 'Optional',
                          tone: c.isMandatory ? ApprovalsTone.info : ApprovalsTone.neutral),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          if (c.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(c.description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class _DetailsTab extends ConsumerWidget {
  const _DetailsTab({required this.course});
  final TrainingCourse course;

  Widget _section(IconData icon, String title, List<Widget> lines) => TrainingCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrainingSectionHeader(icon, title),
            const SizedBox(height: 12),
            for (final (i, l) in lines.indexed) ...[if (i > 0) const SizedBox(height: 8), l],
          ],
        ),
      );

  Widget _line(IconData icon, String lead, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: AppColors.textSecondary)),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                Text(lead, style: TextStyle(color: AppColors.textSecondary)),
                Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = course;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(trainingCourseProvider(course.id)),
      child: ListView(
        key: const Key('training-details'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          TrainingCourseHeader(course: c),
          _section(Icons.event_note_outlined, 'Schedule', [
            if (c.trainerLabel.isNotEmpty) _line(Icons.person_outline, 'Trainer / owner', c.trainerLabel),
            if (c.durationMinutes != null) _line(Icons.schedule, 'Duration', '${c.durationMinutes} minutes'),
            _line(Icons.play_circle_outline, 'Start date', c.startDate ?? '—'),
            _line(Icons.flag_outlined, 'Deadline', c.deadline ?? '—'),
          ]),
          _section(Icons.fact_check_outlined, 'Assessment', [
            _line(Icons.link, 'Linked assessment',
                c.assessment == null ? 'None' : '${c.assessment!.title} (pass mark ${c.assessment!.passPercentage}%)'),
            if (c.assessment != null)
              _line(Icons.ondemand_video_outlined, 'Videos optional',
                  c.videosOptional ? 'Yes — passing the assessment completes it' : 'No'),
          ]),
          _section(Icons.person_add_alt_outlined, 'New joiners', [
            _line(
                Icons.autorenew,
                'New joiners',
                c.autoAssignNewJoiners
                    ? 'Assigned automatically, due within ${c.newJoinerDeadlineDays} day(s)'
                    : 'Not assigned automatically'),
            if (c.autoAssignNewJoiners)
              _line(Icons.apartment, 'New-joiner branches', c.newJoinerBranches.isEmpty ? 'All' : c.newJoinerBranches.join(', ')),
            if (c.autoAssignNewJoiners)
              _line(Icons.account_tree_outlined, 'New-joiner departments',
                  c.newJoinerDepartments.isEmpty ? 'All' : c.newJoinerDepartments.join(', ')),
          ]),
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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: progressAsync.when(
          skipLoadingOnRefresh: true,
          loading: () => [const ApprovalsLoading(label: 'Loading progress…')],
          error: (e, _) => [
            TrainingStateView.error(e,
                what: 'progress', onRetry: () => ref.invalidate(trainingProgressProvider(widget.course.id))),
          ],
          data: (rows) => [
            if (rows.isEmpty)
              TrainingStateView.empty(
                key: const Key('training-progress-empty'),
                title: 'No one in your scope has this course yet.',
                message: widget.access.canAssign && !widget.course.archived ? 'Use the Assign tab to give it to employees.' : null,
                icon: Icons.groups_outlined,
                compact: true,
              )
            else
              _Summary(rows: rows),
            for (final r in rows)
              TrainingAssignmentCard(
                key: Key('training-progress-${r.id}'),
                row: r,
                actions: [
                  if (widget.access.canResetAttempts && r.canResetAttempts)
                    OutlinedButton.icon(
                      key: Key('training-reset-${r.id}'),
                      onPressed: _busy.contains(r.id) ? null : () => _act(r, reset: true),
                      style: trainingOutlinedStyle(),
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('Reset attempts'),
                    ),
                  if (widget.access.canAssign && r.canRemove)
                    OutlinedButton.icon(
                      key: Key('training-remove-${r.id}'),
                      onPressed: _busy.contains(r.id) ? null : () => _act(r, reset: false),
                      style: trainingOutlinedStyle(color: AppColors.error),
                      icon: const Icon(Icons.person_remove_outlined, size: 18),
                      label: const Text('Remove'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// "4 people" + one chip per status present (counts from the rows shown).
class _Summary extends StatelessWidget {
  const _Summary({required this.rows});
  final List<TrainingAssignmentRow> rows;

  @override
  Widget build(BuildContext context) {
    final counts = <TrainingStatus, int>{};
    for (final r in rows) {
      counts[r.status] = (counts[r.status] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${rows.length} ${rows.length == 1 ? 'person' : 'people'}',
              key: const Key('training-progress-count'),
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          for (final e in counts.entries) TrainingBadge(label: '${e.value} ${e.key.label}', color: trainingStatusColor(e.key)),
        ],
      ),
    );
  }
}
