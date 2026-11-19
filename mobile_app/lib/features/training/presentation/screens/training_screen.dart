import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/training_models.dart';
import '../providers/training_providers.dart';
import '../widgets/training_reports_panel.dart';
import '../widgets/training_widgets.dart';

/// Training & Learning (web /dashboard/training, training.view, module
/// 'training'): dashboard figures, the course catalogue and — with
/// training.view_reports — the assignment report. The backend scopes every
/// figure and row to the viewer (branch for branch-restricted roles).
///
/// New Course (training.create) opens the course to finish it — details,
/// materials, assignment — as on web.
class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = TrainingAccess(ref.watch(authStateProvider).valueOrNull?.user);
    final tabs = [
      const Tab(key: Key('training-tab-courses'), text: 'Courses'),
      if (access.canViewReports) const Tab(key: Key('training-tab-reports'), text: 'Reports'),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: access.canCreate
            ? FloatingActionButton.extended(
                key: const Key('training-new-course'),
                onPressed: () => _newCourse(context, ref),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: Text('New Course',
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
              )
            : null,
        body: Column(
          children: [
            Material(
              color: AppColors.surface,
              child: TabBar(
                tabs: tabs,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const _CoursesTab(),
                  if (access.canViewReports) const TrainingReportsPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Web CreateCourseButton: title (required) + category → POST courses/,
/// then the new course opens (Details tab) to finish it.
Future<void> _newCourse(BuildContext context, WidgetRef ref) async {
  final created = await showDialog<TrainingCourse>(context: context, builder: (_) => const NewCourseDialog());
  if (created == null || !context.mounted) return;
  ref.invalidate(trainingCoursesProvider);
  ref.invalidate(trainingDashboardProvider);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: const Text('Course created.'),
    backgroundColor: AppColors.success,
    behavior: SnackBarBehavior.floating,
  ));
  context.push('/dashboard/training/${created.id}', extra: created);
}

class NewCourseDialog extends ConsumerStatefulWidget {
  const NewCourseDialog({super.key});

  @override
  ConsumerState<NewCourseDialog> createState() => _NewCourseDialogState();
}

class _NewCourseDialogState extends ConsumerState<NewCourseDialog> {
  final _title = TextEditingController();
  final _category = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give the course a title.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final c = await ref
          .read(trainingAdminActionsProvider)
          .createCourse(title: _title.text.trim(), category: _category.text.trim());
      if (mounted) Navigator.of(context).pop(c);
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => TrainingDialog(
        title: 'New Training Course',
        icon: Icons.add_circle_outline,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Give it a title now; you finish the details, materials and assignment next.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_error!,
                      key: const Key('new-course-error'),
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
                ),
              TextField(
                key: const Key('new-course-title'),
                controller: _title,
                maxLength: 200,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: trainingInput('Title *'),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('new-course-category'),
                controller: _category,
                maxLength: 100,
                decoration: trainingInput('Category', hint: 'e.g. Safety, Compliance'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              style: trainingTextStyle(),
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            key: const Key('new-course-create'),
            style: trainingFilledStyle(),
            onPressed: _saving ? null : _create,
            child: Text(_saving ? 'Creating…' : 'Create'),
          ),
        ],
      );
}

class _CoursesTab extends ConsumerStatefulWidget {
  const _CoursesTab();

  @override
  ConsumerState<_CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends ConsumerState<_CoursesTab> with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  bool _archived = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(trainingDashboardProvider);
    ref.invalidate(trainingCoursesProvider(_archived));
    await ref.read(trainingCoursesProvider(_archived).future).catchError((_) => <TrainingCourse>[]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final access = TrainingAccess(ref.watch(authStateProvider).valueOrNull?.user);
    final coursesAsync = ref.watch(trainingCoursesProvider(_archived));
    final q = _search.text.trim().toLowerCase();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          Text('Courses, assignments, progress and assessment results.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          const _DashboardStats(),
          TextField(
            key: const Key('training-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: trainingInput('Search courses', prefix: const Icon(Icons.search)).copyWith(
              labelText: null,
              hintText: 'Search courses',
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                key: const Key('training-show-archived'),
                selected: _archived,
                showCheckmark: true,
                checkmarkColor: AppColors.primary,
                avatar: Icon(Icons.inventory_2_outlined,
                    size: 16, color: _archived ? AppColors.primary : AppColors.textSecondary),
                label: const Text('Show archived'),
                labelStyle: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600, color: _archived ? AppColors.primary : AppColors.textSecondary),
                selectedColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundColor: AppColors.surface,
                side: BorderSide(color: _archived ? AppColors.primary : AppColors.border),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (v) => setState(() => _archived = v),
              ),
              if (coursesAsync.valueOrNull != null)
                Text('${coursesAsync.valueOrNull!.length} course${coursesAsync.valueOrNull!.length == 1 ? '' : 's'}',
                    key: const Key('training-course-count'),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          ...coursesAsync.when(
            skipLoadingOnRefresh: true,
            loading: () => [const ApprovalsLoading(label: 'Loading courses…')],
            error: (e, _) => [
              TrainingStateView.error(e,
                  what: 'courses', onRetry: () => ref.invalidate(trainingCoursesProvider(_archived))),
            ],
            data: (courses) {
              final shown = [
                for (final c in courses)
                  if (q.isEmpty || '${c.title} ${c.category}'.toLowerCase().contains(q)) c,
              ];
              if (shown.isEmpty) {
                if (q.isNotEmpty) {
                  return [
                    TrainingStateView.noMatch(
                      key: const Key('training-no-match'),
                      title: 'No courses match your search.',
                      message: 'Try a different title or category.',
                      onClear: () => setState(_search.clear),
                    ),
                  ];
                }
                return [
                  TrainingStateView.empty(
                    key: const Key('training-empty'),
                    title: 'No courses yet.',
                    message:
                        access.canCreate ? 'Create the first one.' : 'Courses will appear here once they are created.',
                    compact: true,
                  ),
                ];
              }
              return [for (final c in shown) _CourseCard(course: c)];
            },
          ),
        ],
      ),
    );
  }
}

/// Web Stat cards, as one summary surface. Hidden when the viewer has no
/// dashboard access (403), as web renders them only when the request succeeds.
class _DashboardStats extends ConsumerWidget {
  const _DashboardStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(trainingDashboardProvider).valueOrNull;
    if (d == null) return const SizedBox.shrink();
    final stats = [
      (Icons.menu_book_outlined, 'Active courses', '${d.activeCourses} / ${d.totalCourses}', AppColors.primary),
      (Icons.groups_outlined, 'Employees assigned', '${d.employeesAssigned}', AppColors.primary),
      (Icons.check_circle_outline, 'Completed', '${d.completed} (${d.completionPercent}%)', AppColors.success),
      (Icons.timelapse, 'In progress', '${d.inProgress}', AppColors.info),
      (Icons.alarm, 'Overdue', '${d.overdue}', AppColors.warning),
      (
        Icons.fact_check_outlined,
        'Assessment pass / fail',
        '${d.assessmentPassed} / ${d.assessmentFailed}',
        AppColors.primary
      ),
    ];
    return Container(
      key: const Key('training-stats'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
          final cols = (box.maxWidth < 300 || scale > 1.4) ? 1 : 2;
          final w = (box.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(
            spacing: 12,
            runSpacing: 0,
            children: [
              for (final (icon, label, value, color) in stats)
                SizedBox(
                  width: w,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        ApprovalsIconBox(icon, color: color, size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(value,
                                  style: AppTextStyles.h4
                                      .copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                              Text(label,
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});
  final TrainingCourse course;

  @override
  Widget build(BuildContext context) {
    final c = course;
    final tone = c.archived ? ApprovalsTone.neutral : (c.isActive ? ApprovalsTone.success : ApprovalsTone.warning);
    final pct = c.assignedCount == 0 ? 0 : ((c.completedCount * 100) / c.assignedCount).round().clamp(0, 100);
    return TrainingCard(
      key: Key('training-course-${c.id}'),
      onTap: () => context.push('/dashboard/training/${c.id}', extra: c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!trainingCompact(context)) ...[
                ApprovalsIconBox(Icons.school_outlined,
                    color: approvalsToneColor(tone == ApprovalsTone.success ? ApprovalsTone.info : tone), size: 40),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        TrainingBadge(label: c.stateLabel, color: approvalsToneColor(tone)),
                        if (c.category.isNotEmpty) ApprovalsChip(c.category, icon: Icons.sell_outlined),
                        ApprovalsChip(c.isMandatory ? 'Mandatory' : 'Optional',
                            tone: c.isMandatory ? ApprovalsTone.info : ApprovalsTone.neutral),
                        if (c.autoAssignNewJoiners)
                          const ApprovalsChip('New joiners', icon: Icons.person_add_alt_outlined),
                      ],
                    ),
                  ],
                ),
              ),
              if (!trainingCompact(context))
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8),
                child: Icon(Icons.chevron_right, color: AppColors.textHint),
              ),
            ],
          ),
          if (c.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(c.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              TrainingFact(Icons.description_outlined, '${c.materialCount} material${c.materialCount == 1 ? '' : 's'}'),
              TrainingFact(Icons.fact_check_outlined, c.assessment?.title ?? 'No assessment'),
              if (c.durationMinutes != null) TrainingFact(Icons.schedule, '${c.durationMinutes} min'),
            ],
          ),
          if (c.assignedCount > 0) ...[
            const SizedBox(height: 10),
            TrainingProgressBar(pct, color: AppColors.success),
            const SizedBox(height: 4),
            Text('${c.completedCount} of ${c.assignedCount} completed',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ] else ...[
            const SizedBox(height: 10),
            Text('0 assigned', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
          ],
        ],
      ),
    );
  }
}
