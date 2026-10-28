import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart'
    hide employeeAttendanceSummaryProvider;
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/hrms/domain/entities/birthday_entity.dart';
import 'package:mobile_app/features/hrms/presentation/providers/hrms_providers.dart';
import '../../data/models/employee_dashboard_models.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/attendance_ring_card.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/quick_access.dart';

/// Full Employee-role dashboard — a pixel-level port of web's
/// `EmployeeDashboard.tsx`: `EmpConsole` (dark hero card: greeting, clock
/// control, 4-stat row, attendance status strip) → Quick Actions →
/// `EmpLeaveBalances` + `EmpAttendanceSummary` → `EmpActionItems` +
/// `EmpRecentRequests` → `EmpAnnouncement` (a dismissible inline banner,
/// not a card — renders nothing when there's no announcement, exactly like
/// web). Birthdays + Quick Links are kept below web's section list — they
/// aren't part of web's Employee dashboard at all, but they were already
/// working correctly in this app before this port and don't change how the
/// core sections above them look, so there's no reason to remove them.
class EmployeeDashboardView extends ConsumerWidget {
  const EmployeeDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final permissions = user?.permissions ?? const [];
    final canViewBirthdays = permissions.contains('employees.view');

    Future<void> refreshAll() async {
      ref.invalidate(employeeKpisProvider);
      ref.invalidate(todayAttendanceProvider);
      ref.invalidate(employeeLeaveBalancesProvider);
      ref.invalidate(employeeAttendanceSummaryForProvider);
      ref.invalidate(employeeActionItemsProvider);
      ref.invalidate(employeeRecentRequestsProvider);
      ref.invalidate(sharedAnnouncementProvider);
      if (canViewBirthdays) ref.invalidate(birthdaysProvider);
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
            const _EmpConsoleCard(),
            const SizedBox(height: 20),
            const AttendanceRingCard(),
            const SizedBox(height: 20),
            QuickAccessCard(items: kQuickItemsEmployee),
            const SizedBox(height: 20),
            const _EmpLeaveBalancesCard(),
            const SizedBox(height: 20),
            const _EmpAttendanceSummaryCard(),
            const SizedBox(height: 20),
            const _EmpActionItemsCard(),
            const SizedBox(height: 20),
            const _EmpRecentRequestsCard(),
            const SizedBox(height: 20),
            const _EmpAnnouncementBanner(),
            if (canViewBirthdays) ...[
              const SizedBox(height: 20),
              const _TodaysBirthdaysCard(),
              const SizedBox(height: 20),
              const _UpcomingBirthdaysCard(),
            ],
            const SizedBox(height: 20),
            const _QuickLinksCard(),
          ],
        ),
      ),
    );
  }
}

// ── Console (gradient hero + white stat strip; shared shell — see
// dashboard_section.dart's ConsoleHeaderShell/StatusRingAvatar/etc, also
// used by the HR, Admin, and generic/Manager dashboards) ───────────────────

class _EmpConsoleCard extends ConsumerWidget {
  const _EmpConsoleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final name = (user?.fullName ?? '').isEmpty ? 'there' : user!.fullName;
    final kpisAsync = ref.watch(employeeKpisProvider);
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
                    const RoleBadgePill(label: 'EMPLOYEE WORKSPACE', icon: Icons.badge_outlined),
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
          (
            icon: Icons.fingerprint,
            value: '${kpis.daysPresent}/${kpis.workingDays}',
            label: 'Days Present',
            color: AppColors.success,
          ),
          (icon: Icons.event_busy_outlined, value: '${kpis.absentDays}', label: 'Absent Days', color: AppColors.error),
          (
            icon: Icons.checklist_outlined,
            value: '${kpis.pendingActionItems}',
            label: 'Action Items',
            color: AppColors.warning,
          ),
          (
            icon: Icons.receipt_long_outlined,
            value: '${kpis.pendingExpenseClaims}',
            label: 'Expenses',
            color: AppColors.info,
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
              onPressed: () => ref.invalidate(employeeKpisProvider),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Leave balances (grid-of-cells, matching web's EmpLeaveBalances) ────────

// A getter (not a `const` map) so these read the live, theme-aware
// AppColors fields — 3 of these 4 values were previously hardcoded hex
// literals that happened to exactly equal a light-mode-only AppColors
// value, so they stayed pinned to that hue after a dark-mode toggle while
// every other themed color on this screen correctly flipped. 'lwp' has no
// existing AppColors equivalent, so it's left as a literal.
Map<String, Color> get _kLeaveTypeColor => {
  'casual': AppColors.info,
  'sick': AppColors.warning,
  'earned': AppColors.success,
  'lwp': const Color(0xFF64748B),
};

const Map<String, String> _kLeaveTypeLabel = {
  'casual': 'Casual Leave',
  'sick': 'Sick Leave',
  'earned': 'Earned Leave',
  'maternity': 'Maternity Leave',
  'paternity': 'Paternity Leave',
  'lwp': 'Leave Without Pay',
};

class _EmpLeaveBalancesCard extends ConsumerWidget {
  const _EmpLeaveBalancesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(employeeLeaveBalancesProvider);
    final year = DateTime.now().year;

    // No "Apply Leave" trailing button here anymore — AttendanceRingCard
    // (right below the console header, above this card) already has one,
    // and having the same action twice in a row down the page read as
    // redundant rather than a deliberate second shortcut.
    return SectionCard(
      title: 'Leave Balances — $year',
      icon: Icons.beach_access_outlined,
      accentColor: AppColors.warning,
      child: balancesAsync.when(
        data: (summary) {
          if (summary.balances.isEmpty) {
            return SectionMessage(
              icon: Icons.beach_access_outlined,
              label:
                  'No leave balances found for ${summary.year}. Contact HR to credit your leave.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: summary.balances.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // Tall enough for _EmpBalanceCell's optional trailing "N
                  // used" line (only rendered when balance.usedDays > 0) —
                  // 96 fit the common case but overflowed by 6px on any
                  // balance with recorded usage.
                  mainAxisExtent: 104,
                ),
                itemBuilder: (context, i) => _EmpBalanceCell(balance: summary.balances[i]),
              ),
              if (summary.lopDays > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.error_outline, size: 14, color: AppColors.error),
                    const SizedBox(width: 6),
                    Text(
                      '${summary.lopDays.toStringAsFixed(summary.lopDays == summary.lopDays.roundToDouble() ? 0 : 1)} LOP day${summary.lopDays == 1 ? '' : 's'} this year',
                      style: AppTextStyles.caption.copyWith(color: AppColors.error),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.beach_access_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(employeeLeaveBalancesProvider),
        ),
      ),
    );
  }
}

class _EmpBalanceCell extends StatelessWidget {
  final EmployeeLeaveBalance balance;
  const _EmpBalanceCell({required this.balance});

  @override
  Widget build(BuildContext context) {
    final color = _kLeaveTypeColor[balance.leaveType] ?? AppColors.primary;
    final label = _kLeaveTypeLabel[balance.leaveType] ?? balance.leaveType;
    final pct = balance.totalDays > 0
        ? (balance.remaining / balance.totalDays).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                balance.remaining.toStringAsFixed(
                    balance.remaining == balance.remaining.roundToDouble() ? 0 : 1),
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'of ${balance.totalDays.toStringAsFixed(balance.totalDays == balance.totalDays.roundToDouble() ? 0 : 1)} days',
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: AppColors.backgroundMid,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (balance.usedDays > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${balance.usedDays.toStringAsFixed(balance.usedDays == balance.usedDays.roundToDouble() ? 0 : 1)} used'
              '${balance.carriedForward > 0 ? ' · ${balance.carriedForward.toStringAsFixed(balance.carriedForward == balance.carriedForward.roundToDouble() ? 0 : 1)} carried forward' : ''}',
              style: AppTextStyles.labelSmall.copyWith(fontSize: 10, color: AppColors.textHint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Attendance summary (month picker + % bar + 9-stat grid) ────────────────

const _kMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class _EmpAttendanceSummaryCard extends ConsumerStatefulWidget {
  const _EmpAttendanceSummaryCard();

  @override
  ConsumerState<_EmpAttendanceSummaryCard> createState() =>
      _EmpAttendanceSummaryCardState();
}

class _EmpAttendanceSummaryCardState extends ConsumerState<_EmpAttendanceSummaryCard> {
  late int _month;
  late final int _year;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
  }

  @override
  Widget build(BuildContext context) {
    final key = (month: _month, year: _year);
    final summaryAsync = ref.watch(employeeAttendanceSummaryForProvider(key));

    return SectionCard(
      title: "This Month's Attendance",
      icon: Icons.calendar_view_month_outlined,
      accentColor: AppColors.success,
      trailing: _MonthDropdown(
        month: _month,
        year: _year,
        onChanged: (m) => setState(() => _month = m),
      ),
      child: summaryAsync.when(
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Working days: ${s.workingDays}',
                    style: AppTextStyles.caption,
                  ),
                ),
                Text(
                  '${s.attendancePercentage.toStringAsFixed(s.attendancePercentage == s.attendancePercentage.roundToDouble() ? 0 : 1)}%',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: s.attendancePercentage >= 90
                        ? AppColors.success
                        : s.attendancePercentage >= 75
                            ? AppColors.warning
                            : AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (s.attendancePercentage / 100).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: AppColors.backgroundMid,
                valueColor: AlwaysStoppedAnimation(
                  s.attendancePercentage >= 90
                      ? AppColors.success
                      : s.attendancePercentage >= 75
                          ? AppColors.warning
                          : AppColors.error,
                ),
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.15,
              children: [
                _AttendanceMiniStat(
                  icon: Icons.done_all,
                  value: '${s.presentDays}',
                  label: 'Present',
                  color: AppColors.success,
                ),
                _AttendanceMiniStat(
                  icon: Icons.event_busy_outlined,
                  value: '${s.absentDays}',
                  label: 'Absent',
                  color: AppColors.error,
                ),
                _AttendanceMiniStat(
                  icon: Icons.timer_outlined,
                  value: '${s.lateMarks}',
                  label: 'Late Marks',
                  color: AppColors.warning,
                ),
                _AttendanceMiniStat(
                  icon: Icons.beach_access_outlined,
                  value: '${s.leaveDays}',
                  label: 'Leave Days',
                  color: AppColors.info,
                ),
                _AttendanceMiniStat(
                  icon: Icons.brightness_medium_outlined,
                  value: '${s.halfDays}',
                  label: 'Half Days',
                  color: AppColors.warning,
                ),
                _AttendanceMiniStat(
                  icon: Icons.pause_circle_outline,
                  value: '${s.lopPending}',
                  label: 'LOP Pending',
                  color: AppColors.error,
                ),
                _AttendanceMiniStat(
                  icon: Icons.pie_chart_outline,
                  value:
                      '${s.attendancePercentage.toStringAsFixed(s.attendancePercentage == s.attendancePercentage.roundToDouble() ? 0 : 1)}%',
                  label: 'Attendance %',
                  color: AppColors.primary,
                ),
                _AttendanceMiniStat(
                  icon: Icons.access_time,
                  value: s.avgHoursPerDay > 0 ? '${s.avgHoursPerDay.toStringAsFixed(1)}h' : '—',
                  label: 'Avg Hours/Day',
                  color: AppColors.textPrimary,
                ),
                _AttendanceMiniStat(
                  icon: Icons.more_time_outlined,
                  value: s.otHours.isEmpty ? '0h' : s.otHours,
                  label: 'OT Hours',
                  color: AppColors.secondary,
                ),
              ],
            ),
          ],
        ),
        loading: () => const SectionMessage(
          icon: Icons.calendar_view_month_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(employeeAttendanceSummaryForProvider(key)),
        ),
      ),
    );
  }
}

class _MonthDropdown extends StatelessWidget {
  final int month;
  final int year;
  final ValueChanged<int> onChanged;

  const _MonthDropdown({required this.month, required this.year, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: month,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (var m = 1; m <= 12; m++)
          PopupMenuItem(value: m, child: Text('${_kMonthNames[m - 1]} $year')),
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
            Text('${_kMonthNames[month - 1]} $year', style: AppTextStyles.labelSmall),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _AttendanceMiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _AttendanceMiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundMid,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(fontSize: 10, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Action items ─────────────────────────────────────────────────────────────

const Map<String, String> _kActionStatusLabel = {
  'pending': 'Pending',
  'approved': 'Done',
  'rejected': 'Rejected',
};

class _EmpActionItemsCard extends ConsumerWidget {
  const _EmpActionItemsCard();

  static IconData _iconFor(String actionType) {
    if (actionType == 'profile_incomplete') return Icons.person_off_outlined;
    if (actionType == 'missing_document') return Icons.file_present_outlined;
    if (actionType == 'attendance_correction') return Icons.timer_outlined;
    if (actionType == 'leave_approved') return Icons.check_circle_outline;
    if (actionType == 'leave_rejected') return Icons.cancel_outlined;
    return Icons.info_outline;
  }

  static Color _colorFor(String actionType) {
    if (actionType == 'profile_incomplete') return AppColors.error;
    if (actionType == 'missing_document') return AppColors.warning;
    if (actionType == 'attendance_correction') return AppColors.warning;
    if (actionType == 'leave_approved') return AppColors.success;
    if (actionType == 'leave_rejected') return AppColors.error;
    return AppColors.primary;
  }

  static bool _isDone(ActionItem item) =>
      item.status == 'approved' || item.actionType == 'leave_approved';

  // Mobile's route structure doesn't mirror web's 1:1 (e.g. self-service
  // attendance lives at /dashboard/my-attendance here, not
  // /dashboard/attendance as the backend's navigation_url literally says),
  // so this maps by the stable action_type instead of trusting the
  // backend's raw navigation_url string.
  static String? _routeFor(String actionType) {
    if (actionType == 'profile_incomplete') return AppRoutes.profile;
    if (actionType == 'missing_document') return AppRoutes.documents;
    if (actionType == 'attendance_correction') return AppRoutes.myAttendance;
    if (actionType.startsWith('leave_')) return AppRoutes.leave;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(employeeActionItemsProvider);

    return SectionCard(
      title: 'Action Items',
      icon: Icons.checklist_outlined,
      accentColor: AppColors.warning,
      trailing: itemsAsync.maybeWhen(
        data: (r) {
          final pending = r.actionItems.where((i) => !_isDone(i)).length;
          return pending > 0 ? _CountBadge(count: pending, label: 'pending') : const SizedBox.shrink();
        },
        orElse: () => const SizedBox.shrink(),
      ),
      child: itemsAsync.when(
        data: (response) {
          if (response.actionItems.isEmpty) {
            return const SectionMessage(
              icon: Icons.check_circle_outline,
              label: 'All caught up!',
            );
          }
          return Column(
            children: [
              for (var i = 0; i < response.actionItems.length; i++) ...[
                if (i > 0) Divider(height: 20, color: AppColors.border),
                _ActionItemRow(
                  item: response.actionItems[i],
                  icon: _iconFor(response.actionItems[i].actionType),
                  color: _colorFor(response.actionItems[i].actionType),
                  done: _isDone(response.actionItems[i]),
                  route: _routeFor(response.actionItems[i].actionType),
                ),
              ],
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.checklist_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(employeeActionItemsProvider),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final String label;
  const _CountBadge({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count $label',
        style: AppTextStyles.labelSmall
            .copyWith(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 10),
      ),
    );
  }
}

class _ActionItemRow extends StatelessWidget {
  final ActionItem item;
  final IconData icon;
  final Color color;
  final bool done;
  final String? route;

  const _ActionItemRow({
    required this.item,
    required this.icon,
    required this.color,
    required this.done,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: done ? 0.6 : 1,
      child: GestureDetector(
        onTap: route == null ? null : () => goToDashboardSection(context, route!),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: done ? FontWeight.w400 : FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(status: item.status, labelMap: _kActionStatusLabel),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Map<String, String> labelMap;
  const _StatusBadge({required this.status, required this.labelMap});

  // (background, foreground) — solid *Container fill behind the accent
  // color, matching EmployeeCard._StatusBadge's reference pattern, instead
  // of a runtime alpha blend that reads as a barely-visible tint in dark
  // mode (AppColors' dark accents are already light/pastel).
  static (Color, Color) _colorsFor(String s) => switch (s) {
        'approved' => (AppColors.successContainer, AppColors.success),
        'rejected' => (AppColors.errorContainer, AppColors.error),
        'cancelled' => (AppColors.backgroundMid, AppColors.textSecondary),
        _ => (AppColors.warningContainer, AppColors.warning),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colorsFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        labelMap[status] ?? status,
        style: AppTextStyles.labelSmall
            .copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 10),
      ),
    );
  }
}

// ── Recent requests (mixed leave / expense / attendance correction) ────────

const Map<String, String> _kRequestStatusLabel = {
  'pending': 'Pending',
  'l2_pending': 'L2 Pending',
  'approved': 'Approved',
  'rejected': 'Rejected',
  'cancelled': 'Cancelled',
};

class _EmpRecentRequestsCard extends ConsumerWidget {
  const _EmpRecentRequestsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(employeeRecentRequestsProvider);

    return SectionCard(
      title: 'Recent Requests',
      icon: Icons.inbox_outlined,
      accentColor: AppColors.warning,
      trailing: requestsAsync.maybeWhen(
        data: (r) {
          final pending =
              r.requests.where((x) => x.status == 'pending' || x.status == 'l2_pending').length;
          return pending > 0 ? _CountBadge(count: pending, label: 'pending') : const SizedBox.shrink();
        },
        orElse: () => const SizedBox.shrink(),
      ),
      child: requestsAsync.when(
        data: (response) {
          if (response.requests.isEmpty) {
            return GestureDetector(
              onTap: () => goToDashboardSection(context, AppRoutes.leave),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text.rich(
                    TextSpan(
                      style: AppTextStyles.bodySecondary,
                      children: [
                        const TextSpan(text: 'No requests yet. '),
                        TextSpan(
                          text: 'Apply leave',
                          style: AppTextStyles.body.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < response.requests.length; i++) ...[
                if (i > 0) Divider(height: 20, color: AppColors.border),
                _RecentRequestRow(request: response.requests[i]),
              ],
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.inbox_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(employeeRecentRequestsProvider),
        ),
      ),
    );
  }
}

String _fmtShortDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso.isEmpty ? '—' : iso;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]}';
}

class _RecentRequestRow extends StatelessWidget {
  final RecentRequest request;
  const _RecentRequestRow({required this.request});

  static IconData _iconFor(String type) => switch (type) {
        'leave' => Icons.beach_access_outlined,
        'expense' => Icons.receipt_long_outlined,
        'attendance_correction' => Icons.access_time_outlined,
        _ => Icons.description_outlined,
      };

  static Color _colorFor(String type) => switch (type) {
        'leave' => AppColors.success,
        'expense' => AppColors.warning,
        'attendance_correction' => AppColors.info,
        _ => AppColors.textSecondary,
      };

  String _detailLine() {
    final d = request.details;
    switch (request.requestType) {
      case 'leave':
        final start = d['start_date'];
        final end = d['end_date'];
        final days = d['days'];
        if (start != null && end != null) {
          return '${_fmtShortDate('$start')} – ${_fmtShortDate('$end')}'
              '${days != null ? ' · ${days}d' : ''}';
        }
        return '';
      case 'expense':
        final amount = d['amount'];
        final category = d['category'];
        return [
          if (category != null) '$category',
          if (amount != null) '₹$amount',
        ].join(' · ');
      case 'attendance_correction':
        final date = d['date'];
        final punchType = d['punch_type'];
        return [
          if (date != null) _fmtShortDate('$date'),
          if (punchType != null) '$punchType punch',
        ].join(' · ');
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(request.requestType);
    final detail = _detailLine();
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_iconFor(request.requestType), size: 15, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.title,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                detail.isNotEmpty
                    ? '$detail · ${_fmtShortDate(request.appliedDate)}'
                    : _fmtShortDate(request.appliedDate),
                style: AppTextStyles.caption,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusBadge(status: request.status, labelMap: _kRequestStatusLabel),
      ],
    );
  }
}

// ── Announcement (dismissible inline banner — nothing when empty) ──────────

class _EmpAnnouncementBanner extends ConsumerStatefulWidget {
  const _EmpAnnouncementBanner();

  @override
  ConsumerState<_EmpAnnouncementBanner> createState() => _EmpAnnouncementBannerState();
}

class _EmpAnnouncementBannerState extends ConsumerState<_EmpAnnouncementBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final announcementAsync = ref.watch(sharedAnnouncementProvider);

    return announcementAsync.maybeWhen(
      data: (ann) {
        if (ann == null || ann.title.isEmpty || _dismissed) return const SizedBox.shrink();

        final meta = [
          _fmtShortDate(ann.createdAt),
          if (ann.postedBy != null && ann.postedBy!.isNotEmpty) ann.postedBy!,
        ].join(' · ');

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SectionIconAsset('assets/images/Announcement.png', size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          ann.isPinned ? 'PINNED ANNOUNCEMENT' : 'LATEST ANNOUNCEMENT',
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.primary,
                          ),
                        ),
                        if (meta.isNotEmpty)
                          Text(meta, style: AppTextStyles.labelSmall.copyWith(fontSize: 10, color: AppColors.textHint)),
                        if (ann.category.isNotEmpty && ann.category != 'general')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              ann.category[0].toUpperCase() + ann.category.substring(1),
                              style: AppTextStyles.labelSmall
                                  .copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ann.title,
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ann.body,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  GestureDetector(
                    onTap: () => goToDashboardSection(context, AppRoutes.announcements),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_forward, size: 12, color: AppColors.primary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => setState(() => _dismissed = true),
                    child: Icon(Icons.close, size: 15, color: AppColors.textHint),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ── Birthdays (unchanged from the previous generic dashboard) ───────────────

class _TodaysBirthdaysCard extends ConsumerWidget {
  const _TodaysBirthdaysCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthdaysAsync = ref.watch(birthdaysProvider);

    return SectionCard(
      title: "Today's Birthdays",
      iconWidget: const SectionIconAsset('assets/images/Birthday.png'),
      accentColor: AppColors.primary,
      child: birthdaysAsync.when(
        data: (result) {
          if (result.today.isEmpty) {
            return const SectionMessage(
              iconWidget: SectionIconAsset('assets/images/Birthday.png', size: 28),
              label: 'No birthdays today',
            );
          }
          return Column(
            children: [
              for (var i = 0; i < result.today.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _BirthdayRow(entry: result.today[i], showAge: true),
              ],
            ],
          );
        },
        loading: () => const SectionMessage(
          iconWidget: SectionIconAsset('assets/images/Birthday.png', size: 28),
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyHrmsError(e),
          onRetry: () => ref.invalidate(birthdaysProvider),
        ),
      ),
    );
  }
}

class _UpcomingBirthdaysCard extends ConsumerWidget {
  const _UpcomingBirthdaysCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthdaysAsync = ref.watch(birthdaysProvider);

    return SectionCard(
      title: 'Upcoming Birthdays',
      iconWidget: const SectionIconAsset('assets/images/Birthday.png'),
      accentColor: AppColors.primary,
      child: birthdaysAsync.when(
        data: (result) {
          if (result.upcoming.isEmpty) {
            return const SectionMessage(
              iconWidget: SectionIconAsset('assets/images/Birthday.png', size: 28),
              label: 'No upcoming birthdays in the next 30 days',
            );
          }
          return Column(
            children: [
              for (var i = 0; i < result.upcoming.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _BirthdayRow(entry: result.upcoming[i], showAge: false),
              ],
            ],
          );
        },
        loading: () => const SectionMessage(
          iconWidget: SectionIconAsset('assets/images/Birthday.png', size: 28),
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyHrmsError(e),
          onRetry: () => ref.invalidate(birthdaysProvider),
        ),
      ),
    );
  }
}

class _BirthdayRow extends StatelessWidget {
  final BirthdayEntity entry;
  final bool showAge;

  const _BirthdayRow({required this.entry, required this.showAge});

  @override
  Widget build(BuildContext context) {
    final age = entry.age;
    final sub = [
      entry.designation,
      entry.department,
    ].where((s) => s.isNotEmpty).join(' · ');

    return Row(
      children: [
        const Text('🎂', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.name,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (sub.isNotEmpty)
                Text(
                  showAge && age != null ? '$sub · Turning $age' : sub,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
        ),
        if (!showAge)
          Text(
            'In ${entry.daysUntil} day${entry.daysUntil == 1 ? '' : 's'}',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

// ── Quick Links (unchanged from the previous generic dashboard) ────────────

class _QuickLinksCard extends StatelessWidget {
  const _QuickLinksCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Quick Links',
      icon: Icons.link_rounded,
      accentColor: AppColors.primary,
      child: GridView.builder(
        shrinkWrap: true,
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _kQuickLinksEmployee.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 46,
        ),
        itemBuilder: (context, index) {
          final link = _kQuickLinksEmployee[index];
          return GestureDetector(
            onTap: () => goToDashboardSection(context, link.path),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.backgroundLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(link.icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      link.label,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickLinkItem {
  final String label;
  final IconData icon;
  final String path;
  const _QuickLinkItem(
      {required this.label, required this.icon, required this.path});
}

const _kQuickLinksEmployee = <_QuickLinkItem>[
  _QuickLinkItem(
      label: 'Leave History',
      icon: Icons.beach_access_outlined,
      path: '/dashboard/leave'),
  _QuickLinkItem(
      label: 'My Attendance',
      icon: Icons.access_time_outlined,
      path: '/dashboard/my-attendance'),
  _QuickLinkItem(
      label: 'Claim Expense',
      icon: Icons.account_balance_wallet_outlined,
      path: '/dashboard/expenses'),
  _QuickLinkItem(
      label: 'My Documents',
      icon: Icons.description_outlined,
      path: '/dashboard/documents'),
];
