import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/org_chart_entity.dart';

class OrgDeptCard extends StatelessWidget {
  final DepartmentNodeEntity dept;
  const OrgDeptCard({super.key, required this.dept});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored accent bar
            Container(width: 4, color: dept.color),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Head section ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dept.name.toUpperCase(),
                          style: AppTextStyles.caption.copyWith(
                            color: dept.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          dept.head?.fullName ?? '—',
                          style: AppTextStyles.h4.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        if (dept.head != null &&
                            dept.head!.designation.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              dept.head!.designation,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Team members section ─────────────────────────────────
                  Container(
                    width: double.infinity,
                    color: dept.color.withValues(alpha: 0.07),
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TEAM MEMBERS',
                          style: AppTextStyles.caption.copyWith(
                            color: dept.color,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _membersText(dept.members),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _membersText(List<OrgMemberEntity> members) {
    if (members.isEmpty) return '—';
    if (members.length <= 2) {
      return members.map((m) => m.fullName).join(',  ');
    }
    return '${members.length} members';
  }
}
