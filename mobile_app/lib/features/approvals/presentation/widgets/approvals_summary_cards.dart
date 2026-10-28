import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../providers/approvals_providers.dart';

/// 4 small stat cards (Pending / Leave / Expense / Correction pending counts)
/// — matches web's SummaryCards, always showing true pending counts
/// regardless of the toolbar's active filters (backed by
/// [approvalsSummaryCountsProvider], which is derived from the RAW fetch).
class ApprovalsSummaryCards extends ConsumerWidget {
  const ApprovalsSummaryCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(approvalsSummaryCountsProvider);
    return StatCardRow(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      cards: [
        StatCard(
          icon: Icons.pending_actions_outlined,
          count: counts.pendingTotal,
          label: 'Pending',
          color: AppColors.primary,
        ),
        StatCard(
          icon: Icons.event_busy_outlined,
          count: counts.leavePending,
          label: 'Leave',
          color: AppColors.warning,
        ),
        StatCard(
          icon: Icons.receipt_long_outlined,
          count: counts.expensePending,
          label: 'Expense',
          color: AppColors.info,
        ),
        StatCard(
          icon: Icons.fact_check_outlined,
          count: counts.correctionPending,
          label: 'Correction',
          color: AppColors.success,
        ),
        StatCard(
          icon: Icons.home_work_outlined,
          count: counts.wfhPending,
          label: 'WFH',
          color: AppColors.primaryLight,
        ),
      ],
    );
  }
}
