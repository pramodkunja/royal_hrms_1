import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/candidate_review/presentation/screens/candidate_review_screen.dart';
import 'package:mobile_app/features/employees/data/services/employee_document_download.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:mobile_app/features/profile/data/services/profile_document_viewer.dart' show kDocumentUnsupportedMessage;
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/features/profile/presentation/screens/profile_document_viewer_screen.dart';
import 'package:mobile_app/shared/documents/document_links.dart';
import '../employees/employee_documents_view_test.dart'
    show FileHost, MemStore, apiBase, fileHost, jpegBytes, link, pdfBytes, pngBytes, token;

// Task 82 (audit REC-27): Candidate Review → applicant → Documents → View.
// Web candidate-review/_components/OnboardingDrawer.tsx opens each document
// in DocPreviewModal (inline: PDF via an authenticated fetch, images as
// <img>, plus "open in new tab"); a row without file_url shows "No link".
// Backend OnboardingApprovalView (list and detail, onboarding.approve,
// branch-scoped) serialises documents with EmployeeDocumentSerializer and
// use_cloudinary_url=True: `file_url` is a short-lived signed file-host link
// (private_download_url, authenticated raw), falling back to the API's own
// /api/onboarding/documents/<id>/ (owner or employees.edit). Uploads are
// PDF / JPG / PNG only. Mobile's View button was a no-op (`onPressed: () {}`);
// it now uses the shared in-app viewer (previewDocumentInApp), which sends
// the app's login only to the API's own server.
// Synthetic applicants and files; stand-in servers only.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> doc(int id, String label, String name, String? url) => {
      'id': id,
      'document_type': 'other',
      'document_type_display': label,
      'file_name': name,
      'file_size': 2048,
      'file_url': url,
      'uploaded_at': '2026-11-01T10:00:00Z',
    };

Map<String, dynamic> applicant(List<Map<String, dynamic>> docs) => {
      'id': 'u-9',
      'full_name': 'Asha Applicant',
      'email': 'asha@example.test',
      'phone': '9000000000',
      'department': 'Engineering',
      'designation': 'Engineer',
      'branch': 'Test Branch',
      'role_name': '',
      'role_display': '',
      'employee_id': '',
      'date_of_joining': null,
      'onboarding_status': 'submitted',
      'date_joined': '2026-11-01T10:00:00Z',
      'candidate_id': 9,
      'position_applied': 'Engineer',
      'profile': {'date_of_birth': '1995-01-01'},
      'documents': docs,
    };

const apiDocPath = '/api/onboarding/documents/55/';

final allDocs = [
  doc(1, 'PAN Card', 'pan.pdf', link('pan', 1)),
  doc(2, 'Aadhaar Card', 'aadhaar.png', link('aadhaar', 1)),
  doc(3, 'Bank Proof', 'bank.jpg', link('bank', 1)),
  doc(4, 'Resume', 'resume.docx', link('resume', 1)),
  doc(5, 'Address Proof', 'address.pdf', null),
  doc(55, 'Offer Letter', 'offer.pdf', '$apiBase/onboarding/documents/55/'),
];

/// The app API: the onboarding approvals list, and the API-hosted document.
class Api implements HttpClientAdapter {
  Api(this.rows);
  final List<Map<String, dynamic>> rows;
  final calls = <RequestOptions>[];
  int listStatus = 200;
  int docStatus = 200;
  Completer<void>? holdDoc;

  int get docGets => calls.where((c) => c.uri.path == apiDocPath).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add(o);
    final p = o.uri.path;
    if (p == apiDocPath) {
      if (holdDoc != null) await holdDoc!.future;
      if (docStatus != 200) return _json(docStatus, {'status': 'error', 'message': 'x', 'data': {}});
      return ResponseBody.fromBytes(pdfBytes, 200, headers: {
        Headers.contentTypeHeader: ['application/pdf']
      });
    }
    if (p == '/api/onboarding/approvals/') {
      if (listStatus != 200) {
        return _json(listStatus, {'status': 'error', 'message': 'You do not have permission to view onboarding approvals.', 'data': {}});
      }
      return _json(200, {
        'status': 'success',
        'message': 'ok',
        'data': {'count': rows.length, 'page': 1, 'page_size': 100, 'total_pages': 1, 'results': rows},
      });
    }
    return _json(200, {'status': 'success', 'message': 'ok', 'data': {'results': <Object>[]}});
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

class TestAuth extends AuthNotifier {
  TestAuth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

UserEntity user(List<String> perms) => UserEntity(
      id: 'hr1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final approver = user(['recruitment.view', 'onboarding.approve']);

late Api api;
late FileHost host;
late MemStore mem;
final launched = <Uri>[];

Finder byKey(String k) => find.byKey(Key(k));
bool sentLogin(RequestOptions o) =>
    o.headers.keys.any((k) => k.toLowerCase() == 'authorization' || k.toLowerCase() == 'cookie');

Future<void> pump(WidgetTester tester,
    {UserEntity? as, List<Map<String, dynamic>>? docs, void Function(Api, FileHost)? setup}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  api = Api([applicant(docs ?? allDocs)]);
  host = FileHost()
    ..files.addAll({
      'pan': (pdfBytes, 'application/octet-stream'), // Cloudinary raw: generic type
      'aadhaar': (pngBytes, 'image/png'),
      'bank': (jpegBytes, 'image/jpeg'),
      'resume': ([0x50, 0x4B, 0x03, 0x04, 1, 2, 3], 'application/octet-stream'), // a .docx (zip)
    });
  mem = MemStore();
  launched.clear();
  setup?.call(api, host);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => TestAuth(as ?? approver)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: apiBase))
        ..httpClientAdapter = api
        ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
          o.headers['Authorization'] = 'Bearer $token';
          h.next(o);
        }))),
      employeeDocumentExternalDioProvider.overrideWithValue(Dio()..httpClientAdapter = host),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      profileDocumentTempStoreProvider.overrideWithValue(mem),
      profilePdfViewBuilderProvider.overrideWithValue((path, tracker) => Text(path, key: const Key('fake-pdf-view'))),
      externalLinkLauncherProvider.overrideWithValue((uri) async {
        launched.add(uri);
        return true;
      }),
    ],
    child: MaterialApp(
      home: Consumer(builder: (_, ref, child) {
        ref.watch(authStateProvider);
        return child!;
      }, child: const Scaffold(body: CandidateReviewScreen())),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> openApplicant(WidgetTester tester) async {
  await tester.tap(find.text('Asha Applicant').first);
  await tester.pumpAndSettle();
  if (find.textContaining('Review —').evaluate().isEmpty && find.text('Review').evaluate().isNotEmpty) {
    await tester.tap(find.text('Review').first);
    await tester.pumpAndSettle();
  }
}

Future<void> view(WidgetTester tester, int id) async {
  await tester.ensureVisible(byKey('onboarding-doc-view-$id'));
  await tester.tap(byKey('onboarding-doc-view-$id'));
  await tester.pumpAndSettle();
}

Future<void> closeViewer(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(ProfileDocumentViewerScreen), matching: find.byIcon(Icons.close)));
  await tester.pumpAndSettle();
}

String? snack(WidgetTester tester) {
  final s = find.descendant(of: find.byType(SnackBar), matching: find.byType(Text));
  return s.evaluate().isEmpty ? null : tester.widget<Text>(s.first).data;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('View opens the document in the app (web DocPreviewModal)', () {
    testWidgets('1-4. PDF on the signed file-host link: viewer opens; no login sent to the file host', (tester) async {
      await pump(tester);
      await openApplicant(tester);
      expect(find.text('DOCUMENTS (6)'), findsOneWidget);
      await view(tester, 1);
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      expect(byKey('fake-pdf-view'), findsOneWidget);
      final req = host.calls.single;
      expect(req.uri.toString(), link('pan', 1)); // exactly the backend's link
      expect(req.uri.host, fileHost);
      expect(sentLogin(req), isFalse);
      await closeViewer(tester);
      expect(mem.files, isEmpty); // temporary copy released
    });

    for (final (label, id, publicId) in [('PNG', 2, 'aadhaar'), ('JPG', 3, 'bank')]) {
      testWidgets('5. $label image: viewer opens', (tester) async {
        await pump(tester);
        await openApplicant(tester);
        await view(tester, id);
        expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
        expect(find.byType(Image), findsWidgets);
        expect(host.calls.single.uri.queryParameters['public_id'], publicId);
      });
    }

    testWidgets('3. API-hosted link: fetched from the API with the login', (tester) async {
      await pump(tester);
      await openApplicant(tester);
      await view(tester, 55);
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      final req = api.calls.lastWhere((c) => c.uri.path == apiDocPath);
      expect(req.headers['Authorization'], 'Bearer $token');
      expect(host.calls, isEmpty);
    });

    testWidgets('6. unsupported type (.docx): opened outside the app with the same link, as web\'s new tab', (tester) async {
      await pump(tester);
      await openApplicant(tester);
      await view(tester, 4);
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
      expect(launched.single.toString(), link('resume', 1));
      expect(snack(tester), isNot(kDocumentUnsupportedMessage));
    });

    testWidgets('7. missing link: "No link", no View button, nothing fetched', (tester) async {
      await pump(tester);
      await openApplicant(tester);
      expect(find.descendant(of: byKey('onboarding-doc-5'), matching: find.text('No link')), findsOneWidget);
      expect(byKey('onboarding-doc-view-5'), findsNothing);
    });
  });

  group('failures', () {
    for (final (status, message) in [
      (401, kDocumentSessionExpiredMessage),
      (403, kDocumentForbiddenMessage),
      (404, kDocumentNotFoundMessage),
    ]) {
      testWidgets('8. HTTP $status: "$message"; no viewer; no token or link in the message', (tester) async {
        await pump(tester, setup: (a, _) => a.docStatus = status);
        await openApplicant(tester);
        await view(tester, 55);
        expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
        expect(snack(tester), message);
        expect(snack(tester)!.contains(token) || snack(tester)!.contains('http'), isFalse);
        // The button is usable again.
        expect(tester.widget<TextButton>(byKey('onboarding-doc-view-55')).onPressed, isNotNull);
      });
    }

    testWidgets('9. network failure: connection message; retry works', (tester) async {
      await pump(tester, setup: (_, h) => h.offline = true);
      await openApplicant(tester);
      await view(tester, 1);
      expect(snack(tester), kDocumentNetworkMessage);
      host.offline = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await view(tester, 1);
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
    });

    testWidgets('10-11. repeated taps: one fetch; "Opening…" and disabled while loading', (tester) async {
      final gate = Completer<void>();
      await pump(tester, setup: (a, _) => a.holdDoc = gate);
      await openApplicant(tester);
      await tester.ensureVisible(byKey('onboarding-doc-view-55'));
      await tester.tap(byKey('onboarding-doc-view-55'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Opening…'), findsOneWidget);
      expect(tester.widget<TextButton>(byKey('onboarding-doc-view-55')).onPressed, isNull);
      await tester.tap(byKey('onboarding-doc-view-55'), warnIfMissed: false);
      await tester.tap(byKey('onboarding-doc-view-55'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(api.docGets, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      expect(api.docGets, 1);
    });
  });

  group('access and navigation', () {
    testWidgets('12. without onboarding.approve the server refuses the list: no documents, nothing fetched',
        (tester) async {
      await pump(tester, as: user(['recruitment.view']), setup: (a, _) => a.listStatus = 403);
      expect(find.text('Asha Applicant'), findsNothing);
      expect(find.byKey(const Key('onboarding-doc-view-1')), findsNothing);
      expect(host.calls, isEmpty);
    });

    testWidgets('13. closing the viewer returns to the applicant\'s review', (tester) async {
      await pump(tester);
      await openApplicant(tester);
      await view(tester, 2);
      await closeViewer(tester);
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
      expect(find.text('DOCUMENTS (6)'), findsOneWidget);
      expect(byKey('onboarding-doc-view-2'), findsOneWidget);
    });
  });
}
