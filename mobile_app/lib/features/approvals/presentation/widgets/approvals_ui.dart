import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../profile/presentation/widgets/profile_widgets.dart';

// Shared Premium Minimal building blocks for the Approvals module (same look
// as My Profile and Company Info): light 14 px cards on a hairline border, tinted
// pill badges, no heavy shadows or gradients.

/// Rows per page — web ApprovalsTable PAGE_SIZE.
const int kApprovalsPageSize = 10;

enum ApprovalsTone { success, warning, error, neutral, info }

Color approvalsToneColor(ApprovalsTone t) => switch (t) {
      ApprovalsTone.success => AppColors.success,
      ApprovalsTone.warning => AppColors.warning,
      ApprovalsTone.error => AppColors.error,
      ApprovalsTone.info => AppColors.info,
      ApprovalsTone.neutral => AppColors.textSecondary,
    };

/// Small tinted pill (status, type, level).
class ApprovalsBadge extends StatelessWidget {
  const ApprovalsBadge(this.text, this.tone, {super.key, this.icon});
  final String text;
  final ApprovalsTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = approvalsToneColor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: c), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(color: c, fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain card shell.
class ApprovalsCard extends StatelessWidget {
  const ApprovalsCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.highlight});
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Optional accent: a 3 px bar on the left edge (e.g. status colour).
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      // The accent is a Stack bar, not a Row sibling, so the card needs no
      // intrinsic sizing (its children may contain LayoutBuilders).
      child: Stack(
        children: [
          Padding(
            padding: highlight == null ? padding : const EdgeInsetsDirectional.only(start: 3).add(padding),
            child: child,
          ),
          if (highlight != null) Positioned(left: 0, top: 0, bottom: 0, width: 3, child: ColoredBox(color: highlight!)),
        ],
      ),
    );
  }
}

/// "You're all caught up!" (web ta-empty) or a filter-miss message.
class ApprovalsEmpty extends StatelessWidget {
  const ApprovalsEmpty({super.key, required this.title, this.subtitle, this.icon = Icons.check_circle_outline});
  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.success),
          const SizedBox(height: 10),
          Text(title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// Web ApprovalsTable pagination: "Showing a–b of n", Prev, a window of up to
/// five page numbers, Next. Hidden when there is one page.
class ApprovalsPager extends StatelessWidget {
  const ApprovalsPager({super.key, required this.page, required this.total, required this.onPage});
  final int page; // 1-based
  final int total; // item count
  final ValueChanged<int> onPage;

  /// Pages for [total] items.
  static int pagesFor(int total) => total <= 0 ? 1 : ((total + kApprovalsPageSize - 1) ~/ kApprovalsPageSize);

  @override
  Widget build(BuildContext context) {
    final pages = pagesFor(total);
    if (pages <= 1) return const SizedBox.shrink();
    final from = (page - 1) * kApprovalsPageSize + 1;
    final to = (page * kApprovalsPageSize).clamp(0, total);
    final window = pages < 5 ? pages : 5;
    final start = (page - 2).clamp(1, pages - window + 1);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          Text(
            'Showing $from–$to of $total',
            key: const Key('approvals-showing'),
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                key: const Key('approvals-prev'),
                onPressed: page <= 1 ? null : () => onPage(page - 1),
                icon: const Icon(Icons.chevron_left, size: 16),
                label: const Text('Prev'),
                style: approvalsOutlinedButtonStyle(minHeight: 40),
              ),
              for (var n = start; n < start + window; n++)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: n == page
                      ? FilledButton(
                          key: Key('approvals-page-$n'),
                          onPressed: () => onPage(n),
                          style: FilledButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: AppColors.primary),
                          child: Text('$n'),
                        )
                      : OutlinedButton(
                          key: Key('approvals-page-$n'),
                          onPressed: () => onPage(n),
                          style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.border)),
                          child: Text('$n'),
                        ),
                ),
              OutlinedButton.icon(
                key: const Key('approvals-next'),
                onPressed: page >= pages ? null : () => onPage(page + 1),
                icon: const Icon(Icons.chevron_right, size: 16),
                label: const Text('Next'),
                iconAlignment: IconAlignment.end,
                style: approvalsOutlinedButtonStyle(minHeight: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Card building blocks (My Profile design language) ────────────────────────
// Every Approvals tab composes its cards from these, so Team Approvals,
// Attendance Approval, Face Registration, Delegation and Leave Cancellations
// read as one family — and as My Profile: the same coloured initials avatar,
// tinted ID pill, label-over-value facts (ProfileDisplayField), 14 px cards on a
// hairline border, divided zones, and a solid primary action.

/// The My Profile avatar palette (MyProfileModel.avatarColor), keyed the same way.
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

Color approvalsAvatarColor(String name) =>
    name.isEmpty ? _kAvatarPalette[0] : _kAvatarPalette[name.codeUnitAt(0) % _kAvatarPalette.length];

String approvalsInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

/// Coloured initials circle, as the My Profile header.
class ApprovalsAvatar extends StatelessWidget {
  const ApprovalsAvatar(this.name, {super.key, this.radius = 22});
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CircleAvatar(
          radius: radius,
          backgroundColor: approvalsAvatarColor(name),
          child: Text(
            approvalsInitials(name),
            style:
                AppTextStyles.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: radius * 0.72),
          ),
        ),
      );
}

/// Employee-ID pill (My Profile's `EMP-0042` chip).
class ApprovalsIdChip extends StatelessWidget {
  const ApprovalsIdChip(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration:
            BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Text(
          text,
          style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
      );
}

/// Small icon + text meta item (My Profile's branch / joined line).
class ApprovalsMeta extends StatelessWidget {
  const ApprovalsMeta(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary))),
        ],
      );
}

/// Tinted rounded icon tile (the section-header icon treatment).
class ApprovalsIconBox extends StatelessWidget {
  const ApprovalsIconBox(this.icon, {super.key, this.color, this.size = 36});
  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: size * 0.5, color: c),
    );
  }
}

/// Request-type row: icon tile, a bold title and a caption underneath.
class ApprovalsTypeRow extends StatelessWidget {
  const ApprovalsTypeRow({super.key, required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ApprovalsIconBox(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (subtitle != null && subtitle!.isNotEmpty && subtitle != title)
                  Text(subtitle!, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      );
}

/// Label-over-value facts, two per row (stacked on a narrow screen or at large
/// text) — My Profile's `ProfileDisplayField` grid, unchanged.
class ApprovalsFacts extends StatelessWidget {
  const ApprovalsFacts(this.facts, {super.key, this.wide = const {}});
  final List<(String, String)> facts;

  /// Labels whose value needs the full row (a date range, a long sentence).
  final Set<String> wide;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    var i = 0;
    while (i < facts.length) {
      final f = facts[i];
      Widget cell(int k) => ProfileDisplayField(label: facts[k].$1, value: facts[k].$2, padBottom: false);
      Widget row;
      if (wide.contains(f.$1)) {
        row = cell(i);
        i += 1;
      } else if (i + 1 < facts.length && !wide.contains(facts[i + 1].$1)) {
        row = ProfileTwoUp(left: cell(i), right: cell(i + 1));
        i += 2;
      } else {
        row = ProfileTwoUp(left: cell(i), right: const SizedBox.shrink());
        i += 1;
      }
      rows.add(Padding(padding: EdgeInsets.only(bottom: i < facts.length ? 12 : 0), child: row));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

/// A free-text block under a small label ("Reason", "Comment"…).
class ApprovalsNote extends StatelessWidget {
  const ApprovalsNote(this.label, this.text, {super.key, this.maxLines});
  final String label;
  final String text;
  final int? maxLines;

  @override
  Widget build(BuildContext context) =>
      ProfileDisplayField(label: label, value: text, padBottom: false, maxLines: maxLines);
}

/// The card: header (avatar, name, ID pill, meta, status badge) / body / footer,
/// separated by hairlines, exactly as My Profile's section cards are divided.
class ApprovalsRequestCard extends StatelessWidget {
  const ApprovalsRequestCard({
    super.key,
    required this.name,
    this.idText,
    this.meta = const [],
    this.badge,
    this.leading,
    required this.body,
    this.footer,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.semanticLabel,
  });

  final String name;
  final String? idText;
  final List<Widget> meta;
  final Widget? badge;

  /// e.g. a selection checkbox, before the avatar.
  final Widget? leading;
  final Widget body;
  final Widget? footer;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 320 || scale > 1.3;
      final identity = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.isEmpty ? 'Unknown' : name,
              style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
          if (idText != null || meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [if (idText != null) ApprovalsIdChip(idText!), ...meta],
            ),
          ],
          if (narrow && badge != null) ...[const SizedBox(height: 8), badge!],
        ],
      );
      return Semantics(
        container: true,
        label: semanticLabel,
        child: Material(
          color: selected ? AppColors.primary.withValues(alpha: 0.04) : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (leading != null) ...[leading!, const SizedBox(width: 6)],
                      ApprovalsAvatar(name),
                      const SizedBox(width: 12),
                      Expanded(child: identity),
                      if (!narrow && badge != null) ...[const SizedBox(width: 8), badge!],
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.border),
                Padding(padding: const EdgeInsets.all(14), child: body),
                if (footer != null) ...[
                  Divider(height: 1, color: AppColors.border),
                  Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 12), child: footer),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Footer actions: Reject / Approve side by side (stacked on a narrow screen or at
/// large text), 44 dp high, with a busy state. Approve is the solid primary action
/// (as My Profile's Save), Reject the outlined one.
class ApprovalsDecisionButtons extends StatelessWidget {
  const ApprovalsDecisionButtons({
    super.key,
    required this.onApprove,
    required this.onReject,
    this.approveKey,
    this.rejectKey,
    this.approveLabel = 'Approve',
    this.rejectLabel = 'Reject',
    this.busy = false,
  });

  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final Key? approveKey;
  final Key? rejectKey;
  final String approveLabel;
  final String rejectLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return LayoutBuilder(builder: (context, c) {
      final approve = FilledButton.icon(
        key: approveKey,
        onPressed: busy ? null : onApprove,
        icon: busy
            ? const SizedBox(
                width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check, size: 16),
        label: Text(approveLabel),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size(0, 44),
          textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
        ),
      );
      final reject = OutlinedButton.icon(
        key: rejectKey,
        onPressed: busy ? null : onReject,
        icon: const Icon(Icons.close, size: 16),
        label: Text(rejectLabel),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
          minimumSize: const Size(0, 44),
          textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
        ),
      );
      if (c.maxWidth < 260 || scale > 1.3) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [approve, const SizedBox(height: 8), reject]);
      }
      return Row(children: [Expanded(child: reject), const SizedBox(width: 10), Expanded(child: approve)]);
    });
  }
}

/// A My Profile-style section: icon + title header over a divided body.
/// (Thin wrapper so Approvals screens say what they mean.)
class ApprovalsSection extends StatelessWidget {
  const ApprovalsSection({super.key, required this.icon, required this.title, required this.child, this.trailing});
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ProfileSectionCard(icon: icon, title: title, trailing: trailing, child: child);
}

/// Section-tab label: icon + text (inherits the TabBar's selected / unselected
/// colour). Public so tests can read the label back.
class ApprovalsTabLabel extends StatelessWidget {
  const ApprovalsTabLabel(this.icon, this.label, {super.key});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
}

/// Text / outlined buttons in the app's primary colour (the theme's default is purple).
ButtonStyle approvalsTextButtonStyle({double minHeight = 44}) =>
    TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: Size(0, minHeight));

ButtonStyle approvalsOutlinedButtonStyle({double minHeight = 44}) => OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: BorderSide(color: AppColors.border),
      minimumSize: Size(0, minHeight),
    );
