import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/my_assessment_model.dart';
import '../providers/assessment_take_providers.dart';
import '../providers/assessments_providers.dart';
import '../providers/my_assessments_providers.dart';
import '../widgets/my_assessment_card.dart';

/// The onboarding assessment gate (web: /onboarding/assessments). Employees
/// whose onboarding was approved but who still have an assessment pending
/// land here (see resolveAuthRedirect) and can only take their assessments
/// or log out. Each time the list loads, the server is asked whether the
/// requirement is met (syncAssessmentGate); only its confirmation lifts the
/// gate. Retry and Log out are always available, so a failed request can
/// never trap anyone.
class AssessmentGateScreen extends ConsumerWidget {
  const AssessmentGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<MyAssessments>>(myAssessmentsProvider, (_, next) {
      final data = next.valueOrNull;
      if (data != null && !next.isLoading) {
        ref.read(assessmentGateSyncProvider)(list: data);
      }
    });
    final async = ref.watch(myAssessmentsProvider);
    final gated =
        ref.watch(authStateProvider).valueOrNull?.user?.needsAssessments ??
            false;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => ref
                .refresh(myAssessmentsProvider.future)
                .then((_) {}, onError: (_) {}),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              children: [
                Icon(Icons.assignment_outlined,
                    size: 40, color: AppColors.primary),
                const SizedBox(height: 12),
                Text('Complete your assessments', style: AppTextStyles.h3),
                const SizedBox(height: 6),
                Text(
                  gated
                      ? 'Your onboarding is approved. Complete the assessments below to continue to Royal HRMS.'
                      : 'All your assessments are complete.',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 20),
                if (!gated) ...[
                  AppButton(
                    key: const Key('assessment-gate-continue'),
                    label: 'Continue to Dashboard',
                    leadingIcon: Icons.arrow_forward,
                    onPressed: () => context.go(AppRoutes.dashboard),
                  ),
                  const SizedBox(height: 20),
                ],
                async.when(
                  skipLoadingOnRefresh: true,
                  loading: () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => AppErrorState(
                    title: 'Could not load your assessments',
                    message: friendlyAssessmentError(e),
                    onRetry: () => ref.invalidate(myAssessmentsProvider),
                  ),
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final a in [...data.pending, ...data.completed])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: MyAssessmentCard(
                            key: ValueKey('gate-assessment-${a.id}'),
                            assignment: a,
                            onTap: () => context
                                .push(AppRoutes.assessmentTakePath(a.id)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(authStateProvider.notifier).logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
