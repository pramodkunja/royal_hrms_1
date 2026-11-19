import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/access_control.dart' show AppModules, userHasModule;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/approvals_providers.dart';

/// Web SummaryCards: Pending Requests, Leave Requests, Expense Requests,
/// Attendance Corrections — true pending counts from the raw fetch (never the
/// toolbar-filtered list); a module the company doesn't have is left out.
class ApprovalsSummaryCards extends ConsumerWidget {
  const ApprovalsSummaryCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(approvalsSummaryCountsProvider);
    final loading =
        ref.watch(unifiedTeamApprovalsProvider).isLoading && !ref.watch(unifiedTeamApprovalsProvider).hasValue;
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final cards = <_Card>[
      _Card('Pending Requests', counts.pendingTotal, Icons.schedule, AppColors.warning),
      if (userHasModule(user, AppModules.leave))
        _Card('Leave Requests', counts.leavePending, Icons.beach_access_outlined, AppColors.success),
      if (userHasModule(user, AppModules.expenses))
        _Card('Expense Requests', counts.expensePending, Icons.receipt_long_outlined, AppColors.warning),
      if (userHasModule(user, AppModules.attendance))
        _Card('Attendance Corrections', counts.correctionPending, Icons.edit_calendar_outlined, AppColors.info),
    ];
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: LayoutBuilder(builder: (context, c) {
        final cols = (scale > 1.6 || c.maxWidth < 300) ? 1 : (c.maxWidth >= 640 ? cards.length.clamp(1, 4) : 2);
        final w = (c.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final card in cards) SizedBox(width: w, child: _SummaryTile(card: card, loading: loading))],
        );
      }),
    );
  }
}

class _Card {
  const _Card(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.card, required this.loading});
  final _Card card;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration:
                BoxDecoration(color: card.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(card.icon, size: 16, color: card.color),
          ),
          const SizedBox(width: 10),
          Text(loading ? '—' : '${card.value}', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(card.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11, height: 1.2)),
          ),
        ],
      ),
    );
  }
}
