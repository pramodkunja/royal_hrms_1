import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/models/assessment_portal_models.dart';

/// One item while taking an assessment (web /onboarding/assessments panel).
/// A quiz shows its options and, once answered, the saved answer and
/// whether it was correct; a video is opened and then marked as watched.
/// Saved items are read-only — the answer is final, as on web.
class AssessmentItemView extends StatelessWidget {
  final AssessmentPortalItem item;
  final int index;
  final int total;
  final AssessmentItemResponse? response;
  final bool done;

  /// The option picked but not yet submitted (kept by the screen).
  final String? selected;
  final ValueChanged<String> onSelect;
  final bool saving;
  final String? error;
  final VoidCallback onSave;
  final VoidCallback onOpenVideo;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Shown on the last item once every item is done.
  final VoidCallback? onSubmitAssessment;
  final bool submitting;

  const AssessmentItemView({
    super.key,
    required this.item,
    required this.index,
    required this.total,
    required this.response,
    required this.done,
    required this.selected,
    required this.onSelect,
    required this.saving,
    required this.error,
    required this.onSave,
    required this.onOpenVideo,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmitAssessment,
    required this.submitting,
  });

  bool get _isQuiz => item.type == AssessmentItemType.quiz;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
            'Item ${index + 1} of $total${item.sectionTitle != null ? ' · ${item.sectionTitle}' : ''}',
            style: AppTextStyles.caption),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : (index + 1) / total,
            minHeight: 4,
            color: AppColors.primary,
            backgroundColor: AppColors.border,
          ),
        ),
        const SizedBox(height: 16),
        Text(
            item.title.isNotEmpty
                ? item.title
                : (_isQuiz ? 'Question' : 'Video'),
            style: AppTextStyles.h4),
        const SizedBox(height: 12),
        if (_isQuiz) ..._quiz() else ..._video(),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!,
              key: const Key('assessment-item-error'),
              style: AppTextStyles.body.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 20),
        if (!done)
          AppButton(
            label: _isQuiz ? 'Submit answer' : 'Mark as watched',
            leadingIcon: _isQuiz ? Icons.check : Icons.check_circle_outline,
            isLoading: saving,
            onPressed: saving || (_isQuiz && selected == null) ? null : onSave,
          )
        else if (onSubmitAssessment != null)
          AppButton(
            label: 'Submit assessment',
            leadingIcon: Icons.send_outlined,
            isLoading: submitting,
            onPressed: submitting ? null : onSubmitAssessment,
          ),
        const SizedBox(height: 10),
        Row(children: [
          if (onPrevious != null)
            TextButton.icon(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous')),
          const Spacer(),
          if (onNext != null)
            TextButton.icon(
              onPressed: onNext,
              icon: const Text('Next item'),
              label: const Icon(Icons.chevron_right),
            ),
        ]),
      ],
    );
  }

  List<Widget> _quiz() => [
        if (item.question.isNotEmpty) ...[
          Text(item.question, style: AppTextStyles.bodyLarge),
          const SizedBox(height: 14),
        ],
        for (final (key, text) in item.options) _option(key, text),
        if (done && response != null) ...[
          const SizedBox(height: 8),
          _verdict(),
        ],
      ];

  Widget _option(String key, String text) {
    final chosen = done ? response?.selectedOption == key : selected == key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: chosen
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: Key('assessment-option-$key'),
          borderRadius: BorderRadius.circular(12),
          onTap: done || saving ? null : () => onSelect(key),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: chosen ? AppColors.primary : AppColors.border,
                  width: chosen ? 2 : 1),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    chosen ? AppColors.primary : AppColors.backgroundMid,
                child: Text(key.toUpperCase(),
                    style: AppTextStyles.label.copyWith(
                        color: chosen ? Colors.white : AppColors.textPrimary)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: AppTextStyles.body)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _verdict() {
    final correct = response!.isCorrect == true;
    final color = correct ? AppColors.success : AppColors.error;
    return Container(
      key: const Key('assessment-verdict'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: correct ? AppColors.successContainer : AppColors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(correct ? Icons.check_circle : Icons.cancel,
            color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${correct ? 'Correct' : 'Incorrect'} · You answered option ${response!.selectedOption.toUpperCase()}'
            '${response!.scoreAwarded > 0 ? ' · +${response!.scoreAwarded} pts' : ''}',
            style: AppTextStyles.body
                .copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  List<Widget> _video() => [
        if (item.durationSecs != null) ...[
          Text('Duration: ${(item.durationSecs! / 60).ceil()} min',
              style: AppTextStyles.bodySecondary),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: item.videoUrl.isEmpty ? null : onOpenVideo,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Open video'),
        ),
        if (done) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 18),
            const SizedBox(width: 6),
            Text('You have watched this video.',
                style: AppTextStyles.body.copyWith(color: AppColors.success)),
          ]),
        ],
      ];
}
