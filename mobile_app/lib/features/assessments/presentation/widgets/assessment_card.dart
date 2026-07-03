import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/assessment_model.dart';
import 'assessment_card_tabs.dart';
import 'assessment_results_section.dart';

class AssessmentCard extends StatelessWidget {
  final AssessmentModel assessment;
  final bool isExpanded;
  final VoidCallback onToggleResults;
  final VoidCallback onItems;
  final VoidCallback onAssign;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AssessmentCard({
    super.key,
    required this.assessment,
    required this.isExpanded,
    required this.onToggleResults,
    required this.onItems,
    required this.onAssign,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expanded + ellipsis instead of a bare Text inside a Wrap — a
              // long, unbroken title has no width limit as a Wrap child and
              // can overflow past the card's edge instead of wrapping.
              Expanded(
                child: Text(
                  assessment.title,
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 14.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (assessment.isActive || assessment.isDefault) ...[
                const SizedBox(width: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (assessment.isActive) const _Badge(label: 'Active', color: AppColors.success, bg: AppColors.successContainer),
                    if (assessment.isDefault) const _Badge(label: 'Default', color: AppColors.info, bg: AppColors.infoContainer),
                  ],
                ),
              ],
            ],
          ),
          if (assessment.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              assessment.description,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ActionTabs(
                  isResultsActive: isExpanded,
                  onToggleResults: onToggleResults,
                  onItems: onItems,
                  onAssign: onAssign,
                ),
              ),
              const SizedBox(width: 6),
              IconOnlyChip(icon: Icons.edit_outlined, onTap: onEdit),
              const SizedBox(width: 4),
              IconOnlyChip(icon: Icons.delete_outline, color: AppColors.error, onTap: onDelete),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            MiniStatsGrid(assessment: assessment),
            const SizedBox(height: 12),
            Text('CANDIDATE RESULTS',
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textHint, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            if (assessment.candidates.isEmpty)
              const NoCandidates()
            else
              Column(
                children: assessment.candidates
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CandidateResultCard(candidate: c),
                        ))
                    .toList(),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Badges ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _Badge({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 10.5)),
    );
  }
}
