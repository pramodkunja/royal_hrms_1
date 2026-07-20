import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/dashboard/data/models/dashboard_common_models.dart';
import 'package:mobile_app/features/dashboard/data/models/hr_dashboard_models.dart';
import 'package:mobile_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/clock_in_card.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/dashboard_section.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';

/// HR role dashboard — ported from web's `HRDashboard.tsx`. Web lays this
/// out as a 2-column desktop grid; this mirrors the same section content but
/// stacks every section into a single scrollable column, since this is a
/// phone app, in the same reading order web uses.
class HrDashboardView extends ConsumerWidget {
  const HrDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(hrKpisProvider);
        ref.invalidate(hrAttendanceSummaryProvider);
        ref.invalidate(hrActionQueueProvider);
        ref.invalidate(hrRecruitmentFunnelProvider);
        ref.invalidate(hrEmployeeLifecycleProvider);
        ref.invalidate(hrBirthdaysTodayProvider);
        ref.invalidate(hrBirthdaysUpcomingProvider);
        ref.invalidate(hrDepartmentHeadcountProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HrKpiCard(),
            const SizedBox(height: 20),
            QuickAccessCard(items: kQuickItemsHr),
            const SizedBox(height: 20),
            const _AttendanceSummaryCard(),
            const SizedBox(height: 20),
            const _ActionQueueCard(),
            const SizedBox(height: 20),
            const _RecruitmentFunnelCard(),
            const SizedBox(height: 20),
            const ClockInCard(),
            const SizedBox(height: 20),
            const _EmployeeLifecycleCard(),
            const SizedBox(height: 20),
            const _DepartmentHeadcountCard(),
            const SizedBox(height: 20),
            const _TodaysBirthdaysCard(),
            const SizedBox(height: 20),
            const _UpcomingBirthdaysCard(),
          ],
        ),
      ),
    );
  }
}

// ── HR KPI strip ─────────────────────────────────────────────────────────────

class _HrKpiCard extends ConsumerWidget {
  const _HrKpiCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(hrKpisProvider);

    return SectionCard(
      title: 'HR Overview',
      icon: Icons.dashboard_outlined,
      accentColor: AppColors.primary,
      child: kpisAsync.when(
        data: (kpis) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KpiGrid(
                tiles: [
                  KpiTile(
                    label: 'Total Workforce',
                    value: '${kpis.totalWorkforce}',
                    icon: Icons.groups_outlined,
                    color: AppColors.primary,
                  ),
                  KpiTile(
                    label: 'Pending Actions',
                    value: '${kpis.pendingActions}',
                    icon: Icons.pending_actions_outlined,
                    color: AppColors.warning,
                  ),
                  KpiTile(
                    label: 'Active Interviews',
                    value: '${kpis.activeInterviews}',
                    icon: Icons.person_search_outlined,
                    color: AppColors.info,
                  ),
                  KpiTile(
                    label: 'On Probation',
                    value: '${kpis.employeesOnProbation}',
                    icon: Icons.hourglass_bottom_outlined,
                    color: AppColors.secondary,
                  ),
                  KpiTile(
                    label: 'Corrections Pending',
                    value: '${kpis.attendanceCorrectionPending}',
                    icon: Icons.edit_calendar_outlined,
                    color: AppColors.error,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (kpis.clockedIn
                            ? AppColors.success
                            : AppColors.textHint)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        kpis.clockedIn
                            ? Icons.check_circle_outline
                            : Icons.remove_circle_outline,
                        size: 14,
                        color: kpis.clockedIn
                            ? AppColors.success
                            : AppColors.textHint,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        kpis.clockedIn ? 'Clocked In' : 'Clocked Out',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: kpis.clockedIn
                              ? AppColors.success
                              : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.dashboard_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(hrKpisProvider),
        ),
      ),
    );
  }
}

// ── Today's Attendance Summary (org-wide snapshot) ──────────────────────────

class _AttendanceSummaryCard extends ConsumerWidget {
  const _AttendanceSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(hrAttendanceSummaryProvider);

    return SectionCard(
      title: "Today's Attendance",
      icon: Icons.fact_check_outlined,
      accentColor: AppColors.info,
      child: summaryAsync.when(
        data: (summary) {
          final values = [
            summary.present,
            summary.absent,
            summary.late,
            summary.leave,
            summary.weeklyOff,
            summary.holiday,
          ];
          final maxValue = values.fold<int>(0, (m, v) => v > m ? v : m);
          final effectiveMax = maxValue <= 0 ? 1 : maxValue;
          return Column(
            children: [
              BarRow(
                label: 'Present',
                value: summary.present,
                maxValue: effectiveMax,
                color: AppColors.success,
              ),
              const SizedBox(height: 12),
              BarRow(
                label: 'Absent',
                value: summary.absent,
                maxValue: effectiveMax,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              BarRow(
                label: 'Late',
                value: summary.late,
                maxValue: effectiveMax,
                color: AppColors.warning,
              ),
              const SizedBox(height: 12),
              BarRow(
                label: 'On Leave',
                value: summary.leave,
                maxValue: effectiveMax,
                color: AppColors.secondary,
              ),
              const SizedBox(height: 12),
              BarRow(
                label: 'Weekly Off',
                value: summary.weeklyOff,
                maxValue: effectiveMax,
                color: AppColors.info,
              ),
              const SizedBox(height: 12),
              BarRow(
                label: 'Holiday',
                value: summary.holiday,
                maxValue: effectiveMax,
                color: AppColors.primary,
              ),
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.fact_check_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(hrAttendanceSummaryProvider),
        ),
      ),
    );
  }
}

// ── Action Queue ─────────────────────────────────────────────────────────────

class _ActionQueueCard extends ConsumerWidget {
  const _ActionQueueCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(hrActionQueueProvider);

    return SectionCard(
      title: 'Action Queue',
      icon: Icons.inbox_outlined,
      accentColor: AppColors.warning,
      child: queueAsync.when(
        data: (queue) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${queue.totalPending}',
                style: AppTextStyles.h2,
              ),
              Text(
                'Total Pending',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 12),
              _QueueRow(
                  label: 'Candidate Reviews', value: queue.candidateReviews),
              _QueueRow(
                  label: 'Leave Approvals', value: queue.leaveApprovals),
              _QueueRow(
                  label: 'Attendance Corrections',
                  value: queue.attendanceCorrections),
              _QueueRow(label: 'Expense Claims', value: queue.expenseClaims),
              _QueueRow(
                  label: 'Onboarding Reviews',
                  value: queue.onboardingReviews),
              _QueueRow(
                  label: 'Separation Requests',
                  value: queue.separationRequests),
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.inbox_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(hrActionQueueProvider),
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final String label;
  final int value;

  const _QueueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Text(
            '$value',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Recruitment Funnel ───────────────────────────────────────────────────────

class _RecruitmentFunnelCard extends ConsumerWidget {
  const _RecruitmentFunnelCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final funnelAsync = ref.watch(hrRecruitmentFunnelProvider);

    return SectionCard(
      title: 'Recruitment Funnel',
      icon: Icons.filter_alt_outlined,
      accentColor: AppColors.primary,
      child: funnelAsync.when(
        data: (funnel) {
          return Column(
            children: [
              _QueueRow(
                  label: 'Interviews Scheduled',
                  value: funnel.interviewsScheduled),
              _QueueRow(label: 'Interviewed', value: funnel.interviewed),
              _QueueRow(label: 'Selected', value: funnel.selected),
              _QueueRow(
                  label: 'Details Submitted',
                  value: funnel.detailsSubmitted),
              _QueueRow(label: 'Onboarded', value: funnel.onboarded),
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.filter_alt_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(hrRecruitmentFunnelProvider),
        ),
      ),
    );
  }
}

// ── Employee Lifecycle ───────────────────────────────────────────────────────

class _EmployeeLifecycleCard extends ConsumerWidget {
  const _EmployeeLifecycleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifecycleAsync = ref.watch(hrEmployeeLifecycleProvider);

    return SectionCard(
      title: 'Employee Lifecycle',
      icon: Icons.timeline_outlined,
      accentColor: AppColors.info,
      child: lifecycleAsync.when(
        data: (lifecycle) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LifecycleGroup(
                title: 'New Joiners',
                group: lifecycle.newJoiners,
                lineBuilder: (e) {
                  final parts = [
                    if (e.department.isNotEmpty) e.department,
                    if ((e.designation ?? '').isNotEmpty) e.designation!,
                  ];
                  final secondary = parts.join(' · ');
                  final joining = e.dateOfJoining;
                  return _LifecycleLines(
                    secondary: secondary,
                    tertiary: (joining != null && joining.isNotEmpty)
                        ? 'Joined: $joining'
                        : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              _LifecycleGroup(
                title: 'Notice Period',
                group: lifecycle.noticePeriod,
                lineBuilder: (e) {
                  final parts = [
                    if (e.department.isNotEmpty) e.department,
                    if ((e.designation ?? '').isNotEmpty) e.designation!,
                  ];
                  return _LifecycleLines(secondary: parts.join(' · '));
                },
              ),
              const SizedBox(height: 16),
              _LifecycleGroup(
                title: 'Work Anniversaries',
                group: lifecycle.workAnniversaries,
                lineBuilder: (e) {
                  final years = e.yearsCompleted;
                  final anniversary = e.anniversaryDate;
                  final tertiary = (years != null &&
                          anniversary != null &&
                          anniversary.isNotEmpty)
                      ? '$years yrs (since $anniversary)'
                      : null;
                  return _LifecycleLines(
                    secondary: e.department,
                    tertiary: tertiary,
                  );
                },
              ),
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.timeline_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(hrEmployeeLifecycleProvider),
        ),
      ),
    );
  }
}

class _LifecycleLines {
  final String secondary;
  final String? tertiary;

  const _LifecycleLines({required this.secondary, this.tertiary});
}

class _LifecycleGroup extends StatelessWidget {
  final String title;
  final HrLifecycleGroup group;
  final _LifecycleLines Function(HrLifecycleEmployee) lineBuilder;

  const _LifecycleGroup({
    required this.title,
    required this.group,
    required this.lineBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Text('(${group.count})', style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: 6),
        if (group.employees.isEmpty)
          Text('No data', style: AppTextStyles.caption)
        else
          Column(
            children: [
              for (var i = 0; i < group.employees.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _LifecycleEmployeeRow(
                  employee: group.employees[i],
                  lines: lineBuilder(group.employees[i]),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _LifecycleEmployeeRow extends StatelessWidget {
  final HrLifecycleEmployee employee;
  final _LifecycleLines lines;

  const _LifecycleEmployeeRow({required this.employee, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          employee.fullName,
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        if (lines.secondary.isNotEmpty)
          Text(
            lines.secondary,
            style: AppTextStyles.caption,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        if (lines.tertiary != null)
          Text(
            lines.tertiary!,
            style: AppTextStyles.caption,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
      ],
    );
  }
}

// ── Department Headcount ─────────────────────────────────────────────────────

class _DepartmentHeadcountCard extends ConsumerWidget {
  const _DepartmentHeadcountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headcountAsync = ref.watch(hrDepartmentHeadcountProvider);

    return SectionCard(
      title: 'Department Headcount',
      icon: Icons.apartment_outlined,
      accentColor: AppColors.primary,
      child: headcountAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const SectionMessage(
              icon: Icons.apartment_outlined,
              label: 'No department data available.',
            );
          }
          final maxValue =
              list.fold<int>(0, (m, d) => d.count > m ? d.count : m);
          final effectiveMax = maxValue <= 0 ? 1 : maxValue;
          return Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                BarRow(
                  label: list[i].department,
                  value: list[i].count,
                  maxValue: effectiveMax,
                  color: AppColors.primary,
                ),
              ],
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.apartment_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(hrDepartmentHeadcountProvider),
        ),
      ),
    );
  }
}

// ── Birthdays ────────────────────────────────────────────────────────────────

class _TodaysBirthdaysCard extends ConsumerWidget {
  const _TodaysBirthdaysCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthdaysAsync = ref.watch(hrBirthdaysTodayProvider);

    return SectionCard(
      title: "Today's Birthdays",
      icon: Icons.cake_outlined,
      accentColor: AppColors.secondary,
      child: birthdaysAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const SectionMessage(
              icon: Icons.cake_outlined,
              label: 'No birthdays today',
            );
          }
          return Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _BirthdayRow(employee: list[i]),
              ],
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.cake_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(hrBirthdaysTodayProvider),
        ),
      ),
    );
  }
}

class _UpcomingBirthdaysCard extends ConsumerWidget {
  const _UpcomingBirthdaysCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthdaysAsync = ref.watch(hrBirthdaysUpcomingProvider);

    return SectionCard(
      title: 'Upcoming Birthdays',
      icon: Icons.card_giftcard_outlined,
      accentColor: AppColors.secondary,
      child: birthdaysAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const SectionMessage(
              icon: Icons.card_giftcard_outlined,
              label: 'No upcoming birthdays',
            );
          }
          return Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _BirthdayRow(employee: list[i], showDaysUntil: true),
              ],
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.card_giftcard_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(hrBirthdaysUpcomingProvider),
        ),
      ),
    );
  }
}

class _BirthdayRow extends StatelessWidget {
  final DashboardBirthdayEmployee employee;
  final bool showDaysUntil;

  const _BirthdayRow({required this.employee, this.showDaysUntil = false});

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (employee.department.isNotEmpty) employee.department,
      if (employee.branch.isNotEmpty) employee.branch,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.fullName,
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (parts.isNotEmpty)
                Text(
                  parts.join(' · '),
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
        ),
        if (showDaysUntil) ...[
          const SizedBox(width: 8),
          Text(
            'In ${employee.daysUntil} days',
            style: AppTextStyles.caption.copyWith(color: AppColors.info),
          ),
        ],
      ],
    );
  }
}
