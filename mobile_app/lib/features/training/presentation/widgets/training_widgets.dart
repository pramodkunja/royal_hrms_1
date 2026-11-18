import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: child,
            ),
          ),
        ),
      );
}

/// Centered grey message (loading-free empty states inside a tab).
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

/// One assignment (progress tab and reports): employee, optional course,
/// status, progress bar, due / completed / best score, optional actions.
class TrainingAssignmentCard extends StatelessWidget {
  const TrainingAssignmentCard({super.key, required this.row, this.showCourse = false, this.actions = const []});
  final TrainingAssignmentRow row;
  final bool showCourse;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final facts = [
      'Due ${r.dueDate ?? '—'}',
      'Completed ${r.completedAt == null ? '—' : r.completedAt!.substring(0, r.completedAt!.length.clamp(0, 10))}',
      'Best score ${r.bestScorePercent == null ? '—' : '${r.bestScorePercent}%'}',
    ];
    return TrainingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.employee.name,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    if (r.employee.subtitle.isNotEmpty)
                      Text(r.employee.subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    if (showCourse)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(r.courseTitle,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: TrainingBadge.status(r.status)),
            ],
          ),
          const SizedBox(height: 10),
          // HO-46: the text below states the progress; the bar is decorative for
          // screen readers (it used to be read before the employee's name).
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (r.progressPercent.clamp(0, 100)) / 100,
                minHeight: 6,
                backgroundColor: AppColors.backgroundLow,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('${r.progressPercent}% progress', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final f in facts) Text(f, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 4),
            // HO-46: actions sit at the right edge of the card.
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(alignment: WrapAlignment.end, spacing: 8, children: actions),
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
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: destructive ? AppColors.error : AppColors.primary),
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
        appBar: AppBar(title: Text(material.title, overflow: TextOverflow.ellipsis)),
        body: TrainingPdfView(materialId: material.id, fileFormat: material.fileFormat),
      );
}

/// yyyy-MM-dd for the API.
String trainingIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
