import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/data/models/notice_period_models.dart';
import 'package:mobile_app/features/settings/presentation/notice_period/notice_period_providers.dart';
import 'package:mobile_app/features/settings/presentation/notice_period/notice_period_screen.dart';
import 'package:mobile_app/features/settings/presentation/settings_hub/settings_screen.dart';

// Settings → Notice Period (web settings/notice-period/page.tsx and, on the
// production branch, NoticePeriodImportModal.tsx) against a stand-in for
// EmployeeListCreateView.get, EmployeeDetailView.put and
// NoticePeriodImportView / NoticePeriodImportSampleView. Synthetic data only;
// no real employee is changed and no real file is imported.

const listPath = '/employees/';
String detailPath(String code) => '/employees/$code/';
const importPath = '/employees/notice-period/import/';
const samplePath = '/employees/notice-period/import/sample/';

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> emp(int i, {Object? notice}) => {
      'id': 'u$i',
      'employee_id': 'TST${i.toString().padLeft(3, '0')}',
      'full_name': 'Test Person $i',
      'branch': i.isEven ? 'North' : '',
      'department': i.isEven ? 'Engineering' : 'Sales',
      'designation': 'Analyst',
      'notice_period_days': notice,
    };

Map<String, dynamic> importRow(int row, String code, String status,
        {String name = '', int? current, int? next, String message = ''}) =>
    {
      'row': row,
      'employee_id': code,
      'name': name,
      'current': current,
      'new': next,
      'status': status,
      'message': message,
    };

final previewRows = [
  importRow(2, 'TST001', 'update', name: 'Test Person 1', current: 30, next: 60, message: 'Will be updated.'),
  importRow(3, 'TST002', 'update', name: 'Test Person 2', next: 90, message: 'Will be updated.'),
  importRow(4, 'TST003', 'no_change', name: 'Test Person 3', current: 1, next: 1, message: 'No change.'),
  importRow(5, 'TST004', 'skipped', name: 'Test Person 4', message: 'Blank notice period — left unchanged.'),
  importRow(6, 'NOPE01', 'error', message: 'Employee not found.'),
];

class FakeServer implements HttpClientAdapter {
  FakeServer() {
    employees = [
      emp(1, notice: 30),
      emp(2),
      emp(3, notice: 1),
      for (var i = 4; i <= 23; i++) emp(i, notice: 60),
    ];
  }

  late List<Map<String, dynamic>> employees;
  int? listStatus;
  Completer<void>? holdList;
  Completer<void>? holdPut;
  Completer<void>? holdImport;
  ({int status, String message})? refuseNextPut;
  ({int status, String message})? refuseNextImport;
  int previewUpdates = 2;
  final calls = <({String method, String path, Map<String, dynamic> query, Object? body})>[];

  List<({String method, String path, Map<String, dynamic> query, Object? body})> of(String method, String path) =>
      calls.where((c) => c.method == method && c.path == path).toList();
  int get writes => calls.where((c) => c.method != 'GET').length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: Map.of(o.queryParameters), body: o.data));
    if (o.method == 'GET' && o.path == listPath) {
      final gate = holdList;
      if (gate != null) await gate.future;
      if (listStatus != null) {
        return _json(listStatus!, {'status': 'error', 'message': 'You do not have permission.', 'data': {}});
      }
      final search = (o.queryParameters['search'] as String? ?? '').toLowerCase();
      final dept = o.queryParameters['department'] as String? ?? '';
      final page = o.queryParameters['page'] as int;
      final size = o.queryParameters['page_size'] as int;
      final hits = employees
          .where((e) =>
              (search.isEmpty ||
                  (e['full_name'] as String).toLowerCase().contains(search) ||
                  (e['employee_id'] as String).toLowerCase().contains(search)) &&
              (dept.isEmpty || e['department'] == dept))
          .toList();
      final slice = hits.skip((page - 1) * size).take(size).toList();
      return _json(200, {
        'status': 'success',
        'message': 'Employees retrieved.',
        'data': {
          'count': hits.length,
          'page': page,
          'page_size': size,
          'total_pages': (hits.length / size).ceil(),
          'results': slice
        },
      });
    }
    if (o.method == 'PUT' && o.path.startsWith(listPath)) {
      final gate = holdPut;
      if (gate != null) await gate.future;
      final refusal = refuseNextPut;
      if (refusal != null) {
        refuseNextPut = null;
        return _json(refusal.status, {'status': 'error', 'message': refusal.message, 'data': {}});
      }
      final code = o.path.split('/')[2];
      final e = employees.firstWhere((e) => e['employee_id'] == code);
      e['notice_period_days'] = (o.data as Map)['notice_period_days'];
      return _json(200, {'status': 'success', 'message': 'Employee updated.', 'data': e});
    }
    if (o.method == 'POST' && o.path == importPath) {
      final gate = holdImport;
      if (gate != null) await gate.future;
      final refusal = refuseNextImport;
      if (refusal != null) {
        refuseNextImport = null;
        return _json(refusal.status, {'status': 'error', 'message': refusal.message, 'data': {}});
      }
      final form = o.data as FormData;
      final dry = form.fields.any((f) => f.key == 'dry_run' && f.value == 'true');
      final summary = {'total': 5, 'update': previewUpdates, 'no_change': 1, 'skipped': 1, 'error': 1};
      if (dry) {
        return _json(200, {
          'status': 'success',
          'message': 'Preview ready. Nothing has been saved yet.',
          'data': {'summary': summary, 'rows': previewRows},
        });
      }
      return _json(200, {
        'status': 'success',
        'message': '2 notice period(s) updated.',
        'data': {
          'summary': {...summary, 'updated': 2},
          'rows': [
            for (final r in previewRows)
              r['status'] == 'update' ? {...r, 'status': 'updated', 'message': 'Updated.'} : r
          ],
        },
      });
    }
    if (o.method == 'GET' && o.path == samplePath) {
      return ResponseBody.fromBytes(utf8.encode('Employee ID,Notice Period (days)\nEMP001,30\n'), 200);
    }
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
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

UserEntity user(List<String> perms, {bool superuser = false}) => UserEntity(
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

final editor = user(['settings.view', 'employees.view', 'employees.edit']);
final viewer = user(['settings.view', 'employees.view']);

typedef Picked = ({String name, Uint8List bytes, int size});

late FakeServer server;
Picked? nextFile;
final saved = <({String name, Uint8List bytes})>[];

Picked file(String name, {int? size}) {
  final bytes = Uint8List.fromList(utf8.encode('Employee ID,Notice Period (days)\nTST001,60\n'));
  return (name: name, bytes: bytes, size: size ?? bytes.length);
}

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      noticeImportFilePickerProvider.overrideWithValue(() async => nextFile),
      noticeSampleSaverProvider.overrideWithValue((name, bytes) async {
        saved.add((name: name, bytes: bytes));
        return '/tmp/$name';
      }),
    ];

/// Hub → Notice Period through the real routes (SettingsAppBar needs GoRouter).
Future<void> pumpApp(WidgetTester tester,
    {UserEntity? as, FakeServer? with_, String start = AppRoutes.settingsNoticePeriod}) async {
  tester.view.physicalSize = const Size(1080, 14000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? FakeServer();
  saved.clear();
  nextFile = null;
  final router = GoRouter(initialLocation: AppRoutes.settings, routes: [
    GoRoute(path: AppRoutes.settings, builder: (_, __) => const SettingsScreen()),
    GoRoute(path: AppRoutes.settingsNoticePeriod, builder: (_, __) => const NoticePeriodScreen()),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? editor),
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  if (start != AppRoutes.settings) {
    router.push(start);
    await tester.pumpAndSettle();
  }
}

Finder byKey(String k) => find.byKey(Key(k));

Map<String, dynamic> lastListQuery() => server.of('GET', listPath).last.query;

Future<void> save(WidgetTester tester, String code, String value) async {
  await tester.enterText(byKey('notice-input-$code'), value);
  await tester.pump();
  await tester.tap(byKey('notice-save-$code'));
  await tester.pumpAndSettle();
}

String? rowError(WidgetTester tester, String code) {
  final f = byKey('notice-error-$code');
  return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
}

Future<void> openImport(WidgetTester tester) async {
  await tester.tap(byKey('notice-import-open'));
  await tester.pumpAndSettle();
}

Future<void> pick(WidgetTester tester, Picked f) async {
  nextFile = f;
  await tester.tap(byKey('notice-import-pick'));
  await tester.pumpAndSettle();
}

String alert(WidgetTester tester, String key) =>
    tester.widgetList<Text>(find.descendant(of: byKey(key), matching: find.byType(Text))).map((t) => t.data).join();

bool enabled(WidgetTester tester, String key) {
  final w = tester.widget(byKey(key));
  return switch (w) {
    FilledButton b => b.onPressed != null,
    TextButton b => b.onPressed != null,
    OutlinedButton b => b.onPressed != null,
    IconButton b => b.onPressed != null,
    _ => throw StateError('$w'),
  };
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules (web lib/noticePeriod.ts)', () {
    test('input validation and payload value', () {
      expect(noticePeriodInputError(''), isNull);
      expect(noticePeriodInputError('  '), isNull);
      expect(noticePeriodInputError('0'), isNull);
      expect(noticePeriodInputError(' 365 '), isNull);
      expect(noticePeriodInputError('366'), 'Maximum 365 days.');
      expect(noticePeriodInputError('99999999999999999999999'), 'Maximum 365 days.');
      for (final bad in ['abc', '2.5', '-1', '+3', '1e2', '3 0']) {
        expect(noticePeriodInputError(bad), 'Enter a whole number of days.', reason: bad);
      }
      expect(noticePeriodPayloadValue(''), isNull);
      expect(noticePeriodPayloadValue(' 045 '), 45);
      expect(formatNoticePeriod(null), 'Not assigned');
      expect(formatNoticePeriod(1), '1 day');
      expect(formatNoticePeriod(0), '0 days');
    });
  });

  group('screen', () {
    testWidgets('1. loads page 1 of the employee list (no status filter) and pages on', (tester) async {
      await pumpApp(tester);
      expect(find.text('Notice Period'), findsWidgets);
      expect(lastListQuery(), {'page': 1, 'page_size': 20});
      expect(find.text('23 employees'), findsOneWidget);
      expect(byKey('notice-row-TST001'), findsOneWidget);
      expect(byKey('notice-row-TST021'), findsNothing);
      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(enabled(tester, 'notice-prev'), isFalse);
      await tester.tap(byKey('notice-next'));
      await tester.pumpAndSettle();
      expect(lastListQuery(), {'page': 2, 'page_size': 20});
      expect(byKey('notice-row-TST021'), findsOneWidget);
      expect(enabled(tester, 'notice-next'), isFalse);
    });

    testWidgets('2. shows each employee\'s details and notice period', (tester) async {
      await pumpApp(tester, as: viewer);
      final row = byKey('notice-row-TST002');
      expect(find.descendant(of: row, matching: find.text('Test Person 2')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('North · Engineering · Analyst')), findsOneWidget);
      expect(
          find.descendant(of: byKey('notice-row-TST001'), matching: find.text('— · Sales · Analyst')), findsOneWidget);
      expect(tester.widget<Text>(byKey('notice-value-TST001')).data, '30 days');
      expect(tester.widget<Text>(byKey('notice-value-TST002')).data, 'Not assigned');
      expect(tester.widget<Text>(byKey('notice-value-TST003')).data, '1 day');
    });

    testWidgets('3. search is debounced and resets to page 1; department filters the list', (tester) async {
      await pumpApp(tester);
      await tester.tap(byKey('notice-next'));
      await tester.pumpAndSettle();
      final before = server.of('GET', listPath).length;
      await tester.enterText(byKey('notice-search'), '  person 1 ');
      await tester.pump(const Duration(milliseconds: 100));
      expect(server.of('GET', listPath).length, before);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(lastListQuery(), {'search': 'person 1', 'page': 1, 'page_size': 20});
      await tester.enterText(byKey('notice-search'), '');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(byKey('notice-department'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sales').last);
      await tester.pumpAndSettle();
      expect(lastListQuery(), {'department': 'Sales', 'page': 1, 'page_size': 20});
      expect(byKey('notice-row-TST002'), findsNothing);
      expect(byKey('notice-row-TST001'), findsOneWidget);
    });

    testWidgets('4. loading, empty and error states', (tester) async {
      final s = FakeServer()..holdList = Completer();
      await pumpApp(tester, with_: s, start: AppRoutes.settings);
      final router = GoRouter.of(tester.element(find.byType(SettingsScreen)));
      router.push(AppRoutes.settingsNoticePeriod);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(byKey('notice-loading'), findsOneWidget);
      s.holdList!.complete();
      await tester.pumpAndSettle();
      expect(byKey('notice-loading'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester, with_: FakeServer()..employees = []);
      expect(byKey('notice-empty'), findsOneWidget);
      expect(find.text('No employees found.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester, with_: FakeServer()..listStatus = 403);
      expect(alert(tester, 'notice-error'), 'You do not have permission.');
    });
  });

  group('editing', () {
    testWidgets('5. a valid change sends exactly {notice_period_days: int} and reloads the list', (tester) async {
      await pumpApp(tester);
      // Save is enabled only once the value differs.
      expect(enabled(tester, 'notice-save-TST001'), isFalse);
      final getsBefore = server.of('GET', listPath).length;
      await save(tester, 'TST001', ' 45 ');
      final put = server.of('PUT', detailPath('TST001')).single;
      expect(put.body, {'notice_period_days': 45});
      expect(server.of('GET', listPath).length, getsBefore + 1);
      expect(byKey('notice-saved-TST001'), findsOneWidget);
      expect(enabled(tester, 'notice-save-TST001'), isFalse);
    });

    testWidgets('6. blank clears (null) and 0 is a value', (tester) async {
      await pumpApp(tester);
      await save(tester, 'TST001', '');
      expect(server.of('PUT', detailPath('TST001')).single.body, {'notice_period_days': null});
      await save(tester, 'TST002', '0');
      expect(server.of('PUT', detailPath('TST002')).single.body, {'notice_period_days': 0});
    });

    testWidgets('7. invalid values are refused with web\'s messages; nothing is sent', (tester) async {
      await pumpApp(tester);
      await save(tester, 'TST001', '2.5');
      expect(rowError(tester, 'TST001'), 'Enter a whole number of days.');
      await save(tester, 'TST001', '-3');
      expect(rowError(tester, 'TST001'), 'Enter a whole number of days.');
      await save(tester, 'TST001', '366');
      expect(rowError(tester, 'TST001'), 'Maximum 365 days.');
      expect(server.writes, 0);
    });

    testWidgets('8. server validation and permission errors are shown on the row; nothing reloads', (tester) async {
      final s = FakeServer()..refuseNextPut = (status: 400, message: 'Notice period must be between 0 and 365 days.');
      await pumpApp(tester, with_: s);
      final getsBefore = s.of('GET', listPath).length;
      await save(tester, 'TST001', '45');
      expect(rowError(tester, 'TST001'), 'Notice period must be between 0 and 365 days.');
      expect(s.of('GET', listPath).length, getsBefore);
      s.refuseNextPut = (status: 403, message: 'You do not have permission to perform this action.');
      await tester.tap(byKey('notice-save-TST001'));
      await tester.pumpAndSettle();
      expect(rowError(tester, 'TST001'), 'You do not have permission to perform this action.');
      s.refuseNextPut = (status: 404, message: 'Employee not found.');
      await tester.tap(byKey('notice-save-TST001'));
      await tester.pumpAndSettle();
      expect(rowError(tester, 'TST001'), 'Employee not found.');
    });

    testWidgets('9. double-tapping Save sends one request; the button shows Saving…', (tester) async {
      final s = FakeServer()..holdPut = Completer();
      await pumpApp(tester, with_: s);
      await tester.enterText(byKey('notice-input-TST001'), '45');
      await tester.pump();
      await tester.tap(byKey('notice-save-TST001'));
      await tester.pump();
      expect(find.descendant(of: byKey('notice-save-TST001'), matching: find.text('Saving…')), findsOneWidget);
      expect(enabled(tester, 'notice-save-TST001'), isFalse);
      await tester.tap(byKey('notice-save-TST001'), warnIfMissed: false);
      s.holdPut!.complete();
      await tester.pumpAndSettle();
      expect(s.of('PUT', detailPath('TST001')), hasLength(1));
    });
  });

  group('permissions', () {
    testWidgets('10. with employees.edit: inputs, Save and Import; no view-only note', (tester) async {
      await pumpApp(tester);
      expect(byKey('notice-input-TST001'), findsOneWidget);
      expect(byKey('notice-save-TST001'), findsOneWidget);
      expect(byKey('notice-import-open'), findsOneWidget);
      expect(byKey('notice-view-only'), findsNothing);
    });

    testWidgets('11. without employees.edit: read-only values, the view-only note, no Import', (tester) async {
      for (final u in [
        viewer,
        user(['settings.view', 'settings.edit', 'employees.view'])
      ]) {
        await pumpApp(tester, as: u);
        expect(server.of('GET', listPath), hasLength(1));
        expect(byKey('notice-value-TST001'), findsOneWidget);
        expect(byKey('notice-input-TST001'), findsNothing);
        expect(byKey('notice-save-TST001'), findsNothing);
        expect(byKey('notice-import-open'), findsNothing);
        expect(alert(tester, 'notice-view-only'),
            'You can view notice periods. Changing them needs permission to edit employees.');
        await tester.pumpWidget(const SizedBox());
      }
      // A superuser can edit.
      await pumpApp(tester, as: user([], superuser: true));
      expect(byKey('notice-input-TST001'), findsOneWidget);
    });

    test('12. the service refuses save, preview, import and sample without employees.edit, before any request',
        () async {
      for (final u in [
        viewer,
        user(['settings.edit'])
      ]) {
        server = FakeServer();
        final c = ProviderContainer(overrides: overrides(u));
        addTearDown(c.dispose);
        await c.read(authStateProvider.future);
        final svc = c.read(noticePeriodServiceProvider);
        final f = file('n.csv');
        await expectLater(svc.save('TST001', '45'), throwsA(isA<NoticePeriodDenied>()));
        await expectLater(svc.preview(f), throwsA(isA<NoticePeriodDenied>()));
        await expectLater(svc.apply(f), throwsA(isA<NoticePeriodDenied>()));
        await expectLater(svc.sample('csv'), throwsA(isA<NoticePeriodDenied>()));
        expect(server.calls, isEmpty);
      }
      expect(
          noticePeriodError(const NoticePeriodDenied(), 'x'), 'You do not have permission to change notice periods.');
    });

    test('13. the service refuses an invalid value and a second import while one runs, before any request', () async {
      server = FakeServer()..holdImport = Completer();
      final c = ProviderContainer(overrides: overrides(editor));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final svc = c.read(noticePeriodServiceProvider);
      await expectLater(svc.save('TST001', '400'), throwsA(isA<ArgumentError>()));
      final first = svc.preview(file('n.csv'));
      await Future<void>.delayed(Duration.zero);
      await expectLater(svc.apply(file('n.csv')), throwsA(isA<NoticePeriodBusy>()));
      server.holdImport!.complete();
      expect((await first).summary.update, 2);
      expect(server.of('POST', importPath), hasLength(1));
      expect(server.of('PUT', detailPath('TST001')), isEmpty);
    });
  });

  group('import', () {
    testWidgets('14. preview (dry_run) → confirm → result, with web\'s exact multipart payloads; the list reloads',
        (tester) async {
      await pumpApp(tester);
      await openImport(tester);
      expect(byKey('notice-import-dialog'), findsOneWidget);
      expect(enabled(tester, 'notice-import-preview'), isFalse);
      await pick(tester, file('notice.csv'));
      expect(tester.widget<Text>(byKey('notice-import-file')).data, 'notice.csv');

      await tester.tap(byKey('notice-import-preview'));
      await tester.pumpAndSettle();
      final dry = server.of('POST', importPath).single.body as FormData;
      expect(dry.fields.map((f) => '${f.key}=${f.value}'), ['dry_run=true']);
      expect(dry.files.single.key, 'file');
      expect(dry.files.single.value.filename, 'notice.csv');
      expect(alert(tester, 'notice-import-preview-summary'),
          'Preview (nothing saved yet): 2 to update, 1 no change, 1 skipped, 1 with errors. Only “Will update” rows are saved.');
      // Row-level results, as web Rows.
      Finder inRow(int r, String t) => find.descendant(of: byKey('notice-import-row-$r'), matching: find.text(t));
      expect(inRow(2, 'Test Person 1 (TST001)'), findsOneWidget);
      expect(inRow(2, '30 days → 60 days'), findsOneWidget);
      expect(inRow(2, 'Will update'), findsOneWidget);
      expect(inRow(3, 'Not assigned → 90 days'), findsOneWidget);
      expect(inRow(4, '1 day'), findsOneWidget);
      expect(inRow(4, 'No change'), findsOneWidget);
      expect(inRow(5, 'Blank notice period — left unchanged.'), findsOneWidget);
      expect(inRow(6, 'NOPE01'), findsOneWidget);
      expect(inRow(6, 'Employee not found.'), findsOneWidget);
      expect(inRow(6, 'Error'), findsOneWidget);
      expect(server.of('PUT', detailPath('TST001')), isEmpty);

      await tester.tap(byKey('notice-import-update'));
      await tester.pumpAndSettle();
      expect(alert(tester, 'notice-import-confirm-text'), startsWith('Update the notice period of 2 employee(s)?'));
      expect(find.text('Yes, update 2 employee(s)'), findsOneWidget);
      // Back returns to the preview without sending.
      await tester.tap(byKey('notice-import-back'));
      await tester.pumpAndSettle();
      expect(byKey('notice-import-confirm-text'), findsNothing);
      await tester.tap(byKey('notice-import-update'));
      await tester.pumpAndSettle();

      final getsBefore = server.of('GET', listPath).length;
      await tester.tap(byKey('notice-import-confirm'));
      await tester.pumpAndSettle();
      final posts = server.of('POST', importPath);
      expect(posts, hasLength(2));
      final real = posts[1].body as FormData;
      expect(real.fields, isEmpty);
      expect(real.files.single.key, 'file');
      expect(real.files.single.value.filename, 'notice.csv');
      expect(alert(tester, 'notice-import-result-summary'),
          'Finished: 2 updated, 1 no change, 1 skipped, 1 with errors (of 5 rows).');
      expect(find.descendant(of: byKey('notice-import-row-2'), matching: find.text('Updated')), findsOneWidget);

      await tester.tap(byKey('notice-import-done'));
      await tester.pumpAndSettle();
      expect(byKey('notice-import-dialog'), findsNothing);
      expect(server.of('GET', listPath).length, greaterThan(getsBefore));
    });

    testWidgets('15. file checks (web checkImportFile) refuse before any request', (tester) async {
      await pumpApp(tester);
      await openImport(tester);
      await pick(tester, file('notice.txt'));
      expect(alert(tester, 'notice-import-error'), 'Upload a .csv or .xlsx file.');
      expect(enabled(tester, 'notice-import-preview'), isFalse);
      await pick(tester, file('big.xlsx', size: 5 * 1024 * 1024 + 1));
      expect(alert(tester, 'notice-import-error'), 'File must not exceed 5 MB.');
      await pick(tester, file('empty.csv', size: 0));
      expect(alert(tester, 'notice-import-error'), 'The file is empty.');
      expect(enabled(tester, 'notice-import-preview'), isFalse);
      expect(server.writes, 0);
    });

    testWidgets('16. server errors on preview and on confirm are shown; confirm returns to the preview',
        (tester) async {
      final s = FakeServer()..refuseNextImport = (status: 400, message: 'The file needs an "Employee ID" column.');
      await pumpApp(tester, with_: s);
      await openImport(tester);
      await pick(tester, file('notice.csv'));
      await tester.tap(byKey('notice-import-preview'));
      await tester.pumpAndSettle();
      expect(alert(tester, 'notice-import-error'), 'The file needs an "Employee ID" column.');
      expect(byKey('notice-import-preview-summary'), findsNothing);

      await tester.tap(byKey('notice-import-preview'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('notice-import-update'));
      await tester.pumpAndSettle();
      s.refuseNextImport = (status: 403, message: 'You do not have permission to change notice periods.');
      await tester.tap(byKey('notice-import-confirm'));
      await tester.pumpAndSettle();
      expect(alert(tester, 'notice-import-error'), 'You do not have permission to change notice periods.');
      expect(byKey('notice-import-confirm-text'), findsNothing);
      expect(byKey('notice-import-update'), findsOneWidget);
      expect(byKey('notice-import-result-summary'), findsNothing);
    });

    testWidgets('17. nothing to update: the update button stays disabled', (tester) async {
      await pumpApp(tester, with_: FakeServer()..previewUpdates = 0);
      await openImport(tester);
      await pick(tester, file('notice.csv'));
      await tester.tap(byKey('notice-import-preview'));
      await tester.pumpAndSettle();
      expect(find.text('Update 0 employee(s)…'), findsOneWidget);
      expect(enabled(tester, 'notice-import-update'), isFalse);
    });

    testWidgets('18. double-tapping the confirm sends one import; Saving… and close is disabled meanwhile',
        (tester) async {
      final s = FakeServer();
      await pumpApp(tester, with_: s);
      await openImport(tester);
      await pick(tester, file('notice.csv'));
      await tester.tap(byKey('notice-import-preview'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('notice-import-update'));
      await tester.pumpAndSettle();
      s.holdImport = Completer();
      await tester.tap(byKey('notice-import-confirm'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      expect(enabled(tester, 'notice-import-confirm'), isFalse);
      expect(enabled(tester, 'notice-import-close'), isFalse);
      expect(enabled(tester, 'notice-import-back'), isFalse);
      await tester.tap(byKey('notice-import-confirm'), warnIfMissed: false);
      await tester.pump();
      s.holdImport!.complete();
      await tester.pumpAndSettle();
      expect(s.of('POST', importPath), hasLength(2)); // the preview and one confirm
      expect(byKey('notice-import-result-summary'), findsOneWidget);
    });

    testWidgets('19. sample files download from the sample endpoint', (tester) async {
      await pumpApp(tester);
      await openImport(tester);
      await tester.tap(byKey('notice-sample-xlsx'));
      await tester.pumpAndSettle();
      expect(server.of('GET', samplePath).single.query, {'format': 'xlsx'});
      expect(saved.single.name, 'notice_period_import_sample.xlsx');
      expect(saved.single.bytes, isNotEmpty);
    });

    testWidgets('20. Import another file resets the dialog', (tester) async {
      await pumpApp(tester);
      await openImport(tester);
      await pick(tester, file('notice.csv'));
      await tester.tap(byKey('notice-import-preview'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('notice-import-update'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('notice-import-confirm'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('notice-import-another'));
      await tester.pumpAndSettle();
      expect(byKey('notice-import-file'), findsNothing);
      expect(enabled(tester, 'notice-import-preview'), isFalse);
    });
  });

  group('Settings hub', () {
    testWidgets('21. the Notice Period tile is listed under All and Modules, opens the screen, and back returns',
        (tester) async {
      await pumpApp(tester, start: AppRoutes.settings);
      final tile = find.text('Notice Period');
      expect(tile, findsOneWidget);
      expect(find.text("Assign each employee's notice period for resignations"), findsOneWidget);
      await tester.tap(find.text('Modules'));
      await tester.pumpAndSettle();
      expect(tile, findsOneWidget);
      await tester.tap(find.text('Company'));
      await tester.pumpAndSettle();
      expect(tile, findsNothing);
      await tester.tap(find.text('All Settings'));
      await tester.pumpAndSettle();

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(NoticePeriodScreen), findsOneWidget);
      expect(server.of('GET', listPath), hasLength(1));
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(NoticePeriodScreen), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    test('22. the route needs settings.view, like every Settings page (web proxy.ts)', () {
      expect(requiredPermissionsFor(AppRoutes.settingsNoticePeriod), ['settings.view']);
    });
  });
}
