import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/data/services/profile_document_viewer.dart';
import '../../../profile/presentation/providers/profile_providers.dart' show profileDocumentTempStoreProvider;
import '../../../profile/presentation/screens/profile_document_viewer_screen.dart';
import '../providers/employee_providers.dart';

/// Downloads an employee file ([url]: a signed file-host link, or a link on
/// the API's own server) and shows it in the app's document viewer — as web
/// DocPreviewModal. Shared by Employee Profile → Documents and the
/// file-type custom fields (Task 54/57). See EmployeeDocumentDownloader for
/// which client fetches what (the app's login never goes to another host)
/// and ProfileDocumentViewer for the format checks and temporary copies.
///
/// [freshUrl] supplies a new link when the file host refuses an expired
/// one; without it an expired link is reported as such.
///
/// Returns a message to show when the file couldn't be opened, otherwise
/// null (opened, or abandoned because the screen closed or the signed-in
/// user changed meanwhile — then nothing is shown and any copy is released).
Future<String?> openEmployeeFileInApp(
  BuildContext context,
  WidgetRef ref, {
  required int id,
  required String url,
  required String fileName,
  required String title,
  Future<String?> Function()? freshUrl,
}) async {
  String? signedInUser() => ref.read(authStateProvider).valueOrNull?.user?.id;
  final user = signedInUser();
  final downloader = ref.read(employeeDocumentDownloaderProvider);
  final viewer = ProfileDocumentViewer(
    download: (_) => freshUrl == null
        ? downloader.download(url, fileName: fileName)
        : downloader.downloadWithRefresh(url, fileName: fileName, freshUrl: freshUrl),
    store: ref.read(profileDocumentTempStoreProvider),
  );
  final outcome = await viewer.load(id, knownFileName: fileName);
  if (!context.mounted || user == null || signedInUser() != user) {
    if (outcome is ProfileDocumentReady) await outcome.release();
    return null;
  }
  switch (outcome) {
    case DocumentViewFailed(:final message):
      return message;
    case ProfileDocumentReady():
      // The viewer screen deletes the temporary copy when it closes.
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ProfileDocumentViewerScreen(document: outcome, title: title),
      ));
      return null;
  }
}

/// One uploaded file of a file-type custom field: its name and size, View
/// (in-app, with a spinner while downloading), an optional [trailing]
/// action (e.g. Remove) and, when it can't be opened, the reason with Retry.
class EmployeeFileTile extends ConsumerStatefulWidget {
  const EmployeeFileTile({
    super.key,
    required this.id,
    required this.url,
    required this.fileName,
    required this.title,
    this.fileSize = 0,
    this.freshUrl,
    this.trailing,
  });

  final int id;
  final String url;
  final String fileName;
  final String title;
  final int fileSize;
  final Future<String?> Function()? freshUrl;
  final Widget? trailing;

  @override
  ConsumerState<EmployeeFileTile> createState() => _EmployeeFileTileState();
}

class _EmployeeFileTileState extends ConsumerState<EmployeeFileTile> {
  bool _opening = false;
  String? _error;

  Future<void> _open() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    final message = await openEmployeeFileInApp(
      context,
      ref,
      id: widget.id,
      url: widget.url,
      fileName: widget.fileName,
      title: widget.title,
      freshUrl: widget.freshUrl,
    );
    if (!mounted) return;
    setState(() {
      _opening = false;
      _error = message;
    });
  }

  static String _size(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final canView = widget.url.trim().isNotEmpty;
    final size = _size(widget.fileSize);
    return Column(
      key: Key('custom-file-${widget.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: canView && !_opening ? _open : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  size.isEmpty ? widget.fileName : '${widget.fileName} · $size',
                  style: AppTextStyles.bodySmall.copyWith(color: canView ? AppColors.primary : null),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          if (_opening)
            const Padding(
              key: Key('custom-file-opening'),
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              key: Key('custom-file-view-${widget.id}'),
              tooltip: canView ? 'View' : 'No file to view',
              icon: Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
              onPressed: canView ? _open : null,
              visualDensity: VisualDensity.compact,
            ),
          if (widget.trailing != null) widget.trailing!,
        ]),
        if (_error != null)
          Padding(
            key: Key('custom-file-error-${widget.id}'),
            padding: const EdgeInsets.only(left: 26, bottom: 4),
            child: Row(children: [
              Expanded(child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error))),
              TextButton(
                key: Key('custom-file-retry-${widget.id}'),
                onPressed: _opening ? null : _open,
                child: const Text('Retry'),
              ),
            ]),
          ),
      ],
    );
  }
}
