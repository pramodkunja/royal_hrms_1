import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/leave_entity.dart';
import 'leave_number_format.dart';

// Task 84 (audit LV-11): the Apply Leave server preview, as web
// ApplyLeaveForm.tsx renders GET /leave/requests/?action=preview&leave_type=
// &start_date=&end_date=&duration= (backend views/leave.py _leave_preview).
// Every figure is the server's — nothing is recalculated here:
//   header   "{actual_leave_days} working day(s)" + "{lop_days}d will be LOP"
//   grid     Calendar Days · Actual Leave Days · Available Balance ·
//            Leave Days Used · LOP Days
//   lists    Company Holidays (name + the server's pre-formatted date, e.g.
//            "15 Aug", shown as-is) and Week-Offs (ISO date formatted like
//            web fmtDate, en-IN "16 Nov 2026", + the server's day name).
// The policy warning and web's insufficient-balance notice are separate
// widgets below, placed after the panel as on web.

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Web leave/_data.ts fmtDate: en-IN `{day: numeric, month: short, year:
/// numeric}` → "16 Nov 2026". Anything that isn't an ISO date is shown as-is.
String leavePreviewDate(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
  if (m == null) return iso.isEmpty ? '—' : iso;
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return iso;
  return '${int.parse(m.group(3)!)} ${_months[month - 1]} ${m.group(1)}';
}

class LeavePreviewPanel extends StatelessWidget {
  final LeavePreviewEntity preview;
  const LeavePreviewPanel({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    final p = preview;
    final hasLop = p.lopDays > 0;
    final headColor = hasLop ? AppColors.warning : AppColors.primary;
    final divider = Divider(height: 1, thickness: 1, color: AppColors.border);

    Widget row(String key, String label, double value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary)),
              ),
              Text(formatLeaveDays(value),
                  key: Key('leave-preview-$key'),
                  style: AppTextStyles.caption.copyWith(
                      fontSize: 12, fontWeight: FontWeight.w600, color: color ?? AppColors.textPrimary)),
            ],
          ),
        );

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(text.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.textSecondary)),
        );

    return Container(
      key: const Key('leave-preview-panel'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${formatLeaveDays(p.actualLeaveDays)} working day${p.actualLeaveDays == 1 ? '' : 's'}',
                key: const Key('leave-preview-headline'),
                style: AppTextStyles.caption.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: headColor),
              ),
              if (hasLop)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${formatLeaveDays(p.lopDays)}d will be LOP',
                      key: const Key('leave-preview-lop-badge'),
                      style: AppTextStyles.caption
                          .copyWith(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.warning)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          divider,
          const SizedBox(height: 8),
          row('calendar-days', 'Calendar Days', p.calendarDays.toDouble()),
          row('actual-days', 'Actual Leave Days', p.actualLeaveDays),
          row('available', 'Available Balance', p.availableBalance),
          row('used', 'Leave Days Used', p.leaveDaysUsed),
          row('lop', 'LOP Days', p.lopDays, color: hasLop ? AppColors.warning : null),
          if (p.companyHolidays.isNotEmpty) ...[
            const SizedBox(height: 8),
            divider,
            const SizedBox(height: 8),
            heading('Company Holidays'),
            for (final h in p.companyHolidays)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(h.label,
                          style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    // Pre-formatted by the backend ("15 Aug") — shown as-is.
                    Text(h.date, style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
          ],
          if (p.weekOffs.isNotEmpty) ...[
            const SizedBox(height: 8),
            divider,
            const SizedBox(height: 8),
            heading('Week-Offs'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final w in p.weekOffs)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('${leavePreviewDate(w.date)} · ${w.label}',
                        style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The server's policy warning (e.g. maximum consecutive days), as web's
/// info box.
class LeavePreviewWarning extends StatelessWidget {
  final String text;
  const LeavePreviewWarning({super.key, required this.text});

  @override
  Widget build(BuildContext context) => _Notice(
        key: const Key('leave-preview-warning'),
        icon: Icons.info_outline,
        color: AppColors.info,
        text: text,
      );
}

/// Web: shown when the preview says the balance isn't enough and the policy
/// doesn't convert the shortfall to LOP.
class LeavePreviewInsufficient extends StatelessWidget {
  const LeavePreviewInsufficient({super.key});

  @override
  Widget build(BuildContext context) => _Notice(
        key: const Key('leave-preview-insufficient'),
        icon: Icons.warning_amber_outlined,
        color: AppColors.error,
        text: 'Insufficient leave balance for the selected dates. This request cannot be submitted.',
      );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Notice({super.key, required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: AppTextStyles.caption.copyWith(fontSize: 11, color: color))),
          ],
        ),
      );
}
