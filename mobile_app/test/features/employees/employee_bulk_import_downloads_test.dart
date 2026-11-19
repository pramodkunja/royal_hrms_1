import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_bulk_import_support.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_bulk_import_screen.dart';
import 'package:mobile_app/shared/models/bulk_import_result.dart';

// Task 98: web BulkImportModal sample downloads (GET
// /employees/bulk-import/sample/?format=csv|xlsx, bytes saved untouched as
// employee_import_sample.<format>) and the client-built error_report.csv.
// Stand-in server and saver; synthetic data only.

class FakeBulkServer implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  Object body = <int>[];
  Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    requests.add(o);
    if (gate != null) await gate!.future;
    final bytes = body is List<int> ? body as List<int> : utf8.encode(jsonEncode(body));
    return ResponseBody.fromBytes(bytes, status);
  }

  @override
  void close({bool force = false}) {}
}

class _Auth extends AuthNotifier {
  _Auth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

UserEntity _user(List<String> perms, {bool superuser = false}) => UserEntity(
      id: 'u1',
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

const _errors = [
  BulkImportErrorResult(row: 2, identifier: 'a@x.test', field: 'role', message: 'Role "Boss", not found'),
  BulkImportErrorResult(row: 3, identifier: null, field: 'email', message: 'line one\nline two'),
];

BulkImportResult _result(List<BulkImportErrorResult> errors) => BulkImportResult(
    totalRows: 2,
    created: 0,
    skipped: 0,
    failed: errors.length,
    createdRows: const [],
    skippedRows: const [],
    errors: errors);

late FakeBulkServer server;
late List<(String, Uint8List)> saved;
String? savePath;
Object? saveThrows;

Future<void> pumpScreen(WidgetTester tester, UserEntity u, {BulkImportResult? result}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = FakeBulkServer();
  saved = [];
  savePath = '/saved/file';
  saveThrows = null;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      employeeFileSaverProvider.overrideWithValue((name, bytes) async {
        if (saveThrows != null) throw saveThrows!;
        saved.add((name, bytes));
        return savePath;
      }),
    ],
    child: MaterialApp(home: EmployeeBulkImportScreen(initialResult: result)),
  ));
  await tester.pumpAndSettle();
}

Finder k(String key) => find.byKey(Key(key));
final _hr = _user(const ['employees.create']);

void main() {
  group('report text (web downloadErrorReport / csvCell)', () {
    test('header, order, quoting, no BOM, no trailing newline', () {
      expect(buildEmployeeImportErrorReport(_errors),
          'Row,Email,Field,Error\n2,a@x.test,role,"Role ""Boss"", not found"\n3,,email,"line one\nline two"');
      final bytes = employeeImportErrorReportBytes(_errors);
      expect(bytes.take(3).toList(), isNot([0xEF, 0xBB, 0xBF]));
      expect(utf8.decode(bytes), buildEmployeeImportErrorReport(_errors));
    });
  });

  group('sample download', () {
    for (final format in ['csv', 'xlsx']) {
      testWidgets('$format: request, bytes saved untouched, filename', (tester) async {
        await pumpScreen(tester, _hr);
        server.body = <int>[0, 1, 2, 250, 251];
        await tester.tap(k('employee-sample-$format'));
        await tester.pumpAndSettle();
        expect(server.requests.single.path, '/employees/bulk-import/sample/');
        expect(server.requests.single.method, 'GET');
        expect(server.requests.single.queryParameters, {'format': format});
        expect(saved.single.$1, 'employee_import_sample.$format');
        expect(saved.single.$2, [0, 1, 2, 250, 251]);
        expect(find.text('Sample downloaded.'), findsOneWidget);
      });
    }

    testWidgets('403 shows the server message and saves nothing', (tester) async {
      await pumpScreen(tester, _hr);
      server.status = 403;
      server.body = {
        'status': 'error',
        'message': 'You do not have permission to download the employee import template.'
      };
      await tester.tap(k('employee-sample-csv'));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      expect(find.text('You do not have permission to download the employee import template.'), findsOneWidget);
    });

    testWidgets('busy blocks double taps and the other format', (tester) async {
      await pumpScreen(tester, _hr);
      server.gate = Completer<void>();
      await tester.tap(k('employee-sample-csv'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Downloading…'), findsOneWidget);
      await tester.tap(k('employee-sample-csv'), warnIfMissed: false);
      await tester.tap(k('employee-sample-xlsx'), warnIfMissed: false);
      await tester.pump();
      expect(server.requests, hasLength(1));
      server.gate!.complete();
      await tester.pumpAndSettle();
      expect(saved, hasLength(1));
      expect(find.text('Downloading…'), findsNothing);
    });

    testWidgets('save cancelled: no error, no toast', (tester) async {
      await pumpScreen(tester, _hr);
      savePath = null;
      await tester.tap(k('employee-sample-csv'));
      await tester.pumpAndSettle();
      expect(k('employee-sample-error'), findsNothing);
      expect(find.text('Sample downloaded.'), findsNothing);
    });

    testWidgets('save failure: plain message without paths', (tester) async {
      await pumpScreen(tester, _hr);
      saveThrows = Exception('/data/user/0/secret/path failed');
      await tester.tap(k('employee-sample-csv'));
      await tester.pumpAndSettle();
      expect(k('employee-sample-error'), findsOneWidget);
      expect(find.textContaining('/data/'), findsNothing);
    });
  });

  group('error report button', () {
    testWidgets('shown with errors; saves error_report.csv', (tester) async {
      await pumpScreen(tester, _hr, result: _result(_errors));
      await tester.ensureVisible(k('employee-error-report'));
      await tester.tap(k('employee-error-report'));
      await tester.pumpAndSettle();
      expect(saved.single.$1, 'error_report.csv');
      expect(utf8.decode(saved.single.$2), buildEmployeeImportErrorReport(_errors));
      expect(server.requests, isEmpty);
    });

    testWidgets('not offered without errors', (tester) async {
      await pumpScreen(tester, _hr, result: _result(const []));
      expect(k('employee-error-report'), findsNothing);
    });

    testWidgets('save failure shows a plain message', (tester) async {
      await pumpScreen(tester, _hr, result: _result(_errors));
      saveThrows = Exception('/x/y');
      await tester.ensureVisible(k('employee-error-report'));
      await tester.tap(k('employee-error-report'));
      await tester.pumpAndSettle();
      expect(find.text('Could not save the error report.'), findsOneWidget);
    });
  });

  group('permission gating (employees.create)', () {
    for (final (name, u, ok) in [
      ('creator', _hr, true),
      ('superuser', _user(const [], superuser: true), true),
      ('viewer', _user(const ['employees.view']), false),
    ]) {
      testWidgets('$name: ${ok ? 'sample buttons' : 'denied view'}', (tester) async {
        await pumpScreen(tester, u);
        expect(k('employee-sample-csv'), ok ? findsOneWidget : findsNothing);
        expect(k('employee-sample-xlsx'), ok ? findsOneWidget : findsNothing);
        expect(k('employee-import-denied'), ok ? findsNothing : findsOneWidget);
        expect(server.requests, isEmpty);
      });
    }
  });
}
