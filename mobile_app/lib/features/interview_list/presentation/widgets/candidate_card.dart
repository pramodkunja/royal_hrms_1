import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/candidate_entity.dart';
import '../providers/interview_providers.dart';
import 'activity_log_dialog.dart';
import 'interview_status_badge.dart';

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
                              fontWeight: FontWeight.w700)),
                      Text(c.email,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
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
          const Divider(height: 1, color: AppColors.border),

          // ── Actions ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _LogsButton(candidate: c),
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
    return TextButton.icon(
      onPressed: () => showDialog(
        context: context,
        builder: (_) => ActivityLogDialog(
          candidateId: candidate.id,
          candidateName: candidate.name,
        ),
      ),
      icon: const Icon(Icons.access_time_outlined, size: 14),
      label: const Text('Logs'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        textStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
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
      icon: const Icon(Icons.more_vert, size: 18,
          color: AppColors.textSecondary),
      tooltip: 'Change status',
      onSelected: (newStatus) async {
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
