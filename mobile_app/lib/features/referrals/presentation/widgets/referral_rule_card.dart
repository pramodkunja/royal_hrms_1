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

// ── Static "Referral Bonus Breakdown" panel — matches web verbatim, purely
// informational, not tied to any real candidate/bonus record (see backend
// research: web hardcodes this, no live data source exists for it).

class ReferralBonusBreakdownPanel extends StatelessWidget {
  const ReferralBonusBreakdownPanel({super.key});

  static const _stages = [
    (stage: 'Referral Accepted', bonus: '—', note: 'Candidate enters the hiring pipeline'),
    (stage: 'Candidate Selected', bonus: '—', note: 'No payout at the offer stage'),
    (stage: '90-Day Milestone', bonus: '₹10,000', note: 'Full bonus in next payroll cycle'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: AppColors.primary,
            child: Row(
              children: [
                const Icon(Icons.emoji_events_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Referral Bonus Breakdown',
                  style: AppTextStyles.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            // IntrinsicHeight + stretch so all three boxes share the height
            // of the tallest one, regardless of how many lines each note
            // wraps to — otherwise each Column sizes to its own content and
            // the three end up visibly different heights.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _stages.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _BreakdownStageBox(stage: _stages[i])),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownStageBox extends StatelessWidget {
  final ({String stage, String bonus, String note}) stage;

  const _BreakdownStageBox({required this.stage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            stage.stage.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textHint,
              fontWeight: FontWeight.w600,
              fontSize: 9,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stage.bonus,
            textAlign: TextAlign.center,
            style: AppTextStyles.h4.copyWith(
              color: stage.bonus == '—' ? AppColors.textSecondary : AppColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stage.note,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
