import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart';
import '../../data/models/shift_master_models.dart';
import 'shift_format.dart';

/// Section heading with a one-line explanation, used to separate the shift
/// configuration (masters) from the employee shift assignment.
class ShiftSectionHeader extends StatelessWidget {
  const ShiftSectionHeader({super.key, required this.icon, required this.title, required this.subtitle, this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final head = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ApprovalsIconBox(icon),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            header: true,
            child: Text(title, style: AppTextStyles.label.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        ]),
      ),
    ]);
    if (trailing == null) return head;
    return LayoutBuilder(builder: (context, c) {
      final stack = c.maxWidth < 420 || scale > 1.3;
      if (stack) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          head,
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: trailing!),
        ]);
      }
      return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: head), const SizedBox(width: 12), trailing!]);
    });
  }
}

/// One labelled fact ("Break" / "45 min").
class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
      ]);
}

/// A readable card for one shift master: name and status, start - end (with an
/// overnight indicator only when the end is before the start), the shift
/// length and working time, break, grace period, and labelled actions.
class ShiftMasterTile extends StatelessWidget {
  const ShiftMasterTile({
    super.key,
    required this.shift,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDeactivate,
  });

  final ShiftMaster shift;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final s = shift;
    final id = s.id;
    final start = toHHMM(s.startTime), end = toHHMM(s.endTime);
    final overnight = isOvernightShift(start, end);
    final length = shiftLengthMinutes(start, end);
    final net = shiftNetMinutes(start, end, s.breakDuration);
    final fine = AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary);
    return Container(
      key: Key('shift-master-$id'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(s.name, style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (s.isDefault)
            ApprovalsChip('Default',
                key: Key('shift-master-default-$id'), icon: Icons.star_outline, tone: ApprovalsTone.info),
          ApprovalsChip(s.isActive ? 'Active' : 'Inactive',
              key: Key('shift-master-status-$id'), tone: s.isActive ? ApprovalsTone.success : ApprovalsTone.neutral),
          if (overnight)
            ApprovalsChip('Overnight · ends next day',
                key: Key('shift-master-overnight-$id'), icon: Icons.nights_stay_outlined, tone: ApprovalsTone.warning),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.schedule_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text('$start – $end',
                key: Key('shift-master-time-$id'),
                style: AppTextStyles.h4.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 22, runSpacing: 10, children: [
          if (length != null) _Fact('Shift length', formatShiftDuration(length), key: Key('shift-master-length-$id')),
          if (net != null) _Fact('Working time', formatShiftDuration(net), key: Key('shift-master-net-$id')),
          _Fact('Break', '${s.breakDuration} min', key: Key('shift-master-break-$id')),
          _Fact('Grace period', '${s.gracePeriod} min', key: Key('shift-master-grace-$id')),
        ]),
        if (s.minimumWorkingHours.isNotEmpty || s.maximumWorkingHours.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            [
              if (s.minimumWorkingHours.isNotEmpty) 'Present from ${s.minimumWorkingHours} h',
              if (s.maximumWorkingHours.isNotEmpty) 'Overtime after ${s.maximumWorkingHours} h',
            ].join(' · '),
            style: fine,
          ),
        ],
        if (canEdit || canDelete) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (canEdit)
              OutlinedButton.icon(
                key: Key('shift-master-edit-$id'),
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            if (canDelete)
              Tooltip(
                message: s.isDefault ? 'Assign another shift as default before removing this one.' : 'Deactivate',
                child: OutlinedButton.icon(
                  key: Key('shift-master-delete-$id'),
                  onPressed: s.isDefault ? null : onDeactivate,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: AppColors.error,
                    side: s.isDefault ? null : BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Deactivate'),
                ),
              ),
          ]),
          if (canDelete && s.isDefault) ...[
            const SizedBox(height: 6),
            Text('The default shift can’t be deactivated. Make another shift the default first.',
                key: Key('shift-master-default-note-$id'), style: fine),
          ],
        ],
      ]),
    );
  }
}
