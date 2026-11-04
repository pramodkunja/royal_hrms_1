import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/wfh_daily_report_entity.dart';

/// Card with a header, used for each block of the Daily Work Report tab.
class WfhReportSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;

  const WfhReportSection({super.key, required this.title, this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 18, color: AppColors.primary), const SizedBox(width: 8)],
            Expanded(child: Text(title, style: AppTextStyles.h4.copyWith(fontSize: 16))),
          ]),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// Inline success / error message (web's alert-success / alert-error).
class WfhReportNotice extends StatelessWidget {
  final String text;
  final bool ok;

  const WfhReportNotice({super.key, required this.text, required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ok ? AppColors.successContainer : AppColors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_outline : Icons.error_outline, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: color))),
      ]),
    );
  }
}

Color wfhReportStatusColor(WfhReportReviewStatus s) => switch (s) {
      WfhReportReviewStatus.pending => AppColors.warning,
      WfhReportReviewStatus.fullDay => AppColors.success,
      WfhReportReviewStatus.halfDay => AppColors.primary,
      WfhReportReviewStatus.notAccepted => AppColors.error,
    };

/// Review-status pill (web's badge-warn / success / primary / error).
class WfhReportStatusChip extends StatelessWidget {
  final WfhReportReviewStatus status;
  const WfhReportStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = wfhReportStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
