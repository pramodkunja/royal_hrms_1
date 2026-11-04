part of '../screens/onboarding_screen.dart';

// ─── Admin-configured data steps (0 Personal … 3 Emergency) ─────────────────
//
// Web: app/onboarding/page.tsx + _components/DynamicStepFields.tsx. Every
// visible field configured for the step — built-in and custom alike — in
// configured order, with its configured label and required flag. Values
// edited on any step are kept in onboardingDraftProvider until that step is
// saved, so moving between steps loses nothing. One PATCH per step carries
// the step's values (custom ones by field_key); custom "file" fields upload
// separately as they are chosen.

class _ConfiguredStep extends ConsumerStatefulWidget {
  const _ConfiguredStep({
    super.key,
    required this.step,
    required this.fields,
    required this.values,
    required this.customFiles,
    required this.onSaved,
    required this.onPrevious,
  });

  final int step;
  final List<OnboardingFieldConfigModel> fields; // visible, in order
  final Map<String, String> values; // saved on the server
  final List<CustomFileValue> customFiles;
  final VoidCallback onSaved;
  final VoidCallback? onPrevious;

  @override
  ConsumerState<_ConfiguredStep> createState() => _ConfiguredStepState();
}

class _ConfiguredStepState extends ConsumerState<_ConfiguredStep> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  Map<String, String> _serverErrors = const {};
  final _fileErrors = <String, String>{};

  String _value(Map<String, String> draft, String key) => draft[key] ?? widget.values[key] ?? '';

  List<CustomFileValue> _filesFor(String key) => widget.customFiles.where((f) => f.fieldKey == key).toList();

  Future<void> _save() async {
    if (_saving) return; // one save at a time
    final draft = ref.read(onboardingDraftProvider);
    final formOk = _formKey.currentState?.validate() ?? true;
    _fileErrors.clear();
    for (final f in widget.fields.where((f) => f.fieldType == 'file' && f.required)) {
      if (_filesFor(f.fieldKey).isEmpty) _fileErrors[f.fieldKey] = '${f.label} is required.';
    }
    if (!formOk || _fileErrors.isNotEmpty) {
      setState(() {});
      final missing = widget.fields
          .where((f) =>
              f.required &&
              (f.fieldType == 'file' ? _fileErrors.containsKey(f.fieldKey) : _value(draft, f.fieldKey).trim().isEmpty))
          .map((f) => f.label);
      _snack(missing.isEmpty ? 'Please correct the highlighted fields.' : 'Please fill in: ${missing.join(', ')}');
      return;
    }

    final payload = <String, dynamic>{
      for (final f in widget.fields.where((f) => f.fieldType != 'file')) f.fieldKey: _value(draft, f.fieldKey),
    };
    setState(() {
      _saving = true;
      _serverErrors = const {};
    });
    final err = await ref.read(onboardingProfileProvider.notifier).saveConfiguredStep(widget.step, payload);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      // Everything entered stays as it was; the server's reasons are shown.
      setState(() => _serverErrors = err.fieldErrors);
      _snack(err.message);
      return;
    }
    final keys = widget.fields.map((f) => f.fieldKey).toSet();
    ref.read(onboardingDraftProvider.notifier).state = {
      for (final e in ref.read(onboardingDraftProvider).entries)
        if (!keys.contains(e.key)) e.key: e.value,
    };
    widget.onSaved();
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error));

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingProfileProvider.notifier);
    final regular = widget.fields.where((f) => f.fieldType != 'file').toList();
    final fileFields = widget.fields.where((f) => f.fieldType == 'file').toList();

    return _StepFormWrapper(
      formKey: _formKey,
      saving: _saving,
      onSave: _save,
      onPrevious: widget.onPrevious,
      children: [
        _SectionCard(
          icon: kStepMeta[widget.step]['icon'] as IconData,
          title: kStepTitles[widget.step],
          children: [
            if (widget.fields.isEmpty)
              Text('No fields are configured for this step.', style: AppTextStyles.bodySecondary),
            for (final f in regular)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: OnboardingDynamicField(
                  config: f,
                  value: _value(draft, f.fieldKey),
                  serverError: _serverErrors[f.fieldKey],
                  enabled: !_saving,
                  onChanged: (v) {
                    final current = ref.read(onboardingDraftProvider);
                    ref.read(onboardingDraftProvider.notifier).state = {...current, f.fieldKey: v};
                  },
                ),
              ),
            for (final f in fileFields)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: OnboardingCustomFileField(
                  config: f,
                  files: _filesFor(f.fieldKey),
                  errorText: _fileErrors[f.fieldKey],
                  onUpload: notifier.uploadCustomFile,
                  onDelete: notifier.deleteCustomFile,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
