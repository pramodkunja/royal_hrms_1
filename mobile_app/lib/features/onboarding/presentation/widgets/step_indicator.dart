import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

const List<String> kStepLabels = [
  'Personal',
  'Education',
  'Bank',
  'Emergency',
  'Documents',
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
              value: (currentStep + 1) / kStepLabels.length,
              minHeight: 6,
              backgroundColor: AppColors.border.withValues(alpha: 0.4),
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Step circles
        SizedBox(
          height: 64,
          child: Row(
            children: List.generate(kStepLabels.length, (i) {
              final isCurrent = i == currentStep;
              final isDone = i < currentStep;
              return Expanded(
                child: _StepDot(
                  index: i,
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
    required this.label,
    required this.isCurrent,
    required this.isDone,
  });

  final int index;
  final String label;
  final bool isCurrent;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final color = isDone || isCurrent ? AppColors.primary : AppColors.border;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isCurrent ? 34 : 28,
          height: isCurrent ? 34 : 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? AppColors.primary
                : isCurrent
                    ? AppColors.primary
                    : Colors.white,
            border: Border.all(color: color, width: isCurrent ? 2.5 : 1.5),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: isCurrent ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isCurrent ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
