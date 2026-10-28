import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/onboarding_field_config_model.dart' show DocumentTypeFormData;
import '../../providers/settings_providers.dart';

/// Create-only — matches web's `AddDocumentTypeModal`. Every document type
/// is inherently file-typed, so unlike [OnboardingFieldFormSheet] there's no
/// field-type selector or dropdown-options input.
class DocumentTypeFormSheet extends StatefulWidget {
  final WidgetRef ref;
  const DocumentTypeFormSheet({super.key, required this.ref});

  @override
  State<DocumentTypeFormSheet> createState() => _DocumentTypeFormSheetState();
}

class _DocumentTypeFormSheetState extends State<DocumentTypeFormSheet> {
  final _labelCtrl = TextEditingController();
  bool _allowMultiple = false;
  bool _required = false;
  bool _saving = false;
  String? _labelError;

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
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
                const Expanded(
                  child: Text('Add Document Type',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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
                      decoration: _dec('Document Label *', _labelError),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Accepts PDF, JPG, and PNG files up to 5 MB, same as every other document type.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _allowMultiple,
                      onChanged: (v) => setState(() => _allowMultiple = v ?? false),
                      title: const Text('Allow multiple files'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
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
                          : Text('Create Document Type', style: AppTextStyles.label.copyWith(color: Colors.white)),
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
      setState(() => _labelError = 'Label is required.');
      return;
    }
    setState(() => _saving = true);
    final result = await widget.ref.read(documentTypesProvider.notifier).create(
          DocumentTypeFormData(label: label, required: _required, allowMultiple: _allowMultiple),
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
