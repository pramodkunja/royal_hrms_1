import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/models/assessment_portal_models.dart';
import '../../data/models/my_assessment_model.dart';
import 'my_assessment_card.dart';
import 'my_assessment_facts.dart';

/// Before an attempt: what it contains and how it works, from the server's
/// assignment data and the backend's rules. Start is unavailable (with the
/// reason) when [blockedReason] is set.
class AssessmentInstructionsView extends StatelessWidget {
  final MyAssessmentAssignment assignment;
  final String? blockedReason;
  final VoidCallback onStart;

  const AssessmentInstructionsView({
    super.key,
    required this.assignment,
    required this.blockedReason,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final quizzes =
        a.items.where((i) => i.type == AssessmentItemType.quiz).length;
    final videos = a.items.length - quizzes;
    final rules = <String>[
      'Work through the items in order. Each answer is saved as soon as you submit it and can\'t be changed afterwards.',
      if (videos > 0)
        'For a video, open it, watch it, then mark it as watched.',
      'When every item is done, submit the assessment to get your score.',
      'You need ${a.passPercentage}% to pass.',
      if (a.timeLimitMins != null)
        'You have ${a.timeLimitMins} minutes from your first answer. When the time runs out, the assessment is submitted automatically.',
      if (a.deadline != null)
        'Submit before ${formatAssessmentDate(a.deadline)}.',
      a.effectiveMaxAttempts == 0
          ? 'If you don\'t pass, you can retake it.'
          : 'If you don\'t pass, you can retake it while attempts remain (${a.effectiveMaxAttempts} in total).',
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(a.title, style: AppTextStyles.h3)),
          const SizedBox(width: 8),
          MyAssessmentStatusChip(assignment: a),
        ]),
        const SizedBox(height: 6),
        Text(
          [
            if (quizzes > 0) '$quizzes question${quizzes == 1 ? '' : 's'}',
            if (videos > 0) '$videos video${videos == 1 ? '' : 's'}',
          ].join(' · '),
          style: AppTextStyles.bodySecondary,
        ),
        const SizedBox(height: 16),
        _Card(child: MyAssessmentFacts(assignment: a, showHeader: false)),
        const SizedBox(height: 12),
        _Card(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Before you start', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            for (final r in rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: Icon(Icons.circle,
                            size: 6, color: AppColors.textSecondary),
                      ),
                      Expanded(child: Text(r, style: AppTextStyles.body)),
                    ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        if (blockedReason != null) ...[
          Container(
            key: const Key('assessment-blocked'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.block, size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(blockedReason!,
                    style: AppTextStyles.body.copyWith(color: AppColors.error)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        AppButton(
          label: a.items.isEmpty ? 'No items to take' : 'Start assessment',
          leadingIcon: Icons.play_arrow_rounded,
          onPressed:
              blockedReason == null && a.items.isNotEmpty ? onStart : null,
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}
