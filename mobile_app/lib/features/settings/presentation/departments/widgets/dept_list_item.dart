import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/departments_model.dart';

// Deterministic per-department color from the initial letter.
const _kPalette = [
  Color(0xFFE07B39), // amber-orange
  Color(0xFF1E4E8C), // royal navy
  Color(0xFF1B8A6B), // forest teal
  Color(0xFFD0394A), // crimson
  Color(0xFF7C3AED), // violet
  Color(0xFF0284C7), // sky blue
  Color(0xFFDB2777), // rose
  Color(0xFF0D9488), // teal-2
];

Color _deptColor(String name) =>
    name.isEmpty ? _kPalette[1] : _kPalette[name.codeUnitAt(0) % _kPalette.length];

// ── Accordion card ────────────────────────────────────────────────────────────

class DeptListItem extends StatelessWidget {
  final DepartmentModel dept;
  final bool isExpanded;
  final List<DesignationModel> designations;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddDesig;
  final ValueChanged<DesignationModel> onEditDesig;
  final ValueChanged<DesignationModel> onDeleteDesig;

  const DeptListItem({
    super.key,
    required this.dept,
    required this.isExpanded,
    required this.designations,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onAddDesig,
    required this.onEditDesig,
    required this.onDeleteDesig,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = _deptColor(dept.name);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isExpanded
            ? Border.all(color: accentColor.withValues(alpha: 0.60), width: 1.5)
            : Border.all(color: AppColors.border),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeptHeader(
            dept: dept,
            accentColor: accentColor,
            isExpanded: isExpanded,
            onTap: onTap,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            _DesignationPanel(
              designations: designations,
              onAdd: onAddDesig,
              onEdit: onEditDesig,
              onDelete: onDeleteDesig,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Department header (always visible) ────────────────────────────────────────

class _DeptHeader extends StatelessWidget {
  final DepartmentModel dept;
  final Color accentColor;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DeptHeader({
    required this.dept,
    required this.accentColor,
    required this.isExpanded,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initial = dept.name.isNotEmpty ? dept.name[0].toUpperCase() : '?';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient avatar with shadow
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.72)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Name + status + chips
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dept.name,
                          style: AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(isActive: dept.isActive),
                    ],
                  ),
                  if (dept.description != null && dept.description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      dept.description!,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _CountChip(
                        icon: Icons.work_outline,
                        value: dept.designationCount,
                        label: 'Desig',
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      _CountChip(
                        icon: Icons.people_outline,
                        value: dept.employeeCount,
                        label: 'People',
                        color: const Color(0xFF7C3AED),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Action buttons stacked
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  color: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 17),
                  color: AppColors.error,
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Designation expansion panel ───────────────────────────────────────────────

class _DesignationPanel extends StatelessWidget {
  final List<DesignationModel> designations;
  final VoidCallback onAdd;
  final ValueChanged<DesignationModel> onEdit;
  final ValueChanged<DesignationModel> onDelete;

  const _DesignationPanel({
    required this.designations,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Teal banner — visually distinct from the navy dept identity
        Container(
          color: AppColors.success,
          padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.work_outline, color: Colors.white, size: 15),
              ),
              const SizedBox(width: 8),
              Text(
                'Designations',
                style: AppTextStyles.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${designations.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'Add',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Desig list
        Container(
          color: const Color(0xFFF0FAF7),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: designations.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text(
                      'No designations yet — tap Add to create one.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: designations
                      .map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _DesigCard(
                              desig: d,
                              onEdit: () => onEdit(d),
                              onDelete: () => onDelete(d),
                            ),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

// ── Designation card ──────────────────────────────────────────────────────────

class _DesigCard extends StatelessWidget {
  final DesignationModel desig;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DesigCard({
    required this.desig,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initial = desig.name.isNotEmpty ? desig.name[0].toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
        child: Row(
          children: [
            // Teal-themed avatar to differ from dept (navy)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.success, AppColors.success.withValues(alpha: 0.72)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                desig.name,
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Active / Inactive badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: desig.isActive
                    ? AppColors.success.withValues(alpha: 0.10)
                    : AppColors.textHint.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: desig.isActive
                      ? AppColors.success.withValues(alpha: 0.35)
                      : AppColors.textHint.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: desig.isActive ? AppColors.success : AppColors.textHint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    desig.isActive ? 'Active' : 'Inactive',
                    style: AppTextStyles.caption.copyWith(
                      color: desig.isActive ? AppColors.success : AppColors.textHint,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 15),
              color: AppColors.textSecondary,
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 15),
              color: AppColors.error,
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withValues(alpha: 0.10)
            : AppColors.textHint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.textHint.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isActive ? AppColors.success : AppColors.textHint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: AppTextStyles.caption.copyWith(
              color: isActive ? AppColors.success : AppColors.textHint,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  const _CountChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            '$value $label',
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
