import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/profile/data/services/profile_document_viewer.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_document_cleanup.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/features/profile/presentation/screens/profile_document_viewer_screen.dart';

// Phase 11.4 step 4: when the session ends (sign-out, expiry, another user)
// any open document viewer is closed — content off the screen, PDF closed,
// image dropped, route removed — and only then are temporary files deleted.
// Uses the real AuthNotifier (with a fake repository), so sign-out, session
// expiry and a new sign-in go through the app's own paths. Synthetic data.

UserEntity user(String id) => UserEntity(
      id: id,
      email: '$id@example.test',
      fullName: 'Test $id',
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: false,
      permissions: const [],
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.cached);
  UserEntity? cached;

  @override
  Future<UserEntity?> getCachedUser() async => cached;

  @override
  Future<UserEntity> login(String companyCode, String email, String password) async =>
      cached = user(email.split('@').first);

  @override
  Future<void> logout() async => cached = null;

  @override
  Future<void> clearSession() async => cached = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Records the order of events; deletes real (synthetic) files synchronously.
late List<String> log;
late Directory tmp;

class RecordingStore extends ProfileDocumentTempStore {
  RecordingStore() : super(tempRoot: () async => tmp);

  @override
  Future<void> clearAll() async {
    for (final name in [ProfileDocumentTempStore.folderName, ProfileDocumentTempStore.pdfxCacheFolder]) {
      final d = Directory('${tmp.path}/$name');
      if (d.existsSync()) {
        for (final f in d.listSync()) {
          f.deleteSync(recursive: true);
        }
      }
    }
    log.add('clear');
  }
}

/// A valid 1×1 PNG.
final tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
]);

/// Stand-in PDF view; its document "closes" a moment after disposal.
class FakePdfView extends StatefulWidget {
  const FakePdfView({super.key, required this.path, required this.tracker});
  final String path;
  final PdfCloseTracker tracker;

  @override
  State<FakePdfView> createState() => _FakePdfViewState();
}

class _FakePdfViewState extends State<FakePdfView> {
  @override
  void dispose() {
    widget.tracker.track(Future<void>.delayed(Duration.zero, () => log.add('pdf-closed')));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('PDF ${widget.path}', key: const Key('fake-pdf'));
}

late FakeAuthRepository repo;
late ProviderContainer container;
late WidgetTester t;

Future<void> pumpApp(WidgetTester tester, {UserEntity? signedIn}) async {
  t = tester;
  log = [];
  repo = FakeAuthRepository(signedIn ?? user('u1'));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      profileDocumentTempStoreProvider.overrideWithValue(RecordingStore()),
      profilePdfViewBuilderProvider.overrideWithValue(
        (path, tracker) => FakePdfView(path: path, tracker: tracker),
      ),
    ],
    child: MaterialApp(
      home: Consumer(builder: (context, ref, _) {
        // As in RoyalHrmsApp.
        ref.watch(profileDocumentSessionCleanupProvider);
        ref.watch(authStateProvider);
        return const Scaffold(body: Text('Home'));
      }),
    ),
  ));
  container = ProviderScope.containerOf(tester.element(find.text('Home')));
  await container.read(authStateProvider.future);
  await tester.pumpAndSettle();
  expect(log, ['clear']); // startup
  log.clear();
}

/// Whether any part of the viewer is in the tree. Uses Finder.evaluate()
/// (not tester.any, which may not run while a pump is in progress).
bool viewerVisible() => [
      find.byType(ProfileDocumentViewerScreen),
      find.byKey(const Key('fake-pdf')),
      find.byKey(const Key('image-viewer')),
    ].any((f) => f.evaluate().isNotEmpty);

/// A synthetic temporary PDF on disk plus a pdfx leftover.
File seedPdf(int id) {
  File('${tmp.path}/pdf_renderer_cache/page.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(tinyPng);
  return File('${tmp.path}/profile_docs/doc-$id.pdf')
    ..createSync(recursive: true)
    ..writeAsStringSync('%PDF-1.7 synthetic');
}

ProfileDocumentReady openPdf(int id) {
  final file = seedPdf(id);
  final doc = ProfileDocumentReady(
    documentId: id,
    kind: DocumentKind.pdf,
    pdfPath: file.path,
    release: () async {
      log.add('release(viewerVisible=${viewerVisible()})');
      if (file.existsSync()) file.deleteSync();
    },
  );
  _push(doc);
  return doc;
}

ProfileDocumentReady openImage(int id) {
  final doc = ProfileDocumentReady(
    documentId: id,
    kind: DocumentKind.png,
    imageBytes: Uint8List.fromList(tinyPng),
    release: () async => log.add('release(viewerVisible=${viewerVisible()})'),
  );
  _push(doc);
  return doc;
}

void _push(ProfileDocumentReady doc) {
  t.state<NavigatorState>(find.byType(Navigator)).push(MaterialPageRoute<void>(
        builder: (_) => ProfileDocumentViewerScreen(document: doc, title: 'Synthetic document'),
      ));
}

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
  await t.pumpAndSettle();
}

List<String> filesLeft() =>
    tmp.listSync(recursive: true).whereType<File>().map((f) => f.path.substring(tmp.path.length + 1)).toList();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => tmp = Directory.systemTemp.createTempSync('profile_docs_session'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('session end while a document is open', () {
    testWidgets('sign-out with a PDF open: viewer closed, PDF closed, then files deleted', (tester) async {
      await pumpApp(tester);
      final doc = openPdf(41);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-pdf')), findsOneWidget);
      expect(filesLeft(), unorderedEquals(['profile_docs/doc-41.pdf', 'pdf_renderer_cache/page.png']));

      await container.read(authStateProvider.notifier).logout();
      await settle();

      expect(viewerVisible(), isFalse);
      expect(find.text('Home'), findsOneWidget);
      expect(log, ['pdf-closed', 'release(viewerVisible=false)', 'clear']);
      expect(doc.isReleased, isTrue);
      expect(filesLeft(), isEmpty);
    });

    testWidgets('sign-out with an image open: viewer closed, image dropped and evicted, then cleared', (tester) async {
      await pumpApp(tester);
      final doc = openImage(7);
      await tester.pumpAndSettle();
      final bytes = doc.imageBytes!;
      expect(find.byKey(const Key('image-viewer')), findsOneWidget);
      expect(PaintingBinding.instance.imageCache.containsKey(MemoryImage(bytes)), isTrue);

      await container.read(authStateProvider.notifier).logout();
      await settle();

      expect(viewerVisible(), isFalse);
      expect(doc.imageBytes, isNull);
      expect(PaintingBinding.instance.imageCache.containsKey(MemoryImage(bytes)), isFalse);
      expect(log, ['release(viewerVisible=false)', 'clear']);
    });

    testWidgets('session expiry (refresh rejected) closes the viewer before cleanup', (tester) async {
      await pumpApp(tester);
      final doc = openPdf(42);
      await tester.pumpAndSettle();

      // What AuthInterceptor does when the refresh token is rejected.
      container.read(sessionExpiredProvider.notifier).state = true;
      await settle();

      expect(container.read(authStateProvider).valueOrNull?.user, isNull);
      expect(viewerVisible(), isFalse);
      expect(log, ['pdf-closed', 'release(viewerVisible=false)', 'clear']);
      expect(doc.isReleased, isTrue);
      expect(filesLeft(), isEmpty);
    });

    testWidgets("another user signing in closes the previous user's viewer and clears", (tester) async {
      await pumpApp(tester);
      final doc = openImage(8);
      await tester.pumpAndSettle();

      await container.read(authStateProvider.notifier).login('CO', 'u2@example.test', 'synthetic');
      await settle();

      expect(container.read(authStateProvider).valueOrNull?.user?.id, 'u2');
      expect(viewerVisible(), isFalse);
      expect(doc.isReleased, isTrue);
      expect(doc.imageBytes, isNull);
      expect(log, ['release(viewerVisible=false)', 'clear']);
    });

    testWidgets('with no viewer open, sign-out just clears; signing in does not', (tester) async {
      await pumpApp(tester, signedIn: null);
      repo.cached = null;
      await container.read(authStateProvider.notifier).login('CO', 'u1@example.test', 'synthetic');
      await settle();
      expect(log, isEmpty);
      await container.read(authStateProvider.notifier).logout();
      await settle();
      expect(log, ['clear']);
      expect(container.read(documentViewerRegistryProvider).hasOpenViewer, isFalse);
    });
  });

  group('normal navigation still works (no session cleanup)', () {
    testWidgets('Close button: PDF closed and released; still signed in; nothing cleared', (tester) async {
      await pumpApp(tester);
      final doc = openPdf(43);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await settle();
      expect(viewerVisible(), isFalse);
      expect(doc.isReleased, isTrue);
      expect(log, ['release(viewerVisible=false)', 'pdf-closed']);
      expect(filesLeft(), ['pdf_renderer_cache/page.png']); // only session end / start clears this
      expect(container.read(authStateProvider).valueOrNull?.user?.id, 'u1');
      expect(container.read(documentViewerRegistryProvider).hasOpenViewer, isFalse);
    });

    testWidgets('system Back with an image: dropped, evicted and released', (tester) async {
      await pumpApp(tester);
      final doc = openImage(9);
      await tester.pumpAndSettle();
      final bytes = doc.imageBytes!;
      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await settle();
      expect(viewerVisible(), isFalse);
      expect(doc.imageBytes, isNull);
      expect(PaintingBinding.instance.imageCache.containsKey(MemoryImage(bytes)), isFalse);
      expect(log, ['release(viewerVisible=false)']);
    });
  });

  group('viewer screen', () {
    testWidgets('an image that will not decode shows a message, and closing releases it', (tester) async {
      var released = 0;
      final doc = ProfileDocumentReady(
        documentId: 3,
        kind: DocumentKind.png,
        imageBytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]),
        release: () async => released++,
      );
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(home: ProfileDocumentViewerScreen(document: doc, title: 'Card')),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('viewer-error')), findsOneWidget);
      expect(find.text(kDocumentOpenFailedMessage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(released, 1);
    });
  });
}
