import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/onboarding_field_config_model.dart';
import '../../providers/settings_providers.dart';

/// Create-only — matches web's `AddFieldModal` (custom fields are created
/// here; built-in fields can only be hidden/reordered/required-toggled from
/// the list, never edited via this form).
class OnboardingFieldFormSheet extends StatefulWidget {
  final int step;
  final WidgetRef ref;

  const OnboardingFieldFormSheet({super.key, required this.step, required this.ref});

  @override
  State<OnboardingFieldFormSheet> createState() => _OnboardingFieldFormSheetState();
}

class _OnboardingFieldFormSheetState extends State<OnboardingFieldFormSheet> {
  final _labelCtrl = TextEditingController();
  final _optionsCtrl = TextEditingController();
  String _fieldType = 'text';
  bool _allowMultiple = false;
  bool _required = false;
  bool _saving = false;
  String? _labelError;
  String? _optionsError;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _optionsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DlgHeader(
            title: 'Add Custom Field',
            subtitle: OnboardingFieldConfigModel.stepLabels[widget.step] ?? '',
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _labelCtrl,
                      style: AppTextStyles.body,
                      autofocus: true,
                      onChanged: (_) => setState(() => _labelError = null),
                      decoration: _dec('Field Label *', _labelError),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _fieldType,
                      isExpanded: true,
                      decoration: _dec('Field Type'),
                      items: OnboardingFieldConfigModel.fieldTypeLabels.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _fieldType = v ?? 'text'),
                    ),
                    if (_fieldType == 'dropdown') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _optionsCtrl,
                        style: AppTextStyles.body,
                        onChanged: (_) => setState(() => _optionsError = null),
                        decoration: _dec('Dropdown Options *', _optionsError)
                            .copyWith(hintText: 'e.g. Option A, Option B'),
                      ),
                      const SizedBox(height: 4),
                      Text('Separate options with commas.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                    ],
                    if (_fieldType == 'file') ...[
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _allowMultiple,
                        onChanged: (v) => setState(() => _allowMultiple = v ?? false),
                        title: const Text('Allow multiple files'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    ],
                    CheckboxListTile(
                      value: _required,
                      onChanged: (v) => setState(() => _required = v ?? false),
                      title: const Text('Required'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text('Create Field', style: AppTextStyles.label.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, [String? error]) => InputDecoration(
        labelText: label,
        errorText: error,
        labelStyle: AppTextStyles.caption,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Future<void> _submit() async {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      setState(() => _labelError = 'Label cannot be blank.');
      return;
    }
    final options = _optionsCtrl.text.split(',').map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
    if (_fieldType == 'dropdown' && options.isEmpty) {
      setState(() => _optionsError = 'Add at least one option, separated by commas.');
      return;
    }
    setState(() => _saving = true);
    final result = await widget.ref.read(onboardingFieldsProvider.notifier).create(
          OnboardingFieldFormData(
            label: label,
            fieldType: _fieldType,
            options: options,
            allowMultiple: _allowMultiple,
            step: widget.step,
            required: _required,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result), backgroundColor: AppColors.error));
    }
  }
}

class _DlgHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  const _DlgHeader({required this.title, required this.subtitle, required this.onClose});

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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
