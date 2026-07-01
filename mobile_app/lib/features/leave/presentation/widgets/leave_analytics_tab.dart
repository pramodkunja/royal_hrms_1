import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/leave_providers.dart';

// ── Widget — mirrors web's LeaveAnalytics.tsx: KPI cards, real leave balance
// breakdown (stats.balances), and request status distribution. No mock data.

class LeaveAnalyticsTab extends ConsumerWidget {
  const LeaveAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(leaveStatsProvider);
    final stats      = statsAsync.valueOrNull;
    final currentYear = stats?.year ?? DateTime.now().year;

    final totalLabel    = statsAsync.isLoading ? '…' : '${stats?.total     ?? 0}';
    final pendingLabel  = statsAsync.isLoading ? '…' : '${stats?.pending   ?? 0}';
    final approvedLabel = statsAsync.isLoading ? '…' : '${stats?.approved  ?? 0}';
    final rejectedLabel = statsAsync.isLoading ? '…' : '${stats?.rejected  ?? 0}';

    final totalAll   = stats?.total ?? 0;
    final balances    = stats?.balances ?? [];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(leaveStatsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── KPI cards 2×2 ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(child: _KpiCard(icon: Icons.beach_access_outlined, color: AppColors.primary, label: 'Total Requests', value: totalLabel, sub: 'This year ($currentYear)')),
                const SizedBox(width: 10),
                Expanded(child: _KpiCard(icon: Icons.check_circle_outline,  color: AppColors.success, label: 'Approved',       value: approvedLabel, sub: 'This year ($currentYear)')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _KpiCard(icon: Icons.access_time_outlined,  color: AppColors.warning, label: 'Pending Approval', value: pendingLabel, sub: 'This year ($currentYear)')),
                const SizedBox(width: 10),
                Expanded(child: _KpiCard(icon: Icons.event_busy_outlined,   color: AppColors.error,   label: 'Rejected',         value: rejectedLabel, sub: 'This year ($currentYear)')),
              ],
            ),
            const SizedBox(height: 16),

            if (statsAsync.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else ...[
              // ── Leave Balance Breakdown ───────────────────────────────────────
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(b.leaveTypeDisplay,
                                      style: AppTextStyles.caption.copyWith(
                                          fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                ),
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
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${_fmt(b.available)} remaining',
                                style: AppTextStyles.caption.copyWith(
                                    fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )
              else
                _EmptyCard(
                  icon: Icons.bar_chart_outlined,
                  message: 'No leave balance data for $currentYear. Contact HR to credit your annual leave.',
                ),
              const SizedBox(height: 14),

              // ── Request Status Distribution ───────────────────────────────────
              if (totalAll > 0)
                _SectionCard(
                  title: 'Request Status Distribution',
                  icon: Icons.donut_large_outlined,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusRow(label: 'Approved',  value: stats?.approved  ?? 0, total: totalAll, color: AppColors.success),
                      _StatusRow(label: 'Pending',   value: stats?.pending   ?? 0, total: totalAll, color: AppColors.warning),
                      _StatusRow(label: 'Rejected',  value: stats?.rejected  ?? 0, total: totalAll, color: AppColors.error),
                      _StatusRow(label: 'Cancelled', value: stats?.cancelled ?? 0, total: totalAll, color: AppColors.textSecondary),
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
  const _KpiCard({required this.icon, required this.color, required this.label, required this.value, required this.sub});

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
            width: 40, height: 40,
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
                Text(value,
                    style: AppTextStyles.h3.copyWith(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                Text(label,
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(sub,
                    style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.textHint),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
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
  const _SectionCard({required this.title, required this.icon, required this.child});

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
                Text(title, style: AppTextStyles.label),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
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
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  const _StatusRow({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total * 100).round() : 0;
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
                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text('$value ($pct%)',
                  style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? value / total : 0,
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
