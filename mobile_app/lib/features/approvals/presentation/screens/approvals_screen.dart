import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../widgets/attendance_approval_tab.dart';
import '../widgets/face_registration_approvals_tab.dart';
import '../widgets/team_approvals_tab.dart';

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
        'face_id' => 'Face ID Approvals',
        _ => 'Attendance Approval',
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
    final canApproveLeave = user?.hasPermission('leave.approve') ?? false;
    final canApproveExpense = user?.hasPermission('expenses.approve') ?? false;
    // attendance.create — matches web's useAnyPermission("leave.approve",
    // "expenses.approve", "attendance.create") exactly. Previously mobile
    // used attendance.view here, which was a real mismatch (attendance.view
    // is a much broader read permission most employees have, so this tab
    // was showing up for people who couldn't actually action anything).
    final canApproveCorrections = user?.hasPermission('attendance.create') ?? false;
    // wfh.approve — WFH is folded into this same Team Approvals inbox as
    // one more request kind (matches web's TeamApprovalsSection.tsx), not
    // given its own tab or screen.
    final canApproveWfh = user?.hasPermission('wfh.approve') ?? false;
    final canApproveTeam =
        canApproveLeave || canApproveExpense || canApproveCorrections || canApproveWfh;
    // Matches web exactly: user.can_manage_team === true || user.is_superuser
    // === true || hasPermission('payroll.view') — no HR-role exclusion /
    // payroll.approve alternative, both of which were undocumented
    // mobile-only deviations from web's actual gate.
    final canApproveAttendance = (user?.canManageTeam ?? false) ||
        (user?.isSuperuser ?? false) ||
        (user?.hasPermission('payroll.view') ?? false);
    final canApproveFaceId = user?.hasPermission('facial_recognition.approve') ?? false;

    final keys = <String>[
      if (canApproveTeam) 'team',
      if (canApproveAttendance) 'attendance',
      if (canApproveFaceId) 'face_id',
    ];
    _syncTabs(keys);
    final tabCtrl = _tabCtrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlueHeroBanner(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Approvals', style: AppTextStyles.h4.copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Items waiting on your action',
                      style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
            ),
            if (keys.isEmpty)
              Expanded(child: _EmptyState())
            else if (tabCtrl != null) ...[
              if (keys.length > 1)
                TabBar(
                  controller: tabCtrl,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  labelStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: AppTextStyles.label.copyWith(fontSize: 13),
                  tabs: keys.map((k) => Tab(text: _tabLabel(k))).toList(),
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
                              ),
                            'face_id' => const FaceRegistrationApprovalsTab(),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 44, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              'You have no approval permissions.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
