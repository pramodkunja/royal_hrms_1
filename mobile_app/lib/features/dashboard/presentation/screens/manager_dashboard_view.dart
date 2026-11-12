import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/dashboard/data/models/dashboard_common_models.dart';
import 'package:mobile_app/features/dashboard/data/models/manager_dashboard_models.dart';
import 'package:mobile_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/attendance_ring_card.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/dashboard_section.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/quick_access.dart';
import 'package:mobile_app/shared/widgets/app_error_state.dart';

/// Manager dashboard — ported from web's `ManagerDashboard.tsx`, backed by
/// GET /dashboard/manager/ (one response: team overview, quick actions,
/// pending approvals, birthdays, recent team activity, today's attendance,
/// upcoming leaves — all scoped server-side to the manager's direct
/// reports). Sections stack in web's reading order. Shown for users whose
/// role manages a team (resolveDashboardCategory → 'manager'), as on web.
class ManagerDashboardView extends ConsumerWidget {
  const ManagerDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refreshAll() async {
      ref.invalidate(managerDashboardProvider);
      ref.invalidate(sharedAnnouncementProvider);
      await ref.read(managerDashboardProvider.future).then((_) {}, onError: (_) {});
    }

    // Reached via context.go(); sections are pushed on top, so refresh when
    // the dashboard becomes visible again (same as the other dashboards).
    ref.listen<int>(dashboardRevisitProvider, (prev, next) {
      if (prev != null) refreshAll();
    });

    final dataAsync = ref.watch(managerDashboardProvider);

    return RefreshIndicator(
      onRefresh: refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ManagerConsoleHeader(overview: dataAsync.valueOrNull?.overview),
            const SizedBox(height: 20),
            // Latest announcement above Attendance (requested order).
            const _AnnouncementCard(),
            const SizedBox(height: 20),
            const AttendanceRingCard(),
            const SizedBox(height: 20),
            ...dataAsync.when(
              skipLoadingOnRefresh: true,
              loading: () => [
                SectionCard(
                  title: 'Team',
                  icon: Icons.groups_outlined,
                  accentColor: AppColors.primary,
                  child: const SectionMessage(icon: Icons.hourglass_empty, label: 'Loading…'),
                ),
              ],
              error: (e, _) => [
                SectionCard(
                  key: const Key('manager-dashboard-error'),
                  title: 'Team',
                  icon: Icons.groups_outlined,
                  accentColor: AppColors.primary,
                  child: AppErrorState.forError(
                    e,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onRetry: () => ref.invalidate(managerDashboardProvider),
                  ),
                ),
              ],
              data: (d) => [
                if (d.quickActions.isNotEmpty) ...[
                  QuickAccessCard(items: managerQuickItems(d.quickActions)),
                  const SizedBox(height: 20),
                ],
                _PendingApprovalsCard(items: d.pendingApprovals),
                const SizedBox(height: 20),
                _RecentActivityCard(items: d.recentActivity),
                if (d.todaysBirthdays.isNotEmpty || d.upcomingBirthdays.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _BirthdaysCard(today: d.todaysBirthdays, upcoming: d.upcomingBirthdays),
                ],
                const SizedBox(height: 20),
                _TeamAttendanceCard(items: d.teamAttendance),
                const SizedBox(height: 20),
                _UpcomingLeavesCard(items: d.upcomingLeaves),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The server's quick actions mapped to this app's screens (web overrides
/// the backend URLs the same way, QA_URL_OVERRIDE). Each tile carries the
/// router's own permission for its path, so QuickAccessCard hides any the
/// user could not open; an action this app has no screen for is left out.
List<QuickItem> managerQuickItems(List<ManagerQuickAction> actions) {
  const paths = {
    'apply_leave': AppRoutes.leave,
    'my_requests': AppRoutes.myRequests,
    'team_members': AppRoutes.employees,
    'review_approvals': AppRoutes.approvals,
    'my_payslip': AppRoutes.myPayslips,
    'interviews': AppRoutes.interviewList,
  };
  final templates = {for (final q in kQuickItemsManager) q.path: q};
  return [
    for (final a in actions)
      if (paths[a.id] case final path?)
        QuickItem(
          label: a.count != null && a.count! > 0 ? '${a.label} (${a.count})' : a.label,
          icon: templates[path]?.icon ?? Icons.link,
          color: templates[path]?.color ?? AppColors.primary,
          path: path,
          anyOfPermissions: requiredPermissionsFor(path),
        ),
  ];
}

String _date(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]}';
}

String _ago(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final diff = DateTime.now().difference(d.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String _label(String raw) =>
    raw.isEmpty ? raw : raw.replaceAll('_', ' ').replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase());

class _ManagerConsoleHeader extends ConsumerWidget {
  const _ManagerConsoleHeader({required this.overview});
  final ManagerTeamOverview? overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final clockedIn = ref.watch(todayAttendanceProvider).valueOrNull?.isClockedIn ?? false;
    final ov = overview;
    final name = (ov?.managerName.isNotEmpty ?? false) ? ov!.managerName : (user?.fullName ?? '');
    final first = name.trim().isEmpty ? 'there' : name.trim().split(' ').first;
    // Unknown stays "—" (never shown as 0) until the server has answered.
    String v(String Function(ManagerTeamOverview o) f) => ov == null ? '—' : f(ov);

    return ConsoleHeaderShell(
      heroContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatusRingAvatar(name: name, active: clockedIn),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const RoleBadgePill(label: 'TEAM CONSOLE', icon: Icons.groups_outlined),
                const SizedBox(height: 7),
                Text('${ov?.greeting.isNotEmpty == true ? ov!.greeting : 'Hello'},',
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                Text(first,
                    style: AppTextStyles.h3.copyWith(color: Colors.white, height: 1.15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          ConsoleInfoBar(clockedIn: clockedIn),
        ],
      ),
      statsContent: ConsoleStatsRow(key: const Key('manager-stats'), stats: [
        (icon: Icons.groups_outlined, value: v((o) => '${o.teamSize}'), label: 'Team Size', color: AppColors.primary),
        (
          icon: Icons.checklist_outlined,
          value: v((o) => '${o.pendingApprovals}'),
          label: 'Pending',
          color: AppColors.warning,
        ),
        (
          icon: Icons.beach_access_outlined,
          value: v((o) => '${o.employeesOnLeaveToday}'),
          label: 'On Leave',
          color: AppColors.info,
        ),
        (
          icon: Icons.insights_outlined,
          value: v((o) => '${_trimPct(o.teamAttendancePercentage)}%'),
          label: 'Attendance',
          color: AppColors.success,
        ),
      ]),
    );
  }

  static String _trimPct(double p) => p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(1);
}

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sharedAnnouncementProvider);
    return SectionCard(
      title: 'Latest Announcement',
      iconWidget: const SectionIconAsset('assets/images/Announcement.png'),
      accentColor: AppColors.primary,
      child: async.when(
        loading: () => const SectionMessage(icon: Icons.campaign_outlined, label: 'Loading…'),
        // Its own request: a failure here leaves the rest of the dashboard.
        error: (e, _) =>
            SectionError(message: friendlyDashboardError(e), onRetry: () => ref.invalidate(sharedAnnouncementProvider)),
        data: (DashboardAnnouncement? a) => a == null || a.title.isEmpty
            ? const SectionMessage(icon: Icons.campaign_outlined, label: 'No announcements yet')
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text(a.body, style: AppTextStyles.bodySecondary, maxLines: 4, overflow: TextOverflow.ellipsis),
              ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.name, required this.title, this.subtitle, this.trailing});
  final String name;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          InitialsAvatar(name: name, radius: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(subtitle!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      );
}

Widget _pill(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
    );

Color _statusColor(String s) => switch (s) {
      'present' || 'approved' => AppColors.success,
      'late' || 'pending' || 'l2_pending' => AppColors.warning,
      'on_leave' || 'half_day' => AppColors.info,
      'absent' || 'rejected' => AppColors.error,
      _ => AppColors.textSecondary,
    };

class _PendingApprovalsCard extends ConsumerWidget {
  const _PendingApprovalsCard({required this.items});
  final List<ManagerPendingApproval> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final canReview = canAccessPath(user, AppRoutes.approvals);
    return SectionCard(
      key: const Key('manager-pending'),
      title: 'Pending Approvals',
      icon: Icons.checklist_outlined,
      accentColor: AppColors.warning,
      trailing: items.isEmpty ? null : _pill('${items.length} item${items.length == 1 ? '' : 's'}', AppColors.warning),
      child: items.isEmpty
          ? const SectionMessage(icon: Icons.task_alt, label: 'No pending approvals.')
          : Column(children: [
              for (final p in items)
                _Row(
                  name: p.employeeName,
                  title: p.employeeName,
                  subtitle: [
                    p.summary,
                    p.dateFrom == p.dateTo ? _date(p.dateFrom) : '${_date(p.dateFrom)} – ${_date(p.dateTo)}',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  trailing: canReview
                      ? TextButton(
                          onPressed: () => goToDashboardSection(context, AppRoutes.approvals),
                          child: const Text('Review'),
                        )
                      : null,
                ),
            ]),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.items});
  final List<ManagerTeamActivity> items;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Recent Team Activity',
        icon: Icons.timeline_outlined,
        accentColor: AppColors.primary,
        child: items.isEmpty
            ? const SectionMessage(icon: Icons.timeline_outlined, label: 'No recent activity.')
            : Column(children: [
                for (final a in items)
                  _Row(
                    name: a.employeeName,
                    title: '${a.employeeName} · ${a.description}',
                    subtitle: _ago(a.createdAt),
                  ),
              ]),
      );
}

class _BirthdaysCard extends StatelessWidget {
  const _BirthdaysCard({required this.today, required this.upcoming});
  final List<DashboardBirthdayEmployee> today;
  final List<DashboardBirthdayEmployee> upcoming;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Birthdays',
        icon: Icons.cake_outlined,
        accentColor: AppColors.primary,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final b in today)
            _Row(
                name: b.fullName, title: b.fullName, subtitle: 'Today 🎉', trailing: _pill('Today', AppColors.success)),
          for (final b in upcoming.take(5))
            _Row(
              name: b.fullName,
              title: b.fullName,
              subtitle: _date(b.dateOfBirth), // day and month only
              trailing: _pill('in ${b.daysUntil}d', AppColors.info),
            ),
        ]),
      );
}

class _TeamAttendanceCard extends StatelessWidget {
  const _TeamAttendanceCard({required this.items});
  final List<ManagerTeamAttendance> items;

  @override
  Widget build(BuildContext context) => SectionCard(
        key: const Key('manager-team-attendance'),
        title: 'Team Attendance Today',
        icon: Icons.how_to_reg_outlined,
        accentColor: AppColors.success,
        child: items.isEmpty
            ? const SectionMessage(icon: Icons.how_to_reg_outlined, label: 'No attendance data.')
            : Column(children: [
                for (final e in items)
                  _Row(
                    name: e.employeeName,
                    title: e.employeeName,
                    subtitle: [
                      e.designation,
                      if (e.clockIn != null) 'In ${e.clockIn}${e.clockOut != null ? ' · Out ${e.clockOut}' : ''}',
                    ].where((s) => s.isNotEmpty).join(' · '),
                    trailing: _pill(_label(e.status), _statusColor(e.status)),
                  ),
              ]),
      );
}

class _UpcomingLeavesCard extends StatelessWidget {
  const _UpcomingLeavesCard({required this.items});
  final List<ManagerUpcomingLeave> items;

  @override
  Widget build(BuildContext context) => SectionCard(
        key: const Key('manager-upcoming-leaves'),
        title: 'Upcoming Leaves',
        icon: Icons.event_outlined,
        accentColor: AppColors.info,
        child: items.isEmpty
            ? const SectionMessage(icon: Icons.event_outlined, label: 'No upcoming leaves.')
            : Column(children: [
                for (final l in items)
                  _Row(
                    name: l.employeeName,
                    title: l.employeeName,
                    subtitle: '${l.leaveType} · ${_date(l.dateFrom)}'
                        '${l.dateTo != l.dateFrom ? ' – ${_date(l.dateTo)}' : ''} · '
                        '${l.totalDays == l.totalDays.roundToDouble() ? l.totalDays.toStringAsFixed(0) : l.totalDays} day(s)',
                    trailing: _pill(_label(l.status), _statusColor(l.status)),
                  ),
              ]),
      );
}
