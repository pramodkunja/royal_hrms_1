import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../../../shared/widgets/stat_card.dart';
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
            assessmentsAsync.when(
              // SliverToBoxAdapter (not SliverFillRemaining) for every
              // non-list state — SliverFillRemaining centers its child in
              // the *entire* remaining viewport, which on a tall phone
              // strands a small card in a sea of blank space no matter how
              // it's styled. Sizing to actual content keeps it anchored
              // under the header like the populated list is.
              loading: () => const SliverToBoxAdapter(
                child: Column(children: [_Header(), _LoadingView()]),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Column(
                  children: [
                    const _Header(),
                    _ErrorView(
                      message: e.toString(),
                      onRetry: () => ref.invalidate(assessmentsProvider),
                    ),
                  ],
                ),
              ),
              data: (assessments) => assessments.isEmpty
                  ? SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const _Header(),
                          _EmptyView(onAdd: () => _openForm(null)),
                        ],
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildListDelegate([
                        // Hero, then stats in normal flow below it (not
                        // overlapping) — the overlap trick relied on a
                        // hardcoded hero height that undershot the real
                        // rendered height of wrapping text, which visibly
                        // covered the description and let it spill out past
                        // the hero's rounded bottom. Matches the safe
                        // pattern every other hero'd screen already uses.
                        const _Header(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _OverallStatsRow(assessments: assessments),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          child: Column(
                            children: assessments
                                .map((a) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: AssessmentCard(
                                        assessment: a,
                                        isExpanded: _expandedId == a.id,
                                        onToggleResults: () => setState(
                                          () => _expandedId =
                                              _expandedId == a.id ? null : a.id,
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
      // Only shown once there's at least one assessment — the empty state
      // already has its own "Create Assessment" button front and center, so
      // showing this FAB too just duplicated the same action twice on one
      // screen. Once the list is non-empty, this becomes the quick way to
      // add another without scrolling back to the top.
      floatingActionButton: assessmentsAsync.maybeWhen(
        data: (assessments) => assessments.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _openForm(null),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('New Assessment',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
        orElse: () => null,
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
    if (mounted)
      await ref.read(assessmentsProvider.notifier).refreshOne(assessment.id);
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
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await ref
        .read(assessmentsProvider.notifier)
        .removeAssessment(assessment.id);
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
    return BlueHeroBanner(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_outlined,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Build pre-onboarding assessments and assign them to candidates.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySecondary
                    .copyWith(color: Colors.white.withValues(alpha: 0.9)),
              ),
            ),
          ),
        ],
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
    final assigned =
        assessments.fold<int>(0, (sum, a) => sum + a.assignedCount);
    final pending = assessments.fold<int>(0, (sum, a) => sum + a.pendingCount);
    final inProgress =
        assessments.fold<int>(0, (sum, a) => sum + a.inProgressCount);
    final completed =
        assessments.fold<int>(0, (sum, a) => sum + a.completedCount);

    final stats = [
      // The total assessment count from the backend wasn't surfaced
      // anywhere in this row before — only the per-candidate aggregates
      // were shown.
      (
        label: 'Total Assessments',
        value: assessments.length,
        icon: Icons.fact_check_outlined,
        color: const Color(0xFF1E4E8C)
      ),
      (
        label: 'Total Assigned',
        value: assigned,
        icon: Icons.people_outline,
        color: AppColors.primary
      ),
      (
        label: 'Pending',
        value: pending,
        icon: Icons.access_time,
        color: AppColors.warning
      ),
      (
        label: 'In Progress',
        value: inProgress,
        icon: Icons.edit_outlined,
        color: AppColors.info
      ),
      (
        label: 'Completed',
        value: completed,
        icon: Icons.check_circle_outline,
        color: AppColors.success
      ),
    ];

    // Shared StatCard/StatCardRow — same visual design as the Employees
    // screen's directory-stats strip (148-wide cards, 40x40 icon tile,
    // fontSize 22 count). Values/icons/colors unchanged, only the card
    // chrome now matches the rest of the app.
    return StatCardRow(
      cards: stats
          .map((s) => StatCard(
                icon: s.icon,
                count: s.value,
                label: s.label,
                color: s.color,
              ))
          .toList(),
    );
  }
}

// ── Loading / Empty / Error ──────────────────────────────────────────────────
//
// All three share _StateCard for their outer chrome (radius, padding,
// border, shadow) so they read as one consistent design instead of three
// separately hand-rolled layouts — the same card language AssessmentCard
// and _OverallStatsRow's tiles already use elsewhere on this screen.

class _StateCard extends StatelessWidget {
  final Widget child;
  const _StateCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: child,
      ),
    );
  }
}

/// A round icon badge with a soft gradient fill — shared by the loading/
/// empty/error states so each is distinguished only by its color and icon,
/// not by three different treatments.
class _StateIconBadge extends StatelessWidget {
  final Widget child;
  final Color color;
  const _StateIconBadge({required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.06)
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(child: child),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StateIconBadge(
            color: AppColors.primary,
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 18),
          Text('Loading assessments…', style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StateIconBadge(
            color: AppColors.primary,
            child: Icon(Icons.assignment_outlined,
                size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text('No assessments yet',
              style: AppTextStyles.h3, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Create your first assessment to assign to candidates during onboarding.',
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Assessment'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
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
    return _StateCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StateIconBadge(
            color: AppColors.error,
            child: Icon(Icons.cloud_off_outlined,
                size: 30, color: AppColors.error),
          ),
          const SizedBox(height: 20),
          Text('Could not load assessments',
              style: AppTextStyles.h3, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message,
              style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
