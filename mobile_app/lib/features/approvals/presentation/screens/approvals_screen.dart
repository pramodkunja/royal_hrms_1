import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../widgets/attendance_approval_tab.dart';
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
    final canApproveTeam = canApproveLeave || canApproveExpense;
    // Matches web: managers always get this tab (role.can_manage_team);
    // everyone else needs a payroll permission, but HR is excluded since
    // attendance sign-off moved to Leave Management for HR specifically.
    final role = user?.role ?? '';
    final isHR = role == 'hr' || role == 'hr_admin';
    final hasPayrollPerm = user?.hasPermission('payroll.view') == true || user?.hasPermission('payroll.approve') == true;
    final canApproveAttendance = (user?.canManageTeam ?? false) || (hasPayrollPerm && !isHR);
    final canApproveCorrections = user?.hasPermission('attendance.view') ?? false;

    final keys = <String>[
      if (canApproveTeam || canApproveCorrections) 'team',
      if (canApproveAttendance) 'attendance',
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Approvals', style: AppTextStyles.h4),
                  const SizedBox(height: 2),
                  Text('Items waiting on your action', style: AppTextStyles.caption),
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
                  tabs: keys
                      .map((k) => Tab(text: k == 'team' ? 'Team Approvals' : 'Attendance Approval'))
                      .toList(),
                ),
              Expanded(
                child: TabBarView(
                  controller: tabCtrl,
                  children: keys
                      .map((k) => k == 'team'
                          ? TeamApprovalsTab(
                              canApproveLeave: canApproveLeave,
                              canApproveExpense: canApproveExpense,
                              canApproveCorrections: canApproveCorrections,
                            )
                          : const AttendanceApprovalTab())
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
