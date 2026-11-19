import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/approvals_providers.dart';
import 'approvals_kit.dart';
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
  final bool canApproveSeparation;
  const TeamApprovalsTab({
    super.key,
    required this.canApproveLeave,
    required this.canApproveExpense,
    this.canApproveCorrections = false,
    this.canApproveWfh = false,
    this.canApproveSeparation = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canApproveLeave && !canApproveExpense && !canApproveCorrections && !canApproveWfh && !canApproveSeparation) {
      return const Center(
        child: ApprovalsEmptyState(
          kind: ApprovalsStateKind.denied,
          title: 'Approvals aren’t available',
          message: 'You have no approval permissions.',
        ),
      );
    }

    final selected = ref.watch(approvalsSelectedIdsProvider);

    // One scroll view: the summary, type tabs and filters are the list's header.
    // Only the bulk bar is pinned (at the bottom, within thumb reach).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: ApprovalsList(header: [ApprovalsSummaryCards(), ApprovalsTypeTabsRow(), ApprovalsToolbar()]),
        ),
        if (selected.isNotEmpty)
          const SafeArea(top: false, child: Padding(padding: EdgeInsets.only(top: 8), child: ApprovalsBulkActionBar())),
      ],
    );
  }
}
