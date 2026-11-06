import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/monthly_leave_models.dart';

// Shared pieces of the Monthly Leave Management tab (web MonthlyLeaveTab.tsx:
// MonthYearFields, RowsTable, AnnualWarning, alerts, CollapsibleCard).

/// Collapsible section card; the body keeps its state while collapsed.
class MonthlyCollapsibleCard extends StatelessWidget {
  const MonthlyCollapsibleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700))),
                Icon(open ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
              ]),
            ),
          ),
          Visibility(
            visible: open,
            maintainState: true,
            child: Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: child),
          ),
        ],
      ),
    );
  }
}

/// Web MonthYearFields: Month (January…December) and Year (this year and
/// the two before).
class MonthYearFields extends StatelessWidget {
  const MonthYearFields({
    super.key,
    required this.month,
    required this.year,
    required this.years,
    required this.onMonth,
    required this.onYear,
    this.disabled = false,
    this.keyPrefix = '',
  });

  final int month;
  final int year;
  final List<int> years;
  final ValueChanged<int> onMonth;
  final ValueChanged<int> onYear;
  final bool disabled;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) =>
        InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder());
    return Row(children: [
      Expanded(
        flex: 3,
        child: DropdownButtonFormField<int>(
          key: Key('${keyPrefix}month'),
          initialValue: month,
          isExpanded: true,
          decoration: deco('Month'),
          items: [
            for (var i = 0; i < 12; i++) DropdownMenuItem(value: i + 1, child: Text(kMonthNames[i])),
          ],
          onChanged: disabled ? null : (v) => v == null ? null : onMonth(v),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: DropdownButtonFormField<int>(
          key: Key('${keyPrefix}year'),
          initialValue: years.contains(year) ? year : years.first,
          isExpanded: true,
          decoration: deco('Year'),
          items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y'))],
          onChanged: disabled ? null : (v) => v == null ? null : onYear(v),
        ),
      ),
    ]);
  }
}

enum MonthlyAlertKind { info, success, warn, error }

class MonthlyAlert extends StatelessWidget {
  const MonthlyAlert({super.key, required this.kind, required this.text});
  final MonthlyAlertKind kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (kind) {
      MonthlyAlertKind.info => (AppColors.info, Icons.info_outline),
      MonthlyAlertKind.success => (AppColors.success, Icons.check_circle_outline),
      MonthlyAlertKind.warn => (AppColors.warning, Icons.warning_amber_rounded),
      MonthlyAlertKind.error => (AppColors.error, Icons.error_outline),
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5))),
      ]),
    );
  }
}

/// Web AnnualWarning (possible double-counting).
class AnnualWarning extends StatelessWidget {
  const AnnualWarning({super.key, required this.types});
  final List<String> types;

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) return const SizedBox.shrink();
    return MonthlyAlert(
      key: const Key('monthly-annual-warning'),
      kind: MonthlyAlertKind.warn,
      text: 'Possible double-counting: ${types.join(', ')} also ${types.length > 1 ? 'have' : 'has'} an annual '
          'entitlement. Monthly credits are added on top of whatever is already in the balance. Use them only if '
          "that leave type isn't also credited annually.",
    );
  }
}

Color _statusColor(String status) => switch (status) {
      'new' => AppColors.success,
      'update' => AppColors.primary,
      'duplicate' => AppColors.warning,
      'error' => AppColors.error,
      _ => AppColors.textSecondary,
    };

/// Web RowsTable as cards: row, employee, leave type, credit, current,
/// change, status and details.
class MonthlyRowsList extends StatelessWidget {
  const MonthlyRowsList({super.key, required this.rows});
  final List<MonthlyImportRow> rows;

  @override
  Widget build(BuildContext context) {
    final muted = AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary);
    return Column(children: [
      for (final r in rows)
        Container(
          key: Key('monthly-row-${r.row}'),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration:
              BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('${r.row}. ${r.employeeCode}${r.employeeName != null ? ' · ${r.employeeName}' : ''}',
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text(r.statusLabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(r.status))),
            ]),
            const SizedBox(height: 2),
            Text('${r.typeLabel} · Credit ${r.credit} · Current ${r.previousText} · Change ${r.deltaText}',
                style: muted),
            if (r.message.isNotEmpty) Text(r.message, style: muted),
          ]),
        ),
    ]);
  }
}

Widget monthlySpinner() => const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2));
