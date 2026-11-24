import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'approvals_ui.dart';

// Approval-specific building blocks. My Profile supplies the typography, colours,
// surfaces and buttons; the *composition* here is an inbox, not a form: a person,
// what they are asking for in plain language (icon + headline, dates / amount as
// natural lines, short quoted reason), and the decision actions — hierarchy and
// whitespace instead of a bordered box around every value.

/// The card: person on top, the request below, optional footer actions.
class ApprovalsCardShell extends StatelessWidget {
  const ApprovalsCardShell({
    super.key,
    required this.name,
    this.idText,
    this.meta,
    this.badge,
    this.note,
    this.leading,
    required this.child,
    this.footer,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.semanticLabel,
  });

  final String name;
  final String? idText;

  /// Department / branch, shown after the id.
  final String? meta;
  final Widget? badge;

  /// Subtle line under the badge (e.g. "Submitted 13 Nov 2026").
  final Widget? note;

  /// e.g. the selection checkbox.
  final Widget? leading;
  final Widget child;
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
      final who = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.isEmpty ? 'Unknown' : name,
              style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
          if ((idText ?? '').isNotEmpty || (meta ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if ((idText ?? '').isNotEmpty)
                  Text(idText!,
                      style:
                          AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                if ((idText ?? '').isNotEmpty && (meta ?? '').isNotEmpty)
                  Text('·', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                if ((meta ?? '').isNotEmpty)
                  Text(meta!, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ],
          if (narrow && badge != null) ...[const SizedBox(height: 6), badge!],
          if (narrow && note != null) ...[const SizedBox(height: 2), note!],
        ],
      );
      return Semantics(
        container: true,
        label: semanticLabel,
        child: Material(
          color: selected ? AppColors.primary.withValues(alpha: 0.04) : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (leading != null) ...[leading!, const SizedBox(width: 4)],
                      ApprovalsAvatar(name, radius: 21),
                      const SizedBox(width: 12),
                      Expanded(child: who),
                      if (!narrow && (badge != null || note != null)) ...[
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (badge != null) badge!,
                            if (note != null) ...[const SizedBox(height: 4), note!]
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  child,
                  if (footer != null) ...[
                    const SizedBox(height: 10),
                    Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
                    const SizedBox(height: 8),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// "What they are asking for": an icon tile, a bold headline and small chips.
class ApprovalsHeadline extends StatelessWidget {
  const ApprovalsHeadline({super.key, required this.icon, required this.title, this.chips = const [], this.tone});
  final IconData icon;
  final String title;
  final List<Widget> chips;
  final Color? tone;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ApprovalsIconBox(icon, color: tone, size: 34),
          const SizedBox(width: 10),
          // Title and chips share the line and wrap together when they must.
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 15)),
                ...chips,
              ],
            ),
          ),
        ],
      );
}

/// A small quiet fact chip: "Full Day", "2 Days", "Travel", "1 LOP".
class ApprovalsChip extends StatelessWidget {
  const ApprovalsChip(this.text, {super.key, this.icon, this.tone = ApprovalsTone.neutral});
  final String text;
  final IconData? icon;
  final ApprovalsTone tone;

  @override
  Widget build(BuildContext context) {
    final c = approvalsToneColor(tone);
    final neutral = tone == ApprovalsTone.neutral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: neutral ? AppColors.backgroundLow : c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: neutral ? AppColors.textSecondary : c),
            const SizedBox(width: 4)
          ],
          Flexible(
            child: Text(text,
                style: AppTextStyles.caption
                    .copyWith(color: neutral ? AppColors.textPrimary : c, fontWeight: FontWeight.w600, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}

/// One natural line: a small icon and the text ("📅 20 Nov – 21 Nov 2026").
class ApprovalsInfoRow extends StatelessWidget {
  const ApprovalsInfoRow(this.icon, this.text, {super.key, this.strong = false});
  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
                    color: AppColors.textPrimary)),
          ),
        ],
      );
}

/// A big number with a caption — an expense amount, a match score.
class ApprovalsKeyFigure extends StatelessWidget {
  const ApprovalsKeyFigure(this.value, {super.key, this.caption});
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
              child: Text(value,
                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
          if ((caption ?? '').isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(child: Text(caption!, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary))),
          ],
        ],
      );
}

/// The employee's words, short: a soft left rule and quiet text.
class ApprovalsQuote extends StatelessWidget {
  const ApprovalsQuote(this.text, {super.key, this.maxLines = 2});
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 10),
        decoration:
            BoxDecoration(border: Border(left: BorderSide(color: AppColors.primary.withValues(alpha: 0.25), width: 3))),
        child: Text(text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4)),
      );
}

/// Subtle secondary line ("Submitted 13 Nov 2026").
class ApprovalsFineprint extends StatelessWidget {
  const ApprovalsFineprint(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.textHint));
}

/// The action row: Details · Reject · Approve in one line when there is room,
/// otherwise Details on its own with the two decisions stacked, all ≥ 44 dp.
class ApprovalsActionRow extends StatelessWidget {
  const ApprovalsActionRow({
    super.key,
    this.onDetails,
    this.onReject,
    this.onApprove,
    this.detailsKey,
    this.rejectKey,
    this.approveKey,
    this.busy = false,
    this.approveLabel = 'Approve',
    this.rejectLabel = 'Reject',
  });

  final VoidCallback? onDetails;
  final VoidCallback? onReject;
  final VoidCallback? onApprove;
  final Key? detailsKey;
  final Key? rejectKey;
  final Key? approveKey;
  final bool busy;
  final String approveLabel;
  final String rejectLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final details = onDetails == null
          ? null
          : TextButton.icon(
              key: detailsKey,
              onPressed: onDetails,
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('Details'),
              style: approvalsTextButtonStyle(),
            );
      final reject = onReject == null
          ? null
          : OutlinedButton(
              key: rejectKey,
              onPressed: busy ? null : onReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.55)),
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
              ),
              child: Text(rejectLabel),
            );
      final approve = onApprove == null
          ? null
          : FilledButton(
              key: approveKey,
              onPressed: busy ? null : onApprove,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
              ),
              child: busy
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(approveLabel),
            );
      // One line only when the three controls measurably fit (font- and
      // text-scale-independent); otherwise Details sits above full-width buttons.
      double textWidth(String t, {FontWeight w = FontWeight.w600}) {
        final tp = TextPainter(
          text: TextSpan(text: t, style: AppTextStyles.bodySmall.copyWith(fontWeight: w)),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        return tp.width;
      }

      final need = (onDetails == null ? 0 : textWidth('Details') + 16 + 8 + 24 + 12) +
          (onReject == null ? 0 : textWidth(rejectLabel) + 32 + 8) +
          (onApprove == null ? 0 : (busy ? 16 : textWidth(approveLabel)) + 36) +
          8;
      final inOneLine = need <= c.maxWidth;
      if (inOneLine) {
        return Row(children: [
          if (details != null) details,
          const Spacer(),
          if (reject != null) reject,
          if (reject != null && approve != null) const SizedBox(width: 8),
          if (approve != null) approve,
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (details != null) Align(alignment: Alignment.centerLeft, child: details),
        if (reject != null || approve != null) ...[
          const SizedBox(height: 4),
          if (reject != null) reject,
          if (reject != null && approve != null) const SizedBox(height: 8),
          if (approve != null) approve,
        ],
      ]);
    });
  }
}

// ── Empty / no-match / error / denied states ──────────────────────────────────

enum ApprovalsStateKind { empty, noMatch, error, denied, offline }

/// One component for every "nothing to show" case, so each reads differently:
/// *empty* is calm and positive, *noMatch* offers to clear the filters, *error*
/// and *offline* are amber/red with Retry (never a success look), *denied* is a
/// lock with no Retry.
class ApprovalsEmptyState extends StatelessWidget {
  const ApprovalsEmptyState({
    super.key,
    required this.kind,
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final ApprovalsStateKind kind;
  final String title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Less vertical padding (inside a tab that already has content above).
  final bool compact;

  /// The state for a caught load [error]: access / disabled-module → denied (no
  /// Retry), connection → offline, anything else → error; the server's own text
  /// is the message.
  factory ApprovalsEmptyState.forError(Object error,
      {Key? key, VoidCallback? onRetry, bool compact = false, String what = 'requests'}) {
    final message = moduleDisabledMessage(error) ?? userFriendlyMessage(error);
    switch (appErrorKind(error)) {
      case AppErrorKind.moduleDisabled:
        return ApprovalsEmptyState(
            key: key ?? const Key('module-disabled'),
            kind: ApprovalsStateKind.denied,
            title: 'Not enabled for your company',
            message: message,
            icon: Icons.block_outlined,
            compact: compact);
      case AppErrorKind.forbidden:
        return ApprovalsEmptyState(
            key: key ?? const Key('access-denied'),
            kind: ApprovalsStateKind.denied,
            title: 'Access denied',
            message: message,
            icon: Icons.lock_outline,
            compact: compact);
      case AppErrorKind.network:
        return ApprovalsEmptyState(
            key: key,
            kind: ApprovalsStateKind.offline,
            title: 'No connection',
            message: message,
            actionLabel: onRetry == null ? null : 'Retry',
            onAction: onRetry,
            compact: compact);
      case AppErrorKind.server:
      case AppErrorKind.unknown:
        return ApprovalsEmptyState(
            key: key,
            kind: ApprovalsStateKind.error,
            title: 'Couldn’t load $what',
            message: message,
            actionLabel: onRetry == null ? null : 'Retry',
            onAction: onRetry,
            compact: compact);
    }
  }

  (Color, IconData) get _look => switch (kind) {
        ApprovalsStateKind.empty => (AppColors.success, icon ?? Icons.task_alt),
        ApprovalsStateKind.noMatch => (AppColors.primary, icon ?? Icons.filter_alt_off_outlined),
        ApprovalsStateKind.error => (AppColors.error, icon ?? Icons.error_outline),
        ApprovalsStateKind.offline => (AppColors.warning, icon ?? Icons.wifi_off_outlined),
        ApprovalsStateKind.denied => (AppColors.textSecondary, icon ?? Icons.lock_outline),
      };

  @override
  Widget build(BuildContext context) {
    final (tone, glyph) = _look;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 28 : 44, horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A calm "illustration": the icon on two soft rings.
            SizedBox(
              width: 116,
              height: 116,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(decoration: BoxDecoration(shape: BoxShape.circle, color: tone.withValues(alpha: 0.06))),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: tone.withValues(alpha: 0.11)),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: tone.withValues(alpha: 0.25)),
                    ),
                    child: Icon(glyph, size: 28, color: tone),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            if ((message ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(message!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.45)),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              kind == ApprovalsStateKind.noMatch
                  ? OutlinedButton.icon(
                      key: const Key('approvals-empty-action'),
                      onPressed: onAction,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: Text(actionLabel!),
                      style: approvalsOutlinedButtonStyle(),
                    )
                  : FilledButton.icon(
                      key: const Key('approvals-empty-action'),
                      onPressed: onAction,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(actionLabel!),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(0, 44)),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading, in the same visual language: a quiet spinner and a line of text.
class ApprovalsLoading extends StatelessWidget {
  const ApprovalsLoading({super.key, this.label = 'Loading requests…'});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary)),
            const SizedBox(height: 14),
            Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
}
