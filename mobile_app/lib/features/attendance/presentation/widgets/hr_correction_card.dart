import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/attendance_entity.dart';

// Shared between the Attendance screen's own "Correction Requests" inbox and
// the Approvals screen's "Team Approvals" > Attendance Correction type — both
// list the same HrCorrectionRowEntity rows via slightly different providers,
// so this takes a plain onReview callback instead of reading a provider
// directly.

Color _statusColor(String s) => switch (s.toLowerCase()) {
      'approved' => AppColors.success,
      'pending' => AppColors.warning,
      'l2_pending' => AppColors.info,
      'rejected' => AppColors.error,
      _ => AppColors.textSecondary,
    };

String _statusLabel(String s) => switch (s.toLowerCase()) {
      'pending' => 'Pending (Manager)',
      'l2_pending' => 'Pending (HR)',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => s,
    };

String _initials(String name) {
  final p = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
  if (p.length >= 2) return '${p.first[0]}${p.last[0]}'.toUpperCase();
  return p.isNotEmpty && p.first.isNotEmpty ? p.first[0].toUpperCase() : '?';
}

class HrCorrectionCard extends StatefulWidget {
  final HrCorrectionRowEntity record;
  final Future<String?> Function(bool approve) onReview;
  const HrCorrectionCard(
      {super.key, required this.record, required this.onReview});

  @override
  State<HrCorrectionCard> createState() => _HrCorrectionCardState();
}

class _HrCorrectionCardState extends State<HrCorrectionCard> {
  bool _reviewing = false;

  Future<void> _review(bool approve) async {
    setState(() => _reviewing = true);
    final error = await widget.onReview(approve);
    if (!mounted) return;
    setState(() => _reviewing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            error ?? (approve ? 'Correction approved.' : 'Correction rejected.')),
        backgroundColor: error != null ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final showAwaiting = !record.canAction &&
        (record.status == 'pending' || record.status == 'l2_pending');
    final showFlow = record.l1Status != null || record.l2Status != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(_initials(record.name),
                      style: AppTextStyles.label.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.name,
                          style: AppTextStyles.label
                              .copyWith(fontWeight: FontWeight.w600)),
                      Text('${record.employeeId} · ${record.department}',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(record.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel(record.status),
                      style: AppTextStyles.labelSmall.copyWith(
                          color: _statusColor(record.status),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _KV(k: 'Date', v: record.date)),
              Expanded(child: _KV(k: 'Punch Type', v: record.punchType)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _KV(
                      k: 'Requested In', v: record.requestedInTime ?? '—')),
              Expanded(
                  child: _KV(
                      k: 'Requested Out', v: record.requestedOutTime ?? '—')),
            ]),
            const SizedBox(height: 8),
            _KV(k: 'Reason', v: record.reason),

            if (showAwaiting) ...[
              const SizedBox(height: 8),
              Text(
                record.status == 'pending'
                    ? ((record.l1ApproverName?.isNotEmpty ?? false)
                        ? 'Awaiting ${record.l1ApproverName}'
                        : 'Awaiting manager')
                    : ((record.l2ApproverName?.isNotEmpty ?? false)
                        ? 'Awaiting ${record.l2ApproverName}'
                        : 'Awaiting HR'),
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textHint, fontSize: 11),
              ),
            ],

            if (showFlow) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              if (record.l1Status != null)
                StageLine(
                  level: 'Manager',
                  approverName: record.l1ApproverName,
                  status: record.l1Status,
                  remarks: record.l1Remarks,
                ),
              if (record.l2Status != null) ...[
                const SizedBox(height: 6),
                StageLine(
                  level: 'HR',
                  approverName: record.l2ApproverName,
                  status: record.l2Status,
                  remarks: record.l2Remarks,
                ),
              ],
            ],

            if (record.canAction) ...[
              const SizedBox(height: 10),
              if (_reviewing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                )
              else
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _review(false),
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _review(true),
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String k;
  final String v;
  const _KV({required this.k, required this.v});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textHint, fontSize: 10)),
          const SizedBox(height: 2),
          Text(v,
              style: AppTextStyles.label
                  .copyWith(fontWeight: FontWeight.w500, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      );
}

class StageLine extends StatelessWidget {
  final String level;
  final String? approverName;
  final String? status;
  final String remarks;
  const StageLine({
    super.key,
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
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$level: ${(approverName?.isNotEmpty ?? false) ? approverName : "Not yet assigned"} — ${status ?? "pending"}',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
              if (remarks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('"$remarks"',
                      style: AppTextStyles.caption.copyWith(
                          fontSize: 10, color: AppColors.textSecondary)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
