import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../leave/domain/entities/leave_entity.dart';
import '../providers/approvals_providers.dart';

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

// Pending items awaiting the current user's approval, for Leave and/or
// Expense depending on which of leave.approve / expenses.approve they hold.
// If they only hold one, the type toggle is hidden and that type is forced.
class TeamApprovalsTab extends ConsumerStatefulWidget {
  final bool canApproveLeave;
  final bool canApproveExpense;
  const TeamApprovalsTab({
    super.key,
    required this.canApproveLeave,
    required this.canApproveExpense,
  });

  @override
  ConsumerState<TeamApprovalsTab> createState() => _TeamApprovalsTabState();
}

class _TeamApprovalsTabState extends ConsumerState<TeamApprovalsTab> {
  bool _actionLoading = false;

  Future<void> _approveLeave(String id) async {
    setState(() => _actionLoading = true);
    final err =
        await ref.read(pendingLeaveApprovalsProvider.notifier).approve(id);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err != null) _showSnack(err, isError: true);
  }

  Future<void> _rejectLeaveDialog(String id) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.cancel_outlined,
                  size: 18, color: AppColors.error),
            ),
            const SizedBox(width: 10),
            Text('Reject Request', style: AppTextStyles.label),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rejection Reason *',
                style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              maxLines: 3,
              maxLength: 300,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'Explain why this request is being rejected…'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Submit Rejection'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    setState(() => _actionLoading = true);
    final err = await ref
        .read(pendingLeaveApprovalsProvider.notifier)
        .reject(id, reason);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err != null) _showSnack(err, isError: true);
  }

  Future<void> _setExpenseStatus(int expenseNumber, String status) async {
    setState(() => _actionLoading = true);
    final err = await ref
        .read(pendingExpenseApprovalsProvider.notifier)
        .setStatus(expenseNumber, status);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err != null) _showSnack(err, isError: true);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final canBoth = widget.canApproveLeave && widget.canApproveExpense;
    var type = ref.watch(teamApprovalsTypeProvider);
    if (!widget.canApproveLeave && type == ApprovalsRequestType.leave) {
      type = ApprovalsRequestType.expense;
    } else if (!widget.canApproveExpense &&
        type == ApprovalsRequestType.expense) {
      type = ApprovalsRequestType.leave;
    }
    final isLeave = type == ApprovalsRequestType.leave;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canBoth)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                _ToggleChip(
                  label: 'Leave',
                  selected: isLeave,
                  onTap: () => ref
                      .read(teamApprovalsTypeProvider.notifier)
                      .state = ApprovalsRequestType.leave,
                ),
                const SizedBox(width: 8),
                _ToggleChip(
                  label: 'Expense',
                  selected: !isLeave,
                  onTap: () => ref
                      .read(teamApprovalsTypeProvider.notifier)
                      .state = ApprovalsRequestType.expense,
                ),
              ],
            ),
          ),
        Expanded(
          child: isLeave
              ? _PendingLeaveList(
                  actionLoading: _actionLoading,
                  onApprove: _approveLeave,
                  onReject: _rejectLeaveDialog,
                )
              : _PendingExpenseList(
                  actionLoading: _actionLoading,
                  onSetStatus: _setExpenseStatus,
                ),
        ),
      ],
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
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label,
            style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _PendingLeaveList extends ConsumerWidget {
  final bool actionLoading;
  final void Function(String id) onApprove;
  final void Function(String id) onReject;
  const _PendingLeaveList({
    required this.actionLoading,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingLeaveApprovalsProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () =>
          ref.read(pendingLeaveApprovalsProvider.notifier).refresh(),
      child: requestsAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) =>
            _errorView('Could not load pending leave requests: $e'),
        data: (items) => items.isEmpty
            ? _emptyView(Icons.checklist_outlined,
                'No pending leave requests for your approval.')
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final r = items[i];
                  return _LeaveApprovalCard(
                    request: r,
                    actionLoading: actionLoading,
                    onApprove: () => onApprove(r.id),
                    onReject: () => onReject(r.id),
                  );
                },
              ),
      ),
    );
  }
}

class _PendingExpenseList extends ConsumerWidget {
  final bool actionLoading;
  final void Function(int expenseNumber, String status) onSetStatus;
  const _PendingExpenseList(
      {required this.actionLoading, required this.onSetStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(pendingExpenseApprovalsProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () =>
          ref.read(pendingExpenseApprovalsProvider.notifier).refresh(),
      child: expensesAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) =>
            _errorView('Could not load pending expense claims: $e'),
        data: (items) => items.isEmpty
            ? _emptyView(Icons.checklist_outlined,
                'No pending expense claims for your approval.')
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final e = items[i];
                  return _ExpenseApprovalCard(
                    expense: e,
                    actionLoading: actionLoading,
                    onApprove: () => onSetStatus(e.expenseNumber, 'approved'),
                    onReject: () => onSetStatus(e.expenseNumber, 'rejected'),
                  );
                },
              ),
      ),
    );
  }
}

Widget _emptyView(IconData icon, String text) {
  return Center(
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.success),
            const SizedBox(height: 10),
            Text(text,
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

Widget _errorView(String message) {
  return SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message,
          style: AppTextStyles.caption.copyWith(color: AppColors.error)),
    ),
  );
}

class _LeaveApprovalCard extends StatelessWidget {
  final LeaveRequestEntity request;
  final bool actionLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _LeaveApprovalCard({
    required this.request,
    required this.actionLoading,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
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
          Container(height: 3, color: AppColors.warning),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              request.employee.isNotEmpty
                                  ? request.employee
                                  : 'Unknown',
                              style: AppTextStyles.label.copyWith(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (request.department.isNotEmpty)
                            Text(request.department,
                                style: AppTextStyles.caption
                                    .copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(request.leaveType,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: actionLoading ? null : onApprove,
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Approve',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: actionLoading ? null : onReject,
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text('Reject',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseApprovalCard extends StatelessWidget {
  final ExpenseModel expense;
  final bool actionLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _ExpenseApprovalCard({
    required this.expense,
    required this.actionLoading,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
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
          Container(height: 3, color: AppColors.warning),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              expense.employeeName.isNotEmpty
                                  ? expense.employeeName
                                  : 'Unknown',
                              style: AppTextStyles.label.copyWith(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (expense.branchName.isNotEmpty)
                            Text(expense.branchName,
                                style: AppTextStyles.caption
                                    .copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                    Text('₹${expense.amount.toStringAsFixed(2)}',
                        style: AppTextStyles.label.copyWith(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
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
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10)),
                    ),
                    const SizedBox(width: 8),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: actionLoading ? null : onApprove,
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Approve',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: actionLoading ? null : onReject,
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text('Reject',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
