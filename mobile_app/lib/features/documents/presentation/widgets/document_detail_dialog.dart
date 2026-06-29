import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/document_entity.dart';
import '../providers/document_providers.dart';
import 'document_type_helpers.dart';

class DocumentDetailDialog extends ConsumerStatefulWidget {
  final DocumentEntity document;
  const DocumentDetailDialog({super.key, required this.document});

  @override
  ConsumerState<DocumentDetailDialog> createState() =>
      _DocumentDetailDialogState();
}

class _DocumentDetailDialogState
    extends ConsumerState<DocumentDetailDialog> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Row(
              children: [
                const Icon(Icons.folder_open_outlined,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    doc.title,
                    style: AppTextStyles.label.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          // ── Body ───────────────────────────────────────────────────────────
          Container(
            color: AppColors.background,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── File preview area ─────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: documentTypeColor(doc.fileType)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            documentTypeIcon(doc.fileType),
                            size: 32,
                            color: documentTypeColor(doc.fileType),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          doc.fileName,
                          style: AppTextStyles.label
                              .copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${doc.fileType} · ${doc.fileSizeDisplay}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Metadata ──────────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _MetaRow(
                            icon: Icons.category_outlined,
                            label: 'Category',
                            value: doc.categoryDisplay),
                        const Divider(height: 1, color: AppColors.border),
                        _MetaRow(
                            icon: Icons.person_outline,
                            label: 'Uploaded by',
                            value: doc.uploadedByName),
                        const Divider(height: 1, color: AppColors.border),
                        _MetaRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Upload date',
                            value: formatDocDate(doc.uploadedAt)),
                        const Divider(height: 1, color: AppColors.border),
                        const _MetaRow(
                            icon: Icons.groups_outlined,
                            label: 'Access',
                            value: 'All Employees'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  _actionButtons(doc.fileUrl),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(String fileUrl) {
    final btnShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10));
    return Row(
      children: [
        SizedBox(
          height: 42,
          child: FilledButton.icon(
            onPressed: _deleting ? null : _confirmDelete,
            icon: _deleting
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: AppTextStyles.labelSmall,
              shape: btnShape,
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 42,
          child: OutlinedButton.icon(
            onPressed: () => _openUrl(fileUrl),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('Preview'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: AppTextStyles.labelSmall,
              shape: btnShape,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 42,
          child: FilledButton.icon(
            onPressed: () => _openUrl(fileUrl),
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Download'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: AppTextStyles.labelSmall,
              shape: btnShape,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Confirm Delete'),
        content: Text(
          'Delete "${widget.document.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    final error = await ref
        .read(documentListProvider.notifier)
        .remove(widget.document.id);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (error == null) {
      ref.read(documentStatsProvider.notifier).refresh();
      Navigator.pop(context);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.labelSmall
                  .copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
