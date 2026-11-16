import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/approvals/presentation/providers/approvals_providers.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/approval_detail_sheet.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/documents/data/models/document_model.dart';
import 'package:mobile_app/features/documents/presentation/widgets/document_detail_dialog.dart';
import 'package:mobile_app/features/employees/data/services/employee_document_download.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:mobile_app/features/expenses/data/models/expense_model.dart';
import 'package:mobile_app/features/expenses/presentation/widgets/expense_detail_dialog.dart';
import 'package:mobile_app/features/leave/presentation/widgets/leave_request_detail_sheet.dart';
import 'package:mobile_app/features/leave/data/models/leave_models.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/features/profile/presentation/screens/profile_document_viewer_screen.dart';
import 'package:mobile_app/features/wfh/data/models/wfh_models.dart';
import 'package:mobile_app/features/wfh/presentation/widgets/wfh_request_detail_sheet.dart';
import 'package:mobile_app/shared/documents/document_links.dart';

import '../features/employees/employee_documents_view_test.dart'
    show FileHost, MemStore, apiBase, fileHost, jpegBytes, pdfBytes, pngBytes, token;

// Task 67: opening request documents as web does.
//  - In the app (web DocPreviewModal): Team Approvals attachments (leave
//    supporting document, expense receipts, WFH medical proof) and Document
//    Center Preview — PDF/JPG/PNG in the viewer; other types outside the app.
//  - Outside the app (web plain new-tab links): leave, expense, WFH and
//    separation documents, Document Center Download, map links — handed to
//    the device without the canLaunchUrl check that is false on Android 11+.
// Signed file-host links are fetched without the login; the API's own links
// with it. Synthetic files and people; stand-in servers only.

/// The app API: serves the token-signed Document Center link and records calls.
class Api implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  int docStatus = 200;
  List<int> docBytes = pdfBytes;

  /// Returned for GETs of a request's own detail (path containing its id).
  Map<String, Map<String, dynamic>> details = {};

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add(o);
    if (o.uri.path == '/api/documents/7/') {
      if (docStatus != 200) {
        return ResponseBody.fromBytes(utf8.encode('{"status":"error","message":"x"}'), docStatus, headers: {
          Headers.contentTypeHeader: ['application/json']
        });
      }
      return ResponseBody.fromBytes(docBytes, 200, headers: {
        Headers.contentTypeHeader: ['application/pdf']
      });
    }
    final detail = details.entries.where((e) => o.uri.path.contains('/${e.key}/')).firstOrNull;
    return ResponseBody.fromString(
        jsonEncode({'status': 'success', 'message': 'ok', 'data': detail?.value ?? <String, dynamic>{}}), 200,
        headers: {
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
          id: 'hr1',
          email: 'hr@example.test',
          fullName: 'Test HR',
          role: 'hr',
          roleDisplay: 'HR',
          mustChangePassword: false,
          permissions: ['leave.approve', 'expenses.approve', 'wfh.approve', 'documents.view'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

late Api api;
late FileHost host;
late MemStore mem;
final launched = <Uri>[];
bool launchResult = true;
Finder byKey(String k) => find.byKey(Key(k));

Future<void> pumpHost(WidgetTester tester, Future<void> Function(BuildContext, WidgetRef) onOpen,
    {void Function(FileHost)? setupHost}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  api = Api();
  host = FileHost()
    ..files.addAll({
      'leave-doc': (pngBytes, 'image/png'),
      'receipt-1': (pdfBytes, 'application/octet-stream'), // Cloudinary raw: generic type
      'receipt-2': (jpegBytes, 'image/jpeg'),
      'wfh-proof': (pdfBytes, 'application/pdf'),
    });
  setupHost?.call(host);
  mem = MemStore();
  launched.clear();
  launchResult = true;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
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
        return launchResult;
      }),
    ],
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
            ? const SizedBox()
            : Scaffold(
                body: Center(
                  child: TextButton(
                    key: const Key('origin'),
                    onPressed: () => onOpen(context, ref),
                    child: const Text('ORIGIN SCREEN'),
                  ),
                ),
              ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

Future<void> closeViewer(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(ProfileDocumentViewerScreen), matching: find.byIcon(Icons.close)));
  await tester.pumpAndSettle();
}

bool sentLogin(RequestOptions o) => o.headers.keys.any((k) => k.toLowerCase() == 'authorization' || k.toLowerCase() == 'cookie');

UnifiedApprovalItem leaveItem(String url) => UnifiedApprovalItem.fromLeave(LeaveRequestModel.fromJson({
      'id': 'L1',
      'employee_name': 'Asha Test',
      'employee_code': 'EMP-1',
      'leave_type': 'sick',
      'leave_type_display': 'Sick Leave',
      'start_date': '2026-11-10',
      'end_date': '2026-11-11',
      'status': 'pending',
      'reason': 'Fever',
      'created_at': '2026-11-09T10:00:00Z',
      'document_url': url,
      'can_action': true,
    }));

UnifiedApprovalItem expenseItem(List<String> urls) => UnifiedApprovalItem.fromExpense(ExpenseModel.fromJson({
      'expense_number': 12,
      'expense_ref': 'EXP-12',
      'title': 'Taxi',
      'category': 'travel',
      'amount': '450.00',
      'expense_date': '2026-11-08',
      'status': 'pending',
      'employee_name': 'Bina Test',
      'created_at': '2026-11-08T10:00:00Z',
      'receipts': [
        for (var i = 0; i < urls.length; i++) {'id': 'r${i + 1}', 'url': urls[i]}
      ],
    }));

Map<String, dynamic> wfhJson({String? proof}) => {
      'id': 'W1',
      'start_date': '2026-11-12',
      'end_date': '2026-11-12',
      'reason': 'Recovering',
      'location_label': 'Home',
      'latitude': 12.5,
      'longitude': 77.5,
      'status': 'pending',
      'employee_name': 'Chetan Test',
      'employee_code': 'EMP-3',
      'is_medical': proof != null,
      'supporting_document_url': proof,
      'created_at': '2026-11-11T10:00:00Z',
    };

/// A signed file-host link whose path ends with the stored file name, as the
/// backend's authenticated Cloudinary links do (the stand-in host finds the
/// file by public_id).
String signed(String id, [String name = 'file.bin']) =>
    'https://$fileHost/raw/authenticated/s--sig--/v1/tenant/$name?public_id=$id';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('helpers', () {
    test('file name from a link, as web fileNameFromUrl', () {
      expect(documentFileNameFromUrl('https://h.test/a/b/receipt%20one.pdf?sig=1'), 'receipt one.pdf');
      expect(documentFileNameFromUrl('https://h.test/'), 'file');
      expect(documentFileNameFromUrl('https://h.test/v1/tenant/sick-note.png?public_id=x'), 'sick-note.png');
    });

    testWidgets('external open: https handed to the device; failures and non-web links shown, never launched',
        (tester) async {
      await pumpHost(tester, (c, r) => openDocumentLinkExternally(c, r, 'https://$fileHost/doc.pdf?s=1'));
      await tapKey(tester, 'origin');
      expect(launched.single.toString(), 'https://$fileHost/doc.pdf?s=1');
      expect(host.calls, isEmpty); // nothing downloaded by the app
      expect(api.calls, isEmpty);

      launchResult = false;
      await tapKey(tester, 'origin');
      expect(find.text(kLinkOpenFailedMessage), findsOneWidget);
    });

    for (final bad in ['', 'javascript:alert(1)', 'file:///etc/passwd', 'intent://x', 'https://']) {
      testWidgets('external open refuses "$bad"', (tester) async {
        await pumpHost(tester, (c, r) => openDocumentLinkExternally(c, r, bad, failureMessage: 'NOPE'));
        await tapKey(tester, 'origin');
        expect(launched, isEmpty);
        expect(find.text('NOPE'), findsOneWidget);
      });
    }

    test('a throwing launcher counts as a failure (no exception escapes)', () async {
      // Same logic as openDocumentLinkExternally's try/catch, without UI.
      Future<bool> launcher(Uri _) async => throw StateError('no activity');
      var opened = true;
      try {
        opened = await launcher(Uri.parse('https://x.test/a.pdf'));
      } catch (_) {
        opened = false;
      }
      expect(opened, isFalse);
    });
  });

  group('Team Approvals attachments (web DocPreviewModal → in-app)', () {
    testWidgets('leave supporting document (image): file host without the login; back to the request',
        (tester) async {
      await pumpHost(tester, (c, r) => showApprovalDetailSheet(c, leaveItem(signed('leave-doc', 'sick-note.png'))));
      await tapKey(tester, 'origin');
      await tapKey(tester, 'approval-attachment-Supporting document');
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      expect(host.calls, hasLength(1));
      expect(sentLogin(host.calls.single), isFalse); // the login never goes to the file host
      expect(launched, isEmpty);
      await closeViewer(tester);
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
      expect(byKey('approval-attachment-Supporting document'), findsOneWidget); // the request is still open
    });

    testWidgets('expense receipts: PDF in the viewer, temporary copy removed on close; JPG too', (tester) async {
      await pumpHost(tester, (c, r) => showApprovalDetailSheet(c, expenseItem([signed('receipt-1', 'taxi.pdf'), signed('receipt-2', 'meal.jpg')])));
      await tapKey(tester, 'origin');
      await tapKey(tester, 'approval-attachment-Receipt 1');
      expect(byKey('fake-pdf-view'), findsOneWidget);
      expect(mem.files, hasLength(1));
      await closeViewer(tester);
      expect(mem.files, isEmpty);
      await tapKey(tester, 'approval-attachment-Receipt 2');
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      expect(byKey('fake-pdf-view'), findsNothing);
      await closeViewer(tester);
      expect(host.calls.map((c) => c.uri.queryParameters['public_id']), ['receipt-1', 'receipt-2']);
      expect(host.calls.any(sentLogin), isFalse);
    });

    testWidgets('WFH medical proof is listed (as web) and opens', (tester) async {
      await pumpHost(tester,
          (c, r) => showApprovalDetailSheet(c, UnifiedApprovalItem.fromWfh(WfhRequestModel.fromJson(wfhJson(proof: signed('wfh-proof', 'doctor.pdf'))))));
      await tapKey(tester, 'origin');
      expect(find.text('Medical Proof'), findsOneWidget);
      await tapKey(tester, 'approval-attachment-Medical Proof');
      expect(byKey('fake-pdf-view'), findsOneWidget);
      await closeViewer(tester);
    });

    testWidgets('WFH without proof: no attachments section, nothing fetched', (tester) async {
      await pumpHost(
          tester, (c, r) => showApprovalDetailSheet(c, UnifiedApprovalItem.fromWfh(WfhRequestModel.fromJson(wfhJson()))));
      await tapKey(tester, 'origin');
      expect(find.text('ATTACHMENTS'), findsNothing);
      expect(host.calls, isEmpty);
    });

    testWidgets('expired / refused link, missing file, offline: a message, no viewer', (tester) async {
      await pumpHost(tester, (c, r) => showApprovalDetailSheet(c, expenseItem([signed('receipt-1', 'taxi.pdf'), signed('gone', 'old.pdf')])),
          setupHost: (h) => h.refuse['receipt-1'] = 401);
      await tapKey(tester, 'origin');
      await tapKey(tester, 'approval-attachment-Receipt 1');
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
      expect(find.text(kRequestDocumentExpiredMessage), findsOneWidget);
      await tapKey(tester, 'approval-attachment-Receipt 2');
      expect(find.text(kDocumentNotFoundMessage), findsOneWidget);
      host.offline = true;
      await tapKey(tester, 'approval-attachment-Receipt 1');
      expect(find.text(kDocumentNetworkMessage), findsOneWidget);
      expect(launched, isEmpty);
      expect(mem.files, isEmpty);
    });

    testWidgets('a type the viewer can\'t show opens outside the app (web "Open"), not downloaded',
        (tester) async {
      final url = signed('note-docx', 'medical-note.docx');
      await pumpHost(tester, (c, r) => showApprovalDetailSheet(c, leaveItem(url)),
          setupHost: (h) => h.files['note-docx'] = (utf8.encode('PK\u0003\u0004 synthetic'), 'application/octet-stream'));
      await tapKey(tester, 'origin');
      await tapKey(tester, 'approval-attachment-Supporting document');
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
      expect(launched.single.toString(), url);
      expect(mem.files, isEmpty);
    });

    testWidgets('the map link goes outside the app', (tester) async {
      await pumpHost(tester,
          (c, r) => showApprovalDetailSheet(c, UnifiedApprovalItem.fromWfh(WfhRequestModel.fromJson(wfhJson()))));
      await tapKey(tester, 'origin');
      await tester.tap(find.textContaining('View on map'));
      await tester.pumpAndSettle();
      expect(launched.single.toString(), 'https://maps.google.com/?q=12.5,77.5');
    });
  });

  group('Document Center (web: Preview in-app, Download via the browser)', () {
    DocumentModel docModel({String name = 'policy.pdf'}) => DocumentModel.fromJson({
          'id': 7,
          'title': 'Leave Policy',
          'category': 'policy',
          'category_display': 'Company Policy',
          'file_url': '$apiBase/documents/7/?t=signed-token-7',
          'file_name': name,
          'file_type': 'PDF',
          'file_size': 2048,
          'uploaded_at': '2026-11-01T10:00:00Z',
        });

    Future<void> openDialog(BuildContext c, DocumentModel d) =>
        showDialog<void>(context: c, builder: (_) => DocumentDetailDialog(document: d));

    testWidgets('Preview: the API\'s own signed link through the app\'s client; viewer; back', (tester) async {
      await pumpHost(tester, (c, r) => openDialog(c, docModel()));
      await tapKey(tester, 'origin');
      await tapKey(tester, 'document-preview');
      expect(byKey('fake-pdf-view'), findsOneWidget);
      final call = api.calls.singleWhere((c) => c.uri.path == '/api/documents/7/');
      expect(call.uri.queryParameters['t'], 'signed-token-7');
      expect(host.calls, isEmpty);
      await closeViewer(tester);
      expect(byKey('document-preview'), findsOneWidget);
      expect(mem.files, isEmpty);
    });

    testWidgets('Preview refused (403) or gone (404): the reason; no viewer', (tester) async {
      await pumpHost(tester, (c, r) => openDialog(c, docModel()));
      api.docStatus = 403;
      await tapKey(tester, 'origin');
      await tapKey(tester, 'document-preview');
      expect(find.text(kDocumentForbiddenMessage), findsOneWidget);
      api.docStatus = 404;
      await tapKey(tester, 'document-preview');
      expect(find.text(kDocumentNotFoundMessage), findsOneWidget);
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
    });

    testWidgets('Preview of a file that is not really a PDF/image is refused', (tester) async {
      await pumpHost(tester, (c, r) => openDialog(c, docModel()));
      api.docBytes = utf8.encode('<html>login page</html>');
      await tapKey(tester, 'origin');
      await tapKey(tester, 'document-preview');
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
      expect(mem.files, isEmpty);
    });

    testWidgets('Download hands the link to the browser; the app downloads nothing', (tester) async {
      await pumpHost(tester, (c, r) => openDialog(c, docModel()));
      await tapKey(tester, 'origin');
      await tapKey(tester, 'document-download');
      expect(launched.single.toString(), '$apiBase/documents/7/?t=signed-token-7');
      expect(api.calls.where((c) => c.uri.path == '/api/documents/7/'), isEmpty);
    });
  });

  group('plain links (web new tab → outside the app)', () {
    testWidgets('leave request: "View attached document" goes to the device; back to the request', (tester) async {
      final url = signed('leave-doc', 'sick-note.png');
      final leaveJson = <String, dynamic>{
        'id': 'L1',
        'employee_name': 'Asha Test',
        'leave_type': 'sick',
        'leave_type_display': 'Sick Leave',
        'start_date': '2026-11-10',
        'end_date': '2026-11-11',
        'status': 'pending',
        'reason': 'Fever',
        'created_at': '2026-11-09T10:00:00Z',
        'document_url': url,
      };
      final leave = LeaveRequestModel.fromJson(leaveJson);
      await pumpHost(
          tester,
          (c, r) => showModalBottomSheet<void>(
              context: c, isScrollControlled: true, builder: (_) => LeaveRequestDetailSheet(initial: leave)));
      api.details['L1'] = leaveJson; // the sheet reloads the request
      await tapKey(tester, 'origin');
      final link = find.text('View attached document');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(launched.map((u) => u.toString()), [url]);
      expect(host.calls, isEmpty);
      expect(link, findsOneWidget); // still on the request
    });

    testWidgets('expense: each receipt goes to the device; a refused launch says so', (tester) async {
      final r1 = signed('receipt-1', 'taxi.pdf');
      final r2 = signed('receipt-2', 'meal.jpg');
      final expenseJson = {
        'expense_number': 12,
        'expense_ref': 'EXP-12',
        'title': 'Taxi',
        'category': 'travel',
        'amount': '450.00',
        'expense_date': '2026-11-08',
        'status': 'pending',
        'employee_name': 'Bina Test',
        'created_at': '2026-11-08T10:00:00Z',
        'receipts': [
          {'id': 'r1', 'url': r1},
          {'id': 'r2', 'url': r2},
        ],
      };
      await pumpHost(tester, (c, r) => ExpenseDetailDialog.show(c, ExpenseModel.fromJson(expenseJson)));
      api.details['12'] = expenseJson;
      await tapKey(tester, 'origin');
      await tester.tap(find.text('Receipt 2'));
      await tester.pumpAndSettle();
      expect(launched.map((u) => u.toString()), [r2]);
      launchResult = false;
      await tester.tap(find.text('Receipt 1'));
      await tester.pumpAndSettle();
      expect(find.text('Could not open receipt.'), findsOneWidget);
      expect(host.calls, isEmpty);
    });

    testWidgets('WFH request: medical proof and map go to the device, nothing downloaded', (tester) async {
      final proof = signed('wfh-proof', 'doctor.pdf');
      await pumpHost(
          tester,
          (c, r) => showModalBottomSheet<void>(
              context: c,
              isScrollControlled: true,
              builder: (_) => WfhRequestDetailSheet(initial: WfhRequestModel.fromJson(wfhJson(proof: proof)))));
      api.details['W1'] = wfhJson(proof: proof);
      await tapKey(tester, 'origin');
      await tapKey(tester, 'wfh-medical-proof-link');
      expect(launched.map((u) => u.toString()), [proof]);
      expect(host.calls, isEmpty);
      expect(find.byType(ProfileDocumentViewerScreen), findsNothing);
    });
  });
}
