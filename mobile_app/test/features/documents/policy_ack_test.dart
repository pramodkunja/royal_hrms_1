import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/documents/data/datasources/document_remote_datasource.dart';
import 'package:mobile_app/features/documents/data/models/document_model.dart';
import 'package:mobile_app/features/documents/data/models/policy_ack_models.dart';
import 'package:mobile_app/features/documents/presentation/widgets/document_detail_dialog.dart';
import 'package:mobile_app/features/documents/presentation/widgets/document_upload_dialog.dart';
import 'package:mobile_app/features/documents/presentation/widgets/pending_acknowledgements.dart';

// Phase 7: Company Policy acknowledgement against a stand-in for the
// production API (apps/accounts/views_policy.py + DocumentDetailView):
// pending list, acknowledge {version} (409 on a stale version, 201/200),
// the documents.edit report and requirement toggle, and the upload flag.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object? data, [int status = 200, String message = 'ok']) =>
    _json(status, {'status': 'success', 'message': message, 'data': data});
ResponseBody _fail(int status, String message) => _json(status, {'status': 'error', 'message': message, 'data': {}});

Map<String, dynamic> docJson(int id, String title,
        {bool requires = true, int version = 2, String? ackAt, String category = 'policy'}) =>
    {
      'id': id,
      'title': title,
      'description': 'Read before your first day.',
      'category': category,
      'category_display': 'Policy',
      'file_url': 'https://files.invalid/$id.pdf',
      'file_name': '$id.pdf',
      'file_type': 'PDF',
      'file_size': 1000,
      'file_size_display': '1 KB',
      'branch_name': null,
      'uploaded_by_name': 'HR',
      'uploaded_at': '2026-11-01T10:00:00Z',
      'is_active': true,
      'requires_acknowledgement': requires,
      'version': version,
      'my_acknowledged_at': ackAt,
    };

class FakeDocsServer implements HttpClientAdapter {
  FakeDocsServer(this.docs, {required this.perms});
  final Map<int, Map<String, dynamic>> docs;
  final Set<String> perms;
  final acked = <int, int>{}; // doc id → version acknowledged by "me"
  final calls = <({String method, String path, Object? body})>[];
  Completer<void>? holdAck;
  bool dropNextAck = false;
  bool failPending = false;

  bool _has(String p) => perms.contains(p) || perms.contains('settings.edit');
  int count(String method, String path) => calls.where((c) => c.method == method && c.path == path).length;

  Map<String, dynamic> _view(Map<String, dynamic> d) => {
        ...d,
        'my_acknowledged_at':
            d['requires_acknowledgement'] == true && acked[d['id']] == d['version'] ? '2026-11-04T09:30:00Z' : null,
      };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, body: o.data));
    final p = o.path;
    if (p == '/documents/pending-acknowledgements/') {
      if (failPending) return _fail(500, 'Server error.');
      if (!_has('documents.view')) return _ok(<Object>[]);
      return _ok([
        for (final d in docs.values)
          if (d['requires_acknowledgement'] == true && acked[d['id']] != d['version'])
            {'id': d['id'], 'title': d['title'], 'category': d['category'], 'version': d['version']},
      ]);
    }
    if (p == '/documents/' && o.method == 'POST') {
      final form = o.data as FormData;
      final id = 900 + docs.length;
      docs[id] = docJson(id, form.fields.firstWhere((f) => f.key == 'title').value,
          requires: form.fields.any((f) => f.key == 'requires_acknowledgement' && f.value == 'true'), version: 1);
      return _ok(_view(docs[id]!), 201);
    }
    final ack = RegExp(r'^/documents/(\d+)/acknowledge/$').firstMatch(p);
    if (ack != null && o.method == 'POST') {
      if (holdAck != null) await holdAck!.future;
      if (dropNextAck) {
        dropNextAck = false;
        throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      }
      if (!_has('documents.view')) return _fail(403, 'You do not have permission to view documents.');
      final d = docs[int.parse(ack.group(1)!)];
      if (d == null || d['requires_acknowledgement'] != true) {
        return _fail(404, 'Document not found or does not need acknowledgement.');
      }
      final version = (o.data as Map)['version'];
      if (version is! int) return _fail(400, 'version is required.');
      if (version != d['version']) {
        return _fail(409, 'This document has been updated. Please reopen it and read the latest version.');
      }
      final created = acked[d['id']] != version;
      acked[d['id'] as int] = version;
      return _ok({'document': d['id'], 'version': version, 'acknowledged_at': '2026-11-04T09:30:00Z'},
          created ? 201 : 200, created ? 'Acknowledged.' : 'Already acknowledged.');
    }
    final report = RegExp(r'^/documents/(\d+)/acknowledgements/$').firstMatch(p);
    if (report != null) {
      if (!_has('documents.edit')) return _fail(403, 'You do not have permission to view acknowledgements.');
      final d = docs[int.parse(report.group(1)!)]!;
      return _ok({
        'document': {'id': d['id'], 'title': d['title'], 'version': d['version']},
        'total': 2,
        'acknowledged': 1,
        'employees': [
          {
            'employee_id': 'EMP-1',
            'name': 'Asha Rao',
            'branch': 'Surat',
            'department': 'Eng',
            'acknowledged_at': '2026-11-03T10:00:00Z'
          },
          {
            'employee_id': 'EMP-2',
            'name': 'Ravi Kumar',
            'branch': 'Surat',
            'department': 'Ops',
            'acknowledged_at': null
          },
        ],
      });
    }
    final detail = RegExp(r'^/documents/(\d+)/$').firstMatch(p);
    if (detail != null) {
      final d = docs[int.parse(detail.group(1)!)];
      if (d == null) return _fail(404, 'Document not found.');
      if (o.method == 'PATCH') {
        if (!_has('documents.edit')) return _fail(403, 'You do not have permission to update documents.');
        d['requires_acknowledgement'] = (o.data as Map)['requires_acknowledgement'];
      }
      return _ok(_view(d));
    }
    if (p == '/documents/') {
      return _ok({
        'results': [for (final d in docs.values) _view(d)]
      });
    }
    if (p == '/documents/stats/') return _ok({'total': docs.length, 'by_category': {}});
    return _fail(404, 'Not found');
  }

  @override
  void close({bool force = false}) {}
}

class _Auth extends AuthNotifier {
  _Auth(this.perms);
  final List<String> perms;
  @override
  Future<AuthState> build() async => AuthState(
      user: UserEntity(
          id: 'u1',
          email: 'e@example.com',
          fullName: 'Pat',
          role: 'employee',
          roleDisplay: 'Employee',
          mustChangePassword: false,
          permissions: perms,
          onboardingStatus: 'complete',
          assessmentStatus: 'complete'));
}

const employee = ['documents.view'];
const hr = ['documents.view', 'documents.create', 'documents.edit', 'documents.delete'];

late FakeDocsServer server;

Future<void> pump(WidgetTester tester, Widget child, {List<String> perms = employee, FakeDocsServer? s}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = s ?? FakeDocsServer({7: docJson(7, 'Leave Policy')}, perms: perms.toSet());
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      authStateProvider.overrideWith(() => _Auth(perms)),
    ],
    child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  ));
  await tester.pumpAndSettle();
}

Future<void> openDetail(WidgetTester tester, {List<String> perms = employee, FakeDocsServer? s}) async {
  final srv = s ?? FakeDocsServer({7: docJson(7, 'Leave Policy')}, perms: perms.toSet());
  await pump(tester, DocumentDetailDialog(document: DocumentModel.fromJson(_viewOf(srv, 7))), perms: perms, s: srv);
}

Map<String, dynamic> _viewOf(FakeDocsServer s, int id) => {
      ...s.docs[id]!,
      'my_acknowledged_at': s.acked[id] == s.docs[id]!['version'] ? '2026-11-04T09:30:00Z' : null,
    };

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> acceptAndSubmit(WidgetTester tester) async {
  await tapKey(tester, 'ack-accept');
  await tapKey(tester, 'ack-submit');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('models (web lib/policyAck.ts)', () {
    test('document fields, pending rows and the report parse', () {
      final d = DocumentModel.fromJson(docJson(7, 'Leave Policy', version: 3, ackAt: '2026-11-01T00:00:00Z'));
      expect((d.requiresAcknowledgement, d.version, d.myAcknowledgedAt), (true, 3, '2026-11-01T00:00:00Z'));
      expect(ackStateOf(d), AckState.acknowledged);
      expect(ackStateOf(DocumentModel.fromJson(docJson(1, 'x'))), AckState.pending);
      expect(ackStateOf(DocumentModel.fromJson(docJson(1, 'x', requires: false))), AckState.notRequired);
      // Older payloads without the fields still parse.
      final old = Map<String, dynamic>.from(docJson(1, 'x'))
        ..remove('requires_acknowledgement')
        ..remove('version')
        ..remove('my_acknowledged_at');
      expect((DocumentModel.fromJson(old).requiresAcknowledgement, DocumentModel.fromJson(old).version), (false, 1));
      final p = PendingAcknowledgement.fromJson({'id': 7, 'title': 'Leave Policy', 'category': 'policy', 'version': 2});
      expect((p.id, p.title, p.version), (7, 'Leave Policy', 2));
    });

    test('report rows filter like web', () {
      const rows = [
        AckReportRow(employeeId: '1', name: 'A', acknowledgedAt: 'x'),
        AckReportRow(employeeId: '2', name: 'B'),
      ];
      expect(filterAckRows(rows, AckFilter.pending).map((r) => r.name), ['B']);
      expect(filterAckRows(rows, AckFilter.acknowledged).map((r) => r.name), ['A']);
      expect(filterAckRows(rows, AckFilter.all), hasLength(2));
    });
  });

  group('pending acknowledgements', () {
    testWidgets('banner names what is pending; none → nothing shown', (tester) async {
      await pump(tester, const PendingAcknowledgementsBanner());
      expect(find.byKey(const Key('pending-ack-banner')), findsOneWidget);
      expect(find.textContaining('Leave Policy'), findsOneWidget);
      await pump(tester, const PendingAcknowledgementsBanner(),
          s: FakeDocsServer({7: docJson(7, 'Leave Policy', requires: false)}, perms: employee.toSet()));
      expect(find.byKey(const Key('pending-ack-banner')), findsNothing);
    });

    testWidgets('the sheet lists them with version; empty and error states', (tester) async {
      await pump(tester, const SizedBox(height: 600, child: PendingAcknowledgementsSheet()));
      expect(find.byKey(const Key('pending-ack-7')), findsOneWidget);
      expect(find.textContaining('version 2'), findsOneWidget);

      await pump(tester, const SizedBox(height: 600, child: PendingAcknowledgementsSheet()),
          s: FakeDocsServer({}, perms: employee.toSet()));
      expect(find.byKey(const Key('pending-ack-empty')), findsOneWidget);

      final failing = FakeDocsServer({7: docJson(7, 'Leave Policy')}, perms: employee.toSet())..failPending = true;
      await pump(tester, const SizedBox(height: 600, child: PendingAcknowledgementsSheet()), s: failing);
      expect(find.text('Server error.'), findsOneWidget);
      failing.failPending = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pending-ack-7')), findsOneWidget);
    });

    testWidgets('opening one loads the document and shows its acknowledgement', (tester) async {
      await pump(tester, const SizedBox(height: 600, child: PendingAcknowledgementsSheet()));
      await tapKey(tester, 'pending-ack-7');
      expect(server.count('GET', '/documents/7/'), 1);
      expect(find.byKey(const Key('ack-panel')), findsOneWidget);
      expect(find.textContaining('version 2'), findsWidgets);
    });
  });

  group('acknowledging', () {
    testWidgets('needs the confirmation, sends the current version, success only after the server', (tester) async {
      await openDetail(tester);
      final submit = find.byKey(const Key('ack-submit'));
      expect(tester.widget<FilledButton>(submit).onPressed, isNull); // not yet confirmed
      await acceptAndSubmit(tester);
      final post = server.calls.lastWhere((c) => c.method == 'POST');
      expect(post.path, '/documents/7/acknowledge/');
      expect(post.body, {'version': 2});
      expect(find.byKey(const Key('ack-done')), findsOneWidget);
      expect(server.acked[7], 2);
    });

    testWidgets('after acknowledging, the pending banner refreshes and goes away', (tester) async {
      final s = FakeDocsServer({7: docJson(7, 'Leave Policy')}, perms: employee.toSet());
      await pump(
          tester,
          Column(children: [
            const PendingAcknowledgementsBanner(),
            DocumentDetailDialog(document: DocumentModel.fromJson(_viewOf(s, 7))),
          ]),
          s: s);
      expect(find.byKey(const Key('pending-ack-banner')), findsOneWidget);
      await acceptAndSubmit(tester);
      expect(s.count('GET', '/documents/pending-acknowledgements/'), 2);
      expect(find.byKey(const Key('pending-ack-banner')), findsNothing);
    });

    testWidgets('a newer version (409): the message, the current version, confirm again', (tester) async {
      await openDetail(tester);
      server.docs[7]!['version'] = 3; // HR replaced the file meanwhile
      await acceptAndSubmit(tester);
      expect(
          find.text('This document has been updated. Please reopen it and read the latest version.'), findsOneWidget);
      expect(find.byKey(const Key('ack-done')), findsNothing);
      expect(server.count('GET', '/documents/7/'), 1); // reloaded
      expect(find.textContaining('version 3'), findsWidgets);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('ack-accept'))).value, isFalse);
      await acceptAndSubmit(tester);
      expect(server.calls.lastWhere((c) => c.method == 'POST').body, {'version': 3});
      expect(find.byKey(const Key('ack-done')), findsOneWidget);
    });

    testWidgets('repeat taps while saving send once', (tester) async {
      await openDetail(tester);
      server.holdAck = Completer<void>();
      await tapKey(tester, 'ack-accept');
      await tester.tap(find.byKey(const Key('ack-submit')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ack-submit')), warnIfMissed: false);
      await tester.pump();
      server.holdAck!.complete();
      await tester.pumpAndSettle();
      expect(server.count('POST', '/documents/7/acknowledge/'), 1);
    });

    testWidgets('a refusal is shown as the server sent it; a dropped connection can be retried', (tester) async {
      final s = FakeDocsServer({7: docJson(7, 'Leave Policy')}, perms: employee.toSet());
      await openDetail(tester, s: s);
      s.docs[7]!['requires_acknowledgement'] = false; // no longer asked for
      await acceptAndSubmit(tester);
      expect(find.text('Document not found or does not need acknowledgement.'), findsOneWidget);
      expect(find.byKey(const Key('ack-done')), findsNothing);

      s.docs[7]!['requires_acknowledgement'] = true;
      s.dropNextAck = true;
      await tapKey(tester, 'ack-submit');
      expect(find.text('No internet connection. Check your connection and try again.'), findsOneWidget);
      await tapKey(tester, 'ack-submit');
      expect(find.byKey(const Key('ack-done')), findsOneWidget);
    });
  });

  group('HR view (documents.edit)', () {
    testWidgets('employees see no report or management controls and never request it', (tester) async {
      await openDetail(tester);
      expect(find.byKey(const Key('ack-view-report')), findsNothing);
      expect(find.byKey(const Key('ack-stop')), findsNothing);
      expect(server.calls.where((c) => c.path.endsWith('/acknowledgements/')), isEmpty);
    });

    testWidgets('a document that needs none shows nothing to an employee', (tester) async {
      await openDetail(tester,
          s: FakeDocsServer({7: docJson(7, 'Holiday List', requires: false)}, perms: employee.toSet()));
      expect(find.byKey(const Key('ack-panel')), findsNothing);
    });

    testWidgets('who has and has not acknowledged, filtered like web', (tester) async {
      await openDetail(tester, perms: hr);
      await tapKey(tester, 'ack-view-report');
      expect(find.text('1 of 2 acknowledged version 2'), findsOneWidget);
      expect(find.textContaining('Ravi Kumar'), findsOneWidget); // default: not yet
      expect(find.textContaining('Asha Rao'), findsNothing);
      await tester.tap(find.byKey(const Key('ack-report-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Everyone').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Asha Rao'), findsOneWidget);
      expect(find.textContaining('Ravi Kumar'), findsOneWidget);
    });

    testWidgets('switching acknowledgement on and off', (tester) async {
      final s = FakeDocsServer({7: docJson(7, 'Handbook', requires: false)}, perms: hr.toSet());
      await openDetail(tester, perms: hr, s: s);
      await tapKey(tester, 'ack-require');
      expect(s.calls.lastWhere((c) => c.method == 'PATCH').body, {'requires_acknowledgement': true});
      expect(find.byKey(const Key('ack-stop')), findsOneWidget);
      await tapKey(tester, 'ack-stop');
      expect(s.calls.lastWhere((c) => c.method == 'PATCH').body, {'requires_acknowledgement': false});
      expect(find.byKey(const Key('ack-require')), findsOneWidget);
    });
  });

  group('upload', () {
    test('sends requires_acknowledgement only when asked, everything else unchanged', () async {
      final dir = await Directory.systemTemp.createTemp('ack_upload');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/p.pdf')..writeAsBytesSync([1, 2, 3]);
      final s = FakeDocsServer({}, perms: hr.toSet());
      final ds = DocumentRemoteDataSource(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s);

      await ds.createDocument(
          filePath: file.path, fileName: 'p.pdf', title: 'Handbook', description: 'd', category: 'policy');
      final plain = s.calls.last.body as FormData;
      expect(plain.fields.map((f) => f.key), ['title', 'description', 'category']);
      expect(plain.files.single.key, 'file');

      final created = await ds.createDocument(
          filePath: file.path,
          fileName: 'p.pdf',
          title: 'Code of Conduct',
          description: '',
          category: 'policy',
          requiresAcknowledgement: true);
      final flagged = s.calls.last.body as FormData;
      expect(flagged.fields.firstWhere((f) => f.key == 'requires_acknowledgement').value, 'true');
      expect(created.requiresAcknowledgement, isTrue);
    });

    testWidgets('the upload form offers the acknowledgement option, off by default', (tester) async {
      await pump(tester, const DocumentUploadDialog(), perms: hr);
      final box = find.byKey(const Key('upload-requires-ack'));
      expect(box, findsOneWidget);
      expect(tester.widget<CheckboxListTile>(box).value, isFalse);
      await tester.tap(box);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(box).value, isTrue);
    });
  });
}
