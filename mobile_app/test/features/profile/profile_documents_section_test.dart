import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/onboarding/presentation/widgets/onboarding_custom_file_field.dart'
    show onboardingFilePickerProvider;
import 'package:mobile_app/features/profile/data/services/profile_document_viewer.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/features/profile/presentation/screens/profile_document_viewer_screen.dart';
import 'package:mobile_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:mobile_app/features/profile/presentation/widgets/profile_documents_section.dart';

// Phase 11.4 steps 3–4: My Profile → Documents upload / replace / in-app view UI,
// against a stand-in for the production endpoints. Synthetic data only.

/// Records what the section asks the viewer to do.
class FakeViewer extends ProfileDocumentViewer {
  FakeViewer()
      : super(
          download: (_) async => throw UnimplementedError(),
          store: ProfileDocumentTempStore(tempRoot: () async => throw UnimplementedError()),
        );

  final loads = <(int, String?)>[];
  final released = <int>[];

  /// What the next load returns; null → a ready JPEG (shown from memory).
  DocumentViewOutcome? outcome;
  Completer<void>? hold;

  ProfileDocumentReady ready(int id, {bool pdf = false}) => ProfileDocumentReady(
        documentId: id,
        kind: pdf ? DocumentKind.pdf : DocumentKind.jpeg,
        imageBytes: pdf ? null : Uint8List.fromList(_tinyPng),
        pdfPath: pdf ? '/synthetic/profile_docs/doc-$id.pdf' : null,
        release: () async => released.add(id),
      );

  @override
  Future<DocumentViewOutcome> load(int documentId, {String? knownFileName}) async {
    loads.add((documentId, knownFileName));
    final gate = hold;
    if (gate != null) await gate.future;
    return outcome ?? ready(documentId);
  }
}

/// A valid 1×1 PNG, so Image.memory can decode it.
const _tinyPng = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
];

late FakeViewer viewer;

/// A signed-in employee (the section only shows documents to the user who
/// asked for them).
class SignedIn extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'u1',
          email: 'test.user@example.test',
          fullName: 'Test User',
          role: 'employee',
          roleDisplay: 'Employee',
          mustChangePassword: false,
          permissions: [],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );

  void signOut() => state = const AsyncData(AuthState.initial());
}

Map<String, dynamic> docJson(int id, String type, String at) => {
      'id': id,
      'document_type': type,
      'document_type_display': type == 'old_cert' ? 'Old Certificate' : type,
      'file_url': 'https://test.invalid/api/onboarding/documents/$id/',
      'file_name': 'file$id.pdf',
      'file_size': 2048,
      'uploaded_at': at,
    };

final defaultTypes = [
  {'type_key': 'pan_card', 'label': 'PAN Card', 'order': 1, 'visible': true, 'required': true},
  {'type_key': 'aadhaar_card', 'label': 'Aadhaar Card', 'order': 2, 'visible': true, 'required': true},
  {'type_key': 'certs', 'label': 'Certificates', 'order': 3, 'visible': true, 'allow_multiple': true},
  {'type_key': 'old_cert', 'label': 'Old Certificate', 'order': 0, 'visible': false},
];

List<Map<String, dynamic>> defaultDocs() => [
      docJson(41, 'pan_card', '2026-03-10T10:00:00Z'),
      docJson(42, 'certs', '2026-02-01T10:00:00Z'),
      docJson(43, 'certs', '2026-04-01T10:00:00Z'),
      docJson(44, 'old_cert', '2025-12-01T10:00:00Z'),
    ];

late FakeDocServer server;
late List<PlatformFile?> picks;
late int pickerCalls;

PlatformFile pf(String name, [int size = 1024]) => PlatformFile(name: name, size: size, bytes: Uint8List(size));

Future<void> pump(WidgetTester tester, {List<Map<String, dynamic>>? docs}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = FakeDocServer(types: defaultTypes, docs: docs ?? defaultDocs());
  picks = [];
  pickerCalls = 0;
  viewer = FakeViewer();
  final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server;
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      dioProvider.overrideWithValue(dio),
      authStateProvider.overrideWith(SignedIn.new),
      profileDocumentViewerProvider.overrideWithValue(viewer),
      profilePdfViewBuilderProvider.overrideWithValue(
        (path, tracker) => Text(path, key: const Key('fake-pdf-view')),
      ),
      onboardingFilePickerProvider.overrideWithValue(() async {
        pickerCalls++;
        return picks.isEmpty ? null : picks.removeAt(0);
      }),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          // As in the app: the sign-in state (kept alive by the router) and
          // the profile itself are loaded.
          ref.watch(authStateProvider);
          ref.watch(myProfileProvider);
          return const SingleChildScrollView(child: ProfileDocumentsSection());
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder rowOf(String type) => find.byKey(ValueKey('doc-row-$type'));
Finder inRow(String type, Finder f) => find.descendant(of: rowOf(type), matching: f);
Finder actionOf(String type) => inRow(type, find.byKey(const Key('doc-upload-action')));

Future<void> tapAction(WidgetTester tester, String type) async {
  await tester.tap(actionOf(type));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('rows: config order, uploaded and missing types, newest single file, all multi files, read-only retired',
      (tester) async {
    await pump(tester, docs: [
      ...defaultDocs(),
      docJson(40, 'pan_card', '2026-01-05T10:00:00Z'), // older duplicate: not shown
    ]);
    final order = [
      for (final t in ['pan_card', 'aadhaar_card', 'certs', 'old_cert']) tester.getTopLeft(rowOf(t)).dy,
    ];
    expect([...order]..sort(), order);

    expect(inRow('pan_card', find.text('Mar 10, 2026 · 2 KB')), findsOneWidget);
    expect(inRow('pan_card', find.byTooltip('View PAN Card')), findsOneWidget);
    expect(inRow('pan_card', find.byTooltip('Replace PAN Card')), findsOneWidget);

    expect(inRow('aadhaar_card', find.text('Not uploaded')), findsOneWidget);
    expect(inRow('aadhaar_card', find.text('Required')), findsOneWidget);
    expect(inRow('aadhaar_card', find.byTooltip('Upload Aadhaar Card')), findsOneWidget);

    expect(inRow('certs', find.text('2 files')), findsOneWidget);
    expect(inRow('certs', find.byTooltip('View Certificates')), findsNWidgets(2));
    expect(inRow('certs', find.byTooltip('Add another Certificates')), findsOneWidget);
    final newer = tester.getTopLeft(inRow('certs', find.text('Apr 1, 2026 · 2 KB'))).dy;
    final older = tester.getTopLeft(inRow('certs', find.text('Feb 1, 2026 · 2 KB'))).dy;
    expect(newer, lessThan(older));

    expect(inRow('old_cert', find.text('Old Certificate')), findsOneWidget);
    expect(inRow('old_cert', find.byKey(const Key('doc-read-only'))), findsOneWidget);
    expect(actionOf('old_cert'), findsNothing);
    expect(inRow('old_cert', find.byTooltip('View Old Certificate')), findsOneWidget);
  });

  testWidgets('uploading a missing document: no confirmation, success after the server saves it, list reloads',
      (tester) async {
    await pump(tester);
    final listsBefore = server.count('GET /onboarding/documents/');
    picks.add(pf('aadhaar.png'));
    await tapAction(tester, 'aadhaar_card');
    expect(find.byKey(const Key('replace-document-dialog')), findsNothing);
    expect(server.uploads.single.path, '/employees/EMP-T1/documents/');
    expect(server.uploads.single.body, contains('aadhaar_card'));
    expect(server.uploads.single.body, contains('content-type: image/png'));
    expect(find.text('Document uploaded successfully.'), findsOneWidget);
    expect(server.count('GET /onboarding/documents/'), listsBefore + 1);
    expect(inRow('aadhaar_card', find.text('Not uploaded')), findsNothing);
    expect(inRow('aadhaar_card', find.byTooltip('Replace Aadhaar Card')), findsOneWidget);
  });

  testWidgets('replacing asks first; Cancel opens no picker and sends nothing', (tester) async {
    await pump(tester);
    picks.add(pf('new.pdf'));
    await tapAction(tester, 'pan_card');
    expect(find.byKey(const Key('replace-document-dialog')), findsOneWidget);
    expect(find.text('Replace document?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(pickerCalls, 0);
    expect(server.uploads, isEmpty);
    expect(inRow('pan_card', find.text('Mar 10, 2026 · 2 KB')), findsOneWidget);
  });

  testWidgets('confirming Replace uploads and shows the new file', (tester) async {
    await pump(tester);
    picks.add(pf('new.pdf'));
    await tapAction(tester, 'pan_card');
    await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
    await tester.pumpAndSettle();
    expect(server.uploads.single.body, contains('pan_card'));
    expect(find.text('Document uploaded successfully.'), findsOneWidget);
    expect(inRow('pan_card', find.text('Nov 5, 2026 · 2 KB')), findsOneWidget);
    expect(inRow('pan_card', find.text('Mar 10, 2026 · 2 KB')), findsNothing);
  });

  testWidgets('a multiple-file type adds another file without confirmation', (tester) async {
    await pump(tester);
    picks.add(pf('cert.jpg'));
    await tapAction(tester, 'certs');
    expect(find.byKey(const Key('replace-document-dialog')), findsNothing);
    expect(server.uploads.single.body, contains('content-type: image/jpeg'));
    expect(inRow('certs', find.text('3 files')), findsOneWidget);
    expect(inRow('certs', find.byTooltip('View Certificates')), findsNWidgets(3));
  });

  testWidgets('files the backend would refuse are rejected before sending; exactly 5 MB is sent', (tester) async {
    await pump(tester);
    for (final (file, message) in [
      (pf('notes.docx'), 'Only PDF, JPG, and PNG files are allowed.'),
      (pf('empty.pdf', 0), 'Uploaded file is empty.'),
      (pf('big.pdf', 5 * 1024 * 1024 + 1), 'File size 5.0 MB exceeds the 5 MB limit.'),
      (PlatformFile(name: 'x.pdf', size: 10), 'Could not read the file.'),
    ]) {
      picks.add(file);
      await tapAction(tester, 'aadhaar_card');
      expect(find.text(message), findsOneWidget, reason: file.name);
      expect(find.text('Document uploaded successfully.'), findsNothing);
      ScaffoldMessenger.of(tester.element(rowOf('pan_card'))).removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }
    expect(server.uploads, isEmpty);
    expect(inRow('aadhaar_card', find.text('Not uploaded')), findsOneWidget);

    picks.add(pf('exact.pdf', 5 * 1024 * 1024));
    await tapAction(tester, 'aadhaar_card');
    expect(server.uploads, hasLength(1));
  });

  testWidgets('while uploading: progress shown, that action disabled, other types still upload', (tester) async {
    await pump(tester);
    final gate = server.hold = Completer<void>();
    picks.add(pf('a.pdf'));
    await tester.tap(actionOf('aadhaar_card'));
    await tester.pump();
    await tester.pump();
    expect(inRow('aadhaar_card', find.byKey(const Key('doc-uploading'))), findsOneWidget);
    expect(inRow('aadhaar_card', find.text('Uploading…')), findsOneWidget);
    expect(find.text('Document uploaded successfully.'), findsNothing);

    InkWell actionInk(String type) =>
        tester.widget<InkWell>(find.descendant(of: actionOf(type), matching: find.byType(InkWell)));
    expect(actionInk('aadhaar_card').onTap, isNull); // disabled while its upload runs
    expect(actionInk('certs').onTap, isNotNull);

    // A second tap on the same row does nothing at all.
    await tester.tap(actionOf('aadhaar_card'));
    await tester.pump();
    expect(pickerCalls, 1);

    // Another type is not blocked.
    picks.add(pf('c.pdf'));
    await tester.tap(actionOf('certs'));
    await tester.pump();
    await tester.pump();
    expect(pickerCalls, 2);

    gate.complete();
    await tester.pumpAndSettle();
    expect(server.uploads, hasLength(2));
    expect(find.byKey(const Key('doc-uploading')), findsNothing);
    expect(inRow('aadhaar_card', find.byTooltip('Replace Aadhaar Card')), findsOneWidget);
  });

  testWidgets('a refused upload shows the server message, never success, and keeps the current file', (tester) async {
    await pump(tester);
    server.uploadStatus = 400;
    server.uploadMessage = 'Invalid document type.';
    final listsBefore = server.count('GET /onboarding/documents/');
    picks.add(pf('new.pdf'));
    await tapAction(tester, 'pan_card');
    await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid document type.'), findsOneWidget);
    expect(find.text('Document uploaded successfully.'), findsNothing);
    expect(server.count('GET /onboarding/documents/'), listsBefore);
    expect(inRow('pan_card', find.text('Mar 10, 2026 · 2 KB')), findsOneWidget);
    expect(inRow('pan_card', find.byTooltip('Replace PAN Card')), findsOneWidget);
  });

  testWidgets('a picker cancelled with no file sends nothing', (tester) async {
    await pump(tester);
    await tapAction(tester, 'aadhaar_card');
    expect(pickerCalls, 1);
    expect(server.uploads, isEmpty);
  });

  testWidgets('a failed list shows the error and Retry reloads it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    await pump(tester);
    server.docsStatus = 500;
    final container = ProviderScope.containerOf(tester.element(find.byType(ProfileDocumentsSection)));
    container.invalidate(myDocumentsProvider);
    // Nothing else schedules frames here, so advance the clock explicitly.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Retry'), findsOneWidget);
    server.docsStatus = 200;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(rowOf('pan_card'), findsOneWidget);
  });

  testWidgets('View loads the right document and shows it in the app; notice shown', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('doc-viewer-notice')), findsOneWidget);
    expect(kInAppViewerNotice, contains('not shared with other apps'));
    expect(kInAppViewerNotice, contains('deleted when you close them or sign out'));

    await tester.tap(inRow('pan_card', find.byTooltip('View PAN Card')));
    await tester.pumpAndSettle();
    expect(viewer.loads.single, (41, 'file41.pdf'));
    expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
    expect(find.text('PAN Card'), findsWidgets); // viewer title
    expect(find.byKey(const Key('image-viewer')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(viewer.released, isEmpty);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
    expect(viewer.released, [41]); // temporary copy deleted on close

    // Multiple-file and retired types view each file by its own id.
    for (final id in [42, 44]) {
      await tester.tap(find.byKey(ValueKey('doc-view-$id')));
      await tester.pumpAndSettle();
      // System back.
      tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
      await tester.pumpAndSettle();
    }
    expect(viewer.loads.map((v) => v.$1), [41, 42, 44]);
    expect(viewer.released, [41, 42, 44]); // system back releases too
  });

  testWidgets('a PDF opens in the in-app PDF view; closing releases it', (tester) async {
    await pump(tester);
    viewer.outcome = viewer.ready(41, pdf: true);
    await tester.tap(find.byKey(const ValueKey('doc-view-41')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake-pdf-view')), findsOneWidget);
    expect(find.text('/synthetic/profile_docs/doc-41.pdf'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(viewer.released, [41]);
  });

  testWidgets('no notice when nothing is uploaded', (tester) async {
    await pump(tester, docs: []);
    expect(find.byKey(const Key('doc-viewer-notice')), findsNothing);
  });

  testWidgets('while a document loads: spinner, that View disabled, a second tap ignored', (tester) async {
    await pump(tester);
    final gate = viewer.hold = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('doc-view-41')));
    await tester.pump();
    final view41 = find.byKey(const ValueKey('doc-view-41'));
    expect(find.descendant(of: view41, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    expect(tester.widget<InkWell>(find.descendant(of: view41, matching: find.byType(InkWell))).onTap, isNull);
    await tester.tap(view41);
    await tester.pump();
    expect(viewer.loads, hasLength(1));
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
  });

  testWidgets('a failed load shows its message, opens nothing, and leaves the list unchanged', (tester) async {
    await pump(tester);
    for (final message in [
      kDocumentUnsupportedMessage,
      kDocumentEmptyMessage,
      kDocumentOpenFailedMessage,
      'Document not found.',
    ]) {
      viewer.outcome = DocumentViewFailed(message);
      await tester.tap(find.byKey(const ValueKey('doc-view-41')));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
      ScaffoldMessenger.of(tester.element(rowOf('pan_card'))).removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }
    expect(inRow('pan_card', find.text('Mar 10, 2026 · 2 KB')), findsOneWidget);
    expect(inRow('pan_card', find.byTooltip('Replace PAN Card')), findsOneWidget);
    expect(server.uploads, isEmpty);
  });

  testWidgets('if the section is gone before loading finishes, the copy is released and nothing opens', (tester) async {
    await pump(tester);
    final gate = viewer.hold = Completer<void>();
    viewer.outcome = viewer.ready(41, pdf: true);
    await tester.tap(find.byKey(const ValueKey('doc-view-41')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    gate.complete();
    await tester.pumpAndSettle();
    expect(viewer.released, [41]);
    expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
  });

  testWidgets('signing out while a document loads: nothing is shown and the copy is released', (tester) async {
    await pump(tester);
    final gate = viewer.hold = Completer<void>();
    viewer.outcome = viewer.ready(41, pdf: true);
    await tester.tap(find.byKey(const ValueKey('doc-view-41')));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(ProfileDocumentsSection)));
    (container.read(authStateProvider.notifier) as SignedIn).signOut();
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
    expect(viewer.released, [41]);
    // The View button is usable again (not stuck loading).
    final view41 = find.byKey(const ValueKey('doc-view-41'));
    expect(find.descendant(of: view41, matching: find.byType(CircularProgressIndicator)), findsNothing);
  });

  testWidgets('the profile screen still shows its other sections with Documents last', (tester) async {
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    server = FakeDocServer(types: defaultTypes, docs: defaultDocs());
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        authStateProvider.overrideWith(SignedIn.new),
        profileDocumentViewerProvider.overrideWithValue(FakeViewer()),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    ));
    await tester.pumpAndSettle();
    for (final title in [
      'Personal Information',
      'Address',
      'Education & Experience',
      'Bank Details',
      'Emergency Contact',
      'Change Password',
      'Documents'
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    expect(rowOf('pan_card'), findsOneWidget);
    expect(find.text('Test User'), findsWidgets);
  });
}

class _Upload {
  _Upload(this.path, this.body);
  final String path;
  final String body;
}

class FakeDocServer implements HttpClientAdapter {
  FakeDocServer({required this.types, required List<Map<String, dynamic>> docs}) : docs = [...docs];

  final List<Map<String, dynamic>> types;
  final List<Map<String, dynamic>> docs;
  int docsStatus = 200;
  int uploadStatus = 201;
  String uploadMessage = 'Document uploaded.';
  Completer<void>? hold;
  final calls = <String>[];
  final uploads = <_Upload>[];
  int _nextId = 99;

  int count(String call) => calls.where((c) => c == call).length;

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? _) async {
    calls.add('${o.method} ${o.path}');
    if (o.method == 'GET' && o.path == '/employees/me/') {
      return _json(200, {
        'status': 'success',
        'message': 'ok',
        'data': {
          'id': 'u1',
          'employee_id': 'EMP-T1',
          'full_name': 'Test User',
          'email': 'test.user@example.test',
          'onboarding_status': 'complete',
          'profile': <String, dynamic>{},
        },
      });
    }
    if (o.method == 'GET' && o.path == '/onboarding/document-type-config/') {
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
      final multiple = types.any((t) => t['type_key'] == type && t['allow_multiple'] == true);
      if (!multiple) docs.removeWhere((d) => d['document_type'] == type);
      final created = docJson(_nextId++, type, '2026-11-05T09:00:00Z');
      docs.add(created);
      return _json(201, {'status': 'success', 'message': uploadMessage, 'data': created});
    }
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}
