import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/email_template_model.dart';
import '../../providers/settings_providers.dart';

// Matches backend's EmailTemplateAttachment.ALLOWED_MIME_TYPES.
const _kAttachmentExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx'];
const _kMaxAttachmentBytes = 10 * 1024 * 1024;

const Map<String, String> _kExtToMime = {
  'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
  'gif': 'image/gif', 'webp': 'image/webp',
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

// Fallback options — used only while categories are loading/unavailable, or
// to keep a legacy template_type selectable even if it's absent from the
// fetched category list. The real source of truth is emailTemplateCategoriesProvider.
const _kFallbackTemplateTypes = [
  ('document',     'Document Templates'),
  ('notification', 'Notification Templates'),
  ('reminder',     'Reminder Templates'),
  ('wish',         'Wish Templates'),
];

const _kCreateCategorySentinel = '__create_new_category__';

// A file picked locally but not yet uploaded — only used in add mode, since
// the create-template endpoint doesn't accept files; attachments are
// uploaded one-by-one right after the template is created (see _submit).
class _PendingAttachment {
  final File file;
  final String mimeType;
  final String filename;
  final int size;
  const _PendingAttachment({
    required this.file,
    required this.mimeType,
    required this.filename,
    required this.size,
  });
}

class TemplateEditorSheet extends ConsumerStatefulWidget {
  final EmailTemplateModel? template;

  const TemplateEditorSheet({super.key, this.template});

  @override
  ConsumerState<TemplateEditorSheet> createState() => _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends ConsumerState<TemplateEditorSheet> {
  late final EmailTemplateFormData _form;
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _bodyCtrl;
  final Map<String, String?> _errors = {};
  bool _saving = false;
  bool _slugEdited = false; // track if user manually edited slug
  bool _creatingCategory = false;
  late List<EmailTemplateAttachmentModel> _attachments;
  final List<_PendingAttachment> _pendingAttachments = [];
  bool _uploadingAttachment = false;

  bool get _isAdd => widget.template == null;

  @override
  void initState() {
    super.initState();
    _form = widget.template != null
        ? EmailTemplateFormData.fromModel(widget.template!)
        : EmailTemplateFormData();
    _displayNameCtrl = TextEditingController(text: _form.displayName);
    _slugCtrl        = TextEditingController(text: _form.name);
    _subjectCtrl     = TextEditingController(text: _form.subject);
    _bodyCtrl        = TextEditingController(text: _form.body);
    _attachments     = List.of(widget.template?.attachments ?? const []);
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _slugCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _onDisplayNameChanged(String value) {
    _form.displayName = value;
    _clearErr('displayName');
    if (_isAdd && !_slugEdited) {
      final slug = EmailTemplateFormData.toSlug(value);
      _slugCtrl.text = slug;
      _form.name = slug;
    }
  }

  void _clearErr(String key) => setState(() => _errors.remove(key));

  // ── {VARIABLE} tag detection — live, both add & edit mode ──────────────────

  static final _tagRe = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}');
  static final _htmlTagRe = RegExp(r'<[^>]*>');

  List<String> get _knownVars => widget.template?.availableVariables ?? const [];

  List<String> get _allVars {
    final strippedBody = _bodyCtrl.text.replaceAll(_htmlTagRe, ' ');
    final combined = '${_subjectCtrl.text} $strippedBody';
    final detected = _tagRe.allMatches(combined).map((m) => m.group(1)!);
    final vars = {..._knownVars, ...detected}.toList()..sort();
    return vars;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DlgHeader(
            icon: Icons.mail_outline,
            title: _isAdd ? 'Add Email Template' : 'Edit Template',
            subtitle: _isAdd
                ? 'Create a new transactional email template'
                : widget.template?.displayName ?? '',
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDisplayName(),
                    if (_isAdd) _buildSlug(),
                    if (_isAdd) _buildCategoryDropdown() else _buildLockedCategory(),
                    _buildSubject(),
                    _buildBody(),
                    _buildVariableChips(_allVars),
                    _buildAttachmentsSection(),
                    const SizedBox(height: 8),
                    _buildActiveSwitch(),
                    const SizedBox(height: 16),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Fields ─────────────────────────────────────────────────────────────────

  Widget _buildDisplayName() => _FormField(
    label: 'Display Name *',
    hint: 'e.g. Pay Slip, Birthday Wish',
    controller: _displayNameCtrl,
    error: _errors['displayName'],
    readOnly: !_isAdd,
    onChanged: _onDisplayNameChanged,
  );

  Widget _buildSlug() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _slugCtrl,
          style: AppTextStyles.body.copyWith(fontFamily: 'monospace'),
          decoration: _inputDec('Slug (name) *', _errors['name']).copyWith(
            helperText: 'auto-generated · lowercase_with_underscores',
            helperStyle: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 11),
            suffixIcon: _slugEdited
                ? IconButton(
                    icon: Icon(Icons.refresh, size: 18, color: AppColors.textHint),
                    tooltip: 'Re-generate from display name',
                    onPressed: () {
                      final slug = EmailTemplateFormData.toSlug(_displayNameCtrl.text);
                      _slugCtrl.text = slug;
                      _form.name = slug;
                      setState(() => _slugEdited = false);
                    },
                  )
                : Icon(Icons.lock_outline, size: 16, color: AppColors.textHint),
          ),
          onChanged: (v) {
            _form.name = v;
            _clearErr('name');
            setState(() => _slugEdited = v != EmailTemplateFormData.toSlug(_displayNameCtrl.text));
          },
        ),
      ],
    ),
  );

  // ── Category — data-driven dropdown with inline "create new" ───────────────

  Widget _buildCategoryDropdown() {
    final categoriesAsync = ref.watch(emailTemplateCategoriesProvider);
    return categoriesAsync.when(
      loading: () => _categoryDropdownField(
        items: _kFallbackTemplateTypes,
        enabled: false,
        hint: 'Loading categories…',
      ),
      error: (_, __) => _categoryDropdownField(items: _kFallbackTemplateTypes),
      data: (categories) {
        final fetchedCodes = categories.map((c) => c.name).toSet();
        final extra = _kFallbackTemplateTypes.where((t) => !fetchedCodes.contains(t.$1));
        final items = <(String, String)>[
          ...categories.map((c) => (c.name, c.displayName)),
          ...extra,
        ];
        return _categoryDropdownField(items: items, allowCreate: true);
      },
    );
  }

  Widget _categoryDropdownField({
    required List<(String, String)> items,
    bool enabled = true,
    bool allowCreate = false,
    String? hint,
  }) {
    final validValue = items.any((t) => t.$1 == _form.templateType) ? _form.templateType : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: validValue,
        isExpanded: true,
        style: AppTextStyles.body,
        decoration: _inputDec('Category *', _errors['templateType']).copyWith(
          suffixIcon: _creatingCategory
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : null,
        ),
        hint: Text(hint ?? 'Select category', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
        items: [
          ...items.map((t) => DropdownMenuItem<String>(
                value: t.$1,
                child: Text(t.$2, maxLines: 1, overflow: TextOverflow.ellipsis),
              )),
          if (allowCreate)
            DropdownMenuItem<String>(
              value: _kCreateCategorySentinel,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('Create new category',
                      style: AppTextStyles.body.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
        onChanged: (!enabled || _creatingCategory)
            ? null
            : (v) {
                if (v == _kCreateCategorySentinel) {
                  _showCreateCategoryDialog();
                  return;
                }
                setState(() {
                  _form.templateType = v;
                  _clearErr('templateType');
                });
              },
      ),
    );
  }

  Future<void> _showCreateCategoryDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Create Category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppTextStyles.body,
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'e.g. Payroll Notices',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    setState(() => _creatingCategory = true);
    final created = await createEmailTemplateCategory(ref, name, onError: (msg) => _toast(msg, false));
    if (!mounted) return;
    setState(() {
      _creatingCategory = false;
      if (created != null) {
        _form.templateType = created.name;
        _clearErr('templateType');
      }
    });
  }

  Widget _buildLockedCategory() {
    final label = widget.template?.category ?? _form.templateType ?? '';
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text('Category', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.lock_outline, size: 14, color: AppColors.textHint),
        ],
      ),
    );
  }

  Widget _buildSubject() => _FormField(
    label: 'Subject *',
    hint: 'Email subject line...',
    controller: _subjectCtrl,
    error: _errors['subject'],
    onChanged: (v) { _form.subject = v; _clearErr('subject'); },
  );

  // ── Body — basic rich-text toolbar over a raw-HTML field ────────────────────

  Widget _buildBody() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Body *', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        _buildBodyToolbar(),
        const SizedBox(height: 6),
        TextFormField(
          controller: _bodyCtrl,
          maxLines: 12,
          minLines: 8,
          style: AppTextStyles.body.copyWith(fontFamily: 'monospace', fontSize: 13),
          onChanged: (v) { _form.body = v; _clearErr('body'); },
          decoration: _inputDec('', _errors['body']).copyWith(labelText: null),
        ),
        const SizedBox(height: 4),
        Text(
          'Supports HTML. Use the toolbar to format, or type {VARIABLE} tokens directly.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        ),
      ],
    ),
  );

  Widget _buildBodyToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ToolbarBtn(icon: Icons.format_bold, tooltip: 'Bold', onTap: () => _wrapSelection('<b>', '</b>')),
            _ToolbarBtn(icon: Icons.format_italic, tooltip: 'Italic', onTap: () => _wrapSelection('<i>', '</i>')),
            _ToolbarBtn(icon: Icons.format_underlined, tooltip: 'Underline', onTap: () => _wrapSelection('<u>', '</u>')),
            _ToolbarBtn(icon: Icons.format_list_bulleted, tooltip: 'Bullet list', onTap: _wrapBulletList),
            _ToolbarBtn(icon: Icons.link, tooltip: 'Link', onTap: _wrapLink),
          ],
        ),
      ),
    );
  }

  void _applyBodyEdit(String newText, TextSelection newSelection) {
    _bodyCtrl.value = TextEditingValue(text: newText, selection: newSelection);
    setState(() { _form.body = newText; _clearErrSilently('body'); });
  }

  void _clearErrSilently(String key) => _errors.remove(key);

  void _wrapSelection(String open, String close) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selected = text.substring(start, end);
    final newText = text.replaceRange(start, end, '$open$selected$close');
    final cursor = start + open.length + selected.length + close.length;
    _applyBodyEdit(newText, TextSelection.collapsed(offset: cursor));
  }

  void _wrapBulletList() {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selected = text.substring(start, end);
    final lines = selected.isEmpty
        ? ['List item']
        : selected.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final listHtml = '<ul>${lines.map((l) => '<li>$l</li>').join()}</ul>';
    final newText = text.replaceRange(start, end, listHtml);
    _applyBodyEdit(newText, TextSelection.collapsed(offset: start + listHtml.length));
  }

  Future<void> _wrapLink() async {
    final ctrl = TextEditingController(text: 'https://');
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Insert Link'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          style: AppTextStyles.body,
          decoration: const InputDecoration(labelText: 'URL'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()), child: const Text('Insert')),
        ],
      ),
    );
    if (url == null || url.isEmpty || !mounted) return;

    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final label = text.substring(start, end).isEmpty ? url : text.substring(start, end);
    final linkHtml = '<a href="$url">$label</a>';
    final newText = text.replaceRange(start, end, linkHtml);
    _applyBodyEdit(newText, TextSelection.collapsed(offset: start + linkHtml.length));
  }

  // ── Variables ────────────────────────────────────────────────────────────────

  Widget _buildVariableChips(List<String> vars) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AVAILABLE TAGS',
          style: AppTextStyles.caption.copyWith(
            fontSize: 11, color: AppColors.textHint,
            fontWeight: FontWeight.w700, letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        if (vars.isEmpty)
          Text(
            'Type {VARIABLE} in the subject or body to detect a tag.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
          )
        else
          Wrap(
            spacing: 8, runSpacing: 8,
            children: vars.map((v) => GestureDetector(
              onTap: () {
                final sel  = _bodyCtrl.selection;
                final text = _bodyCtrl.text;
                final token = '{$v}';
                final start = sel.isValid ? sel.start : text.length;
                final end = sel.isValid ? sel.end : text.length;
                final inserted = text.replaceRange(start, end, token);
                _applyBodyEdit(inserted, TextSelection.collapsed(offset: start + token.length));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '{$v}',
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'monospace', color: AppColors.primary,
                    fontWeight: FontWeight.w600, fontSize: 12,
                  ),
                ),
              ),
            )).toList(),
          ),
      ],
    ),
  );

  // ── Attachments ────────────────────────────────────────────────────────────

  Widget _buildAttachmentsSection() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'ATTACHMENTS',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11, color: AppColors.textHint,
                  fontWeight: FontWeight.w700, letterSpacing: 0.7,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _uploadingAttachment
                  ? null
                  : (_isAdd ? _pickPendingAttachment : _pickAndUploadAttachment),
              icon: _uploadingAttachment
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.attach_file, size: 16, color: AppColors.primary),
              label: Text(
                _uploadingAttachment ? 'Uploading…' : 'Add File',
                style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isAdd) ..._buildPendingAttachmentRows() else ..._buildExistingAttachmentRows(),
      ],
    ),
  );

  List<Widget> _buildExistingAttachmentRows() {
    if (_attachments.isEmpty) {
      return [
        Text(
          'No files attached. Images, PDF, Word or Excel · max 10 MB.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        ),
      ];
    }
    return _attachments
        .map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AttachmentRow(
                attachment: a,
                onOpen: () => _openAttachment(a),
                onDelete: () => _deleteAttachment(a),
              ),
            ))
        .toList();
  }

  List<Widget> _buildPendingAttachmentRows() {
    if (_pendingAttachments.isEmpty) {
      return [
        Text(
          'Images, PDF, Word or Excel · max 10 MB. Files are uploaded once the template is created.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        ),
      ];
    }
    return _pendingAttachments
        .map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PendingAttachmentRow(
                attachment: a,
                onRemove: () => setState(() => _pendingAttachments.remove(a)),
              ),
            ))
        .toList();
  }

  Future<void> _pickPendingAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kAttachmentExtensions,
    );
    final picked = result?.files.firstOrNull;
    if (picked == null || picked.path == null) return;

    if (picked.size > _kMaxAttachmentBytes) {
      _toast('File size must not exceed 10 MB.', false);
      return;
    }
    final ext = picked.extension?.toLowerCase() ?? '';
    final mimeType = _kExtToMime[ext];
    if (mimeType == null) {
      _toast('Unsupported file type.', false);
      return;
    }
    setState(() => _pendingAttachments.add(_PendingAttachment(
          file: File(picked.path!),
          mimeType: mimeType,
          filename: picked.name,
          size: picked.size,
        )));
  }

  Future<void> _pickAndUploadAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kAttachmentExtensions,
    );
    final picked = result?.files.firstOrNull;
    if (picked == null || picked.path == null) return;

    if (picked.size > _kMaxAttachmentBytes) {
      _toast('File size must not exceed 10 MB.', false);
      return;
    }
    final ext = picked.extension?.toLowerCase() ?? '';
    final mimeType = _kExtToMime[ext];
    if (mimeType == null) {
      _toast('Unsupported file type.', false);
      return;
    }

    setState(() => _uploadingAttachment = true);
    final error = await ref.read(emailTemplatesProvider.notifier).uploadAttachment(
          widget.template!.id,
          File(picked.path!),
          mimeType,
        );
    if (!mounted) return;
    setState(() {
      _uploadingAttachment = false;
      if (error == null) {
        final updated = ref.read(emailTemplatesProvider).valueOrNull
            ?.firstWhere((t) => t.id == widget.template!.id, orElse: () => widget.template!);
        _attachments = List.of(updated?.attachments ?? _attachments);
      }
    });
    if (error != null) _toast(error, false);
  }

  Future<void> _openAttachment(EmailTemplateAttachmentModel attachment) async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _deleteAttachment(EmailTemplateAttachmentModel attachment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Remove Attachment'),
        content: Text('Remove "${attachment.filename}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final error = await ref
        .read(emailTemplatesProvider.notifier)
        .removeAttachment(widget.template!.id, attachment.id);
    if (!mounted) return;
    if (error == null) {
      setState(() => _attachments.removeWhere((a) => a.id == attachment.id));
    } else {
      _toast(error, false);
    }
  }

  void _toast(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Widget _buildActiveSwitch() => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text('Active', style: AppTextStyles.label),
    subtitle: Text('Inactive templates are not sent by the system.', style: AppTextStyles.caption),
    value: _form.isActive,
    activeThumbColor: AppColors.success,
    onChanged: (v) => setState(() => _form.isActive = v),
  );

  Widget _buildSubmitButton() => FilledButton(
    onPressed: _saving ? null : _submit,
    style: FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
      backgroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: _saving
        ? const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Text(
            _isAdd ? 'Create Template' : 'Save Changes',
            style: AppTextStyles.label.copyWith(color: Colors.white),
          ),
  );

  InputDecoration _inputDec(String label, [String? error]) => InputDecoration(
    labelText: label.isEmpty ? null : label,
    errorText: error,
    labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.error),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  Future<void> _submit() async {
    _form.availableVariables = _allVars;
    final errors = _form.validate(isAdd: _isAdd);
    if (errors.isNotEmpty) {
      setState(() => _errors.addAll(errors));
      return;
    }
    setState(() => _saving = true);
    final notifier = ref.read(emailTemplatesProvider.notifier);

    if (_isAdd) {
      final error = await notifier.create(_form);
      if (!mounted) return;
      if (error != null) {
        setState(() => _saving = false);
        _toast(error, false);
        return;
      }
      if (_pendingAttachments.isNotEmpty) {
        final list = ref.read(emailTemplatesProvider).valueOrNull ?? [];
        final createdId = list.isNotEmpty ? list.last.id : null;
        if (createdId != null) {
          final failures = <String>[];
          for (final pending in _pendingAttachments) {
            final uploadError =
                await notifier.uploadAttachment(createdId, pending.file, pending.mimeType);
            if (uploadError != null) failures.add(pending.filename);
          }
          if (failures.isNotEmpty && mounted) {
            _toast('Template created, but ${failures.length} attachment(s) failed to upload.', false);
          }
        }
      }
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context);
    } else {
      final error = await notifier.edit(widget.template!.id, _form);
      if (!mounted) return;
      setState(() => _saving = false);
      if (error == null) {
        Navigator.pop(context);
      } else {
        _toast(error, false);
      }
    }
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ToolbarBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _DlgHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  const _DlgHeader({required this.icon, required this.title, required this.subtitle, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  final EmailTemplateAttachmentModel attachment;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _AttachmentRow({required this.attachment, required this.onOpen, required this.onDelete});

  IconData get _icon {
    if (attachment.mimeType.startsWith('image/')) return Icons.image_outlined;
    if (attachment.mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (attachment.mimeType.contains('word')) return Icons.description_outlined;
    if (attachment.mimeType.contains('sheet') || attachment.mimeType.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String get _sizeLabel {
    final kb = attachment.size / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(_icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    attachment.filename,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _sizeLabel,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 17),
            color: AppColors.error,
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

// Row for a locally-picked, not-yet-uploaded attachment (add mode only).
class _PendingAttachmentRow extends StatelessWidget {
  final _PendingAttachment attachment;
  final VoidCallback onRemove;

  const _PendingAttachmentRow({required this.attachment, required this.onRemove});

  String get _sizeLabel {
    final kb = attachment.size / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Icon(Icons.upload_file_outlined, size: 18, color: AppColors.textHint),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.filename,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$_sizeLabel · will upload on save',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 10.5),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 17),
            color: AppColors.error,
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? error;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  const _FormField({
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        style: AppTextStyles.body,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
          labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          filled: true,
          fillColor: readOnly ? AppColors.background : AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: readOnly ? Icon(Icons.lock_outline, size: 16, color: AppColors.textHint) : null,
        ),
      ),
    );
  }
}
