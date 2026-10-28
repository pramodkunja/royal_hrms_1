import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/wfh_entity.dart';

Color wfhStatusColor(String status) => switch (status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      'cancelled' => AppColors.textSecondary,
      _ => AppColors.warning,
    };

// Pill showing a WFH request's status — uses statusLabel (not the raw
// status string) so pending/l2_pending render as distinct, readable labels
// ("Pending (Manager)" / "Pending (HR)") instead of collapsing into one
// generic "pending" pill the way Leave's equivalent does.
class WfhStatusChip extends StatelessWidget {
  final String status;
  const WfhStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = wfhStatusColor(status);
    final label = wfhStatusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
