import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/assessment_model.dart';

const _kMonthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')} ${_kMonthShort[d.month - 1]} ${d.year}';
}

class ItemRow extends StatelessWidget {
  final AssessmentItemModel item;
  final bool deleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const ItemRow({
    super.key,
    required this.item,
    required this.deleting,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = item.itemType == AssessmentItemType.video;
    final tint = isVideo ? const Color(0xFF2A6ACC) : const Color(0xFF7C3AED);

    final String subtitle;
    if (isVideo) {
      subtitle = item.durationSecs != null && item.durationSecs! > 0
          ? '${(item.durationSecs! / 60).ceil()} min'
          : 'Video';
    } else {
      subtitle = 'Quiz · ${item.passScore} pt${item.passScore == 1 ? '' : 's'}'
          '${item.correctOption.isNotEmpty ? ' · Correct: ${item.correctOption.toUpperCase()}' : ''}';
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            child: Icon(isVideo ? Icons.play_circle_outline : Icons.help_outline, size: 18, color: tint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.order}. ${item.title}',
                    style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(_fmtDate(item.createdAt), style: AppTextStyles.caption.copyWith(fontSize: 10)),
          const SizedBox(width: 4),
          if (deleting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              color: AppColors.textSecondary,
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              color: AppColors.error,
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}
