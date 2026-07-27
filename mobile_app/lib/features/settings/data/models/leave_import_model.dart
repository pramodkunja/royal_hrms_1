import 'package:flutter/foundation.dart';

// Opening Balance & History bulk import — one-time historical migration tool
// (LeaveOpeningBalanceValidateView / LeaveOpeningBalanceImportView). A row is
// either a "balance" row (annual totals) or a "history" row (individual
// leave dates); the unused columns are blank per row type.

@immutable
class LeaveImportPreviewRow {
  final int row;
  final String rowType; // 'balance' | 'history'
  final String employeeId;
  final String leaveType;
  final String financialYear;
  final String? fromDate;
  final String? toDate;
  final String? days;
  final bool valid;
  final String? error;

  const LeaveImportPreviewRow({
    required this.row,
    required this.rowType,
    required this.employeeId,
    required this.leaveType,
    required this.financialYear,
    this.fromDate,
    this.toDate,
    this.days,
    required this.valid,
    this.error,
  });

  bool get isHistory => rowType == 'history';

  factory LeaveImportPreviewRow.fromJson(Map<String, dynamic> json) => LeaveImportPreviewRow(
    row:           (json['row'] as num?)?.toInt() ?? 0,
    rowType:       json['row_type'] as String? ?? 'balance',
    employeeId:    json['employee_id'] as String? ?? '',
    leaveType:     json['leave_type'] as String? ?? '',
    financialYear: json['financial_year'] as String? ?? '',
    fromDate:      json['from_date'] as String?,
    toDate:        json['to_date'] as String?,
    days:          json['days']?.toString(),
    valid:         json['valid'] as bool? ?? false,
    error:         json['error'] as String?,
  );
}

@immutable
class LeaveImportValidateResult {
  final int totalRows;
  final int validRows;
  final int errorRows;
  final int balanceRows;
  final int historyRows;
  final List<LeaveImportPreviewRow> preview;

  const LeaveImportValidateResult({
    required this.totalRows,
    required this.validRows,
    required this.errorRows,
    required this.balanceRows,
    required this.historyRows,
    required this.preview,
  });

  factory LeaveImportValidateResult.fromJson(Map<String, dynamic> json) => LeaveImportValidateResult(
    totalRows:   (json['total_rows'] as num?)?.toInt() ?? 0,
    validRows:   (json['valid_rows'] as num?)?.toInt() ?? 0,
    errorRows:   (json['error_rows'] as num?)?.toInt() ?? 0,
    balanceRows: (json['balance_rows'] as num?)?.toInt() ?? 0,
    historyRows: (json['history_rows'] as num?)?.toInt() ?? 0,
    preview: (json['preview'] as List<dynamic>? ?? [])
        .map((e) => LeaveImportPreviewRow.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

@immutable
class LeaveImportRowError {
  final int row;
  final String employeeId;
  final String leaveType;
  final String financialYear;
  final String? fromDate;
  final String? toDate;
  final String reason;

  const LeaveImportRowError({
    required this.row,
    required this.employeeId,
    required this.leaveType,
    required this.financialYear,
    this.fromDate,
    this.toDate,
    required this.reason,
  });

  factory LeaveImportRowError.fromJson(Map<String, dynamic> json) => LeaveImportRowError(
    row:           (json['row'] as num?)?.toInt() ?? 0,
    employeeId:    json['employee_id'] as String? ?? '',
    leaveType:     json['leave_type'] as String? ?? '',
    financialYear: json['financial_year'] as String? ?? '',
    fromDate:      json['from_date'] as String?,
    toDate:        json['to_date'] as String?,
    reason:        json['reason'] as String? ?? '',
  );
}

@immutable
class LeaveImportResult {
  final int totalRecords;
  final int balancesCreated;
  final int historyImported;
  final int successful;
  final int failed;
  final int skipped;
  final List<LeaveImportRowError> errors;
  final String? errorReportCsv;

  const LeaveImportResult({
    required this.totalRecords,
    required this.balancesCreated,
    required this.historyImported,
    required this.successful,
    required this.failed,
    required this.skipped,
    required this.errors,
    this.errorReportCsv,
  });

  factory LeaveImportResult.fromJson(Map<String, dynamic> json) => LeaveImportResult(
    totalRecords:    (json['total_records'] as num?)?.toInt() ?? 0,
    balancesCreated: (json['balances_created'] as num?)?.toInt() ?? 0,
    historyImported: (json['history_imported'] as num?)?.toInt() ?? 0,
    successful:      (json['successful'] as num?)?.toInt() ?? 0,
    failed:          (json['failed'] as num?)?.toInt() ?? 0,
    skipped:         (json['skipped'] as num?)?.toInt() ?? 0,
    errors: (json['errors'] as List<dynamic>? ?? [])
        .map((e) => LeaveImportRowError.fromJson(e as Map<String, dynamic>))
        .toList(),
    errorReportCsv: json['error_report_csv'] as String?,
  );
}
