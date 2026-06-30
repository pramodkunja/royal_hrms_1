import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Status display helpers ─────────────────────────────────────────────────────

const _kStatusLabels = {
  'pending':              'Pending',
  'screening':            'Screening',
  'interview_scheduled':  'Scheduled',
  'interview_done':       'Done',
  'selected':             'Selected',
  'offer_sent':           'Offer Sent',
  'converted':            'Converted',
  'rejected':             'Rejected',
};

Color candidateStatusColor(String status) {
  switch (status) {
    case 'pending':             return AppColors.warning;
    case 'screening':           return const Color(0xFF7B61FF);
    case 'interview_scheduled': return AppColors.info;
    case 'interview_done':      return const Color(0xFF0E7C86);
    case 'selected':            return AppColors.success;
    case 'offer_sent':          return const Color(0xFF2E7D32);
    case 'converted':           return const Color(0xFF0E7C86);
    case 'rejected':            return AppColors.error;
    default:                    return AppColors.textHint;
  }
}

String candidateStatusLabel(String status) =>
    _kStatusLabels[status] ?? status;

String interviewModeLabel(String mode) {
  switch (mode) {
    case 'in_person':   return 'In-Person';
    case 'phone':       return 'Phone';
    case 'video_call':  return 'Video Call';
    default:            return mode;
  }
}

// ── Status badge widget ────────────────────────────────────────────────────────

class CandidateStatusBadge extends StatelessWidget {
  final String status;
  const CandidateStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = candidateStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        candidateStatusLabel(status),
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ── Statuses available for manual update ──────────────────────────────────────

const kChangeableStatuses = [
  'pending',
  'screening',
  'interview_scheduled',
  'interview_done',
  'selected',
  'rejected',
];
