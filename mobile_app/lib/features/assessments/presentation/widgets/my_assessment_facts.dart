import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/my_assessment_model.dart';
import 'my_assessment_card.dart';

/// The facts of one assignment — status, progress, pass mark, score,
/// attempts, time limit, due and completion dates — all from the server's
/// response. Shown on the assessment's instructions and result screens.
class MyAssessmentFacts extends StatelessWidget {
  final MyAssessmentAssignment assignment;

  /// Hide the title row when the host screen already shows it.
  final bool showHeader;
  const MyAssessmentFacts(
      {super.key, required this.assignment, this.showHeader = true});

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final rows = <(String, String)>[
      ('Status', a.status.label),
      ('Progress', '${a.completedItems} of ${a.totalItems} items'),
      ('Pass mark', '${a.passPercentage}%'),
      if (a.isComplete && a.maxScore > 0)
        ('Score', '${a.scorePercent}% (${a.score}/${a.maxScore})'),
      ('Attempts used', '${a.attemptCount}'),
      (
        'Attempts allowed',
        a.effectiveMaxAttempts == 0 ? 'Unlimited' : '${a.effectiveMaxAttempts}'
      ),
      if (a.attemptsRemaining != null)
        ('Attempts remaining', '${a.attemptsRemaining}'),
      if (a.timeLimitMins != null) ('Time limit', '${a.timeLimitMins} min'),
      if (a.deadline != null) ('Due', formatAssessmentDate(a.deadline)),
      if (a.completedAt != null)
        ('Completed', formatAssessmentDate(a.completedAt)),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(a.title, style: AppTextStyles.h4)),
            const SizedBox(width: 8),
            MyAssessmentStatusChip(assignment: a),
          ]),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 6),
        ],
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Text(label, style: AppTextStyles.bodySecondary)),
              Text(value,
                  style:
                      AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
    );
  }
}
