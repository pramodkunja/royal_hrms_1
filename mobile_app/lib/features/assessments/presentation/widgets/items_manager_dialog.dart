import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/assessment_model.dart';
import '../providers/assessments_providers.dart';
import 'item_form.dart';
import 'item_row.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';

/// Mirrors the reference web screen's ItemsModal ("Sections — <title>"):
/// the assessment's sections (title, order, marks) with their video/quiz
/// items, plus any unsectioned items. Sections and items are fetched lazily
/// (only while this dialog is open). Every change needs assessments.edit.
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

  /// The section a new item is added under (web forSectionId; null = unsectioned).
  String? _forSectionId;

  // Section form (web panelMode "section").
  bool _showSectionForm = false;
  AssessmentSectionModel? _editSection;
  final _secTitleCtrl = TextEditingController();
  final _secOrderCtrl = TextEditingController();
  final _secScoreCtrl = TextEditingController();
  String? _sectionError;

  /// Web formErr shown above the list (failed deletes).
  String? _listError;
  String? _deletingSectionId;

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
    _secTitleCtrl.dispose();
    _secOrderCtrl.dispose();
    _secScoreCtrl.dispose();
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

  /// Web openAddItem(sectionId): next order across all items.
  void _openAdd(String? sectionId) {
    final items = ref.read(assessmentItemsProvider(_assessmentId)).valueOrNull ?? [];
    final nextOrder = items.isEmpty ? 1 : items.map((i) => i.order).reduce((a, b) => a > b ? a : b) + 1;
    setState(() {
      _editTarget = null;
      _forSectionId = sectionId;
      _fillControllers(AssessmentItemFormData(order: nextOrder));
      _showSectionForm = false;
      _showForm = true;
      _error = null;
    });
  }

  void _openEdit(AssessmentItemModel item) {
    setState(() {
      _editTarget = item;
      _forSectionId = item.sectionId;
      _fillControllers(AssessmentItemFormData.fromModel(item));
      _showSectionForm = false;
      _showForm = true;
      _error = null;
    });
  }

  void _closeForm() => setState(() {
        _showForm = false;
        _error = null;
      });

  // ── Sections (web openAddSection / openEditSection / saveSection / deleteSection) ──

  void _openAddSection() {
    final sections = ref.read(assessmentSectionsProvider(_assessmentId)).valueOrNull ?? [];
    final f = AssessmentSectionFormData.add(sections.length);
    _openSectionForm(null, f);
  }

  void _openEditSection(AssessmentSectionModel s) => _openSectionForm(s, AssessmentSectionFormData.fromModel(s));

  void _openSectionForm(AssessmentSectionModel? target, AssessmentSectionFormData f) {
    setState(() {
      _editSection = target;
      _secTitleCtrl.text = f.title;
      _secOrderCtrl.text = f.order;
      _secScoreCtrl.text = f.score;
      _sectionError = null;
      _showForm = false;
      _showSectionForm = true;
    });
  }

  void _closeSectionForm() => setState(() {
        _showSectionForm = false;
        _editSection = null;
        _sectionError = null;
      });

  Future<void> _saveSection() async {
    if (_saving) return;
    final form =
        AssessmentSectionFormData(title: _secTitleCtrl.text, order: _secOrderCtrl.text, score: _secScoreCtrl.text);
    final problem = form.validate();
    if (problem != null) {
      setState(() => _sectionError = problem);
      return;
    }
    setState(() {
      _saving = true;
      _sectionError = null;
    });
    final notifier = ref.read(assessmentSectionsProvider(_assessmentId).notifier);
    final target = _editSection;
    final result = target == null ? await notifier.createSection(form) : await notifier.editSection(target.id, form);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result == null) {
        _showSectionForm = false;
        _editSection = null;
      } else {
        _sectionError = result;
      }
    });
  }

  Future<void> _confirmDeleteSection(AssessmentSectionModel s) async {
    if (_deletingSectionId != null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Section?'),
        content: const Text('Delete this section? Items will become unsectioned.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('section-delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _deletingSectionId = s.id;
      _listError = null;
    });
    final result = await ref.read(assessmentSectionsProvider(_assessmentId).notifier).removeSection(s.id);
    if (!mounted) return;
    setState(() {
      _deletingSectionId = null;
      _listError = result;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
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
      // Web: `section: forSectionId` on every save. On edit it is the item's
      // own section — sent only when the server reported it.
      sectionId: _forSectionId,
      sendSection: _editTarget == null || _editTarget!.sectionKnown,
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
    final result =
        _editTarget == null ? await notifier.createItem(form) : await notifier.editItem(_editTarget!.id, form);
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
    final result = await ref.read(assessmentItemsProvider(_assessmentId).notifier).removeItem(item.id);
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
    final sectionsAsync = ref.watch(assessmentSectionsProvider(_assessmentId));
    final canEdit = canEditAssessments(ref.watch(authStateProvider).valueOrNull?.user);
    final panelOpen = _showForm || _showSectionForm;

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
                        const Text('Sections',
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildContent(itemsAsync, sectionsAsync, canEdit, panelOpen),
                    if (_showSectionForm) ...[
                      const SizedBox(height: 8),
                      _SectionForm(
                        isAdd: _editSection == null,
                        error: _sectionError,
                        saving: _saving,
                        titleCtrl: _secTitleCtrl,
                        orderCtrl: _secOrderCtrl,
                        scoreCtrl: _secScoreCtrl,
                        onCancel: _closeSectionForm,
                        onSubmit: _saveSection,
                      ),
                    ],
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
                  // Web footer: "Add Section" while no form is open (and only
                  // for assessments.edit holders here), then Done.
                  if (!panelOpen && canEdit)
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('section-add'),
                        onPressed: _openAddSection,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Section'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: AppColors.primary),
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
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

  Widget _buildContent(AsyncValue<List<AssessmentItemModel>> itemsAsync,
      AsyncValue<List<AssessmentSectionModel>> sectionsAsync, bool canEdit, bool panelOpen) {
    final items = itemsAsync.valueOrNull;
    final sections = sectionsAsync.valueOrNull;
    if ((itemsAsync.isLoading && items == null) || (sectionsAsync.isLoading && sections == null)) {
      return const Padding(
        key: Key('items-loading'),
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final failure = (items == null ? itemsAsync.error : null) ?? (sections == null ? sectionsAsync.error : null);
    if (failure != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          Text(userFriendlyMessage(failure),
              key: const Key('items-load-error'),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          TextButton(
            key: const Key('items-retry'),
            onPressed: () {
              ref.invalidate(assessmentItemsProvider(_assessmentId));
              ref.invalidate(assessmentSectionsProvider(_assessmentId));
            },
            child: const Text('Retry'),
          ),
        ]),
      );
    }
    final allItems = items ?? const <AssessmentItemModel>[];
    final allSections = sections ?? const <AssessmentSectionModel>[];
    if (allSections.isEmpty && allItems.isEmpty && !panelOpen) {
      return Padding(
        key: const Key('items-empty'),
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text('No sections or items yet. Tap Add Section to get started.',
              style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
        ),
      );
    }
    final sectionIds = allSections.map((s) => s.id).toSet();
    List<AssessmentItemModel> inSection(String id) =>
        allItems.where((i) => i.sectionId == id).toList()..sort((a, b) => a.order.compareTo(b.order));
    // Web: items with no section (an item pointing at a section not listed
    // here is shown with the unsectioned ones, so nothing disappears).
    final unsectioned = allItems.where((i) => i.sectionId == null || !sectionIds.contains(i.sectionId)).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    Widget itemRow(AssessmentItemModel item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ItemRow(
            item: item,
            deleting: _deletingId == item.id,
            onEdit: canEdit ? () => _openEdit(item) : null,
            onDelete: canEdit ? () => _confirmDelete(item) : null,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!panelOpen && _listError != null) ...[
          Container(
            key: const Key('items-list-error'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(8)),
            child: Text(_listError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ),
          const SizedBox(height: 12),
        ],
        for (var si = 0; si < allSections.length; si++) ...[
          _SectionCard(
            index: si + 1,
            section: allSections[si],
            itemCount: inSection(allSections[si].id).length,
            deleting: _deletingSectionId == allSections[si].id,
            onEdit: canEdit ? () => _openEditSection(allSections[si]) : null,
            onDelete: canEdit ? () => _confirmDeleteSection(allSections[si]) : null,
            onAddItem: canEdit ? () => _openAdd(allSections[si].id) : null,
            children: [for (final item in inSection(allSections[si].id)) itemRow(item)],
          ),
          const SizedBox(height: 12),
        ],
        if (unsectioned.isNotEmpty)
          Container(
            key: const Key('unsectioned-group'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(allSections.isEmpty ? Icons.list : Icons.warning_amber_rounded,
                    size: 14, color: allSections.isEmpty ? AppColors.textSecondary : AppColors.warning),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(allSections.isEmpty ? 'Items' : 'Items not assigned to any section',
                      style: AppTextStyles.caption.copyWith(
                          fontSize: 12, color: allSections.isEmpty ? AppColors.textSecondary : AppColors.warning)),
                ),
              ]),
              const SizedBox(height: 8),
              for (final item in unsectioned) itemRow(item),
              if (canEdit)
                TextButton.icon(
                  key: const Key('unsectioned-add-item'),
                  onPressed: () => _openAdd(null),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Unsectioned Item'),
                ),
            ]),
          ),
      ],
    );
  }
}

/// Web section card: number, title, "<score> marks · <n> items", edit/delete,
/// its items, and "Add Item".
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.index,
    required this.section,
    required this.itemCount,
    required this.deleting,
    required this.children,
    this.onEdit,
    this.onDelete,
    this.onAddItem,
  });
  final int index;
  final AssessmentSectionModel section;
  final int itemCount;
  final bool deleting;
  final List<Widget> children;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('section-${section.id}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: AppColors.primary.withValues(alpha: 0.05),
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$index',
                  style: AppTextStyles.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(section.title,
                    style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
                Text('${section.score} marks · $itemCount item${itemCount == 1 ? '' : 's'}',
                    key: Key('section-meta-${section.id}'), style: AppTextStyles.caption.copyWith(fontSize: 11)),
              ]),
            ),
            if (deleting)
              const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              if (onEdit != null)
                IconButton(
                  key: Key('section-edit-${section.id}'),
                  tooltip: 'Edit section',
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  key: Key('section-delete-${section.id}'),
                  tooltip: 'Delete section',
                  icon: const Icon(Icons.delete_outline, size: 16),
                  color: AppColors.error,
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
        if (onAddItem != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: TextButton.icon(
                key: Key('section-add-item-${section.id}'),
                onPressed: onAddItem,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item'),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Web "Add Section" / "Edit Section" form.
class _SectionForm extends StatelessWidget {
  const _SectionForm({
    required this.isAdd,
    required this.error,
    required this.saving,
    required this.titleCtrl,
    required this.orderCtrl,
    required this.scoreCtrl,
    required this.onCancel,
    required this.onSubmit,
  });
  final bool isAdd;
  final String? error;
  final bool saving;
  final TextEditingController titleCtrl;
  final TextEditingController orderCtrl;
  final TextEditingController scoreCtrl;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('section-form'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(isAdd ? 'Add Section' : 'Edit Section', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (error != null) ...[
          Container(
            key: const Key('section-form-error'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(8)),
            child: Text(error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          key: const Key('section-title'),
          controller: titleCtrl,
          enabled: !saving,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Title *', hintText: 'e.g. Technical Knowledge', isDense: true),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('section-order'),
              controller: orderCtrl,
              enabled: !saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Order', isDense: true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const Key('section-score'),
              controller: scoreCtrl,
              enabled: !saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  const InputDecoration(labelText: 'Score (marks allocated)', hintText: 'e.g. 40', isDense: true),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
              key: const Key('section-cancel'), onPressed: saving ? null : onCancel, child: const Text('Cancel')),
          const SizedBox(width: 8),
          FilledButton(
            key: const Key('section-save'),
            onPressed: saving ? null : onSubmit,
            child: Text(saving ? 'Saving…' : (isAdd ? 'Save' : 'Update')),
          ),
        ]),
      ]),
    );
  }
}
