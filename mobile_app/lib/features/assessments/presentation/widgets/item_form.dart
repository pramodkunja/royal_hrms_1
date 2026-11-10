import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/assessment_model.dart';
import 'assessment_video_preview.dart';

// ── True / False helper (web ItemsModal) ──────────────────────────────────────
// A UI helper only: a True/False question is an ordinary quiz item whose
// options are "True" / "False" with no C / D — the request is unchanged.

const kQuestionTypeMcq = 'mcq';
const kQuestionTypeTrueFalse = 'truefalse';

/// Web openEditItem: a quiz item reopens as True/False when option A is
/// "true", option B is "false" (any case) and there is no option C.
bool isTrueFalseQuestion({required String itemType, required String optionA, required String optionB, required String optionC}) =>
    itemType == AssessmentItemType.quiz &&
    optionA.toLowerCase() == 'true' &&
    optionB.toLowerCase() == 'false' &&
    optionC.isEmpty;

/// Web changeQuestionType("truefalse"): A "True", B "False", C/D cleared, and
/// a C/D correct answer falls back to A. Returns the correct option to use.
String applyTrueFalse({
  required TextEditingController a,
  required TextEditingController b,
  required TextEditingController c,
  required TextEditingController d,
  required String correctOption,
}) {
  a.text = 'True';
  b.text = 'False';
  c.text = '';
  d.text = '';
  return correctOption == 'c' || correctOption == 'd' ? 'a' : correctOption;
}

// ── Add/Edit item inline form ─────────────────────────────────────────────────

class ItemForm extends StatelessWidget {
  final bool isAdd;
  final String? error;
  final bool saving;
  final String itemType;
  final String correctOption;
  /// [kQuestionTypeMcq] or [kQuestionTypeTrueFalse] (quiz items only).
  final String questionType;
  final ValueChanged<String> onQuestionTypeChanged;
  final TextEditingController titleCtrl;
  final TextEditingController videoUrlCtrl;
  final TextEditingController durationCtrl;
  final TextEditingController questionCtrl;
  final TextEditingController optACtrl;
  final TextEditingController optBCtrl;
  final TextEditingController optCCtrl;
  final TextEditingController optDCtrl;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onCorrectOptionChanged;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const ItemForm({
    super.key,
    required this.isAdd,
    required this.error,
    required this.saving,
    required this.itemType,
    required this.correctOption,
    this.questionType = kQuestionTypeMcq,
    required this.onQuestionTypeChanged,
    required this.titleCtrl,
    required this.videoUrlCtrl,
    required this.durationCtrl,
    required this.questionCtrl,
    required this.optACtrl,
    required this.optBCtrl,
    required this.optCCtrl,
    required this.optDCtrl,
    required this.onTypeChanged,
    required this.onCorrectOptionChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  bool get _isVideo => itemType == AssessmentItemType.video;
  bool get _isTrueFalse => questionType == kQuestionTypeTrueFalse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isAdd ? 'Add Item' : 'Edit Item',
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (error != null) ...[
            _InlineError(message: error!),
            const SizedBox(height: 10),
          ],
          // Web's item form has no Order field: order is set automatically
          // (next number on add, the item's own order on edit).
          DropdownButtonFormField<String>(
            initialValue: itemType,
            decoration: _dec('Type *'),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: AssessmentItemType.video, child: Text('Video')),
              DropdownMenuItem(value: AssessmentItemType.quiz, child: Text('Quiz')),
            ],
            onChanged: (v) => onTypeChanged(v ?? AssessmentItemType.video),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: titleCtrl,
            maxLength: 200,
            decoration: _dec('Title *',
                hint: _isVideo ? 'e.g. Company Introduction' : 'e.g. Policy Quiz Q1'),
          ),
          if (_isVideo) ...[
            const SizedBox(height: 2),
            TextFormField(
              key: const Key('item-video-url'),
              controller: videoUrlCtrl,
              decoration: _dec('Video URL *', hint: 'https://youtu.be/...'),
              keyboardType: TextInputType.url,
            ),
            // Web VideoPreview, updated as the URL is typed.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: videoUrlCtrl,
              builder: (_, v, __) => AssessmentVideoPreview(url: v.text),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec('Duration (seconds)', hint: '180'),
            ),
          ] else ...[
            const SizedBox(height: 2),
            // Web "Question Type *": Multiple Choice / True / False.
            DropdownButtonFormField<String>(
              key: ValueKey('item-question-type-$questionType'),
              initialValue: questionType,
              decoration: _dec('Question Type *'),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: kQuestionTypeMcq, child: Text('Multiple Choice')),
                DropdownMenuItem(value: kQuestionTypeTrueFalse, child: Text('True / False')),
              ],
              onChanged: saving ? null : (v) => onQuestionTypeChanged(v ?? kQuestionTypeMcq),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: questionCtrl,
              maxLines: 2,
              decoration: _dec('Question *', hint: 'e.g. What is the notice period?'),
            ),
            const SizedBox(height: 10),
            // True/False: A and B are fixed ("True" / "False", read-only) and
            // C / D are not offered — as web.
            Row(children: [
              Expanded(
                  child: TextFormField(
                      key: const Key('item-option-a'),
                      controller: optACtrl,
                      readOnly: _isTrueFalse,
                      decoration: _dec('Option A *', hint: _isTrueFalse ? 'True' : null))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextFormField(
                      key: const Key('item-option-b'),
                      controller: optBCtrl,
                      readOnly: _isTrueFalse,
                      decoration: _dec('Option B *', hint: _isTrueFalse ? 'False' : null))),
            ]),
            if (!_isTrueFalse) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(key: const Key('item-option-c'), controller: optCCtrl, decoration: _dec('Option C'))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(key: const Key('item-option-d'), controller: optDCtrl, decoration: _dec('Option D'))),
              ]),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    // Rebuilt when the question type or the answer changes
                    // (e.g. a C/D answer falling back to A for True/False).
                    key: ValueKey('item-correct-$questionType-$correctOption'),
                    initialValue: correctOption,
                    decoration: _dec('Correct Option *'),
                    items: _isTrueFalse
                        ? const [
                            DropdownMenuItem(value: 'a', child: Text('True')),
                            DropdownMenuItem(value: 'b', child: Text('False')),
                          ]
                        : const [
                            DropdownMenuItem(value: 'a', child: Text('Option A')),
                            DropdownMenuItem(value: 'b', child: Text('Option B')),
                            DropdownMenuItem(value: 'c', child: Text('Option C')),
                            DropdownMenuItem(value: 'd', child: Text('Option D')),
                          ],
                    onChanged: (v) => onCorrectOptionChanged(v ?? 'a'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onCancel,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11)),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: saving ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isAdd ? 'Add Item' : 'Update Item'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: true,
    labelStyle: AppTextStyles.caption,
    hintStyle: AppTextStyles.caption,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  );
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
          const SizedBox(width: 6),
          Expanded(child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
        ],
      ),
    );
  }
}
