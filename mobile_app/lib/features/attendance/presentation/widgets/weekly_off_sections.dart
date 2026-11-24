import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart';
import '../../data/models/weekly_off_assignment_models.dart';

// Building blocks of the redesigned Weekly Off Assignment tab: a titled section
// card, a labelled value, and the per-employee assignment card. Presentation
// only; every rule (who can assign, what is sent) stays in the tab and sheets.

/// True when the layout should stack instead of sitting side by side.
bool weeklyOffCompact(BuildContext context, double width) =>
    width < 420 || MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;

/// How many equal columns [width] holds when each needs at least [minColumn].
int weeklyOffColumns(double width, double minColumn, {int max = 4}) {
  final n = ((width + 12) / (minColumn + 12)).floor();
  return n.clamp(1, max);
}

/// Children laid out in [columns] equal columns (wrapping rows).
class WeeklyOffGrid extends StatelessWidget {
  const WeeklyOffGrid({super.key, required this.columns, required this.children, this.gap = 12});
  final int columns;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]],
      ]);
    }
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final child in children) SizedBox(width: w, child: child),
      ]);
    });
  }
}

/// A titled card: icon tile, heading, optional helper line, then the body.
class WeeklyOffSection extends StatelessWidget {
  const WeeklyOffSection({super.key, required this.icon, required this.title, this.subtitle, required this.child});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ApprovalsIconBox(icon, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Semantics(header: true, child: Text(title, style: AppTextStyles.h4.copyWith(fontSize: 15))),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

/// Small caption over a value (wraps, never ellipsized).
class WeeklyOffField extends StatelessWidget {
  const WeeklyOffField(this.label, this.value, {super.key, this.strong = false});
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 1),
        Text(value,
            style: AppTextStyles.bodySmall.copyWith(
                fontSize: 13, fontWeight: strong ? FontWeight.w600 : FontWeight.w500, color: AppColors.textPrimary)),
      ]);
}

/// One employee's weekly-off assignment (web table row): who, status, the
/// current pattern with its dates, and the Assign / Change action.
class WeeklyOffAssignmentCard extends StatelessWidget {
  const WeeklyOffAssignmentCard({super.key, required this.row, required this.canAssign, required this.onAssign});
  final WeeklyOffAssignmentRow row;
  final bool canAssign;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final who = [row.employeeId, row.department, row.branch].where((s) => s.isNotEmpty).join(' · ');
    final tone = row.isAssigned ? ApprovalsTone.success : ApprovalsTone.neutral;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, c) {
          final identity = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.employeeName, style: AppTextStyles.bodySmall.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
            if (who.isNotEmpty)
              Text(who, style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary)),
          ]);
          final badge = ApprovalsBadge(row.status, tone);
          // The status pill drops under the name when the row would be cramped.
          if (MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3 || c.maxWidth < 260) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              identity,
              const SizedBox(height: 6),
              badge,
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: identity),
            const SizedBox(width: 8),
            badge,
          ]);
        }),
        const SizedBox(height: 10),
        Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 10),
        // Web: pattern_name ?? "—"
        WeeklyOffField('Weekly off pattern', row.patternName ?? '—',
            strong: true, key: Key('wo-pattern-${row.employeeId}')),
        const SizedBox(height: 8),
        Wrap(spacing: 24, runSpacing: 8, children: [
          WeeklyOffField('Effective from', row.effectiveFrom ?? '—'),
          WeeklyOffField('Effective to', row.effectiveTo ?? '-'),
        ]),
        if (canAssign) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: Key('wo-assign-${row.employeeId}'),
              style: TextButton.styleFrom(
                  minimumSize: const Size(48, 44), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: onAssign,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(row.isAssigned ? 'Change' : 'Assign'),
            ),
          ),
        ],
      ]),
    );
  }
}
