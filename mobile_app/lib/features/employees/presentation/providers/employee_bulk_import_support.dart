import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/bulk_import_result.dart';
import '../../../auth/domain/entities/user_entity.dart';

/// Web employees/page.tsx shows the Bulk Import entry to `employees.create`;
/// the server (EmployeeBulkImportView / EmployeeBulkImportSampleView) checks
/// the same codename.
bool canOpenEmployeeBulkImport(UserEntity? user) =>
    user != null && (user.isSuperuser || user.permissions.contains('employees.create'));

const kEmployeeImportDenied = 'You do not have permission to import employees.';
const kEmployeeSampleFailed = 'Failed to download sample file.';
const kEmployeeErrorReportFileName = 'error_report.csv';

/// Web BulkImportModal `validateFile`, same wording.
String? checkEmployeeImportFile(String name, int size) {
  final lower = name.toLowerCase();
  if (!lower.endsWith('.csv') && !lower.endsWith('.xlsx')) {
    return 'Unsupported file type. Please upload a .csv or .xlsx file.';
  }
  if (size > 5 * 1024 * 1024) return 'File is too large. Maximum allowed size is 5 MB.';
  return null;
}

/// Web lib/csv.ts `csvCell`: quote only when the text has a comma, a double
/// quote or a line feed; embedded quotes are doubled.
String _csvCell(Object? value) {
  final text = value?.toString() ?? '';
  return RegExp('[",\n]').hasMatch(text) ? '"${text.replaceAll('"', '""')}"' : text;
}

/// Web `downloadErrorReport`: header Row,Email,Field,Error then one line per
/// import error, joined with "\n" (no trailing newline, no BOM), UTF-8.
String buildEmployeeImportErrorReport(List<BulkImportErrorResult> errors) {
  final rows = <List<Object?>>[
    ['Row', 'Email', 'Field', 'Error'],
    ...errors.map((e) => [e.row, e.identifier, e.field, e.message]),
  ];
  return rows.map((r) => r.map(_csvCell).join(',')).join('\n');
}

Uint8List employeeImportErrorReportBytes(List<BulkImportErrorResult> errors) =>
    Uint8List.fromList(utf8.encode(buildEmployeeImportErrorReport(errors)));

/// Saves a file through the system "save as" dialog (no storage permission);
/// returns the saved path, or null when the user cancels. Tests override it.
final employeeFileSaverProvider = Provider<Future<String?> Function(String fileName, Uint8List bytes)>(
  (ref) => (fileName, bytes) => FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: [fileName.split('.').last],
      ),
);
