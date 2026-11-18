import 'package:flutter/material.dart';
import 'package:mobile_app/core/router/access_control.dart' show AppModules, userHasModule;
import 'package:mobile_app/features/settings/presentation/providers/settings_providers.dart' show kAuditLogModules;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/module_gate.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart' show EmployeeFilters, EmployeeModel;
import 'package:mobile_app/features/employees/presentation/widgets/send_wish_sheet.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart'
    show employeeFiltersProvider;
import 'package:mobile_app/features/dashboard/data/models/admin_dashboard_models.dart';
import 'package:mobile_app/features/dashboard/data/models/dashboard_common_models.dart';
import 'package:mobile_app/features/dashboard/data/models/hr_dashboard_models.dart' show HrLifecycleEmployee;
import 'package:mobile_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/hr_dashboard_view.dart' show HrActionQueueCard;
import 'package:mobile_app/features/dashboard/presentation/widgets/attendance_ring_card.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/dashboard_section.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/emp_celebration_cards.dart'
    show canSendBirthdayWishes;
import 'package:mobile_app/features/dashboard/presentation/widgets/hr_notice_period_row.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/send_all_birthday_wishes_sheet.dart';

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
      ref.invalidate(hrActionQueueProvider);
      ref.invalidate(hrSeparationQueueCountProvider);
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

    // Web AdminDashboard.tsx:83: a Branch Admin also gets its own branch's
    // Action Queue, between Pending Approvals and Department Headcount.
    final branchAdmin = ref.watch(authStateProvider.select((s) => s.valueOrNull?.user?.canManageBranch ?? false));

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
            // Latest announcement above Attendance (requested order; web
            // AdminDashboard also renders AnnouncementCard right after the console).
            // Web AdminDashboard: announcement and attendance cards only with
            // their modules.
            const ModuleGate(
              module: AppModules.announcements,
              child: Column(children: [_AnnouncementCard(), SizedBox(height: 20)]),
            ),
            const ModuleGate(
              module: AppModules.attendance,
              child: Column(children: [AttendanceRingCard(), SizedBox(height: 20)]),
            ),
            QuickAccessCard(items: kQuickItemsAdmin),
            const SizedBox(height: 20),
            const _PendingApprovalsCard(),
            const SizedBox(height: 20),
            if (branchAdmin) ...[
              const HrActionQueueCard(key: Key('admin-branch-action-queue')),
              const SizedBox(height: 20),
            ],
            const _DepartmentHeadcountCard(),
            const SizedBox(height: 20),
            const _EmployeeLifecycleCard(),
            const SizedBox(height: 20),
            const _TodaysBirthdaysCard(),
            const SizedBox(height: 20),
            const _UpcomingBirthdaysCard(),
            const SizedBox(height: 20),
            const AdminAuditLogsCard(),
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
    // Web AdminDashboard: clock-in / attendance status only with the
    // attendance module (not fetched otherwise).
    final attendanceOn = userHasModule(user, AppModules.attendance);
    final clockedIn = attendanceOn && (ref.watch(todayAttendanceProvider).valueOrNull?.isClockedIn ?? false);

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
          if (attendanceOn) ConsoleInfoBar(clockedIn: clockedIn),
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
          style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.85)),
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
    // Web PendingApprovalsWidget ROW_MODULES: leave / expense / separation
    // rows only with their modules.
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final leaveOn = userHasModule(user, AppModules.leave);
    final expensesOn = userHasModule(user, AppModules.expenses);
    final separationOn = userHasModule(user, AppModules.separation);

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
                  if (leaveOn) ...[
                    ActionRow(
                      icon: Icons.beach_access_outlined,
                      iconColor: AppColors.success,
                      title: 'Leave Requests',
                      count: approvals.leaveRequests,
                      // Web PendingApprovalsWidget: Leave Requests → /dashboard/approvals.
                      onTap: () => goToDashboardSection(context, AppRoutes.approvals),
                    ),
                    const Divider(height: 24),
                  ],
                  if (expensesOn) ...[
                    ActionRow(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: AppColors.warning,
                      title: 'Expense Claims',
                      count: approvals.expenseClaims,
                      onTap: () => goToDashboardSection(context, AppRoutes.expenses),
                    ),
                    const Divider(height: 24),
                  ],
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
                      ref.read(employeeFiltersProvider.notifier).state = const EmployeeFilters(status: 'onboarding');
                      goToDashboardSection(context, AppRoutes.employees);
                    },
                  ),
                  if (separationOn) ...[
                    const Divider(height: 24),
                    ActionRow(
                      icon: Icons.logout_outlined,
                      iconColor: AppColors.error,
                      title: 'Separation Requests',
                      count: approvals.separationRequests,
                      onTap: () => goToDashboardSection(context, AppRoutes.separation),
                    ),
                  ],
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
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Flexible: wraps on a narrow screen / large text
                    // instead of overflowing (found by Task 74's layout check).
                    Flexible(
                        child: Text(
                      'View all pending approvals',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                    )),
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
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700),
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
          final maxValue = list.map((d) => d.count).fold<int>(0, (a, b) => a > b ? a : b);
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
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
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
          onRetry: () => ref.invalidate(systemAdminEmployeeLifecycleProvider),
        ),
      ),
    );
  }
}

class _LifecycleList extends StatelessWidget {
  final AdminLifecycleGroup group;
  // 0 = New Joiners, 1 = Notice Period, 2 = Anniversaries.
  final int tab;

  const _LifecycleList({required this.group, required this.tab});

  @override
  Widget build(BuildContext context) {
    if (group.employees.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        // Web admin EmployeeLifecycleTabs: "No records" (Notice tab).
        child: Center(child: Text(tab == 1 ? 'No records' : 'No data', style: AppTextStyles.caption)),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < group.employees.length; i++) ...[
          if (i > 0) const Divider(height: 20),
          // Server order (last working day, then name) is kept as sent.
          if (tab == 1)
            _AdminNoticeRow(employee: group.employees[i])
          else
            _LifecycleRow(employee: group.employees[i], showYears: tab == 2),
        ],
      ],
    );
  }
}

/// Notice Period tab: web components/dashboard/NoticePeriodRow.tsx (as used
/// by the admin EmployeeLifecycleTabs) — name, "<employee id> · <department>
/// · <branch>", "Approved <date>", "Last day: <date>" and the server's
/// countdown / "Notice completed". Same widget as the HR dashboard's tab.
/// Tapping opens the employee, as every other mobile lifecycle row does.
class _AdminNoticeRow extends StatelessWidget {
  const _AdminNoticeRow({required this.employee});

  final AdminLifecycleEmployee employee;

  @override
  Widget build(BuildContext context) {
    final e = employee;
    return GestureDetector(
      key: Key('admin-notice-row-${e.requestId ?? e.employeeId}'),
      behavior: HitTestBehavior.opaque, // the whole row, not just its text
      onTap:
          e.employeeId.isEmpty ? null : () => goToDashboardSection(context, '${AppRoutes.employees}/${e.employeeId}'),
      child: HrNoticePeriodRow(
        employee: HrLifecycleEmployee(
          employeeId: e.employeeId,
          fullName: e.fullName,
          department: e.department,
          designation: null,
          dateOfJoining: null,
          yearsCompleted: null,
          anniversaryDate: null,
          branch: e.branch.trim().isEmpty ? null : e.branch.trim(),
          requestId: e.requestId,
          approvedAt: e.approvedAt,
          lastWorkingDay: e.lastWorkingDay,
          daysRemaining: e.daysRemaining,
          noticeStatus: e.noticeStatus,
        ),
      ),
    );
  }
}

class _LifecycleRow extends StatelessWidget {
  final AdminLifecycleEmployee employee;
  final bool showYears;

  const _LifecycleRow({required this.employee, required this.showYears});

  @override
  Widget build(BuildContext context) {
    final secondary = '— · ${employee.department.isNotEmpty ? employee.department : "—"}';
    final trailingText = showYears ? (employee.years != null ? '${employee.years} yrs' : null) : employee.dateOfJoining;

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
            child: Icon(Icons.event_available_outlined, size: 16, color: AppColors.success),
          ),
        ],
      ),
    );
  }
}

// ── Birthdays (two separate cards — Today / Upcoming) ────────────────────────
// Web BirthdayWidget (admin dashboard): each row has Send Wish (→ "Resend"
// once the server confirmed a send this session) and Today's card has Send
// All. Shown only to users the backend lets send (canSendBirthdayWishes —
// the send endpoint needs recruitment.edit; templates need settings.view).

/// Employee ids whose wish the server confirmed during this dashboard visit
/// (web `sentIds`, component state) — drives the Send Wish → Resend label.
final adminBirthdayWishesSentProvider = StateProvider.autoDispose<Set<String>>((ref) => const {});

Future<void> _sendWish(BuildContext context, WidgetRef ref, DashboardBirthdayEmployee e) async {
  final sent = await SendWishSheet.show(
    context,
    employee: EmployeeModel.fromJson({
      'employee_id': e.employeeId,
      'full_name': e.fullName,
      'email': e.email,
      'department': e.department,
      'designation': e.designation,
    }),
    occasionKey: 'birthday',
  );
  if (sent) {
    final n = ref.read(adminBirthdayWishesSentProvider.notifier);
    n.state = {...n.state, e.employeeId};
  }
}

class _TodaysBirthdaysCard extends ConsumerWidget {
  const _TodaysBirthdaysCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthdaysAsync = ref.watch(systemAdminBirthdaysTodayProvider);
    final canWish = canSendBirthdayWishes(ref.watch(authStateProvider).valueOrNull?.user);
    final today = birthdaysAsync.valueOrNull ?? const <DashboardBirthdayEmployee>[];

    return SectionCard(
      title: "Today's Birthdays",
      iconWidget: const SectionIconAsset('assets/images/Birthday.png'),
      accentColor: AppColors.primary,
      trailing: canWish && today.isNotEmpty
          ? OutlinedButton.icon(
              key: const Key('birthday-send-all'),
              onPressed: () async {
                final sent = await SendAllBirthdayWishesSheet.show(context, today);
                if (sent.isNotEmpty) {
                  final n = ref.read(adminBirthdayWishesSentProvider.notifier);
                  n.state = {...n.state, ...sent};
                }
              },
              icon: const Icon(Icons.celebration_outlined, size: 16),
              label: const Text('Send All'),
            )
          : null,
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
                _BirthdayRow(entry: list[i], showDaysUntil: false, canWish: canWish),
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
    final canWish = canSendBirthdayWishes(ref.watch(authStateProvider).valueOrNull?.user);

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
                _BirthdayRow(entry: list[i], showDaysUntil: true, canWish: canWish),
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

class _BirthdayRow extends ConsumerWidget {
  final DashboardBirthdayEmployee entry;
  final bool showDaysUntil;
  final bool canWish;

  const _BirthdayRow({required this.entry, required this.showDaysUntil, required this.canWish});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alreadySent = ref.watch(adminBirthdayWishesSentProvider).contains(entry.employeeId);
    final sub = [entry.department, entry.branch].where((s) => s.isNotEmpty).join(' · ');

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
        if (canWish && entry.employeeId.isNotEmpty) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            key: Key('birthday-wish-${entry.employeeId}'),
            onPressed: () => _sendWish(context, ref, entry),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(alreadySent ? 'Resend' : 'Send Wish'),
          ),
        ],
      ],
    );
  }
}

// ── Audit Logs (module filter + Load more pagination) ───────────────────────

/// Options: the module names the backend actually writes to AuditLog.module
/// (kAuditLogModules — the same list as Settings → Audit Log), sent as-is:
/// GET /dashboard/system-admin/audit-logs/?module= matches exactly
/// (SystemAdminAuditLogsView). Task 74 (audit L9): the old 'attendance' and
/// 'hrms' options matched no audit row — attendance events go to the separate
/// AttendanceAuditLog — so they always showed nothing. Web's widget sends
/// display labels ("Employee", "Auth", …), which match nothing either.
///
/// An option is hidden when the backend hides its rows: the same view drops
/// rows whose subscription module is off (apps/tenants/access.py
/// AUDIT_MODULES). Keyed by the stored names; AUDIT_MODULES spells
/// announcements' key 'announcement', which no audit row uses, so the
/// server never hides Announcements rows and the option stays.
const _kAuditHiddenWith = <String, String>{
  'leave': AppModules.leave,
  'payroll': AppModules.payroll,
  'recruitment': AppModules.recruitment,
  'assets': AppModules.assets,
  'documents': AppModules.documents,
  'wfh': AppModules.wfh,
};

/// The admin dashboard's Audit Logs card (public so its layout can be
/// tested on its own).
class AdminAuditLogsCard extends ConsumerStatefulWidget {
  const AdminAuditLogsCard({super.key});

  @override
  ConsumerState<AdminAuditLogsCard> createState() => _AuditLogsCardState();
}

class _AuditLogsCardState extends ConsumerState<AdminAuditLogsCard> {
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
      // Bounded (and its parts Flexible) so the filter and "View all" never
      // push past the card at large text sizes; the title wraps instead.
      trailing: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.55),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                  child: _ModuleFilterDropdown(
                options: [
                  for (final m in kAuditLogModules)
                    if (userHasModule(ref.watch(authStateProvider).valueOrNull?.user, _kAuditHiddenWith[m.value])) m,
                ],
                value: _module,
                onChanged: (m) => setState(() {
                  _module = m;
                  _loadedOnce = false;
                  _entries.clear();
                }),
              )),
              const SizedBox(width: 8),
              // Full audit trail (search, date range, pagination) already
              // exists at Settings → Audit Log — this card is just a
              // summary widget, so "View all" opens that real screen rather
              // than duplicating its filters here.
              Flexible(
                  child: GestureDetector(
                onTap: () => context.push(AppRoutes.settingsAuditLog),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'View all',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_forward, size: 13, color: AppColors.primary),
                  ],
                ),
              )),
            ],
          )),
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
                  Flexible(
                    child: Text(
                      '${_entries.length} of $_total entries',
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
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
  final String value; // '' = All; otherwise a backend module name
  final ValueChanged<String> onChanged;

  /// Backend value (sent) and readable label (shown).
  final List<({String value, String label})> options;

  const _ModuleFilterDropdown({required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        const PopupMenuItem(value: '', child: Text('All modules')),
        for (final m in options) PopupMenuItem(value: m.value, child: Text(m.label)),
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
            // Flexible + ellipsis: the header bounds this button, so a long
            // label ("Financial Year") or large text shrinks instead of
            // pushing past the screen edge.
            Flexible(
              child: Text(
                value.isEmpty
                    ? 'All modules'
                    : options.where((m) => m.value == value).map((m) => m.label).firstOrNull ?? value,
                key: const Key('dashboard-audit-module'),
                style: AppTextStyles.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.info, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Flexible too: at large text sizes badge and date share the row.
            Flexible(
              child: Text(
                _formatDateTime(entry.createdAt),
                style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
            Flexible(
              child: Text(entry.ipAddress ?? '—',
                  style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            // Long stored names (e.g. company_financial_year) or large text
            // shrink with an ellipsis instead of overflowing the row.
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundMid,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.module,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
