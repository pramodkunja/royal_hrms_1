import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/assessment_model.dart';

const _kMonthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')} ${_kMonthShort[d.month - 1]} ${d.year}';
}

// ── Mini stats grid (Items / Assigned / Pending / In Progress / Completed) ────

class MiniStatsGrid extends StatelessWidget {
  final AssessmentModel assessment;
  const MiniStatsGrid({super.key, required this.assessment});

  @override
  Widget build(BuildContext context) {
    final stats = [
      (label: 'Items', value: assessment.itemCount, color: AppColors.textSecondary),
      (label: 'Assigned', value: assessment.assignedCount, color: AppColors.primary),
      (label: 'Pending', value: assessment.pendingCount, color: AppColors.warning),
      (label: 'In Progress', value: assessment.inProgressCount, color: AppColors.info),
      (label: 'Completed', value: assessment.completedCount, color: AppColors.success),
    ];
    // Row of Expanded tiles (not Wrap with a fixed tile width) so the 5
    // stats always divide the card's actual width evenly in a single row —
    // a fixed-width Wrap doesn't fit 5×78px+gaps on narrower phones and
    // wraps into an uneven, cramped-looking 3+2 split.
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: stats[i].color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${stats[i].value}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: stats[i].color, height: 1)),
                  const SizedBox(height: 3),
                  Text(stats[i].label,
                      style: AppTextStyles.caption.copyWith(fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Candidate result card ──────────────────────────────────────────────────────

class CandidateResultCard extends StatelessWidget {
  final AssessmentCandidateModel candidate;
  const CandidateResultCard({super.key, required this.candidate});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (candidate.status) {
      AssessmentAssignStatus.complete => AppColors.success,
      AssessmentAssignStatus.inProgress => AppColors.info,
      _ => AppColors.textHint,
    };
    final statusBg = switch (candidate.status) {
      AssessmentAssignStatus.complete => AppColors.successContainer,
      AssessmentAssignStatus.inProgress => AppColors.infoContainer,
      _ => AppColors.backgroundMid,
    };
    final pct = candidate.scorePercentage;
    final isComplete = candidate.status == AssessmentAssignStatus.complete;
    final pctColor = !isComplete
        ? AppColors.textHint
        : (candidate.passed ? AppColors.success : AppColors.error);
    final scoreText =
        isComplete ? '${candidate.achievedScore} / ${candidate.totalQuestions}' : '—';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(candidate.assigneeName,
                              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        _AssigneeTypeBadge(type: candidate.assigneeType),
                      ],
                    ),
                    Text(candidate.assigneeEmail,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                child: Text(AssessmentAssignStatus.label(candidate.status),
                    style: AppTextStyles.labelSmall.copyWith(color: statusColor, fontWeight: FontWeight.w700, fontSize: 10.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _MetaField(label: 'Score', value: scoreText),
              _MetaField(label: 'Score %', value: pct, valueColor: pctColor),
              _MetaField(label: 'Pass Threshold', value: '${candidate.passPercentage}%'),
              _MetaField(label: 'Attempts', value: '${candidate.attemptCount}'),
              _MetaField(label: 'Assigned', value: _fmtDate(candidate.createdAt)),
              _MetaField(label: 'Completed', value: _fmtDate(candidate.completedAt)),
              if (candidate.deadline != null)
                _MetaField(label: 'Deadline', value: _fmtDate(candidate.deadline)),
            ],
          ),
        ],
      ),
    );
  }
}

// Distinguishes an internal employee assignment from an external
// recruitment-candidate one — both share the same `candidates[]` list on the
// backend (CandidateAssignment.assignee_type), but look identical in the UI
// without this badge.
class _AssigneeTypeBadge extends StatelessWidget {
  final String type;
  const _AssigneeTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isEmployee = type == AssessmentAssigneeType.employee;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.backgroundMid,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isEmployee ? Icons.badge_outlined : Icons.person_outline,
              size: 10, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(AssessmentAssigneeType.label(type),
              style: AppTextStyles.caption
                  .copyWith(fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MetaField extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _MetaField({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 9.5)),
        Text(value,
            style: AppTextStyles.labelSmall.copyWith(
                color: valueColor ?? AppColors.textPrimary, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class NoCandidates extends StatelessWidget {
  const NoCandidates({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 28, color: AppColors.textHint),
          const SizedBox(height: 6),
          Text('No candidates assigned yet.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
        ],
      ),
    );
  }
}
