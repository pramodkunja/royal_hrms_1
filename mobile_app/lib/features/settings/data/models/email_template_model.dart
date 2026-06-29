import 'package:flutter/foundation.dart';

@immutable
class EmailTemplateCategoryModel {
  final int id;
  final String name;        // codename e.g. 'document'
  final String displayName; // e.g. 'Document Templates'
  final String? description;

  const EmailTemplateCategoryModel({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
  });

  factory EmailTemplateCategoryModel.fromJson(Map<String, dynamic> json) =>
      EmailTemplateCategoryModel(
        id:          json['id'] as int,
        name:        json['name'] as String? ?? '',
        displayName: json['display_name'] as String? ?? json['name'] as String? ?? '',
        description: json['description'] as String?,
      );
}

@immutable
class EmailTemplateModel {
  final int id;
  final String name;            // slug e.g. 'pay_slip'
  final String displayName;     // human-readable e.g. 'Pay Slip'
  final String? description;
  final String subject;
  final String body;
  final String? category;       // template_type_display
  final String? templateType;   // template_type codename
  final bool isActive;
  final bool isBuiltin;
  final List<String> availableVariables;
  final String? updatedAt;

  const EmailTemplateModel({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    required this.subject,
    required this.body,
    this.category,
    this.templateType,
    required this.isActive,
    required this.isBuiltin,
    required this.availableVariables,
    this.updatedAt,
  });

  EmailTemplateModel copyWith({bool? isActive}) => EmailTemplateModel(
    id:                 id,
    name:               name,
    displayName:        displayName,
    description:        description,
    subject:            subject,
    body:               body,
    category:           category,
    templateType:       templateType,
    isActive:           isActive ?? this.isActive,
    isBuiltin:          isBuiltin,
    availableVariables: availableVariables,
    updatedAt:          updatedAt,
  );

  factory EmailTemplateModel.fromJson(Map<String, dynamic> json) {
    final rawVars = json['available_variables'];
    final vars = <String>[];
    if (rawVars is List) {
      vars.addAll(rawVars.map((e) => e.toString()));
    }
    return EmailTemplateModel(
      id:                 json['id'] as int,
      name:               json['name'] as String? ?? '',
      displayName:        json['display_name'] as String? ?? json['name'] as String? ?? '',
      description:        json['description'] as String?,
      subject:            json['subject'] as String? ?? '',
      body:               json['body'] as String? ?? '',
      category:           json['template_type_display'] as String?,
      templateType:       json['template_type'] as String?,
      isActive:           json['is_active'] as bool? ?? true,
      isBuiltin:          json['is_builtin'] as bool? ?? false,
      availableVariables: vars,
      updatedAt:          json['updated_at'] as String?,
    );
  }
}

// ── Form model ────────────────────────────────────────────────────────────────

class EmailTemplateFormData {
  String displayName;
  String name;        // slug
  String subject;
  String body;
  String? templateType;
  bool isActive;

  EmailTemplateFormData({
    this.displayName = '',
    this.name = '',
    this.subject = '',
    this.body = '',
    this.templateType,
    this.isActive = true,
  });

  factory EmailTemplateFormData.fromModel(EmailTemplateModel model) =>
      EmailTemplateFormData(
        displayName:  model.displayName,
        name:         model.name,
        subject:      model.subject,
        body:         model.body,
        templateType: model.templateType,
        isActive:     model.isActive,
      );

  static String toSlug(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');

  Map<String, dynamic> toJson({required bool isAdd}) => {
    'display_name': displayName,
    if (isAdd) 'name': name,
    'subject':      subject,
    'body':         body,
    if (templateType != null) 'template_type': templateType,
    'is_active':    isActive,
  };

  Map<String, String?> validate({required bool isAdd}) {
    final errors = <String, String?>{};
    if (displayName.trim().isEmpty) errors['displayName'] = 'Display name is required';
    if (isAdd && name.trim().isEmpty) errors['name'] = 'Slug is required';
    if (isAdd && templateType == null) errors['templateType'] = 'Category is required';
    if (subject.trim().isEmpty) errors['subject'] = 'Subject is required';
    if (body.trim().isEmpty) errors['body'] = 'Body is required';
    return errors;
  }
}
