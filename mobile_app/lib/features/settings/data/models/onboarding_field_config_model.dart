/// Onboarding wizard field configuration (steps 0-3 — Personal, Education &
/// Experience, Bank Details, Emergency Contact). Matches backend
/// `OnboardingFieldConfig` / `OnboardingFieldConfigSerializer` exactly.
/// Step 4 (Documents) is a separate sibling model — see [DocumentTypeConfigModel].
class OnboardingFieldConfigModel {
  static const stepPersonal = 0;
  static const stepEducation = 1;
  static const stepBank = 2;
  static const stepEmergency = 3;

  static const stepLabels = {
    stepPersonal: 'Personal Information',
    stepEducation: 'Education & Experience',
    stepBank: 'Bank Details',
    stepEmergency: 'Emergency Contact',
  };

  static const fieldTypeLabels = {
    'text': 'Text',
    'textarea': 'Long text',
    'number': 'Number',
    'date': 'Date',
    'dropdown': 'Dropdown',
    'checkbox': 'Checkbox',
    'file': 'File / Image',
  };

  final String fieldKey;
  final String label;
  final String fieldType;
  final List<String> options;
  final bool allowMultiple;
  final int step;
  final int order;
  final bool visible;
  final bool required;
  final bool isCustom;
  final bool isLocked;
  final String? updatedAt;

  const OnboardingFieldConfigModel({
    required this.fieldKey,
    required this.label,
    required this.fieldType,
    required this.options,
    required this.allowMultiple,
    required this.step,
    required this.order,
    required this.visible,
    required this.required,
    required this.isCustom,
    required this.isLocked,
    this.updatedAt,
  });

  factory OnboardingFieldConfigModel.fromJson(Map<String, dynamic> json) {
    return OnboardingFieldConfigModel(
      fieldKey: json['field_key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      fieldType: json['field_type'] as String? ?? 'text',
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      allowMultiple: json['allow_multiple'] as bool? ?? false,
      step: (json['step'] as num?)?.toInt() ?? 0,
      order: (json['order'] as num?)?.toInt() ?? 0,
      visible: json['visible'] as bool? ?? true,
      required: json['required'] as bool? ?? false,
      isCustom: json['is_custom'] as bool? ?? false,
      isLocked: json['is_locked'] as bool? ?? false,
      updatedAt: json['updated_at'] as String?,
    );
  }

  String get fieldTypeLabel => fieldTypeLabels[fieldType] ?? fieldType;
  String get stepLabel => stepLabels[step] ?? 'Step $step';
}

/// `POST /api/settings/onboarding-fields/` payload — matches
/// `OnboardingFieldConfigCreateSerializer`.
class OnboardingFieldFormData {
  final String label;
  final String fieldType;
  final List<String> options;
  final bool allowMultiple;
  final int step;
  final bool required;

  const OnboardingFieldFormData({
    required this.label,
    required this.fieldType,
    this.options = const [],
    this.allowMultiple = false,
    required this.step,
    this.required = false,
  });

  Map<String, dynamic> toJson() => {
        'label': label.trim(),
        'field_type': fieldType,
        'options': fieldType == 'dropdown' ? options : const [],
        'allow_multiple': fieldType == 'file' ? allowMultiple : false,
        'step': step,
        'required': required,
      };
}

/// Onboarding wizard Step 5 (Documents) type configuration. Matches backend
/// `DocumentTypeConfig` / `DocumentTypeConfigSerializer` exactly.
class DocumentTypeConfigModel {
  final String typeKey;
  final String label;
  final int order;
  final bool visible;
  final bool required;
  final bool allowMultiple;
  final bool isCustom;
  final bool isLocked;
  final String? updatedAt;

  const DocumentTypeConfigModel({
    required this.typeKey,
    required this.label,
    required this.order,
    required this.visible,
    required this.required,
    required this.allowMultiple,
    required this.isCustom,
    required this.isLocked,
    this.updatedAt,
  });

  factory DocumentTypeConfigModel.fromJson(Map<String, dynamic> json) {
    return DocumentTypeConfigModel(
      typeKey: json['type_key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      visible: json['visible'] as bool? ?? true,
      required: json['required'] as bool? ?? false,
      allowMultiple: json['allow_multiple'] as bool? ?? false,
      isCustom: json['is_custom'] as bool? ?? false,
      isLocked: json['is_locked'] as bool? ?? false,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

/// `POST /api/settings/document-types/` payload — matches
/// `DocumentTypeConfigCreateSerializer`.
class DocumentTypeFormData {
  final String label;
  final bool required;
  final bool allowMultiple;

  const DocumentTypeFormData({
    required this.label,
    this.required = false,
    this.allowMultiple = false,
  });

  Map<String, dynamic> toJson() => {
        'label': label.trim(),
        'required': required,
        'allow_multiple': allowMultiple,
      };
}
