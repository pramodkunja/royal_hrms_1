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

class FakeServer implements HttpClientAdapter {
  ({int status, Map<String, dynamic> body})? nextImport;
  Completer<void>? holdImport;
  final calls = <({String method, String path, Map<String, dynamic> query, Object? body})>[];

  List<({String method, String path, Map<String, dynamic> query, Object? body})> of(String method, String path) =>
      calls.where((c) => c.method == method && c.path == path).toList();
  List<FormData> get imports => of('POST', importPath).map((c) => c.body as FormData).toList();
  int get otherGets => calls.where((c) => c.method == 'GET' && c.path != ApiConstants.employees).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: Map.of(o.queryParameters), body: o.data));
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

PlatformFile csv([String name = 'attendance.csv']) {
  final bytes = Uint8List.fromList(utf8.encode('employee_id,date,punch_in,punch_out\nTST001,2026-07-02,09:05,18:15\n'));
  return PlatformFile(name: name, size: bytes.length, bytes: bytes);
}

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      attendanceImportFilePickerProvider.overrideWithValue(() async => nextFile),
      attendanceImportDatePickerProvider.overrideWithValue((context, initial) async => nextDate),
    ];

Future<void> pumpScreen(WidgetTester tester, {UserEntity? as, FakeServer? with_}) async {
  tester.view.physicalSize = const Size(1600, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? FakeServer();
  nextFile = null;
  nextDate = null;
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

Future<void> upload(WidgetTester tester) => tapKey(tester, 'attendance-import-upload');

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
      expect(server.imports, isEmpty);
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

    testWidgets('11b. double-tapping Upload sends one request; mode and inputs are locked meanwhile', (tester) async {
      final s = FakeServer()..holdImport = Completer();
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await tapKey(tester, 'attendance-import-mode-single');
      await pickEmployee(tester);
      await pickFile(tester);
      await tester.tap(byKey('attendance-import-upload'));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(byKey('attendance-import-upload')).onPressed, isNull);
      expect(tester.widget<InkWell>(byKey('attendance-import-mode-bulk')).onTap, isNull);
      expect(tester.widget<InkWell>(byKey('attendance-import-mode-single')).onTap, isNull);
      await tester.tap(byKey('attendance-import-upload'), warnIfMissed: false);
      await tester.tap(byKey('attendance-import-mode-bulk'), warnIfMissed: false);
      await tester.pump();
      s.holdImport!.complete();
      await tester.pumpAndSettle();
      expect(s.imports, hasLength(1));
      expect(fields(s.imports.single), ['employee_id=TST001']);
    });
  });

  group('server responses', () {
    testWidgets('12a. a 404 for an employee outside the importer\'s scope is shown; nothing is imported',
        (tester) async {
      final s = FakeServer()
        ..nextImport = (status: 404, body: {'status': 'error', 'message': 'Employee not found.', 'data': {}});
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await tapKey(tester, 'attendance-import-mode-single');
      await pickEmployee(tester);
      await pickFile(tester);
      await upload(tester);
      expect(errorText(tester), 'Employee not found.');
      expect(byKey('attendance-import-message'), findsNothing);
    });

    testWidgets('12b. a server permission refusal is shown', (tester) async {
      final s = FakeServer()
        ..nextImport = (status: 403, body: {'status': 'error', 'message': 'Permission denied.', 'data': {}});
      await pumpScreen(tester, with_: s);
      await openImport(tester);
      await pickFile(tester);
      await upload(tester);
      expect(errorText(tester), 'Permission denied.');
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
}
