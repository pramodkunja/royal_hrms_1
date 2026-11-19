import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../data/models/training_models.dart';
import '../providers/training_providers.dart';
import '../widgets/training_widgets.dart';

/// My Learning (web /dashboard/my-learning): the training assigned to the
/// signed-in employee. Every signed-in user (no permission; the API returns
/// only their own assignments); hidden when the company lacks the
/// 'training' module. The six tabs filter the one list on the device, as on
/// web. This screen and the course page only read; progress is recorded only
/// once a material is opened (see MyMaterialScreen).
class MyLearningScreen extends ConsumerStatefulWidget {
  const MyLearningScreen({super.key});

  @override
  ConsumerState<MyLearningScreen> createState() => _MyLearningScreenState();
}

class _MyLearningScreenState extends ConsumerState<MyLearningScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: kMyLearningFilters.length, vsync: this)
    ..addListener(() {
      if (mounted) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(myTrainingListProvider);
    await ref.read(myTrainingListProvider.future).catchError((_) => <MyTraining>[]);
  }

  /// Empty message per tab (web: "Nothing here." / "No training has been assigned to you yet.").
  Widget _empty(TrainingStatus? filter) {
    final (message, icon) = switch (filter) {
      null => ('Courses HR assigns to you will show up here.', Icons.menu_book_outlined),
      TrainingStatus.assigned => ('Nothing is waiting to be started.', Icons.play_circle_outline),
      TrainingStatus.inProgress => ('No course is in progress right now.', Icons.timelapse),
      TrainingStatus.overdue => ('Nothing is overdue. Well done.', Icons.event_available_outlined),
      TrainingStatus.completed => ('You have not completed a course yet.', Icons.emoji_events_outlined),
      TrainingStatus.failed => ('No course has a failed assessment.', Icons.verified_outlined),
    };
    return TrainingStateView.empty(
      key: Key('my-learning-empty-${filter?.api ?? 'all'}'),
      title: filter != null ? 'Nothing here.' : 'No training has been assigned to you yet.',
      message: message,
      icon: icon,
      compact: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(myTrainingListProvider);
    final filter = kMyLearningFilters[_tabs.index].$1;
    final all = listAsync.valueOrNull;
    int count(TrainingStatus? s) => all == null ? 0 : filterMyTraining(all, s).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Pill tabs (same look as Approvals), each with its on-device count.
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textPrimary,
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            splashBorderRadius: BorderRadius.circular(22),
            labelStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
            unselectedLabelStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
            tabs: [
              for (final (s, label) in kMyLearningFilters)
                Tab(
                  key: Key('my-learning-tab-${s?.api ?? 'all'}'),
                  height: 40,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(label),
                    if (all != null) ...[
                      const SizedBox(width: 6),
                      Text('${count(s)}',
                          key: Key('my-learning-count-${s?.api ?? 'all'}'),
                          // no colour: inherits the tab's own (white on the selected pill)
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ]),
                ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: listAsync.when(
                skipLoadingOnRefresh: true,
                loading: () => const TrainingLoading('Loading your learning…'),
                error: (e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    TrainingStateView.error(e,
                        what: 'your learning', onRetry: () => ref.invalidate(myTrainingListProvider)),
                  ],
                ),
                data: (all) {
                  final rows = filterMyTraining(all, filter);
                  return LayoutBuilder(builder: (context, box) {
                    final cols = box.maxWidth >= 900 ? 3 : (box.maxWidth >= 600 ? 2 : 1);
                    const gap = 12.0;
                    final cardWidth = (box.maxWidth - 32 - gap * (cols - 1)) / cols;
                    return ListView(
                      key: const Key('my-learning-list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        Text('Training assigned to you. Open a course to watch, read and take its assessment.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        if (all.isNotEmpty) ...[const SizedBox(height: 12), _Overview(all)],
                        const SizedBox(height: 14),
                        if (rows.isEmpty) _empty(filter),
                        Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final r in rows) SizedBox(width: cardWidth, child: _MyCourseCard(training: r)),
                          ],
                        ),
                      ],
                    );
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact learning overview, counted from the list the API returned (web
/// shows no summary; these are the same status counts as its tabs).
class _Overview extends StatelessWidget {
  const _Overview(this.all);
  final List<MyTraining> all;

  @override
  Widget build(BuildContext context) {
    int n(TrainingStatus s) => all.where((r) => r.status == s).length;
    final tiles = <(IconData, Color, int, String)>[
      (Icons.menu_book_outlined, AppColors.primary, all.length, 'Assigned'),
      (Icons.timelapse, AppColors.info, n(TrainingStatus.inProgress), 'In progress'),
      (Icons.check_circle_outline, AppColors.success, n(TrainingStatus.completed), 'Completed'),
      (Icons.alarm, AppColors.warning, n(TrainingStatus.overdue), 'Overdue'),
    ];
    return Container(
      key: const Key('my-learning-overview'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(builder: (context, c) {
        // Four across when wide, two on a phone, one when large text would split the labels.
        final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
        final cols = c.maxWidth >= 520 ? 4 : (scale > 1.3 || c.maxWidth < 240 ? 1 : 2);
        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (icon, color, value, label) in tiles)
              SizedBox(
                width: w,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration:
                          BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, size: 19, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$value',
                              style:
                                  AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _MyCourseCard extends ConsumerStatefulWidget {
  const _MyCourseCard({required this.training});
  final MyTraining training;

  @override
  ConsumerState<_MyCourseCard> createState() => _MyCourseCardState();
}

class _MyCourseCardState extends ConsumerState<_MyCourseCard> {
  /// A second tap while the course page is opening (or open) does nothing, so
  /// one back press always returns to the list.
  bool _opening = false;

  MyTraining get training => widget.training;

  /// Primary action label: what the learner would do next.
  String get _action => switch (training.status) {
        TrainingStatus.assigned => 'Start',
        TrainingStatus.inProgress || TrainingStatus.overdue => 'Continue',
        TrainingStatus.completed => 'Review',
        TrainingStatus.failed => 'View',
      };

  @override
  Widget build(BuildContext context) {
    final t = training;
    final pct = t.progressPercent.clamp(0, 100);
    final overdue = t.status == TrainingStatus.overdue;
    final doneAt = t.row.completedAt;
    final completedOn = doneAt?.substring(0, doneAt.length.clamp(0, 10));
    Future<void> open() async {
      if (_opening) return;
      _opening = true;
      try {
        await context.push('/dashboard/my-learning/${t.id}', extra: t);
      } finally {
        _opening = false;
      }
    }

    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final cover = t.course.hasThumbnail;
    final badge = TrainingBadge.status(t.status);
    final title = Text(t.course.title,
        style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3));
    final description = t.course.description.trim();
    final trainer = t.course.trainerName.trim();
    final minutes = t.course.durationMinutes;
    return TrainingCard(
      key: Key('my-learning-card-${t.id}'),
      padding: EdgeInsets.zero,
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A cover only when the course has a thumbnail (web); otherwise the
          // icon sits beside the title so no space is spent on an empty band.
          if (cover)
            SizedBox(
              height: 110,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: _Thumbnail(courseId: t.course.id, hasThumbnail: true),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(builder: (context, c) {
                  final stacked = c.maxWidth < 260 || scale > 1.3;
                  final head = stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [title, const SizedBox(height: 6), badge])
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [Expanded(child: title), const SizedBox(width: 8), badge],
                        );
                  if (cover || stacked) return head;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.school_outlined, size: 22, color: AppColors.primary),
                      ),
                      Expanded(child: head),
                    ],
                  );
                }),
                if (t.course.category.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(children: [ApprovalsChip(t.course.category, icon: Icons.sell_outlined)]),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(description,
                      key: Key('my-learning-description-${t.id}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4)),
                ],
                const SizedBox(height: 10),
                // The web card line, kept whole (item count, due, start date).
                Text(t.cardLine,
                    key: Key('my-learning-line-${t.id}'),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                if (trainer.isNotEmpty || (minutes != null && minutes > 0)) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 14, runSpacing: 4, children: [
                    if (trainer.isNotEmpty) TrainingFact(Icons.person_outline, trainer),
                    if (minutes != null && minutes > 0) TrainingFact(Icons.schedule, '$minutes min'),
                  ]),
                ],
                if (overdue && t.row.dueDate != null) ...[
                  const SizedBox(height: 6),
                  TrainingFact(Icons.warning_amber_rounded, 'Was due ${t.row.dueDate}',
                      color: AppColors.warning, strong: true),
                ],
                if (t.status == TrainingStatus.completed) ...[
                  const SizedBox(height: 6),
                  TrainingFact(
                      Icons.emoji_events_outlined,
                      [
                        'Completed${completedOn == null ? '' : ' on $completedOn'}',
                        if (t.row.bestScorePercent != null) 'Best score ${t.row.bestScorePercent}%',
                      ].join(' · '),
                      color: AppColors.success,
                      strong: true),
                ],
                if (t.status == TrainingStatus.failed) ...[
                  const SizedBox(height: 6),
                  TrainingFact(Icons.block, 'Assessment not passed. HR can reset your attempts.',
                      color: AppColors.error, strong: true),
                ],
                const SizedBox(height: 12),
                TrainingProgressBar(pct, color: t.status == TrainingStatus.completed ? AppColors.success : null),
                const SizedBox(height: 6),
                LayoutBuilder(builder: (context, c) {
                  final pctText = Text('$pct% of required materials',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary));
                  final action = FilledButton(
                    key: Key('my-learning-open-${t.id}'),
                    style: trainingFilledStyle(),
                    onPressed: open,
                    child: Text(_action),
                  );
                  // Percentage and action share a line when they fit; otherwise the action drops below.
                  if (c.maxWidth < 280 || scale > 1.3) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      pctText,
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerRight, child: action),
                    ]);
                  }
                  return Row(children: [Expanded(child: pctText), const SizedBox(width: 12), action]);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The course thumbnail (web: <img> from the access-checked file URL), or
/// the school icon when there is none or it can't load.
class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.courseId, required this.hasThumbnail});
  final String courseId;
  final bool hasThumbnail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = ColoredBox(
      color: AppColors.backgroundLow,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.school_outlined, size: 30, color: AppColors.primary),
        ),
      ),
    );
    if (!hasThumbnail) return fallback;
    final bytes = ref.watch(trainingThumbnailProvider(courseId)).valueOrNull;
    if (bytes == null || bytes.isEmpty) return fallback;
    return Image.memory(bytes, fit: BoxFit.cover, excludeFromSemantics: true, errorBuilder: (_, __, ___) => fallback);
  }
}
