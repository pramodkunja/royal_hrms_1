import 'package:flutter/foundation.dart';

// Holiday type codes — match the reference web screen's HolidayType union exactly.
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
  final int id;
  final String name;
  final DateTime date;
  final String type; // HolidayType.national | regional | company
  final bool isOptional;
  final String applicableBranches; // "All" or comma-separated branch names
  final bool isActive;

  const HolidayModel({
    required this.id,
    required this.name,
    required this.date,
    required this.type,
    required this.isOptional,
    required this.applicableBranches,
    required this.isActive,
  });

  HolidayModel copyWith({
    String? name,
    DateTime? date,
    String? type,
    bool? isOptional,
    String? applicableBranches,
    bool? isActive,
  }) {
    return HolidayModel(
      id: id,
      name: name ?? this.name,
      date: date ?? this.date,
      type: type ?? this.type,
      isOptional: isOptional ?? this.isOptional,
      applicableBranches: applicableBranches ?? this.applicableBranches,
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
  String applicableBranches;
  bool isOptional;
  bool isActive;

  HolidayFormData({
    this.name = '',
    this.date,
    this.type = HolidayType.national,
    this.applicableBranches = 'All',
    this.isOptional = false,
    this.isActive = true,
  });

  factory HolidayFormData.fromModel(HolidayModel model) => HolidayFormData(
    name: model.name,
    date: model.date,
    type: model.type,
    applicableBranches: model.applicableBranches,
    isOptional: model.isOptional,
    isActive: model.isActive,
  );

  /// Field-level validation errors, keyed by field name — matches the
  /// reference screen's exact copy: "Holiday name is required." /
  /// "Date is required."
  Map<String, String?> validate() {
    final errors = <String, String?>{};
    if (name.trim().isEmpty) errors['name'] = 'Holiday name is required.';
    if (date == null) errors['date'] = 'Date is required.';
    return errors;
  }
}
