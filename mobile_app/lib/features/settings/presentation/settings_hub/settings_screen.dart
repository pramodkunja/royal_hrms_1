import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Tab definitions ───────────────────────────────────────────────────────────

enum _Tab { all, company, modules, comm, system }

class _TabMeta {
  final _Tab id;
  final String label;
  final IconData icon;
  const _TabMeta(this.id, this.label, this.icon);
}

const _kTabs = [
  _TabMeta(_Tab.all,     'All Settings',  Icons.grid_view_rounded),
  _TabMeta(_Tab.company, 'Company',       Icons.business_outlined),
  _TabMeta(_Tab.modules, 'Modules',       Icons.layers_outlined),
  _TabMeta(_Tab.comm,    'Communication', Icons.mail_outline),
  _TabMeta(_Tab.system,  'System',        Icons.storage_outlined),
];

// ── Tile definitions ──────────────────────────────────────────────────────────

class _Tile {
  final _Tab cat;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String desc;
  final String? route;
  const _Tile({
    required this.cat, required this.icon,
    required this.iconColor, required this.iconBg,
    required this.label, required this.desc, this.route,
  });
}

const _kTiles = <_Tile>[
  // Company
  _Tile(
    cat: _Tab.company,
    icon: Icons.business_outlined, iconColor: Color(0xFF1E4E8C), iconBg: Color(0xFFEBF0FA),
    label: 'Company Info',
    desc: 'Name, GST, address and registration details',
    route: AppRoutes.settingsCompany,
  ),
  _Tile(
    cat: _Tab.company,
    icon: Icons.account_tree_outlined, iconColor: Color(0xFF1B8A6B), iconBg: Color(0xFFE6F5F0),
    label: 'Depts & Designations',
    desc: 'Organisation structure and job titles',
    route: AppRoutes.settingsDepartments,
  ),
  _Tile(
    cat: _Tab.company,
    icon: Icons.shield_outlined, iconColor: Color(0xFF6B3FA0), iconBg: Color(0xFFF0EBF9),
    label: 'Roles & Permissions',
    desc: 'Role-based access control for all users',
    route: AppRoutes.settingsRoles,
  ),
  _Tile(
    cat: _Tab.company,
    icon: Icons.badge_outlined, iconColor: Color(0xFF0E7C86), iconBg: Color(0xFFE5F4F5),
    label: 'Employee ID Format',
    desc: 'Prefix, padding and starting sequence',
    route: AppRoutes.settingsEmployeeCode,
  ),
  // Modules
  _Tile(
    cat: _Tab.modules,
    icon: Icons.beach_access_outlined, iconColor: Color(0xFFB5651D), iconBg: Color(0xFFFAF0E6),
    label: 'Leave Policy',
    desc: 'Configure leave types, accruals and limits',
  ),
  _Tile(
    cat: _Tab.modules,
    icon: Icons.payments_outlined, iconColor: Color(0xFF4A148C), iconBg: Color(0xFFF3E5F5),
    label: 'Payroll Rules',
    desc: 'Salary components, tax slabs and statutory',
  ),
  _Tile(
    cat: _Tab.modules,
    icon: Icons.access_time_outlined, iconColor: Color(0xFF006064), iconBg: Color(0xFFE0F4F4),
    label: 'Attendance Rules',
    desc: 'Shift timings, late marks and overtime',
  ),
  _Tile(
    cat: _Tab.modules,
    icon: Icons.people_outline, iconColor: Color(0xFF37474F), iconBg: Color(0xFFECEFF1),
    label: 'Recruitment Config',
    desc: 'Interview stages and evaluation criteria',
  ),
  // Communication
  _Tile(
    cat: _Tab.comm,
    icon: Icons.dns_outlined, iconColor: Color(0xFF2A6ACC), iconBg: Color(0xFFEBF2FF),
    label: 'SMTP Settings',
    desc: 'Outgoing email server configuration',
    route: AppRoutes.settingsSmtp,
  ),
  _Tile(
    cat: _Tab.comm,
    icon: Icons.mail_outline, iconColor: Color(0xFFC0392B), iconBg: Color(0xFFFAEAE8),
    label: 'Email Templates',
    desc: 'Customise all transactional emails',
    route: AppRoutes.settingsEmailTemplates,
  ),
  _Tile(
    cat: _Tab.comm,
    icon: Icons.notifications_outlined, iconColor: Color(0xFFE65100), iconBg: Color(0xFFFFF3E0),
    label: 'Notifications',
    desc: 'In-app and email notification preferences',
  ),
  // System
  _Tile(
    cat: _Tab.system,
    icon: Icons.history_rounded, iconColor: Color(0xFF5D4037), iconBg: Color(0xFFF3EDE8),
    label: 'Audit Log',
    desc: 'View all system actions and changes',
    route: AppRoutes.settingsAuditLog,
  ),
];

// ── Section grouping ──────────────────────────────────────────────────────────

class _Section {
  final String label;
  final IconData icon;
  final Color color;
  final List<_Tile> tiles;
  const _Section({required this.label, required this.icon, required this.color, required this.tiles});
}

({String label, IconData icon, Color color}) _sectionMeta(_Tab tab) => switch (tab) {
  _Tab.company => (label: 'Company Settings', icon: Icons.business_outlined, color: const Color(0xFF1E4E8C)),
  _Tab.modules => (label: 'Module Configuration', icon: Icons.layers_outlined, color: const Color(0xFF4A148C)),
  _Tab.comm    => (label: 'Communication', icon: Icons.mail_outline, color: const Color(0xFFC0392B)),
  _Tab.system  => (label: 'System', icon: Icons.storage_outlined, color: const Color(0xFF5D4037)),
  _Tab.all     => (label: 'All Settings', icon: Icons.grid_view_rounded, color: AppColors.primary),
};

List<_Section> _grouped(List<_Tile> tiles) {
  final map = <_Tab, List<_Tile>>{};
  for (final t in tiles) {
    map.putIfAbsent(t.cat, () => []).add(t);
  }
  return map.entries.map((e) {
    final meta = _sectionMeta(e.key);
    return _Section(label: meta.label, icon: meta.icon, color: meta.color, tiles: e.value);
  }).toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  _Tab _active = _Tab.all;

  List<_Tile> get _filtered =>
      _active == _Tab.all ? _kTiles : _kTiles.where((t) => t.cat == _active).toList();

  @override
  Widget build(BuildContext context) {
    final sections = _active == _Tab.all
        ? _grouped(_filtered)
        : [_Section(
            label: '',
            icon: Icons.settings_outlined,
            color: AppColors.primary,
            tiles: _filtered,
          )];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(),
        const SizedBox(height: 4),
        _TabBar(active: _active, onSelect: (t) => setState(() => _active = t)),
        const SizedBox(height: 2),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: _listItemCount(sections),
            itemBuilder: (context, i) => _listItem(sections, i),
          ),
        ),
      ],
    );
  }

  int _listItemCount(List<_Section> sections) {
    int count = 0;
    for (final s in sections) {
      if (s.label.isNotEmpty) count++;
      count += s.tiles.length;
    }
    return count;
  }

  Widget _listItem(List<_Section> sections, int index) {
    int cursor = 0;
    for (final section in sections) {
      if (section.label.isNotEmpty) {
        if (index == cursor) return _SectionLabel(section: section);
        cursor++;
      }
      for (final tile in section.tiles) {
        if (index == cursor) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TileCard(tile: tile),
          );
        }
        cursor++;
      }
    }
    return const SizedBox.shrink();
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B3A6B), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B3A6B).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings',
                    style: AppTextStyles.h3.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('Configure all Royal HRMS modules',
                    style: AppTextStyles.caption.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          _HeaderStat(count: _kTiles.length, label: 'Options'),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final int count;
  final String label;
  const _HeaderStat({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count', style: AppTextStyles.h4.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final _Tab active;
  final ValueChanged<_Tab> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E6EB)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _kTabs.map((tab) => _TabItem(
            tab: tab,
            isActive: tab.id == active,
            onTap: () => onSelect(tab.id),
          )).toList(),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final _TabMeta tab;
  final bool isActive;
  final VoidCallback onTap;
  const _TabItem({required this.tab, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1B3A6B) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [BoxShadow(color: const Color(0xFF1B3A6B).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tab.icon,
              size: 15,
              color: isActive ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              tab.label,
              style: AppTextStyles.caption.copyWith(
                color: isActive ? Colors.white : const Color(0xFF64748B),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final _Section section;
  const _SectionLabel({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: section.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(section.icon, size: 14, color: section.color),
          ),
          const SizedBox(width: 8),
          Text(
            section.label,
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(height: 1, color: AppColors.border),
          ),
        ],
      ),
    );
  }
}

// ── Tile card ─────────────────────────────────────────────────────────────────

class _TileCard extends StatelessWidget {
  final _Tile tile;
  const _TileCard({required this.tile});

  @override
  Widget build(BuildContext context) {
    final isAvailable = tile.route != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isAvailable ? () => context.push(tile.route!) : null,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _TileIcon(
                  icon: tile.icon,
                  iconColor: isAvailable ? tile.iconColor : AppColors.textHint,
                  bgColor: isAvailable ? tile.iconBg : const Color(0xFFF5F5F5),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tile.label,
                              style: AppTextStyles.label.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isAvailable ? AppColors.textPrimary : AppColors.textHint,
                              ),
                            ),
                          ),
                          if (!isAvailable) const _SoonBadge(),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tile.desc,
                        style: AppTextStyles.caption.copyWith(
                          color: isAvailable ? AppColors.textSecondary : AppColors.textHint,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isAvailable)
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 18),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  const _TileIcon({required this.icon, required this.iconColor, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFFECB3)),
      ),
      child: Text(
        'Soon',
        style: AppTextStyles.caption.copyWith(
          color: const Color(0xFFE65100),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
