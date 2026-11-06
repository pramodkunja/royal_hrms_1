import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

// Leave Policy → Monthly Credit Settings for the selected leave type — web
// app/dashboard/settings/leave-policy/_components/MonthlyCreditSettingsSection.tsx.
// Credit Schedule (Annual / Monthly); Monthly Carry Forward only for Monthly;
// the server sets monthly_rules_from to the 1st of next month whenever either
// changes, and earlier months are never recalculated. Saved with the rest of
// the policy (PUT /leave/policy/<type>/).

const _schedules = [
  (value: 'annual', title: 'Annual', subtitle: 'Annual entitlement is credited for the year (current behaviour).'),
  (
    value: 'monthly',
    title: 'Monthly',
    subtitle: 'Credits are recorded month by month through Monthly Leave Management.'
  ),
];

/// en-IN short months (web toLocaleDateString("en-IN")): September is "Sept".
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];

/// Web formatDate(iso): "1 Dec 2026"; null when unreadable.
String? formatRulesFrom(String? iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso ?? '');
  if (m == null) return null;
  final d = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

class MonthlyCreditSettingsSection extends StatelessWidget {
  const MonthlyCreditSettingsSection({
    super.key,
    required this.creditSchedule,
    required this.monthlyCarryForward,
    required this.rulesFrom,
    required this.onScheduleChanged,
    required this.onCarryForwardChanged,
    this.enabled = true,
  });

  final String creditSchedule;
  final bool monthlyCarryForward;
  final String? rulesFrom;
  final ValueChanged<String> onScheduleChanged;
  final ValueChanged<bool> onCarryForwardChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final muted = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary, height: 1.5);
    final from = formatRulesFrom(rulesFrom);
    return Column(
      key: const Key('monthly-credit-settings'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Credit Schedule', style: AppTextStyles.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final s in _schedules) ...[
          _ScheduleOption(
            key: Key('credit-schedule-${s.value}'),
            title: s.title,
            subtitle: s.subtitle,
            selected: creditSchedule == s.value,
            onTap: enabled ? () => onScheduleChanged(s.value) : null,
          ),
          const SizedBox(height: 8),
        ],
        if (creditSchedule == 'monthly')
          SwitchListTile(
            key: const Key('monthly-carry-forward'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('Monthly Carry Forward (unused monthly credit rolls into the next month)',
                style: AppTextStyles.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
            value: monthlyCarryForward,
            activeTrackColor: AppColors.success,
            onChanged: enabled ? onCarryForwardChanged : null,
          ),
        const SizedBox(height: 4),
        Text(
          'Monthly leave types get no annual credit (Credit Rules, new joiners, yearly reset); credits are entered '
          "or imported in Monthly Leave Management, and leave is checked against each month's own credit.",
          style: muted,
        ),
        Text(
          "With Monthly Carry Forward off, the unused part of a month's credit expires at month end. Opening "
          'balances, carried-forward days and manual adjustments never expire, and leave that was pending when the '
          'month closed is protected.',
          style: muted,
        ),
        Text(
          'Changes take effect from the 1st of next month; earlier months and existing balances are not '
          'recalculated.${from != null ? ' Current rules apply from $from.' : ''}',
          key: const Key('monthly-rules-from'),
          style: muted,
        ),
      ],
    );
  }
}

class _ScheduleOption extends StatelessWidget {
  const _ScheduleOption(
      {super.key, required this.title, required this.subtitle, required this.selected, required this.onTap});

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 1.5),
            color: selected ? AppColors.primary.withValues(alpha: 0.05) : null,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18, color: selected ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppTextStyles.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
