import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../separation/presentation/notice_period.dart';
import '../../data/models/employee_notice_period_model.dart';
import '../providers/dashboard_providers.dart';
import 'dashboard_section.dart';

/// The signed-in employee's own notice countdown — web
/// `components/dashboard/employee/EmpNoticePeriodCard.tsx`, shown on the
/// Employee dashboard right after the console.
///
/// As on web it renders nothing unless the server returns a notice period
/// (the employee's separation is fully approved), and nothing while it
/// loads. A refusal or "not found" (401/403/404) also renders nothing — the
/// card does not apply to this user. Any other failure shows the card with
/// the error and Retry, so a real notice period isn't silently hidden.
/// Everything shown (days remaining, dates, status) is the server's.
/// [bottomSpacing] is added only when something is shown.
class EmpNoticePeriodCard extends ConsumerWidget {
  const EmpNoticePeriodCard({super.key, this.bottomSpacing = 20});

  final double bottomSpacing;

  static bool _notApplicable(Object e) {
    final code = e is DioException ? e.response?.statusCode : null;
    return code == 401 || code == 403 || code == 404;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(employeeNoticePeriodProvider);
    final Widget? card = async.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => null,
      data: (np) => np == null ? null : _NoticeCard(np: np),
      error: (e, _) => _notApplicable(e)
          ? null
          : SectionCard(
              key: const Key('notice-period-card'),
              title: 'Notice Period',
              icon: Icons.hourglass_bottom,
              accentColor: AppColors.warning,
              child: SectionError(
                message: friendlyDashboardError(e),
                onRetry: () => ref.invalidate(employeeNoticePeriodProvider),
              ),
            ),
    );
    if (card == null) return const SizedBox.shrink();
    return Padding(padding: EdgeInsets.only(bottom: bottomSpacing), child: card);
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.np});
  final EmployeeNoticePeriod np;

  @override
  Widget build(BuildContext context) {
    final completed = np.isCompleted;
    final accent = completed ? AppColors.success : AppColors.warning;
    final figure = completed ? 'Done' : (np.daysRemaining?.toString() ?? '—');
    final figureColor = completed ? AppColors.success : AppColors.error;
    return SectionCard(
      key: const Key('notice-period-card'),
      title: 'Notice Period',
      icon: Icons.hourglass_bottom,
      accentColor: accent,
      trailing: _StatusBadge(completed: completed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    figure,
                    key: const Key('notice-figure'),
                    style: AppTextStyles.h1.copyWith(color: figureColor, height: 1.1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    noticeRemainingLabel(np.daysRemaining, np.noticeStatus),
                    key: const Key('notice-remaining'),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Detail(label: 'Approved on', value: formatNoticeDate(np.approvedAt)),
                    _Detail(label: 'Last working day', value: formatNoticeDate(np.confirmedLastWorkingDay)),
                    _Detail(label: 'Type', value: np.separationType.isEmpty ? '—' : np.separationType),
                  ],
                ),
              ),
            ],
          ),
          if (np.requestId.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('notice-view-details'),
                onPressed: () => goToDashboardSection(context, AppRoutes.separationDetailPath(np.requestId)),
                child: const Text('View details'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.completed});
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) =
        completed ? (AppColors.successContainer, AppColors.success) : (AppColors.warningContainer, AppColors.warning);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        completed ? 'Completed' : 'Serving notice',
        style: AppTextStyles.labelSmall.copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 10),
      ),
    );
  }
}
