import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/data/services/profile_document_viewer.dart';
import '../../../profile/presentation/providers/profile_document_cleanup.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/training_providers.dart';

/// In-app, read-only view of a training PDF (web PdfFrame).
///
/// Storage safety — same rules as the profile document viewer:
///  - the file is fetched with the user's login, checked to really be a PDF
///    (content type, file format and the bytes' %PDF- signature);
///  - it is written only to the app-private temporary folder
///    (`profile_docs/training-material.pdf`, no title or id in the name) and
///    opened with PdfDocument.openFile — not openData, which leaves an
///    undeleted copy in the Android cache;
///  - the copy is deleted when the view closes, before every new view, at
///    app start and at sign-out (the view registers with
///    DocumentViewerRegistry so sign-out closes it first).
/// Nothing is shared with another app and nothing goes to public storage.
/// Fetching the file records no learner progress.
class TrainingPdfView extends ConsumerStatefulWidget {
  const TrainingPdfView({super.key, required this.materialId, this.fileFormat = 'pdf'});
  final String materialId;
  final String fileFormat;

  @override
  ConsumerState<TrainingPdfView> createState() => _TrainingPdfViewState();
}

class _TrainingPdfViewState extends ConsumerState<TrainingPdfView> {
  PdfControllerPinch? _controller;
  File? _file;
  String? _error;
  Object? _registration;
  late final ProfileDocumentTempStore _store = ref.read(profileDocumentTempStoreProvider);
  late final DocumentViewerRegistry _registry = ref.read(documentViewerRegistryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    File? target;
    try {
      await _store.clearAll();
      final file = await ref.read(trainingDatasourceProvider).fetchMaterialFile(widget.materialId);
      final kind = resolveDocumentKind(
        contentType: file.contentType,
        fileNames: ['material.${widget.fileFormat}'],
        bytes: file.bytes,
      );
      if (file.bytes.isEmpty || kind != DocumentKind.pdf) {
        if (mounted) setState(() => _error = 'The document could not be shown.');
        return;
      }
      target = await _store.trainingPdfFile();
      await target.writeAsBytes(file.bytes, flush: true);
      if (!mounted) {
        await _store.deleteFile(target);
        return;
      }
      _file = target;
      _registration = _registry.register(_closeForSignOut);
      setState(() => _controller = PdfControllerPinch(document: PdfDocument.openFile(target!.path)));
    } catch (e) {
      if (target != null) await _store.deleteFile(target);
      if (mounted) setState(() => _error = 'The document could not be shown. ${userFriendlyMessage(e)}');
    }
  }

  Future<void> _release() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      final doc = c.document;
      c.dispose();
      try {
        await (await doc).close();
      } catch (_) {}
    }
    final f = _file;
    _file = null;
    if (f != null) await _store.deleteFile(f);
  }

  /// Sign-out: take the document off screen, then delete the copy.
  Future<void> _closeForSignOut() async {
    if (mounted) setState(() => _error = 'Signed out.');
    await _release();
  }

  @override
  void dispose() {
    final reg = _registration;
    if (reg != null) _registry.unregister(reg);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.error)),
      );
    }
    final c = _controller;
    if (c == null) {
      return Center(
        child: Semantics(label: 'Loading document', child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return PdfViewPinch(
      controller: c,
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
        pageLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, __) => Center(
          child: Text('The document could not be shown.', style: TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }
}
