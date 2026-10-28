import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Ports the two real backend statuses ('sent'/'failed') — CandidateEmail
/// has no 'pending'/'delivered'/'bounced' state (see backend/apps/
/// recruitment/models.py CandidateEmail.STATUS_CHOICES).
class EmailStatusChip extends StatelessWidget {
  final String status;
  const EmailStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isSent = status == 'sent';
    final color = isSent ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isSent ? 'Sent' : 'Failed',
        style: AppTextStyles.caption
            .copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
