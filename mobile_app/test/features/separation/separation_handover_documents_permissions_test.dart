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
import 'package:mobile_app/features/separation/data/models/separation_models.dart';
import 'package:mobile_app/features/separation/presentation/widgets/separation_documents_section.dart';
import 'package:mobile_app/features/separation/presentation/widgets/separation_handover_section.dart';

// Task 71b (audit findings M1, L5):
//  - Handover tasks: web KtHandoverSection canManage = canApprove && !is_own —
//    an approver never adds, toggles or deletes tasks on their OWN
//    separation, though the backend would allow toggle (approver or owner)
//    and delete (approver) — separation_workflow.py patch / delete.
//  - Documents: the backend lets only a separation approver or the uploader
//    delete (SeparationDocumentDetailView.delete). Owning the request isn't
//    enough. The current serializer sends no uploader id, so the uploader is
//    recognised only when the server sends `uploaded_by` (or `can_delete`).
// Synthetic people and documents; a stand-in server answers.

const reqId = 'sep-1';

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> task(String id, {bool done = false}) => {
      'id': id,
      'task': 'Handover task $id',
      'description': '',
      'assigned_to': null,
      'assigned_to_name': 'Ravi Test',
      'due_date': null,
      'is_completed': done,
      'created_by_name': 'Hema HR',
      'created_at': '2026-11-01T09:00:00Z',
    };

Map<String, dynamic> doc(String id, String by, {Object? uploadedBy, bool? canDelete}) => {
      'id': id,
      'document_type': 'other',
      'document_type_display': 'Other',
      'file_url': null,
      'uploaded_by_name': by,
      'created_at': '2026-11-01T09:00:00Z',
      if (uploadedBy != null) 'uploaded_by': uploadedBy,
      if (canDelete != null) 'can_delete': canDelete,
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> tasks = [task('t1')];
  List<Map<String, dynamic>> docs = [doc('d1', 'Hema HR'), doc('d2', 'Mira Owner')];
  final writes = <(String, String, Object?)>[];
  String? refuse;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'GET') {
      if (o.path == '/separation/requests/$reqId/tasks/') {
        return _json(200, {'status': 'success', 'message': 'ok', 'data': tasks});
      }
      if (o.path == '/separation/requests/$reqId/documents/') {
        return _json(200, {'status': 'success', 'message': 'ok', 'data': docs});
      }
      return _json(200, {'status': 'success', 'message': 'ok', 'data': <Object>[]});
    }
    writes.add((o.method, o.path, o.data));
    if (refuse != null) return _json(403, {'status': 'error', 'message': refuse, 'data': {}});
    return _json(200, {'status': 'success', 'message': 'ok', 'data': {}});
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
          id: 'u-me',
          email: 'me@example.test',
          fullName: 'Mira Owner',
          role: 'r',
          roleDisplay: 'Role',
          mustChangePassword: false,
          permissions: [],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

late Server server;

Future<void> pump(WidgetTester tester, Widget child, {void Function(Server)? setup}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  ));
  await tester.pumpAndSettle();
}

Widget handover({required bool canManage, required bool isOwn}) =>
    SeparationHandoverSection(requestId: reqId, canManage: canManage, isOwn: isOwn);

Widget documents({required bool canUpload, bool isApprover = false, String? me = 'u-me'}) =>
    SeparationDocumentsSection(requestId: reqId, canUpload: canUpload, isApprover: isApprover, currentUserId: me);

/// The task's completion toggle (a GestureDetector around its status icon).
GestureDetector toggleOf(WidgetTester tester) => tester.widget<GestureDetector>(find
    .ancestor(of: find.byIcon(Icons.radio_button_unchecked), matching: find.byType(GestureDetector))
    .first);

final deleteButtons = find.byIcon(Icons.delete_outline);
final addTaskButton = find.byIcon(Icons.add_circle_outline);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('handover tasks (web: canApprove && !is_own)', () {
    testWidgets('approver on their OWN separation: tasks shown; no add, toggle or delete', (tester) async {
      await pump(tester, handover(canManage: true, isOwn: true));
      expect(find.text('Handover task t1'), findsOneWidget);
      expect(toggleOf(tester).onTap, isNull);
      expect(deleteButtons, findsNothing);
      expect(addTaskButton, findsNothing);
      // Tapping the status icon sends nothing either.
      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pumpAndSettle();
      expect(server.writes, isEmpty);
    });

    testWidgets('approver on another employee\'s separation: add, toggle and delete available', (tester) async {
      await pump(tester, handover(canManage: true, isOwn: false));
      expect(addTaskButton, findsOneWidget);
      expect(toggleOf(tester).onTap, isNotNull);
      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pumpAndSettle();
      expect(server.writes.single.$1, 'PATCH');
      expect(server.writes.single.$2, '/separation/requests/$reqId/tasks/t1/');
      expect(server.writes.single.$3, {'is_completed': true}); // payload unchanged
      await tester.tap(deleteButtons);
      await tester.pumpAndSettle();
      expect(server.writes.last.$1, 'DELETE');
      expect(server.writes.last.$2, '/separation/requests/$reqId/tasks/t1/');
    });

    testWidgets('server refusal of toggle / delete is shown', (tester) async {
      await pump(tester, handover(canManage: true, isOwn: false), setup: (s) => s.refuse = 'Permission denied.');
      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pumpAndSettle();
      expect(find.text('Permission denied.'), findsOneWidget);
      await tester.tap(deleteButtons);
      await tester.pumpAndSettle();
      expect(server.writes.map((w) => w.$1), ['PATCH', 'DELETE']);
    });

    for (final (label, isOwn) in [('ordinary employee on their own separation', true), ('non-approver on another\'s', false)]) {
      testWidgets('$label: view only', (tester) async {
        await pump(tester, handover(canManage: false, isOwn: isOwn));
        expect(find.text('Handover task t1'), findsOneWidget);
        expect(toggleOf(tester).onTap, isNull);
        expect(deleteButtons, findsNothing);
        expect(addTaskButton, findsNothing);
      });
    }
  });

  group('document delete (backend: approver or uploader)', () {
    test('rule: server verdict first, then approver, then uploader by id — never by name', () {
      SeparationDocumentModel d(Map<String, dynamic> j) => SeparationDocumentModel.fromJson(j);
      expect(canDeleteSeparationDocument(d(doc('a', 'Hema HR')), isApprover: true, currentUserId: 'u-me'), isTrue);
      // Name matches the user, but no id: not recognised as the uploader.
      expect(canDeleteSeparationDocument(d(doc('a', 'Mira Owner')), isApprover: false, currentUserId: 'u-me'), isFalse);
      expect(canDeleteSeparationDocument(d(doc('a', 'x', uploadedBy: 'u-me')), isApprover: false, currentUserId: 'u-me'),
          isTrue);
      expect(canDeleteSeparationDocument(d(doc('a', 'x', uploadedBy: 'u-hr')), isApprover: false, currentUserId: 'u-me'),
          isFalse);
      expect(canDeleteSeparationDocument(d(doc('a', 'x', uploadedBy: 'u-me')), isApprover: false, currentUserId: null),
          isFalse);
      expect(canDeleteSeparationDocument(d(doc('a', 'x', canDelete: false)), isApprover: true, currentUserId: 'u-me'),
          isFalse);
      expect(canDeleteSeparationDocument(d(doc('a', 'x', canDelete: true)), isApprover: false, currentUserId: 'u-me'),
          isTrue);
      expect(d(doc('a', 'x', uploadedBy: 42)).uploadedById, '42');
      expect(d(doc('a', 'x')).uploadedById, isNull);
      expect(d(doc('a', 'x')).canDelete, isNull);
    });

    testWidgets('separation owner (not an approver): may upload, but no Delete on any document', (tester) async {
      await pump(tester, documents(canUpload: true));
      expect(find.text('Attach Document'), findsOneWidget);
      expect(find.textContaining('Hema HR'), findsWidgets);
      expect(find.textContaining('Mira Owner'), findsWidgets);
      expect(deleteButtons, findsNothing);
    });

    testWidgets('uploader recognised by the server\'s id: Delete only on their own upload', (tester) async {
      await pump(tester, documents(canUpload: true), setup: (s) {
        s.docs = [doc('d1', 'Hema HR', uploadedBy: 'u-hr'), doc('d2', 'Mira Owner', uploadedBy: 'u-me')];
      });
      expect(deleteButtons, findsOneWidget);
      await tester.tap(deleteButtons);
      await tester.pumpAndSettle();
      expect(server.writes.single.$1, 'DELETE');
      expect(server.writes.single.$2, '/separation/requests/$reqId/documents/d2/');
    });

    testWidgets('approver: Delete on every document; server refusal shown', (tester) async {
      await pump(tester, documents(canUpload: true, isApprover: true),
          setup: (s) => s.refuse = 'You do not have access to this separation request.');
      expect(deleteButtons, findsNWidgets(2));
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();
      expect(server.writes.single.$2, '/separation/requests/$reqId/documents/d1/');
      expect(find.text('You do not have access to this separation request.'), findsOneWidget);
    });

    testWidgets('server can_delete wins over the local rule', (tester) async {
      await pump(tester, documents(canUpload: true, isApprover: true), setup: (s) {
        s.docs = [doc('d1', 'Hema HR', canDelete: false), doc('d2', 'Mira Owner', canDelete: true)];
      });
      expect(deleteButtons, findsOneWidget);
    });

    testWidgets('non-approver on another\'s separation: no upload, no delete', (tester) async {
      await pump(tester, documents(canUpload: false));
      expect(find.text('Attach Document'), findsNothing);
      expect(deleteButtons, findsNothing);
    });
  });
}
