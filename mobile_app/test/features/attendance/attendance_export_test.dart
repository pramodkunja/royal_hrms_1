import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_export.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// Task 4: HR attendance CSV export — single day, month and custom date range
// (web lib/attendanceExport.ts + AttendanceTab.tsx; backend
// AttendanceExportFilterSerializer / HRAttendanceExportView). A stand-in for
// GET /attendance/export/ and the screen's other endpoints; the save dialog
// is replaced by a recorder. "Today" is fixed at 15 March 2026. Synthetic
// data only; nothing is sent anywhere.

final today = DateTime(2026, 3, 15, 10, 30);

/// The server's columns (services_hr_ops._EXPORT_COLUMNS), in order.
const webColumns = [
  'employee_id', 'name', 'department', 'branch', //
  'date', 'clock_in', 'clock_out', 'total_hours',
  'overtime', 'status',
  'clock_in_location', 'clock_out_location',
  'clock_in_gps_accuracy_m', 'clock_out_gps_accuracy_m',
];

/// What the server sends: UTF-8 BOM, header, CRLF rows (Python csv).
String csvText({bool rows = true}) => '﻿${webColumns.join(',')}\r\n'
    '${rows ? 'EMP-901,Test Person,QA,North Wing,01-03-2026,09:02 AM,06:10 PM,9h 8m,0h 0m,Present,'
        '"Gate 2, Test Park",Gate 2,12,15\r\n' : ''}';

ResponseBody _json(Object body, int status) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class FakeExportServer implements HttpClientAdapter {
  final exports = <Map<String, dynamic>>[];
  List<int> csv = utf8.encode(csvText());

  /// Next export answers with this status and {status: error, message}.
  ({int status, String message})? refuseNext;
  bool dropNext = false;
  Completer<void>? hold;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == ApiConstants.attendanceExport) {
      exports.add(Map.of(o.queryParameters));
      if (hold != null) await hold!.future;
      if (dropNext) {
        dropNext = false;
        throw DioException.connectionError(requestOptions: o, reason: 'offline');
      }
      final r = refuseNext;
      if (r != null) {
        refuseNext = null;
        return _json({'status': 'error', 'message': r.message, 'data': null}, r.status);
      }
      return ResponseBody.fromBytes(csv, 200, headers: {
        Headers.contentTypeHeader: ['text/csv; charset=utf-8'],
        'content-disposition': ['attachment; filename="attendance.csv"'],
      });
    }
    // Everything else on the screen: empty lists / zero counts.
    return _json({
      'status': 'success',
      'message': 'ok',
      'data': {'results': [], 'count': 0, 'summary_chips': <String, int>{}},
    }, 200);
  }

  @override
  void close({bool force = false}) {}
}

class SavedFile {
  SavedFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
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

UserEntity hrUser(List<String> perms, {String? branch, bool superuser = false}) => UserEntity(
      id: 'hr1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      branch: branch,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final hrExporter = hrUser(['attendance.view', 'attendance.export']);
final hrViewer = hrUser(['attendance.view']);

late FakeExportServer server;
late List<SavedFile> saved;

/// When true the save dialog is "cancelled"; when set, saving throws.
bool cancelSave = false;
bool failSave = false;

List<Override> overrides(UserEntity user) => [
      authStateProvider.overrideWith(() => _Auth(user)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      attendanceExportClockProvider.overrideWithValue(() => today),
      attendanceCsvSaverProvider.overrideWithValue((name, bytes) async {
        if (failSave) throw Exception('/private/path/should-not-show');
        if (cancelSave) return null;
        saved.add(SavedFile(name, bytes));
        return '/storage/$name';
      }),
    ];

void reset() {
  server = FakeExportServer();
  saved = [];
  cancelSave = false;
  failSave = false;
}

Future<ProviderContainer> signedIn(UserEntity user) async {
  final c = ProviderContainer(overrides: overrides(user));
  addTearDown(c.dispose);
  await c.read(authStateProvider.future);
  return c;
}

late ProviderContainer screen;

Future<void> pumpScreen(WidgetTester tester, {UserEntity? as}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? hrExporter),
    child: const MaterialApp(home: Scaffold(body: AttendanceScreen())),
  ));
  await tester.pumpAndSettle();
  screen = ProviderScope.containerOf(tester.element(find.byType(AttendanceScreen)));
  await screen.read(authStateProvider.future);
  await tester.pumpAndSettle();
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('attendance-export-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('attendance-export-sheet')), findsOneWidget);
}

Future<void> submit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('export-submit')));
  await tester.pumpAndSettle();
}

String? textOf(WidgetTester tester, String key) {
  final f = find.byKey(Key(key));
  return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
}

FilledButton submitButton(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const Key('export-submit')));

Finder inSheet(Finder f) => find.descendant(of: find.byKey(const Key('attendance-export-sheet')), matching: f);

/// Advances the clock without settling (the spinner never settles).
Future<void> pumpFor(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

SnackBar snack(WidgetTester tester) => tester.widget<SnackBar>(find.byType(SnackBar));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(reset);

  group('rules (web lib/attendanceExport.ts)', () {
    test('1. single day: date param, as before; no date means the server’s today', () {
      const d = AttendanceExportRequest.day(branch: 'North Wing', department: 'QA');
      expect(d.params(), {'branch': 'North Wing', 'department': 'QA'});
      expect(d.fileName(today), 'attendance_2026-03-15.csv');
      final e = AttendanceExportRequest.day(date: DateTime(2026, 3, 2));
      expect(e.params(), {'date': '2026-03-02'});
      expect(e.fileName(today), 'attendance_2026-03-02.csv');
      expect(e.problem(today), isNull);
    });

    test('2–3. month: month=YYYY-MM only; December and January', () {
      const dec = AttendanceExportRequest.month(year: 2025, month: 12, department: 'QA');
      expect(dec.params(), {'month': '2025-12', 'department': 'QA'});
      expect(dec.fileName(today), 'attendance_2025-12.csv');
      const jan = AttendanceExportRequest.month(year: 2026, month: 1);
      expect(jan.params(), {'month': '2026-01'});
      expect(jan.problem(today), isNull);
      expect(dec.problem(today), isNull);
      // This month is allowed (the server stops at today); the next is not.
      expect(const AttendanceExportRequest.month(year: 2026, month: 3).problem(today), isNull);
      expect(const AttendanceExportRequest.month(year: 2026, month: 4).problem(today), 'Cannot export a future month.');
      expect(const AttendanceExportRequest.month(year: 2027, month: 1).problem(today), 'Cannot export a future month.');
      expect(const AttendanceExportRequest.month(year: 1999, month: 12).problem(today),
          'month must be in YYYY-MM format.');
    });

    test('4. leap-year February: 29 days in 2024, a 28/29 Feb range end, 1–29 Feb is 29 days', () {
      const feb = AttendanceExportRequest.month(year: 2024, month: 2);
      expect(feb.params(), {'month': '2024-02'});
      expect(exportRangeProblem(DateTime(2024, 2, 1), DateTime(2024, 2, 29), today), isNull);
      final r = AttendanceExportRequest.range(from: DateTime(2024, 2, 28), to: DateTime(2024, 3, 1));
      expect(r.params(), {'from_date': '2024-02-28', 'to_date': '2024-03-01'});
      // 31 Jan – 2 Mar 2024 is 32 days only because 2024 has 29 Feb.
      expect(exportRangeProblem(DateTime(2024, 1, 31), DateTime(2024, 3, 1), today), isNull);
      expect(exportRangeProblem(DateTime(2024, 1, 31), DateTime(2024, 3, 2), today), 'Range cannot exceed 31 days.');
      expect(exportRangeProblem(DateTime(2023, 1, 31), DateTime(2023, 3, 2), today), isNull); // 31 days
    });

    test('5. custom range: from_date and to_date, YYYY-MM-DD, with the filters', () {
      final r = AttendanceExportRequest.range(
          from: DateTime(2025, 12, 20), to: DateTime(2026, 1, 5), branch: 'North Wing', department: 'QA');
      expect(
          r.params(), {'from_date': '2025-12-20', 'to_date': '2026-01-05', 'branch': 'North Wing', 'department': 'QA'});
      expect(r.fileName(today), 'attendance_2025-12-20_to_2026-01-05.csv');
      expect(r.problem(today), isNull);
    });

    test('6. missing, reversed and future ranges are refused with web’s messages', () {
      expect(exportRangeProblem(null, DateTime(2026, 3, 1), today), 'Select both From and To dates.');
      expect(exportRangeProblem(DateTime(2026, 3, 1), null, today), 'Select both From and To dates.');
      expect(exportRangeProblem(DateTime(2026, 3, 10), DateTime(2026, 3, 9), today),
          'From date must be on or before To date.');
      expect(
          exportRangeProblem(DateTime(2026, 3, 10), DateTime(2026, 3, 16), today), 'To date cannot be in the future.');
      expect(exportRangeProblem(DateTime(2026, 3, 15), DateTime(2026, 3, 15), today), isNull); // today itself
    });

    test('7. both ends inclusive: one day is 1, 31 days allowed, 32 refused', () {
      expect(exportRangeProblem(DateTime(2026, 3, 9), DateTime(2026, 3, 9), today), isNull);
      expect(exportRangeProblem(DateTime(2026, 1, 1), DateTime(2026, 1, 31), today), isNull);
      expect(exportRangeProblem(DateTime(2026, 1, 1), DateTime(2026, 2, 1), today), 'Range cannot exceed 31 days.');
      // Across a daylight-saving change still counts calendar days.
      expect(exportRangeProblem(DateTime(2025, 10, 1), DateTime(2025, 10, 31), today), isNull);
    });

    test('12. file names: mode and period, plus a restricted user’s branch (web branchSlug)', () {
      expect(exportBranchSlug(hrUser(['attendance.export'], branch: ' North  Wing ')), 'North-Wing_');
      expect(exportBranchSlug(hrUser(['attendance.export', 'settings.edit'], branch: 'North Wing')), '');
      expect(exportBranchSlug(hrUser(['attendance.export'], branch: 'North Wing', superuser: true)), '');
      expect(exportBranchSlug(hrUser(['attendance.export'])), '');
      const m = AttendanceExportRequest.month(year: 2026, month: 2);
      expect(m.fileName(today, branchSlug: 'North-Wing_'), 'attendance_North-Wing_2026-02.csv');
    });

    test('csvHasDataRows: header only is empty; BOM, CRLF and quoted commas handled', () {
      expect(csvHasDataRows(utf8.encode(csvText(rows: false))), isFalse);
      expect(csvHasDataRows(utf8.encode(csvText())), isTrue);
      expect(csvHasDataRows(utf8.encode('﻿${webColumns.join(',')}')), isFalse);
    });
  });

  group('exporter (below the UI)', () {
    test('2. month request carries only month + filters; 5. range only from/to + filters', () async {
      final c = await signedIn(hrExporter);
      final x = c.read(attendanceExporterProvider);
      expect(await x.export(const AttendanceExportRequest.month(year: 2025, month: 12, branch: 'North Wing')),
          isA<AttendanceExportSaved>());
      expect(await x.export(AttendanceExportRequest.range(from: DateTime(2026, 2, 20), to: DateTime(2026, 3, 1))),
          isA<AttendanceExportSaved>());
      expect(await x.export(AttendanceExportRequest.day(date: DateTime(2026, 3, 2), department: 'QA')),
          isA<AttendanceExportSaved>());
      expect(server.exports, [
        {'month': '2025-12', 'branch': 'North Wing'},
        {'from_date': '2026-02-20', 'to_date': '2026-03-01'},
        {'date': '2026-03-02', 'department': 'QA'},
      ]);
      expect(saved.map((s) => s.name),
          ['attendance_2025-12.csv', 'attendance_2026-02-20_to_2026-03-01.csv', 'attendance_2026-03-02.csv']);
    });

    test('8–9. the CSV is saved byte for byte: BOM, web’s 14 columns in order, location columns', () async {
      final c = await signedIn(hrExporter);
      final out =
          await c.read(attendanceExporterProvider).export(const AttendanceExportRequest.month(year: 2026, month: 3));
      expect(out, isA<AttendanceExportSaved>().having((o) => o.empty, 'empty', false));
      expect(saved.single.bytes, server.csv);
      final text = utf8.decode(saved.single.bytes);
      expect(saved.single.bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]); // UTF-8 BOM kept for Excel
      final header = text.substring(text.startsWith('\uFEFF') ? 1 : 0, text.indexOf('\r\n')).split(',');
      expect(header, webColumns);
      expect(header.sublist(10), [
        'clock_in_location', 'clock_out_location', 'clock_in_gps_accuracy_m', 'clock_out_gps_accuracy_m', //
      ]);
      expect(text, contains('"Gate 2, Test Park"'));
    });

    test('10. header-only CSV is saved and reported empty; a zero-byte body is an error, not a file', () async {
      final c = await signedIn(hrExporter);
      final x = c.read(attendanceExporterProvider);
      server.csv = utf8.encode(csvText(rows: false));
      expect(await x.export(const AttendanceExportRequest.day()),
          isA<AttendanceExportSaved>().having((o) => o.empty, 'empty', true));
      server.csv = const [];
      expect(await x.export(const AttendanceExportRequest.day()),
          isA<AttendanceExportFailed>().having((o) => o.message, 'message', contains('empty file')));
      expect(saved, hasLength(1));
    });

    test('11. server refusal shows its message (from a bytes body); 5xx and offline are friendly', () async {
      final c = await signedIn(hrExporter);
      final x = c.read(attendanceExporterProvider);
      server.refuseNext = (status: 400, message: 'Date range cannot exceed 31 days.');
      expect(await x.export(const AttendanceExportRequest.day()),
          isA<AttendanceExportFailed>().having((o) => o.message, 'message', 'Date range cannot exceed 31 days.'));
      server.refuseNext = (status: 500, message: '');
      expect(await x.export(const AttendanceExportRequest.day()),
          isA<AttendanceExportFailed>().having((o) => o.message, 'message', 'Server error. Please try again later.'));
      server.dropNext = true;
      expect(
          await x.export(const AttendanceExportRequest.day()),
          isA<AttendanceExportFailed>()
              .having((o) => o.message, 'message', 'Cannot reach server. Check your connection.'));
      expect(saved, isEmpty);
    });

    test('13. save dialog cancelled saves nothing; a save failure never shows the path', () async {
      final c = await signedIn(hrExporter);
      final x = c.read(attendanceExporterProvider);
      cancelSave = true;
      expect(await x.export(const AttendanceExportRequest.day()), isA<AttendanceExportCancelled>());
      cancelSave = false;
      failSave = true;
      final out = await x.export(const AttendanceExportRequest.day());
      expect(out, isA<AttendanceExportFailed>().having((o) => o.message, 'message', isNot(contains('/private'))));
    });

    test('12. a branch-restricted user’s file is prefixed with their branch, as on web', () async {
      final c = await signedIn(hrUser(['attendance.view', 'attendance.export'], branch: 'North Wing'));
      await c.read(attendanceExporterProvider).export(const AttendanceExportRequest.month(year: 2026, month: 1));
      expect(saved.single.name, 'attendance_North-Wing_2026-01.csv');
    });

    test('14–15. without attendance.export nothing is requested, whatever the caller', () async {
      final c = await signedIn(hrViewer);
      final out = await c.read(attendanceExporterProvider).export(const AttendanceExportRequest.day());
      expect(out, isA<AttendanceExportFailed>().having((o) => o.message, 'message', kAttendanceExportNotPermitted));
      expect(server.exports, isEmpty);
    });

    test('6. invalid ranges and future months are refused before any request', () async {
      final c = await signedIn(hrExporter);
      final x = c.read(attendanceExporterProvider);
      expect(await x.export(AttendanceExportRequest.range(from: DateTime(2026, 3, 10), to: DateTime(2026, 3, 1))),
          isA<AttendanceExportFailed>().having((o) => o.message, 'm', 'From date must be on or before To date.'));
      expect(await x.export(AttendanceExportRequest.range(from: DateTime(2026, 1, 1), to: DateTime(2026, 2, 1))),
          isA<AttendanceExportFailed>().having((o) => o.message, 'm', 'Range cannot exceed 31 days.'));
      expect(await x.export(const AttendanceExportRequest.month(year: 2026, month: 4)), isA<AttendanceExportFailed>());
      expect(server.exports, isEmpty);
    });

    test('16. a second export while one runs is ignored; the next one after it goes through', () async {
      final c = await signedIn(hrExporter);
      final x = c.read(attendanceExporterProvider);
      server.hold = Completer();
      final first = x.export(const AttendanceExportRequest.day());
      await Future<void>.delayed(Duration.zero);
      expect(await x.export(const AttendanceExportRequest.month(year: 2026, month: 2)), isA<AttendanceExportIgnored>());
      server.hold!.complete();
      expect(await first, isA<AttendanceExportSaved>());
      server.hold = null;
      expect(await x.export(const AttendanceExportRequest.month(year: 2026, month: 2)), isA<AttendanceExportSaved>());
      expect(server.exports, hasLength(2));
    });
  });

  group('screen', () {
    testWidgets('14. the Export button is only there with attendance.export', (tester) async {
      await pumpScreen(tester, as: hrViewer);
      expect(find.byKey(const Key('attendance-export-button')), findsNothing);
      expect(find.text('Import'), findsOneWidget); // the rest of the toolbar is unchanged
    });

    testWidgets('1. single day (default): table date, filters, file name and the old success message', (tester) async {
      await pumpScreen(tester);
      screen.read(hrAttendanceDateFilterProvider.notifier).state = DateTime(2026, 3, 2);
      screen.read(hrAttendanceBranchFilterProvider.notifier).state = 'North Wing';
      await tester.pumpAndSettle();
      await openSheet(tester);
      expect(textOf(tester, 'export-filters'), 'Branch: North Wing · Department: All');
      expect(inSheet(find.text('2 Mar 2026')), findsOneWidget);
      await submit(tester);
      expect(server.exports, [
        {'date': '2026-03-02', 'branch': 'North Wing'}
      ]);
      expect(saved.single.name, 'attendance_2026-03-02.csv');
      expect(find.byKey(const Key('attendance-export-sheet')), findsNothing);
      expect(find.text('Attendance exported.'), findsOneWidget);
      expect(snack(tester).backgroundColor, AppColors.success);
    });

    testWidgets('1. single day with no table date still sends no date (server’s today)', (tester) async {
      await pumpScreen(tester);
      await openSheet(tester);
      expect(inSheet(find.text('15 Mar 2026')), findsOneWidget);
      await submit(tester);
      expect(server.exports, [<String, dynamic>{}]);
      expect(saved.single.name, 'attendance_2026-03-15.csv');
    });

    testWidgets('2–3. month: picker stops at this month; previous-year December is sent as 2025-12', (tester) async {
      await pumpScreen(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('export-mode-month')));
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);
      await tester.tap(find.byKey(const Key('export-month-field')));
      await tester.pumpAndSettle();
      Widget monthButton(int m) => tester.widget<TextButton>(find.byKey(Key('export-month-$m')));
      expect((monthButton(4) as TextButton).onPressed, isNull); // April 2026 is in the future
      expect((monthButton(3) as TextButton).onPressed, isNotNull);
      expect(tester.widget<IconButton>(find.byKey(const Key('export-month-next-year'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('export-month-prev-year')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('export-month-12')));
      await tester.pumpAndSettle();
      expect(find.text('December 2025'), findsOneWidget);
      await submit(tester);
      expect(server.exports, [
        {'month': '2025-12'}
      ]);
      expect(saved.single.name, 'attendance_2025-12.csv');
    });

    testWidgets('5. range: defaults to 1st of the month – today; picking From sends the new start', (tester) async {
      await pumpScreen(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('export-mode-range')));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('1 Mar 2026')), findsOneWidget);
      expect(inSheet(find.text('15 Mar 2026')), findsOneWidget);
      await tester.tap(find.byKey(const Key('export-from-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('5 Mar 2026')), findsOneWidget);
      await submit(tester);
      expect(server.exports, [
        {'from_date': '2026-03-05', 'to_date': '2026-03-15'}
      ]);
      expect(saved.single.name, 'attendance_2026-03-05_to_2026-03-15.csv');
    });

    testWidgets('10. an empty export still saves and says nothing matched', (tester) async {
      server.csv = utf8.encode(csvText(rows: false));
      await pumpScreen(tester);
      await openSheet(tester);
      await submit(tester);
      expect(saved, hasLength(1));
      expect(find.text('Attendance exported — no records matched the filters.'), findsOneWidget);
    });

    testWidgets('11/17. a refusal stays in the sheet; Export CSV again retries and saves', (tester) async {
      await pumpScreen(tester);
      await openSheet(tester);
      server.refuseNext = (status: 400, message: 'Cannot export a future month.');
      await submit(tester);
      expect(textOf(tester, 'export-error'), 'Cannot export a future month.');
      expect(find.byKey(const Key('attendance-export-sheet')), findsOneWidget);
      expect(saved, isEmpty);
      await submit(tester);
      expect(saved, hasLength(1));
      expect(server.exports, hasLength(2));
      expect(find.text('Attendance exported.'), findsOneWidget);
    });

    testWidgets('13. closing the save dialog keeps the sheet open with no message', (tester) async {
      cancelSave = true;
      await pumpScreen(tester);
      await openSheet(tester);
      await submit(tester);
      expect(find.byKey(const Key('attendance-export-sheet')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const Key('export-error')), findsNothing);
      expect(submitButton(tester).onPressed, isNotNull);
    });

    testWidgets('16–17. while exporting: "Exporting…", buttons disabled, extra taps send nothing', (tester) async {
      await pumpScreen(tester);
      await openSheet(tester);
      server.hold = Completer();
      await tester.tap(find.byKey(const Key('export-submit')));
      await pumpFor(tester);
      expect(server.exports, hasLength(1)); // the request is out and held
      expect(find.text('Exporting…'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);
      expect(tester.widget<TextButton>(find.byKey(const Key('export-cancel'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('export-submit')), warnIfMissed: false);
      await pumpFor(tester);
      expect(server.exports, hasLength(1));
      server.hold!.complete();
      await tester.pumpAndSettle();
      expect(saved, hasLength(1));
      expect(server.exports, hasLength(1));
    });
  });
}
