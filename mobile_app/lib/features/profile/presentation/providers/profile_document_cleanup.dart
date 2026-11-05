import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import 'profile_providers.dart';

/// The document viewers currently open. When the session ends, each one is
/// closed — content removed from the screen, PDF closed, image dropped, route
/// gone — before any temporary file is deleted.
class DocumentViewerRegistry {
  final _closers = <Object, Future<void> Function()>{};

  bool get hasOpenViewer => _closers.isNotEmpty;

  /// [close] tears the viewer down; returns a token for [unregister].
  Object register(Future<void> Function() close) {
    final token = Object();
    _closers[token] = close;
    return token;
  }

  void unregister(Object token) => _closers.remove(token);

  /// Closes every open viewer, one after another. Never throws.
  Future<void> closeAll() async {
    for (final close in _closers.values.toList()) {
      try {
        await close();
      } catch (_) {
        // A viewer that fails to close still must not block the cleanup.
      }
    }
    _closers.clear();
  }
}

final documentViewerRegistryProvider = Provider<DocumentViewerRegistry>((ref) => DocumentViewerRegistry());

/// Watched once by the app root. Clears every temporary profile document
/// copy (and pdfx page images):
///  - at app start — no document viewer can be open yet;
///  - whenever the signed-in user goes away or changes (sign-out, an expired
///    session — which signs out — or another user signing in). Any open
///    viewer is closed first, then the files are deleted.
/// It only listens to the sign-in state; it never changes it.
final profileDocumentSessionCleanupProvider = Provider<void>((ref) {
  final store = ref.watch(profileDocumentTempStoreProvider);
  final viewers = ref.watch(documentViewerRegistryProvider);

  // Runs one after another, so a second sign-out never overlaps the first.
  var chain = Future<void>.value();
  void enqueue(Future<void> Function() step) {
    chain = chain.then((_) => step()).catchError((_) {});
  }

  enqueue(store.clearAll);
  ref.listen(authStateProvider, (previous, next) {
    final before = previous?.valueOrNull?.user?.id;
    final after = next.valueOrNull?.user?.id;
    if (before == null || before == after) return;
    enqueue(() async {
      await viewers.closeAll();
      await store.clearAll();
    });
  });
});
