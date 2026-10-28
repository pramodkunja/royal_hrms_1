import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../attendance/domain/entities/attendance_entity.dart';

/// Opens the Attendance Correction detail sheet from My Requests. There is
/// no reusable detail widget for an employee's own correction elsewhere in
/// the app (hr_correction_card.dart is the HR/manager review-inbox row, a
/// different entity), so this renders straight from the already-loaded
/// [correction] — mirrors web's MyCorrectionDetailModal, which also doesn't
/// re-fetch. No cancel action: the backend has no withdraw endpoint for
/// attendance corrections.
Future<void> showMyCorrectionDetailSheet(BuildContext context, MyCorrectionEntity correction) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MyCorrectionDetailSheet(correction: correction),
  );
}

Color _statusColor(String s) => switch (s) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      _ => AppColors.warning,
    };

String _statusLabel(String s) => switch (s) {
      'pending' => 'Pending (Manager)',
      'l2_pending' => 'Pending (HR)',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => s,
    };

class MyCorrectionDetailSheet extends StatelessWidget {
  final MyCorrectionEntity correction;
  const MyCorrectionDetailSheet({super.key, required this.correction});

  @override
  Widget build(BuildContext context) {
    final c = correction;
    final sc = _statusColor(c.status);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.edit_calendar_outlined, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Attendance Correction', style: AppTextStyles.h4.copyWith(fontSize: 15)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Field(label: 'Date', value: c.date)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: sc.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sc.withValues(alpha: 0.3)),
                            ),
                            child: Text(_statusLabel(c.status),
                                style: AppTextStyles.caption
                                    .copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: sc)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _Field(label: 'Punch Type', value: c.punchType)),
                          Expanded(child: _Field(label: 'Original In', value: c.originalInTime ?? '—')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _Field(label: 'Requested In', value: c.requestedInTime ?? '—')),
                          Expanded(child: _Field(label: 'Requested Out', value: c.requestedOutTime ?? '—')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),
                      _Field(label: 'Reason', value: c.reason),
                      if (c.notes != null && c.notes!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _Field(label: 'Notes', value: c.notes!),
                      ],
                      const SizedBox(height: 14),
                      Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),
                      Text('APPROVAL FLOW',
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      const SizedBox(height: 10),
                      _StageRow(
                        level: 'Manager',
                        approverName: c.l1ApproverName,
                        status: c.l1Status,
                        remarks: c.l1Remarks,
                      ),
                      if (c.l2Status != null) ...[
                        const SizedBox(height: 10),
                        _StageRow(
                          level: 'HR',
                          approverName: c.l2ApproverName,
                          status: c.l2Status,
                          remarks: c.l2Remarks,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(
                  height: MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom
                      : 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: AppTextStyles.caption
                .copyWith(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 3),
        Text(value.isNotEmpty ? value : '—', style: AppTextStyles.body.copyWith(fontSize: 13)),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  final String level;
  final String? approverName;
  final String? status;
  final String remarks;
  const _StageRow({
    required this.level,
    required this.approverName,
    required this.status,
    required this.remarks,
  });

  @override
  Widget build(BuildContext context) {
    final color = status == 'approved'
        ? AppColors.success
        : status == 'rejected'
            ? AppColors.error
            : AppColors.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$level Approval',
                  style: AppTextStyles.label.copyWith(fontSize: 12)),
              Text(
                  (approverName?.isNotEmpty ?? false) ? approverName! : 'Not yet assigned',
                  style: AppTextStyles.caption.copyWith(fontSize: 11)),
              if (remarks.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('"$remarks"',
                      style: AppTextStyles.caption
                          .copyWith(fontSize: 11, color: AppColors.textSecondary)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
