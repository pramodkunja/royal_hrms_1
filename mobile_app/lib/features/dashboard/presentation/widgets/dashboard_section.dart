import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';

/// A fixed-size, centered image icon — used wherever a dashboard card needs
/// an asset (PNG) icon instead of a Material [Icon]. Sized via an explicit
/// [SizedBox] + [Center] rather than relying on the image's own intrinsic
/// layout, so it renders at exactly [size] and stays centered even when a
/// parent (e.g. a fixed-size chip container) hands it tighter constraints.
class SectionIconAsset extends StatelessWidget {
  final String assetPath;
  final double size;

  const SectionIconAsset(this.assetPath, {super.key, this.size = 19});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Image.asset(assetPath, width: size, height: size, fit: BoxFit.contain),
      ),
    );
  }
}

/// Shared section-card chrome used by every dashboard widget (Employee,
/// Admin, HR, and the generic/Manager fallback) so all role dashboards look
/// visually consistent. Extracted from what used to be a private class in
/// `home_screen.dart` so the new per-role dashboard files can reuse it.
class SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  // Overrides [icon] with an asset image (e.g. SectionIconAsset) when set —
  // used by cards (Announcement, Birthdays) that show a PNG instead of a
  // Material icon.
  final Widget? iconWidget;
  final Color accentColor;
  final Widget child;
  final Widget? trailing;

  const SectionCard({
    super.key,
    required this.title,
    this.icon,
    this.iconWidget,
    required this.accentColor,
    required this.child,
    this.trailing,
  }) : assert(icon != null || iconWidget != null, 'Provide either icon or iconWidget');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                iconWidget ?? Icon(icon, size: 19, color: accentColor),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: AppTextStyles.h4)),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class SectionMessage extends StatelessWidget {
  final IconData? icon;
  // Overrides [icon] with an asset image (e.g. SectionIconAsset) — see
  // SectionCard.iconWidget for the same pattern.
  final Widget? iconWidget;
  final String label;

  const SectionMessage({super.key, this.icon, this.iconWidget, required this.label})
      : assert(icon != null || iconWidget != null, 'Provide either icon or iconWidget');

  @override
  Widget build(BuildContext context) {
    // The literal 'Loading…' label is used only by every dashboard card's
    // `loading:` branch (confirmed via a full-codebase grep: 26 call sites
    // use exactly this string, and every empty-state usage of
    // SectionMessage has its own specific message instead) — so this
    // check can never misfire onto a real "no data" state. Swapping in a
    // shimmering skeleton here means every one of those ~26 loading
    // branches gets it for free, with no call site needing to change.
    if (label == 'Loading…') {
      return const _SectionSkeleton();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      // SizedBox(width: double.infinity) forces this Column to actually span
      // the card's full width — SectionCard's outer Column uses
      // crossAxisAlignment.start, so without this the Column here would
      // shrink to its widest child's (the Text's) intrinsic width and the
      // whole icon+label block would sit pinned to the left edge instead of
      // centered in the card.
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            iconWidget ?? Icon(icon, color: AppColors.textHint, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// A generic 2-row shimmer placeholder — approximates the icon-chip + two
/// text lines shape most dashboard cards actually render once loaded
/// (ActionRow, BarRow, birthday/lifecycle rows) closely enough to read as
/// "this card's content is on its way" rather than a full-screen-style
/// generic grey rectangle.
class _SectionSkeleton extends StatefulWidget {
  const _SectionSkeleton();

  @override
  State<_SectionSkeleton> createState() => _SectionSkeletonState();
}

class _SectionSkeletonState extends State<_SectionSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.35 + (_controller.value * 0.35);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              _skeletonRow(opacity, secondLineWidth: 110),
              const SizedBox(height: 14),
              _skeletonRow(opacity, secondLineWidth: 70),
            ],
          ),
        );
      },
    );
  }

  Widget _skeletonRow(double opacity, {required double secondLineWidth}) {
    Widget bar({double? width, required double height}) => Opacity(
          opacity: opacity,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.backgroundMid,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        );

    return Row(
      children: [
        bar(width: 36, height: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(width: double.infinity, height: 12),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: bar(width: secondLineWidth, height: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SectionError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const SectionError({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 26),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodySecondary.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// A compact KPI tile — used by the KPI strips on the Employee, HR, and
/// Admin dashboards (mirrors web's KpiConsole / HrConsole / EmpConsole stat
/// tiles).
class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

/// Fixed-column KPI grid — 2 columns on phone widths, consistent
/// `mainAxisExtent` sizing so tiles never overflow regardless of label
/// length (matches the fix already applied to the Quick Access grid).
class KpiGrid extends StatelessWidget {
  final List<KpiTile> tiles;
  final int crossAxisCount;

  const KpiGrid({super.key, required this.tiles, this.crossAxisCount = 2});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        // 92 wasn't tall enough: padding(12+12) + icon row(~16) + spacing(10)
        // + 1-line value(h3, ~24) + spacing(2) + a 2-line label(caption,
        // ~30) adds up to ~106dp, so any tile whose label wraps to two
        // lines (e.g. "Pending Actions", "Active Branches") overflowed.
        mainAxisExtent: 116,
      ),
      itemBuilder: (context, index) => tiles[index],
    );
  }
}

/// Initials for an avatar chip — "Jane Doe" -> "JD", a single name -> its
/// first letter, empty -> "?". Shared by every role's console/lifecycle/
/// birthday rows so avatar initials are computed identically everywhere.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (name.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

/// A circular initials avatar — used anywhere a dashboard row would show a
/// real employee photo if this app had one (lifecycle rows, birthdays).
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final Color backgroundColor;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.backgroundColor = const Color(0xFF16224A),
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        initialsOf(name),
        style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Role console header (gradient hero + white stat strip) ─────────────────
// Shared by every role's dashboard (Employee/Manager/HR/Admin) so "welcome
// card" + "today's attendance status" look and behave identically across
// every flow — only the badge label, greeting name, and the real KPIs/stats
// plugged into the white strip vary per role.

const kConsoleMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "11 Aug 2026" — no `intl` package in this app, so a small hand-rolled
/// formatter shared by every console header instead of one copy each.
String todayLabel() {
  final now = DateTime.now();
  return '${now.day} ${kConsoleMonthNames[now.month - 1]} ${now.year}';
}

const kConsoleGradient = LinearGradient(
  colors: [Color(0xFF0EA5E9), Color(0xFF6366F1), Color(0xFFA21CAF)],
  stops: [0.0, 0.55, 1.0],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// The two-zone card shape itself: a gradient "hero" zone (whatever identity
/// content the caller builds, e.g. avatar + greeting + status) on top, and a
/// plain white zone below it for that role's real stats — one shared shell
/// so every role's header has the exact same silhouette, shadow, and corner
/// radius regardless of what's plugged into each zone.
class ConsoleHeaderShell extends StatelessWidget {
  final Widget heroContent;
  final Widget statsContent;

  const ConsoleHeaderShell({super.key, required this.heroContent, required this.statsContent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: const BoxDecoration(gradient: kConsoleGradient),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(right: -24, top: -34, child: HeroGlow(color: Colors.white, size: 130)),
                const Positioned(left: -30, bottom: -30, child: HeroGlow(color: Color(0xFFFDE68A), size: 90)),
                heroContent,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: statsContent,
          ),
        ],
      ),
    );
  }
}

/// A soft, blurred-looking color orb purely for background texture on the
/// gradient zone.
class HeroGlow extends StatelessWidget {
  final Color color;
  final double size;

  const HeroGlow({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// Avatar with a colored status ring (green while [active], dim otherwise)
/// plus a small overlapping "verified" badge — reads as a proper identity
/// component rather than a plain circle of initials.
class StatusRingAvatar extends StatelessWidget {
  final String name;
  final bool active;

  const StatusRingAvatar({super.key, required this.name, required this.active});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? const Color(0xFF4ADE80) : Colors.white.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18)),
              child: Center(
                child: Text(
                  initialsOf(name),
                  style: AppTextStyles.h4.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFDE68A),
                border: Border.all(color: const Color(0xFF6366F1), width: 2),
              ),
              child: const Icon(Icons.verified, size: 11, color: Color(0xFF6366F1)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The small uppercase pill naming which console this is ("HR OPERATIONS",
/// "EMPLOYEE WORKSPACE", "SYSTEM CONSOLE"...).
class RoleBadgePill extends StatelessWidget {
  final String label;
  final IconData icon;

  const RoleBadgePill({super.key, required this.label, this.icon = Icons.workspace_premium_outlined});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// The date + clocked-in/out glass bar sitting at the bottom of the gradient
/// zone. [clockedIn] comes from the same `todayAttendanceProvider` every
/// role's AttendanceRingCard already watches, so this pill and that card
/// never disagree about whether the signed-in user is currently clocked in.
class ConsoleInfoBar extends StatelessWidget {
  final bool clockedIn;

  const ConsoleInfoBar({super.key, required this.clockedIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 13, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              todayLabel(),
              style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.9)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white.withValues(alpha: 0.25),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: clockedIn ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            clockedIn ? 'Clocked In' : 'Not Clocked In',
            style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// One stat in the white strip below the gradient hero — a colored icon
/// chip (colors only really pop against white) with a centered bold number
/// and label, so the "number belongs to this icon" relationship is obvious
/// regardless of how long each role's labels are.
class LightStatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const LightStatCell({super.key, required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

typedef ConsoleStatData = ({IconData icon, String value, String label, Color color});

/// A row of [LightStatCell]s, evenly spaced with no dividers between them —
/// the row every role's console header stats render into.
class ConsoleStatsRow extends StatelessWidget {
  final List<ConsoleStatData> stats;

  const ConsoleStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: LightStatCell(icon: stats[i].icon, value: stats[i].value, label: stats[i].label, color: stats[i].color),
          ),
        ],
      ],
    );
  }
}

/// A tappable "N pending" row — icon chip + title + colored count + chevron.
/// Used by every role's action-queue/pending-approvals list so tapping a
/// count actually opens that section instead of just displaying a number.
class ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int count;
  final VoidCallback onTap;

  const ActionRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text('Awaiting action', style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            '$count',
            style: AppTextStyles.h4.copyWith(color: iconColor, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 20, color: AppColors.textHint),
        ],
      ),
    );
  }
}

/// An underline-style tab chip — icon + label + a small count pill, used by
/// every role's tabbed Employee Lifecycle card (New Joiners / Notice Period
/// / Anniversaries). Purely presentational: the parent owns which tab is
/// selected and what happens on tap.
class LifecycleTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const LifecycleTabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.backgroundMid,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single horizontal bar row — used by DeptHeadcountChart's port (no chart
/// library is in pubspec.yaml, so a simple proportional bar list stands in
/// for web's chart, showing the same department/count data).
class BarRow extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;

  const BarRow({
    super.key,
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$value',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: AppColors.backgroundMid,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
