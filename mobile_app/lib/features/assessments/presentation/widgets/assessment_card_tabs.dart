import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Action tabs (Results / Items / Assign) ─────────────────────────────────────
//
// A real segmented tab bar — each tab is `Expanded` so the three actions
// always divide the card's available width evenly and never overflow,
// instead of auto-sized chips that could wrap unpredictably.

class ActionTabs extends StatelessWidget {
  final bool isResultsActive;
  final VoidCallback onToggleResults;
  final VoidCallback onItems;
  final VoidCallback onAssign;

  const ActionTabs({
    super.key,
    required this.isResultsActive,
    required this.onToggleResults,
    required this.onItems,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              icon: isResultsActive ? Icons.expand_less : Icons.expand_more,
              label: 'Results',
              active: isResultsActive,
              onTap: onToggleResults,
            ),
          ),
          Expanded(
            child: _TabButton(
              icon: Icons.playlist_add_check_outlined,
              label: 'Items',
              active: false,
              onTap: onItems,
            ),
          ),
          Expanded(
            child: _TabButton(
              icon: Icons.person_add_alt_1_outlined,
              label: 'Assign',
              active: false,
              onTap: onAssign,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: active
              ? BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: AppColors.cardShadow)
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: active ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: active ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IconOnlyChip extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const IconOnlyChip({super.key, required this.icon, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
        ),
      ),
    );
  }
}
