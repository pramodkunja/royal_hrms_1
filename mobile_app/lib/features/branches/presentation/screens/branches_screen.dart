import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/branch_entity.dart';
import '../providers/branch_providers.dart';
import '../widgets/branch_card.dart';
import '../widgets/branch_filter_bar.dart';
import '../widgets/branch_form_dialog.dart';
import '../widgets/branch_list_states.dart';
import '../widgets/branch_stats_row.dart';
import '../widgets/employee_distribution.dart';

class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});

  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  BranchStatusFilter _statusFilter = BranchStatusFilter.all;
  BranchTypeFilter _typeFilter = BranchTypeFilter.all;
  BranchGeofencingFilter _geoFilter = BranchGeofencingFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<BranchEntity> _applyFilters(List<BranchEntity> branches) {
    final query = _search.trim().toLowerCase();
    return branches.where((b) {
      if (query.isNotEmpty) {
        final haystack =
            '${b.branchName} ${b.branchCode} ${b.cityName} ${b.stateName}'
                .toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      switch (_statusFilter) {
        case BranchStatusFilter.active:
          if (!b.isActive) return false;
        case BranchStatusFilter.inactive:
          if (b.isActive) return false;
        case BranchStatusFilter.all:
          break;
      }
      switch (_typeFilter) {
        case BranchTypeFilter.headquarters:
          if (!b.isHeadquarter) return false;
        case BranchTypeFilter.branch:
          if (b.isHeadquarter) return false;
        case BranchTypeFilter.all:
          break;
      }
      switch (_geoFilter) {
        case BranchGeofencingFilter.enabled:
          if (!b.geofencingEnabled) return false;
        case BranchGeofencingFilter.disabled:
          if (b.geofencingEnabled) return false;
        case BranchGeofencingFilter.all:
          break;
      }
      return true;
    }).toList();
  }

  Future<void> _refresh() {
    return Future.wait([
      ref.read(branchStatsProvider.notifier).refresh(),
      ref.read(branchListProvider.notifier).refresh(),
      ref.read(branchDistributionProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchListProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      // Hidden while there are zero branches at all — BranchEmptyView
      // already has its own "Add Branch" button front and center there, so
      // showing this FAB too just duplicated the same action twice on one
      // screen (same fix as Assessments'/Documents' empty states). Still
      // shown when filters/search reduce the list to zero *matches*, since
      // then this FAB remains the only way to add a branch.
      floatingActionButton: branchesAsync.maybeWhen(
        data: (branches) => branches.isEmpty
            ? null
            : screenWidth < 360
                ? FloatingActionButton(
                    onPressed: () => _openForm(context, null),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    tooltip: 'Add Branch',
                    child: const Icon(Icons.add),
                  )
                : FloatingActionButton.extended(
                    onPressed: () => _openForm(context, null),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Add Branch',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
        orElse: () => null,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            // ── Hero (search + filters) ──────────────────────────────────────
            // No separate "Branch Management" title here — that duplicated
            // the app bar's own title. Hero comes first, matching Employees'
            // order (hero, then stats), not stats-then-hero. Pull-to-refresh
            // (RefreshIndicator above) already covers what _PageHeader's
            // explicit refresh icon used to do.
            SliverToBoxAdapter(
              child: branchesAsync.maybeWhen(
                data: (branches) => branches.isEmpty
                    ? const SizedBox.shrink()
                    : BranchFilterBar(
                        searchController: _searchCtrl,
                        onSearchChanged: (val) => setState(() => _search = val),
                        statusFilter: _statusFilter,
                        onStatusChanged: (val) =>
                            setState(() => _statusFilter = val),
                        typeFilter: _typeFilter,
                        onTypeChanged: (val) => setState(() => _typeFilter = val),
                        geofencingFilter: _geoFilter,
                        onGeofencingChanged: (val) =>
                            setState(() => _geoFilter = val),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            SliverToBoxAdapter(
              child: branchesAsync.when(
                loading: () => const BranchStatsRowShimmer(),
                error: (e, _) => const SizedBox.shrink(),
                data: (branches) => BranchStatsRow(branches: branches),
              ),
            ),
            branchesAsync.when(
              loading: () => _loadingGrid(),
              error: (e, _) => SliverToBoxAdapter(
                child: BranchErrorView(
                  message: friendlyBranchError(e),
                  onRetry: () {
                    ref.invalidate(branchListProvider);
                    ref.invalidate(branchStatsProvider);
                  },
                ),
              ),
              data: (branches) {
                if (branches.isEmpty) {
                  return SliverToBoxAdapter(
                    child: BranchEmptyView(
                        onAdd: () => _openForm(context, null)),
                  );
                }
                final filtered = _applyFilters(branches);
                if (filtered.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _NoMatchesView(onClear: () {
                      setState(() {
                        _searchCtrl.clear();
                        _search = '';
                        _statusFilter = BranchStatusFilter.all;
                        _typeFilter = BranchTypeFilter.all;
                        _geoFilter = BranchGeofencingFilter.all;
                      });
                    }),
                  );
                }
                return _BranchGrid(
                  branches: filtered,
                  twoColumns: isWide,
                  onEdit: (b) => _openForm(context, b),
                  onDelete: (b) => _confirmDelete(context, ref, b),
                );
              },
            ),
            const SliverToBoxAdapter(child: EmployeeDistributionSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, BranchEntity? branch) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: BranchFormDialog(branch: branch),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BranchEntity branch,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete "${branch.branchName}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final error =
        await ref.read(branchListProvider.notifier).remove(branch.id);
    if (error == null) {
      ref.read(branchStatsProvider.notifier).refresh();
      ref.read(branchDistributionProvider.notifier).refresh();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(error ?? '"${branch.branchName}" deleted.'),
        backgroundColor:
            error == null ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  SliverPadding _loadingGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, __) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          childCount: 3,
        ),
      ),
    );
  }
}

class _NoMatchesView extends StatelessWidget {
  final VoidCallback onClear;
  const _NoMatchesView({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 44, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('No branches match your filters', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search or filters.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
              label: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchGrid extends StatelessWidget {
  final List<BranchEntity> branches;
  final bool twoColumns;
  final void Function(BranchEntity) onEdit;
  final void Function(BranchEntity) onDelete;

  const _BranchGrid({
    required this.branches,
    required this.twoColumns,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (!twoColumns) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BranchCard(
                branch: branches[index],
                onEdit: () => onEdit(branches[index]),
                onDelete: () => onDelete(branches[index]),
              ),
            ),
            childCount: branches.length,
          ),
        ),
      );
    }

    final rowCount = (branches.length / 2).ceil();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, rowIndex) {
            final firstIndex = rowIndex * 2;
            final secondIndex = firstIndex + 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: BranchCard(
                      branch: branches[firstIndex],
                      onEdit: () => onEdit(branches[firstIndex]),
                      onDelete: () => onDelete(branches[firstIndex]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: secondIndex < branches.length
                        ? BranchCard(
                            branch: branches[secondIndex],
                            onEdit: () => onEdit(branches[secondIndex]),
                            onDelete: () => onDelete(branches[secondIndex]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
          childCount: rowCount,
        ),
      ),
    );
  }
}
