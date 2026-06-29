import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/branch_entity.dart';

class BranchStatsRow extends StatelessWidget {
  final BranchStatsEntity stats;
  const BranchStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatCardData(
        label: 'Total Branches',
        value: '${stats.totalBranches}',
        icon: Icons.business_outlined,
        color: AppColors.primary,
        bgColor: const Color(0xFFEBF0FA),
      ),
      _StatCardData(
        label: 'Total Workforce',
        value: '${stats.totalEmployees}',
        icon: Icons.people_outline,
        color: const Color(0xFF219653),
        bgColor: const Color(0xFFE8F7EF),
      ),
      _StatCardData(
        label: 'Cities Covered',
        value: '${stats.totalCities}',
        icon: Icons.location_city_outlined,
        color: AppColors.info,
        bgColor: const Color(0xFFE3F4F6),
      ),
      _StatCardData(
        label: 'Active Branches',
        value: '${stats.totalActiveBranches}',
        icon: Icons.check_circle_outline,
        color: AppColors.success,
        bgColor: const Color(0xFFE4F4EE),
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

class BranchStatsRowShimmer extends StatelessWidget {
  const BranchStatsRowShimmer({super.key});

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

class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  const _StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;
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
              color: data.bgColor,
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
