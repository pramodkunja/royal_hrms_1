import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_error_state.dart';
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
                label: const Text('New Course', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New Training Course'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_error!, key: const Key('new-course-error'), style: TextStyle(color: AppColors.error)),
                ),
              TextField(
                key: const Key('new-course-title'),
                controller: _title,
                maxLength: 200,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              TextField(
                key: const Key('new-course-category'),
                controller: _category,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g. Safety, Compliance'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            key: const Key('new-course-create'),
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
    final coursesAsync = ref.watch(trainingCoursesProvider(_archived));
    final q = _search.text.trim().toLowerCase();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text('Courses, assignments, progress and assessment results.', style: AppTextStyles.bodySecondary),
          const SizedBox(height: 12),
          const _DashboardStats(),
          TextField(
            key: const Key('training-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search courses',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          SwitchListTile.adaptive(
            key: const Key('training-show-archived'),
            contentPadding: EdgeInsets.zero,
            value: _archived,
            onChanged: (v) => setState(() => _archived = v),
            title: Text('Show archived', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          ),
          ...coursesAsync.when(
            skipLoadingOnRefresh: true,
            loading: () => [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ],
            error: (e, _) => [
              AppErrorState.forError(e, onRetry: () => ref.invalidate(trainingCoursesProvider(_archived))),
            ],
            data: (courses) {
              final shown = [
                for (final c in courses)
                  if (q.isEmpty || '${c.title} ${c.category}'.toLowerCase().contains(q)) c,
              ];
              if (shown.isEmpty) {
                return [
                  TrainingNote(q.isNotEmpty ? 'No courses match your search.' : 'No courses yet.',
                      icon: Icons.school_outlined),
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

/// Web Stat cards. Hidden when the viewer has no dashboard access (403), as
/// web renders them only when the request succeeds.
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
      (Icons.timelapse, 'In progress', '${d.inProgress}', AppColors.primary),
      (Icons.alarm, 'Overdue', '${d.overdue}', AppColors.warning),
      (
        Icons.fact_check_outlined,
        'Assessment pass / fail',
        '${d.assessmentPassed} / ${d.assessmentFailed}',
        AppColors.primary
      ),
    ];
    return Padding(
      key: const Key('training-stats'),
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = (box.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (icon, label, value, color) in stats)
                Container(
                  width: w,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 22, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(value,
                                style:
                                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
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
    final stateColor = c.archived ? AppColors.textSecondary : (c.isActive ? AppColors.success : AppColors.warning);
    return TrainingCard(
      key: Key('training-course-${c.id}'),
      onTap: () => context.push('/dashboard/training/${c.id}', extra: c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(c.title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 8),
              TrainingBadge(label: c.stateLabel, color: stateColor),
            ],
          ),
          if (c.summaryLine.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(c.summaryLine, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _Fact(Icons.description_outlined, '${c.materialCount} material${c.materialCount == 1 ? '' : 's'}'),
              _Fact(Icons.fact_check_outlined, c.assessment?.title ?? 'No assessment'),
              _Fact(Icons.person_add_alt_outlined, '${c.assignedCount} assigned'),
              _Fact(Icons.check_circle_outline, '${c.completedCount} completed'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        ],
      );
}
