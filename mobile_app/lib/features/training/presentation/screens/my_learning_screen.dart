import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_error_state.dart';
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

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(myTrainingListProvider);
    final filter = kMyLearningFilters[_tabs.index].$1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Material(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                for (final (s, label) in kMyLearningFilters)
                  Tab(key: Key('my-learning-tab-${s?.api ?? 'all'}'), text: label),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: listAsync.when(
                skipLoadingOnRefresh: true,
                loading: () => Center(
                  child: Semantics(label: 'Loading', child: CircularProgressIndicator(color: AppColors.primary)),
                ),
                error: (e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [AppErrorState.forError(e, onRetry: () => ref.invalidate(myTrainingListProvider))],
                ),
                data: (all) {
                  final rows = filterMyTraining(all, filter);
                  return ListView(
                    key: const Key('my-learning-list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      Text('Training assigned to you. Open a course to watch, read and take its assessment.',
                          style: AppTextStyles.bodySecondary),
                      const SizedBox(height: 12),
                      if (rows.isEmpty)
                        TrainingNote(
                          filter != null ? 'Nothing here.' : 'No training has been assigned to you yet.',
                          icon: Icons.menu_book_outlined,
                        ),
                      for (final r in rows) _MyCourseCard(training: r),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyCourseCard extends ConsumerWidget {
  const _MyCourseCard({required this.training});
  final MyTraining training;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = training;
    final pct = t.progressPercent.clamp(0, 100);
    return TrainingCard(
      key: Key('my-learning-card-${t.id}'),
      padding: EdgeInsets.zero,
      onTap: () => context.push('/dashboard/my-learning/${t.id}', extra: t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 96,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: _Thumbnail(courseId: t.course.id, hasThumbnail: t.course.hasThumbnail),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(t.course.title,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
                    const SizedBox(width: 8),
                    TrainingBadge.status(t.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(t.cardLine, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                ExcludeSemantics(
                  // The text below states it; the bar is decorative for screen readers.
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 6,
                      backgroundColor: AppColors.backgroundLow,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('$pct% of required materials', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
      child: Center(child: Icon(Icons.school_outlined, size: 34, color: AppColors.primary)),
    );
    if (!hasThumbnail) return fallback;
    final bytes = ref.watch(trainingThumbnailProvider(courseId)).valueOrNull;
    if (bytes == null || bytes.isEmpty) return fallback;
    return Image.memory(bytes, fit: BoxFit.cover, excludeFromSemantics: true, errorBuilder: (_, __, ___) => fallback);
  }
}
