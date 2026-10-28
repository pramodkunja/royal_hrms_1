import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// Shared status → color mapping for request status, approval-stage status,
// and clearance status alike — all three share the same pending/approved/
// rejected/cancelled vocabulary. Mirrors web's statusBadgeClass() keyword
// matching (app/dashboard/separation/_workflow.ts).
Color separationStatusColor(String status) {
  final s = status.toLowerCase();
  if (s.contains('reject')) return AppColors.error;
  if (s.contains('cancel')) return AppColors.textSecondary;
  if (s.contains('approve') || s.contains('complete') || s.contains('clear')) {
    return AppColors.success;
  }
  return AppColors.warning;
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso.length >= 10 ? iso.substring(0, 10) : iso);
    const m = [
      '',
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
    return '${d.day} ${m[d.month]} ${d.year}';
  } catch (_) {
    return iso;
  }
}

String formatSeparationDate(String? iso) => _fmtDate(iso);

class SeparationStatusChip extends StatelessWidget {
  final String status;
  final String label;
  const SeparationStatusChip({super.key, required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = separationStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption
            .copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}

class SeparationSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SeparationSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
