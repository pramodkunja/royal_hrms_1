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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openUpload(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text(
          'Upload',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
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
            // ── Title ────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Document Center',
                  style: AppTextStyles.h4,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, __) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          childCount: 3,
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
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DocumentCard(
              document: documents[index],
              onTap: () => onTap(documents[index]),
            ),
          ),
          childCount: documents.length,
        ),
      ),
    );
  }
}
