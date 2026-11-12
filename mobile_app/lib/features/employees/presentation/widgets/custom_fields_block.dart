import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../onboarding/data/models/onboarding_config_models.dart';
import '../../../onboarding/presentation/widgets/onboarding_custom_file_field.dart';
import '../../../onboarding/presentation/widgets/onboarding_dynamic_field.dart';
import '../../../settings/data/models/onboarding_field_config_model.dart';
import 'employee_file_viewer.dart';

// HR-created custom fields (Settings → Onboarding Fields) on employee
// profiles — web employees/[id]/page.tsx (applyFieldConfig/customFieldKeys)
// and dashboard/profile/ProfileClient.tsx. A field belongs to step 0-3 =
// Personal, Education & Experience, Bank Details, Emergency Contact; only
// `is_custom && visible` fields are shown. Types: text, textarea, number,
// date ("YYYY-MM-DD"), dropdown (`options`), checkbox ("true"/"false") and
// file (separate file values). There is no default-value setting.

/// GET /onboarding/field-config/ grouped by step.
final profileFieldConfigProvider = FutureProvider.autoDispose<Map<int, List<OnboardingFieldConfigModel>>>((ref) async {
  final res = await ref.watch(dioProvider).get(ApiConstants.onboardingFieldConfig);
  final body = res.data;
  return OnboardingConfig.parseFields(body is Map && body.containsKey('data') ? body['data'] : body);
});

/// The visible custom fields of [step], in order (web applyFieldConfig).
List<OnboardingFieldConfigModel> customFieldsForStep(Map<int, List<OnboardingFieldConfigModel>> config, int step) =>
    [...(config[step] ?? const <OnboardingFieldConfigModel>[])].where((c) => c.isCustom && c.visible).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

/// Every configured text-type (non-file) custom key, hidden ones included
/// (web customFieldKeys).
List<String> textCustomFieldKeys(Map<int, List<OnboardingFieldConfigModel>> config) => [
      for (final list in config.values)
        for (final c in list)
          if (c.isCustom && c.fieldType != 'file') c.fieldKey,
    ];

/// Web employee-detail save: `custom_field_values` for every configured
/// text-type key — the edited value, else the saved one, else "". Keys of
/// fields no longer configured are not sent; the backend merges the dict
/// into the stored one, so their saved values are kept.
Map<String, String> employeeCustomFieldsPayload(
  Map<int, List<OnboardingFieldConfigModel>> config,
  Map<String, String> saved,
  Map<String, String> edits,
) =>
    {for (final k in textCustomFieldKeys(config)) k: edits[k] ?? saved[k] ?? ''};

/// How a saved value reads on the profile.
String customFieldDisplay(OnboardingFieldConfigModel c, String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return '—';
  if (c.fieldType == 'checkbox') return v == 'true' ? 'Yes' : (v == 'false' ? 'No' : v);
  return v;
}

/// A dropdown whose saved value is no longer an option keeps that value
/// selectable (and visible) rather than showing blank.
OnboardingFieldConfigModel _withSavedOption(OnboardingFieldConfigModel c, String value) {
  if (c.fieldType != 'dropdown' || value.isEmpty || c.options.contains(value)) return c;
  return OnboardingFieldConfigModel(
    fieldKey: c.fieldKey,
    label: c.label,
    fieldType: c.fieldType,
    options: [...c.options, value],
    allowMultiple: c.allowMultiple,
    step: c.step,
    order: c.order,
    visible: c.visible,
    required: c.required,
    isCustom: c.isCustom,
    isLocked: c.isLocked,
    updatedAt: c.updatedAt,
  );
}

/// The custom fields of one profile section: read-only values, an Edit
/// sheet for the text-type ones ([onSaveText], when allowed) and the file
/// fields (upload/replace/delete when [canEditFiles]).
class CustomFieldsBlock extends ConsumerWidget {
  const CustomFieldsBlock({
    super.key,
    required this.step,
    required this.values,
    required this.files,
    this.onSaveText,
    this.canEditFiles = false,
    this.onUpload,
    this.onDelete,
    this.freshFileUrl,
  });

  final int step;
  final Map<String, String> values;
  final List<CustomFileValue> files;

  /// Saves this section's edited text values; null → read-only. Returns an
  /// error message, or null on success.
  final Future<String?> Function(Map<int, List<OnboardingFieldConfigModel>> config, Map<String, String> edits)?
      onSaveText;
  final bool canEditFiles;
  final Future<String?> Function(String fieldKey, String fileName, List<int> bytes)? onUpload;
  final Future<String?> Function(int id)? onDelete;

  /// A new link for file [id] when the file host refused an expired signed
  /// one (HR employee profile); null → no refresh (e.g. My Profile's links
  /// are on the API's own server and don't expire).
  final Future<String?> Function(int id)? freshFileUrl;

  Widget _fileTile(OnboardingFieldConfigModel c, CustomFileValue f, {Widget? trailing}) {
    final fresh = freshFileUrl;
    return EmployeeFileTile(
      key: ValueKey('custom-file-tile-${f.id}'),
      id: f.id,
      url: f.fileUrl ?? '',
      fileName: f.fileName,
      // As before: the editable list shows name · size, the read-only one the name.
      fileSize: trailing == null ? 0 : f.fileSize,
      title: c.label,
      freshUrl: fresh == null ? null : () => fresh(f.id),
      trailing: trailing,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(profileFieldConfigProvider);
    return configAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Could not load custom fields.',
            key: Key('custom-fields-error-$step'), style: AppTextStyles.caption.copyWith(color: AppColors.error)),
      ),
      data: (config) {
        final fields = customFieldsForStep(config, step);
        if (fields.isEmpty) return const SizedBox.shrink();
        final textFields = fields.where((c) => c.fieldType != 'file').toList();
        final fileFields = fields.where((c) => c.fieldType == 'file').toList();
        final save = onSaveText;
        return Container(
          key: Key('custom-fields-$step'),
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('Additional information', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (save != null && textFields.isNotEmpty)
                TextButton.icon(
                  key: Key('custom-fields-edit-$step'),
                  onPressed: () => CustomFieldsEditSheet.show(
                    context,
                    fields: textFields,
                    values: values,
                    onSave: (edits) => save(config, edits),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
            ]),
            for (final c in textFields)
              Padding(
                key: Key('custom-field-${c.fieldKey}'),
                padding: const EdgeInsets.only(top: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.required ? '${c.label} *' : c.label,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(customFieldDisplay(c, values[c.fieldKey]),
                      key: Key('custom-value-${c.fieldKey}'), style: AppTextStyles.body),
                ]),
              ),
            for (final c in fileFields)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: canEditFiles && onUpload != null && onDelete != null
                    ? OnboardingCustomFileField(
                        config: c,
                        files: files.where((f) => f.fieldKey == c.fieldKey).toList(),
                        onUpload: onUpload!,
                        onDelete: onDelete!,
                        // Each file viewable in the app; Remove unchanged.
                        fileRowBuilder: (f, remove) => _fileTile(c, f, trailing: remove),
                      )
                    : _ReadOnlyFiles(
                        config: c,
                        files: files.where((f) => f.fieldKey == c.fieldKey).toList(),
                        tile: (f) => _fileTile(c, f),
                      ),
              ),
          ]),
        );
      },
    );
  }
}

class _ReadOnlyFiles extends StatelessWidget {
  const _ReadOnlyFiles({required this.config, required this.files, required this.tile});
  final OnboardingFieldConfigModel config;
  final List<CustomFileValue> files;
  final Widget Function(CustomFileValue f) tile;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('custom-file-readonly-${config.fieldKey}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(config.required ? '${config.label} *' : config.label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        if (files.isEmpty) Text('—', style: AppTextStyles.body) else for (final f in files) tile(f),
      ],
    );
  }
}

/// Edits one section's text-type custom fields. As web's employee form,
/// required fields are flagged but do not block saving (the backend does
/// not enforce them on this edit). A failed save keeps every value.
class CustomFieldsEditSheet extends StatefulWidget {
  const CustomFieldsEditSheet({super.key, required this.fields, required this.values, required this.onSave});

  final List<OnboardingFieldConfigModel> fields;
  final Map<String, String> values;
  final Future<String?> Function(Map<String, String> edits) onSave;

  static Future<bool> show(
    BuildContext context, {
    required List<OnboardingFieldConfigModel> fields,
    required Map<String, String> values,
    required Future<String?> Function(Map<String, String> edits) onSave,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomFieldsEditSheet(fields: fields, values: values, onSave: onSave),
    );
    return saved ?? false;
  }

  @override
  State<CustomFieldsEditSheet> createState() => _CustomFieldsEditSheetState();
}

class _CustomFieldsEditSheetState extends State<CustomFieldsEditSheet> {
  late final Map<String, String> _edits = {
    for (final c in widget.fields) c.fieldKey: widget.values[c.fieldKey] ?? '',
  };
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await widget.onSave(Map.of(_edits));
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Form(
            autovalidateMode: AutovalidateMode.always,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit additional information', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                for (final c in widget.fields) ...[
                  OnboardingDynamicField(
                    config: _withSavedOption(c, _edits[c.fieldKey] ?? ''),
                    value: _edits[c.fieldKey] ?? '',
                    enabled: !_saving,
                    onChanged: (v) => setState(() => _edits[c.fieldKey] = v),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_error != null) ...[
                  Text(_error!,
                      key: const Key('custom-fields-save-error'),
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                  const SizedBox(height: 10),
                ],
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('custom-fields-save'),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
