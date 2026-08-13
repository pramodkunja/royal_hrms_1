import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/branch_entity.dart';

/// Dashboard summary — every number is derived live from the currently
/// loaded branch list, never hardcoded or fetched separately.
class BranchStatsRow extends StatelessWidget {
  final List<BranchEntity> branches;
  const BranchStatsRow({super.key, required this.branches});

  @override
  Widget build(BuildContext context) {
    final totalWorkforce = branches.fold<int>(0, (sum, b) => sum + b.employeesCount);
    final citiesCovered = branches.map((b) => b.cityName).toSet().length;
    final activeBranches = branches.where((b) => b.isActive).length;
    final headquarters = branches.where((b) => b.isHeadquarter).length;
    final geofenced = branches.where((b) => b.geofencingEnabled).length;

    final items = [
      _StatCardData(
        label: 'Total Branches',
        value: '${branches.length}',
        icon: Icons.business_outlined,
        color: AppColors.primary,
        bgColor: const Color(0xFFEBF0FA),
      ),
      _StatCardData(
        label: 'Total Workforce',
        value: '$totalWorkforce',
        icon: Icons.people_outline,
        color: const Color(0xFF219653),
        bgColor: const Color(0xFFE8F7EF),
      ),
      _StatCardData(
        label: 'Cities Covered',
        value: '$citiesCovered',
        icon: Icons.location_city_outlined,
        color: AppColors.info,
        bgColor: const Color(0xFFE3F4F6),
      ),
      _StatCardData(
        label: 'Active Branches',
        value: '$activeBranches',
        icon: Icons.check_circle_outline,
        color: AppColors.success,
        bgColor: const Color(0xFFE4F4EE),
      ),
      _StatCardData(
        label: 'Headquarters',
        value: '$headquarters',
        icon: Icons.star_outline_rounded,
        color: AppColors.secondary,
        bgColor: const Color(0xFFFBF1DE),
      ),
      _StatCardData(
        label: 'Geofenced Branches',
        value: '$geofenced',
        icon: Icons.shield_outlined,
        color: AppColors.warning,
        bgColor: AppColors.warningContainer,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 900 ? 6 : (width >= 560 ? 3 : 2);
          return GridView.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: crossAxisCount >= 6 ? 1.35 : 2.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: items.map((d) => _StatCard(data: d)).toList(),
          );
        },
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 900 ? 6 : (width >= 560 ? 3 : 2);
          return GridView.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: crossAxisCount >= 6 ? 1.35 : 2.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              6,
              (_) => Container(
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          );
        },
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
