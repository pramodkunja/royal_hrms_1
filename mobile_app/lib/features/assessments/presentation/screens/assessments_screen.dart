import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/assessment_model.dart';
import '../providers/assessments_providers.dart';
import '../widgets/assessment_card.dart';
import '../widgets/assessment_form_dialog.dart';
import '../widgets/assign_dialog.dart';
import '../widgets/items_manager_dialog.dart';

class AssessmentsScreen extends ConsumerStatefulWidget {
  const AssessmentsScreen({super.key});

  @override
  ConsumerState<AssessmentsScreen> createState() => _AssessmentsScreenState();
}

class _AssessmentsScreenState extends ConsumerState<AssessmentsScreen> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final assessmentsAsync = ref.watch(assessmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.refresh(assessmentsProvider.future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _Header()),
            assessmentsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: _ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(assessmentsProvider),
                ),
              ),
              data: (assessments) => assessments.isEmpty
                  ? SliverFillRemaining(child: _EmptyView(onAdd: () => _openForm(null)))
                  : SliverList(
                      delegate: SliverChildListDelegate([
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _OverallStatsRow(assessments: assessments),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          child: Column(
                            children: assessments
                                .map((a) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: AssessmentCard(
                                        assessment: a,
                                        isExpanded: _expandedId == a.id,
                                        onToggleResults: () => setState(
                                          () => _expandedId = _expandedId == a.id ? null : a.id,
                                        ),
                                        onItems: () => _openItems(a),
                                        onAssign: () => _openAssign(a),
                                        onEdit: () => _openForm(a),
                                        onDelete: () => _confirmDelete(a),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ]),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Assessment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _openForm(AssessmentModel? assessment) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: AssessmentFormDialog(assessment: assessment, ref: ref),
      ),
    );
  }

  Future<void> _openItems(AssessmentModel assessment) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ItemsManagerDialog(assessment: assessment),
      ),
    );
    // Item counts (item_count) shown on the card can change after managing
    // items — refresh this assessment's row so the counter stays accurate.
    if (mounted) await ref.read(assessmentsProvider.notifier).refreshOne(assessment.id);
  }

  Future<void> _openAssign(AssessmentModel assessment) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: AssignDialog(assessment: assessment, ref: ref),
      ),
    );
  }

  Future<void> _confirmDelete(AssessmentModel assessment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Assessment?'),
        content: Text('Delete "${assessment.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await ref.read(assessmentsProvider.notifier).removeAssessment(assessment.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? '"${assessment.title}" deleted.'),
      backgroundColor: error == null ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
    if (error == null && _expandedId == assessment.id) {
      setState(() => _expandedId = null);
    }
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Text(
        'Build pre-onboarding assessments and assign them to candidates.',
        style: AppTextStyles.bodySecondary,
      ),
    );
  }
}

// ── Overall stats row ────────────────────────────────────────────────────────

class _OverallStatsRow extends StatelessWidget {
  final List<AssessmentModel> assessments;
  const _OverallStatsRow({required this.assessments});

  @override
  Widget build(BuildContext context) {
    final assigned = assessments.fold<int>(0, (sum, a) => sum + a.assignedCount);
    final pending = assessments.fold<int>(0, (sum, a) => sum + a.pendingCount);
    final inProgress = assessments.fold<int>(0, (sum, a) => sum + a.inProgressCount);
    final completed = assessments.fold<int>(0, (sum, a) => sum + a.completedCount);

    final stats = [
      (label: 'Total Assigned', value: assigned, icon: Icons.people_outline, color: AppColors.primary),
      (label: 'Pending', value: pending, icon: Icons.access_time, color: AppColors.warning),
      (label: 'In Progress', value: inProgress, icon: Icons.edit_outlined, color: AppColors.info),
      (label: 'Completed', value: completed, icon: Icons.check_circle_outline, color: AppColors.success),
    ];

    return SizedBox(
      // Tall enough for icon (26) + number (20, height:1) + gap (6) + label
      // (~15) + vertical padding (24) with margin to spare — a tighter box
      // here previously clipped the label by a few px on some font metrics.
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = stats[i];
          return Container(
            width: 130,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: s.color.withValues(alpha: 0.18)),
              boxShadow: [BoxShadow(color: s.color.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(color: s.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
                  child: Icon(s.icon, size: 14, color: s.color),
                ),
                const SizedBox(height: 8),
                Text('${s.value}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: s.color, height: 1)),
                const SizedBox(height: 4),
                Text(s.label, style: AppTextStyles.caption.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.assignment_outlined, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('No assessments yet', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              'Create your first assessment to assign to candidates during onboarding.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Assessment'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('Could not load assessments', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
