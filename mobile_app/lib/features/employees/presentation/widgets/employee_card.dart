import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/employee_model.dart';

class EmployeeCard extends StatelessWidget {
  final EmployeeModel employee;
  final VoidCallback? onView;
  final VoidCallback? onEdit;

  const EmployeeCard({
    super.key,
    required this.employee,
    this.onView,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final name = employee.fullName.isEmpty
        ? '${employee.firstName} ${employee.lastName}'.trim()
        : employee.fullName;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Colored left accent strip ──────────────────────────────
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: employee.avatarColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),

            // ── Card body ──────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top: Avatar + Info + Status ──────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Avatar(employee: employee),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: AppTextStyles.label.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              if (employee.employeeId.isNotEmpty)
                                Text(
                                  '#${employee.employeeId}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: employee.avatarColor,
                                  ),
                                ),
                              if (employee.designation.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  employee.designation,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: employee.status),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Middle: Branch + Department ──────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _InfoItem(
                              icon: Icons.location_on_outlined,
                              label: 'BRANCH',
                              value: employee.branch.isEmpty
                                  ? '—'
                                  : employee.branch,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: AppColors.border,
                          ),
                          Expanded(
                            child: _InfoItem(
                              icon: Icons.business_outlined,
                              label: 'DEPT',
                              value: employee.department.isEmpty
                                  ? '—'
                                  : employee.department,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── Bottom: Action buttons ───────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.remove_red_eye_outlined,
                            label: 'View Profile',
                            onTap: onView,
                            filled: false,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.edit_outlined,
                            label: 'Edit Details',
                            onTap: onEdit,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final EmployeeModel employee;
  const _Avatar({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: employee.avatarColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: employee.avatarColor.withValues(alpha: 0.30),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          employee.initials,
          style: TextStyle(
            color: employee.avatarColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'active'     => (AppColors.successContainer, AppColors.success,  'Active'),
      'onboarding' => (AppColors.warningContainer, AppColors.warning,  'Onboarding'),
      'inactive'   => (AppColors.errorContainer,   AppColors.error,    'Inactive'),
      _            => (AppColors.border,            AppColors.textHint, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ── Info item (icon + label + value stacked) ──────────────────────────────────

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 13, color: AppColors.textHint),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.label.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  const _ActionBtn({
    required this.icon,
    required this.label,
    this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: filled ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
