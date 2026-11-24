import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../../../shared/formatters/en_in_format.dart' show formatMoney;
import '../../data/models/expense_model.dart' show ExpenseStats;
import '../providers/expense_providers.dart';
import '../widgets/expense_list_item.dart';
import '../widgets/expense_form_sheet.dart';
import 'package:mobile_app/shared/widgets/app_error_state.dart';

// ── Filter tab ────────────────────────────────────────────────────────────────

class _FilterTab {
  final String value;
  final String label;
  final IconData icon;
  const _FilterTab(this.value, this.label, this.icon);
}

const _kFilterTabs = [
  _FilterTab('all', 'All Claims', Icons.list_outlined),
  _FilterTab('travel', 'Travel', Icons.flight_takeoff_outlined),
  _FilterTab('meals', 'Meals', Icons.restaurant_outlined),
  _FilterTab('equipment', 'Equipment', Icons.computer_outlined),
  _FilterTab('other', 'Other', Icons.more_horiz_outlined),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class ExpenseScreen extends ConsumerWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(expenseCategoryFilterProvider);
    final listAsync = ref.watch(expenseListProvider);
    final statsAsync = ref.watch(expenseStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      // Hidden while there are zero expense claims — _EmptyState already
      // has its own "New Expense" button front and center there, so showing
      // this FAB too just duplicated the same action twice on one screen
      // (same fix as Assessments'/Documents'/Branches' empty states).
      floatingActionButton: listAsync.maybeWhen(
        data: (expenses) => expenses.isEmpty
            ? null
            : FloatingActionButton(
                onPressed: () => _openForm(context, ref),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add, color: Colors.white),
              ),
        orElse: () => null,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Pinned header (blue hero) ────────────────────────────────────
            BlueHeroBanner(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expense Claims',
                      style: AppTextStyles.h4.copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    'Submit and track your reimbursement requests',
                    style: AppTextStyles.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(expenseListProvider);
                  ref.invalidate(expenseStatsProvider);
                },
                child: CustomScrollView(
                  slivers: [
                    // ── Stats cards (web's five-card summary; see the section below) ─────────
                    SliverToBoxAdapter(
                      child: _ExpenseStatsSection(
                        stats: statsAsync,
                        categoryFiltered: activeFilter != 'all',
                        onRetry: () => ref.invalidate(expenseStatsProvider),
                      ),
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
                      loading: () => SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          ),
                        ),
                      ),
                      error: (err, __) => SliverToBoxAdapter(
                        child: AppErrorState.forError(
                          err,
                          title: 'Failed to load expenses',
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
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                      title: title,
                      amount: amount,
                      category: category,
                      expenseDate: expenseDate,
                      description: description,
                      receipts: receipts,
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

// ── Stats cards ───────────────────────────────────────────────────────────────
//
// Mirrors web's ExpenseClaims summary (GET /expenses/stats/):
//   Total Claims         ← total                      (count)
//   Pending              ← pending      + pending_amount  when > 0 (₹, en-IN grouping)
//   Approved             ← approved     + approved_amount when > 0 (₹, en-IN grouping)
//   Rejected             ← rejected                   (count)
//   Total Claimed Amount ← total_amount               (₹, "1.5L" / "12.5K" abbreviation)
// Values come only from that response, never from the paginated list. While the request is
// loading or refreshing, or after it failed, a card shows "—" (not the previous numbers, not
// 0); an error says so and offers Retry.

/// Web `formatAmount`: ≥1 lakh → "₹1.5L", ≥1 thousand → "₹12.5K", else en-IN grouped with up
/// to two decimals (never rounded to a whole rupee).
String formatExpenseTotal(double n) {
  if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1)}L';
  if (n >= 1000) return '₹${(n / 1000).toStringAsFixed(1)}K';
  return formatMoney(n);
}

class _ExpenseStatsSection extends StatelessWidget {
  final AsyncValue<ExpenseStats> stats;
  final bool categoryFiltered;
  final VoidCallback onRetry;
  const _ExpenseStatsSection({required this.stats, required this.categoryFiltered, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Only a finished, successful response counts as current data.
    final s = stats.isLoading ? null : stats.valueOrNull;
    final failed = !stats.isLoading && stats.hasError;

    String count(int? v) => v == null ? '—' : '$v';
    String? sub(double? v) => v != null && v > 0 ? formatMoney(v) : null;

    final cards = [
      _StatTile(
        key: const Key('expense-stat-total'),
        label: 'Total Claims',
        value: count(s?.total),
        icon: Icons.receipt_long_outlined,
        color: AppColors.primary,
      ),
      _StatTile(
        key: const Key('expense-stat-pending'),
        label: 'Pending',
        value: count(s?.pending),
        sub: sub(s?.pendingAmount),
        icon: Icons.access_time_outlined,
        color: const Color(0xFFB45309),
      ),
      _StatTile(
        key: const Key('expense-stat-approved'),
        label: 'Approved',
        value: count(s?.approved),
        sub: sub(s?.approvedAmount),
        icon: Icons.check_circle_outline,
        color: const Color(0xFF219653),
      ),
      _StatTile(
        key: const Key('expense-stat-rejected'),
        label: 'Rejected',
        value: count(s?.rejected),
        icon: Icons.cancel_outlined,
        color: AppColors.error,
      ),
      _StatTile(
        key: const Key('expense-stat-amount'),
        label: 'Total Claimed Amount',
        value: s?.totalAmount == null ? '—' : formatExpenseTotal(s!.totalAmount!),
        icon: Icons.payments_outlined,
        color: AppColors.info,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failed) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: AppErrorState.forError(
                stats.error!,
                key: const Key('expense-stats-error'),
                title: 'Could not load the summary',
                onRetry: onRetry,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 10),
          ],
          LayoutBuilder(builder: (context, c) {
            // One column at large text so labels and amounts keep whole words.
            final large = MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
            final cols = large ? 1 : (c.maxWidth >= 900 ? 5 : (c.maxWidth >= 560 ? 3 : 2));
            const gap = 10.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < cards.length; i++)
                  // On a phone the last (amount) card takes the whole row.
                  SizedBox(width: cols <= 2 && i == cards.length - 1 ? c.maxWidth : w, child: cards[i]),
              ],
            );
          }),
          if (categoryFiltered) ...[
            const SizedBox(height: 8),
            Text(
              'These totals cover all claims in every category; the list below is filtered.',
              key: const Key('expense-stats-scope-note'),
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;
  const _StatTile({super.key, required this.label, required this.value, this.sub, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final iconTile = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 20, color: color),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The figure is never clipped or truncated: it shrinks only if it cannot fit.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              maxLines: 1,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.1, letterSpacing: -0.5)),
        ),
        const SizedBox(height: 3),
        Text(label,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(sub!,
                style: AppTextStyles.caption.copyWith(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(children: [iconTile, const SizedBox(width: 10), Expanded(child: text)]),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final String activeFilter;
  final void Function(String) onSelect;
  const _FilterChips({required this.activeFilter, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    // Tall enough for the chip at the user's text size (50 at normal size).
    final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return SizedBox(
      height: 30 + 20 * textScale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: _kFilterTabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final tab = _kFilterTabs[i];
          final selected = activeFilter == tab.value;
          return GestureDetector(
            onTap: () => onSelect(tab.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
                boxShadow: selected ? null : AppColors.cardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon,
                      size: 12,
                      color: selected ? Colors.white : AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(tab.label,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            selected ? Colors.white : AppColors.textSecondary,
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
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.account_balance_wallet_outlined,
                size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('No expense claims yet',
              style: AppTextStyles.h4.copyWith(fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Submit a new expense to get started.\nAttach your receipt for faster approval.',
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onNewExpense,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Expense',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

