import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/employee_model.dart';

// (background, foreground, display label) for a status — shared by the top
// accent bar and the status pill so both agree (top bar = status color,
// exactly like the reference design's amber bar on the Onboarding card and
// green bar on the Active card; the employee's own avatar color is a
// separate, per-person identity color, not tied to status).
(Color, Color, String) _statusStyle(String status) => switch (status) {
      'active'     => (AppColors.successContainer, AppColors.success,  'Active'),
      'onboarding' => (AppColors.warningContainer, AppColors.warning,  'Onboarding'),
      'inactive'   => (AppColors.errorContainer,   AppColors.error,    'Inactive'),
      _            => (AppColors.border,            AppColors.textHint, status),
    };

/// A compact, portrait "directory" card — a status-colored top accent bar,
/// a big centered avatar, name/ID/role stacked and centered, a status pill,
/// and two square icon-only actions at the bottom. Meant to sit in a
/// 2-column grid rather than as a full-width row.
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
    final (_, statusColor, _) = _statusStyle(employee.status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      // Plain (non-Expanded, mainAxisSize.min) content — this card renders
      // inside a SliverGrid tile (bounded/tight height) when the directory
      // is in grid view, but the SAME card also renders inside a SliverList
      // (unbounded height) when the grid/list toggle is switched to list
      // view. An Expanded/spaceBetween layout here worked in the grid but
      // crashed in the list ("non-zero flex but incoming height constraints
      // are unbounded") — sizing to intrinsic content height works in both:
      // the grid tile just leaves a little blank space below the buttons
      // when content is shorter than the tile, and the list sizes each row
      // to exactly its own content.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Status-colored top accent bar ───────────────────────────────
          Container(height: 4, color: statusColor),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Avatar(employee: employee),
                const SizedBox(height: 10),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (employee.employeeId.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '#${employee.employeeId}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ],
                if (employee.designation.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    employee.designation,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11.5),
                  ),
                ],
                const SizedBox(height: 8),
                _StatusBadge(status: employee.status),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SquareIconButton(
                        icon: Icons.remove_red_eye_outlined,
                        filled: false,
                        onTap: onView,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SquareIconButton(
                        icon: Icons.edit_outlined,
                        filled: true,
                        onTap: onEdit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: employee.avatarColor.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          employee.initials,
          style: TextStyle(
            color: employee.avatarColor,
            fontSize: 20,
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
    final (bg, fg, label) = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }
}

// ── Square icon-only action button ────────────────────────────────────────────

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  const _SquareIconButton({
    required this.icon,
    required this.filled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: filled ? AppColors.primary : AppColors.primary.withValues(alpha: 0.30),
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: filled ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
