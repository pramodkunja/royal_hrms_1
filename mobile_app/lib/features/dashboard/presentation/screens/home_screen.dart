import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/hrms/domain/entities/birthday_entity.dart';
import 'package:mobile_app/features/hrms/presentation/providers/hrms_providers.dart';
import 'package:mobile_app/features/leave/domain/entities/leave_entity.dart';
import 'package:mobile_app/features/leave/presentation/providers/leave_providers.dart';
import '../widgets/attendance_ring_card.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/quick_access.dart';
import 'admin_dashboard_view.dart';
import 'employee_dashboard_view.dart';
import 'hr_dashboard_view.dart';

/// Role router — resolves the signed-in user's role category and renders
/// the matching dashboard. Mirrors web's `resolveRole()` branch in
/// `app/dashboard/page.tsx`, which renders one of `EmployeeDashboard`,
/// `HRDashboard`, `AdminDashboard`, or `ManagerDashboard`.
///
/// Manager falls back to [_GenericDashboardView] (the dashboard this screen
/// used for every role before the per-role port) rather than a dedicated
/// view — web's `ManagerDashboard.tsx` has no real backend behind it (every
/// stat/list is hardcoded mock data except its birthday widget), so there's
/// nothing genuine to port for that role yet.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final category = resolveRoleCategory(user?.role ?? '');

    return switch (category) {
      'employee' => const EmployeeDashboardView(),
      'admin' => const AdminDashboardView(),
      'hr' => const HrDashboardView(),
      _ => const _GenericDashboardView(),
    };
  }
}

/// The dashboard's previous single-layout implementation — kept only for
/// Manager, which has no real per-role backend on web to port yet.
class _GenericDashboardView extends ConsumerWidget {
  const _GenericDashboardView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final permissions = user?.permissions ?? const [];
    final category = resolveRoleCategory(user?.role ?? '');
    final quickAccess = kQuickItemsByRole[category]!;
    final canViewBirthdays = permissions.contains('employees.view');

    Future<void> refreshAll() async {
      ref.invalidate(leaveStatsProvider);
      ref.invalidate(leaveRequestsProvider);
      ref.invalidate(todayAttendanceProvider);
      if (canViewBirthdays) ref.invalidate(birthdaysProvider);
    }

    // HomeScreen is reached via context.go() but every sub-section under it
    // (Attendance, Leave, etc.) is pushed on top via goToDashboardSection —
    // so popping back here never re-triggers autoDispose providers on its
    // own. Re-run the same refresh pull-to-refresh does whenever the
    // dashboard becomes visible again. `prev != null` skips the initial
    // subscription — only actual increments matter.
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
            _WelcomeCard(
              name: user?.fullName ?? '',
              roleDisplay: user?.roleDisplay ?? '',
              permissions: permissions,
            ),
            const SizedBox(height: 20),
            const AttendanceRingCard(),
            const SizedBox(height: 20),
            if (quickAccess.isNotEmpty) ...[
              QuickAccessCard(items: quickAccess),
              const SizedBox(height: 20),
            ],
            const _LeaveBalanceCard(),
            const SizedBox(height: 20),
            const _RecentLeaveRequestsCard(),
            if (canViewBirthdays) ...[
              const SizedBox(height: 20),
              const _TodaysBirthdaysCard(),
              const SizedBox(height: 20),
              const _UpcomingBirthdaysCard(),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Welcome card (gradient hero + white stat strip; shared shell — see
// dashboard_section.dart's ConsoleHeaderShell/StatusRingAvatar/etc, also
// used by the Employee, HR, and Admin dashboards) ───────────────────────────
// No numeric KPIs exist for this role (web's own ManagerDashboard.tsx has no
// real backend behind it either), so the stat strip surfaces the two real
// fields this view already had — role and permission count — instead of
// inventing fake numbers just to fill four cells.

class _WelcomeCard extends ConsumerWidget {
  final String name;
  final String roleDisplay;
  final List<String> permissions;

  const _WelcomeCard({
    required this.name,
    required this.roleDisplay,
    required this.permissions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clockedIn = ref.watch(todayAttendanceProvider).valueOrNull?.isClockedIn ?? false;
    final badge = roleDisplay.isEmpty ? 'WORKSPACE' : roleDisplay.toUpperCase();

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
                    RoleBadgePill(label: badge),
                    const SizedBox(height: 7),
                    Text(
                      'Welcome back,',
                      style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                    Text(
                      name.isEmpty ? 'there' : name,
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
      statsContent: ConsoleStatsRow(stats: [
        (icon: Icons.badge_outlined, value: roleDisplay.isEmpty ? 'Employee' : roleDisplay, label: 'Role', color: AppColors.primary),
        (
          icon: Icons.verified_user_outlined,
          value: '${permissions.length}',
          label: permissions.length == 1 ? 'Permission' : 'Permissions',
          color: AppColors.success,
        ),
      ]),
    );
  }
}

// ── Leave Balance card (generic/Manager fallback only — Employee has its
// own richer version wired to the dashboard-app endpoint) ──────────────────

class _LeaveBalanceCard extends ConsumerWidget {
  const _LeaveBalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(leaveStatsProvider);

    return SectionCard(
      title: 'Leave Balance',
      icon: Icons.beach_access_outlined,
      accentColor: AppColors.warning,
      child: statsAsync.when(
        data: (stats) {
          if (stats.balances.isEmpty) {
            final year = stats.year > 0 ? stats.year : DateTime.now().year;
            return SectionMessage(
              icon: Icons.beach_access_outlined,
              label:
                  'No leave balance found for $year. Contact HR to credit your leave.',
            );
          }
          return Column(
            children: [
              for (var i = 0; i < stats.balances.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _BalanceRow(balance: stats.balances[i]),
              ],
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.beach_access_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyLeaveError(e),
          onRetry: () => ref.invalidate(leaveStatsProvider),
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final BalanceSummaryEntity balance;

  const _BalanceRow({required this.balance});

  @override
  Widget build(BuildContext context) {
    final color =
        Color(LeaveTypeColors.colorValueForCode(balance.leaveTypeCode));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                balance.leaveTypeDisplay,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${balance.available.toStringAsFixed(1)} / ${balance.totalDays.toStringAsFixed(1)} days',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: balance.pct,
            minHeight: 6,
            backgroundColor: AppColors.backgroundMid,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ── Recent Leave Requests card (generic/Manager fallback only) ─────────────

class _RecentLeaveRequestsCard extends ConsumerWidget {
  const _RecentLeaveRequestsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(leaveRequestsProvider);

    return SectionCard(
      title: 'Recent Leave Requests',
      icon: Icons.list_alt_outlined,
      accentColor: AppColors.warning,
      child: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const SectionMessage(
              icon: Icons.inbox_outlined,
              label: 'No leave requests yet. Apply your first leave.',
            );
          }
          final sorted = [...requests]..sort((a, b) {
              final da = DateTime.tryParse(a.appliedOn);
              final db = DateTime.tryParse(b.appliedOn);
              if (da == null || db == null) return 0;
              return db.compareTo(da);
            });
          final recent = sorted.take(5).toList();
          return Column(
            children: [
              for (var i = 0; i < recent.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _RequestRow(request: recent[i]),
              ],
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.inbox_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyLeaveError(e),
          onRetry: () => ref.invalidate(leaveRequestsProvider),
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final LeaveRequestEntity request;

  const _RequestRow({required this.request});

  // (background, foreground) — mirrors EmployeeCard._StatusBadge's pattern
  // of a solid *Container fill behind the semantic accent color, rather
  // than a runtime alpha blend of the accent itself. The blend approach
  // produces a barely-visible tint in dark mode since AppColors' dark
  // palette accents are themselves already light/pastel; the *Container
  // fields are hand-tuned solid fills that don't have that problem.
  static (Color, Color) _statusColors(String s) => switch (s) {
        'approved' => (AppColors.successContainer, AppColors.success),
        'rejected' => (AppColors.errorContainer, AppColors.error),
        'cancelled' => (AppColors.backgroundMid, AppColors.textSecondary),
        _ => (AppColors.warningContainer, AppColors.warning), // 'pending', 'l2_pending'
      };

  @override
  Widget build(BuildContext context) {
    final (bg, sc) = _statusColors(request.status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.leaveType,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                '${request.from} – ${request.to} · ${request.days} day${request.days == 1 ? '' : 's'}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            request.status,
            style: AppTextStyles.caption
                .copyWith(color: sc, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Birthdays cards (generic/Manager fallback only) ─────────────────────────

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
