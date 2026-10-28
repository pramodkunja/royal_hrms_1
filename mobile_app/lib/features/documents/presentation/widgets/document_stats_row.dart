import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/document_entity.dart';
import '../../../../shared/widgets/stat_card.dart';

class DocumentStatsRow extends StatelessWidget {
  final DocumentStatsEntity stats;
  const DocumentStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      StatCard(
        label: 'Total Documents',
        count: stats.total,
        icon: Icons.folder_outlined,
        color: AppColors.primary,
      ),
      StatCard(
        label: 'Policies',
        count: stats.policy,
        icon: Icons.policy_outlined,
        color: const Color(0xFF219653),
      ),
      StatCard(
        label: 'Forms',
        count: stats.form,
        icon: Icons.description_outlined,
        color: AppColors.info,
      ),
      StatCard(
        label: 'Templates',
        count: stats.template,
        icon: Icons.picture_as_pdf_outlined,
        color: AppColors.warning,
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
        children: items,
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
