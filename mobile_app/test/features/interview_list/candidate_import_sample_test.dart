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
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/interview_list/data/datasources/interview_datasource.dart';
import 'package:mobile_app/features/interview_list/presentation/providers/interview_providers.dart';
import 'package:mobile_app/features/interview_list/presentation/screens/candidate_bulk_import_screen.dart';

// Task 19 (audit A-I7): web CandidateBulkImportModal "Sample CSV" / "Sample
// XLSX" → GET /recruitment/candidates/bulk-import/sample/?format=csv|xlsx,
// saved as candidate_import_sample.<format>. The SERVER builds the file
// (CandidateBulkImportSampleView, recruitment.view; build_sample_csv = UTF-8
// BOM + csv.writer CRLF rows; build_sample_xlsx). Mobile downloads and saves
// those exact bytes. Stand-in server and a stand-in "save as" — nothing is
// imported or written anywhere.

/// Byte-for-byte what build_sample_csv returns for the view's _HEADERS and
/// _SAMPLE_ROWS.
final kBackendCsv = utf8.encode('\ufeff'
    'Candidate Name,Email,Mobile Number,Position Applied,Branch,Interview Date,Interview Mode,Notes\r\n'
    'Rahul Sharma,rahul.sharma@email.com,9876543210,Software Engineer,Mumbai HQ,2026-07-25,In-Person,\r\n'
    'Priya Patel,priya.patel@email.com,9123456789,Product Manager,Delhi Branch,2026-07-26,Video Call,Strong candidate\r\n');

/// An XLSX is a zip ("PK\x03\x04…"); the content is whatever the server built.
final kBackendXlsx = <int>[0x50, 0x4B, 0x03, 0x04, 1, 2, 3, 4, 5, 6, 7, 8];

class Server implements HttpClientAdapter {
  final calls = <Map<String, dynamic>>[];
  int status = 200;
  Completer<void>? hold;
  bool importCalled = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == ApiConstants.candidateBulkImportSample && o.method == 'GET') {
      calls.add(Map<String, dynamic>.from(o.queryParameters));
      final gate = hold;
      if (gate != null) await gate.future;
      if (status != 200) {
        return ResponseBody.fromString(
            jsonEncode({
              'status': 'error',
              'message': 'You do not have permission to download the candidate import template.',
              'data': {},
            }),
            status,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            });
      }
      final xlsx = o.queryParameters['format'] == 'xlsx';
      return ResponseBody.fromBytes(xlsx ? kBackendXlsx : kBackendCsv, 200, headers: {
        Headers.contentTypeHeader: [
          xlsx ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' : 'text/csv; charset=utf-8'
        ],
        'content-disposition': ['attachment; filename="candidate_import_sample.${xlsx ? 'xlsx' : 'csv'}"'],
      });
    }
    if (o.path == ApiConstants.candidateBulkImport) importCalled = true;
    return ResponseBody.fromString(jsonEncode({'status': 'success', 'data': {}}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
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
  @override
  Future<AuthState> build() async => const AuthState(
      user: UserEntity(
          id: 'u1',
          email: 'hr@example.test',
          fullName: 'Test HR',
          role: 'hr',
          roleDisplay: 'HR',
          mustChangePassword: false,
          permissions: ['recruitment.view', 'recruitment.create'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete'));
}

late Server server;
final saved = <({String name, Uint8List bytes})>[];
String? saverResult = '/picked/location';
Object? saverThrows;

Future<void> pumpScreen(WidgetTester tester, {Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  saved.clear();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      candidateSampleSaverProvider.overrideWithValue((name, bytes) async {
        if (saverThrows != null) throw saverThrows!;
        saved.add((name: name, bytes: bytes));
        return saverResult;
      }),
    ],
    child: const MaterialApp(home: CandidateBulkImportScreen()),
  ));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    saverResult = '/picked/location';
    saverThrows = null;
  });

  group('datasource (server-built file)', () {
    test('the endpoint is web\'s API.recruitment.bulkImportSample', () {
      expect(ApiConstants.candidateBulkImportSample, '/recruitment/candidates/bulk-import/sample/');
    });

    test('asks ?format=csv|xlsx and returns the bytes untouched', () async {
      final s = Server();
      final ds = InterviewDataSource(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s);
      expect(await ds.fetchBulkImportSample('csv'), kBackendCsv);
      expect(await ds.fetchBulkImportSample('xlsx'), kBackendXlsx);
      expect(s.calls, [
        {'format': 'csv'},
        {'format': 'xlsx'},
      ]);
    });

    test('the sample\'s columns are the ones the importer maps (required + optional)', () {
      expect(kBackendCsv.take(3), [0xEF, 0xBB, 0xBF], reason: 'UTF-8 BOM for Excel');
      final text = utf8.decode(kBackendCsv.skip(3).toList());
      final header = text.split('\r\n').first.split(',');
      expect(header, [
        'Candidate Name', 'Email', 'Mobile Number', 'Position Applied', //
        'Branch', 'Interview Date', 'Interview Mode', 'Notes',
      ]);
      // _IMPORT_COL_MAP: required name/email/position_applied/branch_name;
      // optional phone/interview_date/interview_mode/notes.
      const map = {
        'candidate name': 'name', 'email': 'email', 'mobile number': 'phone',
        'position applied': 'position_applied', 'branch': 'branch_name',
        'interview date': 'interview_date', 'interview mode': 'interview_mode', 'notes': 'notes',
      };
      expect(header.map((h) => map[h.toLowerCase()]), [
        'name', 'email', 'phone', 'position_applied', 'branch_name', 'interview_date', 'interview_mode', 'notes',
      ]);
      final rows = text.split('\r\n').where((l) => l.isNotEmpty).skip(1).toList();
      expect(rows, hasLength(2));
      expect(rows.first.split(',')[5], '2026-07-25', reason: 'dates as YYYY-MM-DD');
    });

    test('a refusal (bytes) is decoded into the server\'s message', () async {
      final s = Server()..status = 403;
      final ds = InterviewDataSource(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s);
      await expectLater(
        ds.fetchBulkImportSample('csv'),
        throwsA(isA<DioException>().having((e) => (e.response?.data as Map)['message'], 'message',
            'You do not have permission to download the candidate import template.')),
      );
    });
  });

  group('screen', () {
    testWidgets('Sample CSV / Sample XLSX are offered on the bulk-import screen', (tester) async {
      await pumpScreen(tester);
      expect(find.text('Sample CSV'), findsOneWidget);
      expect(find.text('Sample XLSX'), findsOneWidget);
      expect(server.calls, isEmpty, reason: 'nothing downloads until tapped');
    });

    for (final format in ['csv', 'xlsx']) {
      testWidgets('$format: saved as candidate_import_sample.$format with the server\'s exact bytes', (tester) async {
        await pumpScreen(tester);
        await tester.tap(byKey('candidate-sample-$format'));
        await tester.pumpAndSettle();
        expect(server.calls, [
          {'format': format}
        ]);
        expect(saved.single.name, 'candidate_import_sample.$format');
        expect(saved.single.bytes, format == 'csv' ? kBackendCsv : kBackendXlsx);
        expect(find.text('Sample downloaded.'), findsOneWidget);
        expect(server.importCalled, isFalse, reason: 'no import is triggered');
      });
    }

    testWidgets('cancelling the save dialog shows nothing (no error, no success)', (tester) async {
      saverResult = null;
      await pumpScreen(tester);
      await tester.tap(byKey('candidate-sample-csv'));
      await tester.pumpAndSettle();
      expect(find.text('Sample downloaded.'), findsNothing);
      expect(byKey('candidate-sample-error'), findsNothing);
    });

    testWidgets('a server refusal is shown under the buttons; they work again', (tester) async {
      final s = Server()..status = 403;
      await pumpScreen(tester, with_: s);
      await tester.tap(byKey('candidate-sample-xlsx'));
      await tester.pumpAndSettle();
      expect(find.text('You do not have permission to download the candidate import template.'), findsOneWidget);
      expect(saved, isEmpty);
      expect(tester.widget<ButtonStyleButton>(byKey('candidate-sample-csv')).onPressed, isNotNull);
      // a retry that succeeds clears the error
      s.status = 200;
      await tester.tap(byKey('candidate-sample-xlsx'));
      await tester.pumpAndSettle();
      expect(byKey('candidate-sample-error'), findsNothing);
      expect(saved, hasLength(1));
    });

    testWidgets('a failure while saving is reported too', (tester) async {
      saverThrows = Exception('Could not save the file.');
      await pumpScreen(tester);
      await tester.tap(byKey('candidate-sample-csv'));
      await tester.pumpAndSettle();
      expect(find.text('Could not save the file.'), findsOneWidget);
    });

    testWidgets('while downloading: "Downloading…", both buttons disabled, extra taps send nothing', (tester) async {
      final s = Server()..hold = Completer();
      await pumpScreen(tester, with_: s);
      await tester.tap(byKey('candidate-sample-csv'));
      await tester.pump();
      expect(find.text('Downloading…'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(byKey('candidate-sample-csv')).onPressed, isNull);
      expect(tester.widget<ButtonStyleButton>(byKey('candidate-sample-xlsx')).onPressed, isNull);
      await tester.tap(byKey('candidate-sample-csv'), warnIfMissed: false);
      await tester.tap(byKey('candidate-sample-xlsx'), warnIfMissed: false);
      await tester.pump();
      s.hold!.complete();
      await tester.pumpAndSettle();
      expect(s.calls, hasLength(1));
      expect(saved, hasLength(1));
      expect(find.text('Sample CSV'), findsOneWidget);
    });

    testWidgets('the Import button is unchanged (disabled until a file is picked)', (tester) async {
      await pumpScreen(tester);
      final importButton = find.ancestor(of: find.text('Import'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
      expect(tester.widget<ButtonStyleButton>(importButton).onPressed, isNull, reason: 'no file picked yet');
    });
  });
}
