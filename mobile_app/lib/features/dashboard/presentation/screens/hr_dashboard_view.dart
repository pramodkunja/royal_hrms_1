import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/dashboard/data/models/dashboard_common_models.dart';
import 'package:mobile_app/features/dashboard/data/models/hr_dashboard_models.dart';
import 'package:mobile_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/attendance_ring_card.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/dashboard_section.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart'
    show EmployeeFilters;
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart'
    show employeeFiltersProvider;

/// HR role dashboard — ported from web's `HRDashboard.tsx`. Web lays this
/// out as a 2-column desktop grid; this mirrors the same section content but
/// stacks every section into a single scrollable column, since this is a
/// phone app, in the same reading order web uses.
class HrDashboardView extends ConsumerWidget {
  const HrDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refreshAll() async {
      ref.invalidate(hrKpisProvider);
      ref.invalidate(sharedAnnouncementProvider);
      ref.invalidate(hrAttendanceSummaryProvider);
      ref.invalidate(hrActionQueueProvider);
      ref.invalidate(hrRecruitmentFunnelProvider);
      ref.invalidate(hrEmployeeLifecycleProvider);
      ref.invalidate(hrBirthdaysTodayProvider);
      ref.invalidate(hrBirthdaysUpcomingProvider);
      ref.invalidate(hrDepartmentHeadcountProvider);
    }

    // This view is reached via context.go() but every sub-section under it
    // is pushed on top via goToDashboardSection — so popping back here
    // never re-triggers autoDispose providers on its own. Re-run the same
    // refresh pull-to-refresh does whenever the dashboard becomes visible
    // again. `prev != null` skips the initial subscription.
    ref.listen<int>(dashboardRevisitProvider, (prev, next) {
      if (prev != null) refreshAll();
    });

    return RefreshIndicator(
      onRefresh: refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HrConsoleHeader(),
            const SizedBox(height: 20),
            const AttendanceRingCard(),
            const SizedBox(height: 20),
            QuickAccessCard(items: kQuickItemsHr),
            const SizedBox(height: 20),
            const _AttendanceSummaryCard(),
            const SizedBox(height: 20),
            const _ActionQueueCard(),
            const SizedBox(height: 20),
            const _RecruitmentFunnelCard(),
            const SizedBox(height: 20),
            const _AnnouncementCard(),
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

// ── HR Console header (gradient hero + white stat strip; shared shell —
// see dashboard_section.dart's ConsoleHeaderShell/StatusRingAvatar/etc, also
// used by the Employee, Admin, and generic/Manager dashboards) ─────────────

class _HrConsoleHeader extends ConsumerWidget {
  const _HrConsoleHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final kpisAsync = ref.watch(hrKpisProvider);
    final name = (user?.fullName ?? '').isEmpty ? 'there' : user!.fullName;
    // Same provider AttendanceRingCard (rendered right below this) reads for
    // its own clocked-in state — one canonical source, so the two never
    // disagree about whether this person is currently clocked in.
    final clockedIn = ref.watch(todayAttendanceProvider).valueOrNull?.isClockedIn ?? false;

    return ConsoleHeaderShell(
      heroContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusRingAvatar(name: name, active: clockedIn),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RoleBadgePill(label: 'HR OPERATIONS'),
                    const SizedBox(height: 7),
                    Text(
                      'Welcome back,',
                      style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                    Text(
                      name,
                      style: AppTextStyles.h3.copyWith(color: Colors.white, height: 1.15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConsoleInfoBar(clockedIn: clockedIn),
        ],
      ),
      statsContent: kpisAsync.when(
        data: (kpis) => ConsoleStatsRow(stats: [
          (icon: Icons.groups_outlined, value: '${kpis.totalWorkforce}', label: 'Workforce', color: AppColors.primary),
          (icon: Icons.pending_actions_outlined, value: '${kpis.pendingActions}', label: 'Pending', color: AppColors.warning),
          (icon: Icons.person_search_outlined, value: '${kpis.activeInterviews}', label: 'Interviews', color: AppColors.info),
          (
            icon: Icons.edit_calendar_outlined,
            value: '${kpis.attendanceCorrectionPending}',
            label: 'Corrections',
            color: AppColors.error,
          ),
        ]),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(friendlyDashboardError(e), style: AppTextStyles.caption.copyWith(color: AppColors.error)),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => ref.invalidate(hrKpisProvider),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Latest Announcement ──────────────────────────────────────────────────────

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementAsync = ref.watch(sharedAnnouncementProvider);

    return SectionCard(
      title: 'Latest Announcement',
      iconWidget: const SectionIconAsset('assets/images/Announcement.png'),
      accentColor: AppColors.primary,
      child: announcementAsync.when(
        data: (announcement) {
          if (announcement == null || announcement.title.isEmpty) {
            return const SectionMessage(
              iconWidget: SectionIconAsset('assets/images/Announcement.png', size: 28),
              label: 'No announcements yet',
            );
          }
          final metaParts = [
            announcement.category,
            if (announcement.postedBy != null && announcement.postedBy!.isNotEmpty) announcement.postedBy!,
            _formatDateTime(announcement.createdAt),
          ].where((s) => s.isNotEmpty).join(' · ');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                announcement.title,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 6),
              Text(
                announcement.body,
                style: AppTextStyles.bodySecondary,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              if (metaParts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(metaParts, style: AppTextStyles.caption),
              ],
            ],
          );
        },
        loading: () => const SectionMessage(
          iconWidget: SectionIconAsset('assets/images/Announcement.png', size: 28),
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(sharedAnnouncementProvider),
        ),
      ),
    );
  }
}

/// Formats an ISO datetime string as "20 Jul, 01:27 pm" — no `intl` package
/// in this app, so this is a small hand-rolled formatter (mirrors the one in
/// admin_dashboard_view.dart).
String _formatDateTime(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final local = dt.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'am' : 'pm';
  return '${local.day} ${kConsoleMonthNames[local.month - 1]}, '
      '${hour12.toString().padLeft(2, '0')}:$minute $period';
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
              const SizedBox(height: 16),
              ActionRow(
                icon: Icons.how_to_reg_outlined,
                iconColor: AppColors.info,
                title: 'Candidate Reviews',
                count: queue.candidateReviews,
                onTap: () => goToDashboardSection(context, AppRoutes.candidateReview),
              ),
              const Divider(height: 24),
              ActionRow(
                icon: Icons.beach_access_outlined,
                iconColor: AppColors.success,
                title: 'Leave Approvals',
                count: queue.leaveApprovals,
                onTap: () => goToDashboardSection(context, AppRoutes.leave),
              ),
              const Divider(height: 24),
              ActionRow(
                icon: Icons.edit_calendar_outlined,
                iconColor: AppColors.error,
                title: 'Attendance Corrections',
                count: queue.attendanceCorrections,
                onTap: () => goToDashboardSection(context, AppRoutes.approvals),
              ),
              const Divider(height: 24),
              ActionRow(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: AppColors.warning,
                title: 'Expense Claims',
                count: queue.expenseClaims,
                onTap: () => goToDashboardSection(context, AppRoutes.expenses),
              ),
              const Divider(height: 24),
              ActionRow(
                icon: Icons.person_add_alt_outlined,
                iconColor: AppColors.primary,
                title: 'Onboarding Reviews',
                count: queue.onboardingReviews,
                // No dedicated onboarding-review screen exists in this app
                // yet, so this opens the Employees list pre-filtered to
                // status=onboarding — the same fallback the Admin dashboard
                // uses for the identical tile.
                onTap: () {
                  ref.read(employeeFiltersProvider.notifier).state =
                      const EmployeeFilters(status: 'onboarding');
                  goToDashboardSection(context, AppRoutes.employees);
                },
              ),
              const Divider(height: 24),
              ActionRow(
                icon: Icons.logout_outlined,
                iconColor: AppColors.secondary,
                title: 'Separation Requests',
                count: queue.separationRequests,
                onTap: () => goToDashboardSection(context, AppRoutes.separation),
              ),
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
          // Each stage is a fraction of the top-of-funnel count (not
          // whichever stage happens to be largest) — matching web's funnel
          // visual, where every bar is a progressively smaller share of the
          // same starting pool, with fading opacity to reinforce the drop-off.
          final stages = [
            ('Interviews Scheduled', funnel.interviewsScheduled),
            ('Interviewed', funnel.interviewed),
            ('Selected', funnel.selected),
            ('Details Submitted', funnel.detailsSubmitted),
            ('Onboarded', funnel.onboarded),
          ];
          final topOfFunnel = stages.first.$2 <= 0 ? 1 : stages.first.$2;
          return Column(
            children: [
              for (var i = 0; i < stages.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                BarRow(
                  label: stages[i].$1,
                  value: stages[i].$2,
                  maxValue: topOfFunnel,
                  color: AppColors.primary.withValues(alpha: 1.0 - i * 0.15),
                ),
              ],
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

// ── Employee Lifecycle (tabbed) ─────────────────────────────────────────────

class _EmployeeLifecycleCard extends ConsumerStatefulWidget {
  const _EmployeeLifecycleCard();

  @override
  ConsumerState<_EmployeeLifecycleCard> createState() => _EmployeeLifecycleCardState();
}

class _EmployeeLifecycleCardState extends ConsumerState<_EmployeeLifecycleCard> {
  int _tab = 0;

  static const _tabsMeta = [
    (label: 'New Joiners', icon: Icons.person_add_alt_1_outlined),
    (label: 'Notice Period', icon: Icons.logout_outlined),
    (label: 'Anniversaries', icon: Icons.emoji_events_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final lifecycleAsync = ref.watch(hrEmployeeLifecycleProvider);

    return SectionCard(
      title: 'Employee Lifecycle',
      icon: Icons.sync_alt_outlined,
      accentColor: AppColors.info,
      trailing: OutlinedButton(
        onPressed: () => goToDashboardSection(context, AppRoutes.employees),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: const Size(0, 0),
          side: BorderSide(color: AppColors.border),
        ),
        child: Text('All employees', style: AppTextStyles.labelSmall),
      ),
      child: lifecycleAsync.when(
        data: (lifecycle) {
          final groups = [lifecycle.newJoiners, lifecycle.noticePeriod, lifecycle.workAnniversaries];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: LifecycleTabButton(
                        label: _tabsMeta[i].label,
                        icon: _tabsMeta[i].icon,
                        count: groups[i].count,
                        selected: _tab == i,
                        onTap: () => setState(() => _tab = i),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _LifecycleList(group: groups[_tab], tab: _tab),
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.sync_alt_outlined,
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

class _LifecycleList extends StatelessWidget {
  final HrLifecycleGroup group;
  final int tab;

  const _LifecycleList({required this.group, required this.tab});

  @override
  Widget build(BuildContext context) {
    if (group.employees.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('No data', style: AppTextStyles.caption)),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < group.employees.length; i++) ...[
          if (i > 0) const Divider(height: 20),
          _LifecycleRow(employee: group.employees[i], tab: tab),
        ],
      ],
    );
  }
}

class _LifecycleRow extends StatelessWidget {
  final HrLifecycleEmployee employee;
  // 0 = New Joiners, 1 = Notice Period, 2 = Anniversaries — picks which
  // trailing badge/date this row shows, matching the selected tab.
  final int tab;

  const _LifecycleRow({required this.employee, required this.tab});

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (employee.department.isNotEmpty) employee.department,
      if ((employee.designation ?? '').isNotEmpty) employee.designation!,
    ];
    final secondary = parts.isEmpty ? '—' : parts.join(' · ');

    final String? trailingText;
    final IconData badgeIcon;
    final Color badgeColor;
    switch (tab) {
      case 0:
        final joining = employee.dateOfJoining;
        trailingText = (joining != null && joining.isNotEmpty) ? joining : null;
        badgeIcon = Icons.person_add_alt_1_outlined;
        badgeColor = AppColors.success;
      case 1:
        trailingText = null;
        badgeIcon = Icons.logout_outlined;
        badgeColor = AppColors.warning;
      default:
        final years = employee.yearsCompleted;
        trailingText = years != null ? '$years yrs' : null;
        badgeIcon = Icons.emoji_events_outlined;
        badgeColor = AppColors.secondary;
    }

    return GestureDetector(
      onTap: employee.employeeId.isEmpty
          ? null
          : () => goToDashboardSection(context, '${AppRoutes.employees}/${employee.employeeId}'),
      child: Row(
        children: [
          InitialsAvatar(name: employee.fullName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.fullName,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(secondary, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis, maxLines: 1),
              ],
            ),
          ),
          if (trailingText != null) ...[
            Text(trailingText, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
            const SizedBox(width: 8),
          ],
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(badgeIcon, size: 16, color: badgeColor),
          ),
        ],
      ),
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
          // A different color per department (cycling through the same
          // palette web uses for its department swatches) instead of one
          // flat color for every bar — makes each row distinguishable at a
          // glance in a list that can run to a dozen+ departments.
          final palette = [
            AppColors.primary,
            AppColors.success,
            AppColors.info,
            AppColors.warning,
            AppColors.secondary,
            AppColors.error,
          ];
          return Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                BarRow(
                  label: list[i].department,
                  value: list[i].count,
                  maxValue: effectiveMax,
                  color: palette[i % palette.length],
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
      iconWidget: const SectionIconAsset('assets/images/Birthday.png'),
      accentColor: AppColors.secondary,
      child: birthdaysAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const SectionMessage(
              iconWidget: SectionIconAsset('assets/images/Birthday.png', size: 28),
              label: 'No birthdays today',
            );
          }
          return Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _BirthdayRow(employee: list[i], isToday: true),
              ],
            ],
          );
        },
        loading: () => const SectionMessage(
          iconWidget: SectionIconAsset('assets/images/Birthday.png', size: 28),
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
      iconWidget: const SectionIconAsset('assets/images/Birthday.png'),
      accentColor: AppColors.secondary,
      child: birthdaysAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const SectionMessage(
              iconWidget: SectionIconAsset('assets/images/Birthday.png', size: 28),
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
          iconWidget: SectionIconAsset('assets/images/Birthday.png', size: 28),
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
  // Today's card gets a soft green tint per row (matching web's treatment
  // of today's birthdays specifically, distinct from the plain Upcoming
  // list) — everything else about the row is identical either way.
  final bool isToday;

  const _BirthdayRow({required this.employee, this.showDaysUntil = false, this.isToday = false});

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (employee.department.isNotEmpty) employee.department,
      if (employee.branch.isNotEmpty) employee.branch,
    ];
    return Container(
      padding: isToday ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : EdgeInsets.zero,
      decoration: isToday
          ? BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10))
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎂', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.fullName,
                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
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
      ),
    );
  }
}
