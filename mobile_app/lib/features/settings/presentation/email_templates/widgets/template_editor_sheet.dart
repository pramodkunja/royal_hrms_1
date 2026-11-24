import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../shared/widgets/blue_app_bar.dart';
import '../../../../profile/presentation/widgets/profile_widgets.dart';
import '../../../data/models/email_template_model.dart';
import '../../providers/settings_providers.dart';
import 'template_preview_sheet.dart' show VariableChip;

// Matches backend's EmailTemplateAttachment.ALLOWED_MIME_TYPES.
const _kAttachmentExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx'];
const _kMaxAttachmentBytes = 10 * 1024 * 1024;

const Map<String, String> _kExtToMime = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
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
  ('document', 'Document Templates'),
  ('notification', 'Notification Templates'),
  ('reminder', 'Reminder Templates'),
  ('wish', 'Wish Templates'),
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

/// Full-screen Add / Edit Email Template page. Push it with
/// `Navigator.push<bool>(MaterialPageRoute(...))`: it pops `true` once the
/// server CONFIRMED the save (create, or edit), and null otherwise.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  final EmailTemplateModel? template;

  const TemplateEditorScreen({super.key, this.template});

  @override
  ConsumerState<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  late final EmailTemplateFormData _form;
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _bodyCtrl;
  final Map<String, String?> _errors = {};
  final _anchors = <String, GlobalKey>{};
  final _scroll = ScrollController();
  String? _saveError;
  bool _saving = false;
  bool _slugEdited = false; // track if user manually edited slug
  bool _creatingCategory = false;
  int _catEpoch = 0; // bumped to rebuild the category dropdown on its real value
  late List<EmailTemplateAttachmentModel> _attachments;
  final List<_PendingAttachment> _pendingAttachments = [];
  bool _uploadingAttachment = false;

  /// The order fields appear in, to find the first one that needs attention.
  static const _order = ['displayName', 'name', 'templateType', 'subject', 'body'];

  bool get _isAdd => widget.template == null;

  GlobalKey _anchor(String f) => _anchors.putIfAbsent(f, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _form = widget.template != null ? EmailTemplateFormData.fromModel(widget.template!) : EmailTemplateFormData();
    _displayNameCtrl = TextEditingController(text: _form.displayName);
    _slugCtrl = TextEditingController(text: _form.name);
    _subjectCtrl = TextEditingController(text: _form.subject);
    _bodyCtrl = TextEditingController(text: _form.body);
    _attachments = List.of(widget.template?.attachments ?? const []);
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _slugCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _scroll.dispose();
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

  /// Brings the first field that needs attention (or, for a message that
  /// belongs to no field, the banner at the top) into view.
  void _showProblem() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final first = _order.where((k) => _errors[k] != null).firstOrNull;
      final ctx = first == null ? null : _anchors[first]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.15, duration: const Duration(milliseconds: 250));
      } else if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  // ── Look ───────────────────────────────────────────────────────────────────

  OutlineInputBorder _border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));

  InputDecoration _decoration({String? hint, String? error, Widget? suffix, bool enabled = true}) => InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        errorText: error,
        errorMaxLines: 4,
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: enabled ? AppColors.surface : AppColors.backgroundLow,
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        disabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.primary, 1.5),
        errorBorder: _border(AppColors.error),
        focusedErrorBorder: _border(AppColors.error, 1.5),
        suffixIcon: suffix,
      );

  /// A labelled field: label above, control below, its own scroll anchor.
  Widget _field(String f, String label, Widget control, {bool required = false, String? helper}) => Padding(
        key: _anchor(f),
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: label),
              if (required) TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
            ]),
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          control,
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(helper, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 12)),
            ),
        ]),
      );

  Widget _lock() => Icon(Icons.lock_outline, size: 16, color: AppColors.textHint);

  Widget _lockedText(String key, String value) => InputDecorator(
        key: Key(key),
        decoration: _decoration(suffix: _lock(), enabled: false),
        child: Text(value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
      );

  // ── Basics ─────────────────────────────────────────────────────────────────

  Widget _buildDisplayName() => _field(
        'displayName',
        'Display Name',
        _isAdd
            ? TextField(
                key: const Key('et-field-display-name'),
                controller: _displayNameCtrl,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                decoration: _decoration(hint: 'e.g. Pay Slip, Birthday Wish', error: _errors['displayName']),
                onChanged: _onDisplayNameChanged,
              )
            : _lockedText('et-field-display-name', _displayNameCtrl.text),
        required: _isAdd,
      );

  Widget _buildSlug() => _field(
        'name',
        'Slug (name)',
        TextField(
          key: const Key('et-field-name'),
          controller: _slugCtrl,
          enabled: !_saving,
          textInputAction: TextInputAction.next,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontFamily: 'monospace'),
          decoration: _decoration(
            error: _errors['name'],
            suffix: _slugEdited
                ? IconButton(
                    key: const Key('et-slug-regen'),
                    icon: Icon(Icons.refresh, size: 18, color: AppColors.textHint),
                    tooltip: 'Re-generate from display name',
                    onPressed: _saving
                        ? null
                        : () {
                            final slug = EmailTemplateFormData.toSlug(_displayNameCtrl.text);
                            _slugCtrl.text = slug;
                            _form.name = slug;
                            setState(() => _slugEdited = false);
                          },
                  )
                : _lock(),
          ),
          onChanged: (v) {
            _form.name = v;
            _clearErr('name');
            setState(() => _slugEdited = v != EmailTemplateFormData.toSlug(_displayNameCtrl.text));
          },
        ),
        required: true,
        helper: 'auto-generated · lowercase_with_underscores',
      );

  // ── Category — data-driven dropdown with inline "create new" ───────────────

  Widget _buildCategory() {
    if (!_isAdd) {
      final label = widget.template?.category ?? _form.templateType ?? '';
      return _field('templateType', 'Category', _lockedText('et-field-category', label));
    }
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
    return _field(
      'templateType',
      'Category',
      KeyedSubtree(
        key: const Key('et-field-category'),
        child: DropdownButtonFormField<String>(
          key: ValueKey('cat-$validValue-${items.length}-$enabled-$_catEpoch'),
          initialValue: validValue,
          isExpanded: true,
          menuMaxHeight: 340,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          decoration: _decoration(
            error: _errors['templateType'],
            enabled: enabled && !_saving,
            suffix: _creatingCategory
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
          hint: Text(hint ?? 'Select category', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
          items: [
            ...items.map((t) => DropdownMenuItem<String>(
                  value: t.$1,
                  child: Text(t.$2, maxLines: 2, overflow: TextOverflow.ellipsis),
                )),
            if (allowCreate)
              DropdownMenuItem<String>(
                value: _kCreateCategorySentinel,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('Create new category',
                          style:
                              AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (!enabled || _creatingCategory || _saving)
              ? null
              : (v) {
                  if (v == _kCreateCategorySentinel) {
                    // The dropdown now holds the "create" row; rebuild it on the real value.
                    setState(() => _catEpoch++);
                    _showCreateCategoryDialog();
                    return;
                  }
                  setState(() {
                    _form.templateType = v;
                    _errors.remove('templateType');
                  });
                },
        ),
      ),
      required: true,
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
          key: const Key('et-new-category-name'),
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
            key: const Key('et-new-category-create'),
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
        _errors.remove('templateType');
      }
    });
  }

  // ── Message ────────────────────────────────────────────────────────────────

  Widget _buildSubject() => _field(
        'subject',
        'Subject',
        TextField(
          key: const Key('et-field-subject'),
          controller: _subjectCtrl,
          enabled: !_saving,
          textInputAction: TextInputAction.next,
          minLines: 1,
          maxLines: 3,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          decoration: _decoration(hint: 'Email subject line...', error: _errors['subject']),
          onChanged: (v) {
            _form.subject = v;
            _clearErr('subject');
          },
        ),
        required: true,
      );

  // Body — basic toolbar over a raw-HTML field.
  Widget _buildBody() => _field(
        'body',
        'Body',
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildBodyToolbar(),
          const SizedBox(height: 8),
          TextField(
            key: const Key('et-field-body'),
            controller: _bodyCtrl,
            enabled: !_saving,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 10,
            maxLines: 20,
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontFamily: 'monospace', fontSize: 13),
            onChanged: (v) {
              _form.body = v;
              _clearErr('body');
            },
            decoration: _decoration(hint: '<p>Dear {EMPLOYEE_NAME},</p>', error: _errors['body']),
          ),
        ]),
        required: true,
        helper: 'Supports HTML. Use the toolbar to format, or type {VARIABLE} tokens directly.',
      );

  Widget _buildBodyToolbar() {
    final on = !_saving;
    return Container(
      key: const Key('et-toolbar'),
      decoration: BoxDecoration(
        color: AppColors.backgroundLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(2),
      child: Wrap(
        children: [
          _ToolbarBtn(
              id: 'bold',
              icon: Icons.format_bold,
              tooltip: 'Bold',
              onTap: on ? () => _wrapSelection('<b>', '</b>') : null),
          _ToolbarBtn(
              id: 'italic',
              icon: Icons.format_italic,
              tooltip: 'Italic',
              onTap: on ? () => _wrapSelection('<i>', '</i>') : null),
          _ToolbarBtn(
              id: 'underline',
              icon: Icons.format_underlined,
              tooltip: 'Underline',
              onTap: on ? () => _wrapSelection('<u>', '</u>') : null),
          _ToolbarBtn(
              id: 'strike',
              icon: Icons.format_strikethrough,
              tooltip: 'Strikethrough',
              onTap: on ? () => _wrapSelection('<s>', '</s>') : null),
          _ToolbarBtn(
              id: 'bullets',
              icon: Icons.format_list_bulleted,
              tooltip: 'Bullet list',
              onTap: on ? () => _wrapList('ul') : null),
          _ToolbarBtn(
              id: 'numbers',
              icon: Icons.format_list_numbered,
              tooltip: 'Numbered list',
              onTap: on ? () => _wrapList('ol') : null),
          _ToolbarBtn(id: 'link', icon: Icons.link, tooltip: 'Link', onTap: on ? _wrapLink : null),
        ],
      ),
    );
  }

  void _applyBodyEdit(String newText, TextSelection newSelection) {
    _bodyCtrl.value = TextEditingValue(text: newText, selection: newSelection);
    setState(() {
      _form.body = newText;
      _errors.remove('body');
    });
  }

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

  void _wrapList(String tag) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selected = text.substring(start, end);
    final lines = selected.isEmpty ? ['List item'] : selected.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final listHtml = '<$tag>${lines.map((l) => '<li>$l</li>').join()}</$tag>';
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
          key: const Key('et-link-url'),
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          style: AppTextStyles.body,
          decoration: const InputDecoration(labelText: 'URL'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            key: const Key('et-link-insert'),
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text('Insert'),
          ),
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

  void _insertVariable(String v) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final token = '{$v}';
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final inserted = text.replaceRange(start, end, token);
    _applyBodyEdit(inserted, TextSelection.collapsed(offset: start + token.length));
  }

  Widget _buildVariables(List<String> vars) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vars.isEmpty)
            Text(
              'Type {VARIABLE} in the subject or body to detect a tag.',
              key: const Key('et-variables-empty'),
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 12),
            )
          else ...[
            Wrap(
              key: const Key('et-variables'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in vars)
                  KeyedSubtree(
                    key: Key('et-var-$v'),
                    child: VariableChip(name: v, onTap: _saving ? null : () => _insertVariable(v)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Tap a tag to insert it into the body.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ],
      );

  // ── Attachments ────────────────────────────────────────────────────────────

  Widget _addFileButton() => OutlinedButton.icon(
        key: const Key('et-add-file'),
        onPressed:
            (_uploadingAttachment || _saving) ? null : (_isAdd ? _pickPendingAttachment : _pickAndUploadAttachment),
        icon: _uploadingAttachment
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.attach_file, size: 16, color: AppColors.primary),
        label: Text(
          _uploadingAttachment ? 'Uploading…' : 'Add File',
          style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  Widget _buildAttachments() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...(_isAdd ? _buildPendingAttachmentRows() : _buildExistingAttachmentRows()),
          const SizedBox(height: 4),
          _addFileButton(),
        ],
      );

  List<Widget> _buildExistingAttachmentRows() {
    if (_attachments.isEmpty) {
      return [
        Text(
          'No files attached. Images, PDF, Word or Excel · max 10 MB.',
          key: const Key('et-attachments-empty'),
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 12),
        ),
      ];
    }
    return [
      for (final a in _attachments)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _AttachmentRow(
            attachment: a,
            onOpen: () => _openAttachment(a),
            onDelete: _saving ? null : () => _deleteAttachment(a),
          ),
        ),
    ];
  }

  List<Widget> _buildPendingAttachmentRows() {
    if (_pendingAttachments.isEmpty) {
      return [
        Text(
          'Images, PDF, Word or Excel · max 10 MB. Files are uploaded once the template is created.',
          key: const Key('et-attachments-empty'),
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 12),
        ),
      ];
    }
    return [
      for (final a in _pendingAttachments)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PendingAttachmentRow(
            attachment: a,
            onRemove: _saving ? null : () => setState(() => _pendingAttachments.remove(a)),
          ),
        ),
    ];
  }

  /// Picks one file and applies web/backend's size and type rules; null (after
  /// a message) when the file is refused.
  Future<(PlatformFile, String)?> _pickValid() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kAttachmentExtensions,
    );
    final picked = result?.files.firstOrNull;
    if (picked == null || picked.path == null) return null;

    if (picked.size > _kMaxAttachmentBytes) {
      _toast('File size must not exceed 10 MB.', false);
      return null;
    }
    final ext = picked.extension?.toLowerCase() ?? '';
    final mimeType = _kExtToMime[ext];
    if (mimeType == null) {
      _toast('Unsupported file type.', false);
      return null;
    }
    return (picked, mimeType);
  }

  Future<void> _pickPendingAttachment() async {
    final v = await _pickValid();
    if (v == null || !mounted) return;
    final (picked, mimeType) = v;
    setState(() => _pendingAttachments.add(_PendingAttachment(
          file: File(picked.path!),
          mimeType: mimeType,
          filename: picked.name,
          size: picked.size,
        )));
  }

  Future<void> _pickAndUploadAttachment() async {
    final v = await _pickValid();
    if (v == null || !mounted) return;
    final (picked, mimeType) = v;

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
        final updated = ref
            .read(emailTemplatesProvider)
            .valueOrNull
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
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Remove Attachment'),
        content: Text('Remove "${attachment.filename}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('et-remove-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final error = await ref.read(emailTemplatesProvider.notifier).removeAttachment(widget.template!.id, attachment.id);
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

  // ── Status ─────────────────────────────────────────────────────────────────

  Widget _buildActiveSwitch() => Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Active', style: AppTextStyles.label),
              const SizedBox(height: 2),
              Text('Inactive templates are not sent by the system.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ]),
          ),
          const SizedBox(width: 8),
          Switch(
            key: const Key('et-active'),
            value: _form.isActive,
            activeThumbColor: AppColors.success,
            onChanged: _saving ? null : (v) => setState(() => _form.isActive = v),
          ),
        ],
      );

  // ── Save ───────────────────────────────────────────────────────────────────

  Widget _banner(String text) => Container(
        key: const Key('et-save-error'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
        ]),
      );

  Widget _actionBar(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final cancel = OutlinedButton(
      key: const Key('et-cancel'),
      onPressed: _saving ? null : () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: const Text('Cancel'),
    );
    final save = FilledButton(
      key: const Key('et-save'),
      onPressed: _saving ? null : _submit,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: AppColors.primary,
        // While saving the button stays blue with its spinner (not a greyed-out look).
        disabledBackgroundColor: _saving ? AppColors.primary : null,
        disabledForegroundColor: _saving ? Colors.white : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: _saving
          ? const Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 10),
              Text('Saving…'),
            ])
          : Text(_isAdd ? 'Create Template' : 'Save Changes'),
    );
    return Material(
      color: AppColors.surface,
      elevation: 4,
      shadowColor: Colors.black12,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: LayoutBuilder(builder: (context, c) {
                if (c.maxWidth < 300 || scale > 1.3) {
                  return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        save,
                        const SizedBox(height: 8),
                        cancel,
                      ]);
                }
                return Row(children: [
                  Expanded(child: cancel),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: save),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    _form.availableVariables = _allVars;
    final errors = _form.validate(isAdd: _isAdd);
    if (errors.isNotEmpty) {
      setState(() {
        _saveError = null;
        _errors
          ..clear()
          ..addAll(errors);
      });
      _showProblem();
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
      _errors.clear();
    });
    final notifier = ref.read(emailTemplatesProvider.notifier);

    if (_isAdd) {
      final error = await notifier.create(_form);
      if (!mounted) return;
      if (error != null) {
        setState(() {
          _saving = false;
          _saveError = error;
        });
        _showProblem();
        return;
      }
      if (_pendingAttachments.isNotEmpty) {
        final list = ref.read(emailTemplatesProvider).valueOrNull ?? [];
        final createdId = list.isNotEmpty ? list.last.id : null;
        if (createdId != null) {
          final failures = <String>[];
          for (final pending in _pendingAttachments) {
            final uploadError = await notifier.uploadAttachment(createdId, pending.file, pending.mimeType);
            if (uploadError != null) failures.add(pending.filename);
          }
          if (failures.isNotEmpty && mounted) {
            _toast('Template created, but ${failures.length} attachment(s) failed to upload.', false);
          }
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      final error = await notifier.edit(widget.template!.id, _form);
      if (!mounted) return;
      if (error == null) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _saving = false;
          _saveError = error;
        });
        _showProblem();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final tight = MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom < 480;
    final name = widget.template?.displayName ?? '';

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: BlueAppBar(title: _isAdd ? 'Add Email Template' : 'Edit: $name'),
        // With the keyboard up on a very short screen the bar would eat the form: it
        // returns as soon as the keyboard closes.
        bottomNavigationBar: keyboardOpen && tight ? null : _actionBar(context),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            // Not a lazy list: every field is built, so a refused field far down can be scrolled to.
            child: SingleChildScrollView(
              key: const Key('et-form'),
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_saveError != null) _banner(_saveError!),
                ProfileSectionCard(
                  icon: Icons.mail_outline,
                  title: 'Basics',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _buildDisplayName(),
                    if (_isAdd) _buildSlug(),
                    _buildCategory(),
                  ]),
                ),
                const SizedBox(height: 12),
                ProfileSectionCard(
                  icon: Icons.edit_note_outlined,
                  title: 'Message',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _buildSubject(),
                    _buildBody(),
                  ]),
                ),
                const SizedBox(height: 12),
                ProfileSectionCard(
                  icon: Icons.data_object,
                  title: 'Variables',
                  child: _buildVariables(_allVars),
                ),
                const SizedBox(height: 12),
                ProfileSectionCard(
                  icon: Icons.attach_file,
                  title: 'Attachments',
                  child: _buildAttachments(),
                ),
                const SizedBox(height: 12),
                ProfileSectionCard(
                  icon: Icons.toggle_on_outlined,
                  title: 'Status',
                  child: _buildActiveSwitch(),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _ToolbarBtn extends StatelessWidget {
  final String id;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _ToolbarBtn({required this.id, required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: Key('et-tool-$id'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: onTap == null ? AppColors.textHint : AppColors.textSecondary),
        ),
      ),
    );
  }
}

String _sizeLabel(int bytes) {
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}

class _FileRowShell extends StatelessWidget {
  const _FileRowShell(
      {required this.icon, required this.name, required this.detail, required this.action, this.onOpen});
  final Widget icon;
  final String name;
  final String detail;
  final Widget action;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(detail, style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
          action,
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  final EmailTemplateAttachmentModel attachment;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

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

  @override
  Widget build(BuildContext context) {
    return _FileRowShell(
      icon: Icon(_icon, size: 18, color: AppColors.primary),
      name: attachment.filename,
      detail: _sizeLabel(attachment.size),
      onOpen: onOpen,
      action: IconButton(
        key: Key('et-attachment-remove-${attachment.id}'),
        icon: const Icon(Icons.delete_outline, size: 18),
        color: AppColors.error,
        onPressed: onDelete,
        tooltip: 'Remove',
      ),
    );
  }
}

// Row for a locally-picked, not-yet-uploaded attachment (add mode only).
class _PendingAttachmentRow extends StatelessWidget {
  final _PendingAttachment attachment;
  final VoidCallback? onRemove;

  const _PendingAttachmentRow({required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return _FileRowShell(
      icon: Icon(Icons.upload_file_outlined, size: 18, color: AppColors.textHint),
      name: attachment.filename,
      detail: '${_sizeLabel(attachment.size)} · will upload on save',
      action: IconButton(
        key: Key('et-pending-remove-${attachment.filename}'),
        icon: const Icon(Icons.close, size: 18),
        color: AppColors.error,
        onPressed: onRemove,
        tooltip: 'Remove',
      ),
    );
  }
}
