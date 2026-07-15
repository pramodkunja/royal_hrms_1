import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../expenses/presentation/widgets/expense_form_sheet.dart';
import '../../../leave/domain/entities/leave_entity.dart';
import '../providers/approvals_providers.dart';
import 'new_leave_request_sheet.dart';

const _kStatusFilters = ['all', 'pending', 'approved', 'rejected'];

String _fmtIso(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${m[d.month]}';
  } catch (_) {
    return iso;
  }
}

Color _statusColor(String s) => switch (s) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      'cancelled' => AppColors.textSecondary,
      _ => AppColors.warning,
    };

class MyRequestsTab extends ConsumerWidget {
  const MyRequestsTab({super.key});

  Future<void> _newLeave(BuildContext context, WidgetRef ref) async {
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: NewLeaveRequestSheet(),
      ),
    );
    if (submitted == true) {
      ref.invalidate(myLeaveRequestsProvider);
    }
  }

  Future<void> _newExpense(BuildContext context, WidgetRef ref) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExpenseFormSheet(
        onSubmit: ({
          required title,
          required amount,
          required category,
          required expenseDate,
          required description,
          required receipts,
        }) =>
            ref.read(myExpensesProvider.notifier).submit(
                  title: title,
                  amount: amount,
                  category: category,
                  expenseDate: expenseDate,
                  description: description,
                  receipts: receipts,
                ),
      ),
    );
    if (submitted == true) {
      ref.invalidate(myExpensesProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(myRequestsTypeProvider);
    final statusFilter = ref.watch(myRequestsStatusFilterProvider);
    final isLeave = type == ApprovalsRequestType.leave;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _TypeToggle(
                  isLeave: isLeave,
                  onChanged: (v) =>
                      ref.read(myRequestsTypeProvider.notifier).state = v,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => isLeave
                    ? _newLeave(context, ref)
                    : _newExpense(context, ref),
                icon: Icon(
                    isLeave
                        ? Icons.beach_access_outlined
                        : Icons.wallet_outlined,
                    size: 15),
                label: Text(isLeave ? 'New Leave' : 'New Expense',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kStatusFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final f = _kStatusFilters[i];
                final selected = statusFilter == f;
                return GestureDetector(
                  onTap: () => ref
                      .read(myRequestsStatusFilterProvider.notifier)
                      .state = f,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              selected ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(
                      f[0].toUpperCase() + f.substring(1),
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            selected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: isLeave ? const _MyLeaveList() : const _MyExpenseList(),
        ),
      ],
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final bool isLeave;
  final ValueChanged<ApprovalsRequestType> onChanged;
  const _TypeToggle({required this.isLeave, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.backgroundLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: 'Leave',
            selected: isLeave,
            onTap: () => onChanged(ApprovalsRequestType.leave),
          ),
          _ToggleChip(
            label: 'Expense',
            selected: !isLeave,
            onTap: () => onChanged(ApprovalsRequestType.expense),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected ? AppColors.cardShadow : null,
        ),
        child: Text(label,
            style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary)),
      ),
    );
  }
}

class _MyLeaveList extends ConsumerWidget {
  const _MyLeaveList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myLeaveRequestsProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(myLeaveRequestsProvider.notifier).refresh(),
      child: requestsAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) =>
            _ErrorView(message: 'Could not load leave requests: $e'),
        data: (items) => items.isEmpty
            ? const _EmptyView(
                icon: Icons.beach_access_outlined,
                text: 'No leave requests found.')
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _LeaveRequestCard(request: items[i]),
              ),
      ),
    );
  }
}

class _MyExpenseList extends ConsumerWidget {
  const _MyExpenseList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(myExpensesProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(myExpensesProvider.notifier).refresh(),
      child: expensesAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) =>
            _ErrorView(message: 'Could not load expense claims: $e'),
        data: (items) => items.isEmpty
            ? const _EmptyView(
                icon: Icons.wallet_outlined, text: 'No expense claims found.')
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ExpenseCard(expense: items[i]),
              ),
      ),
    );
  }
}

class _LeaveRequestCard extends StatelessWidget {
  final LeaveRequestEntity request;
  const _LeaveRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(request.status);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 3, color: sc),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(request.leaveType,
                          style: AppTextStyles.label.copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sc.withValues(alpha: 0.3)),
                      ),
                      child: Text(request.status,
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: sc)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 11, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text('${_fmtIso(request.from)} – ${_fmtIso(request.to)}',
                        style: AppTextStyles.caption.copyWith(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('${request.days}d',
                        style: AppTextStyles.caption
                            .copyWith(fontSize: 11, color: AppColors.textHint)),
                    const Spacer(),
                    Text('Applied ${_fmtIso(request.appliedOn)}',
                        style: AppTextStyles.caption
                            .copyWith(fontSize: 10, color: AppColors.textHint)),
                  ],
                ),
                if (request.reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(request.reason,
                      style: AppTextStyles.caption.copyWith(
                          fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (request.rejectReason != null &&
                    request.rejectReason!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Remarks: ${request.rejectReason}',
                      style: AppTextStyles.caption
                          .copyWith(fontSize: 10, color: AppColors.error)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(expense.status);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 3, color: sc),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(expense.title,
                          style: AppTextStyles.label.copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sc.withValues(alpha: 0.3)),
                      ),
                      child: Text(expense.status,
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: sc)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(expense.category,
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                    const SizedBox(width: 8),
                    Text('₹${expense.amount.toStringAsFixed(2)}',
                        style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                    const Spacer(),
                    Text(_fmtIso(expense.createdAt),
                        style: AppTextStyles.caption
                            .copyWith(fontSize: 10, color: AppColors.textHint)),
                  ],
                ),
                if (expense.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(expense.description,
                      style: AppTextStyles.caption.copyWith(
                          fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyView({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: AppColors.textHint),
              const SizedBox(height: 10),
              Text(text, style: AppTextStyles.bodySecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message,
            style: AppTextStyles.caption.copyWith(color: AppColors.error)),
      ),
    );
  }
}
