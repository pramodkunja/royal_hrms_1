import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/wfh_daily_report_entity.dart';
import '../wfh_report_strings.dart';
import 'wfh_report_review_panel.dart';
import 'wfh_report_section.dart';

/// One report row (web's ReportRow): date, late flag, work text, status and
/// reviewer. In the review list it also shows the employee and — only when
/// the server says `can_review` — the review controls.
class WfhReportCard extends StatelessWidget {
  final WfhDailyReportEntity report;
  final bool showEmployee;

  const WfhReportCard({super.key, required this.report, this.showEmployee = false});

  Widget _line(String label, String text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: text),
          ]),
          style: AppTextStyles.bodySmall.copyWith(color: color ?? AppColors.textPrimary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showEmployee)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: r.employeeName, style: AppTextStyles.label),
                if (r.employeeCode.isNotEmpty)
                  TextSpan(text: '  ${r.employeeCode}', style: AppTextStyles.caption),
              ])),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.date, style: AppTextStyles.labelLarge),
                    if (r.submittedLate)
                      Text(WfhReportStrings.submittedLate,
                          style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  WfhReportStatusChip(status: r.reviewStatus),
                  if (r.reviewedByName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('by ${r.reviewedByName}', style: AppTextStyles.caption),
                    ),
                ],
              ),
            ],
          ),
          _line(WfhReportStrings.done, r.completedWork),
          if (r.pendingWork.isNotEmpty) _line(WfhReportStrings.pending, r.pendingWork),
          if (r.updates.isNotEmpty) _line(WfhReportStrings.updates, r.updates),
          if (r.reviewRemarks.isNotEmpty)
            _line(WfhReportStrings.reviewer, r.reviewRemarks, color: AppColors.textSecondary),
          if (showEmployee && r.canReview) WfhReportReviewPanel(report: r),
        ],
      ),
    );
  }
}
