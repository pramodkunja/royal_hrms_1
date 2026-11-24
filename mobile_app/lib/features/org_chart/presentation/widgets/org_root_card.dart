import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/org_chart_entity.dart';
import 'org_labels.dart';

/// The branch/company's top-of-chart person — whoever has no reporting
/// manager, per the backend. [person] is null when the backend couldn't
/// identify exactly one such person (none, or more than one — a data-
/// quality gap, not an error), in which case we show a neutral note rather
/// than guessing.
class OrgRootCard extends StatelessWidget {
  final OrgPersonEntity? person;
  final VoidCallback? onTap;

  const OrgRootCard({super.key, this.person, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (person == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          key: const Key('org-root-not-set'),
          children: [
            Text(
              'TOP OF CHART',
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              kOrgNotSet,
              style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w500, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // Why it is not set (existing wording): the backend names a head only when exactly one
            // person has no reporting manager.
            Text(
              'No single head identified for this branch.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final p = person!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: [
              if (p.designation.isNotEmpty) ...[
                Text(
                  p.designation.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.textHint,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
              ],
              Text(
                orgHasText(p.name) ? p.name : kOrgNameNotSet,
                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
