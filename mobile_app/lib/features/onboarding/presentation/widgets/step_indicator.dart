import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// kStepMeta is defined in onboarding_steps.dart (part file of onboarding_screen.dart).
// Re-export only the count here for use in the indicator.
const int kTotalSteps = 5;

const List<String> kStepLabels = [
  'Personal',
  'Education',
  'Bank',
  'Emergency',
  'Documents',
];

const List<IconData> kStepIcons = [
  Icons.person_outline,
  Icons.school_outlined,
  Icons.account_balance_outlined,
  Icons.contact_emergency_outlined,
  Icons.folder_copy_outlined,
];

/// Connected step-circle wizard: a single line linking every circle fills up
/// to however far the user has progressed. The current step additionally
/// carries a soft secondary-colour halo so all three theme accents (primary
/// for progress, secondary for "you are here", success for done) read
/// intentionally rather than as one flat brand colour throughout.
class OnboardingStepIndicator extends StatelessWidget {
  const OnboardingStepIndicator({super.key, required this.currentStep});

  final int currentStep;

  static const double _circleSize = 38;
  static const double _haloSize = 50;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Step ${currentStep + 1} of $kTotalSteps',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const Spacer(),
            Text(
              '${(((currentStep) / (kTotalSteps - 1)) * 100).round()}% complete',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: _haloSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: _haloSize / 2,
                right: _haloSize / 2,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Positioned(
                left: _haloSize / 2,
                right: _haloSize / 2,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: currentStep / (kTotalSteps - 1),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(kTotalSteps, (i) {
                    return _StepCircle(
                      icon: kStepIcons[i],
                      isCurrent: i == currentStep,
                      isDone: i < currentStep,
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(kTotalSteps, (i) {
            final isCurrent = i == currentStep;
            final isDone = i < currentStep;
            return Expanded(
              child: Text(
                kStepLabels[i],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isCurrent
                      ? AppColors.primary
                      : (isDone ? AppColors.success : AppColors.textHint),
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.icon,
    required this.isCurrent,
    required this.isDone,
  });

  final IconData icon;
  final bool isCurrent;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final Color bg = isDone
        ? AppColors.success
        : isCurrent
            ? AppColors.primary
            : AppColors.surface;
    final Color borderColor = isDone
        ? AppColors.success
        : (isCurrent ? AppColors.primary : AppColors.border);
    final Color iconColor =
        (isDone || isCurrent) ? Colors.white : AppColors.textHint;

    final circle = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: OnboardingStepIndicator._circleSize,
      height: OnboardingStepIndicator._circleSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: borderColor, width: isCurrent ? 0 : 1.5),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Icon(
        isDone ? Icons.check_rounded : icon,
        size: 17,
        color: iconColor,
      ),
    );

    if (!isCurrent) return circle;

    // Secondary-tinted halo marks "you are here" distinctly from "done".
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: OnboardingStepIndicator._haloSize,
      height: OnboardingStepIndicator._haloSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondary.withValues(alpha: 0.16),
      ),
      alignment: Alignment.center,
      child: circle,
    );
  }
}
