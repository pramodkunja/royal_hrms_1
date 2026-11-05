import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../onboarding/data/models/onboarding_config_models.dart';
import '../../../onboarding/presentation/widgets/onboarding_custom_file_field.dart' show onboardingFilePickerProvider;
import '../../data/models/profile_document_model.dart';
import '../../data/models/profile_document_rows.dart';
import '../../data/services/profile_document_viewer.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../screens/profile_document_viewer_screen.dart';
import 'profile_widgets.dart';

// My Profile → Documents (web: ProfileClient.tsx "Documents" tab). One row
// per configured document type, uploaded or not; the employee can upload a
// missing document or replace their current one (a single-file type asks
// first), or add another file to a type that allows several. Types the admin
// no longer offers stay listed, read-only. Uploads go to the employee's own
// profile only (profileDocumentUploadProvider). View downloads the file with
// the employee's login and shows it inside the app
// (profileDocumentViewerProvider, ProfileDocumentViewerScreen); no other app
// is given the file.

/// Shown above the rows whenever a document can be viewed.
const kInAppViewerNotice = 'Documents open inside Royal HRMS and are not shared with other apps. '
    'Temporary copies are deleted when you close them or sign out.';

String _fmtDate(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return '';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final local = dt.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

String _fmtFileSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _fileSubtitle(ProfileDocumentModel f) =>
    [_fmtDate(f.uploadedAt), _fmtFileSize(f.fileSize)].where((s) => s.isNotEmpty).join(' · ');

class ProfileDocumentsSection extends ConsumerStatefulWidget {
  const ProfileDocumentsSection({super.key});

  @override
  ConsumerState<ProfileDocumentsSection> createState() => _ProfileDocumentsSectionState();
}

class _ProfileDocumentsSectionState extends ConsumerState<ProfileDocumentsSection> {
  /// Documents being downloaded/opened (one at a time per document).
  final Set<int> _viewing = {};

  Future<void> _view(ProfileDocumentModel file, String title) async {
    if (file.id <= 0 || _viewing.contains(file.id)) return;
    String? signedInUser() => ref.read(authStateProvider).valueOrNull?.user?.id;
    final user = signedInUser();
    setState(() => _viewing.add(file.id));
    final outcome = await ref.read(profileDocumentViewerProvider).load(file.id, knownFileName: file.fileName);
    // Gone, or the session ended / changed while loading: never show it.
    if (!mounted || user == null || signedInUser() != user) {
      if (outcome is ProfileDocumentReady) await outcome.release();
      if (mounted) setState(() => _viewing.remove(file.id));
      return;
    }
    setState(() => _viewing.remove(file.id));
    switch (outcome) {
      case DocumentViewFailed(:final message):
        _snack(message, isError: true);
      case ProfileDocumentReady():
        // The viewer screen deletes the temporary copy when it closes.
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ProfileDocumentViewerScreen(document: outcome, title: title),
        ));
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<bool> _confirmReplace(ProfileDocumentRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('replace-document-dialog'),
        title: const Text('Replace document?'),
        content: Text('Your current ${row.label} will be replaced by the file you choose. '
            'The current file is removed once the new one is saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Replace')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _upload(ProfileDocumentRow row) async {
    if (!row.canUpload) return;
    if (ref.read(profileDocumentUploadProvider).contains(row.documentType)) return;
    if (row.replaceNeedsConfirmation && !await _confirmReplace(row)) return;
    if (!mounted) return;
    final picked = await ref.read(onboardingFilePickerProvider)();
    if (!mounted || picked == null) return;
    final bytes = picked.bytes;
    // Checked here too so a refused file never shows as uploading.
    final problem = bytes == null ? 'Could not read the file.' : onboardingUploadError(picked.name, bytes.length);
    if (problem != null) {
      _snack(problem, isError: true);
      return;
    }
    final outcome = await ref
        .read(profileDocumentUploadProvider.notifier)
        .upload(row, ProfileUploadFile(name: picked.name, bytes: bytes!));
    switch (outcome) {
      case DocumentUploadSucceeded():
        _snack('Document uploaded successfully.');
      case DocumentUploadFailed(:final message):
        _snack(message, isError: true);
      case DocumentUploadIgnored():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = ref.watch(profileDocumentListingProvider);
    final uploading = ref.watch(profileDocumentUploadProvider);
    return ProfileSectionCard(
      icon: Icons.folder_outlined,
      title: 'Documents',
      child: listing.when(
        // Keep showing the current rows while the list reloads.
        skipLoadingOnReload: true,
        data: (l) {
          if (l.rows.isEmpty) {
            return Text('No documents uploaded yet.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint));
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (l.rows.any((r) => r.uploaded))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(kInAppViewerNotice,
                        key: const Key('doc-viewer-notice'),
                        style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                  ),
                ]),
              ),
            for (var i = 0; i < l.rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.border),
              _DocumentRow(
                key: ValueKey('doc-row-${l.rows[i].documentType}'),
                row: l.rows[i],
                uploading: uploading.contains(l.rows[i].documentType),
                onUpload: () => _upload(l.rows[i]),
                viewing: _viewing,
                onView: _view,
              ),
            ],
          ]);
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(friendlyProfileError(e), style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          TextButton(
            onPressed: () {
              ref.invalidate(myDocumentsProvider);
              ref.invalidate(myDocumentTypesProvider);
            },
            child: const Text('Retry'),
          ),
        ]),
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  final ProfileDocumentRow row;
  final bool uploading;
  final VoidCallback onUpload;
  final Set<int> viewing;
  final Future<void> Function(ProfileDocumentModel file, String title) onView;

  const _DocumentRow({
    super.key,
    required this.row,
    required this.uploading,
    required this.onUpload,
    required this.viewing,
    required this.onView,
  });

  Widget _viewAction(ProfileDocumentModel f) => _IconAction(
        key: ValueKey('doc-view-${f.id}'),
        tooltip: 'View ${row.label}',
        icon: Icons.visibility_outlined,
        busy: viewing.contains(f.id),
        onTap: f.id <= 0 || viewing.contains(f.id) ? null : () => onView(f, row.label),
      );

  String get _status {
    if (uploading) return 'Uploading…';
    if (!row.uploaded) return 'Not uploaded';
    if (!row.allowMultiple) return _fileSubtitle(row.latest!);
    return row.files.length == 1 ? '1 file' : '${row.files.length} files';
  }

  @override
  Widget build(BuildContext context) {
    final String actionTooltip;
    final IconData actionIcon;
    if (!row.uploaded) {
      actionTooltip = 'Upload ${row.label}';
      actionIcon = Icons.upload_outlined;
    } else if (row.allowMultiple) {
      actionTooltip = 'Add another ${row.label}';
      actionIcon = Icons.add;
    } else {
      actionTooltip = 'Replace ${row.label}';
      actionIcon = Icons.sync;
    }
    final single = !row.allowMultiple && row.uploaded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (row.uploaded ? AppColors.success : AppColors.primary).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: uploading
                ? SizedBox(
                    key: const Key('doc-uploading'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : Icon(row.uploaded ? Icons.task_outlined : Icons.insert_drive_file_outlined,
                    size: 16, color: row.uploaded ? AppColors.success : AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(row.label,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                if (row.required && row.canUpload && !row.uploaded)
                  Text('Required', style: AppTextStyles.labelSmall.copyWith(color: AppColors.error)),
              ]),
              const SizedBox(height: 2),
              Text(_status, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              if (!row.canUpload)
                Text('No longer requested · view only',
                    key: const Key('doc-read-only'), style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
            ]),
          ),
          if (single) _viewAction(row.latest!),
          if (row.canUpload) ...[
            const SizedBox(width: 6),
            _IconAction(
              key: const Key('doc-upload-action'),
              tooltip: actionTooltip,
              icon: actionIcon,
              onTap: uploading ? null : onUpload,
            ),
          ],
        ]),
        if (row.allowMultiple)
          for (final f in row.files)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 8),
              child: Row(children: [
                Icon(Icons.description_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_fileSubtitle(f).isEmpty ? 'Uploaded file' : _fileSubtitle(f),
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ),
                _viewAction(f),
              ]),
            ),
      ]),
    );
  }
}

class _IconAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;

  const _IconAction({super.key, required this.tooltip, required this.icon, required this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.backgroundLow, borderRadius: BorderRadius.circular(8)),
            child: busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : Icon(icon, size: 16, color: enabled ? AppColors.textSecondary : AppColors.textHint),
          ),
        ),
      ),
    );
  }
}
