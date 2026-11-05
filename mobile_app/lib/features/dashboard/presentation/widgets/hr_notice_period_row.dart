import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../separation/presentation/notice_period.dart' show formatNoticeDate, noticeRemainingLabel;
import '../../data/models/hr_dashboard_models.dart';
import 'dashboard_section.dart';

/// Web components/dashboard/NoticePeriodRow.tsx in the HR "Employee
/// Lifecycle" card's Notice Period tab: initials, name, "<employee id> ·
/// <department> · <branch>" (or "—"), "Approved <date>"; on the right "Last
/// day: <date>" in red and the server's countdown ("12 days remaining",
/// "Notice completed", or "—"). Dates as web formatNoticeDate ("—" when
/// missing or unreadable); every value is the server's.
class HrNoticePeriodRow extends StatelessWidget {
  const HrNoticePeriodRow({super.key, required this.employee});

  final HrLifecycleEmployee employee;

  @override
  Widget build(BuildContext context) {
    final e = employee;
    final meta = [e.employeeId, e.department, e.branch ?? ''].where((s) => s.isNotEmpty).join(' · ');
    return Row(
      children: [
        InitialsAvatar(name: e.fullName),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.fullName,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
              Text(meta.isEmpty ? '—' : meta,
                  key: const Key('notice-row-meta'),
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
              Text('Approved ${formatNoticeDate(e.approvedAt)}',
                  key: const Key('notice-row-approved'),
                  style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Last day: ${formatNoticeDate(e.lastWorkingDay)}',
                key: const Key('notice-row-last-day'),
                style:
                    AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
            const SizedBox(height: 1),
            Text(noticeRemainingLabel(e.daysRemaining, e.noticeStatus),
                key: const Key('notice-row-remaining'),
                style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}
