import '../../../../shared/formatters/en_in_format.dart' show formatEnInDate;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart';
import '../../domain/entities/attendance_entity.dart';

// HR Attendance -> OT Entry -> "OT Records". Shows exactly what the list API
// returns (backend services_hr_ops.list_overtime): employee name + id, date,
// OT hours, type, OT amount, approver name and status. The API has no remarks
// field, and web's OT Records table has no row actions (create-only), so the
// card carries none.

/// `2026-11-18` -> `18 Nov 2026` (en-IN, so September is "Sept"); anything else is shown as received.
String formatAttendanceDate(String raw) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
  if (m == null) return raw;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  final date = DateTime(y, mo, d);
  // A date that does not exist (month 13, 31 Feb) is not reformatted.
  if (date.year != y || date.month != mo || date.day != d) return raw;
  return formatEnInDate(date);
}

/// pending -> amber, approved -> green, rejected -> red, anything else neutral.
ApprovalsTone otStatusTone(String status) => switch (status.trim().toLowerCase()) {
      'approved' => ApprovalsTone.success,
      'pending' => ApprovalsTone.warning,
      'rejected' => ApprovalsTone.error,
      _ => ApprovalsTone.neutral,
    };

IconData otStatusIcon(String status) => switch (status.trim().toLowerCase()) {
      'approved' => Icons.check_circle_outline,
      'pending' => Icons.schedule,
      'rejected' => Icons.cancel_outlined,
      _ => Icons.info_outline,
    };

String otStatusLabel(String status) {
  final s = status.trim();
  if (s.isEmpty) return 'Unknown';
  return s[0].toUpperCase() + s.substring(1);
}

bool _blank(String v) => v.trim().isEmpty || v.trim() == '—';

class OtRecordCard extends StatelessWidget {
  const OtRecordCard({super.key, required this.record});
  final OvertimeRowEntity record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final approver = _blank(r.approvedBy) ? 'Not assigned' : r.approvedBy;
    final amount = r.otAmount.trim().isEmpty ? '—' : '₹ ${r.otAmount}';
    return ApprovalsCardShell(
      name: r.name,
      idText: r.employeeId,
      badge: ApprovalsBadge(otStatusLabel(r.status), otStatusTone(r.status), icon: otStatusIcon(r.status)),
      semanticLabel: 'Overtime ${r.name}, ${formatAttendanceDate(r.date)}, ${r.otHours}, ${otStatusLabel(r.status)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 28,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              _Stat(label: 'Overtime', value: r.otHours.isEmpty ? '—' : r.otHours, big: true, color: AppColors.primary),
              _Stat(label: 'OT Amount', value: amount, color: AppColors.success),
              if (r.otType.isNotEmpty) ApprovalsChip(r.otType, icon: Icons.bolt_outlined),
            ],
          ),
          const SizedBox(height: 12),
          ApprovalsInfoRow(Icons.calendar_today_outlined, formatAttendanceDate(r.date)),
          const SizedBox(height: 8),
          _LabelledLine(
            icon: Icons.verified_user_outlined,
            label: 'Approved By',
            value: approver,
            muted: _blank(r.approvedBy),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.big = false, this.color});
  final String label;
  final String value;
  final bool big;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
          const SizedBox(height: 2),
          Text(value,
              style: (big ? AppTextStyles.h3 : AppTextStyles.body).copyWith(
                  fontWeight: big ? FontWeight.w800 : FontWeight.w700, color: color ?? AppColors.textPrimary)),
        ],
      );
}

class _LabelledLine extends StatelessWidget {
  const _LabelledLine({required this.icon, required this.label, required this.value, this.muted = false});
  final IconData icon;
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                Text(value,
                    style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: muted ? AppColors.textSecondary : AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      );
}

/// One column on phones, two from 600 dp, centred with a max width on big
/// tablets. Used for the OT records and the invalid-punch cards.
class ResponsiveCardColumns extends StatelessWidget {
  const ResponsiveCardColumns({super.key, required this.children, this.maxWidth = 1000});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : maxWidth;
        final width = w > maxWidth ? maxWidth : w;
        final cols = width >= 600 ? 2 : 1;
        const gap = 12.0;
        final item = (width - gap * (cols - 1)) / cols;
        return Center(
          child: SizedBox(
            width: width,
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (final ch in children) SizedBox(width: item, child: ch)],
            ),
          ),
        );
      });
}
