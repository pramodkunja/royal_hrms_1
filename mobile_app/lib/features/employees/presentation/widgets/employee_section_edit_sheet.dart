import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/employee_model.dart';
import '../../domain/employee_profile_sections.dart';
import '../providers/employee_providers.dart';
import 'custom_fields_block.dart' show profileFieldConfigProvider;

/// Edit form for one of the HR Employee Profile's Education & Experience,
/// Bank Details or Emergency Contact sections — web employees/[id]/page.tsx
/// ProfileForm in edit mode for that section: the same fields, labels,
/// placeholders, options and required asterisks, hidden fields per Settings →
/// Onboarding Fields. Save sends only this section's keys (PUT
/// /employees/<code>/); the server validates them. On failure the message and
/// per-field errors are shown and every entered value is kept for a retry.
/// Cancel closes without a request. Returns true when saved.
class EmployeeSectionEditSheet extends ConsumerStatefulWidget {
  const EmployeeSectionEditSheet({super.key, required this.employee, required this.section});

  final EmployeeModel employee;
  final EmployeeProfileSection section;

  static Future<bool> show(BuildContext context, EmployeeModel employee, EmployeeProfileSection section) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: EmployeeSectionEditSheet(employee: employee, section: section),
      ),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<EmployeeSectionEditSheet> createState() => _EmployeeSectionEditSheetState();
}

class _EmployeeSectionEditSheetState extends ConsumerState<EmployeeSectionEditSheet> {
  late final Map<String, String> _initial = profileSectionValues(widget.section, widget.employee);
  late final Map<String, String> _values = {..._initial};
  late final Map<String, TextEditingController> _ctrls = {
    for (final f in _def.fields)
      if (f.kind != ProfileFieldKind.select) f.key: TextEditingController(text: _initial[f.key] ?? ''),
  };
  Map<String, String> _fieldErrors = const {};
  String? _error;
  bool _saving = false;

  ({String title, int step, List<ProfileFieldDef> fields}) get _def => kEmployeeProfileSections[widget.section]!;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(String key, String value) {
    _values[key] = value;
    if (_fieldErrors.containsKey(key)) setState(() => _fieldErrors = {..._fieldErrors}..remove(key));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    final result = await saveEmployeeProfileSection(
        ref, widget.employee.employeeId, profileSectionPayload(widget.section, _values));
    if (!mounted) return;
    if (result == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = result.message;
      _fieldErrors = result.fieldErrors;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(profileFieldConfigProvider).valueOrNull;
    final fields = _def.fields.where((f) => isProfileFieldVisible(widget.section, f.key, config)).toList();
    return Container(
      key: Key('section-edit-${widget.section.name}'),
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Edit ${_def.title}',
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Container(
                      key: const Key('section-edit-error'),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                    ),
                  for (final f in fields) ...[
                    _field(f),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('section-edit-cancel'),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const Key('section-edit-save'),
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(ProfileFieldDef f) => InputDecoration(
        labelText: f.required ? '${f.label} *' : f.label,
        hintText: f.placeholder,
        errorText: _fieldErrors[f.key],
        errorMaxLines: 3,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  Widget _field(ProfileFieldDef f) {
    if (f.kind == ProfileFieldKind.select) {
      final current = _values[f.key] ?? '';
      // A stored value that isn't one of web's options (older or imported
      // data) stays selectable so opening and saving never changes it.
      final options = [
        if (current.isNotEmpty && !f.options.any((o) => o.value == current)) ProfileFieldOption(current, current),
        ...f.options,
      ];
      return DropdownButtonFormField<String>(
        key: Key('section-field-${f.key}'),
        initialValue: current,
        isExpanded: true,
        decoration: _dec(f),
        items: [
          const DropdownMenuItem(value: '', child: Text('Select')),
          for (final o in options) DropdownMenuItem(value: o.value, child: Text(o.label)),
        ],
        onChanged: _saving ? null : (v) => setState(() => _set(f.key, v ?? '')),
      );
    }
    return TextField(
      key: Key('section-field-${f.key}'),
      controller: _ctrls[f.key],
      enabled: !_saving,
      maxLines: f.kind == ProfileFieldKind.textarea ? 3 : 1,
      keyboardType: switch (f.kind) {
        ProfileFieldKind.phone => TextInputType.phone,
        ProfileFieldKind.email => TextInputType.emailAddress,
        ProfileFieldKind.textarea => TextInputType.multiline,
        _ => TextInputType.text,
      },
      decoration: _dec(f),
      onChanged: (v) => _set(f.key, v),
    );
  }
}
