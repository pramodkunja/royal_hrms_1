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
  /// Edit/delete/add actions only with settings.edit (web canEdit).
  final bool canEdit;
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
    this.canEdit = true,
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
            canEdit: canEdit,
            onTap: onTap,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: AppColors.border),
            if (dept.roles.isNotEmpty) _RolesPanel(roles: dept.roles),
            _DesignationPanel(
              canEdit: canEdit,
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
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DeptHeader({
    required this.dept,
    required this.accentColor,
    required this.isExpanded,
    required this.canEdit,
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
        child: _DeptHeaderRow(
          canEdit: canEdit,
          actionsKey: Key('dept-actions-${dept.id}'),
          lead: [
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
                  // The whole department name wraps (no ellipsis); at large text the
                  // status drops under it instead of squeezing it.
                  LayoutBuilder(builder: (context, c) {
                    final nameText = Text(
                      dept.name,
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    );
                    final stacked = c.maxWidth < 200 || MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [nameText, const SizedBox(height: 6), _StatusBadge(isActive: dept.isActive)],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: nameText),
                        const SizedBox(width: 8),
                        _StatusBadge(isActive: dept.isActive),
                      ],
                    );
                  }),
                  if (dept.description != null && dept.description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      dept.description!,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _CountChip(
                        icon: Icons.work_outline,
                        value: dept.designationCount,
                        label: 'Desig',
                        color: AppColors.primary,
                      ),
                      _CountChip(
                        icon: Icons.people_outline,
                        value: dept.employeeCount,
                        label: 'People',
                        color: const Color(0xFF7C3AED),
                      ),
                      if (dept.roles.isNotEmpty)
                        _CountChip(
                          icon: Icons.shield_outlined,
                          value: dept.roles.length,
                          label: 'Roles',
                          color: const Color(0xFF0E7C86),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          actions: [

                IconButton(
                  key: Key('dept-edit-${dept.id}'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                IconButton(
                  key: Key('dept-delete-${dept.id}'),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.error,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
          ],
        ),
      ),
    );
  }
}

/// Department header: identity on the left, Edit/Delete stacked on the right when there is
/// room; at large text or on a narrow card the actions move under the details so the name
/// and status keep the full width.
class _DeptHeaderRow extends StatelessWidget {
  final bool canEdit;
  final Key actionsKey;
  final List<Widget> lead;
  final List<Widget> actions;
  const _DeptHeaderRow(
      {required this.canEdit, required this.actionsKey, required this.lead, required this.actions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final large = MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
      if (!canEdit) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: lead);
      if (large || c.maxWidth < 280) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: lead),
          Align(
              alignment: Alignment.centerRight,
              child: Row(key: actionsKey, mainAxisSize: MainAxisSize.min, children: actions)),
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ...lead,
        Column(key: actionsKey, mainAxisSize: MainAxisSize.min, children: actions),
      ]);
    });
  }
}

// ── Roles panel (read-only — computed from active users in this dept) ────────

class _RolesPanel extends StatelessWidget {
  final List<DepartmentRoleTag> roles;
  const _RolesPanel({required this.roles});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F7F8),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            'ROLES',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textHint,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
              letterSpacing: 0.4,
            ),
          ),
          ...roles.map((r) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E7C86).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0E7C86).withValues(alpha: 0.20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined, size: 11, color: Color(0xFF0E7C86)),
                    const SizedBox(width: 5),
                    Text(
                      r.displayName,
                      style: AppTextStyles.caption.copyWith(
                        color: const Color(0xFF0E7C86),
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Designation expansion panel ───────────────────────────────────────────────

class _DesignationPanel extends StatelessWidget {
  final bool canEdit;
  final List<DesignationModel> designations;
  final VoidCallback onAdd;
  final ValueChanged<DesignationModel> onEdit;
  final ValueChanged<DesignationModel> onDelete;

  const _DesignationPanel({
    required this.canEdit,
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
          // A Wrap, not a Row: at large text the Add button drops below the title instead of overflowing.
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.work_outline, color: Colors.white, size: 15),
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(
                'Designations',
                style: AppTextStyles.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              )),
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
              ]),
              if (canEdit)
              GestureDetector(
                key: const Key('desig-add'),
                behavior: HitTestBehavior.opaque,
                onTap: onAdd,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
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
          color: Color.alphaBlend(AppColors.success.withValues(alpha: 0.07), AppColors.surface),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: designations.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text(
                      canEdit ? 'No designations yet — tap Add to create one.' : 'No designations yet.',
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
                              canEdit: canEdit,
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
  final bool canEdit;
  final DesignationModel desig;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DesigCard({
    required this.canEdit,
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
        child: _DesigRow(
          lead: [
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
            // The whole name wraps (no ellipsis); the status sits beneath it.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                desig.name,
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
                  const SizedBox(height: 6),
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
                ],
              ),
            ),
          ],
          actions: [
            if (canEdit) ...[
            IconButton(
              key: Key('desig-edit-${desig.id}'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              key: Key('desig-delete-${desig.id}'),
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.error,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Name block with its Edit/Delete actions: side by side when the card is wide enough,
/// otherwise the actions sit under the name (never squeezing the name or the status).
class _DesigRow extends StatelessWidget {
  final List<Widget> lead;
  final List<Widget> actions;
  const _DesigRow({required this.lead, required this.actions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final stacked =
          actions.isNotEmpty && (c.maxWidth < 250 || MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3);
      if (!stacked) return Row(children: [...lead, ...actions]);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: lead),
        Align(alignment: Alignment.centerRight, child: Row(mainAxisSize: MainAxisSize.min, children: actions)),
      ]);
    });
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
          Flexible(
            child: Text(
              '$value $label',
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
