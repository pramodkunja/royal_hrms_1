import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_app_bar.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart';
import '../../data/models/training_models.dart';
import 'training_pdf_view.dart';

/// Status colours as web STATUS_BADGE: info / primary / success / error / warn.
Color trainingStatusColor(TrainingStatus s) => switch (s) {
      TrainingStatus.assigned => AppColors.info,
      TrainingStatus.inProgress => AppColors.primary,
      TrainingStatus.completed => AppColors.success,
      TrainingStatus.failed => AppColors.error,
      TrainingStatus.overdue => AppColors.warning,
    };

class TrainingBadge extends StatelessWidget {
  const TrainingBadge({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  factory TrainingBadge.status(TrainingStatus s) => TrainingBadge(label: s.label, color: trainingStatusColor(s));

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}

/// A white rounded card used across the training screens.
class TrainingCard extends StatelessWidget {
  const TrainingCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: child,
            ),
          ),
        ),
      );
}

/// Centered grey message (inline notes inside a tab, e.g. a section hint).
class TrainingNote extends StatelessWidget {
  const TrainingNote(this.text, {super.key, this.icon = Icons.info_outline});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.textHint),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: AppTextStyles.bodySecondary),
          ],
        ),
      );
}

// ── Task 102 building blocks ────────────────────────────────────────────────

/// Training's empty / no-match / error / denied states, on the shared
/// [ApprovalsEmptyState]. Failure never wears the calm "empty" look.
class TrainingStateView {
  TrainingStateView._();

  static Widget empty({required String title, String? message, IconData icon = Icons.school_outlined, Key? key, bool compact = false}) =>
      ApprovalsEmptyState(key: key, kind: ApprovalsStateKind.empty, title: title, message: message, icon: icon, compact: compact);

  static Widget noMatch({required String title, String? message, required VoidCallback onClear, Key? key, String actionLabel = 'Clear search'}) =>
      ApprovalsEmptyState(
          key: key,
          kind: ApprovalsStateKind.noMatch,
          title: title,
          message: message,
          actionLabel: actionLabel,
          onAction: onClear,
          compact: true);

  /// A caught load failure: access / disabled module -> denied (no Retry),
  /// connection -> offline, anything else -> error. Server text is the message.
  static Widget error(Object e, {VoidCallback? onRetry, String what = 'this', Key? key, bool compact = true}) {
    final base = ApprovalsEmptyState.forError(e, key: key, onRetry: onRetry, compact: compact);
    if (base.kind == ApprovalsStateKind.denied) return base;
    return ApprovalsEmptyState(
      key: base.key,
      kind: base.kind,
      title: base.kind == ApprovalsStateKind.offline ? 'No connection' : 'Couldn’t load $what',
      message: base.message,
      actionLabel: base.actionLabel,
      onAction: base.onAction,
      compact: compact,
    );
  }
}

/// Loading, in the shared language.
class TrainingLoading extends StatelessWidget {
  const TrainingLoading(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Center(child: ApprovalsLoading(label: label));
}

/// Slim progress bar with its value stated in text elsewhere (decorative for
/// screen readers, HO-46).
class TrainingProgressBar extends StatelessWidget {
  const TrainingProgressBar(this.percent, {super.key, this.color, this.height = 6});
  final int percent;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: LinearProgressIndicator(
            value: percent.clamp(0, 100) / 100,
            minHeight: height,
            backgroundColor: AppColors.backgroundLow,
            color: color ?? AppColors.primary,
          ),
        ),
      );
}

/// Icon + text fact, wraps inside a [Wrap] and never overflows.
class TrainingFact extends StatelessWidget {
  const TrainingFact(this.icon, this.text, {super.key, this.color, this.strong = false});
  final IconData icon;
  final String text;
  final Color? color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 5),
        Flexible(
          child: Text(text,
              style: AppTextStyles.caption.copyWith(color: c, fontWeight: strong ? FontWeight.w600 : FontWeight.w500)),
        ),
      ],
    );
  }
}

/// Section header: tinted icon tile + title (+ optional subtitle).
class TrainingSectionHeader extends StatelessWidget {
  const TrainingSectionHeader(this.icon, this.title, {super.key, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ApprovalsIconBox(icon, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                if ((subtitle ?? '').isNotEmpty)
                  Text(subtitle!, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      );
}

/// Calm full-width info / warning strip.
class TrainingBanner extends StatelessWidget {
  const TrainingBanner({super.key, required this.text, required this.icon, required this.color, required this.background});
  final String text;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.4))),
          ],
        ),
      );
}

/// Large text (>1.3x): cards drop their decorative leading icon and chevron so the
/// title keeps a readable column.
bool trainingCompact(BuildContext context) => MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;

/// True when buttons with these [labels] (plus [icon] widths and padding) fit one
/// line in [maxWidth] at the current text scale. Measured, not a fixed breakpoint.
bool trainingActionsFit(BuildContext context, double maxWidth, List<String> labels,
    {double chrome = 40, double gap = 8, double extra = 0}) {
  var need = extra;
  for (final l in labels) {
    final tp = TextPainter(
      text: TextSpan(text: l, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    need += tp.width + chrome + gap;
  }
  return need <= maxWidth;
}

ButtonStyle trainingFilledStyle({Color? color}) => FilledButton.styleFrom(
      backgroundColor: color ?? AppColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
    );

ButtonStyle trainingOutlinedStyle({Color? color}) => OutlinedButton.styleFrom(
      foregroundColor: color ?? AppColors.primary,
      side: BorderSide(color: color?.withValues(alpha: 0.55) ?? AppColors.border),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
    );

ButtonStyle trainingTextStyle({Color? color}) => TextButton.styleFrom(
      foregroundColor: color ?? AppColors.primary,
      minimumSize: const Size(0, 44),
      textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
    );

/// Outlined input used by every Training form and dialog.
InputDecoration trainingInput(String label, {String? hint, String? error, String? helper, Widget? prefix}) => InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      helperText: helper,
      helperMaxLines: 3,
      errorMaxLines: 3,
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      prefixIcon: prefix,
      labelStyle: TextStyle(color: AppColors.textSecondary),
      floatingLabelStyle: TextStyle(color: AppColors.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
    );

/// White-surface dialog: no Material 3 tint, primary-coloured controls. Actions
/// stack automatically (AlertDialog's OverflowBar) when they do not fit.
class TrainingDialog extends StatelessWidget {
  const TrainingDialog({super.key, required this.title, required this.content, required this.actions, this.icon});
  final String title;
  final Widget content;
  final List<Widget> actions;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
        contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            if (icon != null) ...[ApprovalsIconBox(icon!, size: 34), const SizedBox(width: 10)],
            Expanded(child: Text(title, style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700))),
          ],
        ),
        content: DefaultTextStyle.merge(
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.45),
          child: content,
        ),
        actions: actions,
      );
}

/// One assignment (progress tab and reports): person (avatar, name, id line),
/// optional course, status chip, progress bar, due / completed / best score
/// and optional actions. Stays inside its card at any width or text size.
class TrainingAssignmentCard extends StatelessWidget {
  const TrainingAssignmentCard({super.key, required this.row, this.showCourse = false, this.actions = const []});
  final TrainingAssignmentRow row;
  final bool showCourse;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final c = r.completedAt;
    final done = c?.substring(0, c.length.clamp(0, 10));
    final overdue = r.status == TrainingStatus.overdue;
    return TrainingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ApprovalsAvatar(r.employee.name, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.employee.name, style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                    if (r.employee.subtitle.isNotEmpty)
                      Text(r.employee.subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    if (showCourse)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(r.courseTitle,
                            style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    Padding(padding: const EdgeInsets.only(top: 6), child: TrainingBadge.status(r.status)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TrainingProgressBar(r.progressPercent, color: trainingStatusColor(r.status)),
          const SizedBox(height: 4),
          Text('${r.progressPercent}% progress', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              TrainingFact(Icons.event_outlined, 'Due ${r.dueDate ?? '—'}',
                  color: overdue ? AppColors.warning : null, strong: overdue),
              TrainingFact(Icons.check_circle_outline, 'Completed ${done ?? '—'}',
                  color: done != null ? AppColors.success : null),
              TrainingFact(Icons.emoji_events_outlined, 'Best score ${r.bestScorePercent == null ? '—' : '${r.bestScorePercent}%'}'),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 4, children: actions),
            ),
          ],
        ],
      ),
    );
  }
}

/// Asks before an action that changes production data. Returns true only on
/// an explicit confirm.
Future<bool> confirmTrainingAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => TrainingDialog(
      title: title,
      icon: destructive ? Icons.delete_outline : Icons.help_outline,
      content: Text(message),
      actions: [
        TextButton(
            style: trainingTextStyle(),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
        FilledButton(
          style: trainingFilledStyle(color: destructive ? AppColors.error : AppColors.primary),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Read-only PDF preview of a course document (web MaterialPreview →
/// PdfFrame). Uses TrainingPdfView (app-private temp copy, deleted on close
/// and at sign-out); no learner progress is recorded (admin preview).
class TrainingPdfPreviewScreen extends StatelessWidget {
  const TrainingPdfPreviewScreen({super.key, required this.material});
  final TrainingMaterial material;

  static Future<void> open(BuildContext context, TrainingMaterial material) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TrainingPdfPreviewScreen(material: material)));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: BlueAppBar(title: material.title),
        body: TrainingPdfView(materialId: material.id, fileFormat: material.fileFormat),
      );
}

/// yyyy-MM-dd for the API.
String trainingIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
