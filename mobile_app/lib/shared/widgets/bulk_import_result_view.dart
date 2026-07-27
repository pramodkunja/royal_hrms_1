import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../models/bulk_import_result.dart';

/// Renders a completed [BulkImportResult]: summary counts, then expandable
/// skipped/error row lists. Shared by the Employee and Candidate bulk-import
/// screens since the backend returns an identically-shaped envelope for both.
class BulkImportResultView extends StatelessWidget {
  final BulkImportResult result;
  const BulkImportResultView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _StatChip(label: 'Total', value: result.totalRows, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            _StatChip(label: 'Created', value: result.created, color: AppColors.success),
            const SizedBox(width: 8),
            _StatChip(label: 'Skipped', value: result.skipped, color: AppColors.warning),
            const SizedBox(width: 8),
            _StatChip(label: 'Failed', value: result.failed, color: AppColors.error),
          ],
        ),
        if (result.skippedRows.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            icon: Icons.info_outline,
            color: AppColors.warning,
            title: 'Skipped (${result.skippedRows.length})',
            children: result.skippedRows
                .map((s) => _RowTile(
                      row: s.row,
                      title: s.identifier,
                      subtitle: s.reason,
                      color: AppColors.warning,
                    ))
                .toList(),
          ),
        ],
        if (result.errors.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            icon: Icons.error_outline,
            color: AppColors.error,
            title: 'Errors (${result.errors.length})',
            children: result.errors
                .map((e) => _RowTile(
                      row: e.row,
                      title: e.identifier?.isNotEmpty == true ? e.identifier! : e.field,
                      subtitle: e.message,
                      color: AppColors.error,
                    ))
                .toList(),
          ),
        ],
        if (result.createdRows.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            icon: Icons.check_circle_outline,
            color: AppColors.success,
            title: 'Created (${result.createdRows.length})',
            children: result.createdRows
                .map((c) => _RowTile(
                      row: c.row,
                      title: c.identifier,
                      subtitle: c.extra,
                      color: AppColors.success,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<Widget> children;
  const _Section({required this.icon, required this.color, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        initiallyExpanded: children.length <= 5,
        leading: Icon(icon, size: 18, color: color),
        title: Text(title,
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, color: color)),
        children: children,
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final int row;
  final String title;
  final String? subtitle;
  final Color color;
  const _RowTile({required this.row, required this.title, this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Row $row',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: AppTextStyles.caption.copyWith(fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
