import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../facial_recognition/domain/entities/face_registration_entity.dart';
import '../../../facial_recognition/presentation/controllers/face_registration_controller.dart';
import '../../../facial_recognition/presentation/providers/facial_recognition_providers.dart';
import '../../../facial_recognition/presentation/state/face_registration_state.dart';
import '../../../facial_recognition/presentation/widgets/face_capture_bottom_sheet.dart';
import '../../../facial_recognition/presentation/widgets/face_consent_text.dart';
import '../../../settings/data/models/onboarding_field_config_model.dart';
import '../../data/models/onboarding_config_models.dart';
import '../../domain/entities/onboarding_entity.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/onboarding_custom_file_field.dart';
import '../widgets/onboarding_dynamic_field.dart';
import '../widgets/step_indicator.dart';

part '../widgets/onboarding_steps.dart';
part '../widgets/onboarding_configured_step.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(onboardingProfileProvider);
    // The admin-configured fields/document types and uploaded custom files.
    final configAsync = ref.watch(onboardingConfigProvider);
    final customFilesAsync = ref.watch(onboardingCustomFilesProvider);
    final currentStep = ref.watch(onboardingStepProvider);
    // Defaults to false while the toggle is still loading, same as web's
    // useState(false) before its own fetch resolves — see FACE_STEP in
    // app/onboarding/page.tsx.
    final includeFaceStep =
        ref.watch(faceVerificationStatusProvider).valueOrNull?.isMandatory ?? false;
    final totalSteps = includeFaceStep ? kTotalSteps + 1 : kTotalSteps;

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
              includeFaceStep: includeFaceStep,
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
                data: (profile) => configAsync.hasError || customFilesAsync.hasError
                    ? _ErrorView(
                        message: 'Could not load the onboarding form. Please try again.',
                        onRetry: () {
                          ref.invalidate(onboardingConfigProvider);
                          ref.invalidate(onboardingCustomFilesProvider);
                        },
                      )
                    : !configAsync.hasValue || !customFilesAsync.hasValue
                        ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : _StepContent(
                  profile: profile,
                  config: configAsync.requireValue,
                  customFiles: customFilesAsync.requireValue,
                  onConfiguredSaved: (step) {
                    if (step < totalSteps - 1) {
                      ref.read(onboardingStepProvider.notifier).state = step + 1;
                    }
                  },
                  currentStep: currentStep,
                  includeFaceStep: includeFaceStep,
                  onPrevious: currentStep > 0 ? goBack : null,
                  onContinueToFaceStep: () =>
                      ref.read(onboardingStepProvider.notifier).state = kTotalSteps,
                  onUpload: (docType, file) async {
                    final mime = onboardingUploadMime(file.name);
                    final multipart = MultipartFile.fromBytes(
                      file.bytes!,
                      filename: file.name,
                      // The server checks the part's content type.
                      contentType: mime == null ? null : DioMediaType.parse(mime),
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
                  onSavePan: (pan) =>
                      ref.read(onboardingProfileProvider.notifier).savePanNumber(pan),
                  onSaveDraft: () =>
                      ref.read(onboardingProfileProvider.notifier).saveDocumentsDraft(),
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
    required this.includeFaceStep,
    required this.onLogout,
  });

  final int currentStep;
  final bool includeFaceStep;
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
                      currentStep < kTotalSteps ? kStepLabels[currentStep] : kFaceStepLabel,
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
          child: OnboardingStepIndicator(currentStep: currentStep, includeFaceStep: includeFaceStep),
        ),
      ],
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({
    required this.profile,
    required this.currentStep,
    required this.includeFaceStep,
    required this.onPrevious,
    required this.onContinueToFaceStep,
    required this.onUpload,
    required this.onDelete,
    required this.onSaveDraft,
    required this.onSavePan,
    required this.onSubmit,
    required this.config,
    required this.customFiles,
    required this.onConfiguredSaved,
  });

  final OnboardingConfig config;
  final List<CustomFileValue> customFiles;
  final void Function(int step) onConfiguredSaved;
  final OnboardingProfileEntity profile;
  final int currentStep;
  final bool includeFaceStep;
  final VoidCallback? onPrevious;
  final VoidCallback onContinueToFaceStep;
  final Future<String?> Function(String docType, PlatformFile file) onUpload;
  final Future<String?> Function(int id) onDelete;
  final Future<({bool ok, String message})> Function() onSaveDraft;
  final Future<String?> Function(String pan) onSavePan;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    switch (currentStep) {
      case 0:
      case 1:
      case 2:
      case 3:
        return _ConfiguredStep(
          key: ValueKey('configured-step-$currentStep'),
          step: currentStep,
          fields: config.fieldsFor(currentStep),
          values: profile.values,
          customFiles: customFiles,
          onSaved: () => onConfiguredSaved(currentStep),
          onPrevious: onPrevious,
        );
      case 4:
        return _DocumentsStep(
          documentTypes: config.visibleDocumentTypes,
          panNumber: profile.values['pan_number'] ?? '',
          onSavePan: onSavePan,
          documents: profile.documents,
          onUpload: onUpload,
          onDelete: onDelete,
          onSaveDraft: onSaveDraft,
          onSubmit: onSubmit,
          onPrevious: onPrevious,
          hasFaceStep: includeFaceStep,
          onContinueToFaceStep: onContinueToFaceStep,
        );
      case 5:
        if (!includeFaceStep) return const SizedBox.shrink();
        return _FaceIdStep(
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
