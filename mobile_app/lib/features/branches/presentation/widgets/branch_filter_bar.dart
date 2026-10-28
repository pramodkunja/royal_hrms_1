import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';

enum BranchStatusFilter { all, active, inactive }

enum BranchTypeFilter { all, headquarters, branch }

enum BranchGeofencingFilter { all, enabled, disabled }

extension BranchStatusFilterLabel on BranchStatusFilter {
  String get label => switch (this) {
        BranchStatusFilter.all => 'All',
        BranchStatusFilter.active => 'Active',
        BranchStatusFilter.inactive => 'Inactive',
      };
}

extension BranchTypeFilterLabel on BranchTypeFilter {
  String get label => switch (this) {
        BranchTypeFilter.all => 'All',
        BranchTypeFilter.headquarters => 'Headquarters',
        BranchTypeFilter.branch => 'Branch',
      };
}

extension BranchGeofencingFilterLabel on BranchGeofencingFilter {
  String get label => switch (this) {
        BranchGeofencingFilter.all => 'All',
        BranchGeofencingFilter.enabled => 'Enabled',
        BranchGeofencingFilter.disabled => 'Disabled',
      };
}

/// Search + filter controls for the branch list. Purely presentational —
/// filtering itself happens client-side over already-loaded data, owned by
/// the parent screen's state.
class BranchFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final BranchStatusFilter statusFilter;
  final ValueChanged<BranchStatusFilter> onStatusChanged;
  final BranchTypeFilter typeFilter;
  final ValueChanged<BranchTypeFilter> onTypeChanged;
  final BranchGeofencingFilter geofencingFilter;
  final ValueChanged<BranchGeofencingFilter> onGeofencingChanged;

  const BranchFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.typeFilter,
    required this.onTypeChanged,
    required this.geofencingFilter,
    required this.onGeofencingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BlueHeroBanner(
          child: TextField(
            controller: searchController,
            style: AppTextStyles.bodySmall,
            onChanged: onSearchChanged,
            decoration: heroSearchFieldDecoration(
              hintText: 'Search by name, code, city or state...',
              showClear: searchController.text.isNotEmpty,
              onClear: () {
                searchController.clear();
                onSearchChanged('');
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterDropdown<BranchStatusFilter>(
                  icon: Icons.toggle_on_outlined,
                  value: statusFilter,
                  options: BranchStatusFilter.values,
                  labelOf: (v) => v.label,
                  prefix: 'Status',
                  onChanged: onStatusChanged,
                ),
                const SizedBox(width: 8),
                _FilterDropdown<BranchTypeFilter>(
                  icon: Icons.account_tree_outlined,
                  value: typeFilter,
                  options: BranchTypeFilter.values,
                  labelOf: (v) => v.label,
                  prefix: 'Type',
                  onChanged: onTypeChanged,
                ),
                const SizedBox(width: 8),
                _FilterDropdown<BranchGeofencingFilter>(
                  icon: Icons.shield_outlined,
                  value: geofencingFilter,
                  options: BranchGeofencingFilter.values,
                  labelOf: (v) => v.label,
                  prefix: 'Geofencing',
                  onChanged: onGeofencingChanged,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final IconData icon;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final String prefix;
  final ValueChanged<T> onChanged;

  const _FilterDropdown({
    required this.icon,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.prefix,
    required this.onChanged,
  });

  bool get _isActive => labelOf(value) != 'All';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _isActive ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isActive ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: PopupMenuButton<T>(
        initialValue: value,
        onSelected: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        itemBuilder: (context) => options
            .map((o) => PopupMenuItem<T>(
                  value: o,
                  child: Text(labelOf(o), style: AppTextStyles.bodySmall),
                ))
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: _isActive ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '$prefix: ${labelOf(value)}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: _isActive ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: _isActive ? AppColors.primary : AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
