import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/branch_entity.dart';
import '../../../../shared/widgets/stat_card.dart';

/// Dashboard summary — every number is derived live from the currently
/// loaded branch list, never hardcoded or fetched separately.
class BranchStatsRow extends StatelessWidget {
  final List<BranchEntity> branches;
  const BranchStatsRow({super.key, required this.branches});

  @override
  Widget build(BuildContext context) {
    final totalWorkforce =
        branches.fold<int>(0, (sum, b) => sum + b.employeesCount);
    final citiesCovered = branches.map((b) => b.cityName).toSet().length;
    final activeBranches = branches.where((b) => b.isActive).length;
    final headquarters = branches.where((b) => b.isHeadquarter).length;
    final geofenced = branches.where((b) => b.geofencingEnabled).length;

    final items = [
      StatCard(
        label: 'Total Branches',
        count: branches.length,
        icon: Icons.business_outlined,
        color: AppColors.primary,
      ),
      StatCard(
        label: 'Total Workforce',
        count: totalWorkforce,
        icon: Icons.people_outline,
        color: const Color(0xFF219653),
      ),
      StatCard(
        label: 'Cities Covered',
        count: citiesCovered,
        icon: Icons.location_city_outlined,
        color: AppColors.info,
      ),
      StatCard(
        label: 'Active Branches',
        count: activeBranches,
        icon: Icons.check_circle_outline,
        color: AppColors.success,
      ),
      StatCard(
        label: 'Headquarters',
        count: headquarters,
        icon: Icons.star_outline_rounded,
        color: AppColors.secondary,
      ),
      StatCard(
        label: 'Geofenced Branches',
        count: geofenced,
        icon: Icons.shield_outlined,
        color: AppColors.warning,
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
            children: items,
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
