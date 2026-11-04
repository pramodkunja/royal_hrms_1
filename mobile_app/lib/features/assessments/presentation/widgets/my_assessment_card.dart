import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/my_assessment_model.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

/// "04 Nov 2026" in the device's time zone (web: en-IN day/short month), or
/// "—" when missing or unreadable.
String formatAssessmentDate(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
}

/// Status pill for a pending/in-progress assignment, or Passed/Failed for a
/// completed one (web EmployeeMyAssessments badges).
class MyAssessmentStatusChip extends StatelessWidget {
  final MyAssessmentAssignment assignment;
  const MyAssessmentStatusChip({super.key, required this.assignment});

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final (String label, Color color, IconData? icon) = a.isComplete
        ? (a.passed
            ? ('Passed', AppColors.success, Icons.check_circle_outline)
            : ('Failed', AppColors.error, Icons.cancel_outlined))
        : a.status == MyAssessmentStatus.inProgress
            ? ('In Progress', AppColors.info, null)
            : ('Pending', AppColors.textSecondary, null);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4)
        ],
        Text(label,
            style: AppTextStyles.caption.copyWith(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _Meta(this.icon, this.text, {this.color});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text,
            style: AppTextStyles.caption.copyWith(
                fontSize: 11.5,
                color: color ?? AppColors.textSecondary,
                fontWeight: color != null ? FontWeight.w600 : null)),
      ]);
}

/// One assignment in My Assessments. Pending rows show progress, the pass
/// mark, the due date and the attempt; completed rows show the completion
/// date, attempts and score — the same facts web lists.
class MyAssessmentCard extends StatelessWidget {
  final MyAssessmentAssignment assignment;
  final VoidCallback onTap;
  const MyAssessmentCard(
      {super.key, required this.assignment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final meta = a.isComplete
        ? <Widget>[
            _Meta(Icons.event_available_outlined,
                'Completed: ${formatAssessmentDate(a.completedAt)}'),
            _Meta(Icons.refresh,
                '${a.attemptCount} attempt${a.attemptCount == 1 ? '' : 's'}'),
            if (a.maxScore > 0)
              _Meta(Icons.percent,
                  'Score: ${a.scorePercent}% (pass: ${a.passPercentage}%)',
                  color: a.passed ? AppColors.success : AppColors.error),
          ]
        : <Widget>[
            _Meta(Icons.format_list_bulleted,
                '${a.completedItems}/${a.totalItems} items done'),
            _Meta(Icons.percent, '${a.passPercentage}% to pass'),
            if (a.deadline != null)
              _Meta(Icons.event_outlined,
                  'Due: ${formatAssessmentDate(a.deadline)}'),
            if (a.attemptCount > 0)
              _Meta(Icons.refresh, 'Attempt ${a.attemptCount}'),
          ];

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(a.title, style: AppTextStyles.labelLarge)),
                const SizedBox(width: 8),
                MyAssessmentStatusChip(assignment: a),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 6, children: meta),
              if (!a.isComplete && a.totalItems > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: a.progressPercent / 100,
                    minHeight: 4,
                    color: AppColors.info,
                    backgroundColor: AppColors.border,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${a.progressPercent}% complete',
                    style: AppTextStyles.caption.copyWith(fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
