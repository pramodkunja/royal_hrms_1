import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/onboarding_entity.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/step_indicator.dart';

part '../widgets/onboarding_steps.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(onboardingProfileProvider);
    final currentStep = ref.watch(onboardingStepProvider);

    void goBack() {
      if (currentStep > 0) {
        ref.read(onboardingStepProvider.notifier).state = currentStep - 1;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Complete Your Profile',
              style: AppTextStyles.label
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            Text(
              'Step ${currentStep + 1} of $kTotalSteps — ${kStepLabels[currentStep]}',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Logout'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          OnboardingStepIndicator(currentStep: currentStep),
          const SizedBox(height: 8),
          Expanded(
            child: profileAsync.when(
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => _ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(onboardingProfileProvider),
              ),
              data: (profile) => _StepContent(
                profile: profile,
                currentStep: currentStep,
                onPrevious: currentStep > 0 ? goBack : null,
                onStepSaved: (step, data) async {
                  final err = await ref
                      .read(onboardingProfileProvider.notifier)
                      .saveStep(step, data);
                  if (err == null && context.mounted) {
                    if (step < kTotalSteps - 1) {
                      ref.read(onboardingStepProvider.notifier).state =
                          step + 1;
                    }
                  }
                  return err;
                },
                onUpload: (docType) async {
                  return await ref
                      .read(onboardingProfileProvider.notifier)
                      .uploadDocument(
                          docType,
                          const OnboardingDocUploadRequest(null));
                },
                onDelete: (id) async {
                  return await ref
                      .read(onboardingProfileProvider.notifier)
                      .deleteDocument(id);
                },
                onSaveDraft: () async {
                  // Save draft calls step 4 with empty data (no submit)
                  await ref
                      .read(onboardingProfileProvider.notifier)
                      .saveStep(4, {});
                },
                onSubmit: () async {
                  final err = await ref
                      .read(onboardingProfileProvider.notifier)
                      .submitProfile();
                  if (err == null && context.mounted) {
                    context.go(AppRoutes.onboardingAwaiting);
                  } else if (err != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(err),
                        backgroundColor: AppColors.error));
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({
    required this.profile,
    required this.currentStep,
    required this.onPrevious,
    required this.onStepSaved,
    required this.onUpload,
    required this.onDelete,
    required this.onSaveDraft,
    required this.onSubmit,
  });

  final OnboardingProfileEntity profile;
  final int currentStep;
  final VoidCallback? onPrevious;
  final Future<String?> Function(int step, Map<String, dynamic> data)
      onStepSaved;
  final Future<String?> Function(String docType) onUpload;
  final Future<String?> Function(int id) onDelete;
  final Future<void> Function() onSaveDraft;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    switch (currentStep) {
      case 0:
        return _PersonalStep(
          initial: profile.personal,
          onSave: (data) => onStepSaved(0, data),
          onPrevious: onPrevious,
        );
      case 1:
        return _EducationStep(
          initial: profile.education,
          onSave: (data) => onStepSaved(1, data),
          onPrevious: onPrevious,
        );
      case 2:
        return _BankStep(
          initial: profile.bank,
          onSave: (data) => onStepSaved(2, data),
          onPrevious: onPrevious,
        );
      case 3:
        return _EmergencyStep(
          initial: profile.emergency,
          onSave: (data) => onStepSaved(3, data),
          onPrevious: onPrevious,
        );
      case 4:
        return _DocumentsStep(
          documents: profile.documents,
          onUpload: onUpload,
          onDelete: onDelete,
          onSaveDraft: onSaveDraft,
          onSubmit: onSubmit,
          onPrevious: onPrevious,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
