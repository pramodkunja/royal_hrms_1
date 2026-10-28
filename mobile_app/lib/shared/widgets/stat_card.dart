import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Single count-stat card matching the Employees screen's directory-stats
/// design: a colored icon tile on the left, count + label stacked on the
/// right. Pass [width] for use inside a horizontal-scroll row (fixed width,
/// matching Employees' 148); leave it null inside an `Expanded` so it fills
/// the flex share instead.
class StatCard extends StatelessWidget {
  final IconData icon;
  final int? count;
  final String? valueText;
  final String label;
  final Color color;
  final double? width;

  const StatCard({
    super.key,
    required this.icon,
    this.count,
    this.valueText,
    required this.label,
    required this.color,
    this.width,
  }) : assert(
          count != null || valueText != null,
          'Provide either count or valueText',
        );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valueText ?? '$count',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal-scroll row of [StatCard]s, matching the Employees screen's
/// stats strip (fixed-width cards, avoids overflow regardless of item count
/// or label length).
class StatCardRow extends StatelessWidget {
  final List<StatCard> cards;
  final EdgeInsetsGeometry padding;
  final double cardWidth;

  const StatCardRow({
    super.key,
    required this.cards,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.cardWidth = 148,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final c = cards[i];
          return StatCard(
            icon: c.icon,
            count: c.count,
            valueText: c.valueText,
            label: c.label,
            color: c.color,
            width: cardWidth,
          );
        },
      ),
    );
  }
}
