import 'package:flutter/foundation.dart';

@immutable
class EmployeeCodeModel {
  final String prefix;
  final int padding;
  final int nextSequence; // backend field: next_sequence
  final String? preview;

  const EmployeeCodeModel({
    required this.prefix,
    required this.padding,
    required this.nextSequence,
    this.preview,
  });

  factory EmployeeCodeModel.empty() => const EmployeeCodeModel(
    prefix: 'EMP',
    padding: 4,
    nextSequence: 1,
  );

  factory EmployeeCodeModel.fromJson(Map<String, dynamic> json) => EmployeeCodeModel(
    prefix:       json['prefix'] as String? ?? 'EMP',
    padding:      json['padding'] as int? ?? 4,
    nextSequence: json['next_sequence'] as int? ?? json['start_number'] as int? ?? 1,
    preview:      json['preview'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'prefix':        prefix,
    'padding':       padding,
    'next_sequence': nextSequence,
  };

  String get localPreview {
    final number = nextSequence.toString().padLeft(padding, '0');
    return '$prefix$number';
  }

  EmployeeCodeModel copyWith({
    String? prefix,
    int? padding,
    int? nextSequence,
    String? preview,
  }) => EmployeeCodeModel(
    prefix:       prefix ?? this.prefix,
    padding:      padding ?? this.padding,
    nextSequence: nextSequence ?? this.nextSequence,
    preview:      preview ?? this.preview,
  );

  Map<String, String?> validate() {
    final errors = <String, String?>{};
    if (prefix.trim().isEmpty) errors['prefix'] = 'Prefix is required';
    if (padding < 3 || padding > 8) errors['padding'] = 'Padding must be 3–8';
    if (nextSequence < 1) errors['startNumber'] = 'Start number must be ≥ 1';
    return errors;
  }
}
