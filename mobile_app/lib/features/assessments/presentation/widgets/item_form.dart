import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/assessment_model.dart';

// ── Add/Edit item inline form ─────────────────────────────────────────────────

class ItemForm extends StatelessWidget {
  final bool isAdd;
  final String? error;
  final bool saving;
  final String itemType;
  final String correctOption;
  final TextEditingController titleCtrl;
  final TextEditingController orderCtrl;
  final TextEditingController videoUrlCtrl;
  final TextEditingController durationCtrl;
  final TextEditingController questionCtrl;
  final TextEditingController optACtrl;
  final TextEditingController optBCtrl;
  final TextEditingController optCCtrl;
  final TextEditingController optDCtrl;
  final TextEditingController passScoreCtrl;
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
    required this.titleCtrl,
    required this.orderCtrl,
    required this.videoUrlCtrl,
    required this.durationCtrl,
    required this.questionCtrl,
    required this.optACtrl,
    required this.optBCtrl,
    required this.optCCtrl,
    required this.optDCtrl,
    required this.passScoreCtrl,
    required this.onTypeChanged,
    required this.onCorrectOptionChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  bool get _isVideo => itemType == AssessmentItemType.video;

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
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: itemType,
                  decoration: _dec('Type *'),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: AssessmentItemType.video, child: Text('Video')),
                    DropdownMenuItem(value: AssessmentItemType.quiz, child: Text('Quiz')),
                  ],
                  onChanged: (v) => onTypeChanged(v ?? AssessmentItemType.video),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Order'),
                ),
              ),
            ],
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
              controller: videoUrlCtrl,
              decoration: _dec('Video URL *', hint: 'https://youtu.be/...'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec('Duration (seconds)', hint: '180'),
            ),
          ] else ...[
            const SizedBox(height: 2),
            TextFormField(
              controller: questionCtrl,
              maxLines: 2,
              decoration: _dec('Question *', hint: 'e.g. What is the notice period?'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: optACtrl, decoration: _dec('Option A *'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: optBCtrl, decoration: _dec('Option B *'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: optCCtrl, decoration: _dec('Option C'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: optDCtrl, decoration: _dec('Option D'))),
            ]),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: correctOption,
                    decoration: _dec('Correct Option *'),
                    items: const [
                      DropdownMenuItem(value: 'a', child: Text('Option A')),
                      DropdownMenuItem(value: 'b', child: Text('Option B')),
                      DropdownMenuItem(value: 'c', child: Text('Option C')),
                      DropdownMenuItem(value: 'd', child: Text('Option D')),
                    ],
                    onChanged: (v) => onCorrectOptionChanged(v ?? 'a'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: passScoreCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Points', hint: '0'),
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
