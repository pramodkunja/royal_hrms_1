import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/approvals_providers.dart';
import 'approvals_list.dart';
import 'approvals_summary_cards.dart';
import 'approvals_toolbar.dart';

/// Unified "Team Approvals" inbox — ports web's app/dashboard/approvals
/// Team Approvals tab: merges Leave requests + Expense claims + Attendance
/// Corrections into ONE scrollable list, with summary count cards, type
/// tabs (All/Leave/Expense/Attendance Correction) with live pending-count
/// badges, a search/status/date toolbar, bulk multi-select, and a detail
/// sheet. The three sources are permission-gated server-side (403 avoided
/// client-side too — see unifiedTeamApprovalsProvider), so a viewer only
/// ever sees the rows they can actually see/act on.
class TeamApprovalsTab extends ConsumerWidget {
  final bool canApproveLeave;
  final bool canApproveExpense;
  final bool canApproveCorrections;
  final bool canApproveWfh;
  const TeamApprovalsTab({
    super.key,
    required this.canApproveLeave,
    required this.canApproveExpense,
    this.canApproveCorrections = false,
    this.canApproveWfh = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canApproveLeave && !canApproveExpense && !canApproveCorrections && !canApproveWfh) {
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

    final selected = ref.watch(approvalsSelectedIdsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ApprovalsSummaryCards(),
        const ApprovalsTypeTabsRow(),
        const ApprovalsToolbar(),
        if (selected.isNotEmpty) const ApprovalsBulkActionBar(),
        const Expanded(child: ApprovalsList()),
      ],
    );
  }
}
