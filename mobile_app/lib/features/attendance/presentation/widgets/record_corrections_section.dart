import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/attendance_entity.dart';
import '../providers/attendance_providers.dart';
import 'late_justification.dart' show lateStatusBadge;
import 'late_justification_review.dart' show showLateJustificationReview;

const _kPunchTypeLabel = {'IN': 'Clock In', 'OUT': 'Clock Out', 'BOTH': 'Both IN & OUT'};

Color _statusColor(String s) => switch (s) {
      'pending' => AppColors.warning,
      'l2_pending' => AppColors.info,
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      _ => AppColors.textSecondary,
    };

/// "Correction Requests" in the HR attendance record detail — web
/// AttendanceDetailDrawer. Lists the employee's corrections for the day;
/// a `pending` one gets Approve / Reject for attendance.create holders
/// (PATCH /attendance/corrections/<id>/review/ {action}, no remarks, no
/// confirmation — as web). Other rows show who reviewed them.
class RecordCorrectionsSection extends ConsumerStatefulWidget {
  const RecordCorrectionsSection({
    super.key,
    required this.employeeId,
    required this.date,
    this.detailKey,
    this.recordId,
  });

  final String employeeId;
  final String date;

  /// Reloaded after a successful review (an approval re-runs the record).
  final RecordDetailKey? detailKey;
  final String? recordId;

  @override
  ConsumerState<RecordCorrectionsSection> createState() => _RecordCorrectionsSectionState();
}

class _RecordCorrectionsSectionState extends ConsumerState<RecordCorrectionsSection> {
  String? _reviewingId;
  ({String text, bool ok})? _result;

  EmployeeDateKey get _key => (employeeId: widget.employeeId, date: widget.date);

  Future<void> _review(String correctionId, bool approve) async {
    if (_reviewingId != null) return;
    setState(() {
      _reviewingId = correctionId;
      _result = null;
    });
    try {
      final message = await ref.read(attendanceCorrectionReviewProvider).review(
            correctionId,
            approve: approve,
            correctionsKey: _key,
            detailKey: widget.detailKey,
            recordId: widget.recordId,
          );
      if (!mounted) return;
      setState(() => _result = (text: message, ok: true));
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = (text: e is String ? e : friendlyAttendanceError(e), ok: false));
    } finally {
      if (mounted) setState(() => _reviewingId = null);
    }
  }

  /// Late-arrival justifications share this queue but aren't punch
  /// corrections: they're decided in the review sheet (with remarks and the
  /// two-level chain), never with the punch Approve / Reject.
  Future<void> _openLate(HrCorrectionRowEntity c) async {
    if (_reviewingId != null) return;
    setState(() => _result = null);
    final msg = await showLateJustificationReview(context, c);
    if (msg == null || !mounted) return;
    if (widget.detailKey != null) ref.invalidate(attendanceRecordDetailProvider(widget.detailKey!));
    if (widget.recordId != null) ref.invalidate(attendanceRecordAuditProvider(widget.recordId!));
    setState(() => _result = (text: msg, ok: true));
  }

  Widget _lateRow(HrCorrectionRowEntity c) {
    final badge = lateStatusBadge(c.status);
    return Container(
      key: Key('record-correction-${c.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Late Arrival Justification',
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          ),
          Text(badge.$1,
              key: Key('record-correction-status-${c.id}'),
              style: AppTextStyles.labelSmall.copyWith(color: badge.$2, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Text('Clocked in ${c.originalIn ?? '—'} · ${c.reasonLabel.isEmpty ? c.reason : c.reasonLabel}',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: Key('record-correction-late-open-${c.id}'),
            onPressed: _reviewingId != null ? null : () => _openLate(c),
            child: Text(c.canAction ? 'Review' : 'View'),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final correctionsAsync = ref.watch(attendanceRecordCorrectionsProvider(_key));
    final result = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result != null) ...[
          Text(result.text,
              key: const Key('record-correction-review-message'),
              style: AppTextStyles.labelSmall.copyWith(color: result.ok ? AppColors.success : AppColors.error)),
          const SizedBox(height: 6),
        ],
        correctionsAsync.when(
          data: (rows) => rows.isEmpty
              ? Text('No correction requests for this day.',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in rows)
                      c.isLateJustification ? _lateRow(c) : _row(c, canReviewRecordCorrection(user, c)),
                  ],
                ),
          loading: () => const SizedBox(height: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (e, _) => Text(friendlyAttendanceError(e),
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error)),
        ),
      ],
    );
  }

  Widget _row(HrCorrectionRowEntity c, bool canReview) {
    final busy = _reviewingId == c.id;
    final locked = _reviewingId != null;
    final reviewed = (c.reviewedBy?.isNotEmpty ?? false) || (c.reviewedAt?.isNotEmpty ?? false);
    return Container(
      key: Key('record-correction-${c.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(_kPunchTypeLabel[c.punchType] ?? c.punchType,
                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            ),
            Text(c.status,
                key: Key('record-correction-status-${c.id}'),
                style: AppTextStyles.labelSmall
                    .copyWith(color: _statusColor(c.status), fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text('Requested In: ${c.requestedInTime ?? '—'} · Requested Out: ${c.requestedOutTime ?? '—'}',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
          if (c.reason.isNotEmpty)
            Text(c.reason, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
          if (canReview)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                OutlinedButton.icon(
                  key: Key('record-correction-approve-${c.id}'),
                  onPressed: locked ? null : () => _review(c.id, true),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.success),
                  icon: busy
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check, size: 14),
                  label: const Text('Approve'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: Key('record-correction-reject-${c.id}'),
                  onPressed: locked ? null : () => _review(c.id, false),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Reject'),
                ),
              ]),
            )
          else if (reviewed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Reviewed by ${(c.reviewedBy?.isNotEmpty ?? false) ? c.reviewedBy : '—'}'
                '${(c.reviewedAt?.isNotEmpty ?? false) ? ' on ${c.reviewedAt}' : ''}',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
