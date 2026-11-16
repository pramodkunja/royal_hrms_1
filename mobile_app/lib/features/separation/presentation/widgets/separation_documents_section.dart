import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/documents/document_links.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/separation_entity.dart';
import '../providers/separation_providers.dart';
import 'separation_status.dart';
import 'package:mobile_app/core/network/api_client.dart';

const _kMaxDocBytes = 5 * 1024 * 1024;
const _kAllowedDocExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

// Matches SEP_DOCUMENT_TYPE_CHOICES (apps/hrms/models.py) exactly.
const _kDocumentTypes = [
  ('resignation_letter', 'Resignation Letter'),
  ('relieving_letter', 'Relieving Letter'),
  ('experience_letter', 'Experience Letter'),
  ('full_final_statement', 'Full & Final Statement'),
  ('nda', 'NDA / Undertaking'),
  ('other', 'Other'),
];

/// Whether [doc] may be deleted, by the backend's rule
/// (SeparationDocumentDetailView.delete): a separation approver (within the
/// request's visibility, checked by the server), or the person who uploaded
/// it. The server's own `can_delete` wins when it sends one; the uploader is
/// recognised only by user id (`uploaded_by`) — never by name. Owning the
/// separation request alone is not enough.
bool canDeleteSeparationDocument(
  SeparationDocumentEntity doc, {
  required bool isApprover,
  required String? currentUserId,
}) {
  if (doc.canDelete != null) return doc.canDelete!;
  if (isApprover) return true;
  return doc.uploadedById != null && currentUserId != null && doc.uploadedById == currentUserId;
}

/// Document list + upload — separate from the one optional document
/// attached at request-creation time (shown in the Separation Details
/// section instead). Upload is for the owner or an approver (backend
/// SeparationDocumentListCreateView.post); Delete follows
/// [canDeleteSeparationDocument].
class SeparationDocumentsSection extends ConsumerStatefulWidget {
  final String requestId;
  final bool canUpload;

  /// separation.approve by the backend's has_perm (superuser / settings.edit pass).
  final bool isApprover;
  final String? currentUserId;
  const SeparationDocumentsSection({
    super.key,
    required this.requestId,
    required this.canUpload,
    this.isApprover = false,
    this.currentUserId,
  });

  @override
  ConsumerState<SeparationDocumentsSection> createState() =>
      _SeparationDocumentsSectionState();
}

class _SeparationDocumentsSectionState
    extends ConsumerState<SeparationDocumentsSection> {
  bool _uploading = false;

  void _showError(String err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _upload() async {
    final docType = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text('Select Document Type',
                style: AppTextStyles.label.copyWith(fontSize: 13)),
            const SizedBox(height: 6),
            for (final (value, label) in _kDocumentTypes)
              ListTile(
                dense: true,
                title: Text(label, style: AppTextStyles.body.copyWith(fontSize: 13)),
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (docType == null || !mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kAllowedDocExtensions,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.size > _kMaxDocBytes) {
      _showError('File exceeds 5 MB.');
      return;
    }

    setState(() => _uploading = true);
    final err = await ref.read(separationActionsProvider).uploadDocument(
          requestId: widget.requestId,
          documentType: docType,
          file: file,
        );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (err != null) _showError(err);
  }

  bool _canDelete(SeparationDocumentEntity doc) =>
      canDeleteSeparationDocument(doc, isApprover: widget.isApprover, currentUserId: widget.currentUserId);

  Future<void> _delete(SeparationDocumentEntity doc) async {
    if (!_canDelete(doc)) return;
    final err = await ref.read(separationActionsProvider).deleteDocument(
          requestId: widget.requestId,
          documentId: doc.id,
        );
    if (err != null) _showError(err);
  }

  // Web DocumentsSection: a plain link opening in a new tab.
  Future<void> _open(String url) => openDocumentLinkExternally(context, ref, url);

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(separationDocumentsProvider(widget.requestId));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SeparationSectionHeader(title: 'Documents'),
          docsAsync.when(
            data: (docs) => docs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('No documents attached yet.',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textHint)),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < docs.length; i++) ...[
                        if (i > 0) Divider(height: 16, color: AppColors.border),
                        _DocRow(
                          doc: docs[i],
                          canDelete: _canDelete(docs[i]),
                          onOpen: docs[i].fileUrl == null
                              ? null
                              : () => _open(docs[i].fileUrl!),
                          onDelete: () => _delete(docs[i]),
                        ),
                      ],
                      const SizedBox(height: 10),
                    ],
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (e, __) => Text(userFriendlyMessage(e),
                style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
          if (widget.canUpload)
            AppButton(
              label: 'Attach Document',
              variant: AppButtonVariant.outline,
              leadingIcon: Icons.attach_file,
              isLoading: _uploading,
              onPressed: _upload,
            ),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final SeparationDocumentEntity doc;
  final bool canDelete;
  final VoidCallback? onOpen;
  final VoidCallback onDelete;
  const _DocRow({
    required this.doc,
    required this.canDelete,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Row(
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 22, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(doc.documentTypeDisplay,
                    style: AppTextStyles.label.copyWith(fontSize: 13)),
                Text(
                  [
                    if (doc.uploadedByName.isNotEmpty) doc.uploadedByName,
                    formatSeparationDate(doc.createdAt),
                  ].join(' · '),
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 17, color: AppColors.error),
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
