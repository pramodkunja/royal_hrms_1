import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../widgets/my_requests_tab.dart';
import '../widgets/team_approvals_tab.dart';

// Ports web's app/dashboard/approvals/page.tsx — a "My Requests" section
// (own leave + expense requests, with quick-create) and a "Team Approvals"
// section (pending items awaiting the current user's action). Unlike the
// web page, "Team Approvals" is hidden entirely for users with neither
// leave.approve nor expenses.approve, since an approval queue that only
// ever shows your own pending request (and 403s on Approve/Reject) is a
// dead end — same reasoning as hiding the Leave module's Approvals tab.
class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen> {
  bool _showTeamApprovals = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final canApproveLeave = user?.hasPermission('leave.approve') ?? false;
    final canApproveExpense = user?.hasPermission('expenses.approve') ?? false;
    final canApproveAnything = canApproveLeave || canApproveExpense;

    if (!canApproveAnything && _showTeamApprovals) {
      _showTeamApprovals = false;
    }

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
                  Text(
                    'Your requests and items waiting on your action',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            if (canApproveAnything)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: _SectionSwitch(
                  showTeamApprovals: _showTeamApprovals,
                  onChanged: (v) => setState(() => _showTeamApprovals = v),
                ),
              ),
            Expanded(
              child: _showTeamApprovals
                  ? TeamApprovalsTab(
                      canApproveLeave: canApproveLeave,
                      canApproveExpense: canApproveExpense,
                    )
                  : const MyRequestsTab(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionSwitch extends StatelessWidget {
  final bool showTeamApprovals;
  final ValueChanged<bool> onChanged;
  const _SectionSwitch(
      {required this.showTeamApprovals, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.backgroundLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SwitchPill(
              label: 'My Requests',
              icon: Icons.inbox_outlined,
              selected: !showTeamApprovals,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _SwitchPill(
              label: 'Team Approvals',
              icon: Icons.checklist_outlined,
              selected: showTeamApprovals,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _SwitchPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected ? AppColors.cardShadow : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
