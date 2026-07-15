import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/location/location_service.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/hrms/domain/entities/birthday_entity.dart';
import 'package:mobile_app/features/hrms/presentation/providers/hrms_providers.dart';
import 'package:mobile_app/features/leave/domain/entities/leave_entity.dart';
import 'package:mobile_app/features/leave/presentation/providers/leave_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final permissions = user?.permissions ?? const [];
    final quickAccess = _quickAccess(user?.role ?? '');
    final canViewBirthdays = permissions.contains('employees.view');
    final canClockIn = _canClockIn(user?.role ?? '');
    // Quick Links is only on web's EmployeeDashboard.tsx — Manager/HR/Admin
    // dashboards don't render one.
    final showQuickLinks =
        _resolveRoleCategory(user?.role ?? '') == 'employee';

    return RefreshIndicator(
      onRefresh: () async {
        if (canClockIn) ref.invalidate(todayAttendanceProvider);
        ref.invalidate(leaveStatsProvider);
        ref.invalidate(leaveRequestsProvider);
        if (canViewBirthdays) ref.invalidate(birthdaysProvider);
      },
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
            if (quickAccess.isNotEmpty) ...[
              _QuickAccessCard(items: quickAccess),
              const SizedBox(height: 20),
            ],
            if (canClockIn) ...[
              const _ClockInCard(),
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
            // Quick Links is the last card on web too — it sits at the
            // bottom of EmployeeDashboard.tsx's right column, below "My
            // Recent Requests", and that column is the last section on the
            // page.
            if (showQuickLinks) ...[
              const SizedBox(height: 20),
              const _QuickLinksCard(),
            ],
          ],
        ),
      ),
    );
  }

  /// Returns this role's full, fixed Quick Actions set — matching web
  /// exactly (each dashboard component renders its own hardcoded array with
  /// no per-tile permission check at all). A prior version filtered by
  /// permission as a "safety net", but that could silently drop a card
  /// whenever the account's real permission list didn't happen to match the
  /// exact string assumed for that tile — always show the full set instead.
  List<_QuickItem> _quickAccess(String rawRole) {
    return _kQuickItemsByRole[_resolveRoleCategory(rawRole)]!;
  }

  /// Mirrors web's `resolveRole()` in app/dashboard/page.tsx exactly — each
  /// of the 4 role categories gets its own distinct Quick Actions set
  /// (see EmployeeDashboard.tsx/ManagerDashboard.tsx/HRDashboard.tsx/
  /// AdminDashboard.tsx's "Quick actions" arrays).
  String _resolveRoleCategory(String rawRole) {
    final r = rawRole.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (r.contains('hradmin') || r == 'hr') return 'hr';
    if (r.contains('admin')) return 'admin'; // system_admin
    if (r.contains('manager')) return 'manager';
    return 'employee'; // default, matches web's fallback
  }

  /// Self-service clock-in is only shown to the same roles the web app shows
  /// it to: Employee and HR dashboards embed `<ClockInButton />`; Admin and
  /// Manager dashboards do not (see frontend/app/dashboard/_components/ —
  /// only EmployeeDashboard.tsx and HRDashboard.tsx import it). This mirrors
  /// web's `resolveRole()` in app/dashboard/page.tsx exactly, since the
  /// backend does not gate self-service attendance by permission — it's a
  /// role-only UI decision on both platforms.
  bool _canClockIn(String rawRole) {
    final category = _resolveRoleCategory(rawRole);
    return category == 'hr' || category == 'employee';
  }
}

// ── Welcome card ─────────────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  final String name;
  final String roleDisplay;
  final List<String> permissions;

  const _WelcomeCard({
    required this.name,
    required this.roleDisplay,
    required this.permissions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, const Color(0xFF2A6ACC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.elevatedShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good day,',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isEmpty ? 'Welcome' : name,
                  style: AppTextStyles.h3.copyWith(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleDisplay.isEmpty ? 'Employee' : roleDisplay,
                    style:
                        AppTextStyles.labelSmall.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${permissions.length} permission${permissions.length == 1 ? '' : 's'} granted',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _LargeInitialsAvatar(name: name),
        ],
      ),
    );
  }
}

// ── Quick access grid ────────────────────────────────────────────────────────

class _QuickItem {
  final String label;
  final IconData icon;
  final Color color;
  final String path;
  final String? permission;

  const _QuickItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.path,
    this.permission,
  });
}

// Mirrors each web dashboard's own "Quick actions" array exactly (icons
// translated to their nearest Material equivalent, colors mapped to this
// app's matching semantic AppColors token) — see
// frontend/app/dashboard/_components/{Employee,Manager,HR,Admin}Dashboard.tsx.
// Web hardcodes a different 6-tile set per role rather than one shared,
// permission-filtered list, so this app does the same.

final _kQuickItemsEmployee = <_QuickItem>[
  _QuickItem(
      label: 'Apply Leave',
      icon: Icons.beach_access_outlined,
      color: AppColors.success,
      path: '/dashboard/leave',
      permission: 'leave.view'),
  _QuickItem(
      label: 'My Payslips',
      icon: Icons.receipt_long_outlined,
      color: AppColors.primary,
      path: '/dashboard/my-payslip',
      permission: 'payroll.view'),
  _QuickItem(
      label: 'Attendance',
      icon: Icons.access_time_outlined,
      color: AppColors.info,
      path: '/dashboard/my-attendance',
      permission: null),
  _QuickItem(
      label: 'My Expenses',
      icon: Icons.account_balance_wallet_outlined,
      color: AppColors.warning,
      path: '/dashboard/expenses',
      permission: 'expenses.view'),
  _QuickItem(
      label: 'Documents',
      icon: Icons.folder_outlined,
      color: AppColors.primary,
      path: '/dashboard/documents',
      permission: 'documents.view'),
  _QuickItem(
      label: 'My Profile',
      icon: Icons.account_circle_outlined,
      color: AppColors.info,
      path: '/dashboard/profile',
      permission: null),
];

final _kQuickItemsManager = <_QuickItem>[
  _QuickItem(
      label: 'Review Approvals',
      icon: Icons.checklist_outlined,
      color: AppColors.warning,
      path: '/dashboard/approvals',
      permission: 'leave.view'),
  _QuickItem(
      label: 'Apply Leave',
      icon: Icons.beach_access_outlined,
      color: AppColors.success,
      path: '/dashboard/leave',
      permission: 'leave.view'),
  _QuickItem(
      label: 'My Payslip',
      icon: Icons.receipt_long_outlined,
      color: AppColors.primary,
      path: '/dashboard/my-payslip',
      permission: 'payroll.view'),
  _QuickItem(
      label: 'Team Members',
      icon: Icons.groups_outlined,
      color: AppColors.info,
      path: '/dashboard/employees',
      permission: 'employees.view'),
  _QuickItem(
      label: 'Interviews',
      icon: Icons.person_search_outlined,
      color: AppColors.primary,
      path: '/dashboard/interview-list',
      permission: 'recruitment.view'),
  _QuickItem(
      label: 'My Requests',
      icon: Icons.inbox_outlined,
      color: AppColors.warning,
      path: '/dashboard/my-requests',
      permission: null),
];

final _kQuickItemsHr = <_QuickItem>[
  _QuickItem(
      label: 'Interview List',
      icon: Icons.people_outline,
      color: AppColors.primary,
      path: '/dashboard/interview-list',
      permission: 'recruitment.view'),
  _QuickItem(
      label: 'Leave Approvals',
      icon: Icons.beach_access_outlined,
      color: AppColors.success,
      path: '/dashboard/leave',
      permission: 'leave.view'),
  _QuickItem(
      label: 'Run Payroll',
      icon: Icons.payments_outlined,
      color: AppColors.warning,
      path: '/dashboard/payroll',
      permission: 'payroll.view'),
  _QuickItem(
      label: 'Employees',
      icon: Icons.badge_outlined,
      color: AppColors.info,
      path: '/dashboard/employees',
      permission: 'employees.view'),
  _QuickItem(
      label: 'Review Candidates',
      icon: Icons.how_to_reg_outlined,
      color: AppColors.warning,
      path: '/dashboard/candidate-review',
      permission: 'recruitment.view'),
  _QuickItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      color: AppColors.primary,
      path: '/dashboard/settings',
      permission: 'settings.view'),
];

final _kQuickItemsAdmin = <_QuickItem>[
  _QuickItem(
      label: 'Employees',
      icon: Icons.badge_outlined,
      color: AppColors.primary,
      path: '/dashboard/employees',
      permission: 'employees.view'),
  _QuickItem(
      label: 'Roles & Perms',
      icon: Icons.verified_user_outlined,
      color: AppColors.success,
      // Web links straight to /dashboard/settings/permissions; this app has
      // no distinct route for that sub-page, so this opens the Settings hub
      // it lives inside instead.
      path: '/dashboard/settings',
      permission: 'settings.view'),
  _QuickItem(
      label: 'Attendance',
      icon: Icons.access_time_outlined,
      color: AppColors.info,
      path: '/dashboard/attendance',
      permission: 'attendance.view'),
  _QuickItem(
      label: 'Payroll',
      icon: Icons.payments_outlined,
      color: AppColors.warning,
      path: '/dashboard/payroll',
      permission: 'payroll.view'),
  _QuickItem(
      label: 'Branches',
      icon: Icons.business_outlined,
      color: AppColors.primary,
      path: '/dashboard/branches',
      permission: 'branches.view'),
  _QuickItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      color: AppColors.warning,
      path: '/dashboard/settings',
      permission: 'settings.view'),
];

final _kQuickItemsByRole = <String, List<_QuickItem>>{
  'employee': _kQuickItemsEmployee,
  'manager': _kQuickItemsManager,
  'hr': _kQuickItemsHr,
  'admin': _kQuickItemsAdmin,
};

// ── Quick Links (secondary, compact list) ────────────────────────────────────
// Employee dashboard only, matching web's EmployeeDashboard.tsx right-column
// "Quick Links" card — Manager/HR/Admin dashboards on web don't have one.

class _QuickLinksCard extends StatelessWidget {
  const _QuickLinksCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
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
            onTap: () => context.go(link.path),
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

// Wraps the grid in the same highlighted-header card chrome as the other
// dashboard sections below it, instead of a plain heading floating above it.
class _QuickAccessCard extends StatelessWidget {
  final List<_QuickItem> items;

  const _QuickAccessCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Quick Access',
      icon: Icons.apps_rounded,
      accentColor: AppColors.primary,
      child: _QuickAccessGrid(items: items),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  final List<_QuickItem> items;

  const _QuickAccessGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      // A fixed mainAxisExtent (rather than childAspectRatio) keeps tile
      // height constant regardless of available width — childAspectRatio
      // made height shrink along with width once this grid got nested one
      // level deeper inside _SectionCard's own padding, which left too
      // little room for the icon + two-line label and overflowed.
      // 3 columns (not 4) — every role's array is exactly 6 items, so this
      // lays out as a clean 3×2 grid matching the reference design.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 92,
      ),
      itemBuilder: (context, index) => _QuickTile(item: items[index]),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final _QuickItem item;

  const _QuickTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(item.path),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          // A proper bordered white card (not a flat tinted chip) — matches
          // the reference design's nested-card look for each tile.
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: item.color, size: 17),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared section card chrome ───────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
          // Heading is separated from the card body by a full-width divider
          // (not just spacing) and highlighted with the section's accent
          // icon color — reusing colors already established elsewhere in
          // the app (e.g. the Quick Access tile colors) rather than new ones.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 19, color: accentColor),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: AppTextStyles.h4)),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SectionMessage extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionMessage({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textHint, size: 28),
          const SizedBox(height: 8),
          Text(label,
              style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SectionError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 26),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodySecondary.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ── Today's Attendance / Clock In-Out card ───────────────────────────────────

class _ClockInCard extends ConsumerStatefulWidget {
  const _ClockInCard();

  @override
  ConsumerState<_ClockInCard> createState() => _ClockInCardState();
}

class _ClockInCardState extends ConsumerState<_ClockInCard> {
  bool _punching = false;

  Future<void> _toggleClock(TodayAttendanceEntity today) async {
    if (_punching) return;
    setState(() => _punching = true);

    final position =
        await ref.read(locationServiceProvider).getCurrentPosition();
    if (!mounted) return;

    final error = await ref.read(todayAttendanceProvider.notifier).punch(
          isCurrentlyClockedIn: today.isClockedIn,
          attendanceMode: 'office',
          latitude: position?.latitude,
          longitude: position?.longitude,
          accuracy: position?.accuracy,
          deviceName: kIsWeb
              ? 'Web'
              : Platform.isAndroid
                  ? 'Android'
                  : Platform.isIOS
                      ? 'iOS'
                      : null,
          operatingSystem: kIsWeb ? 'web' : Platform.operatingSystem,
        );

    if (!mounted) return;
    setState(() => _punching = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayAttendanceProvider);

    return _SectionCard(
      title: "Today's Attendance",
      icon: Icons.access_time_outlined,
      accentColor: const Color(0xFF1B8A6B),
      child: todayAsync.when(
        data: (today) {
          final lastPunch = today.punches.isEmpty ? null : today.punches.last;
          return Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (today.isClockedIn
                          ? AppColors.success
                          : AppColors.textHint)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  today.isClockedIn
                      ? Icons.timer_outlined
                      : Icons.timer_off_outlined,
                  color: today.isClockedIn
                      ? AppColors.success
                      : AppColors.textHint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      today.isClockedIn ? 'Clocked In' : 'Clocked Out',
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastPunch == null
                          ? today.dateDisplay
                          : 'Last punch: ${lastPunch.type} at ${lastPunch.time}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: ElevatedButton(
                  onPressed: _punching ? null : () => _toggleClock(today),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        today.isClockedIn ? AppColors.error : AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _punching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          today.isClockedIn ? 'Clock Out' : 'Clock In',
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ],
          );
        },
        loading: () => const _SectionMessage(
          icon: Icons.timer_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => _SectionError(
          message: friendlyAttendanceError(e),
          onRetry: () => ref.invalidate(todayAttendanceProvider),
        ),
      ),
    );
  }
}

// ── Leave Balance card ────────────────────────────────────────────────────────

class _LeaveBalanceCard extends ConsumerWidget {
  const _LeaveBalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(leaveStatsProvider);

    return _SectionCard(
      title: 'Leave Balance',
      icon: Icons.beach_access_outlined,
      accentColor: const Color(0xFFB5651D),
      child: statsAsync.when(
        data: (stats) {
          if (stats.balances.isEmpty) {
            final year = stats.year > 0 ? stats.year : DateTime.now().year;
            return _SectionMessage(
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
        loading: () => const _SectionMessage(
          icon: Icons.beach_access_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => _SectionError(
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

// ── Recent Leave Requests card ────────────────────────────────────────────────

class _RecentLeaveRequestsCard extends ConsumerWidget {
  const _RecentLeaveRequestsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(leaveRequestsProvider);

    return _SectionCard(
      title: 'Recent Leave Requests',
      icon: Icons.list_alt_outlined,
      accentColor: const Color(0xFFB5651D),
      child: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const _SectionMessage(
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
        loading: () => const _SectionMessage(
          icon: Icons.inbox_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => _SectionError(
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

  static Color _statusColor(String s) => switch (s) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        'cancelled' => AppColors.textSecondary,
        _ => AppColors.warning, // covers 'pending' and 'l2_pending'
      };

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(request.status);
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
            color: sc.withValues(alpha: 0.1),
            border: Border.all(color: sc.withValues(alpha: 0.3)),
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

// ── Birthdays cards (two separate cards — Today / Upcoming) ──────────────────

class _TodaysBirthdaysCard extends ConsumerWidget {
  const _TodaysBirthdaysCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthdaysAsync = ref.watch(birthdaysProvider);

    return _SectionCard(
      title: "Today's Birthdays",
      icon: Icons.cake_outlined,
      accentColor: AppColors.primary,
      child: birthdaysAsync.when(
        data: (result) {
          if (result.today.isEmpty) {
            return const _SectionMessage(
              icon: Icons.cake_outlined,
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
        loading: () => const _SectionMessage(
          icon: Icons.cake_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => _SectionError(
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

    return _SectionCard(
      title: 'Upcoming Birthdays',
      icon: Icons.celebration_outlined,
      accentColor: AppColors.primary,
      child: birthdaysAsync.when(
        data: (result) {
          if (result.upcoming.isEmpty) {
            return const _SectionMessage(
              icon: Icons.calendar_month_outlined,
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
        loading: () => const _SectionMessage(
          icon: Icons.celebration_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => _SectionError(
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

// ── Large initials avatar ─────────────────────────────────────────────────────

class _LargeInitialsAvatar extends StatelessWidget {
  final String name;

  const _LargeInitialsAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = name.isEmpty
        ? '?'
        : parts.length == 1
            ? parts[0][0].toUpperCase()
            : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.h3.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
