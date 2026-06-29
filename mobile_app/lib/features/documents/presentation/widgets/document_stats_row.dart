import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/document_entity.dart';

class DocumentStatsRow extends StatelessWidget {
  final DocumentStatsEntity stats;
  const DocumentStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatData(
        label: 'Total Documents',
        value: '${stats.total}',
        icon: Icons.folder_outlined,
        color: AppColors.primary,
        bg: const Color(0xFFEBF0FA),
      ),
      _StatData(
        label: 'Policies',
        value: '${stats.policy}',
        icon: Icons.policy_outlined,
        color: const Color(0xFF219653),
        bg: const Color(0xFFE8F7EF),
      ),
      _StatData(
        label: 'Forms',
        value: '${stats.form}',
        icon: Icons.description_outlined,
        color: AppColors.info,
        bg: const Color(0xFFE3F4F6),
      ),
      _StatData(
        label: 'Templates',
        value: '${stats.template}',
        icon: Icons.picture_as_pdf_outlined,
        color: AppColors.warning,
        bg: const Color(0xFFFEF3C7),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: items.map((d) => _StatCard(data: d)).toList(),
      ),
    );
  }
}

class DocumentStatsRowShimmer extends StatelessWidget {
  const DocumentStatsRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
          4,
          (_) => Container(
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;
  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: data.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.value,
                  style: AppTextStyles.h4.copyWith(
                    color: data.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
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
