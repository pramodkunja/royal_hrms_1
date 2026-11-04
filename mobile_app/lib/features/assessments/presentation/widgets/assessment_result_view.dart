import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';

/// The graded attempt (web CompletionModal): score, percentage, pass/fail and
/// the pass mark, exactly as the server returned them. Retake appears only
/// when the server's rules still allow another attempt.
class AssessmentResultView extends StatelessWidget {
  final String title;
  final int score;
  final int maxScore;
  final int percentage;
  final int passPercentage;
  final bool passed;
  final int attemptNumber;
  final String? completedOn;

  /// null hides Retake.
  final VoidCallback? onRetake;
  final bool retaking;
  final String? retakeError;
  final String doneLabel;
  final VoidCallback onDone;

  const AssessmentResultView({
    super.key,
    required this.title,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.passPercentage,
    required this.passed,
    required this.attemptNumber,
    this.completedOn,
    required this.onRetake,
    required this.retaking,
    required this.retakeError,
    required this.doneLabel,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final color = passed ? AppColors.success : AppColors.error;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      children: [
        Center(
          child: SizedBox(
            width: 140,
            height: 140,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: (percentage.clamp(0, 100)) / 100,
                  strokeWidth: 10,
                  color: color,
                  backgroundColor: AppColors.border,
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$score', style: AppTextStyles.h2),
                Text('/ $maxScore', style: AppTextStyles.caption),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Container(
            key: const Key('assessment-result-badge'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: passed
                  ? AppColors.successContainer
                  : AppColors.errorContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(passed ? 'Passed' : 'Not Passed',
                style: AppTextStyles.label
                    .copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 10),
        Center(child: Text('$percentage% Score', style: AppTextStyles.h3)),
        const SizedBox(height: 4),
        Center(
          child: Text('Pass mark $passPercentage% · Attempt #$attemptNumber',
              style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
        ),
        if (completedOn != null) ...[
          const SizedBox(height: 2),
          Center(
              child:
                  Text('Completed $completedOn', style: AppTextStyles.caption)),
        ],
        Center(
            child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(title, style: AppTextStyles.caption))),
        const SizedBox(height: 28),
        if (retakeError != null) ...[
          Text(retakeError!,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.error)),
          const SizedBox(height: 10),
        ],
        if (onRetake != null) ...[
          AppButton(
            label: 'Retake assessment',
            leadingIcon: Icons.refresh,
            isLoading: retaking,
            onPressed: retaking ? null : onRetake,
          ),
          const SizedBox(height: 10),
        ],
        AppButton(
          label: doneLabel,
          variant: onRetake != null
              ? AppButtonVariant.outline
              : AppButtonVariant.filled,
          onPressed: retaking ? null : onDone,
        ),
      ],
    );
  }
}
