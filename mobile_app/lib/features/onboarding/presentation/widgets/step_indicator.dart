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

class OnboardingStepIndicator extends StatelessWidget {
  const OnboardingStepIndicator({super.key, required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (currentStep + 1) / kTotalSteps,
              minHeight: 5,
              backgroundColor: AppColors.border.withValues(alpha: 0.4),
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Step circles
        SizedBox(
          height: 82,
          child: Row(
            children: List.generate(kTotalSteps, (i) {
              final isCurrent = i == currentStep;
              final isDone = i < currentStep;
              return Expanded(
                child: _StepDot(
                  index: i,
                  icon: kStepIcons[i],
                  label: kStepLabels[i],
                  isCurrent: isCurrent,
                  isDone: isDone,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.icon,
    required this.label,
    required this.isCurrent,
    required this.isDone,
  });

  final int index;
  final IconData icon;
  final String label;
  final bool isCurrent;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isDone
        ? const Color(0xFF22C55E)
        : isCurrent
            ? AppColors.primary
            : Colors.white;
    final Color borderColor = isDone
        ? const Color(0xFF22C55E)
        : isCurrent
            ? AppColors.primary
            : AppColors.border;
    final Color iconColor =
        (isDone || isCurrent) ? Colors.white : AppColors.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: isCurrent ? 40 : 32,
          height: isCurrent ? 40 : 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(color: borderColor, width: isCurrent ? 2.5 : 1.5),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Icon(icon, size: isCurrent ? 20 : 16, color: iconColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isDone ? 'DONE' : 'STEP ${index + 1}',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: isDone
                ? const Color(0xFF22C55E)
                : isCurrent
                    ? AppColors.primary
                    : AppColors.textSecondary,
          ),
        ),
        Text(
          kStepLabels[index],
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            color: isCurrent ? AppColors.primary : AppColors.textSecondary,
            fontWeight:
                isCurrent ? FontWeight.w600 : FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
