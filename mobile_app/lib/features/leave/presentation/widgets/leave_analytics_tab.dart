import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../core/permissions/permission_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/leave_providers.dart';

// ── Widget — mirrors web's LeaveAnalytics.tsx (GET /leave/stats/?year=<calendar year>):
//   Total Requests   ← total
//   Approved         ← approved
//   Pending Approval ← pending           (backend: pending + L2-pending)
//   Rejected         ← rejected
//   Loss of Pay (LOP)← lop_days          (backend: approved requests only) + lop_requests
// then the leave balance breakdown (stats.balances, own-scope views only) and the request
// status distribution (approved / pending / rejected / cancelled, % of total).
//
// Values come only from that response. While it loads, the cards show "…"; after a failure the
// tab shows an error (or Access denied) with Retry — never the previous numbers; a field the
// server did not send as a number shows "—" (unavailable), while a real 0 shows 0.
// There are no user-selectable filters on web (the year is the calendar year, the scope follows
// the user's permissions on the server), so none are offered here.

class LeaveAnalyticsTab extends ConsumerWidget {
  const LeaveAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(leaveStatsProvider);
    final loading = statsAsync.isLoading;
    final failed = !loading && statsAsync.hasError;
    // Only a finished, successful response counts as current data.
    final stats = loading || failed ? null : statsAsync.valueOrNull;
    final year = stats != null && stats.year > 0 ? stats.year : ref.watch(leaveDashboardYearProvider);

    // Web: an employee (own figures + balances) is decided by permissions, not the role name —
    // someone without leave.approve who manages no team or branch.
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final canApprove = ref.watch(permissionProvider('leave.approve'));
    final isEmployee = !canApprove && !(user?.canManageTeam ?? false) && !(user?.canManageBranch ?? false);

    String count(String key, int value) => stats == null ? '…' : (stats.unavailable.contains(key) ? '—' : '$value');
    String sub(String key, String text) => stats != null && stats.unavailable.contains(key) ? 'Unavailable' : text;
    final yearSub = 'This year ($year)';

    final lopRequests = stats?.lopRequests ?? 0;
    final cards = [
      _KpiCard(
          key: const Key('leave-stat-total'),
          icon: Icons.beach_access_outlined,
          color: AppColors.primary,
          label: 'Total Requests',
          value: count('total', stats?.total ?? 0),
          sub: sub('total', yearSub)),
      _KpiCard(
          key: const Key('leave-stat-approved'),
          icon: Icons.check_circle_outline,
          color: AppColors.success,
          label: 'Approved',
          value: count('approved', stats?.approved ?? 0),
          sub: sub('approved', yearSub)),
      _KpiCard(
          key: const Key('leave-stat-pending'),
          icon: Icons.access_time_outlined,
          color: AppColors.warning,
          label: 'Pending Approval',
          value: count('pending', stats?.pending ?? 0),
          sub: sub('pending', yearSub)),
      _KpiCard(
          key: const Key('leave-stat-rejected'),
          icon: Icons.event_busy_outlined,
          color: AppColors.error,
          label: 'Rejected',
          value: count('rejected', stats?.rejected ?? 0),
          sub: sub('rejected', yearSub)),
      _KpiCard(
          key: const Key('leave-stat-lop'),
          icon: Icons.money_off_csred_outlined,
          color: AppColors.warning,
          label: 'Loss of Pay (LOP)',
          value: stats == null
              ? '…'
              : (stats.unavailable.contains('lop_days') ? '—' : _fmt(stats.lopDays)),
          sub: stats == null
              ? ''
              : (stats.unavailable.contains('lop_requests')
                  ? 'Unavailable'
                  : '$lopRequests request${lopRequests != 1 ? 's' : ''} in $year')),
    ];

    final totalAll = stats?.total ?? 0;
    final totalKnown = stats != null && !stats.unavailable.contains('total');
    final balances = stats?.balances ?? [];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => refreshLeaveStats(ref),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        child: failed
            ? AppErrorState.forError(
                statsAsync.error!,
                key: const Key('leave-analytics-error'),
                title: 'Failed to load leave analytics.',
                padding: const EdgeInsets.symmetric(vertical: 80),
                onRetry: () => refreshLeaveStats(ref),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(builder: (context, c) {
                    final large = MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
                    // One column at large text so labels and figures keep whole words.
                    final cols = large ? 1 : (c.maxWidth >= 900 ? 5 : (c.maxWidth >= 560 ? 3 : 2));
                    const gap = 10.0;
                    final w = (c.maxWidth - gap * (cols - 1)) / cols;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (var i = 0; i < cards.length; i++)
                          // Two across on a phone; the odd last card takes the whole row.
                          SizedBox(width: cols == 2 && i == cards.length - 1 ? c.maxWidth : w, child: cards[i]),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
                  if (loading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  else ...[
                    // ── Leave Balance Breakdown ─────────────────────────────────────
                    if (balances.isNotEmpty)
                      _SectionCard(
                        title: 'Leave Balance Breakdown',
                        icon: Icons.bar_chart_outlined,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: balances.map((b) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: [
                                      Text(b.leaveTypeDisplay,
                                          style: AppTextStyles.caption
                                              .copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                      Text(
                                        '${_fmt(b.usedDays)} used / ${_fmt(b.totalDays)} total',
                                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: b.pct,
                                      minHeight: 8,
                                      backgroundColor: AppColors.backgroundLow,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${_fmt(b.available)} remaining',
                                      style: AppTextStyles.caption
                                          .copyWith(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      )
                    else if (isEmployee)
                      _EmptyCard(
                        icon: Icons.bar_chart_outlined,
                        message: 'No leave balance data for $year. Contact HR to credit your annual leave.',
                      ),
                    const SizedBox(height: 14),

                    // ── Request Status Distribution ─────────────────────────────────
                    if (totalKnown && totalAll > 0)
                      _SectionCard(
                        title: 'Request Status Distribution',
                        icon: Icons.donut_large_outlined,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final r in [
                              ('Approved', 'approved', stats.approved, AppColors.success),
                              ('Pending', 'pending', stats.pending, AppColors.warning),
                              ('Rejected', 'rejected', stats.rejected, AppColors.error),
                              ('Cancelled', 'cancelled', stats.cancelled, AppColors.textSecondary),
                            ])
                              _StatusRow(
                                  label: r.$1,
                                  value: stats.unavailable.contains(r.$2) ? null : r.$3,
                                  total: totalAll,
                                  color: r.$4),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;
  const _KpiCard(
      {super.key,
      required this.icon,
      required this.color,
      required this.label,
      required this.value,
      required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The figure is never clipped or truncated: it shrinks only if it cannot fit.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      maxLines: 1,
                      style: AppTextStyles.h3.copyWith(
                          fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ),
                Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
                if (sub.isNotEmpty)
                  Text(sub, style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(icon, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: AppTextStyles.label)),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: AppColors.textHint),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center, style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final int? value; // null = unavailable
  final int total;
  final Color color;
  const _StatusRow(
      {required this.label,
      required this.value,
      required this.total,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final v = value;
    final pct = v != null && total > 0 ? (v / total * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: AppTextStyles.caption
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
              Text(v == null ? '—' : '$v ($pct%)',
                  style: AppTextStyles.caption
                      .copyWith(fontSize: 11, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: v != null && total > 0 ? v / total : 0,
              minHeight: 8,
              backgroundColor: AppColors.backgroundLow,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pull-to-refresh / retry for the year-scoped leave stats: re-reads the
/// calendar year too (so a tab left open over New Year asks for the new year,
/// as web's re-render does) and refetches once.
void refreshLeaveStats(WidgetRef ref) {
  ref.invalidate(leaveDashboardYearProvider);
  ref.invalidate(leaveStatsProvider);
}
