import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/company_contact.dart';
import '../providers/contacts_providers.dart';

/// Add or edit one contact (web: the Contact Matrix modal). Resolves to true
/// once the server accepted the change.
class ContactFormSheet extends ConsumerStatefulWidget {
  const ContactFormSheet({super.key, this.editing});

  /// The contact being edited; null to add one.
  final CompanyContact? editing;

  static Future<bool> show(BuildContext context, {CompanyContact? editing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ContactFormSheet(editing: editing),
    );
    return saved == true;
  }

  @override
  ConsumerState<ContactFormSheet> createState() => _ContactFormSheetState();
}

class _ContactFormSheetState extends ConsumerState<ContactFormSheet> {
  late final ContactForm _initial = widget.editing?.toForm() ?? const ContactForm();
  late final _name = TextEditingController(text: _initial.name);
  late final _designation = TextEditingController(text: _initial.designation);
  late final _department = TextEditingController(text: _initial.department);
  late final _purpose = TextEditingController(text: _initial.purpose);
  late final _email = TextEditingController(text: _initial.email);
  late final _phone = TextEditingController(text: _initial.phone);
  late final _level = TextEditingController(text: '${_initial.escalationLevel}');
  late int? _branch = _initial.branch;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _designation, _department, _purpose, _email, _phone, _level]) {
      c.dispose();
    }
    super.dispose();
  }

  ContactForm get _form => ContactForm(
        name: _name.text,
        designation: _designation.text,
        department: _department.text,
        email: _email.text,
        phone: _phone.text,
        purpose: _purpose.text,
        escalationLevel: int.tryParse(_level.text.trim()) ?? 0,
        branch: _branch,
        displayOrder: _initial.displayOrder,
      );

  Future<void> _save() async {
    if (_saving) return; // one request at a time
    final problem = contactFormError(_form);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await ref.read(contactActionsProvider).save(widget.editing?.id, _form);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = err; // everything typed stays
    });
  }

  Widget _field(String label, TextEditingController c,
          {String? hint, TextInputType? keyboard, List<TextInputFormatter>? formatters, String? key}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: key == null ? null : Key(key),
          controller: c,
          enabled: !_saving,
          keyboardType: keyboard,
          inputFormatters: formatters,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(contactBranchesProvider);
    final branches = branchesAsync.valueOrNull ?? const <ContactBranchOption>[];
    // The contact's current branch stays selected even before (or without)
    // the branch list — never silently switched to "All branches".
    final branchIds = {for (final b in branches) b.id};
    final keepCurrent = _branch != null && !branchIds.contains(_branch);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.editing == null ? 'Add Contact' : 'Edit Contact', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            _field('Name *', _name, key: 'contact-name'),
            _field('Designation', _designation, key: 'contact-designation'),
            _field('Department', _department, key: 'contact-department'),
            _field('Contact for', _purpose, hint: 'e.g. Attendance, WFH, leave', key: 'contact-purpose'),
            _field('Email', _email, keyboard: TextInputType.emailAddress, key: 'contact-email'),
            _field('Phone', _phone, keyboard: TextInputType.phone, key: 'contact-phone'),
            _field('Escalation level', _level,
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly],
                key: 'contact-level'),
            DropdownButtonFormField<int?>(
              key: const Key('contact-branch'),
              initialValue: _branch,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Branch',
                helperText: branchesAsync.hasError ? 'Could not load branches.' : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All branches')),
                if (keepCurrent)
                  DropdownMenuItem<int?>(
                    value: _branch,
                    child: Text(
                        widget.editing?.branch == _branch && (widget.editing?.branchName.isNotEmpty ?? false)
                            ? widget.editing!.branchName
                            : 'Current branch',
                        overflow: TextOverflow.ellipsis),
                  ),
                for (final b in branches)
                  DropdownMenuItem<int?>(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: _saving ? null : (v) => setState(() => _branch = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  key: const Key('contact-form-error'),
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('contact-save'),
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    child: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
