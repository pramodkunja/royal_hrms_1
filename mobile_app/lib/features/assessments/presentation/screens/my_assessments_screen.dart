import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../data/models/my_assessment_model.dart';
import '../providers/assessments_providers.dart';
import '../providers/my_assessments_providers.dart';
import '../widgets/my_assessment_card.dart';

/// My Assessments — the signed-in employee's own assignments
/// (web: app/dashboard/assessments/_components/EmployeeMyAssessments.tsx).
/// Self-service: open to every signed-in user; the server returns only the
/// caller's own assignments. Assessment management stays on
/// /dashboard/assessments behind assessments.view.
class MyAssessmentsScreen extends ConsumerWidget {
  const MyAssessmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAssessmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        // A failed refresh is shown by the screen itself (error state).
        onRefresh: () => ref
            .refresh(myAssessmentsProvider.future)
            .then((_) {}, onError: (_) {}),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            BlueHeroBanner(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Assessments',
                      style: AppTextStyles.h4.copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    'Your assigned assessments and their completion status.',
                    style: AppTextStyles.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            async.when(
              skipLoadingOnRefresh: true,
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => AppErrorState(
                title: 'Could not load your assessments',
                message: friendlyAssessmentError(e),
                onRetry: () => ref.invalidate(myAssessmentsProvider),
              ),
              data: (data) => data.assignments.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'No assessments assigned',
                      message:
                          'You have no assessments assigned at the moment. Check back later.',
                    )
                  : _MyAssessmentsBody(data: data),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyAssessmentsBody extends StatelessWidget {
  final MyAssessments data;
  const _MyAssessmentsBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final pending = data.pending;
    final completed = data.completed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            _Stat(
                label: 'Total',
                value: data.assignments.length,
                color: AppColors.primary),
            const SizedBox(width: 10),
            _Stat(
                label: 'Pending',
                value: pending.length,
                color: AppColors.warning),
            const SizedBox(width: 10),
            _Stat(
                label: 'Completed',
                value: completed.length,
                color: AppColors.success),
          ]),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionTitle('Pending (${pending.length})', Icons.schedule,
                AppColors.warning),
            for (final a in pending) _cardFor(context, a),
          ],
          if (completed.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionTitle('Completed (${completed.length})',
                Icons.check_circle_outline, AppColors.success),
            for (final a in completed) _cardFor(context, a),
          ],
        ],
      ),
    );
  }

  Widget _cardFor(BuildContext context, MyAssessmentAssignment a) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: MyAssessmentCard(
          key: ValueKey('my-assessment-${a.id}'),
          assignment: a,
          onTap: () => context.push(AppRoutes.assessmentTakePath(a.id)),
        ),
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$value',
                style: AppTextStyles.h3
                    .copyWith(color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.caption),
          ]),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _SectionTitle(this.text, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(text.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6)),
        ]),
      );
}
