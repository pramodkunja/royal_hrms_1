import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/branch_entity.dart';
import 'branch_details_sheet.dart';

class BranchCard extends StatefulWidget {
  final BranchEntity branch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const BranchCard({
    super.key,
    required this.branch,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<BranchCard> createState() => _BranchCardState();
}

class _BranchCardState extends State<BranchCard> {
  bool _addressExpanded = false;

  @override
  Widget build(BuildContext context) {
    final branch = widget.branch;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: _Header(branch: branch),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _LocationBlock(
              branch: branch,
              expanded: _addressExpanded,
              onToggle: () =>
                  setState(() => _addressExpanded = !_addressExpanded),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(child: _WorkforceChip(branch: branch)),
                const SizedBox(width: 8),
                Expanded(child: _HrChip(branch: branch)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _AttendanceStrip(branch: branch),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.border),
          _Actions(
            onViewDetails: () => showBranchDetailsSheet(context, branch),
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Header: icon + name + code, HQ badge, status pill ──────────────────────

class _Header extends StatelessWidget {
  final BranchEntity branch;
  const _Header({required this.branch});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.business_rounded, color: AppColors.primary, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                branch.branchName,
                style: AppTextStyles.h4,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundMid,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      branch.branchCode,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (branch.isHeadquarter) ...[
                    const SizedBox(width: 6),
                    _HqBadge(),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusPill(isActive: branch.isActive),
      ],
    );
  }
}

class _HqBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 10, color: AppColors.secondary),
          const SizedBox(width: 3),
          Text(
            'HQ',
            style: AppTextStyles.caption.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isActive;
  const _StatusPill({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Location: city · state + expandable address ─────────────────────────────

class _LocationBlock extends StatelessWidget {
  final BranchEntity branch;
  final bool expanded;
  final VoidCallback onToggle;
  const _LocationBlock({
    required this.branch,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final hasAddress = branch.address.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, size: 13, color: AppColors.error),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${branch.cityName} · ${branch.stateName}',
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (hasAddress) ...[
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, size: 13, color: AppColors.textHint),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    branch.address,
                    style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                    maxLines: expanded ? null : 2,
                    overflow: expanded ? null : TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.only(top: 3, left: 18),
                child: Text(
                  expanded ? 'Show less' : 'View full address',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Workforce + HR chips ─────────────────────────────────────────────────────

class _WorkforceChip extends StatelessWidget {
  final BranchEntity branch;
  const _WorkforceChip({required this.branch});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            branch.employeesLabel,
            style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _HrChip extends StatelessWidget {
  final BranchEntity branch;
  const _HrChip({required this.branch});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.badge_outlined, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            branch.hasHr ? branch.hrName! : 'HR: Not Assigned',
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: branch.hasHr ? AppColors.textPrimary : AppColors.textHint,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Secondary geolocation/attendance strip ───────────────────────────────────

class _AttendanceStrip extends StatelessWidget {
  final BranchEntity branch;
  const _AttendanceStrip({required this.branch});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _MiniStat(
          icon: Icons.shield_outlined,
          label: 'Geofencing ${branch.geofencingEnabled ? 'ON' : 'OFF'}',
          color: branch.geofencingEnabled ? AppColors.success : AppColors.textHint,
        ),
        _MiniStat(
          icon: Icons.my_location_outlined,
          label: branch.hasCoordinates ? 'Coordinates ✓' : 'Coordinates —',
          color: branch.hasCoordinates ? AppColors.info : AppColors.textHint,
        ),
        _MiniStat(
          icon: Icons.radar_outlined,
          label: 'Radius ${branch.allowedRadiusMeters}m',
          color: AppColors.textHint,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniStat({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: color),
        ),
      ],
    );
  }
}

// ── Footer actions ───────────────────────────────────────────────────────────

class _Actions extends StatelessWidget {
  final VoidCallback onViewDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _Actions({
    required this.onViewDetails,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            onPressed: onViewDetails,
            icon: Icon(Icons.visibility_outlined, size: 14, color: AppColors.primary),
            label: Text(
              'View Details',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
            ),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
          ),
        ),
        VerticalDivider(width: 1, color: AppColors.border),
        IconButton(
          tooltip: 'Edit branch',
          onPressed: onEdit,
          icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          tooltip: 'Delete branch',
          onPressed: onDelete,
          icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
