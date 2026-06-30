import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/candidate_entity.dart';
import '../providers/interview_providers.dart';
import '../widgets/candidate_card.dart';
import '../widgets/add_candidate_sheet.dart';

part '../widgets/interview_list_widgets.dart';

class InterviewListScreen extends ConsumerWidget {
  const InterviewListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(candidateStatsProvider);
    final listAsync = ref.watch(candidateListProvider);
    final filtered = ref.watch(filteredCandidatesProvider);
    final statusFilter = ref.watch(candidateStatusFilterProvider);
    final search = ref.watch(candidateSearchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.read(candidateListProvider.notifier).refresh();
          ref.read(candidateStatsProvider.notifier).refresh();
        },
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(child: _Header()),

            // ── Stats ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: statsAsync.when(
                loading: () => const _StatsShimmer(),
                error: (_, __) => const SizedBox.shrink(),
                data: (s) => _StatsRow(stats: s),
              ),
            ),

            // ── Info banner ───────────────────────────────────────────
            const SliverToBoxAdapter(child: _InfoBanner()),

            // ── Search + filter ───────────────────────────────────────
            SliverToBoxAdapter(
              child: _SearchFilter(
                statusFilter: statusFilter,
                search: search,
              ),
            ),

            // ── List ─────────────────────────────────────────────────
            listAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: _ErrorView(
                  message: e.toString(),
                  onRetry: () =>
                      ref.invalidate(candidateListProvider),
                ),
              ),
              data: (_) => filtered.isEmpty
                  ? SliverFillRemaining(child: _EmptyView())
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: CandidateCard(candidate: filtered[i]),
                          ),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const AddCandidateSheet(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Candidate'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
