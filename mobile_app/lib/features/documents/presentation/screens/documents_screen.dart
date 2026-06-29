import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/document_entity.dart';
import '../providers/document_providers.dart';
import '../widgets/document_card.dart';
import '../widgets/document_detail_dialog.dart';
import '../widgets/document_filter_bar.dart';
import '../widgets/document_list_states.dart';
import '../widgets/document_stats_row.dart';
import '../widgets/document_upload_dialog.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(documentStatsProvider);
    final docsAsync = ref.watch(documentListProvider);
    final filtered = ref.watch(filteredDocumentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await Future.wait([
            ref.read(documentStatsProvider.notifier).refresh(),
            ref.read(documentListProvider.notifier).refresh(),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            // ── Title + Upload button ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Document Center',
                        style: AppTextStyles.h4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _openUpload(context),
                      icon: const Icon(Icons.upload_file_outlined, size: 16),
                      label: const Text('Upload'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: AppTextStyles.labelSmall
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Stats ────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: statsAsync.when(
                loading: () => const DocumentStatsRowShimmer(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => DocumentStatsRow(stats: stats),
              ),
            ),

            // ── Filter bar ───────────────────────────────────────────────────
            const SliverToBoxAdapter(child: DocumentFilterBar()),

            // ── Document grid or states ──────────────────────────────────────
            docsAsync.when(
              loading: () => _loadingGrid(),
              error: (e, _) => SliverToBoxAdapter(
                child: DocumentErrorView(
                  message: e.toString(),
                  onRetry: () {
                    ref.invalidate(documentListProvider);
                    ref.invalidate(documentStatsProvider);
                  },
                ),
              ),
              data: (_) {
                if (filtered.isEmpty) {
                  return SliverToBoxAdapter(
                    child: DocumentEmptyView(
                        onUpload: () => _openUpload(context)),
                  );
                }
                return _DocumentGrid(
                  documents: filtered,
                  onTap: (doc) => _openDetail(context, doc),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  void _openUpload(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: DocumentUploadDialog(),
      ),
    );
  }

  void _openDetail(BuildContext context, DocumentEntity doc) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: DocumentDetailDialog(document: doc),
      ),
    );
  }

  SliverPadding _loadingGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, __) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          childCount: 2,
        ),
      ),
    );
  }
}

class _DocumentGrid extends StatelessWidget {
  final List<DocumentEntity> documents;
  final void Function(DocumentEntity) onTap;

  const _DocumentGrid({required this.documents, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rowCount = (documents.length / 2).ceil();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, rowIndex) {
            final left = rowIndex * 2;
            final right = left + 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: DocumentCard(
                        document: documents[left],
                        onTap: () => onTap(documents[left]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    right < documents.length
                        ? Expanded(
                            child: DocumentCard(
                              document: documents[right],
                              onTap: () => onTap(documents[right]),
                            ),
                          )
                        : const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            );
          },
          childCount: rowCount,
        ),
      ),
    );
  }
}
