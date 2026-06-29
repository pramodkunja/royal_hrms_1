import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/branch_entity.dart';
import '../providers/branch_providers.dart';
import '../widgets/branch_card.dart';
import '../widgets/branch_form_dialog.dart';
import '../widgets/branch_list_states.dart';
import '../widgets/branch_stats_row.dart';
import '../widgets/employee_distribution.dart';

class BranchesScreen extends ConsumerWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(branchStatsProvider);
    final branchesAsync = ref.watch(branchListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await Future.wait([
            ref.read(branchStatsProvider.notifier).refresh(),
            ref.read(branchListProvider.notifier).refresh(),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Branch Management',
                  style: AppTextStyles.h4,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: statsAsync.when(
                loading: () => const BranchStatsRowShimmer(),
                error: (e, _) => const SizedBox.shrink(),
                data: (stats) => BranchStatsRow(stats: stats),
              ),
            ),
            branchesAsync.when(
              loading: () => _loadingGrid(),
              error: (e, _) => SliverToBoxAdapter(
                child: BranchErrorView(
                  message: e.toString(),
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
                return _BranchGrid(
                  branches: branches,
                  onEdit: (b) => _openForm(context, b),
                  onDelete: (b) => _confirmDelete(context, ref, b),
                );
              },
            ),
            branchesAsync.maybeWhen(
              data: (branches) {
                if (branches.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: EmployeeDistributionSection(branches: branches),
                );
              },
              orElse: () =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
    if (error == null) ref.read(branchStatsProvider.notifier).refresh();

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
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          childCount: 3,
        ),
      ),
    );
  }
}

class _BranchGrid extends StatelessWidget {
  final List<BranchEntity> branches;
  final void Function(BranchEntity) onEdit;
  final void Function(BranchEntity) onDelete;

  const _BranchGrid({
    required this.branches,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
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
}

