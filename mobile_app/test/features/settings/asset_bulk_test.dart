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
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/presentation/assets/asset_bulk_sheet.dart';
import 'package:mobile_app/features/settings/presentation/assets/assets_settings_screen.dart';

// Task 69b: Settings → Assets → Bulk Import / Bulk Assign — web
// BulkImportAssetsModal.tsx / BulkAssignAssetsModal.tsx, lib/assetImport.ts,
// lib/assetAssignImport.ts over backend views_import.py /
// views_assign_import.py (multipart `file`, `dry_run=true` preview, then a
// re-upload to save; assets.create / assets.edit). The stand-in server
// answers like the backend; files are synthetic. Nothing real is imported.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object data, [String message = 'ok']) =>
    _json(200, {'status': 'success', 'message': message, 'data': data});

Map<String, dynamic> importRow(int row, String tag, String status, [List<Map<String, String>> errors = const []]) =>
    {'row': row, 'asset_tag': tag, 'asset_name': 'Item $tag', 'branch': 'NW', 'status': status, 'errors': errors};

Map<String, dynamic> assignRow(int row, String tag, String emp, String status,
        {String assetName = '', String empName = '', List<Map<String, String>> errors = const []}) =>
    {
      'row': row,
      'asset_tag': tag,
      'asset_name': assetName,
      'employee_id': emp,
      'employee_name': empName,
      'status': status,
      'errors': errors,
    };

const reportCsv = 'Row,Asset Tag,Status,Column,Reason\r\n3,LAP-001,duplicate,Asset Tag,Already exists\r\n';
final reportB64 = base64Encode(utf8.encode(reportCsv));

class Upload {
  Upload(this.path, this.fields, this.fileName, this.bytes);
  final String path;
  final Map<String, String> fields;
  final String? fileName;
  final List<int> bytes;
}

class Backend implements HttpClientAdapter {
  final uploads = <Upload>[];
  final gets = <(String, Map<String, dynamic>)>[];
  ({int status, String message})? refuseNext;
  Completer<void>? hold;
  bool sampleFails = false;

  Map<String, dynamic> importPreview = {
    'rows': [
      importRow(2, 'LAP-100', 'ready'),
      importRow(3, 'LAP-001', 'duplicate', [
        {'column': 'Asset Tag', 'message': 'Already exists'}
      ]),
      importRow(4, 'LAP-101', 'error', [
        {'column': 'Branch', 'message': 'Unknown branch "XX".'}
      ]),
    ],
    'counts': {'ready': 1, 'duplicate': 1, 'error': 1},
    'error_report_csv': reportB64,
  };
  Map<String, dynamic> importResult = {
    'rows': [
      importRow(2, 'LAP-100', 'created'),
      importRow(3, 'LAP-001', 'duplicate', [
        {'column': 'Asset Tag', 'message': 'Already exists'}
      ]),
      importRow(4, 'LAP-101', 'error', [
        {'column': 'Branch', 'message': 'Unknown branch "XX".'}
      ]),
    ],
    'summary': {'total': 3, 'created': 1, 'duplicate': 1, 'failed': 1, 'skipped': 0},
    'error_report_csv': reportB64,
  };
  Map<String, dynamic> assignPreview = {
    'rows': [
      assignRow(2, 'LAP-002', 'EMP-7', 'ready', assetName: 'Spare Laptop', empName: 'Asha Test'),
      assignRow(3, 'LAP-001', 'EMP-8', 'already_assigned', assetName: 'Dell Latitude', empName: 'Ravi Test'),
      assignRow(4, 'LAP-009', 'EMP-404', 'error', errors: [
        {'column': 'Employee ID', 'message': 'No active employee with this ID in your scope.'}
      ]),
    ],
    'counts': {'ready': 1, 'already_assigned': 1, 'error': 1},
    'error_report_csv': reportB64,
  };
  Map<String, dynamic> assignResult = {
    'rows': [assignRow(2, 'LAP-002', 'EMP-7', 'assigned', assetName: 'Spare Laptop', empName: 'Asha Test')],
    'summary': {'total': 3, 'assigned': 1, 'already_assigned': 1, 'failed': 1, 'skipped': 0},
    'error_report_csv': null,
  };

  int lists() => gets.where((g) => g.$1 == '/assets/').length;
  List<Upload> uploadsTo(String path) => uploads.where((u) => u.path == path).toList();

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? requestStream, Future<void>? __) async {
    final p = o.path;
    if (o.method == 'GET') gets.add((p, Map.of(o.queryParameters)));
    if (p == '/assets/import/sample/' || p == '/assets/assignments/import/sample/') {
      if (sampleFails) return _json(403, {'status': 'error', 'message': 'You do not have permission.'});
      return ResponseBody.fromBytes(utf8.encode('Asset Tag,Asset Name\n'), 200, headers: {
        Headers.contentTypeHeader: ['text/csv']
      });
    }
    if ((p == '/assets/import/' || p == '/assets/assignments/import/') && o.method == 'POST') {
      final form = o.data as FormData;
      final file = form.files.where((f) => f.key == 'file').firstOrNull?.value;
      final bytes = <int>[];
      if (file != null) {
        // Dio has already read the original while sending; read a copy.
        await for (final chunk in file.clone().finalize()) {
          bytes.addAll(chunk);
        }
      }
      uploads.add(Upload(p, {for (final f in form.fields) f.key: f.value}, file?.filename, bytes));
      if (hold != null) await hold!.future;
      final r = refuseNext;
      if (r != null) {
        refuseNext = null;
        return _json(r.status, {'status': 'error', 'message': r.message, 'data': {}});
      }
      final dry = form.fields.any((f) => f.key == 'dry_run' && f.value == 'true');
      final assign = p.contains('assignments');
      return _ok(assign ? (dry ? assignPreview : assignResult) : (dry ? importPreview : importResult));
    }
    if (p == '/assets/') {
      return _ok({'count': 0, 'page': 1, 'page_size': 20, 'total_pages': 1, 'results': <Object>[]});
    }
    return _ok(<Object>[]);
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

final admin = user(['settings.view', 'assets.view', 'assets.create', 'assets.edit']);

late Backend server;
({String name, Uint8List bytes, int size})? nextFile;
final saved = <(String, List<int>)>[];
Finder byKey(String k) => find.byKey(Key(k));

({String name, Uint8List bytes, int size}) file(String name, List<int> bytes, {int? size}) =>
    (name: name, bytes: Uint8List.fromList(bytes), size: size ?? bytes.length);

final csvBytes = utf8.encode('Asset Tag,Asset Name,Category,Asset Type,Branch\nLAP-100,ThinkPad,IT Equipment,Laptop,NW\n');

Future<void> pump(WidgetTester tester, {UserEntity? as}) async {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Backend();
  nextFile = null;
  saved.clear();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? admin)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      assetBulkFilePickerProvider.overrideWithValue(() async => nextFile),
      assetBulkFileSaverProvider.overrideWithValue((name, bytes) async {
        saved.add((name, bytes));
        return '/tmp/$name';
      }),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(initialLocation: '/s', routes: [
        GoRoute(
          path: '/s',
          builder: (_, __) => Consumer(
            builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
                ? const SizedBox()
                : const AssetsSettingsScreen(),
          ),
        ),
      ]),
    ),
  ));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await settle(tester);
}

Future<void> pickFile(WidgetTester tester, ({String name, Uint8List bytes, int size}) f) async {
  nextFile = f;
  await tapKey(tester, 'bulk-pick');
}

String bannerText(WidgetTester tester, String key) =>
    tester.widgetList<Text>(find.descendant(of: byKey(key), matching: find.byType(Text))).map((t) => t.data).join();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules (web lib/assetImport.ts)', () {
    test('file checks: type, 5 MB, empty', () {
      expect(checkAssetImportFile('assets.csv', 10), isNull);
      expect(checkAssetImportFile('ASSETS.XLSX', 10), isNull);
      expect(checkAssetImportFile('assets.xls', 10), 'Upload a .csv or .xlsx file.');
      expect(checkAssetImportFile('assets.txt', 10), 'Upload a .csv or .xlsx file.');
      expect(checkAssetImportFile('assets.csv', 5 * 1024 * 1024), isNull);
      expect(checkAssetImportFile('assets.csv', 5 * 1024 * 1024 + 1), 'File must not exceed 5 MB.');
      expect(checkAssetImportFile('assets.csv', 0), 'The file is empty.');
    });

    test('row errors as web errorText', () {
      expect(
          assetImportErrorText([
            {'column': 'Branch', 'message': 'Unknown branch.'},
            {'column': '', 'message': 'Row skipped.'},
          ]),
          'Branch: Unknown branch. · Row skipped.');
      expect(assetImportErrorText(null), '');
    });

    test('template columns as the backend (required first in each list as web shows them)', () {
      expect([for (final c in kAssetImportColumns) if (c.$2) c.$1],
          ['Asset Tag', 'Asset Name', 'Category', 'Asset Type', 'Branch']);
      expect(kAssetImportColumns.length, 17);
      expect([for (final c in kAssetAssignColumns) if (c.$2) c.$1],
          ['Asset Tag', 'Employee ID', 'Assigned Date', 'Condition at Assignment']);
      expect([for (final c in kAssetAssignColumns) if (!c.$2) c.$1], ['Expected Return Date', 'Remarks']);
    });
  });

  group('entry points (web page actions)', () {
    testWidgets('Bulk Assign with assets.edit, Bulk Import with assets.create', (tester) async {
      await pump(tester);
      expect(byKey('asset-bulk-assign'), findsOneWidget);
      expect(byKey('asset-bulk-import'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, as: user(['settings.view', 'assets.view', 'assets.edit']));
      expect(byKey('asset-bulk-assign'), findsOneWidget);
      expect(byKey('asset-bulk-import'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, as: user(['settings.view', 'assets.view', 'assets.create']));
      expect(byKey('asset-bulk-assign'), findsNothing);
      expect(byKey('asset-bulk-import'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, as: user(['settings.view', 'assets.view', 'settings.edit']));
      expect(byKey('asset-bulk-assign'), findsNothing); // settings.edit is no substitute
      expect(byKey('asset-bulk-import'), findsNothing);
    });
  });

  group('Bulk Import', () {
    testWidgets('templates: web endpoints, file names, failure message', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-bulk-import');
      expect(find.text('Bulk Import Assets'), findsOneWidget);
      expect(find.textContaining('Asset Tag, Asset Name, Category, Asset Type, Branch.', findRichText: true), findsOneWidget);
      await tapKey(tester, 'bulk-sample-csv');
      await tapKey(tester, 'bulk-sample-xlsx');
      expect([for (final g in server.gets) if (g.$1 == '/assets/import/sample/') g.$2['format']], ['csv', 'xlsx']);
      expect(saved.map((s) => s.$1), ['asset_import_sample.csv', 'asset_import_sample.xlsx']);
      expect(utf8.decode(saved.first.$2), startsWith('Asset Tag'));
      server.sampleFails = true;
      await tapKey(tester, 'bulk-sample-csv');
      expect(find.text('Failed to download the sample.'), findsOneWidget);
    });

    testWidgets('file checks before any upload; Preview needs a file', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-bulk-import');
      expect(tester.widget<FilledButton>(byKey('bulk-preview')).onPressed, isNull);
      await pickFile(tester, file('assets.txt', [1, 2]));
      expect(find.text('Upload a .csv or .xlsx file.'), findsOneWidget);
      await pickFile(tester, file('big.xlsx', [1], size: 6 * 1024 * 1024));
      expect(find.text('File must not exceed 5 MB.'), findsOneWidget);
      await pickFile(tester, file('blank.csv', const []));
      expect(find.text('The file is empty.'), findsOneWidget);
      expect(tester.widget<FilledButton>(byKey('bulk-preview')).onPressed, isNull);
      expect(server.uploads, isEmpty);
      await pickFile(tester, file('assets.xlsx', [0x50, 0x4B, 3, 4]));
      expect(find.text('assets.xlsx'), findsOneWidget);
      expect(tester.widget<FilledButton>(byKey('bulk-preview')).onPressed, isNotNull);
    });

    testWidgets('preview (dry_run) → import (re-upload): exact multipart; partial success; report; refresh',
        (tester) async {
      await pump(tester);
      final listsBefore = server.lists();
      await tapKey(tester, 'asset-bulk-import');
      await pickFile(tester, file('assets.csv', csvBytes));
      await tapKey(tester, 'bulk-preview');
      final dry = server.uploadsTo('/assets/import/').single;
      expect(dry.fields, {'dry_run': 'true'});
      expect(dry.fileName, 'assets.csv');
      expect(dry.bytes, csvBytes);
      expect(bannerText(tester, 'bulk-preview-summary'),
          'Preview (nothing saved yet): 1 ready, 1 duplicate, 1 with errors. Only ready rows are imported.');
      expect(tester.widget<Text>(byKey('bulk-row-status-3')).data, 'Duplicate');
      expect(tester.widget<Text>(byKey('bulk-row-errors-4')).data, 'Branch: Unknown branch "XX".');
      // The error report is the server's CSV.
      await tapKey(tester, 'bulk-report');
      expect(saved.last.$1, 'asset_import_errors.csv');
      expect(utf8.decode(saved.last.$2), contains('LAP-001,duplicate,Asset Tag,Already exists'));
      expect(find.text('Import 1 asset(s)'), findsOneWidget);
      await tapKey(tester, 'bulk-send');
      final save = server.uploadsTo('/assets/import/').last;
      expect(save.fields, isEmpty); // no dry_run: saves
      expect(save.bytes, csvBytes);
      expect(bannerText(tester, 'bulk-result-summary'),
          'Import finished: 1 created, 1 duplicate, 1 failed, 0 skipped (of 3 rows).');
      expect(tester.widget<Text>(byKey('bulk-row-status-2')).data, 'Created');
      await tapKey(tester, 'bulk-done');
      expect(find.text('Bulk Import Assets'), findsNothing);
      expect(server.lists(), greaterThan(listsBefore));
    });

    testWidgets('nothing ready: Import disabled; Cancel back to the file step', (tester) async {
      await pump(tester);
      server.importPreview = {
        'rows': [importRow(2, 'LAP-001', 'duplicate')],
        'counts': {'ready': 0, 'duplicate': 1, 'error': 0},
        'error_report_csv': reportB64,
      };
      await tapKey(tester, 'asset-bulk-import');
      await pickFile(tester, file('assets.csv', csvBytes));
      await tapKey(tester, 'bulk-preview');
      expect(tester.widget<FilledButton>(byKey('bulk-send')).onPressed, isNull);
      await tapKey(tester, 'bulk-cancel');
      expect(byKey('bulk-pick'), findsOneWidget);
      expect(byKey('bulk-file-name'), findsNothing);
    });

    testWidgets('whole file refused (missing column / too many rows): the server message; nothing listed',
        (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-bulk-import');
      await pickFile(tester, file('assets.csv', csvBytes));
      server.refuseNext = (status: 400, message: 'Missing required column(s): Branch.');
      await tapKey(tester, 'bulk-preview');
      expect(find.text('Missing required column(s): Branch.'), findsOneWidget);
      expect(byKey('bulk-rows'), findsNothing);
      server.refuseNext = (status: 403, message: 'You do not have permission to create assets.');
      await tapKey(tester, 'bulk-preview');
      expect(find.text('You do not have permission to create assets.'), findsOneWidget);
      server.refuseNext = (status: 500, message: '');
      await tapKey(tester, 'bulk-preview');
      expect(find.text('Could not check the file.'), findsOneWidget);
    });

    testWidgets('one upload at a time; closing is blocked while it runs', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-bulk-import');
      await pickFile(tester, file('assets.csv', csvBytes));
      server.hold = Completer<void>();
      await tester.tap(byKey('bulk-preview'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Checking…'), findsOneWidget);
      await tester.tap(byKey('bulk-preview'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.widget<IconButton>(byKey('bulk-close')).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(byKey('bulk-pick')).onPressed, isNull);
      // The system back button doesn't close it mid-upload either.
      await tester.binding.handlePopRoute();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100)); // past any closing animation
      }
      expect(find.text('Bulk Import Assets'), findsOneWidget);
      server.hold!.complete();
      await settle(tester);
      expect(server.uploads, hasLength(1));
    });

    testWidgets('closed without importing: the list is not reloaded', (tester) async {
      await pump(tester);
      final before = server.lists();
      await tapKey(tester, 'asset-bulk-import');
      await tapKey(tester, 'bulk-cancel');
      expect(server.lists(), before);
    });
  });

  group('Bulk Assign', () {
    testWidgets('templates: the assignment endpoints and names', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-bulk-assign');
      expect(find.text('Bulk Assign Assets'), findsOneWidget);
      expect(find.textContaining('Asset Tag, Employee ID, Assigned Date, Condition at Assignment.', findRichText: true),
          findsOneWidget);
      await tapKey(tester, 'bulk-sample-xlsx');
      expect(server.gets.last.$1, '/assets/assignments/import/sample/');
      expect(server.gets.last.$2, {'format': 'xlsx'});
      expect(saved.single.$1, 'asset_assignment_sample.xlsx');
    });

    testWidgets('preview → explicit confirmation → assign; invalid employee / already assigned reported; refresh',
        (tester) async {
      await pump(tester);
      final listsBefore = server.lists();
      await tapKey(tester, 'asset-bulk-assign');
      await pickFile(tester, file('assign.xlsx', [0x50, 0x4B, 3, 4, 9]));
      await tapKey(tester, 'bulk-preview');
      final dry = server.uploadsTo('/assets/assignments/import/').single;
      expect(dry.fields, {'dry_run': 'true'});
      expect(dry.fileName, 'assign.xlsx');
      expect(dry.bytes, [0x50, 0x4B, 3, 4, 9]);
      expect(bannerText(tester, 'bulk-preview-summary'),
          'Preview (nothing assigned yet): 1 ready, 1 already assigned, 1 with errors. Only ready rows are assigned.');
      expect(find.text('Spare Laptop (LAP-002) → Asha Test (EMP-7)'), findsOneWidget);
      expect(find.text('LAP-009 → EMP-404'), findsOneWidget);
      expect(tester.widget<Text>(byKey('bulk-row-status-3')).data, 'Already assigned');
      expect(tester.widget<Text>(byKey('bulk-row-errors-4')).data,
          'Employee ID: No active employee with this ID in your scope.');
      // First tap only asks; nothing is sent.
      await tapKey(tester, 'bulk-send');
      expect(byKey('bulk-confirm-note'), findsOneWidget);
      expect(server.uploads, hasLength(1));
      await tapKey(tester, 'bulk-back');
      expect(byKey('bulk-confirm-note'), findsNothing);
      await tapKey(tester, 'bulk-send');
      expect(find.text('Yes, assign 1 asset(s)'), findsOneWidget);
      await tapKey(tester, 'bulk-send');
      final save = server.uploadsTo('/assets/assignments/import/').last;
      expect(save.fields, isEmpty);
      expect(save.bytes, [0x50, 0x4B, 3, 4, 9]);
      expect(bannerText(tester, 'bulk-result-summary'),
          'Finished: 1 assigned, 1 already assigned, 1 failed, 0 skipped (of 3 rows).');
      expect(byKey('bulk-report'), findsNothing); // the server sent no report
      await tapKey(tester, 'bulk-done');
      expect(server.lists(), greaterThan(listsBefore));
    });

    testWidgets('refused on confirm: message; back to the preview without the confirmation', (tester) async {
      await pump(tester);
      await tapKey(tester, 'asset-bulk-assign');
      await pickFile(tester, file('assign.csv', csvBytes));
      await tapKey(tester, 'bulk-preview');
      await tapKey(tester, 'bulk-send');
      server.refuseNext = (status: 403, message: 'You do not have permission to assign assets.');
      await tapKey(tester, 'bulk-send');
      expect(find.text('You do not have permission to assign assets.'), findsOneWidget);
      expect(byKey('bulk-confirm-note'), findsNothing);
      server.refuseNext = (status: 500, message: '');
      await tapKey(tester, 'bulk-send');
      await tapKey(tester, 'bulk-send');
      expect(find.text('Assignment failed.'), findsOneWidget);
    });

    testWidgets('import another file resets; nothing assigned → no reload on close', (tester) async {
      await pump(tester);
      server.assignResult = {
        'rows': [assignRow(2, 'LAP-001', 'EMP-8', 'already_assigned')],
        'summary': {'total': 1, 'assigned': 0, 'already_assigned': 1, 'failed': 0, 'skipped': 0},
        'error_report_csv': null,
      };
      final before = server.lists();
      await tapKey(tester, 'asset-bulk-assign');
      await pickFile(tester, file('assign.csv', csvBytes));
      await tapKey(tester, 'bulk-preview');
      await tapKey(tester, 'bulk-send');
      await tapKey(tester, 'bulk-send');
      await tapKey(tester, 'bulk-another');
      expect(byKey('bulk-pick'), findsOneWidget);
      await tapKey(tester, 'bulk-cancel');
      expect(server.lists(), before);
    });
  });
}
