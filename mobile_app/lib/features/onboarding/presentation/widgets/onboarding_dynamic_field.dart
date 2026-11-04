import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../settings/data/models/onboarding_field_config_model.dart';

/// Built-in profile fields whose values are fixed choices — the same lists
/// web's OnboardingDynamicField uses (they are Django choice fields).
const kBuiltinChoiceFields = <String, List<(String, String)>>{
  'gender': [('male', 'Male'), ('female', 'Female'), ('other', 'Other / Prefer not to say')],
  'marital_status': [('single', 'Single'), ('married', 'Married'), ('divorced', 'Divorced'), ('widowed', 'Widowed')],
  'blood_group': [
    ('A+', 'A+'),
    ('A-', 'A-'),
    ('B+', 'B+'),
    ('B-', 'B-'),
    ('O+', 'O+'),
    ('O-', 'O-'),
    ('AB+', 'AB+'),
    ('AB-', 'AB-'),
  ],
  'account_type': [('savings', 'Savings'), ('current', 'Current')],
};

/// Field types this renderer knows (OnboardingFieldConfig.FIELD_TYPE_CHOICES
/// minus "file", which [OnboardingCustomFileField] handles). Anything else is
/// shown as a plain text input, as web does.
const kSupportedFieldTypes = {'text', 'textarea', 'number', 'date', 'dropdown', 'checkbox'};

/// Keyboard and length hints the old fixed steps used for these built-in
/// fields — conveniences only; the server validates the values.
TextInputType _keyboardFor(String key, String type) {
  if (type == 'number' || key == 'account_number' || key == 'year_of_passing' || key == 'total_experience_years') {
    return TextInputType.number;
  }
  if (key.endsWith('phone')) return TextInputType.phone;
  if (key.endsWith('email')) return TextInputType.emailAddress;
  return TextInputType.text;
}

/// One admin-configured onboarding field (web: OnboardingDynamicField).
/// Values are text, as on web: dates "YYYY-MM-DD", checkboxes "true"/"false".
class OnboardingDynamicField extends StatelessWidget {
  final OnboardingFieldConfigModel config;
  final String value;
  final ValueChanged<String> onChanged;
  final String? serverError;
  final bool enabled;

  const OnboardingDynamicField({
    super.key,
    required this.config,
    required this.value,
    required this.onChanged,
    this.serverError,
    this.enabled = true,
  });

  String get _label => config.required ? '${config.label} *' : config.label;

  String? _validate(String? v) {
    final text = (v ?? '').trim();
    if (config.required && text.isEmpty) return '${config.label} is required.';
    if (text.isNotEmpty && config.fieldType == 'number' && num.tryParse(text) == null) {
      return 'Enter a number.';
    }
    return null;
  }

  InputDecoration _dec({Widget? suffix}) => InputDecoration(
        labelText: _label,
        errorText: serverError,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    final choices = kBuiltinChoiceFields[config.fieldKey] ??
        (config.fieldType == 'dropdown' ? [for (final o in config.options) (o, o)] : null);

    if (choices != null) {
      final current = choices.any((c) => c.$1 == value) ? value : null;
      return DropdownButtonFormField<String>(
        key: Key('onboarding-field-${config.fieldKey}'),
        initialValue: current,
        isExpanded: true,
        decoration: _dec(),
        items: [
          for (final (v, l) in choices) DropdownMenuItem(value: v, child: Text(l, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: enabled ? (v) => onChanged(v ?? '') : null,
        validator: _validate,
      );
    }

    if (config.fieldType == 'checkbox') {
      return FormField<String>(
        key: Key('onboarding-field-${config.fieldKey}'),
        initialValue: value,
        validator: (_) => config.required && value != 'true' ? '${config.label} is required.' : null,
        builder: (state) => Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            value: value == 'true',
            onChanged: enabled ? (v) => onChanged(v == true ? 'true' : 'false') : null,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(_label, style: AppTextStyles.body),
            subtitle: (state.errorText ?? serverError) == null
                ? null
                : Text(state.errorText ?? serverError!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
        ),
      );
    }

    if (config.fieldType == 'date') {
      return _TextInput(
        key: Key('onboarding-field-${config.fieldKey}'),
        value: value,
        onChanged: onChanged,
        readOnly: true,
        enabled: enabled,
        maxLines: 1,
        keyboardType: TextInputType.none,
        decoration: _dec(suffix: const Icon(Icons.calendar_today_outlined, size: 18)),
        validator: _validate,
        onTap: () async {
          final initial = DateTime.tryParse(value) ?? DateTime(2000);
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            onChanged('${picked.year.toString().padLeft(4, '0')}-'
                '${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
          }
        },
      );
    }

    return _TextInput(
      key: Key('onboarding-field-${config.fieldKey}'),
      value: value,
      onChanged: onChanged,
      decoration: _dec(),
      validator: _validate,
      enabled: enabled,
      maxLines: config.fieldType == 'textarea' ? 3 : 1,
      keyboardType:
          config.fieldType == 'textarea' ? TextInputType.multiline : _keyboardFor(config.fieldKey, config.fieldType),
      maxLength: config.fieldKey == 'ifsc_code' ? 11 : null,
      upperCase: config.fieldKey == 'ifsc_code',
    );
  }
}

/// A text input that keeps its own controller, so typing isn't reset by the
/// parent rebuilding with the same value.
class _TextInput extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final FormFieldValidator<String> validator;
  final bool enabled;
  final int maxLines;
  final TextInputType keyboardType;
  final int? maxLength;
  final bool upperCase;
  final bool readOnly;
  final VoidCallback? onTap;

  const _TextInput({
    super.key,
    required this.value,
    required this.onChanged,
    required this.decoration,
    required this.validator,
    required this.enabled,
    required this.maxLines,
    required this.keyboardType,
    this.maxLength,
    this.upperCase = false,
    this.readOnly = false,
    this.onTap,
  });

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final _ctrl = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _TextInput old) {
    super.didUpdateWidget(old);
    if (widget.value != _ctrl.text) _ctrl.text = widget.value;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: _ctrl,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        onTap: widget.onTap,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        maxLength: widget.maxLength,
        textCapitalization: widget.upperCase ? TextCapitalization.characters : TextCapitalization.none,
        inputFormatters: widget.upperCase ? [_UpperCase()] : null,
        decoration: widget.decoration.copyWith(counterText: ''),
        validator: widget.validator,
        onChanged: widget.onChanged,
      );
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
