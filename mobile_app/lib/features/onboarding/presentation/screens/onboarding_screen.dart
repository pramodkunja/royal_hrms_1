import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/validators/form_validators.dart';
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
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingHeader(
              currentStep: currentStep,
              onLogout: () async {
                await ref.read(authStateProvider.notifier).logout();
              },
            ),
            Expanded(
              child: profileAsync.when(
                loading: () => Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
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
                  onUpload: (docType, file) async {
                    final multipart = MultipartFile.fromBytes(
                      file.bytes!,
                      filename: file.name,
                    );
                    return await ref
                        .read(onboardingProfileProvider.notifier)
                        .uploadDocument(docType, multipart);
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
      ),
    );
  }
}

/// Custom header replacing a flat AppBar: an icon badge + title/subtitle
/// row, a compact logout action, and the connected step wizard — all
/// grouped into one visually distinct panel above the scrollable form.
class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.currentStep,
    required this.onLogout,
  });

  final int currentStep;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            boxShadow: AppColors.elevatedShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.badge_outlined,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete Your Profile',
                      style: AppTextStyles.h3.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      kStepLabels[currentStep],
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white.withValues(alpha: 0.82)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onLogout,
                tooltip: 'Logout',
                icon: const Icon(Icons.logout_rounded,
                    color: Colors.white, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.cardShadow,
          ),
          child: OnboardingStepIndicator(currentStep: currentStep),
        ),
      ],
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
  final Future<String?> Function(String docType, PlatformFile file) onUpload;
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
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message,
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
