part of '../screens/interview_list_screen.dart';

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: AppColors.info),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Move candidates through the pipeline stages. '
                'Send portal login to selected candidates so they can fill their onboarding wizard.',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.info, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text('No candidates found',
              style:
                  AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message,
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final CandidateStatsEntity stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: StatCardRow(cards: [
        StatCard(
            icon: Icons.groups_outlined,
            count: stats.total,
            label: 'Total',
            color: AppColors.primary),
        StatCard(
            icon: Icons.access_time_outlined,
            count: stats.pending,
            label: 'Pending',
            color: AppColors.warning),
        StatCard(
            icon: Icons.how_to_reg_outlined,
            count: stats.selected,
            label: 'Selected',
            color: AppColors.success),
        StatCard(
            icon: Icons.person_off_outlined,
            count: stats.rejected,
            label: 'Rejected',
            color: AppColors.error),
      ]),
    );
  }
}

class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: List.generate(
          4,
          (_) => Expanded(
            child: Container(
              height: 80,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchFilter extends ConsumerWidget {
  final String statusFilter;
  final String search;
  const _SearchFilter({required this.statusFilter, required this.search});

  static const _tabs = [
    ('all', 'All'),
    ('pending', 'Pending'),
    ('selected', 'Selected'),
    ('rejected', 'Rejected'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(children: [
      BlueHeroBanner(
        child: TextField(
          onChanged: (v) =>
              ref.read(candidateSearchProvider.notifier).state = v,
          style: AppTextStyles.bodySmall,
          decoration:
              heroSearchFieldDecoration(hintText: 'Search candidate...'),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final (key, label) = _tabs[i];
            final isActive = statusFilter == key;
            return GestureDetector(
              onTap: () {
                // Status filtering is purely client-side (see
                // filteredCandidatesProvider), same as the search box just
                // above. Previously this also called
                // candidateListProvider.notifier.refresh(), which re-fetches
                // the *unfiltered* full list from the network on every tab
                // tap: it forces AsyncLoading() (wiping the already-correct
                // filtered result behind a spinner) and, on any transient
                // network hiccup, replaces the list with an error view —
                // making the tabs look broken/unresponsive instead of the
                // instant client-side filter switch they're meant to be.
                ref.read(candidateStatusFilterProvider.notifier).state = key;
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isActive ? AppColors.primary : AppColors.border),
                ),
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isActive ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
    ]);
  }
}
