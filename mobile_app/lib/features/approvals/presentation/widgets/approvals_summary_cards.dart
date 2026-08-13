import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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
    final items = [
      _StatData('Pending', counts.pendingTotal, Icons.pending_actions_outlined, AppColors.primary),
      _StatData('Leave', counts.leavePending, Icons.event_busy_outlined, AppColors.warning),
      _StatData('Expense', counts.expensePending, Icons.receipt_long_outlined, AppColors.info),
      _StatData('Correction', counts.correctionPending, Icons.fact_check_outlined, AppColors.success),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 4),
      child: SizedBox(
        height: 62,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => _SummaryCard(data: items[i]),
        ),
      ),
    );
  }
}

class _StatData {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatData(this.label, this.value, this.icon, this.color);
}

class _SummaryCard extends StatelessWidget {
  final _StatData data;
  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, size: 16, color: data.color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${data.value}',
                  style: AppTextStyles.h4.copyWith(
                    fontSize: 16,
                    color: data.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  data.label,
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
