import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/location/location_service.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/documents/presentation/widgets/document_file_picker.dart';
import 'package:mobile_app/features/wfh/data/datasources/wfh_remote_datasource.dart';
import 'package:mobile_app/features/wfh/data/models/wfh_models.dart';
import 'package:mobile_app/features/wfh/domain/entities/wfh_entity.dart';
import 'package:mobile_app/features/wfh/domain/repositories/wfh_repository.dart';
import 'package:mobile_app/features/wfh/presentation/providers/wfh_providers.dart';
import 'package:mobile_app/features/wfh/domain/entities/wfh_medical_proof.dart';
import 'package:mobile_app/features/wfh/presentation/widgets/request_wfh_tab.dart';
import 'package:mobile_app/features/wfh/presentation/widgets/wfh_request_detail_sheet.dart';

// Phase 1 C: "WFH for medical reasons" with a proof, per the production
// contract (WorkFromHomeRequestCreateSerializer: is_medical +
// supporting_document, PDF/JPEG/PNG by content type, at most 5 MB).

Map<String, dynamic> _request({bool medical = false, String? proofUrl}) => {
      'id': 'w1',
      'start_date': '2026-11-10',
      'end_date': '2026-11-11',
      'reason': 'Fever',
      'location_label': 'Home',
      'latitude': '17.385000',
      'longitude': '78.486700',
      'status': 'pending',
      'is_medical': medical,
      'supporting_document_url': proofUrl,
      'l1_approver_name': 'Manager M',
      'l1_status': 'pending',
    };

ResponseBody _json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class _Backend implements HttpClientAdapter {
  final posts = <Object?>[];

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'POST' && o.path == ApiConstants.wfhRequests) {
      posts.add(o.data);
      return _json(201, {
        'status': 'success',
        'message': 'ok',
        'data': _request(medical: true, proofUrl: 'https://x/p.pdf')
      });
    }
    if (o.path == ApiConstants.wfhSavedLocations) {
      return _json(200, {'status': 'success', 'data': []});
    }
    if (o.path.startsWith('/wfh/requests/w1')) {
      return _json(200, {
        'status': 'success',
        'data':
            _request(medical: true, proofUrl: 'https://cdn.example/proof.pdf')
      });
    }
    return _json(200, {
      'status': 'success',
      'message': 'ok',
      'data': {'count': 0, 'results': []}
    });
  }

  @override
  void close({bool force = false}) {}
}

class _Location extends LocationService {
  @override
  Future<Position?> getCurrentPosition() async => Position(
        latitude: 17.385,
        longitude: 78.4867,
        timestamp: DateTime(2026),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

class _NullSecureStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

DioException _refusal(String msg) => DioException(
      requestOptions: RequestOptions(path: ApiConstants.wfhRequests),
      type: DioExceptionType.badResponse,
      response: Response(
          requestOptions: RequestOptions(path: ApiConstants.wfhRequests),
          statusCode: 400,
          data: {'status': 'error', 'message': msg}),
    );

/// Records what the form hands to the repository; never touches the network.
class _FakeRepo implements WfhRepository {
  _FakeRepo(this.createError);
  final Object? createError;
  final creates = <({bool isMedical, WfhMedicalProof? proof})>[];

  @override
  Future<WfhRequestEntity> createWfhRequest({
    required String startDate,
    required String endDate,
    String? reason,
    String? locationLabel,
    required double latitude,
    required double longitude,
    bool isMedical = false,
    WfhMedicalProof? medicalProof,
  }) async {
    creates.add((isMedical: isMedical, proof: medicalProof));
    if (createError != null) throw createError!;
    return WfhRequestModel.fromJson(_request(medical: isMedical));
  }

  @override
  Future<List<WfhRequestEntity>> getWfhRequests({String? status}) async =>
      const [];

  @override
  Future<List<WfhSavedLocationEntity>> getSavedLocations() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late Directory _tmp;
File _file(String name, int bytes) =>
    File('${_tmp.path}/$name')..writeAsBytesSync(List.filled(bytes, 1));

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    _tmp = Directory.systemTemp.createTempSync('wfh_proof_test');
  });
  tearDownAll(() => _tmp.deleteSync(recursive: true));

  group('proof rules (web wfhMedicalProofError + backend serializer)', () {
    test('content type comes only from the allowlist, case-insensitively', () {
      expect(wfhProofMimeType('report.pdf'), 'application/pdf');
      expect(wfhProofMimeType('scan.JPG'), 'image/jpeg');
      expect(wfhProofMimeType('scan.jpeg'), 'image/jpeg');
      expect(wfhProofMimeType('photo.png'), 'image/png');
      for (final bad in ['notes.docx', 'image.heic', 'noext', 'trailing.']) {
        expect(wfhProofMimeType(bad), isNull, reason: bad);
      }
    });

    test(
        'non-medical needs nothing; medical needs a PDF/JPG/PNG of at most 5 MB',
        () {
      expect(wfhMedicalProofError(isMedical: false), isNull);
      expect(wfhMedicalProofError(isMedical: true), kWfhProofRequired);
      WfhMedicalProof p(String n, int size) =>
          WfhMedicalProof(path: '/tmp/$n', filename: n, sizeBytes: size);
      expect(wfhMedicalProofError(isMedical: true, proof: p('a.docx', 10)),
          kWfhProofWrongType);
      expect(
          wfhMedicalProofError(
              isMedical: true, proof: p('a.pdf', kWfhProofMaxBytes + 1)),
          kWfhProofTooLarge);
      expect(
          wfhMedicalProofError(
              isMedical: true, proof: p('a.pdf', kWfhProofMaxBytes)),
          isNull);
    });

    test(
        'is_medical and supporting_document_url are parsed; blank url means none',
        () {
      final m = WfhRequestModel.fromJson(
          _request(medical: true, proofUrl: 'https://x/p.pdf'));
      expect(m.isMedical, isTrue);
      expect(m.supportingDocumentUrl, 'https://x/p.pdf');
      expect(
          WfhRequestModel.fromJson(_request(proofUrl: ''))
              .supportingDocumentUrl,
          isNull);
      expect(WfhRequestModel.fromJson(_request()).isMedical, isFalse);
    });
  });

  group('request sent (WfhRemoteDataSource.createWfhRequest)', () {
    WfhRemoteDataSource ds(_Backend b) => WfhRemoteDataSource(
        Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
          ..httpClientAdapter = b);

    test(
        'medical: multipart with is_medical=true and the proof typed from its extension',
        () async {
      final b = _Backend();
      final f = _file('Prescription.PDF', 2048);
      await ds(b).createWfhRequest(
        startDate: '2026-11-10',
        endDate: '2026-11-11',
        reason: 'Fever',
        locationLabel: 'Home',
        latitude: 17.385,
        longitude: 78.4867,
        isMedical: true,
        medicalProof: WfhMedicalProof(
            path: f.path, filename: 'Prescription.PDF', sizeBytes: 2048),
      );
      final form = b.posts.single as FormData;
      final fields = Map.fromEntries(form.fields);
      expect(fields['is_medical'], 'true');
      expect(fields['start_date'], '2026-11-10');
      expect(fields['end_date'], '2026-11-11');
      expect(fields['reason'], 'Fever');
      expect(fields['location_label'], 'Home');
      expect(fields['latitude'], '17.385');
      final file = form.files.single;
      expect(file.key, 'supporting_document');
      expect(file.value.filename, 'Prescription.PDF');
      expect(file.value.contentType.toString(), 'application/pdf');
    });

    test('non-medical: the unchanged JSON body, no is_medical, no file',
        () async {
      final b = _Backend();
      await ds(b).createWfhRequest(
          startDate: '2026-11-10',
          endDate: '2026-11-11',
          reason: '',
          latitude: 17.385,
          longitude: 78.4867);
      expect(b.posts.single, {
        'start_date': '2026-11-10',
        'end_date': '2026-11-11',
        'latitude': 17.385,
        'longitude': 78.4867,
      });
    });
  });

  group('request form', () {
    late _FakeRepo repo;
    late PlatformFile? nextPick;

    Future<void> pumpForm(WidgetTester tester, {Object? createError}) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo = _FakeRepo(createError);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          wfhRepositoryProvider.overrideWithValue(repo),
          locationServiceProvider.overrideWithValue(_Location()),
          wfhProofPickerProvider.overrideWithValue(() async => nextPick),
        ],
        child: const MaterialApp(home: Scaffold(body: RequestWfhTab())),
      ));
      await tester.pumpAndSettle();
      // Dates: today for both (the picker opens on today), then GPS.
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Select').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Use current location'));
      await tester.pumpAndSettle();
    }

    Future<void> tickMedical(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('wfh-medical')));
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester) async {
      await tester.tap(find.byType(DocumentFilePicker));
      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
    }

    testWidgets('medical without proof is blocked before any request',
        (tester) async {
      nextPick = null;
      await pumpForm(tester);
      await tickMedical(tester);
      expect(
          find.text('Medical proof (report or prescription)'), findsOneWidget);
      await submit(tester);
      expect(repo.creates, isEmpty);
      expect(find.text(kWfhProofRequired), findsOneWidget);
    });

    testWidgets(
        'a wrong file type or a file over 5 MB is rejected at pick time',
        (tester) async {
      await pumpForm(tester);
      await tickMedical(tester);

      nextPick =
          PlatformFile(name: 'notes.docx', size: 100, path: '/tmp/notes.docx');
      await pick(tester);
      expect(find.text(kWfhProofWrongType), findsOneWidget);

      nextPick = PlatformFile(
          name: 'scan.pdf', size: kWfhProofMaxBytes + 1, path: '/tmp/scan.pdf');
      await pick(tester);
      expect(find.text(kWfhProofTooLarge), findsOneWidget);

      await submit(tester);
      expect(repo.creates, isEmpty);
    });

    testWidgets(
        'medical with a valid proof is submitted as a medical request with that file',
        (tester) async {
      nextPick =
          PlatformFile(name: 'report.png', size: 4096, path: '/tmp/report.png');
      await pumpForm(tester);
      await tickMedical(tester);
      await pick(tester);
      expect(find.text('report.png'), findsOneWidget);
      await submit(tester);
      final call = repo.creates.single;
      expect(call.isMedical, isTrue);
      expect(call.proof?.filename, 'report.png');
      expect(call.proof?.path, '/tmp/report.png');
      expect(find.text('Request Submitted!'), findsOneWidget);
    });

    testWidgets("the server's validation message is shown", (tester) async {
      const msg =
          'WFH for medical reasons needs a medical proof, report or prescription.';
      nextPick = PlatformFile(name: 'r.pdf', size: 1024, path: '/tmp/r.pdf');
      await pumpForm(tester, createError: _refusal(msg));
      await tickMedical(tester);
      await pick(tester);
      await submit(tester);
      expect(find.text(msg), findsOneWidget);
      expect(find.text('Request Submitted!'), findsNothing);
    });

    testWidgets('unticking medical drops the proof and sends a normal request',
        (tester) async {
      nextPick = PlatformFile(name: 'x.pdf', size: 512, path: '/tmp/x.pdf');
      await pumpForm(tester);
      await tickMedical(tester);
      await pick(tester);
      await tickMedical(tester);
      await submit(tester);
      final call = repo.creates.single;
      expect(call.isMedical, isFalse);
      expect(call.proof, isNull);
    });
  });

  group('request details', () {
    Future<void> openSheet(
        WidgetTester tester, Map<String, dynamic> json) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final initial = WfhRequestModel.fromJson(json);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(
              Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
                ..httpClientAdapter = _Backend()),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullSecureStorage()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showWfhRequestDetailSheet(context, initial: initial),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a medical request shows the Medical proof link',
        (tester) async {
      await openSheet(tester,
          _request(medical: true, proofUrl: 'https://cdn.example/proof.pdf'));
      expect(find.text('WFH for medical reasons'), findsOneWidget);
      expect(find.byKey(const Key('wfh-medical-proof-link')), findsOneWidget);
    });

    testWidgets('a normal request shows no proof link', (tester) async {
      final json = _request();
      json['id'] = 'w2';
      await openSheet(tester, json);
      expect(find.byKey(const Key('wfh-medical-proof-link')), findsNothing);
      expect(find.text('WFH for medical reasons'), findsNothing);
    });
  });
}
