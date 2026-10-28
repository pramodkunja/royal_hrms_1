import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart'
    show EmployeeFilters;
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart'
    show employeeFiltersProvider;
import 'package:mobile_app/features/dashboard/data/models/admin_dashboard_models.dart';
import 'package:mobile_app/features/dashboard/data/models/dashboard_common_models.dart';
import 'package:mobile_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/attendance_ring_card.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/dashboard_section.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';

/// Port of web's `AdminDashboard.tsx` — System Admin's role-specific
/// dashboard. Single scrollable column (phone, not web's 2-column desktop
/// grid) mirroring web's section reading order: System Console header,
/// Quick Actions, Pending Approvals, Department Headcount, Announcement,
/// Employee Lifecycle, Birthdays, Audit Logs.
class AdminDashboardView extends ConsumerWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refreshAll() async {
      ref.invalidate(systemAdminKpisProvider);
      ref.invalidate(todayAttendanceProvider);
      ref.invalidate(systemAdminAnnouncementProvider);
      ref.invalidate(pendingApprovalsProvider);
      ref.invalidate(systemAdminDepartmentHeadcountProvider);
      ref.invalidate(systemAdminEmployeeLifecycleProvider);
      ref.invalidate(systemAdminBirthdaysTodayProvider);
      ref.invalidate(systemAdminBirthdaysUpcomingProvider);
      ref.invalidate(auditLogsPageProvider);
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
            const _SystemConsoleHeader(),
            const SizedBox(height: 20),
            const AttendanceRingCard(),
            const SizedBox(height: 20),
            QuickAccessCard(items: kQuickItemsAdmin),
            const SizedBox(height: 20),
            const _PendingApprovalsCard(),
            const SizedBox(height: 20),
            const _DepartmentHeadcountCard(),
            const SizedBox(height: 20),
            const _AnnouncementCard(),
            const SizedBox(height: 20),
            const _EmployeeLifecycleCard(),
            const SizedBox(height: 20),
            const _TodaysBirthdaysCard(),
            const SizedBox(height: 20),
            const _UpcomingBirthdaysCard(),
            const SizedBox(height: 20),
            const _AuditLogsCard(),
          ],
        ),
      ),
    );
  }
}

// ── System Console header (gradient hero + white stat strip; shared shell —
// see dashboard_section.dart's ConsoleHeaderShell/StatusRingAvatar/etc, also
// used by the Employee, HR, and generic/Manager dashboards) ────────────────

class _SystemConsoleHeader extends ConsumerWidget {
  const _SystemConsoleHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final kpisAsync = ref.watch(systemAdminKpisProvider);
    final name = (user?.fullName ?? '').isEmpty ? 'Admin' : user!.fullName;
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
                    const RoleBadgePill(label: 'SYSTEM CONSOLE', icon: Icons.terminal_rounded),
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
          const SizedBox(height: 12),
          // Service health stays its own small row — a system admin's
          // "is the platform healthy" glance is a different concept from
          // "am I personally clocked in" below it, so it isn't folded into
          // the shared info bar, just kept in the same gradient zone.
          kpisAsync.maybeWhen(
            data: (kpis) => Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _HealthDot(label: 'API', isUp: kpis.apiStatus),
                _HealthDot(label: 'DB', isUp: kpis.databaseStatus),
                _HealthDot(label: 'Mail', isUp: kpis.mailStatus),
                _HealthDot(label: 'Storage', isUp: kpis.storageStatus),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          ConsoleInfoBar(clockedIn: clockedIn),
        ],
      ),
      statsContent: kpisAsync.when(
        data: (kpis) => ConsoleStatsRow(stats: [
          (icon: Icons.groups_outlined, value: '${kpis.totalEmployees}', label: 'Employees', color: AppColors.primary),
          (
            icon: Icons.fact_check_outlined,
            value: '${kpis.pendingApprovals}',
            label: 'Approvals',
            color: AppColors.warning,
          ),
          (
            icon: Icons.person_add_alt_outlined,
            value: '${kpis.employeesOnboarding}',
            label: 'Onboard',
            color: AppColors.success,
          ),
          (icon: Icons.apartment_outlined, value: '${kpis.activeBranches}', label: 'Branches', color: AppColors.info),
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
              onPressed: () => ref.invalidate(systemAdminKpisProvider),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthDot extends StatelessWidget {
  final String label;
  final bool isUp;

  const _HealthDot({required this.label, required this.isUp});

  @override
  Widget build(BuildContext context) {
    final color = isUp ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption
              .copyWith(color: Colors.white.withValues(alpha: 0.85)),
        ),
      ],
    );
  }
}

// ── Pending Approvals ─────────────────────────────────────────────────────────

class _PendingApprovalsCard extends ConsumerWidget {
  const _PendingApprovalsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalsAsync = ref.watch(pendingApprovalsProvider);

    // Built as a bespoke shell (not the shared SectionCard) so the "View
    // all" footer can sit in its own full-bleed, light-tinted band with
    // rounded bottom corners — matching the reference design exactly,
    // which SectionCard's single uniform padded body can't produce.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(Icons.done_all_rounded, size: 19, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Pending Approvals', style: AppTextStyles.h4),
                ),
                approvalsAsync.maybeWhen(
                  data: (a) => _PendingBadge(count: a.totalPending),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: approvalsAsync.when(
              data: (approvals) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ActionRow(
                    icon: Icons.beach_access_outlined,
                    iconColor: AppColors.success,
                    title: 'Leave Requests',
                    count: approvals.leaveRequests,
                    onTap: () => goToDashboardSection(context, AppRoutes.leave),
                  ),
                  const Divider(height: 24),
                  ActionRow(
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppColors.warning,
                    title: 'Expense Claims',
                    count: approvals.expenseClaims,
                    onTap: () => goToDashboardSection(context, AppRoutes.expenses),
                  ),
                  const Divider(height: 24),
                  ActionRow(
                    icon: Icons.how_to_reg_outlined,
                    iconColor: AppColors.primary,
                    title: 'Onboarding Reviews',
                    count: approvals.onboardingReviews,
                    // No dedicated onboarding-review screen exists in this
                    // app yet, so this opens the Employees list pre-filtered
                    // to status=onboarding (a real filter EmployeesScreen
                    // already supports) — the closest genuine destination
                    // instead of a fake/dead link.
                    onTap: () {
                      ref.read(employeeFiltersProvider.notifier).state =
                          const EmployeeFilters(status: 'onboarding');
                      goToDashboardSection(context, AppRoutes.employees);
                    },
                  ),
                  const Divider(height: 24),
                  ActionRow(
                    icon: Icons.logout_outlined,
                    iconColor: AppColors.error,
                    title: 'Separation Requests',
                    count: approvals.separationRequests,
                    onTap: () => goToDashboardSection(context, AppRoutes.separation),
                  ),
                ],
              ),
              loading: () => const SectionMessage(
                icon: Icons.done_all_rounded,
                label: 'Loading…',
              ),
              error: (e, _) => SectionError(
                message: friendlyDashboardError(e),
                onRetry: () => ref.invalidate(pendingApprovalsProvider),
              ),
            ),
          ),
          approvalsAsync.maybeWhen(
            data: (_) => GestureDetector(
              onTap: () => goToDashboardSection(context, AppRoutes.approvals),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLow,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View all pending approvals',
                      style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final int count;
  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count pending',
        style: AppTextStyles.labelSmall
            .copyWith(color: AppColors.warning, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Department Headcount ──────────────────────────────────────────────────────

class _DepartmentHeadcountCard extends ConsumerWidget {
  const _DepartmentHeadcountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headcountAsync = ref.watch(systemAdminDepartmentHeadcountProvider);

    return SectionCard(
      title: 'Department Headcount',
      icon: Icons.groups_outlined,
      accentColor: AppColors.info,
      child: headcountAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const SectionMessage(
              icon: Icons.groups_outlined,
              label: 'No department data available',
            );
          }
          final maxValue = list
              .map((d) => d.count)
              .fold<int>(0, (a, b) => a > b ? a : b);
          return Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                BarRow(
                  label: list[i].department,
                  value: list[i].count,
                  maxValue: maxValue <= 0 ? 1 : maxValue,
                  color: AppColors.info,
                ),
              ],
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.groups_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(systemAdminDepartmentHeadcountProvider),
        ),
      ),
    );
  }
}

// ── Announcement ───────────────────────────────────────────────────────────

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementAsync = ref.watch(systemAdminAnnouncementProvider);

    return SectionCard(
      title: 'Latest Announcement',
      iconWidget: const SectionIconAsset('assets/images/Announcement.png'),
      accentColor: AppColors.primary,
      child: announcementAsync.when(
        data: (announcement) {
          // Treat a blank title the same as no announcement at all — the
          // backend returns `data: null` when none exists, but this guards
          // against ever silently rendering an empty card instead of the
          // "No announcements yet" message if a malformed/empty object ever
          // comes back instead of a clean null.
          if (announcement == null || announcement.title.isEmpty) {
            return const SectionMessage(
              iconWidget: SectionIconAsset('assets/images/Announcement.png', size: 28),
              label: 'No announcements yet',
            );
          }
          final metaParts = [
            announcement.category,
            if (announcement.postedBy != null &&
                announcement.postedBy!.isNotEmpty)
              announcement.postedBy!,
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
          onRetry: () => ref.invalidate(systemAdminAnnouncementProvider),
        ),
      ),
    );
  }
}

/// Formats an ISO datetime string as "20 Jul, 01:27 pm" — no `intl` package
/// dependency in this project, so this is a small hand-rolled formatter
/// rather than pulling one in for a single display need.
String _formatDateTime(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final local = dt.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  var hour = local.hour % 12;
  if (hour == 0) hour = 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'am' : 'pm';
  return '${local.day} ${months[local.month - 1]}, '
      '${hour.toString().padLeft(2, '0')}:$minute $period';
}

// ── Employee Lifecycle (tabbed) ───────────────────────────────────────────────

class _EmployeeLifecycleCard extends ConsumerStatefulWidget {
  const _EmployeeLifecycleCard();

  @override
  ConsumerState<_EmployeeLifecycleCard> createState() =>
      _EmployeeLifecycleCardState();
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
    final lifecycleAsync = ref.watch(systemAdminEmployeeLifecycleProvider);

    return SectionCard(
      title: 'Employee Lifecycle',
      icon: Icons.sync_alt_outlined,
      accentColor: AppColors.success,
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
          final groups = [
            lifecycle.newJoiners,
            lifecycle.noticePeriod,
            lifecycle.workAnniversaries,
          ];
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
              _LifecycleList(group: groups[_tab], showYears: _tab == 2),
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.sync_alt_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(systemAdminEmployeeLifecycleProvider),
        ),
      ),
    );
  }
}


class _LifecycleList extends StatelessWidget {
  final AdminLifecycleGroup group;
  final bool showYears;

  const _LifecycleList({required this.group, required this.showYears});

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
          _LifecycleRow(employee: group.employees[i], showYears: showYears),
        ],
      ],
    );
  }
}

class _LifecycleRow extends StatelessWidget {
  final AdminLifecycleEmployee employee;
  final bool showYears;

  const _LifecycleRow({required this.employee, required this.showYears});

  @override
  Widget build(BuildContext context) {
    final secondary =
        '— · ${employee.department.isNotEmpty ? employee.department : "—"}';
    final trailingText = showYears
        ? (employee.years != null ? '${employee.years} yrs' : null)
        : employee.dateOfJoining;

    return GestureDetector(
      onTap: employee.employeeId.isEmpty
          ? null
          : () => goToDashboardSection(
              context, '${AppRoutes.employees}/${employee.employeeId}'),
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
                Text(
                  secondary,
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (trailingText != null && trailingText.isNotEmpty) ...[
            Text(
              trailingText,
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_available_outlined,
                size: 16, color: AppColors.success),
          ),
        ],
      ),
    );
  }
}

// ── Birthdays (two separate cards — Today / Upcoming) ────────────────────────

class _TodaysBirthdaysCard extends ConsumerWidget {
  const _TodaysBirthdaysCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthdaysAsync = ref.watch(systemAdminBirthdaysTodayProvider);

    return SectionCard(
      title: "Today's Birthdays",
      iconWidget: const SectionIconAsset('assets/images/Birthday.png'),
      accentColor: AppColors.primary,
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
                _BirthdayRow(entry: list[i], showDaysUntil: false),
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
          onRetry: () => ref.invalidate(systemAdminBirthdaysTodayProvider),
        ),
      ),
    );
  }
}

class _UpcomingBirthdaysCard extends ConsumerWidget {
  const _UpcomingBirthdaysCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthdaysAsync = ref.watch(systemAdminBirthdaysUpcomingProvider);

    return SectionCard(
      title: 'Upcoming Birthdays',
      iconWidget: const SectionIconAsset('assets/images/Birthday.png'),
      accentColor: AppColors.primary,
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
                _BirthdayRow(entry: list[i], showDaysUntil: true),
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
          onRetry: () => ref.invalidate(systemAdminBirthdaysUpcomingProvider),
        ),
      ),
    );
  }
}

class _BirthdayRow extends StatelessWidget {
  final DashboardBirthdayEmployee entry;
  final bool showDaysUntil;

  const _BirthdayRow({required this.entry, required this.showDaysUntil});

  @override
  Widget build(BuildContext context) {
    final sub = [entry.department, entry.branch]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Row(
      children: [
        const Text('🎂', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.fullName,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (sub.isNotEmpty)
                Text(
                  sub,
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
        ),
        if (showDaysUntil)
          Text(
            'In ${entry.daysUntil} day${entry.daysUntil == 1 ? '' : 's'}',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

// ── Audit Logs (module filter + Load more pagination) ───────────────────────

const _kAuditModules = <String>[
  'accounts',
  'attendance',
  'hrms',
  'recruitment',
  'branch',
  'announcements',
];

class _AuditLogsCard extends ConsumerStatefulWidget {
  const _AuditLogsCard();

  @override
  ConsumerState<_AuditLogsCard> createState() => _AuditLogsCardState();
}

class _AuditLogsCardState extends ConsumerState<_AuditLogsCard> {
  String _module = ''; // '' = All
  final List<AuditLogEntry> _entries = [];
  int _total = 0;
  bool _loadedOnce = false;
  bool _loadingMore = false;

  void _applyFirstPage(AuditLogsResponse page) {
    _entries
      ..clear()
      ..addAll(page.results);
    _total = page.count;
    _loadedOnce = true;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _entries.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final next = await ref.read(dashboardDataSourceProvider).fetchAuditLogs(
            limit: 20,
            offset: _entries.length,
            module: _module,
          );
      if (!mounted) return;
      setState(() {
        _entries.addAll(next.results);
        _total = next.count;
      });
    } catch (_) {
      // A transient "load more" failure shouldn't blank the page already
      // shown — the user can just tap it again.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (offset: 0, module: _module);
    ref.listen(auditLogsPageProvider(key), (prev, next) {
      if (next.isLoading) _loadedOnce = false;
    });
    final firstPageAsync = ref.watch(auditLogsPageProvider(key));

    return SectionCard(
      title: 'Audit Logs',
      icon: Icons.history_outlined,
      accentColor: AppColors.textSecondary,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModuleFilterDropdown(
            value: _module,
            onChanged: (m) => setState(() {
              _module = m;
              _loadedOnce = false;
              _entries.clear();
            }),
          ),
          const SizedBox(width: 8),
          // Full audit trail (search, date range, pagination) already
          // exists at Settings → Audit Log — this card is just a
          // summary widget, so "View all" opens that real screen rather
          // than duplicating its filters here.
          GestureDetector(
            onTap: () => context.push(AppRoutes.settingsAuditLog),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View all',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward, size: 13, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
      child: firstPageAsync.when(
        data: (page) {
          if (!_loadedOnce) _applyFirstPage(page);
          if (_entries.isEmpty) {
            return const SectionMessage(
              icon: Icons.history_outlined,
              label: 'No audit log entries yet',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _entries.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _AuditLogRow(entry: _entries[i]),
              ],
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_entries.length} of $_total entries',
                    style: AppTextStyles.caption,
                  ),
                  if (_entries.length < _total)
                    TextButton.icon(
                      onPressed: _loadingMore ? null : _loadMore,
                      icon: _loadingMore
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more, size: 16),
                      label: const Text('Load more'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.history_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(auditLogsPageProvider(key)),
        ),
      ),
    );
  }
}

class _ModuleFilterDropdown extends StatelessWidget {
  final String value; // '' = All
  final ValueChanged<String> onChanged;

  const _ModuleFilterDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        const PopupMenuItem(value: '', child: Text('All')),
        for (final m in _kAuditModules) PopupMenuItem(value: m, child: Text(m)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value.isEmpty ? 'All' : value, style: AppTextStyles.labelSmall),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _AuditLogRow extends StatelessWidget {
  final AuditLogEntry entry;

  const _AuditLogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.infoContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.action.toUpperCase(),
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.info, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDateTime(entry.createdAt),
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.person_outline, size: 14, color: AppColors.textHint),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                entry.user ?? '—',
                style: AppTextStyles.caption,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.public, size: 14, color: AppColors.textHint),
            const SizedBox(width: 4),
            Text(entry.ipAddress ?? '—', style: AppTextStyles.caption),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.backgroundMid,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.module,
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
