import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/approvals_providers.dart' show approvalsSummaryCountsProvider;
import '../widgets/approvals_kit.dart';
import '../widgets/approvals_ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../leave/presentation/widgets/leave_cancellation_panel.dart'
    show LeaveCancellationsTab, canReviewLeaveCancellations;
import '../widgets/attendance_approval_tab.dart';
import '../widgets/face_registration_approvals_tab.dart';
import '../widgets/team_approvals_tab.dart';
import '../../../../core/router/access_control.dart';
import '../widgets/delegations_tab.dart' show DelegationsTab;

// Ports web's app/dashboard/approvals/page.tsx (2026-07-21 change) — the
// "My Requests" tab was removed there since a standalone /dashboard/my-requests
// page already covers self-service leave/expense creation; the remaining tabs
// ("Team Approvals", "Attendance Approval") are derived from permission,
// switching to the first still-valid tab if the active one becomes invalid.
// Mobile's own self-service equivalent lives in the Leave and Expenses
// modules (Apply Leave / Add Expense), so this mirrors web exactly rather
// than removing functionality with no replacement.
class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen> with SingleTickerProviderStateMixin {
  TabController? _tabCtrl;
  List<String> _tabKeys = const [];

  void _syncTabs(List<String> keys) {
    if (_listEquals(_tabKeys, keys)) return;
    final oldIndex = _tabCtrl?.index ?? 0;
    _tabCtrl?.dispose();
    _tabKeys = keys;
    _tabCtrl = TabController(length: keys.length, vsync: this, initialIndex: oldIndex < keys.length ? oldIndex : 0);
  }

  String _tabLabel(String key) => switch (key) {
        'team' => 'Team Approvals',
        'face_id' => 'Face Registration', // web page.tsx section label
        'leave_cancellations' => 'Leave Cancellations',
        'delegation' => 'Delegation',
        _ => 'Attendance Approval',
      };

  IconData _tabIcon(String key) => switch (key) {
        'team' => Icons.checklist_rtl,
        'face_id' => Icons.face_outlined,
        'leave_cancellations' => Icons.event_busy_outlined,
        'delegation' => Icons.supervisor_account_outlined,
        _ => Icons.fact_check_outlined,
      };

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    // Web usePermission / useAnyPermission: the superuser flag (which the
    // login also sets for settings.edit roles) or the permission — the same
    // rule as the backend's has_perm. userHasPermission expresses it; a plain
    // list lookup hid these queues from admins (Task 71 H1).
    final canApproveLeave = userHasPermission(user, 'leave.approve');
    final canApproveExpense = userHasPermission(user, 'expenses.approve');
    // attendance.create — matches web's useAnyPermission("leave.approve",
    // "expenses.approve", "attendance.create") exactly. Previously mobile
    // used attendance.view here, which was a real mismatch (attendance.view
    // is a much broader read permission most employees have, so this tab
    // was showing up for people who couldn't actually action anything).
    final canApproveCorrections = userHasPermission(user, 'attendance.create');
    // wfh.approve — WFH is folded into this same Team Approvals inbox as
    // one more request kind (matches web's TeamApprovalsSection.tsx), not
    // given its own tab or screen.
    final canApproveWfh = userHasPermission(user, 'wfh.approve');
    // separation.approve — web's Team Approvals gate includes it
    // (approvals/page.tsx useAnyPermission); separation requests join the
    // same inbox.
    final canApproveSeparation = userHasPermission(user, 'separation.approve');
    final canApproveTeam = canApproveLeave ||
        canApproveExpense ||
        canApproveCorrections ||
        canApproveWfh ||
        canApproveSeparation;
    // Task 77: what the backend authorises for this tab's endpoints
    // (apps/payroll/views/attendance_approval.py _can_view_approvals): a team
    // manager (role.can_manage_team, or a superuser) or has_perm payroll.edit
    // (superuser / settings.edit / the codename). Web shows the tab for
    // payroll.view instead, which every one of these endpoints refuses (403)
    // — reported, not copied. The endpoints sit under /api/payroll/, which
    // the backend blocks when the payroll module is off (tenants
    // feature_gate), so the payroll module is needed besides web's attendance
    // module.
    final canApproveAttendance = userHasModule(user, AppModules.attendance) &&
        userHasModule(user, AppModules.payroll) &&
        ((user?.canManageTeam ?? false) || userHasPermission(user, 'payroll.edit'));
    // Web: facial_recognition.approve and the face_attendance module.
    final canApproveFaceId = userHasPermission(user, 'facial_recognition.approve') &&
        userHasModule(user, AppModules.faceAttendance);
    // Web approvals/page.tsx: usePermission("leave.approve"); backend
    // LeaveCancellationListView: has_perm leave.approve (settings.edit passes
    // too); also needs the leave module.
    final canReviewCancellations = canReviewLeaveCancellations(user);
    // Web: Delegation for leave.approve, or attendance.create held by
    // attendance staff (canDelegateApprovals).
    final canDelegate = canDelegateApprovals(user);

    final keys = <String>[
      if (canApproveTeam) 'team',
      if (canApproveAttendance) 'attendance',
      if (canApproveFaceId) 'face_id',
      if (canReviewCancellations) 'leave_cancellations',
      if (canDelegate) 'delegation',
    ];
    _syncTabs(keys);
    final tabCtrl = _tabCtrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              // Same heading + sub-line pattern as My Profile under the blue app bar.
              // Title and the pending badge sit side by side only when there is room;
              // on a narrow screen or at large text the badge goes underneath, so the
              // title is never squeezed into a sliver.
              child: LayoutBuilder(builder: (context, c) {
                final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Approvals', style: AppTextStyles.h4),
                    const SizedBox(height: 2),
                    Text('Items waiting on your action', style: AppTextStyles.caption.copyWith(fontSize: 12)),
                  ],
                );
                if (!canApproveTeam) return title;
                if (c.maxWidth < 340 || scale > 1.2) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 8), _PendingTotal()],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: title), _PendingTotal()],
                );
              }),
            ),
            if (keys.isEmpty)
              Expanded(child: _EmptyState())
            else if (tabCtrl != null) ...[
              // Web always shows the section tabs, even for a single one.
              TabBar(
                controller: tabCtrl,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textPrimary,
                labelPadding: const EdgeInsets.symmetric(horizontal: 18),
                splashBorderRadius: BorderRadius.circular(22),
                labelStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
                unselectedLabelStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                tabs: [
                  for (final k in keys)
                    Tab(height: 44, child: ApprovalsTabLabel(_tabIcon(k), _tabLabel(k))),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: tabCtrl,
                  children: keys
                      .map((k) => switch (k) {
                            'team' => TeamApprovalsTab(
                                canApproveLeave: canApproveLeave,
                                canApproveExpense: canApproveExpense,
                                canApproveCorrections: canApproveCorrections,
                                canApproveWfh: canApproveWfh,
                                canApproveSeparation: canApproveSeparation,
                              ),
                            'face_id' => const FaceRegistrationApprovalsTab(),
                            'leave_cancellations' => const LeaveCancellationsTab(),
                            'delegation' => const DelegationsTab(),
                            _ => const AttendanceApprovalTab(),
                          })
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: ApprovalsEmptyState(
        kind: ApprovalsStateKind.denied,
        title: 'Approvals aren’t available',
        message: 'You have no approval permissions.',
      ),
    );
  }
}

/// Total pending across every kind this user can see (web SummaryCards "Pending
/// Requests") — the real count, nothing invented.
class _PendingTotal extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(approvalsSummaryCountsProvider).pendingTotal;
    return Semantics(
      label: '$total pending',
      child: ApprovalsBadge('$total pending', total > 0 ? ApprovalsTone.warning : ApprovalsTone.success,
          icon: Icons.schedule),
    );
  }
}
