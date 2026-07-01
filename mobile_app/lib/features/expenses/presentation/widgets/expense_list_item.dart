import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/expense_model.dart';

// ── Category metadata ─────────────────────────────────────────────────────────

IconData categoryIcon(String category) {
  switch (category) {
    case 'travel':    return Icons.flight_takeoff_outlined;
    case 'meals':     return Icons.restaurant_outlined;
    case 'equipment': return Icons.computer_outlined;
    default:          return Icons.more_horiz_outlined;
  }
}

Color categoryColor(String category) {
  switch (category) {
    case 'travel':    return AppColors.primary;
    case 'meals':     return AppColors.warning;
    case 'equipment': return AppColors.info;
    default:          return AppColors.textSecondary;
  }
}

Color categoryBg(String category) {
  switch (category) {
    case 'travel':    return const Color(0xFFEBF0FA);
    case 'meals':     return const Color(0xFFFEF3C7);
    case 'equipment': return const Color(0xFFE3F4F6);
    default:          return const Color(0xFFF3F4F6);
  }
}

String categoryLabel(String category) {
  switch (category) {
    case 'travel':    return 'Travel';
    case 'meals':     return 'Meals';
    case 'equipment': return 'Equipment';
    default:          return 'Other';
  }
}

// ── Amount formatter ──────────────────────────────────────────────────────────

String formatAmount(double amount) {
  if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
  if (amount >= 1000)   return '₹${(amount / 1000).toStringAsFixed(1)}K';
  final str = amount.toStringAsFixed(0);
  final len = str.length;
  final buf = StringBuffer('₹');
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

// ── Date formatter ────────────────────────────────────────────────────────────

String formatDate(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month]} ${d.year}';
  } catch (_) {
    return iso;
  }
}

// ── Status helpers ────────────────────────────────────────────────────────────

Color _statusColor(String status) {
  switch (status) {
    case 'approved': return AppColors.success;
    case 'rejected': return AppColors.error;
    default:         return AppColors.warning;
  }
}

Color _statusBg(String status) {
  switch (status) {
    case 'approved': return const Color(0xFFE8F7EF);
    case 'rejected': return const Color(0xFFFDECEB);
    default:         return const Color(0xFFFEF3C7);
  }
}

// ── Expense list item (standalone card) ───────────────────────────────────────

class ExpenseListItem extends StatelessWidget {
  final ExpenseModel expense;

  const ExpenseListItem({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    final catColor   = categoryColor(expense.category);
    final catBgColor = categoryBg(expense.category);
    final catIcon    = categoryIcon(expense.category);
    final catLbl     = categoryLabel(expense.category);
    final stColor    = _statusColor(expense.status);
    final stBg       = _statusBg(expense.status);
    final hasReceipt = expense.receipts.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.border),
        boxShadow:    AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category icon bubble
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color:        catBgColor,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(catIcon, size: 20, color: catColor),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                mainAxisSize:       MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + amount
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          expense.title,
                          style: AppTextStyles.label.copyWith(
                              fontSize: 13, color: AppColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatAmount(expense.amount),
                        style: AppTextStyles.h4.copyWith(
                            fontSize: 15, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Meta row
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MetaChip(
                          icon:  Icons.calendar_today_outlined,
                          label: formatDate(expense.expenseDate)),
                      if (expense.employeeName.isNotEmpty)
                        _MetaChip(
                            icon:  Icons.person_outline,
                            label: expense.employeeName),
                      if (expense.branchName.isNotEmpty)
                        _MetaChip(
                            icon:  Icons.business_outlined,
                            label: expense.branchName),
                      if (hasReceipt)
                        const _MetaChip(
                            icon:  Icons.attach_file_outlined,
                            label: 'Receipt',
                            color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Footer: category badge + status badge
                  Row(
                    children: [
                      _CategoryBadge(label: catLbl, color: catColor, bg: catBgColor),
                      const SizedBox(width: 8),
                      _StatusBadge(
                          status: expense.status,
                          color:  stColor,
                          bg:     stBg),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color?   color;
  const _MetaChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 3),
        Text(label,
            style: AppTextStyles.caption.copyWith(fontSize: 10, color: c),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;
  final Color  color;
  final Color  bg;
  const _CategoryBadge({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: AppTextStyles.caption.copyWith(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color  color;
  final Color  bg;
  const _StatusBadge({required this.status, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    final label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: AppTextStyles.caption.copyWith(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
