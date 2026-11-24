import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart' show ApprovalsChip;
import '../../../approvals/presentation/widgets/approvals_ui.dart';
import '../../domain/entities/attendance_entity.dart';
import 'late_justification.dart' show fmtLateDate, lateStatusBadge;

// One late-arrival justification in the HR / manager queue, organised into the
// data the server actually sends (services_hr_corrections._build_row +
// _late_fields): who, which day and clock-in, the reason and the employee's
// words, proof, the two approval levels (L1 manager, L2 HR) with their
// remarks, and the action the server allows (can_action). Nothing is derived
// client-side: no lateness or shift rule, only what each field says.

ApprovalsTone lateStatusTone(String status) => switch (status) {
      'pending' || 'l2_pending' => ApprovalsTone.warning,
      'approved' => ApprovalsTone.success,
      'rejected' => ApprovalsTone.error,
      'resubmit' => ApprovalsTone.info,
      _ => ApprovalsTone.neutral,
    };

/// "2026-11-10 11:00" (server local time) → "10 Nov 2026, 11:00"; anything else as sent.
String lateSubmittedLabel(String createdAt) {
  final parts = createdAt.trim().split(' ');
  if (parts.isEmpty || parts.first.isEmpty) return '';
  final date = fmtLateDate(parts.first);
  return parts.length > 1 && parts[1].isNotEmpty ? '$date, ${parts[1]}' : date;
}

/// One approval level as the card shows it.
class LateApprovalStep {
  const LateApprovalStep(this.level, this.approver, this.label, this.tone, this.icon, this.remarks);
  final String level; // 'Manager (L1)' | 'HR (L2)'
  final String approver;
  final String label;
  final ApprovalsTone tone;
  final IconData icon;
  final String remarks;
}

/// The L1 / L2 steps the row's own fields support. A level with neither an
/// approver nor a decision is not shown; the level the request currently sits at
/// reads "Awaiting decision" (status pending → manager, l2_pending → HR).
List<LateApprovalStep> lateApprovalSteps(HrCorrectionRowEntity r) {
  LateApprovalStep? step(String level, String? name, String? st, String remarks, bool current) {
    final who = name ?? '';
    final decided = st != null && st.isNotEmpty;
    if (!decided && who.isEmpty && !current) return null;
    final (label, tone, icon) = switch (st) {
      'approved' => ('Approved', ApprovalsTone.success, Icons.check_circle),
      'rejected' => ('Rejected', ApprovalsTone.error, Icons.cancel),
      'resubmit' => ('Asked to resubmit', ApprovalsTone.info, Icons.undo),
      _ => current
          ? ('Awaiting decision', ApprovalsTone.warning, Icons.hourglass_top)
          : ('Not reached', ApprovalsTone.neutral, Icons.radio_button_unchecked),
    };
    return LateApprovalStep(level, who, label, tone, icon, remarks);
  }

  final l1 = step('Manager (L1)', r.l1ApproverName, r.l1Status, r.l1Remarks, r.status == 'pending');
  final l2 = step('HR (L2)', r.l2ApproverName, r.l2Status, r.l2Remarks, r.status == 'l2_pending');
  return [if (l1 != null) l1, if (l2 != null) l2];
}

class LateJustificationCard extends StatelessWidget {
  const LateJustificationCard({super.key, required this.row, required this.onOpen});
  final HrCorrectionRowEntity row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final badge = lateStatusBadge(r.status);
    final tone = lateStatusTone(r.status);
    final reason = r.reasonLabel.isEmpty ? r.reason : r.reasonLabel;
    final steps = lateApprovalSteps(r);
    final submitted = lateSubmittedLabel(r.createdAt);
    final (proofText, proofColor, proofIcon) = r.hasDocument
        ? (
            r.canViewDocument ? 'Attached' : 'Attached (locked)',
            AppColors.textSecondary,
            r.canViewDocument ? Icons.attach_file : Icons.lock_outline
          )
        : r.proofRequired
            ? ('Missing', AppColors.error, Icons.error_outline)
            : ('None', AppColors.textSecondary, Icons.attach_file);

    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 340 || scale > 1.3;
      final statusBadge = ApprovalsBadge(badge.$1, tone, key: Key('late-card-status-${r.id}'));
      final who = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r.name.isEmpty ? 'Unknown' : r.name,
            style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('${r.employeeId} · ${r.branch.isEmpty ? '—' : r.branch}',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        if (narrow) ...[const SizedBox(height: 6), statusBadge],
      ]);
      return Semantics(
        container: true,
        label: '${r.name}, ${fmtLateDate(r.date)}, ${badge.$1}',
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Status accent: a 3 dp rule in the status colour.
            Container(height: 3, color: approvalsToneColor(tone).withValues(alpha: 0.7)),
            InkWell(
              key: Key('late-review-row-${r.id}'),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ApprovalsAvatar(r.name, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(child: who),
                    if (!narrow) ...[const SizedBox(width: 8), statusBadge],
                  ]),
                  const SizedBox(height: 12),
                  // Day + clock-in (as recorded) + reason category.
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    ApprovalsChip(fmtLateDate(r.date, withWeekday: true), icon: Icons.event_outlined),
                    ApprovalsChip('Clock-in ${r.originalIn ?? '—'}', icon: Icons.login),
                    if (reason.isNotEmpty) ApprovalsChip(reason, icon: Icons.label_outline),
                    if (r.resubmissionCount > 0)
                      ApprovalsChip('Resubmitted ×${r.resubmissionCount}',
                          tone: ApprovalsTone.info, icon: Icons.replay),
                  ]),
                  if (r.explanation.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('JUSTIFICATION',
                        style: AppTextStyles.caption.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.textHint)),
                    const SizedBox(height: 4),
                    Container(
                      key: Key('late-card-explanation-${r.id}'),
                      padding: const EdgeInsets.only(left: 10),
                      decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: AppColors.primary.withValues(alpha: 0.25), width: 3))),
                      child: Text(r.explanation,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.45)),
                    ),
                  ],
                  if (steps.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('APPROVAL',
                        style: AppTextStyles.caption.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.textHint)),
                    const SizedBox(height: 6),
                    for (final s in steps)
                      _StepRow(s, key: Key('late-card-step-${r.id}-${s.level.startsWith('M') ? 'l1' : 'l2'}')),
                  ],
                  if (submitted.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Submitted $submitted', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                  ],
                ]),
              ),
            ),
            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 6,
                spacing: 12,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(proofIcon, size: 14, color: proofColor),
                    const SizedBox(width: 4),
                    Flexible(
                        child: Text('Proof: $proofText',
                            style: AppTextStyles.caption.copyWith(fontSize: 12, color: proofColor))),
                  ]),
                  r.canAction
                      ? FilledButton(
                          key: Key('late-review-open-${r.id}'),
                          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
                          onPressed: onOpen,
                          child: const Text('Review'),
                        )
                      : OutlinedButton(
                          key: Key('late-review-open-${r.id}'),
                          style: approvalsOutlinedButtonStyle()
                              .copyWith(minimumSize: const WidgetStatePropertyAll(Size(96, 44))),
                          onPressed: onOpen,
                          child: const Text('View'),
                        ),
                ],
              ),
            ),
          ]),
        ),
      );
    });
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.s, {super.key});
  final LateApprovalStep s;

  @override
  Widget build(BuildContext context) {
    final color = approvalsToneColor(s.tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(s.icon, size: 16, color: color)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(s.approver.isEmpty ? s.level : '${s.level} · ${s.approver}',
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(s.label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: color)),
            ]),
            if (s.remarks.isNotEmpty)
              Text('“${s.remarks}”',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
          ]),
        ),
      ]),
    );
  }
}
