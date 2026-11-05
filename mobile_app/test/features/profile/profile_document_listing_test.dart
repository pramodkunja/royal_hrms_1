import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/profile/data/models/profile_document_model.dart';
import 'package:mobile_app/features/profile/data/models/profile_document_rows.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/features/settings/data/models/onboarding_field_config_model.dart';

// Phase 11.4 step 2: the merged Documents listing and the upload controller.
// Synthetic data only; a stand-in for the production endpoints.

DocumentTypeConfigModel type(String key, String label,
        {int order = 0, bool visible = true, bool required = false, bool multiple = false}) =>
    DocumentTypeConfigModel(
      typeKey: key,
      label: label,
      order: order,
      visible: visible,
      required: required,
      allowMultiple: multiple,
      isCustom: false,
      isLocked: false,
    );

ProfileDocumentModel doc(int id, String type, String uploadedAt, {String display = ''}) => ProfileDocumentModel(
      id: id,
      documentType: type,
      documentTypeDisplay: display,
      fileUrl: 'https://test.invalid/api/onboarding/documents/$id/',
      fileName: 'file$id.pdf',
      fileSize: 1000,
      uploadedAt: uploadedAt,
    );

Map<String, dynamic> docJson(int id, String type, String at) => {
      'id': id,
      'document_type': type,
      'document_type_display': type,
      'file_url': 'https://test.invalid/api/onboarding/documents/$id/',
      'file_name': 'file$id.pdf',
      'file_size': 1000,
      'uploaded_at': at,
    };

Map<String, dynamic> typeJson(String key, String label, int order, {bool multiple = false, bool visible = true}) =>
    {'type_key': key, 'label': label, 'order': order, 'visible': visible, 'required': true, 'allow_multiple': multiple};

void main() {
  group('buildProfileDocumentListing', () {
    test('one row per visible configured type, in admin order, uploaded or not', () {
      final l = buildProfileDocumentListing([
        type('b', 'Bravo', order: 2),
        type('hidden', 'Hidden', order: 0, visible: false),
        type('a', 'Alpha', order: 1, required: true),
        type('c', 'Charlie', order: 2),
      ], [
        doc(1, 'a', '2026-10-01T00:00:00Z')
      ]);
      expect(l.usingDefaultTypes, isFalse);
      expect(l.rows.map((r) => r.documentType), ['a', 'b', 'c']); // ties keep config order
      expect(l.rows[0].label, 'Alpha');
      expect(l.rows[0].required, isTrue);
      expect(l.rows[0].uploaded, isTrue);
      expect(l.rows[1].uploaded, isFalse);
      expect(l.rows.every((r) => r.canUpload), isTrue);
    });

    test("no configuration → web's built-in list", () {
      final l = buildProfileDocumentListing(const [], const []);
      expect(l.usingDefaultTypes, isTrue);
      expect(l.rows.map((r) => r.documentType), [
        'pan_card',
        'aadhaar_card',
        'degree_certificate',
        'experience_letter',
        'passport_photo',
        'cancelled_cheque',
      ]);
      expect(l.rows.map((r) => r.required), [true, true, false, false, true, true]);
      expect(l.rows.any((r) => r.allowMultiple), isFalse);
    });

    test('only hidden types configured → built-in list too', () {
      expect(buildProfileDocumentListing([type('x', 'X', visible: false)], const []).usingDefaultTypes, isTrue);
    });

    test('single-file type shows the newest upload; replacing it needs confirmation', () {
      final l = buildProfileDocumentListing([
        type('a', 'A')
      ], [
        doc(1, 'a', '2026-01-01T00:00:00Z'),
        doc(2, 'a', '2026-03-01T00:00:00Z'),
      ]);
      final row = l.rows.single;
      expect(row.files.map((f) => f.id), [2]);
      expect(row.latest!.id, 2);
      expect(row.replaceNeedsConfirmation, isTrue);
    });

    test('allow_multiple type lists every upload, newest first, and adds without confirmation', () {
      final l = buildProfileDocumentListing([
        type('m', 'Many', multiple: true)
      ], [
        doc(1, 'm', '2026-01-01T00:00:00Z'),
        doc(3, 'm', '2026-05-01T00:00:00Z'),
        doc(2, 'm', '2026-03-01T00:00:00Z'),
      ]);
      final row = l.rows.single;
      expect(row.files.map((f) => f.id), [3, 2, 1]);
      expect(row.replaceNeedsConfirmation, isFalse);
    });

    test('a type with nothing uploaded needs no confirmation', () {
      expect(buildProfileDocumentListing([type('a', 'A')], const []).rows.single.replaceNeedsConfirmation, isFalse);
    });

    test('uploads of a type no longer offered stay visible, read-only', () {
      final l = buildProfileDocumentListing([
        type('a', 'A'),
        type('old', 'Old', visible: false),
      ], [
        doc(1, 'old', '2026-01-01T00:00:00Z', display: 'Old Certificate'),
        doc(2, 'gone', '2026-02-01T00:00:00Z'),
        doc(3, 'old', '2026-04-01T00:00:00Z', display: 'Old Certificate'),
      ]);
      expect(l.rows.map((r) => r.documentType), ['a', 'old', 'gone']);
      final old = l.rows[1];
      expect(old.label, 'Old Certificate');
      expect(old.canUpload, isFalse);
      expect(old.files.map((f) => f.id), [3, 1]);
      expect(l.rows[2].label, 'gone');
      expect(l.rows[2].canUpload, isFalse);
    });

    test('every uploaded file appears exactly once or under its single-file row', () {
      final docs = [
        doc(1, 'pan_card', '2026-01-01T00:00:00Z'),
        doc(2, 'extra', '2026-01-02T00:00:00Z'),
        doc(3, 'extra', ''),
      ];
      final l = buildProfileDocumentListing(const [], docs);
      final shown = l.rows.expand((r) => r.files).map((f) => f.id).toList();
      expect(shown, unorderedEquals([1, 2, 3]));
      expect(l.rows.last.files.map((f) => f.id), [2, 3]); // undated after dated
    });

    test('a blank label falls back to the type key', () {
      expect(buildProfileDocumentListing([type('k', '  ')], const []).rows.single.label, 'k');
    });
  });

  group('providers', () {
    late _Server server;
    late ProviderContainer container;

    ProviderContainer make({
      Map<String, dynamic>? profile,
      Object? types,
      List<Map<String, dynamic>>? docs,
      bool holdProfile = false,
    }) {
      server = _Server(
        profile: profile ?? {'id': 'u1', 'employee_id': 'EMP-T1', 'full_name': 'Test User', 'profile': {}},
        types: types ?? [typeJson('pan_card', 'PAN Card', 1), typeJson('certs', 'Certificates', 2, multiple: true)],
        docs: docs ?? [docJson(41, 'pan_card', '2026-10-01T00:00:00Z')],
      );
      if (holdProfile) server.profileHold = Completer<void>();
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server;
      container = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
      addTearDown(container.dispose);
      container.listen(profileDocumentListingProvider, (_, __) {});
      container.listen(profileDocumentUploadProvider, (_, __) {});
      container.listen(myProfileProvider, (_, __) {});
      return container;
    }

    ProfileUploadFile pdf([String name = 'scan.pdf']) => ProfileUploadFile(name: name, bytes: Uint8List(8));

    Future<ProfileDocumentRow> row(String type) async =>
        (await container.read(profileDocumentListingProvider.future)).rows.firstWhere((r) => r.documentType == type);

    test('listing merges the configured types with the uploads', () async {
      make();
      final l = await container.read(profileDocumentListingProvider.future);
      expect(l.rows.map((r) => r.documentType), ['pan_card', 'certs']);
      expect(l.rows[0].latest!.id, 41);
      expect(l.rows[1].uploaded, isFalse);
      expect(server.paths, containsAll(['/onboarding/documents/', '/onboarding/document-type-config/']));
    });

    test('a failed type configuration falls back to the built-in list; uploads still show', () async {
      make(types: 500);
      final l = await container.read(profileDocumentListingProvider.future);
      expect(l.usingDefaultTypes, isTrue);
      expect(l.rows.first.documentType, 'pan_card');
      expect(l.rows.first.latest!.id, 41);
    });

    test('a failed document list is the section error', () async {
      make();
      server.docsStatus = 500;
      await expectLater(container.read(profileDocumentListingProvider.future), throwsA(anything));
    });

    test('upload goes to the own employee code, then the list reloads with the new file', () async {
      make();
      await container.read(myProfileProvider.future);
      final pan = await row('pan_card');
      expect(pan.replaceNeedsConfirmation, isTrue);
      final listsBefore = server.count('GET /onboarding/documents/');

      final out = await container.read(profileDocumentUploadProvider.notifier).upload(pan, pdf());
      expect(out, isA<DocumentUploadSucceeded>());
      expect(server.uploads.single.path, '/employees/EMP-T1/documents/');
      expect(server.uploads.single.body, contains('pan_card'));

      final after = await row('pan_card');
      expect(server.count('GET /onboarding/documents/'), listsBefore + 1);
      expect(after.latest!.id, 99); // the server replaced the old file
      expect(after.files, hasLength(1));
      expect(container.read(profileDocumentUploadProvider), isEmpty);
    });

    test('an allow_multiple upload adds a file and both are listed', () async {
      make(docs: [docJson(50, 'certs', '2026-01-01T00:00:00Z')]);
      await container.read(myProfileProvider.future);
      final certs = await row('certs');
      expect(certs.replaceNeedsConfirmation, isFalse);
      await container.read(profileDocumentUploadProvider.notifier).upload(certs, pdf());
      expect((await row('certs')).files.map((f) => f.id), [99, 50]);
    });

    test('a refused upload is a failure with the server message; the list is unchanged', () async {
      make();
      await container.read(myProfileProvider.future);
      server.uploadStatus = 400;
      server.uploadMessage = 'Invalid document type.';
      final listsBefore = server.count('GET /onboarding/documents/');
      final out = await container.read(profileDocumentUploadProvider.notifier).upload(await row('pan_card'), pdf());
      expect(out, isA<DocumentUploadFailed>());
      expect((out as DocumentUploadFailed).message, 'Invalid document type.');
      expect(server.count('GET /onboarding/documents/'), listsBefore);
      expect((await row('pan_card')).latest!.id, 41);
      expect(container.read(profileDocumentUploadProvider), isEmpty);
    });

    test('a file the backend would refuse fails without a request', () async {
      make();
      await container.read(myProfileProvider.future);
      final out =
          await container.read(profileDocumentUploadProvider.notifier).upload(await row('pan_card'), pdf('a.docx'));
      expect((out as DocumentUploadFailed).message, 'Only PDF, JPG, and PNG files are allowed.');
      expect(server.uploads, isEmpty);
    });

    test('a second upload for the same type while one is running sends nothing', () async {
      make();
      await container.read(myProfileProvider.future);
      final pan = await row('pan_card');
      final gate = server.hold = Completer<void>();
      final notifier = container.read(profileDocumentUploadProvider.notifier);
      final first = notifier.upload(pan, pdf());
      await Future<void>.delayed(Duration.zero);
      expect(container.read(profileDocumentUploadProvider), {'pan_card'});
      expect(await notifier.upload(pan, pdf()), isA<DocumentUploadIgnored>());
      // A different type is not blocked.
      final other = notifier.upload(await row('certs'), pdf());
      gate.complete();
      expect(await first, isA<DocumentUploadSucceeded>());
      expect(await other, isA<DocumentUploadSucceeded>());
      expect(server.uploads, hasLength(2));
      expect(container.read(profileDocumentUploadProvider), isEmpty);
    });

    test('read-only rows and a missing employee code send nothing', () async {
      make(profile: {'id': 'u1', 'employee_id': '', 'full_name': 'Test User', 'profile': {}});
      await container.read(myProfileProvider.future);
      final notifier = container.read(profileDocumentUploadProvider.notifier);
      expect(await notifier.upload(await row('pan_card'), pdf()), isA<DocumentUploadFailed>());
      const readOnly = ProfileDocumentRow(
          documentType: 'old', label: 'Old', required: false, allowMultiple: true, canUpload: false, files: []);
      expect(await notifier.upload(readOnly, pdf()), isA<DocumentUploadFailed>());
      expect(server.uploads, isEmpty);
    });

    test('before the profile has loaded nothing is sent', () async {
      make(holdProfile: true);
      final out = await container.read(profileDocumentUploadProvider.notifier).upload(await row('pan_card'), pdf());
      expect(container.read(myProfileProvider).valueOrNull, isNull);
      expect(out, isA<DocumentUploadFailed>());
      expect((out as DocumentUploadFailed).message, 'Your profile is still loading. Please try again.');
      expect(server.uploads, isEmpty);
      server.profileHold!.complete();
    });
  });
}

class _Upload {
  _Upload(this.path, this.body);
  final String path;
  final String body;
}

class _Server implements HttpClientAdapter {
  _Server({required this.profile, required this.types, required List<Map<String, dynamic>> docs}) : docs = [...docs];

  final Map<String, dynamic> profile;
  final Object types; // a list, or an error status
  final List<Map<String, dynamic>> docs;
  int docsStatus = 200;
  int uploadStatus = 201;
  String uploadMessage = 'Document uploaded.';
  Completer<void>? hold;
  Completer<void>? profileHold;
  final calls = <String>[];
  final uploads = <_Upload>[];
  int _nextId = 99;

  List<String> get paths => calls.map((c) => c.split(' ').last).toList();
  int count(String call) => calls.where((c) => c == call).length;

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? _) async {
    calls.add('${o.method} ${o.path}');
    if (o.method == 'GET' && o.path == '/employees/me/') {
      final gate = profileHold;
      if (gate != null) await gate.future;
      return _json(200, {'status': 'success', 'message': 'ok', 'data': profile});
    }
    if (o.method == 'GET' && o.path == '/onboarding/document-type-config/') {
      if (types is int) return _json(types as int, {'status': 'error', 'message': 'Server error.', 'data': {}});
      return _json(200, {'status': 'success', 'message': 'ok', 'data': types});
    }
    if (o.method == 'GET' && o.path == '/onboarding/documents/') {
      if (docsStatus != 200) return _json(docsStatus, {'status': 'error', 'message': 'Server error.', 'data': {}});
      return _json(200, {'status': 'success', 'message': 'ok', 'data': docs});
    }
    if (o.method == 'POST' && o.path.startsWith('/employees/') && o.path.endsWith('/documents/')) {
      final bytes = <int>[];
      if (body != null) {
        await for (final c in body) {
          bytes.addAll(c);
        }
      }
      final text = latin1.decode(bytes);
      uploads.add(_Upload(o.path, text));
      final gate = hold;
      if (gate != null) await gate.future;
      if (uploadStatus >= 400) return _json(uploadStatus, {'status': 'error', 'message': uploadMessage, 'data': {}});
      final type = RegExp(r'name="document_type"\r\n\r\n([^\r]+)').firstMatch(text)!.group(1)!;
      final multiple =
          types is List && (types as List).any((t) => t['type_key'] == type && t['allow_multiple'] == true);
      if (!multiple) docs.removeWhere((d) => d['document_type'] == type); // the backend's replace
      final created = docJson(_nextId++, type, '2026-11-05T09:00:00Z');
      docs.add(created);
      return _json(201, {'status': 'success', 'message': uploadMessage, 'data': created});
    }
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}
