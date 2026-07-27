import 'package:flutter/foundation.dart';

// Shared shape for both bulk-import endpoints (employees, candidates) — the
// backend deliberately returns the same three-bucket envelope for both (see
// EmployeeBulkImportView / CandidateBulkImportView in the Django backend):
// duplicates are skipped (not failed), and every row error carries a row
// number + field so the user can fix and re-upload just the bad rows.

@immutable
class BulkImportRowResult {
  final int row;
  final String identifier;
  final String? extra; // e.g. the generated employee_id
  const BulkImportRowResult({required this.row, required this.identifier, this.extra});

  factory BulkImportRowResult.fromJson(Map<String, dynamic> json) => BulkImportRowResult(
    row: (json['row'] as num? ?? 0).toInt(),
    identifier: json['identifier'] as String? ?? '',
    extra: json['employee_id'] as String?,
  );
}

@immutable
class BulkImportSkipResult {
  final int row;
  final String identifier;
  final String reason;
  const BulkImportSkipResult({required this.row, required this.identifier, required this.reason});

  factory BulkImportSkipResult.fromJson(Map<String, dynamic> json) => BulkImportSkipResult(
    row: (json['row'] as num? ?? 0).toInt(),
    identifier: json['identifier'] as String? ?? '',
    reason: json['reason'] as String? ?? '',
  );
}

@immutable
class BulkImportErrorResult {
  final int row;
  final String field;
  final String? identifier;
  final String message;
  const BulkImportErrorResult({
    required this.row,
    required this.field,
    this.identifier,
    required this.message,
  });

  factory BulkImportErrorResult.fromJson(Map<String, dynamic> json) => BulkImportErrorResult(
    row: (json['row'] as num? ?? 0).toInt(),
    field: json['field'] as String? ?? '',
    identifier: json['identifier'] as String?,
    message: json['message'] as String? ?? '',
  );
}

@immutable
class BulkImportResult {
  final int totalRows;
  final int created;
  final int skipped;
  final int failed;
  final List<BulkImportRowResult> createdRows;
  final List<BulkImportSkipResult> skippedRows;
  final List<BulkImportErrorResult> errors;

  const BulkImportResult({
    required this.totalRows,
    required this.created,
    required this.skipped,
    required this.failed,
    required this.createdRows,
    required this.skippedRows,
    required this.errors,
  });

  factory BulkImportResult.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) parser) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw.whereType<Map<String, dynamic>>().map(parser).toList();
    }

    return BulkImportResult(
      totalRows: (json['total_rows'] as num? ?? 0).toInt(),
      created: (json['created'] as num? ?? 0).toInt(),
      skipped: (json['skipped'] as num? ?? 0).toInt(),
      failed: (json['failed'] as num? ?? 0).toInt(),
      createdRows: parseList('created_rows', BulkImportRowResult.fromJson),
      skippedRows: parseList('skipped_rows', BulkImportSkipResult.fromJson),
      errors: parseList('errors', BulkImportErrorResult.fromJson),
    );
  }
}
