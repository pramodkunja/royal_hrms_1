import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/assessment_model.dart';
import '../providers/assessments_providers.dart';
import 'item_form.dart';
import 'item_row.dart';

/// Mirrors the reference web screen's ItemsModal — manage the video/quiz
/// items that make up one assessment. Items are fetched lazily (only while
/// this dialog is open) via the `assessmentItemsProvider` family.
class ItemsManagerDialog extends ConsumerStatefulWidget {
  final AssessmentModel assessment;
  const ItemsManagerDialog({super.key, required this.assessment});

  @override
  ConsumerState<ItemsManagerDialog> createState() => _ItemsManagerDialogState();
}

class _ItemsManagerDialogState extends ConsumerState<ItemsManagerDialog> {
  bool _showForm = false;
  AssessmentItemModel? _editTarget;
  String? _deletingId;

  late TextEditingController _titleCtrl;
  late TextEditingController _orderCtrl;
  late TextEditingController _videoUrlCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _questionCtrl;
  late TextEditingController _optACtrl;
  late TextEditingController _optBCtrl;
  late TextEditingController _optCCtrl;
  late TextEditingController _optDCtrl;
  late TextEditingController _passScoreCtrl;
  String _itemType = AssessmentItemType.video;
  String _correctOption = 'a';
  bool _saving = false;
  String? _error;

  String get _assessmentId => widget.assessment.id;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _orderCtrl = TextEditingController();
    _videoUrlCtrl = TextEditingController();
    _durationCtrl = TextEditingController();
    _questionCtrl = TextEditingController();
    _optACtrl = TextEditingController();
    _optBCtrl = TextEditingController();
    _optCCtrl = TextEditingController();
    _optDCtrl = TextEditingController();
    _passScoreCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _orderCtrl.dispose();
    _videoUrlCtrl.dispose();
    _durationCtrl.dispose();
    _questionCtrl.dispose();
    _optACtrl.dispose();
    _optBCtrl.dispose();
    _optCCtrl.dispose();
    _optDCtrl.dispose();
    _passScoreCtrl.dispose();
    super.dispose();
  }

  void _fillControllers(AssessmentItemFormData d) {
    _titleCtrl.text = d.title;
    _orderCtrl.text = '${d.order}';
    _videoUrlCtrl.text = d.videoUrl;
    _durationCtrl.text = d.durationSecs?.toString() ?? '';
    _questionCtrl.text = d.question;
    _optACtrl.text = d.optionA;
    _optBCtrl.text = d.optionB;
    _optCCtrl.text = d.optionC;
    _optDCtrl.text = d.optionD;
    _passScoreCtrl.text = '${d.passScore}';
    _itemType = d.itemType;
    _correctOption = d.correctOption.isEmpty ? 'a' : d.correctOption;
  }

  void _openAdd() {
    final items = ref.read(assessmentItemsProvider(_assessmentId)).valueOrNull ?? [];
    final nextOrder = items.isEmpty
        ? 1
        : items.map((i) => i.order).reduce((a, b) => a > b ? a : b) + 1;
    setState(() {
      _editTarget = null;
      _fillControllers(AssessmentItemFormData(order: nextOrder));
      _showForm = true;
      _error = null;
    });
  }

  void _openEdit(AssessmentItemModel item) {
    setState(() {
      _editTarget = item;
      _fillControllers(AssessmentItemFormData.fromModel(item));
      _showForm = true;
      _error = null;
    });
  }

  void _closeForm() => setState(() {
    _showForm = false;
    _error = null;
  });

  Future<void> _submit() async {
    final form = AssessmentItemFormData(
      itemType: _itemType,
      order: int.tryParse(_orderCtrl.text.trim()) ?? 1,
      title: _titleCtrl.text,
      videoUrl: _videoUrlCtrl.text,
      durationSecs: int.tryParse(_durationCtrl.text.trim()),
      question: _questionCtrl.text,
      optionA: _optACtrl.text,
      optionB: _optBCtrl.text,
      optionC: _optCCtrl.text,
      optionD: _optDCtrl.text,
      correctOption: _correctOption,
      passScore: int.tryParse(_passScoreCtrl.text.trim()) ?? 0,
    );
    final validationError = form.validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final notifier = ref.read(assessmentItemsProvider(_assessmentId).notifier);
    final result = _editTarget == null
        ? await notifier.createItem(form)
        : await notifier.editItem(_editTarget!.id, form);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _saving = false;
        _showForm = false;
      });
    } else {
      setState(() {
        _saving = false;
        _error = result;
      });
    }
  }

  Future<void> _confirmDelete(AssessmentItemModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Remove Item?'),
        content: Text('Remove "${item.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deletingId = item.id);
    final result =
        await ref.read(assessmentItemsProvider(_assessmentId).notifier).removeItem(item.id);
    if (!mounted) return;
    setState(() => _deletingId = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result ?? '"${item.title}" removed.'),
      backgroundColor: result == null ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(assessmentItemsProvider(_assessmentId));

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        color: AppColors.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Assessment Items',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(widget.assessment.title,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    itemsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('Could not load items.\n${e.toString()}',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        ),
                      ),
                      data: (items) => items.isEmpty && !_showForm
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Text('No items yet. Add a video or quiz below.',
                                    style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: items
                                  .map((item) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: ItemRow(
                                          item: item,
                                          deleting: _deletingId == item.id,
                                          onEdit: () => _openEdit(item),
                                          onDelete: () => _confirmDelete(item),
                                        ),
                                      ))
                                  .toList(),
                            ),
                    ),
                    if (_showForm) ...[
                      const SizedBox(height: 8),
                      ItemForm(
                        isAdd: _editTarget == null,
                        error: _error,
                        saving: _saving,
                        itemType: _itemType,
                        correctOption: _correctOption,
                        titleCtrl: _titleCtrl,
                        orderCtrl: _orderCtrl,
                        videoUrlCtrl: _videoUrlCtrl,
                        durationCtrl: _durationCtrl,
                        questionCtrl: _questionCtrl,
                        optACtrl: _optACtrl,
                        optBCtrl: _optBCtrl,
                        optCCtrl: _optCCtrl,
                        optDCtrl: _optDCtrl,
                        passScoreCtrl: _passScoreCtrl,
                        onTypeChanged: (t) => setState(() {
                          _itemType = t;
                          _error = null;
                        }),
                        onCorrectOptionChanged: (v) => setState(() => _correctOption = v),
                        onCancel: _closeForm,
                        onSubmit: _submit,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  if (!_showForm)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openAdd,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Item'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: AppColors.primary),
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  if (_showForm) const Spacer(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Done'),
                    ),
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

