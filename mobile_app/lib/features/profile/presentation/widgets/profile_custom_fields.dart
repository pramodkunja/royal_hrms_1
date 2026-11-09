import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../employees/presentation/widgets/custom_fields_block.dart';
import '../../../onboarding/data/models/onboarding_config_models.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../../settings/data/models/onboarding_field_config_model.dart';
import '../providers/profile_providers.dart';

/// Web ProfileClient: after onboarding only the Emergency step's custom
/// fields (text and file) are self-editable; Personal, Education and Bank
/// custom fields are shown read-only. The backend enforces the same rule
/// (MyProfileView.patch keeps Emergency keys only; _self_can_write_custom_file).
const kSelfEditableCustomStep = 3;

/// The Emergency-step text keys from [edits] (web ProfileClient handleSave
/// filters custom_field_values to them).
Map<String, String> selfCustomFieldsPayload(
        Map<int, List<OnboardingFieldConfigModel>> config, Map<String, String> edits) =>
    {
      for (final c in config[kSelfEditableCustomStep] ?? const <OnboardingFieldConfigModel>[])
        if (c.isCustom && c.fieldType != 'file' && edits.containsKey(c.fieldKey)) c.fieldKey: edits[c.fieldKey]!,
    };

class ProfileCustomFields extends ConsumerWidget {
  const ProfileCustomFields({super.key, required this.step, required this.values});

  final int step;
  final Map<String, String> values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editable = step == kSelfEditableCustomStep;
    final files = ref.watch(onboardingCustomFilesProvider).valueOrNull ?? const <CustomFileValue>[];
    return CustomFieldsBlock(
      step: step,
      values: values,
      files: files,
      onSaveText: editable
          ? (config, edits) =>
              ref.read(myProfileProvider.notifier).saveCustomFields(selfCustomFieldsPayload(config, edits))
          : null,
      canEditFiles: editable,
      onUpload: (key, name, bytes) async {
        try {
          await ref.read(onboardingDatasourceProvider).uploadCustomFile(key, name, bytes);
          ref.invalidate(onboardingCustomFilesProvider);
          return null;
        } catch (e) {
          return friendlyProfileError(e);
        }
      },
      onDelete: (id) async {
        try {
          await ref.read(onboardingDatasourceProvider).deleteCustomFile(id);
          ref.invalidate(onboardingCustomFilesProvider);
          return null;
        } catch (e) {
          return friendlyProfileError(e);
        }
      },
    );
  }
}
