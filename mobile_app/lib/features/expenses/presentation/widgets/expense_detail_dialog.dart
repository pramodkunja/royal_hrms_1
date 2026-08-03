import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/expense_model.dart';
import '../providers/expense_providers.dart';
import 'expense_list_item.dart';

// ignore_for_file: use_build_context_synchronously

// ── Expense detail popup ───────────────────────────────────────────────────────
//
// Row data renders immediately (`initial`); GET /expenses/<expense_number>/
// then supplies the current state in case status changed since the list
// loaded — matches web's ExpenseDetailModal.

class ExpenseDetailDialog extends ConsumerWidget {
  final ExpenseModel initial;
  const ExpenseDetailDialog({super.key, required this.initial});

  static Future<void> show(BuildContext context, ExpenseModel expense) {
    return showDialog(
      context: context,
      builder: (_) => ExpenseDetailDialog(initial: expense),
    );
  }

  Future<void> _openReceipt(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open receipt.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(expenseDetailProvider(initial.expenseNumber));
    final expense = detailAsync.valueOrNull ?? initial;
    final stColor = _statusColor(expense.status);
    final stBg = _statusBg(expense.status);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      expense.expenseRef.isEmpty
                          ? 'Expense'
                          : expense.expenseRef,
                      style: AppTextStyles.h4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textHint,
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (detailAsync.isLoading &&
                        detailAsync.valueOrNull == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            Text('Loading latest status…',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    if (detailAsync.hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Could not refresh — showing last known details.',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.error),
                        ),
                      ),

                    // Title + status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Field(label: 'Title', value: expense.title),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: stBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            expense.status[0].toUpperCase() +
                                expense.status.substring(1),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: stColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            label: 'Amount',
                            value: '₹${_formatFull(expense.amount)}',
                            valueStyle: AppTextStyles.h4.copyWith(fontSize: 15),
                          ),
                        ),
                        Expanded(
                          child: _Field(
                            label: 'Category',
                            value: categoryLabel(expense.category),
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
                    _Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            label: 'Employee',
                            value: expense.employeeName.isEmpty
                                ? '—'
                                : expense.employeeName,
                          ),
                        ),
                        Expanded(
                          child: _Field(
                            label: 'Branch',
                            value: expense.branchName.isEmpty
                                ? '—'
                                : expense.branchName,
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
                    _Divider(),
                    _Field(
                        label: 'Expense Date',
                        value: formatDate(expense.expenseDate)),
                    if (expense.description.isNotEmpty) ...[
                      _Divider(),
                      _Field(label: 'Description', value: expense.description),
                    ],
                    if (expense.receipts.isNotEmpty) ...[
                      _Divider(),
                      Text(
                        'Receipts (${expense.receipts.length})',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...expense.receipts.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final receipt = entry.value;
                        final hasUrl =
                            receipt.url != null && receipt.url!.isNotEmpty;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: hasUrl
                                ? () => _openReceipt(context, receipt.url)
                                : null,
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              children: [
                                Icon(Icons.attach_file_outlined,
                                    size: 15,
                                    color: hasUrl
                                        ? AppColors.primary
                                        : AppColors.textHint),
                                const SizedBox(width: 6),
                                Text(
                                  'Receipt ${idx + 1}',
                                  style: AppTextStyles.body.copyWith(
                                    color: hasUrl
                                        ? AppColors.primary
                                        : AppColors.textHint,
                                    fontWeight: FontWeight.w600,
                                    decoration: hasUrl
                                        ? TextDecoration.underline
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFull(double amount) {
    final str = amount.toStringAsFixed(0);
    final len = str.length;
    final buf = StringBuffer();
    for (int i = 0; i < len; i++) {
      if (i > 0) {
        final fromRight = len - i;
        if (fromRight == 3 || (fromRight > 3 && (fromRight - 3) % 2 == 0)) {
          buf.write(',');
        }
      }
      buf.write(str[i]);
    }
    return buf.toString();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFFE8F7EF);
      case 'rejected':
        return const Color(0xFFFDECEB);
      default:
        return const Color(0xFFFEF3C7);
    }
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final bool alignEnd;

  const _Field({
    required this.label,
    required this.value,
    this.valueStyle,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: valueStyle ??
              AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: AppColors.border),
    );
  }
}
