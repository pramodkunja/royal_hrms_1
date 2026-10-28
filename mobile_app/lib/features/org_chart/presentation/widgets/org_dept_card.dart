import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/org_chart_entity.dart';

/// One department's card: an always-visible head row, and a member list
/// that expands on tap rather than being rendered in full up front — with
/// potentially hundreds of employees in a department, dumping every member
/// on screen at once is exactly the "giant connector tree" this feature is
/// meant to avoid.
class OrgDeptCard extends StatefulWidget {
  final OrgDepartmentEntity dept;
  final Color color;
  final ValueChanged<OrgPersonEntity> onTapPerson;

  const OrgDeptCard({
    super.key,
    required this.dept,
    required this.color,
    required this.onTapPerson,
  });

  @override
  State<OrgDeptCard> createState() => _OrgDeptCardState();
}

class _OrgDeptCardState extends State<OrgDeptCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final dept = widget.dept;
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
            Container(width: 4, color: widget.color),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeadSection(
                    dept: dept,
                    color: widget.color,
                    expanded: _expanded,
                    onTapHead: dept.head == null
                        ? null
                        : () => widget.onTapPerson(dept.head!),
                    onToggle: dept.members.isEmpty
                        ? null
                        : () => setState(() => _expanded = !_expanded),
                  ),
                  if (_expanded && dept.members.isNotEmpty)
                    _MembersSection(
                      members: dept.members,
                      color: widget.color,
                      onTapPerson: widget.onTapPerson,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeadSection extends StatelessWidget {
  final OrgDepartmentEntity dept;
  final Color color;
  final bool expanded;
  final VoidCallback? onTapHead;
  final VoidCallback? onToggle;

  const _HeadSection({
    required this.dept,
    required this.color,
    required this.expanded,
    required this.onTapHead,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dept.label.toUpperCase(),
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: onTapHead,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        dept.head?.name ?? '—',
                        style: AppTextStyles.h4.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: onTapHead != null ? AppColors.primary : null,
                        ),
                      ),
                    ),
                    if (dept.head != null && dept.head!.designation.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          dept.head!.designation,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              if (onToggle != null) ...[
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textHint,
                    ),
                    Text(
                      '${dept.members.length}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  final List<OrgPersonEntity> members;
  final Color color;
  final ValueChanged<OrgPersonEntity> onTapPerson;

  const _MembersSection({
    required this.members,
    required this.color,
    required this.onTapPerson,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: members
            .map((m) => _MemberRow(person: m, onTap: () => onTapPerson(m)))
            .toList(),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final OrgPersonEntity person;
  final VoidCallback onTap;

  const _MemberRow({required this.person, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              _InitialsAvatar(name: person.name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name.isEmpty ? '—' : person.name,
                      style: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (person.designation.isNotEmpty)
                      Text(
                        person.designation,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

const _kAvatarPalette = [
  Color(0xFF1E4E8C),
  Color(0xFF219653),
  Color(0xFF7C3AED),
  Color(0xFFD4487B),
  Color(0xFFF2994A),
  Color(0xFF2D9CDB),
  Color(0xFFEB5757),
  Color(0xFF9B51E0),
  Color(0xFF0D7490),
];

class _InitialsAvatar extends StatelessWidget {
  final String name;
  const _InitialsAvatar({required this.name});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color get _color =>
      name.isEmpty ? _kAvatarPalette[0] : _kAvatarPalette[name.codeUnitAt(0) % _kAvatarPalette.length];

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: _color.withValues(alpha: 0.15),
      child: Text(
        _initials,
        style: AppTextStyles.caption
            .copyWith(color: _color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
