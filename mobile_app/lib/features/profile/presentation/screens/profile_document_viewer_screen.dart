import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/services/profile_document_viewer.dart';
import '../providers/profile_document_cleanup.dart';

// In-app viewer for the employee's own profile documents. The file stays
// inside the app. Closing this screen (Close, system Back) closes the PDF,
// drops the image from memory and deletes the temporary copy
// (ProfileDocumentReady.release).
//
// When the session ends (sign-out, expiry, another user) the viewer is closed
// by profileDocumentSessionCleanupProvider through DocumentViewerRegistry,
// before any file is deleted: the content is taken off the screen at once,
// the PDF document is closed, the route is removed and the copy released.

/// Collects the PDF view's close operations so the viewer can wait for them.
class PdfCloseTracker {
  final _pending = <Future<void>>[];

  void track(Future<void> closing) => _pending.add(closing.catchError((_) {}));

  /// Completes when every tracked close has finished (or after [limit]).
  Future<void> done({Duration limit = const Duration(seconds: 2)}) =>
      Future.wait(_pending).timeout(limit, onTimeout: () => const []);
}

/// Builds the PDF view for a temporary file. A provider so tests can supply
/// a stand-in (pdfx needs the platform renderer). The view must report the
/// closing of its document to [tracker] when it is disposed.
final profilePdfViewBuilderProvider = Provider<Widget Function(String pdfPath, PdfCloseTracker tracker)>(
  (ref) => (path, tracker) => _PdfxDocumentView(key: const Key('pdfx-view'), path: path, tracker: tracker),
);

class ProfileDocumentViewerScreen extends ConsumerStatefulWidget {
  const ProfileDocumentViewerScreen({super.key, required this.document, required this.title});

  final ProfileDocumentReady document;
  final String title;

  @override
  ConsumerState<ProfileDocumentViewerScreen> createState() => _ProfileDocumentViewerScreenState();
}

class _ProfileDocumentViewerScreenState extends ConsumerState<ProfileDocumentViewerScreen> {
  final _tracker = PdfCloseTracker();
  late final DocumentViewerRegistry _registry = ref.read(documentViewerRegistryProvider);
  late final Object _registration;

  /// True once the session has ended: nothing of the document is built.
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _registration = _registry.register(_closeForSessionEnd);
  }

  /// The image's decoded copy lives in Flutter's image cache; drop it too.
  void _evictImage() {
    final bytes = widget.document.imageBytes;
    if (bytes != null) MemoryImage(bytes).evict();
  }

  Future<void> _closeForSessionEnd() async {
    if (!mounted) return;
    // 1. Take the document off the screen: the PDF view is removed from the
    //    tree (its dispose closes the document) and the image is no longer
    //    built.
    setState(() => _hidden = true);
    await WidgetsBinding.instance.endOfFrame;
    await _tracker.done();
    // 2. Remove this route without an animation, and wait for the frame that
    //    unmounts it (its dispose also releases the document).
    if (mounted) {
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route);
        await WidgetsBinding.instance.endOfFrame;
      }
    }
    // 3. Drop the image and delete the temporary copy (no-op if done above).
    _evictImage();
    await widget.document.release();
  }

  @override
  void dispose() {
    _registry.unregister(_registration);
    // Children (the PDF view) are disposed first and close the document;
    // then the image is dropped and the temporary copy deleted.
    _evictImage();
    widget.document.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final Widget body;
    if (_hidden || doc.isReleased) {
      body = const SizedBox.expand(key: Key('viewer-closed'));
    } else if (doc.isPdf) {
      body = ref.read(profilePdfViewBuilderProvider)(doc.pdfPath!, _tracker);
    } else {
      body = InteractiveViewer(
        key: const Key('image-viewer'),
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image.memory(
            doc.imageBytes!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const _ViewerMessage(kDocumentOpenFailedMessage),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_hidden ? '' : widget.title, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(child: body),
    );
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            key: const Key('viewer-error'),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.surface),
          ),
        ),
      );
}

/// pdfx pinch-zoom view of a local PDF, opened read-only by path.
class _PdfxDocumentView extends StatefulWidget {
  const _PdfxDocumentView({super.key, required this.path, required this.tracker});
  final String path;
  final PdfCloseTracker tracker;

  @override
  State<_PdfxDocumentView> createState() => _PdfxDocumentViewState();
}

class _PdfxDocumentViewState extends State<_PdfxDocumentView> {
  late final PdfControllerPinch _controller = PdfControllerPinch(document: PdfDocument.openFile(widget.path));

  @override
  void dispose() {
    final document = _controller.document;
    _controller.dispose();
    // The controller does not close the document itself.
    widget.tracker.track(document.then((d) => d.close()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PdfViewPinch(
        controller: _controller,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
          pageLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, __) => const _ViewerMessage(kDocumentOpenFailedMessage),
        ),
      );
}
