import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_export.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';

import 'attendance_export_test.dart' hide main;

// Task 94 / HO-43: single-employee attendance export (web
// lib/attendanceExport.ts:21-45 and AttendanceTab.tsx:86-104, 255-320;
// backend AttendanceExportFilterSerializer.employee + HRAttendanceExportView
// hr_attendance.py:876-881). Synthetic employees only.

ResponseBody _ok(Object data) => ResponseBody.fromString(
      jsonEncode({'status': 'success', 'message': 'ok', 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );

class EmployeeSearchServer extends FakeExportServer {
  final searches = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> employees = [
    for (var i = 1; i <= 10; i++)
      {'id': 'u$i', 'employee_id': 'EMP-90$i', 'full_name': 'Test Person $i', 'department': 'QA', 'status': 'active'},
  ];
  bool failSearch = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path == ApiConstants.employees && o.queryParameters.containsKey('search')) {
      searches.add(Map.of(o.queryParameters));
      if (failSearch) {
        return ResponseBody.fromString('{"status":"error","message":"Search failed.","data":null}', 500, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
      }
      final q = '${o.queryParameters['search']}'.toLowerCase();
      return _ok({
        'results': [
          for (final e in employees)
            if ('${e['full_name']} ${e['employee_id']}'.toLowerCase().contains(q)) e
        ],
        'count': employees.length,
      });
    }
    return super.fetch(o, s, c);
  }
}

late EmployeeSearchServer search;

Future<void> pickSingle(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('export-scope')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Single Employee').last);
  await tester.pumpAndSettle();
}

/// Past the 300 ms debounce, then lets the search request finish ("Searching…"
/// has no animation, so pumpAndSettle alone would stop before it does).
Future<void> settleSearch(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('export-employee-search')), text);
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    reset();
    server = search = EmployeeSearchServer();
  });

  group('rules (web attendanceExportParams / attendanceExportFilename)', () {
    test('an employee replaces the branch / department filters in every mode', () {
      const day = AttendanceExportRequest.day(branch: 'North Wing', department: 'QA', employeeId: 'EMP-901');
      expect(day.params(), {'employee': 'EMP-901'});
      const month = AttendanceExportRequest.month(year: 2026, month: 2, branch: 'B', department: 'D', employeeId: 'E1');
      expect(month.params(), {'month': '2026-02', 'employee': 'E1'});
      final range = AttendanceExportRequest.range(
          from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 5), branch: 'B', employeeId: 'E1');
      expect(range.params(), {'from_date': '2026-03-01', 'to_date': '2026-03-05', 'employee': 'E1'});
      // All employees: unchanged.
      expect(const AttendanceExportRequest.day(branch: 'B', department: 'D').params(), {'branch': 'B', 'department': 'D'});
    });

    test('file name: attendance_<ID>_<period>.csv, unsafe characters → _, branch slug ignored', () {
      final today = DateTime(2026, 3, 15);
      expect(AttendanceExportRequest.day(date: DateTime(2026, 3, 2), employeeId: 'EMP/9 01')
              .fileName(today, branchSlug: 'North-Wing_'),
          'attendance_EMP_9_01_2026-03-02.csv');
      expect(const AttendanceExportRequest.month(year: 2026, month: 2, employeeId: 'E-1_a').fileName(today),
          'attendance_E-1_a_2026-02.csv');
      expect(
          AttendanceExportRequest.range(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 5), employeeId: 'E1')
              .fileName(today),
          'attendance_E1_2026-03-01_to_2026-03-05.csv');
      expect(const AttendanceExportRequest.day().fileName(today, branchSlug: 'North-Wing_'),
          'attendance_North-Wing_2026-03-15.csv');
    });

    test('ExportEmployeeOption reads the list row (department as text or {name})', () {
      final a = ExportEmployeeOption.fromJson(
          {'id': 'u1', 'employee_id': 'E1', 'full_name': 'A B', 'department': {'name': 'QA'}, 'status': 'active'});
      expect((a.department, a.label), ('QA', 'A B (E1)'));
      expect(ExportEmployeeOption.fromJson({'employee_id': 'E2', 'full_name': 'C'}).department, '');
    });

    test('the exporter sends `employee` and no branch / department', () async {
      final c = await signedIn(hrExporter);
      final out = await c.read(attendanceExporterProvider).export(
          const AttendanceExportRequest.day(branch: 'North Wing', department: 'QA', employeeId: 'EMP-901'));
      expect(out, isA<AttendanceExportSaved>());
      expect(search.exports, [
        {'employee': 'EMP-901'}
      ]);
      expect(saved.single.name, 'attendance_EMP-901_2026-03-15.csv');
    });
  });

  group('sheet (web AttendanceTab "Export employees")', () {
    testWidgets('defaults to All Employees; Single Employee disables Export until one is picked', (tester) async {
      await pumpScreen(tester);
      await openSheet(tester);
      expect(inSheet(find.text('All Employees')), findsOneWidget);
      expect(find.byKey(const Key('export-employee-search')), findsNothing);
      expect(submitButton(tester).onPressed, isNotNull);

      await pickSingle(tester);
      expect(find.byKey(const Key('export-employee-search')), findsOneWidget);
      expect(find.text('Search employee by name or ID…'), findsOneWidget);
      expect(textOf(tester, 'export-select-employee'), 'Select an employee from the list to export.');
      expect(submitButton(tester).onPressed, isNull);
      expect(search.exports, isEmpty);
    });

    testWidgets('search: 2+ characters, 300 ms debounce, page_size 20, inactive dropped, first 8', (tester) async {
      search.employees[1]['status'] = 'inactive'; // EMP-902
      await pumpScreen(tester);
      await openSheet(tester);
      await pickSingle(tester);

      await type(tester, 'T');
      await tester.pump(const Duration(milliseconds: 400));
      expect(search.searches, isEmpty, reason: 'one character never searches');

      await type(tester, 'Test');
      await tester.pump(const Duration(milliseconds: 250));
      expect(search.searches, isEmpty, reason: 'still inside the 300 ms debounce');
      await tester.pump(const Duration(milliseconds: 60));
      expect(search.searches.length, lessThanOrEqualTo(1));
      await settleSearch(tester);
      expect(search.searches, [
        {'search': 'Test', 'page_size': 20}
      ]);
      expect(find.byKey(const Key('export-employee-EMP-902')), findsNothing);
      final rows = find.descendant(
          of: find.byKey(const Key('export-employee-results')), matching: find.byType(InkWell));
      expect(rows, findsNWidgets(8));
      expect(find.textContaining('EMP-901 · QA', findRichText: true), findsOneWidget);
    });

    testWidgets('picking sets "Name (ID)", enables Export, and sends employee without the branch filter',
        (tester) async {
      await pumpScreen(tester);
      screen.read(hrAttendanceDateFilterProvider.notifier).state = DateTime(2026, 3, 2);
      screen.read(hrAttendanceBranchFilterProvider.notifier).state = 'North Wing';
      await tester.pumpAndSettle();
      await openSheet(tester);
      await pickSingle(tester);
      await type(tester, 'Person 3');
      await settleSearch(tester);
      await tester.tap(find.byKey(const Key('export-employee-EMP-903')));
      await tester.pumpAndSettle();
      expect(find.text('Test Person 3 (EMP-903)'), findsOneWidget);
      expect(find.byKey(const Key('export-employee-results')), findsNothing);
      expect(find.byKey(const Key('export-select-employee')), findsNothing);

      await submit(tester);
      expect(search.exports, [
        {'date': '2026-03-02', 'employee': 'EMP-903'}
      ]);
      expect(saved.single.name, 'attendance_EMP-903_2026-03-02.csv');
    });

    testWidgets('editing the text after a pick clears the selection again', (tester) async {
      await pumpScreen(tester);
      await openSheet(tester);
      await pickSingle(tester);
      await type(tester, 'Person 4');
      await settleSearch(tester);
      await tester.tap(find.byKey(const Key('export-employee-EMP-904')));
      await tester.pumpAndSettle();
      expect(submitButton(tester).onPressed, isNotNull);
      await type(tester, 'Test Person 4 (EMP-90');
      expect(submitButton(tester).onPressed, isNull);
      expect(find.byKey(const Key('export-select-employee')), findsOneWidget);
      await settleSearch(tester);
    });

    testWidgets('"No matching employees." and a search error', (tester) async {
      await pumpScreen(tester);
      await openSheet(tester);
      await pickSingle(tester);
      await type(tester, 'zz');
      await settleSearch(tester);
      expect(textOf(tester, 'export-employee-none'), 'No matching employees.');

      search.failSearch = true;
      await type(tester, 'zzz');
      await settleSearch(tester);
      expect(find.byKey(const Key('export-employee-error')), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('server 404 "Employee not found." is shown and nothing is saved', (tester) async {
      await pumpScreen(tester);
      await openSheet(tester);
      await pickSingle(tester);
      await type(tester, 'Person 5');
      await settleSearch(tester);
      await tester.tap(find.byKey(const Key('export-employee-EMP-905')));
      await tester.pumpAndSettle();
      search.refuseNext = (status: 404, message: 'Employee not found.');
      await submit(tester);
      expect(textOf(tester, 'export-error'), contains('Employee not found.'));
      expect(saved, isEmpty);
    });

    testWidgets('back to All Employees exports with the filters again', (tester) async {
      await pumpScreen(tester);
      screen.read(hrAttendanceBranchFilterProvider.notifier).state = 'North Wing';
      await tester.pumpAndSettle();
      await openSheet(tester);
      await pickSingle(tester);
      await type(tester, 'Person 6');
      await settleSearch(tester);
      await tester.tap(find.byKey(const Key('export-employee-EMP-906')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('export-scope')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All Employees').last);
      await tester.pumpAndSettle();
      await submit(tester);
      expect(search.exports, [
        {'branch': 'North Wing'}
      ]);
      expect(saved.single.name, 'attendance_2026-03-15.csv');
    });
  });
}
