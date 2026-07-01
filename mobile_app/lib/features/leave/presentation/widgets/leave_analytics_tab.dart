import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/leave_providers.dart';

// ── Static data (mirrors LeaveAnalytics.tsx) ──────────────────────────────────

class _DeptStat {
  final String dept;
  final int taken;
  final int pending;
  final Color color;
  const _DeptStat(this.dept, this.taken, this.pending, this.color);
}

class _MonthStat {
  final String month;
  final int casual;
  final int earned;
  final int sick;
  const _MonthStat(this.month, this.casual, this.earned, this.sick);
  int get total => casual + earned + sick;
}

class _TopTaker {
  final String name;
  final String dept;
  final int days;
  final String initials;
  const _TopTaker(this.name, this.dept, this.days, this.initials);
}

const _kDept = [
  _DeptStat('Engineering', 42, 5, AppColors.primary),
  _DeptStat('HR',          18, 2, AppColors.success),
  _DeptStat('Sales',       35, 7, AppColors.warning),
  _DeptStat('Finance',     14, 1, AppColors.info),
  _DeptStat('Marketing',   22, 3, Color(0xFFAD95CF)),
];

const _kMonthly = [
  _MonthStat('Jan', 12, 8,  4),
  _MonthStat('Feb', 9,  10, 2),
  _MonthStat('Mar', 15, 12, 6),
  _MonthStat('Apr', 8,  9,  3),
  _MonthStat('May', 11, 14, 5),
  _MonthStat('Jun', 18, 16, 7),
];

const _kTopTakers = [
  _TopTaker('Rahul Singh',  'Engineering', 18, 'RS'),
  _TopTaker('Meena Iyer',   'HR',          15, 'MI'),
  _TopTaker('Arjun Mehta',  'Sales',       12, 'AM'),
  _TopTaker('Kavya Nair',   'Marketing',   11, 'KN'),
  _TopTaker('Suresh Kumar', 'Sales',       9,  'SK'),
];

// ── Widget ────────────────────────────────────────────────────────────────────

class LeaveAnalyticsTab extends ConsumerWidget {
  const LeaveAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(leaveStatsProvider);
    final stats      = statsAsync.valueOrNull;

    final maxDept  = _kDept.map((d) => d.taken + d.pending).reduce((a, b) => a > b ? a : b);
    final maxMonth = _kMonthly.map((m) => m.total).reduce((a, b) => a > b ? a : b);

    final totalLabel   = statsAsync.isLoading ? '…' : '${stats?.total   ?? 0}';
    final pendingLabel = statsAsync.isLoading ? '…' : '${stats?.pending ?? 0}';
    final approvedLabel= statsAsync.isLoading ? '…' : '${stats?.approved ?? 0}';
    final rejectedLabel= statsAsync.isLoading ? '…' : '${stats?.rejected ?? 0}';

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
              Expanded(child: _KpiCard(icon: Icons.beach_access_outlined, color: AppColors.primary, label: 'Total Requests',   value: totalLabel)),
              const SizedBox(width: 10),
              Expanded(child: _KpiCard(icon: Icons.access_time_outlined,  color: AppColors.warning, label: 'Pending',          value: pendingLabel)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _KpiCard(icon: Icons.check_circle_outline,  color: AppColors.success, label: 'Approved',         value: approvedLabel)),
              const SizedBox(width: 10),
              Expanded(child: _KpiCard(icon: Icons.event_busy_outlined,   color: AppColors.error,   label: 'Rejected',         value: rejectedLabel)),
            ],
          ),
          const SizedBox(height: 16),

          // ── Department breakdown ────────────────────────────────────────────
          _SectionCard(
            title: 'Leave by Department',
            subtitle: 'Jan – Jun 2026',
            icon: Icons.bar_chart_outlined,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _kDept.map((d) {
                final total    = d.taken + d.pending;
                final takenW   = maxDept > 0 ? d.taken  / maxDept : 0.0;
                final pendingW = maxDept > 0 ? d.pending / maxDept : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(d.dept,
                                style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ),
                          Text('${total}d',
                              style: AppTextStyles.caption.copyWith(fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 10,
                          child: Row(
                            children: [
                              Flexible(
                                flex: (takenW * 1000).round(),
                                child: Container(color: d.color),
                              ),
                              Flexible(
                                flex: (pendingW * 1000).round(),
                                child: Container(color: d.color.withValues(alpha: 0.35)),
                              ),
                              Flexible(
                                flex: ((1 - takenW - pendingW).clamp(0.0, 1.0) * 1000).round(),
                                child: Container(color: AppColors.backgroundLow),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _LegendChip(color: d.color, label: '${d.taken} taken'),
                          const SizedBox(width: 10),
                          _LegendChip(color: d.color.withValues(alpha: 0.4), label: '${d.pending} pending'),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // ── Top leave takers ───────────────────────────────────────────────
          _SectionCard(
            title: 'Top Leave Takers',
            subtitle: 'YTD 2026',
            icon: Icons.people_outline,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_kTopTakers.length, (i) {
                final person = _kTopTakers[i];
                const colors = [AppColors.primary, AppColors.info, AppColors.success, AppColors.warning, Color(0xFFAD95CF)];
                final color  = colors[i % colors.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Text('${i + 1}',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textHint, fontWeight: FontWeight.w700, fontSize: 12),
                          textAlign: TextAlign.center),
                      const SizedBox(width: 10),
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(person.initials,
                              style: AppTextStyles.caption.copyWith(
                                  color: color, fontWeight: FontWeight.w800, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(person.name,
                                style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text(person.dept,
                                style: AppTextStyles.caption.copyWith(fontSize: 10)),
                          ],
                        ),
                      ),
                      Text('${person.days}d',
                          style: AppTextStyles.h4.copyWith(
                              color: AppColors.primary, fontSize: 16)),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),

          // ── Monthly trend ─────────────────────────────────────────────────
          _SectionCard(
            title: 'Monthly Trend — Leave Days',
            subtitle: 'Jan – Jun 2026',
            icon: Icons.show_chart_outlined,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Legend row
                const Row(
                  children: [
                    _LegendChip(color: AppColors.primary, label: 'Casual'),
                    SizedBox(width: 10),
                    _LegendChip(color: AppColors.success, label: 'Earned'),
                    SizedBox(width: 10),
                    _LegendChip(color: AppColors.warning, label: 'Sick'),
                  ],
                ),
                const SizedBox(height: 14),
                // Bar chart
                SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _kMonthly.map((m) {
                      final sickH   = maxMonth > 0 ? (m.sick   / maxMonth) * 100 : 0.0;
                      final earnedH = maxMonth > 0 ? (m.earned / maxMonth) * 100 : 0.0;
                      final casualH = maxMonth > 0 ? (m.casual / maxMonth) * 100 : 0.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Stacked bar
                              SizedBox(
                                height: 100,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(height: sickH,   color: AppColors.warning),
                                          Container(height: earnedH, color: AppColors.success),
                                          Container(height: casualH, color: AppColors.primary),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(m.month,
                                  style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.textHint)),
                              Text('${m.total}',
                                  style: AppTextStyles.caption.copyWith(
                                      fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _KpiCard({required this.icon, required this.color, required this.label, required this.value});

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
  final String subtitle;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.subtitle, required this.icon, required this.child});

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
                const Spacer(),
                Text(subtitle,
                    style: AppTextStyles.caption.copyWith(fontSize: 10)),
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

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ],
    );
  }
}
