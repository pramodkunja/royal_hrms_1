import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart';
import '../../../dashboard/data/models/employee_leave_breakdown.dart' show formatLeaveNumber;
import '../../../leave/domain/entities/leave_entity.dart';

// Employee Profile → Leave → Leave Requests, one card per request. Every value
// is a real LeaveRequestSerializer field (GET /leave/requests/?employee_id=&year=&page=);
// labels and status wording follow web's LeaveTab / LeaveRequestDetailModal / _data.ts.

const _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];

DateTime? _date(String? iso) {
  if (iso == null || iso.length < 10) return null;
  return DateTime.tryParse(iso.substring(0, 10));
}

String _d(DateTime d, {bool year = true}) => '${d.day} ${_months[d.month]}${year ? ' ${d.year}' : ''}';

/// "10 Mar – 11 Mar 2026", one date for a single day, years on both ends when they differ.
String formatLeaveRange(String from, String to) {
  final a = _date(from), b = _date(to);
  if (a == null && b == null) return '—';
  if (a == null || b == null) return _d((a ?? b)!);
  if (a == b) return _d(a);
  if (a.year == b.year) return '${_d(a, year: false)} – ${_d(b)}';
  return '${_d(a)} – ${_d(b)}';
}

/// Web: `${total_days} day(s)` (plural unless exactly 1); fractions kept (0.5).
String formatLeaveDays(double days) => '${formatLeaveNumber(days)} ${days == 1 ? 'day' : 'days'}';

/// Web STATUS_LABEL.
String leaveStatusLabel(String s) => switch (s) {
      'pending' => 'Pending Manager Approval',
      'l2_pending' => 'Pending HR Approval',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'cancelled' => 'Cancelled',
      _ => s,
    };

ApprovalsTone leaveStatusTone(String s) => switch (s) {
      'approved' => ApprovalsTone.success,
      'rejected' => ApprovalsTone.error,
      'cancelled' => ApprovalsTone.neutral,
      _ => ApprovalsTone.warning,
    };

bool _bigText(BuildContext c) => MediaQuery.textScalerOf(c).scale(10) / 10 > 1.3;

/// The cards: 1 column on phones, 2 from 600 dp, centred with a max width on large tablets.
class LeaveRequestCardList extends StatelessWidget {
  const LeaveRequestCardList({super.key, required this.requests, required this.onOpen});
  final List<LeaveRequestEntity> requests;
  final ValueChanged<LeaveRequestEntity> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final two = c.maxWidth >= 600;
      Widget card(LeaveRequestEntity r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LeaveRequestCard(request: r, onOpen: () => onOpen(r)),
          );
      final body = two
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: [for (var i = 0; i < requests.length; i += 2) card(requests[i])])),
                const SizedBox(width: 12),
                Expanded(child: Column(children: [for (var i = 1; i < requests.length; i += 2) card(requests[i])])),
              ],
            )
          : Column(children: [for (final r in requests) card(r)]);
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 960), child: body),
      );
    });
  }
}

class LeaveRequestCard extends StatelessWidget {
  const LeaveRequestCard({super.key, required this.request, required this.onOpen});
  final LeaveRequestEntity request;
  final VoidCallback onOpen;

  /// What the detail sheet offers this viewer (its own gating is unchanged).
  String get _openLabel {
    final r = request;
    if (r.canApprove && r.isPending) return 'Review request';
    if (r.canCancel || r.canRequestCancellation) return 'View / cancel';
    return 'View details';
  }

  @override
  Widget build(BuildContext context) {
    final r = request;
    final big = _bigText(context);
    final tone = leaveStatusTone(r.status);
    final accent = approvalsToneColor(tone);
    final days = r.totalDays ?? r.days.toDouble();
    final showL2 = r.l2ApproverName.isNotEmpty;
    final half = r.durationDisplay.isNotEmpty && r.durationDisplay.toLowerCase() != 'full day';
    final applied = _date(r.appliedOn);

    final statusBadge = ApprovalsBadge(leaveStatusLabel(r.status), tone, key: Key('leave-request-status-${r.id}'));
    final title = Text(r.leaveType.isEmpty ? 'Leave' : r.leaveType,
        key: Key('leave-request-type-${r.id}'),
        style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700));

    final dates = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(formatLeaveRange(r.from, r.to),
              key: Key('leave-request-dates-${r.id}'), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
    final duration = Container(
      key: Key('leave-request-days-${r.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
              text: formatLeaveNumber(days),
              style: AppTextStyles.h3.copyWith(color: AppColors.info, fontWeight: FontWeight.w700)),
          TextSpan(
              text: ' ${days == 1 ? 'day' : 'days'}',
              style: AppTextStyles.caption.copyWith(color: AppColors.info, fontWeight: FontWeight.w600)),
        ]),
      ),
    );

    final chips = <Widget>[
      if (half) ApprovalsBadge(r.durationDisplay, ApprovalsTone.info, icon: Icons.timelapse_outlined),
      if (r.hasLopDays)
        ApprovalsBadge('LOP ${formatLeaveNumber(r.lopDays)}d', ApprovalsTone.warning,
            key: Key('leave-request-lop-${r.id}')),
      if (r.cancellationStatus == 'requested')
        ApprovalsBadge('Cancellation requested', ApprovalsTone.neutral, key: Key('leave-request-cancelreq-${r.id}')),
      if ((r.documentUrl ?? '').isNotEmpty)
        const ApprovalsBadge('Document attached', ApprovalsTone.neutral, icon: Icons.attach_file),
      if (r.canApprove && r.isPending)
        ApprovalsBadge('Awaiting your action', ApprovalsTone.warning, key: Key('leave-request-action-${r.id}')),
    ];

    final footerInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(applied == null ? 'Applied —' : 'Applied ${_d(applied)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          r.approvedBy.isNotEmpty
              ? 'Final decision: ${r.approvedBy}${_date(r.approvedAt) == null ? '' : ' · ${_d(_date(r.approvedAt)!)}'}'
              : 'Not yet actioned',
          key: Key('leave-request-final-${r.id}'),
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
    final openButton = TextButton(
      key: Key('leave-request-open-${r.id}'),
      onPressed: onOpen,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(_openLabel,
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );

    return Semantics(
      container: true,
      label:
          '${r.leaveType}, ${leaveStatusLabel(r.status)}, ${formatLeaveRange(r.from, r.to)}, ${formatLeaveDays(days)}',
      child: Container(
        key: Key('leave-request-card-${r.id}'),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 3, color: accent),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (big) ...[
                        title,
                        const SizedBox(height: 6),
                        Align(alignment: Alignment.centerLeft, child: statusBadge),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 8),
                            Flexible(
                                flex: 0,
                                child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 170), child: statusBadge)),
                          ],
                        ),
                      const SizedBox(height: 10),
                      if (big) ...[
                        dates,
                        const SizedBox(height: 8),
                        Align(alignment: Alignment.centerLeft, child: duration),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: dates),
                            const SizedBox(width: 10),
                            duration,
                          ],
                        ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: chips),
                      ],
                      const SizedBox(height: 12),
                      Text('REASON',
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHint,
                              letterSpacing: 0.6)),
                      const SizedBox(height: 2),
                      Text(r.reason.isEmpty ? '—' : r.reason,
                          key: Key('leave-request-reason-${r.id}'), style: AppTextStyles.body.copyWith(height: 1.4)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('APPROVAL FLOW',
                                style: AppTextStyles.caption.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textHint,
                                    letterSpacing: 0.6)),
                            const SizedBox(height: 8),
                            _LevelRow(
                              key: Key('leave-approval-l1-${r.id}'),
                              level: 'Manager Approval',
                              approver: r.l1ApproverName,
                              status: r.l1Status,
                              remarks: r.l1Remarks,
                              at: r.l1ActionedAt,
                            ),
                            if (showL2) ...[
                              const SizedBox(height: 10),
                              _LevelRow(
                                key: Key('leave-approval-l2-${r.id}'),
                                level: 'HR Approval',
                                approver: r.l2ApproverName,
                                status: r.l2Status,
                                remarks: r.l2Remarks,
                                at: r.l2ActionedAt,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 14, thickness: 1, color: AppColors.border, indent: 14, endIndent: 14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 6, 8),
                  child: big
                      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          footerInfo,
                          Align(alignment: Alignment.centerRight, child: openButton),
                        ])
                      : Row(children: [Expanded(child: footerInfo), openButton]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One approval level (web DecisionRow): dot, level, decision, approver, remarks, date.
class _LevelRow extends StatelessWidget {
  const _LevelRow({super.key, required this.level, required this.approver, this.status, this.remarks, this.at});
  final String level;
  final String approver;
  final String? status;
  final String? remarks;
  final String? at;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      'approved' => ApprovalsTone.success,
      'rejected' => ApprovalsTone.error,
      _ => ApprovalsTone.warning,
    };
    final c = approvalsToneColor(tone);
    final label = switch (status) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      null || '' || 'pending' => 'Pending',
      final s => s,
    };
    final when = _date(at);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(level, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
                  Text(label,
                      key: Key('${(key as ValueKey<String>).value}-status'),
                      style: AppTextStyles.caption.copyWith(color: c, fontWeight: FontWeight.w700)),
                ],
              ),
              Text(approver.isEmpty ? 'Not yet assigned' : approver,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              if ((remarks ?? '').isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
                  child: Text('“$remarks”', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ),
              if (when != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(_d(when), style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
