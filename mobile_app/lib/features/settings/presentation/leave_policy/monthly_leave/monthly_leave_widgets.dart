import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/monthly_leave_models.dart';

// Shared pieces of the Monthly Leave Management tab (web MonthlyLeaveTab.tsx:
// MonthYearFields, RowsTable, AnnualWarning, alerts, CollapsibleCard).

/// Minimum touch target for every action in this tab.
const double kMonthlyTarget = 44;

/// The factor the user's font setting applies to ordinary body text.
double monthlyTextScale(BuildContext context) => MediaQuery.textScalerOf(context).scale(14) / 14;

/// True when controls should stack: a narrow slot or enlarged text. Measured
/// from the space the widget really gets, not from the device.
bool monthlyCompact(BuildContext context, double width, {double narrow = 360, double scale = 1.3}) =>
    width < narrow || monthlyTextScale(context) > scale;

ButtonStyle get monthlyFilledStyle => FilledButton.styleFrom(minimumSize: const Size(64, kMonthlyTarget));
ButtonStyle get monthlyOutlinedStyle => OutlinedButton.styleFrom(minimumSize: const Size(64, kMonthlyTarget));
ButtonStyle get monthlyTextStyle => TextButton.styleFrom(minimumSize: const Size(64, kMonthlyTarget));

/// A label above its input (web form labels), with a gap before the control.
class MonthlyField extends StatelessWidget {
  const MonthlyField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          child,
        ],
      );
}

/// Primary action with an optional secondary one. Wide: secondary left, primary
/// right (web order). Narrow or large text: full width, primary on top.
class MonthlyActionBar extends StatelessWidget {
  const MonthlyActionBar({super.key, required this.primary, this.secondary, this.alignEnd = true});
  final Widget primary;
  final Widget? secondary;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (monthlyCompact(context, c.maxWidth, narrow: 440, scale: 1.15)) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            primary,
            if (secondary != null) ...[const SizedBox(height: 8), secondary!],
          ]);
        }
        return Wrap(
          alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [if (secondary != null) secondary!, primary],
        );
      });
}

/// Cards as one column, or two when the slot is wide enough (tablet).
class MonthlyCardGrid extends StatelessWidget {
  const MonthlyCardGrid({super.key, required this.children, this.gap = 8});
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 560 || monthlyTextScale(context) > 1.6) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final w in children) Padding(padding: EdgeInsets.only(bottom: gap), child: w),
          ]);
        }
        final w = (c.maxWidth - gap) / 2;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final child in children) SizedBox(width: w, child: child),
        ]);
      });
}

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
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
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
/// the two before). Side by side when there is room, stacked otherwise.
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
    const deco = InputDecoration(isDense: true, border: OutlineInputBorder());
    final monthField = MonthlyField(
      label: 'Month',
      child: DropdownButtonFormField<int>(
        key: Key('${keyPrefix}month'),
        initialValue: month,
        isExpanded: true,
        decoration: deco,
        items: [
          for (var i = 0; i < 12; i++) DropdownMenuItem(value: i + 1, child: Text(kMonthNames[i])),
        ],
        onChanged: disabled ? null : (v) => v == null ? null : onMonth(v),
      ),
    );
    final yearField = MonthlyField(
      label: 'Year',
      child: DropdownButtonFormField<int>(
        key: Key('${keyPrefix}year'),
        initialValue: years.contains(year) ? year : years.first,
        isExpanded: true,
        decoration: deco,
        items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y'))],
        onChanged: disabled ? null : (v) => v == null ? null : onYear(v),
      ),
    );
    return LayoutBuilder(builder: (context, c) {
      if (monthlyCompact(context, c.maxWidth, narrow: 300)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [monthField, const SizedBox(height: 12), yearField],
        );
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: monthField),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: yearField),
      ]);
    });
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

/// Word + dot + colour, so a status never relies on colour alone.
class MonthlyStatusBadge extends StatelessWidget {
  const MonthlyStatusBadge(this.status, this.label, {super.key});
  final String status, label;

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c))),
      ]),
    );
  }
}

/// A small labelled figure (Credit, Current, Change…).
class MonthlyFigure extends StatelessWidget {
  const MonthlyFigure(this.label, this.value, {super.key});
  final String label, value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 72),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary)),
          Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Web RowsTable as record cards: header (row, code · name) with a status
/// badge, the leave type, labelled Credit / Current / Change figures, then the
/// details message.
class MonthlyRowsList extends StatelessWidget {
  const MonthlyRowsList({super.key, required this.rows});
  final List<MonthlyImportRow> rows;

  @override
  Widget build(BuildContext context) => MonthlyCardGrid(children: [for (final r in rows) _RowCard(r)]);
}

class _RowCard extends StatelessWidget {
  const _RowCard(this.r);
  final MonthlyImportRow r;

  @override
  Widget build(BuildContext context) {
    final muted = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary);
    final title = Text('${r.row}. ${r.employeeCode}${r.employeeName != null ? ' · ${r.employeeName}' : ''}',
        style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600));
    final badge = MonthlyStatusBadge(r.status, r.statusLabel);
    return Container(
      key: Key('monthly-row-${r.row}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(
          builder: (context, c) => monthlyCompact(context, c.maxWidth, narrow: 300, scale: 1.15)
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 6), badge])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: title),
                  const SizedBox(width: 8),
                  badge,
                ]),
        ),
        const SizedBox(height: 4),
        Text(r.typeLabel, style: muted),
        const SizedBox(height: 8),
        Wrap(spacing: 20, runSpacing: 8, children: [
          MonthlyFigure('Credit', r.credit),
          MonthlyFigure('Current', r.previousText),
          MonthlyFigure('Change', r.deltaText),
        ]),
        if (r.message.isNotEmpty) ...[const SizedBox(height: 8), Text(r.message, style: muted)],
      ]),
    );
  }
}

Widget monthlySpinner() => const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2));
