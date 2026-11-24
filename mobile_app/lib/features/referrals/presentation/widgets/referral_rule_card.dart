import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/referral_entity.dart';

// Mirrors the 14 ICON_OPTIONS values from
// frontend/app/dashboard/settings/referral-rules/page.tsx.
const _kIconMap = <String, IconData>{
  'ti-users': Icons.groups_outlined,
  'ti-currency-rupee': Icons.currency_rupee,
  'ti-user-cancel': Icons.person_off_outlined,
  'ti-calendar-off': Icons.event_busy_outlined,
  'ti-list-numbers': Icons.format_list_numbered,
  'ti-receipt-tax': Icons.receipt_long_outlined,
  'ti-shield-check': Icons.verified_user_outlined,
  'ti-award': Icons.emoji_events_outlined,
  'ti-gift': Icons.card_giftcard_outlined,
  'ti-info-circle': Icons.info_outline,
  'ti-clock': Icons.access_time_outlined,
  'ti-building': Icons.business_outlined,
  'ti-star': Icons.star_outline,
  'ti-check': Icons.check_circle_outline,
};

IconData referralRuleIcon(String tablerIconName) =>
    _kIconMap[tablerIconName] ?? Icons.info_outline;

// Same 14 options, with the exact labels from web's ICON_OPTIONS
// (frontend/app/dashboard/settings/referral-rules/page.tsx) — used by the
// admin add/edit form's icon picker dropdown.
const kReferralRuleIconOptions = <(String key, String label)>[
  ('ti-users', 'Users'),
  ('ti-currency-rupee', 'Currency / Bonus'),
  ('ti-user-cancel', 'User Restriction'),
  ('ti-calendar-off', 'Calendar / Dates'),
  ('ti-list-numbers', 'Numbered List'),
  ('ti-receipt-tax', 'Tax / Receipt'),
  ('ti-shield-check', 'Shield / Security'),
  ('ti-award', 'Award / Achievement'),
  ('ti-gift', 'Gift / Reward'),
  ('ti-info-circle', 'Information'),
  ('ti-clock', 'Time / Duration'),
  ('ti-building', 'Company / Branch'),
  ('ti-star', 'Star'),
  ('ti-check', 'Check / Tick'),
];

class ReferralRuleCard extends StatelessWidget {
  final ReferralRuleEntity rule;
  final int displayIndex;

  const ReferralRuleCard({super.key, required this.rule, required this.displayIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(referralRuleIcon(rule.icon), color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RULE $displayIndex',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rule.title,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  rule.body,
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
