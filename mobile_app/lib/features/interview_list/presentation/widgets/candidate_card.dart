import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/candidate_entity.dart';
import '../providers/interview_providers.dart';
import 'activity_log_dialog.dart';
import 'add_candidate_sheet.dart';
import 'interview_status_badge.dart';
import 'mark_candidate_sheet.dart';

const _kReferredByColor = Color(0xFF7C3AED); // matches web's exact accent color

class CandidateCard extends ConsumerWidget {
  final CandidateEntity candidate;
  const CandidateCard({super.key, required this.candidate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = candidate;
    final initials = c.name.isNotEmpty ? c.name[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.15),
                  child: Text(initials,
                      style: AppTextStyles.label.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: AppTextStyles.label.copyWith(
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(c.email,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (c.referralBy != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_add_alt_outlined,
                                size: 10, color: _kReferredByColor),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                'Referred by ${c.referralByName.isNotEmpty ? c.referralByName : 'Employee'}',
                                style: AppTextStyles.caption.copyWith(
                                    color: _kReferredByColor, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                CandidateStatusBadge(status: c.status),
              ],
            ),
          ),

          // ── Meta row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _MetaChip(
                    icon: Icons.work_outline, label: c.positionApplied),
                if (c.branchName.isNotEmpty)
                  _MetaChip(
                      icon: Icons.location_on_outlined,
                      label: c.branchName),
                if (c.interviewDate.isNotEmpty)
                  _MetaChip(
                      icon: Icons.calendar_today_outlined,
                      label: _fmtDate(c.interviewDate)),
                _MetaChip(
                    icon: Icons.videocam_outlined,
                    label: interviewModeLabel(c.interviewMode)),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.border),

          // ── Actions ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _LogsButton(candidate: c),
                _EditButton(candidate: c),
                const Spacer(),
                _StatusChangeButton(candidate: c),
                const SizedBox(width: 8),
                _PortalActionButton(candidate: c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const m = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${m[dt.month]} ${dt.year}';
  }
}

// ── Meta chip ──────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.textHint),
      const SizedBox(width: 4),
      Text(label,
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textSecondary, fontSize: 11)),
    ]);
  }
}

// ── Logs button ────────────────────────────────────────────────────────────────

class _LogsButton extends StatelessWidget {
  final CandidateEntity candidate;
  const _LogsButton({required this.candidate});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => showDialog(
        context: context,
        builder: (_) => ActivityLogDialog(
          candidateId: candidate.id,
          candidateName: candidate.name,
        ),
      ),
      icon: const Icon(Icons.access_time_outlined, size: 18),
      tooltip: 'Activity Logs',
      color: AppColors.textSecondary,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
    );
  }
}

// ── Edit button ──────────────────────────────────────────────────────────────

class _EditButton extends StatelessWidget {
  final CandidateEntity candidate;
  const _EditButton({required this.candidate});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => showDialog(
        context: context,
        builder: (_) => AddCandidateDialog(existing: candidate),
      ),
      icon: const Icon(Icons.edit_outlined, size: 18),
      tooltip: 'Edit Candidate',
      color: AppColors.textSecondary,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
    );
  }
}

// ── Status change button (3-dot menu) ─────────────────────────────────────────

class _StatusChangeButton extends ConsumerWidget {
  final CandidateEntity candidate;
  const _StatusChangeButton({required this.candidate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (candidate.isConverted) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 18,
          color: AppColors.textSecondary),
      tooltip: 'Change status',
      onSelected: (newStatus) async {
        // Selected/Rejected always route through a confirmation step (remarks
        // + fixed email template), matching web's MarkCandidateModal — every
        // other status is an instant PATCH.
        if (newStatus == 'selected' || newStatus == 'rejected') {
          await MarkCandidateSheet.show(context,
              candidate: candidate, targetStatus: newStatus);
          return;
        }
        final err = await ref
            .read(candidateListProvider.notifier)
            .updateStatus(candidate.id, newStatus);
        if (err != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(err), backgroundColor: AppColors.error));
        }
      },
      itemBuilder: (_) => kChangeableStatuses
          .where((s) => s != candidate.status)
          .map((s) => PopupMenuItem(
                value: s,
                child: Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                          color: candidateStatusColor(s),
                          shape: BoxShape.circle)),
                  Text(candidateStatusLabel(s),
                      style: AppTextStyles.bodySmall),
                ]),
              ))
          .toList(),
    );
  }
}

// ── Portal action button ───────────────────────────────────────────────────────

class _PortalActionButton extends ConsumerWidget {
  final CandidateEntity candidate;
  const _PortalActionButton({required this.candidate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (candidate.isConverted) {
      return _chip('Employee', AppColors.info);
    }
    if (candidate.portalCredentialsSent || candidate.isOfferSent) {
      return _chip('Login Sent', AppColors.textHint);
    }
    if (candidate.canSendLogin) {
      return FilledButton.icon(
        onPressed: () async {
          final err = await ref
              .read(candidateListProvider.notifier)
              .sendLogin(candidate.id);
          if (err != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(err),
                backgroundColor: AppColors.error));
          }
        },
        icon: const Icon(Icons.send_outlined, size: 13),
        label: const Text('Send Login'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11)),
    );
  }
}
