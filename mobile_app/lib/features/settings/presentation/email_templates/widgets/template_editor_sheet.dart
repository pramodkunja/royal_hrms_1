import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/email_template_model.dart';
import '../../providers/settings_providers.dart';

// Hardcoded template type options — matches backend TEMPLATE_TYPE_CHOICES
const _kTemplateTypes = [
  ('document',     'Document Templates'),
  ('notification', 'Notification Templates'),
  ('reminder',     'Reminder Templates'),
  ('wish',         'Wish Templates'),
];

class TemplateEditorSheet extends StatefulWidget {
  final EmailTemplateModel? template;
  final WidgetRef ref;

  const TemplateEditorSheet({super.key, this.template, required this.ref});

  @override
  State<TemplateEditorSheet> createState() => _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends State<TemplateEditorSheet> {
  late final EmailTemplateFormData _form;
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _bodyCtrl;
  final Map<String, String?> _errors = {};
  bool _saving = false;
  bool _slugEdited = false; // track if user manually edited slug

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
                    if (_isAdd) _buildCategoryDropdown(),
                    if (!_isAdd) _buildLockedCategory(),
                    _buildSubject(),
                    _buildBody(),
                    if (!_isAdd && widget.template!.availableVariables.isNotEmpty)
                      _buildVariableChips(widget.template!.availableVariables),
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
                    icon: const Icon(Icons.refresh, size: 18, color: AppColors.textHint),
                    tooltip: 'Re-generate from display name',
                    onPressed: () {
                      final slug = EmailTemplateFormData.toSlug(_displayNameCtrl.text);
                      _slugCtrl.text = slug;
                      _form.name = slug;
                      setState(() => _slugEdited = false);
                    },
                  )
                : const Icon(Icons.lock_outline, size: 16, color: AppColors.textHint),
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

  Widget _buildCategoryDropdown() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: _form.templateType,
      isExpanded: true,
      style: AppTextStyles.body,
      decoration: _inputDec('Category *', _errors['templateType']),
      hint: Text('Select category', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
      items: _kTemplateTypes
          .map((t) => DropdownMenuItem<String>(value: t.$1, child: Text(t.$2)))
          .toList(),
      onChanged: (v) => setState(() {
        _form.templateType = v;
        _clearErr('templateType');
      }),
    ),
  );

  Widget _buildLockedCategory() {
    final label = _kTemplateTypes
        .firstWhere((t) => t.$1 == _form.templateType, orElse: () => ('', _form.templateType ?? ''))
        .$2;
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text('Category', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.lock_outline, size: 14, color: AppColors.textHint),
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

  Widget _buildBody() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _bodyCtrl,
          maxLines: 14,
          style: AppTextStyles.body.copyWith(fontFamily: 'monospace', fontSize: 13),
          onChanged: (v) { _form.body = v; _clearErr('body'); },
          decoration: _inputDec('Body *', _errors['body']).copyWith(
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Supports HTML. Use {VARIABLE} tokens from the list below.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        ),
      ],
    ),
  );

  Widget _buildVariableChips(List<String> vars) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMMON TAGS',
          style: AppTextStyles.caption.copyWith(
            fontSize: 11, color: AppColors.textHint,
            fontWeight: FontWeight.w700, letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: vars.map((v) => GestureDetector(
            onTap: () {
              final sel  = _bodyCtrl.selection;
              final text = _bodyCtrl.text;
              final token = '{$v}';
              final inserted = sel.isValid
                  ? text.replaceRange(sel.start, sel.end, token)
                  : text + token;
              _bodyCtrl.text = inserted;
              _form.body = inserted;
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
    labelText: label,
    errorText: error,
    labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  Future<void> _submit() async {
    final errors = _form.validate(isAdd: _isAdd);
    if (errors.isNotEmpty) {
      setState(() => _errors.addAll(errors));
      return;
    }
    setState(() => _saving = true);
    final notifier = widget.ref.read(emailTemplatesProvider.notifier);
    final error = _isAdd
        ? await notifier.create(_form)
        : await notifier.edit(widget.template!.id, _form);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

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
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: readOnly ? const Icon(Icons.lock_outline, size: 16, color: AppColors.textHint) : null,
        ),
      ),
    );
  }
}
