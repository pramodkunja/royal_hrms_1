import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../../../shared/widgets/expandable_fab.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../domain/entities/candidate_entity.dart';
import '../providers/interview_providers.dart';
import '../widgets/candidate_card.dart';
import '../widgets/add_candidate_sheet.dart';

part '../widgets/interview_list_widgets.dart';

class InterviewListScreen extends ConsumerStatefulWidget {
  const InterviewListScreen({super.key});

  @override
  ConsumerState<InterviewListScreen> createState() =>
      _InterviewListScreenState();
}

class _InterviewListScreenState extends ConsumerState<InterviewListScreen> {
  bool _fabExpanded = false;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(candidateStatsProvider);
    final listAsync = ref.watch(candidateListProvider);
    final filtered = ref.watch(filteredCandidatesProvider);
    final statusFilter = ref.watch(candidateStatusFilterProvider);
    final search = ref.watch(candidateSearchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.read(candidateListProvider.notifier).refresh();
              ref.read(candidateStatsProvider.notifier).refresh();
            },
            child: CustomScrollView(
              slivers: [
                // ── Search + filter (hero first — no separate "Interview
                // List" title here anymore, that duplicated the app bar's
                // own title) ───────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _SearchFilter(
                    statusFilter: statusFilter,
                    search: search,
                  ),
                ),

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

                // ── List ─────────────────────────────────────────────────
                listAsync.when(
                  loading: () => SliverFillRemaining(
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    child: _ErrorView(
                      message: e.toString(),
                      onRetry: () => ref.invalidate(candidateListProvider),
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
          ExpandableFabBarrier(
            visible: _fabExpanded,
            onDismiss: () => setState(() => _fabExpanded = false),
          ),
        ],
      ),
      floatingActionButton: ExpandableFab(
        heroTag: 'interview_list_fab',
        expanded: _fabExpanded,
        onToggle: () => setState(() => _fabExpanded = !_fabExpanded),
        actions: [
          ExpandableFabAction(
            icon: Icons.upload_file_outlined,
            label: 'Bulk Import',
            onTap: () {
              setState(() => _fabExpanded = false);
              context.push(AppRoutes.candidateBulkImport);
            },
          ),
          ExpandableFabAction(
            icon: Icons.person_add_outlined,
            label: 'Add Candidate',
            onTap: () {
              setState(() => _fabExpanded = false);
              showDialog(
                context: context,
                builder: (_) => const AddCandidateDialog(),
              );
            },
          ),
        ],
      ),
    );
  }
}
