import 'package:flutter/foundation.dart';

// Holiday type codes — match backend HOLIDAY_TYPE_CHOICES exactly
// (apps/hrms/models.py): national, regional, company.
class HolidayType {
  HolidayType._();
  static const String national = 'national';
  static const String regional = 'regional';
  static const String company = 'company';

  static const List<String> all = [national, regional, company];

  static String label(String type) => switch (type) {
    national => 'National',
    regional => 'Regional',
    company => 'Company',
    _ => type,
  };
}

@immutable
class HolidayModel {
  final String id; // UUID from backend
  final String name;
  final DateTime date;
  final String type; // HolidayType.national | regional | company
  final bool isOptional;
  final String description;
  final int? branchId; // null = company-wide holiday
  final String branchName; // "All Branches" when branchId is null
  final bool isActive;

  const HolidayModel({
    required this.id,
    required this.name,
    required this.date,
    required this.type,
    required this.isOptional,
    required this.description,
    required this.branchId,
    required this.branchName,
    required this.isActive,
  });

  factory HolidayModel.fromJson(Map<String, dynamic> json) {
    return HolidayModel(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      type: json['holiday_type'] as String? ?? HolidayType.national,
      isOptional: json['is_optional'] as bool? ?? false,
      description: json['description'] as String? ?? '',
      branchId: json['branch'] as int?,
      branchName: json['branch_name'] as String? ?? 'All Branches',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  HolidayModel copyWith({
    String? name,
    DateTime? date,
    String? type,
    bool? isOptional,
    String? description,
    int? branchId,
    bool clearBranch = false,
    String? branchName,
    bool? isActive,
  }) {
    return HolidayModel(
      id: id,
      name: name ?? this.name,
      date: date ?? this.date,
      type: type ?? this.type,
      isOptional: isOptional ?? this.isOptional,
      description: description ?? this.description,
      branchId: clearBranch ? null : (branchId ?? this.branchId),
      branchName: branchName ?? this.branchName,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Mutable form-data class for the Add/Edit dialog, following the same
/// pattern as DeptFormData/DesignationFormData.
class HolidayFormData {
  String name;
  DateTime? date;
  String type;
  bool isOptional;
  String description;
  int? branchId; // null = company-wide
  String branchLabel; // display label for the selected branch option
  bool isActive;

  HolidayFormData({
    this.name = '',
    this.date,
    this.type = HolidayType.national,
    this.isOptional = false,
    this.description = '',
    this.branchId,
    this.branchLabel = 'All Branches (Company-wide)',
    this.isActive = true,
  });

  factory HolidayFormData.fromModel(HolidayModel model) => HolidayFormData(
    name: model.name,
    date: model.date,
    type: model.type,
    isOptional: model.isOptional,
    description: model.description,
    branchId: model.branchId,
    branchLabel: model.branchId == null ? 'All Branches (Company-wide)' : model.branchName,
    isActive: model.isActive,
  );

  // Mirrors backend/apps/hrms/serializers.py _HOLIDAY_NAME_RE exactly —
  // letters, spaces, apostrophes, periods, hyphens; must contain a letter.
  static final RegExp _nameRe = RegExp(r"^(?=.*[A-Za-z])[A-Za-z .'-]+$");

  static String sanitizeName(String value) =>
      value.replaceAll(RegExp(r"[^A-Za-z .'-]"), '');

  /// Field-level validation errors, keyed by field name — matches the
  /// reference screen's exact copy: "Holiday name is required." /
  /// "Date is required."
  Map<String, String?> validate() {
    final errors = <String, String?>{};
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      errors['name'] = 'Holiday name is required.';
    } else if (!_nameRe.hasMatch(trimmedName)) {
      errors['name'] =
          "Holiday name can only contain letters, spaces, apostrophes, periods, and hyphens.";
    }
    if (date == null) errors['date'] = 'Date is required.';
    return errors;
  }
}
