import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/expense_providers.dart';
import '../widgets/expense_list_item.dart';
import '../widgets/expense_form_sheet.dart';

// ── Filter tab ────────────────────────────────────────────────────────────────

class _FilterTab {
  final String   value;
  final String   label;
  final IconData icon;
  const _FilterTab(this.value, this.label, this.icon);
}

const _kFilterTabs = [
  _FilterTab('all',       'All Claims', Icons.list_outlined),
  _FilterTab('travel',    'Travel',     Icons.flight_takeoff_outlined),
  _FilterTab('meals',     'Meals',      Icons.restaurant_outlined),
  _FilterTab('equipment', 'Equipment',  Icons.computer_outlined),
  _FilterTab('other',     'Other',      Icons.more_horiz_outlined),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class ExpenseScreen extends ConsumerWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(expenseCategoryFilterProvider);
    final listAsync    = ref.watch(expenseListProvider);
    final statsAsync   = ref.watch(expenseStatsProvider);
    final stats        = statsAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed:       () => _openForm(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Pinned header ──────────────────────────────────────────────────
            Container(
              color:   AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize:       MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expense Claims', style: AppTextStyles.h4),
                  const SizedBox(height: 2),
                  Text(
                    'Submit and track your reimbursement requests',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // ── Scrollable body ────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color:     AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(expenseListProvider);
                  ref.invalidate(expenseStatsProvider);
                },
                child: CustomScrollView(
                  slivers: [
                    // ── Stats 2×2 grid ──────────────────────────────────────
                    SliverToBoxAdapter(
                      child: _ExpenseStatsGrid(stats: stats),
                    ),

                    // ── Filter chips ────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: _FilterChips(
                        activeFilter: activeFilter,
                        onSelect: (val) => ref
                            .read(expenseCategoryFilterProvider.notifier)
                            .state = val,
                      ),
                    ),

                    // ── List ────────────────────────────────────────────────
                    listAsync.when(
                      loading: () => const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          ),
                        ),
                      ),
                      error: (err, __) => SliverToBoxAdapter(
                        child: _ErrorState(
                          message: err.toString(),
                          onRetry: () => ref.invalidate(expenseListProvider),
                        ),
                      ),
                      data: (expenses) {
                        if (expenses.isEmpty) {
                          return SliverToBoxAdapter(
                            child: _EmptyState(
                              onNewExpense: () => _openForm(context, ref),
                            ),
                          );
                        }
                        return SliverPadding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ExpenseListItem(expense: expenses[i]),
                              ),
                              childCount: expenses.length,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    final saved = await showDialog<bool>(
      context:           context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: ExpenseFormSheet(
            onSubmit: ({
              required String title,
              required String amount,
              required String category,
              required String expenseDate,
              required String description,
              required receipts,
            }) =>
                ref.read(expenseListProvider.notifier).submit(
                  title:       title,
                  amount:      amount,
                  category:    category,
                  expenseDate: expenseDate,
                  description: description,
                  receipts:    receipts,
                ),
          ),
        ),
      ),
    );
    if (saved == true) {
      ref.invalidate(expenseStatsProvider);
    }
  }
}

// ── Stats 2×2 grid ────────────────────────────────────────────────────────────

class _ExpenseStatsGrid extends StatelessWidget {
  final dynamic stats;
  const _ExpenseStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatData(
        label: 'Total Claims',
        value: stats != null ? '${stats.total}' : '—',
        icon:    Icons.receipt_long_outlined,
        color:   AppColors.primary,
        bgColor: const Color(0xFFEBF0FA),
      ),
      _StatData(
        label: 'Pending',
        value: stats != null ? '${stats.pending}' : '—',
        icon:    Icons.access_time_outlined,
        color:   const Color(0xFFB45309),
        bgColor: const Color(0xFFFEF3C7),
      ),
      _StatData(
        label: 'Approved',
        value: stats != null ? '${stats.approved}' : '—',
        icon:    Icons.check_circle_outline,
        color:   const Color(0xFF219653),
        bgColor: const Color(0xFFE8F7EF),
      ),
      _StatData(
        label: 'Total Amount',
        value: stats != null ? _fmtAmount(stats.totalAmount as double) : '—',
        icon:    Icons.payments_outlined,
        color:   AppColors.info,
        bgColor: const Color(0xFFE3F4F6),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GridView.count(
        crossAxisCount:   2,
        mainAxisSpacing:  10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.5,
        shrinkWrap:       true,
        physics:          const NeverScrollableScrollPhysics(),
        children:         items.map((d) => _StatCard(data: d)).toList(),
      ),
    );
  }

  String _fmtAmount(double amount) {
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000)   return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toStringAsFixed(0)}';
  }
}

class _StatData {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  final Color    bgColor;
  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
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
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.border),
        boxShadow:    AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        data.bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:  MainAxisAlignment.center,
              children: [
                Text(
                  data.value,
                  style: AppTextStyles.h4.copyWith(
                    color:      data.color,
                    fontWeight: FontWeight.w700,
                    fontSize:   18,
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

// ── Filter chips ──────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final String              activeFilter;
  final void Function(String) onSelect;
  const _FilterChips({required this.activeFilter, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection:  Axis.horizontal,
        padding:          const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount:        _kFilterTabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final tab      = _kFilterTabs[i];
          final selected = activeFilter == tab.value;
          return GestureDetector(
            onTap: () => onSelect(tab.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:        selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
                boxShadow: selected ? null : AppColors.cardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon,
                      size:  12,
                      color: selected ? Colors.white : AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(tab.label,
                      style: AppTextStyles.caption.copyWith(
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                        color:      selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onNewExpense;
  const _EmptyState({required this.onNewExpense});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color:        AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('No expense claims yet',
              style: AppTextStyles.h4.copyWith(fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Submit a new expense to get started.\nAttach your receipt for faster approval.',
            style:     AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onNewExpense,
            icon:  const Icon(Icons.add, size: 16),
            label: const Text('New Expense',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.wifi_off_outlined,
              size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text('Failed to load expenses',
              style: AppTextStyles.label.copyWith(color: AppColors.error)),
          const SizedBox(height: 6),
          Text(message,
              style: AppTextStyles.caption, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon:  const Icon(Icons.refresh, size: 16),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
