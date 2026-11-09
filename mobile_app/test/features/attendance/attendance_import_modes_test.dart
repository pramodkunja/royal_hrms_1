import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/attendance/data/models/attendance_models.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// P1-4: HR Attendance → Import, bulk and single-employee modes, as web
// ImportModal.tsx against production HRAttendanceImportView
// (POST /attendance/import/, multipart `file` + optional `employee_id`,
// `date_from`, `date_to`). Synthetic employees, dates and files only.

const importPath = ApiConstants.attendanceImport;

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> resultBody({
  String status = 'partial',
  int total = 3,
  int successful = 2,
  int failed = 1,
  int skipped = 0,
  String message = '2 of 3 records imported. 1 failed.',
  List<Map<String, dynamic>>? errors,
}) =>
    {
      'import_id': '0b6f2b1e-0000-4000-8000-000000000001',
      'status': status,
      'message': message,
      'total_records': total,
      'successful': successful,
      'failed': failed,
      'skipped': skipped,
      'errors': errors ??
          [
            {
              'row': 3,
              'employee_id': 'TST002',
              'employee_name': '',
              'attendance_date': '2026-07-03',
              'reason': "This row is for employee 'TST002', not the selected employee 'TST001'.",
              'resolution': 'Remove this row or import it for the right employee.',
            }
          ],
    };

Map<String, dynamic> previewBody({
  int total = 3,
  int toCreate = 1,
  int toUpdate = 1,
  int skipped = 0,
  int failed = 1,
  bool truncated = false,
  String? reportCsv,
  Map<String, dynamic>? employee,
  List<Map<String, dynamic>>? rows,
}) =>
    {
      'status': 'preview',
      'message': 'Preview: ${toCreate + toUpdate} of $total rows will be imported. $failed have errors.',
      'total_records': total,
      'to_create': toCreate,
      'to_update': toUpdate,
      'skipped': skipped,
      'failed': failed,
      'errors': resultBody()['errors'],
      'rows': rows ??
          [
            {
              'row': 1,
              'employee_id': 'TST001',
              'employee_name': 'Test Person One',
              'date': '2026-07-01',
              'punch_in': '09:00',
              'punch_out': '18:00',
              'action': 'create'
            },
            {
              'row': 2,
              'employee_id': 'TST001',
              'employee_name': 'Test Person One',
              'date': '2026-07-02',
              'punch_in': '09:05',
              'punch_out': '18:15',
              'action': 'update'
            },
          ],
      'rows_truncated': truncated,
      if (reportCsv != null) 'error_report_csv': reportCsv,
      if (employee != null) 'employee': employee,
    };

bool isDryRun(Object? body) => body is FormData && body.fields.any((f) => f.key == 'dry_run' && f.value == 'true');

class FakeServer implements HttpClientAdapter {
  /// Answer for the real import (no dry_run).
  ({int status, Map<String, dynamic> body})? nextImport;
  Completer<void>? holdImport;

  /// Answers for dry runs, used in order (the last one repeats).
  final nextPreviews = <({int status, Map<String, dynamic> body})>[];
  Completer<void>? holdPreview;
  final calls = <({String method, String path, Map<String, dynamic> query, Object? body})>[];

  List<({String method, String path, Map<String, dynamic> query, Object? body})> of(String method, String path) =>
      calls.where((c) => c.method == method && c.path == path).toList();
  /// Real imports only (no dry_run).
  List<FormData> get imports =>
      of('POST', importPath).where((c) => !isDryRun(c.body)).map((c) => c.body as FormData).toList();

  /// Dry runs only.
  List<FormData> get previews =>
      of('POST', importPath).where((c) => isDryRun(c.body)).map((c) => c.body as FormData).toList();

  /// Every POST to the import endpoint, in order: 'preview' or 'import'.
  List<String> get sequence => of('POST', importPath).map((c) => isDryRun(c.body) ? 'preview' : 'import').toList();
  int get otherGets => calls.where((c) => c.method == 'GET' && c.path != ApiConstants.employees).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: Map.of(o.queryParameters), body: o.data));
    if (o.method == 'POST' && o.path == importPath && isDryRun(o.data)) {
      final gate = holdPreview;
      if (gate != null) await gate.future;
      final r = nextPreviews.isEmpty
          ? (status: 200, body: {'status': 'success', 'message': 'preview', 'data': previewBody()})
          : (nextPreviews.length > 1 ? nextPreviews.removeAt(0) : nextPreviews.first);
      return _json(r.status, r.body);
    }
    if (o.method == 'POST' && o.path == importPath) {
      final gate = holdImport;
      if (gate != null) await gate.future;
      final r = nextImport ??
          (
            status: 207,
            body: {'status': 'success', 'message': '2 of 3 records imported. 1 failed.', 'data': resultBody()}
          );
      return _json(r.status, r.body);
    }
    if (o.method == 'GET' && o.path == ApiConstants.employees) {
      return _json(200, {
        'status': 'success',
        'data': {
          'count': 1,
          'results': [
            {
              'id': 'u1',
              'employee_id': 'TST001',
              'full_name': 'Test Person One',
              'department': 'Engineering',
              'designation': 'Analyst',
            }
          ],
        },
      });
    }
    return _json(200, {
      'status': 'success',
      'message': 'ok',
      'data': {'results': [], 'count': 0, 'summary_chips': <String, int>{}},
    });
  }

  @override
  void close({bool force = false}) {}
}

class _NullStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class _Auth extends AuthNotifier {
  _Auth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

UserEntity hrUser(List<String> perms, {bool superuser = false}) => UserEntity(
      id: 'hr1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final importer = hrUser(['attendance.view', 'attendance.create', 'employees.view']);
final viewer = hrUser(['attendance.view', 'attendance.export', 'employees.view']);

late FakeServer server;
PlatformFile? nextFile;
DateTime? nextDate;
final savedReports = <({String name, List<int> bytes})>[];

PlatformFile csv([String name = 'attendance.csv', String? body]) {
  final bytes = Uint8List.fromList(
      utf8.encode(body ?? 'employee_id,date,punch_in,punch_out\nTST001,2026-07-02,09:05,18:15\n'));
  return PlatformFile(name: name, size: bytes.length, bytes: bytes);
}

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      attendanceImportFilePickerProvider.overrideWithValue(() async => nextFile),
      attendanceImportDatePickerProvider.overrideWithValue((context, initial) async => nextDate),
      attendanceImportReportSaverProvider.overrideWithValue((name, bytes) async {
        savedReports.add((name: name, bytes: bytes));
        return '/synthetic/$name';
      }),
    ];

Future<void> pumpScreen(WidgetTester tester, {UserEntity? as, FakeServer? with_}) async {
  tester.view.physicalSize = const Size(1600, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? FakeServer();
  nextFile = null;
  nextDate = null;
  savedReports.clear();
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? importer),
    child: const MaterialApp(home: Scaffold(body: AttendanceScreen())),
  ));
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(tester.element(find.byType(AttendanceScreen)));
  await c.read(authStateProvider.future);
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

Future<void> openImport(WidgetTester tester) async {
  await tester.tap(byKey('attendance-import-button'));
  await tester.pumpAndSettle();
  expect(find.text('Import Attendance'), findsOneWidget);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

Future<void> pickFile(WidgetTester tester, [PlatformFile? f]) async {
  nextFile = f ?? csv();
  await tapKey(tester, 'attendance-import-file');
}

Future<void> pickEmployee(WidgetTester tester) async {
  final field = find.descendant(of: byKey('attendance-import-employee'), matching: find.byType(TextField));
  await tester.enterText(field, 'tes');
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test Person One'));
  await tester.pumpAndSettle();
}

Future<void> pickDate(WidgetTester tester, String which, DateTime d) async {
  nextDate = d;
  await tapKey(tester, 'attendance-import-date-$which');
}

Future<void> preview(WidgetTester tester) => tapKey(tester, 'attendance-import-preview');

/// Preview, then (if the preview came back) confirm — the full web flow.
Future<void> upload(WidgetTester tester) async {
  await preview(tester);
  if (byKey('attendance-import-confirm').evaluate().isNotEmpty) await tapKey(tester, 'attendance-import-confirm');
}

String confirmLabel(WidgetTester tester) => tester
    .widget<Text>(find.descendant(of: byKey('attendance-import-confirm'), matching: find.byType(Text)))
    .data!;

bool confirmEnabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(byKey('attendance-import-confirm')).onPressed != null;

Map<String, String> fieldMap(FormData f) => {for (final e in f.fields) e.key: e.value};

String? errorText(WidgetTester tester) {
  final f = byKey('attendance-import-error');
  return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
}

List<String> fields(FormData f) => f.fields.map((e) => '${e.key}=${e.value}').toList();

Future<ProviderContainer> signedIn(UserEntity u) async {
  final c = ProviderContainer(overrides: overrides(u));
  addTearDown(c.dispose);
  await c.read(authStateProvider.future);
  return c;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('result parsing (production keys)', () {
    test('total_records / successful / skipped / message and reason-based row errors', () {
      final r = ImportResultModel.fromJson(resultBody(skipped: 1));
      expect([r.totalRows, r.success, r.failed, r.skipped], [3, 2, 1, 1]);
      expect(r.message, '2 of 3 records imported. 1 failed.');
      final e = r.errors.single;
      expect(e.row, 3);
      expect(e.message, "This row is for employee 'TST002', not the selected employee 'TST001'.");
      expect(e.employee, 'TST002');
      expect(e.date, '2026-07-03');
      expect(e.resolution, 'Remove this row or import it for the right employee.');
    });

    test('older keys are still read', () {
      final r = ImportResultModel.fromJson({
        'total_rows': 4,
        'success': 3,
        'failed': 1,
        'status': 'partial',
        'errors': [
          {
            'row': 2,
            'errors': {
              'date': ['Invalid date.']
            }
          }
        ],
      });
      expect([r.totalRows, r.success, r.failed, r.skipped], [4, 3, 1, 0]);
      expect(r.errors.single.message, 'date: Invalid date.');
    });
  });

  group('modes', () {
    testWidgets('1. both modes are offered; Bulk is selected and shows no employee/date controls', (tester) async {
      await pumpScreen(tester);
      await openImport(tester);
      expect(find.text('Import for All Employees'), findsOneWidget);
      expect(find.text('Import for One Employee'), findsOneWidget);
      expect(byKey('attendance-import-employee'), findsNothing);
      expect(byKey('attendance-import-date-from'), findsNothing);
    });

    testWidgets('2. single mode shows the employee picker, optional From/To dates and its own file note',
        (tester) async {
      await pumpScreen(tester);
      await openImport(tester);
      await tapKey(tester, 'attendance-import-mode-single');
      expect(byKey('attendance-import-employee'), findsOneWidget);
      expect(find.text('From date (optional)'), findsOneWidget);
      expect(find.text('To date (optional)'), findsOneWidget);
      expect(find.textContaining('Every row must belong to the selected employee'), findsOneWidget);
    });

    testWidgets('3. the employee picker searches /employees/ as web (search, page_size=8)', (tester) async {
      await pumpScreen(tester);
      await openImport(tester);
      await tapKey(tester, 'attendance-import-mode-single');
      await pickEmployee(tester);
      expect(server.of('GET', ApiConstants.employees).last.query, {'search': 'tes', 'page_size': 8});
      expect(find.descendant(of: byKey('attendance-import-employee'), matching: find.text('Test Person One')),
          findsOneWidget);
      expect(find.descendant(of: byKey('attendance-import-employee'), matching: find.text('TST001 · Engineering')),
          findsOneWidget);
    });

    testWidgets('4. required file and employee, and From ≤ To, are checked before any request', (tester) async {
      await pumpScreen(tester);
      await openImport(tester);
      await upload(tester);
      expect(errorText(tester), 'Please choose a CSV file.');
      await tapKey(tester, 'attendance-import-mode-single');
      await pickFile(tester);
      await upload(tester);
      expect(errorText(tester), 'Please select an employee.');
      await pickEmployee(tester);
      await pickDate(tester, 'from', DateTime(2026, 7, 31));
      await pickDate(tester, 'to', DateTime(2026, 7, 1));
      await upload(tester);
      expect(errorText(tester), 'The From date must be on or before the To date.');
      expect(server.calls.where((c) => c.method == 'POST'), isEmpty);
    });
  });

  group('payloads', () {
    testWidgets('5. single mode sends file + employee_id + date_from + date_to, exactly', (tester) async {
      await pumpScreen(tester);
      await openImport(tester);
      await tapKey(tester, 'attendance-import-mode-single');
      await pickEmployee(tester);
      await pickDate(tester, 'from', DateTime(2026, 7, 1));
      await pickDate(tester, 'to', DateTime(2026, 7, 31));
      await pickFile(tester);
      await upload(tester);
      final f = server.imports.single;
      expect(fields(f), ['employee_id=TST001', 'date_from=2026-07-01', 'date_to=2026-07-31']);
      expect(f.files.single.key, 'file');
      expect(f.files.single.value.filename, 'attendance.csv');
    });

    testWidgets('6. single mode without dates sends only employee_id; a cleared date is not sent', (tester) async {
      await pumpScreen(tester);
      await openImport(tester);
      await tapKey(tester, 'attendance-import-mode-single');
      await pickEmployee(tester);
      await pickDate(tester, 'from', DateTime(2026, 7, 1));
      await tapKey(tester, 'attendance-import-date-from-clear');
      await pickFile(tester);
      await upload(tester);
      expect(fields(server.imports.single), ['employee_id=TST001']);
    });

    testWidgets('7. bulk mode sends only the file, as before', (tester) async {
      await pumpScreen(tester);
      await openImport(tester);
      await pickFile(tester);
      await upload(tester);
      final f = server.imports.single;
      expect(f.fields, isEmpty);
      expect(f.files.map((e) => e.key), ['file']);
      expect(f.files.single.value.filename, 'attendance.csv');
    });

    testWidgets('8. switching back to Bulk drops the employee and dates; returning to single starts empty',
        (tester) async {
      await pumpScreen(tester);
      await openImport(tester);
      await tapKey(tester, 'attendance-import-mode-single');
      await pickEmployee(tester);
      await pickDate(tester, 'from', DateTime(2026, 7, 1));
      await tapKey(tester, 'attendance-import-mode-bulk');
      await tapKey(tester, 'attendance-import-mode-single');
      expect(find.text('Test Person One'), findsNothing);
      expect(find.text('2026-07-01'), findsNothing);
      await tapKey(tester, 'attendance-import-mode-bulk');
      await pickFile(tester);
      await upload(tester);
      expect(server.imports.single.fields, isEmpty);
    });
  });

  group('permissions and safety', () {
    testWidgets('9. without attendance.create there is no Import (Export stays)', (tester) async {
      await pumpScreen(tester, as: viewer);
      expect(byKey('attendance-import-button'), findsNothing);
      expect(byKey('attendance-export-button'), findsOneWidget);
    });

    test(
        '10. the action refuses either mode without attendance.create, and an invalid single import, before any '
        'request', () async {
      server = FakeServer();
      final bytes = utf8.encode('employee_id,date\n');
      final denied = await signedIn(hrUser(['attendance.view']));
      await expectLater(
          denied.read(attendanceImportActionProvider).upload(bytes, 'a.csv'), throwsA(kAttendanceImportDenied));
      await expectLater(
          denied
              .read(attendanceImportActionProvider)
              .upload(bytes, 'a.csv', single: const AttendanceSingleImport(employeeId: 'TST001')),
          throwsA(kAttendanceImportDenied));
      final allowed = await signedIn(importer);
      await expectLater(
          allowed
              .read(attendanceImportActionProvider)
              .upload(bytes, 'a.csv', single: const AttendanceSingleImport(employeeId: '  ')),
          throwsA('Please select an employee.'));
      await expectLater(
          allowed.read(attendanceImportActionProvider).upload(bytes, 'a.csv',
              single: AttendanceSingleImport(
                  employeeId: 'TST001', dateFrom: DateTime(2026, 7, 2), dateTo: DateTime(2026, 7, 1))),
          throwsA('The From date must be on or before the To date.'));
      expect(server.calls, isEmpty);
    });

    test('11a. one upload at a time: a second call while one runs is refused before any request', () async {
      server = FakeServer()..holdImport = Completer();
      final c = await signedIn(importer);
      final action = c.read(attendanceImportActionProvider);
      final bytes = utf8.encode('employee_id,date\n');
      final first = action.upload(bytes, 'a.csv');
      await Future<void>.delayed(Duration.zero);
      await expectLater(
          c
              .read(attendanceImportActionProvider)
              .upload(bytes, 'b.csv', single: const AttendanceSingleImport(employeeId: 'TST001')),
          throwsA(kAttendanceImportBusy));
      server.holdImport!.complete();
      expect((await first).success, 2);
      expect(server.imports, hasLength(1));
    });

    testWidgets('11b. double-tapping Preview sends one request; mode and inputs are locked meanwhile',
        (tester) async {
      final s = FakeServer()..holdPreview = Completer();
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await tapKey(tester, 'attendance-import-mode-single');
      await pickEmployee(tester);
      await pickFile(tester);
      await tester.tap(byKey('attendance-import-preview'));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(byKey('attendance-import-preview')).onPressed, isNull);
      expect(tester.widget<InkWell>(byKey('attendance-import-mode-bulk')).onTap, isNull);
      expect(tester.widget<InkWell>(byKey('attendance-import-mode-single')).onTap, isNull);
      await tester.tap(byKey('attendance-import-preview'), warnIfMissed: false);
      await tester.tap(byKey('attendance-import-mode-bulk'), warnIfMissed: false);
      await tester.pump();
      s.holdPreview!.complete();
      await tester.pumpAndSettle();
      expect(s.previews, hasLength(1));
      expect(fields(s.previews.single), ['employee_id=TST001', 'dry_run=true']);
      expect(s.imports, isEmpty);
    });
  });

  group('server responses', () {
    testWidgets('12a. a 404 for an employee outside the importer\'s scope is shown; nothing is imported',
        (tester) async {
      final s = FakeServer()
        ..nextPreviews.add((status: 404, body: {'status': 'error', 'message': 'Employee not found.', 'data': {}}));
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await tapKey(tester, 'attendance-import-mode-single');
      await pickEmployee(tester);
      await pickFile(tester);
      await upload(tester);
      expect(errorText(tester), 'Employee not found.');
      expect(byKey('attendance-import-message'), findsNothing);
      expect(byKey('attendance-import-preview-view'), findsNothing);
      expect(s.imports, isEmpty);
    });

    testWidgets('12b. a server permission refusal is shown', (tester) async {
      final s = FakeServer()
        ..nextPreviews.add((status: 403, body: {'status': 'error', 'message': 'Permission denied.', 'data': {}}));
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await pickFile(tester);
      await upload(tester);
      expect(errorText(tester), 'Permission denied.');
      expect(s.imports, isEmpty);
    });

    testWidgets('12c. a file whose every row failed (HTTP 400 with the result) shows the result and its rows',
        (tester) async {
      final s = FakeServer()
        ..nextImport = (
          status: 400,
          body: {
            'status': 'success',
            'message': 'No records imported. 1 failed.',
            'data': resultBody(
                status: 'failed', total: 1, successful: 0, failed: 1, message: 'No records imported. 1 failed.'),
          }
        );
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await pickFile(tester);
      await upload(tester);
      expect(tester.widget<Text>(byKey('attendance-import-message')).data, 'No records imported. 1 failed.');
      expect(find.textContaining("not the selected employee 'TST001'"), findsOneWidget);
    });

    testWidgets('13. a successful import shows the message, totals and row errors, and reloads the list',
        (tester) async {
      final s = FakeServer();
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await tapKey(tester, 'attendance-import-mode-single');
      await pickEmployee(tester);
      await pickFile(tester);
      final before = s.otherGets;
      await upload(tester);
      expect(tester.widget<Text>(byKey('attendance-import-message')).data, '2 of 3 records imported. 1 failed.');
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.textContaining('Row 3 (TST002 · 2026-07-03)'), findsOneWidget);
      expect(find.text('Remove this row or import it for the right employee.'), findsOneWidget);
      expect(s.otherGets, greaterThan(before));
      await tapKey(tester, 'attendance-import-done');
      expect(find.text('Import Attendance'), findsNothing);
    });

    testWidgets('14. a large file queued in the background (202) says so', (tester) async {
      final s = FakeServer()
        ..nextImport = (
          status: 202,
          body: {
            'status': 'success',
            'message': 'queued',
            'data': resultBody(
                status: 'queued',
                total: 900,
                successful: 0,
                failed: 0,
                errors: [],
                message: 'Your file has 900 records and is being processed in the background. '
                    'Poll GET /api/attendance/import/{import_id}/status/ for progress.'),
          }
        );
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await pickFile(tester);
      await upload(tester);
      expect(
          tester.widget<Text>(byKey('attendance-import-queued')).data,
          'Your file has 900 records and is being processed in the background. '
          'You can close this window; refresh the attendance list in a few minutes.');
    });
  });
  group('dry-run preview', () {
    Future<String> content(WidgetTester tester, FormData f) async =>
        (await tester.runAsync(() async => utf8.decode(
            (await f.files.single.value.clone().finalize().toList()).expand((b) => b).toList())))!;

    test('D1. the preview body is parsed with production keys', () {
      final p = parseImportPreview(previewBody(
          truncated: true, reportCsv: 'YQ==', employee: {'employee_id': 'TST001', 'full_name': 'Test Person One'}));
      expect([p.totalRecords, p.toCreate, p.toUpdate, p.skipped, p.failed, p.importable], [3, 1, 1, 0, 1, 2]);
      expect(p.message, 'Preview: 2 of 3 rows will be imported. 1 have errors.');
      expect(p.rowsTruncated, isTrue);
      expect(p.errorReportCsv, 'YQ==');
      expect([p.employeeCode, p.employeeName], ['TST001', 'Test Person One']);
      expect(p.rows.map((r) => [r.row, r.employeeId, r.date, r.punchIn, r.punchOut, r.action]), [
        [1, 'TST001', '2026-07-01', '09:00', '18:00', 'create'],
        [2, 'TST001', '2026-07-02', '09:05', '18:15', 'update'],
      ]);
      final e = p.errors.single;
      expect([e.row, e.employee, e.date, e.resolution], [3, 'TST002', '2026-07-03', 'Remove this row or import it for the right employee.']);
      final bare = parseImportPreview({});
      expect([bare.totalRecords, bare.importable, bare.rows.length, bare.errors.length], [0, 0, 0, 0]);
      expect(bare.employeeName, isNull);
    });

    testWidgets('D2. bulk: the first request is a dry run of exactly the file; the preview is shown; nothing '
        'is imported or reloaded', (tester) async {
      final s = FakeServer();
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await pickFile(tester);
      final before = s.otherGets;
      await preview(tester);
      expect(s.sequence, ['preview']);
      final f = s.previews.single;
      expect(fields(f), ['dry_run=true']);
      expect(f.files.single.key, 'file');
      expect(f.files.single.value.filename, 'attendance.csv');
      expect(await content(tester, f), 'employee_id,date,punch_in,punch_out\nTST001,2026-07-02,09:05,18:15\n');
      // preview, not a result
      expect(byKey('attendance-import-preview-view'), findsOneWidget);
      expect(byKey('attendance-import-message'), findsNothing);
      expect(byKey('attendance-import-done'), findsNothing);
      expect(tester.widget<Text>(byKey('attendance-import-preview-message')).data,
          'All employees — Preview: 2 of 3 rows will be imported. 1 have errors.');
      for (final t in ['Rows in file', 'New records', 'Replace existing', 'Skipped', 'Errors']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(tester.widget<Text>(byKey('attendance-import-replace-warning')).data,
          '1 row(s) will replace the punch times of an existing attendance record for that day.');
      expect(tester.widget<Text>(byKey('attendance-import-errors-title')).data, '1 row with errors (not imported)');
      expect(find.textContaining("Row 3 (TST002 · 2026-07-03): This row is for employee 'TST002'"), findsOneWidget);
      expect(find.text('Remove this row or import it for the right employee.'), findsOneWidget);
      expect(find.text('New record'), findsOneWidget);
      expect(find.text('Replaces existing'), findsOneWidget);
      expect(find.text('Rows to import'), findsOneWidget);
      expect(confirmLabel(tester), 'Import 2 records');
      expect(confirmEnabled(tester), isTrue);
      expect(s.imports, isEmpty);
      expect(s.otherGets, before, reason: 'a dry run is not an import — no reload');
    });

    testWidgets('D3. single: both requests carry the same employee and dates, file and name; only the dry run '
        'has dry_run; the list reloads after the real import', (tester) async {
      final s = FakeServer()
        ..nextPreviews.add((
          status: 200,
          body: {
            'status': 'success',
            'message': 'preview',
            'data': previewBody(employee: {'employee_id': 'TST001', 'full_name': 'Test Person One'}),
          }
        ));
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await tapKey(tester, 'attendance-import-mode-single');
      await pickEmployee(tester);
      await pickDate(tester, 'from', DateTime(2026, 7, 1));
      await pickDate(tester, 'to', DateTime(2026, 7, 31));
      await pickFile(tester);
      final before = s.otherGets;
      await preview(tester);
      expect(fields(s.previews.single), ['employee_id=TST001', 'date_from=2026-07-01', 'date_to=2026-07-31', 'dry_run=true']);
      expect(tester.widget<Text>(byKey('attendance-import-preview-message')).data,
          startsWith('Test Person One (TST001) — '));
      expect(s.otherGets, before);
      await tapKey(tester, 'attendance-import-confirm');
      expect(s.sequence, ['preview', 'import']);
      final real = s.imports.single;
      expect(fields(real), ['employee_id=TST001', 'date_from=2026-07-01', 'date_to=2026-07-31']);
      expect(fieldMap(real), {...fieldMap(s.previews.single)}..remove('dry_run'));
      expect(real.files.single.key, 'file');
      expect(real.files.single.value.filename, 'attendance.csv');
      expect(await content(tester, real), await content(tester, s.previews.single));
      expect(tester.widget<Text>(byKey('attendance-import-message')).data, '2 of 3 records imported. 1 failed.');
      expect(s.otherGets, greaterThan(before));
    });

    testWidgets('D4. Back returns to the form and Cancel closes — neither sends a real import or reloads',
        (tester) async {
      final s = FakeServer();
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await pickFile(tester);
      final before = s.otherGets;
      await preview(tester);
      await tapKey(tester, 'attendance-import-back');
      expect(byKey('attendance-import-preview-view'), findsNothing);
      expect(byKey('attendance-import-preview'), findsOneWidget);
      expect(find.text('attendance.csv'), findsOneWidget, reason: 'the chosen file is kept');
      await tapKey(tester, 'attendance-import-preview');
      await tapKey(tester, 'attendance-import-back');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Import Attendance'), findsNothing);
      expect(s.sequence, ['preview', 'preview']);
      expect(s.imports, isEmpty);
      expect(s.otherGets, before);
    });

    testWidgets('D5. nothing importable: Import is disabled and sends nothing', (tester) async {
      final s = FakeServer()
        ..nextPreviews.add((
          status: 200,
          body: {
            'status': 'success',
            'message': 'preview',
            'data': previewBody(total: 1, toCreate: 0, toUpdate: 0, failed: 1, rows: []),
          }
        ));
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await pickFile(tester);
      await preview(tester);
      expect(confirmLabel(tester), 'Import 0 records');
      expect(confirmEnabled(tester), isFalse);
      expect(byKey('attendance-import-replace-warning'), findsNothing);
      await tester.tap(byKey('attendance-import-confirm'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(s.imports, isEmpty);
    });

    testWidgets('D6. double-tapping Import sends one real import; Back is locked while it runs', (tester) async {
      final s = FakeServer()..holdImport = Completer();
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await pickFile(tester);
      await preview(tester);
      await tester.tap(byKey('attendance-import-confirm'));
      await tester.pump();
      expect(confirmEnabled(tester), isFalse);
      expect(tester.widget<TextButton>(byKey('attendance-import-back')).onPressed, isNull);
      await tester.tap(byKey('attendance-import-confirm'), warnIfMissed: false);
      await tester.tap(byKey('attendance-import-back'), warnIfMissed: false);
      await tester.pump();
      s.holdImport!.complete();
      await tester.pumpAndSettle();
      expect(s.sequence, ['preview', 'import']);
      expect(byKey('attendance-import-message'), findsOneWidget);
    });

    testWidgets('D7. a failed import keeps the preview and shows the error, with no reload; retry re-sends the '
        'same request and then reloads', (tester) async {
      final s = FakeServer()
        ..nextImport = (status: 500, body: {'status': 'error', 'message': 'Server busy, try again.', 'data': {}});
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await tapKey(tester, 'attendance-import-mode-single');
      await pickEmployee(tester);
      await pickFile(tester);
      final before = s.otherGets;
      await upload(tester);
      expect(errorText(tester), 'Server busy, try again.');
      expect(byKey('attendance-import-preview-view'), findsOneWidget);
      expect(confirmEnabled(tester), isTrue);
      expect(s.otherGets, before);
      s.nextImport = null;
      await tapKey(tester, 'attendance-import-confirm');
      expect(s.sequence, ['preview', 'import', 'import']);
      expect(fields(s.imports[0]), ['employee_id=TST001']);
      expect(fields(s.imports[1]), ['employee_id=TST001']);
      expect(await content(tester, s.imports[1]), await content(tester, s.imports[0]));
      expect(byKey('attendance-import-message'), findsOneWidget);
      expect(s.otherGets, greaterThan(before));
    });

    testWidgets('D8. a failed dry run stays on the form; previewing again works', (tester) async {
      final s = FakeServer()
        ..nextPreviews.addAll([
          (status: 400, body: {'status': 'error', 'message': 'Only CSV files are supported.', 'data': {}}),
          (status: 200, body: {'status': 'success', 'message': 'preview', 'data': previewBody()}),
        ]);
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await pickFile(tester);
      await preview(tester);
      expect(errorText(tester), 'Only CSV files are supported.');
      expect(byKey('attendance-import-preview-view'), findsNothing);
      await preview(tester);
      expect(byKey('attendance-import-preview-view'), findsOneWidget);
      expect(errorText(tester), isNull);
      expect(s.imports, isEmpty);
    });

    testWidgets('D9. after Back and a new file, Import sends the new file — never the earlier preview\'s',
        (tester) async {
      final s = FakeServer();
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await pickFile(tester, csv('first.csv', 'employee_id,date\nTST001,2026-07-01\n'));
      await preview(tester);
      await tapKey(tester, 'attendance-import-back');
      await pickFile(tester, csv('second.csv', 'employee_id,date\nTST001,2026-07-09\n'));
      await preview(tester);
      await tapKey(tester, 'attendance-import-confirm');
      expect(s.sequence, ['preview', 'preview', 'import']);
      expect(s.imports.single.files.single.value.filename, 'second.csv');
      expect(await content(tester, s.imports.single), 'employee_id,date\nTST001,2026-07-09\n');
    });

    testWidgets('D10. truncated rows are labelled, and the error report downloads as web names it', (tester) async {
      final s = FakeServer()
        ..nextPreviews.add((
          status: 200,
          body: {
            'status': 'success',
            'message': 'preview',
            'data': previewBody(truncated: true, reportCsv: base64Encode(utf8.encode('row,reason\n3,bad\n'))),
          }
        ));
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await pickFile(tester);
      await preview(tester);
      expect(find.text('Rows to import (first 2 shown)'), findsOneWidget);
      await tapKey(tester, 'attendance-import-report');
      expect(savedReports.single.name, 'attendance_import_errors.csv');
      expect(utf8.decode(savedReports.single.bytes), 'row,reason\n3,bad\n');
      expect(s.imports, isEmpty);
    });

    test('D11. the preview action refuses without attendance.create or with an invalid single import, and '
        'shares the one-at-a-time guard with the import', () async {
      server = FakeServer()..holdPreview = Completer();
      final bytes = utf8.encode('employee_id,date\n');
      final denied = await signedIn(hrUser(['attendance.view']));
      await expectLater(denied.read(attendanceImportActionProvider).preview(bytes, 'a.csv'),
          throwsA(kAttendanceImportDenied));
      final allowed = await signedIn(importer);
      await expectLater(
          allowed
              .read(attendanceImportActionProvider)
              .preview(bytes, 'a.csv', single: const AttendanceSingleImport(employeeId: '')),
          throwsA('Please select an employee.'));
      expect(server.calls, isEmpty);
      final first = allowed.read(attendanceImportActionProvider).preview(bytes, 'a.csv');
      await Future<void>.delayed(Duration.zero);
      await expectLater(allowed.read(attendanceImportActionProvider).upload(bytes, 'a.csv'),
          throwsA(kAttendanceImportBusy));
      server.holdPreview!.complete();
      expect((await first).importable, 2);
      expect(server.sequence, ['preview']);
    });
  });
}
