import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../interview_list/presentation/widgets/interview_status_badge.dart';
import '../../domain/entities/referral_entity.dart';

const _kReferredByColor = Color(0xFF7C3AED); // matches web's exact accent color

class ReferralCard extends StatelessWidget {
  final ReferralEntity referral;
  final bool showReferredBy;

  const ReferralCard({
    super.key,
    required this.referral,
    this.showReferredBy = false,
  });

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _fmtCreatedAt {
    final dt = referral.createdAt;
    return '${dt.day} ${_months[dt.month]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final r = referral;
    final initials = r.name.isNotEmpty ? r.name[0].toUpperCase() : '?';

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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    initials,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name,
                        style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        r.email,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CandidateStatusBadge(status: r.status),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _MetaChip(icon: Icons.work_outline, label: r.positionApplied),
                if (r.branchName.isNotEmpty)
                  _MetaChip(icon: Icons.location_on_outlined, label: r.branchName),
                if (showReferredBy && r.referralByName.isNotEmpty)
                  _MetaChip(
                    icon: Icons.person_add_alt_outlined,
                    label: 'Referred by ${r.referralByName}',
                    color: _kReferredByColor,
                  ),
                _MetaChip(icon: Icons.calendar_today_outlined, label: _fmtCreatedAt),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetaChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: c),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
