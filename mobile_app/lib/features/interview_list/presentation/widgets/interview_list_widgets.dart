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
  const _EmptyView({this.branchName});

  /// Web: "No candidates in <branch>" when a branch is picked.
  final String? branchName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(branchName != null ? 'No candidates in $branchName' : 'No candidates found',
              style:
                  AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
        ],
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

class _SearchFilter extends ConsumerStatefulWidget {
  final String statusFilter;
  final String search;
  const _SearchFilter({required this.statusFilter, required this.search});

  @override
  ConsumerState<_SearchFilter> createState() => _SearchFilterState();
}

class _SearchFilterState extends ConsumerState<_SearchFilter> {
  Timer? _debounce;

  static const _tabs = [
    ('all', 'All'),
    ('pending', 'Pending'),
    ('selected', 'Selected'),
    ('rejected', 'Rejected'),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Web handleSearch: show the text at once, ask the server 350 ms after the
  /// last keystroke (which also restarts at page 1).
  void _onSearch(String v) {
    ref.read(candidateSearchProvider.notifier).state = v;
    _debounce?.cancel();
    _debounce = Timer(kCandidateSearchDebounce, () {
      if (mounted) ref.read(candidateAppliedSearchProvider.notifier).state = v.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusFilter = widget.statusFilter;
    return Column(children: [
      BlueHeroBanner(
        child: TextField(
          key: const Key('candidate-search'),
          onChanged: _onSearch,
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
                // Web handleStatusFilter: the server filters by status and
                // the list restarts at page 1 (candidateListProvider rebuilds).
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
      const SizedBox(height: 10),
      const _BranchFilter(),
      const SizedBox(height: 12),
    ]);
  }
}

/// Web interview-list branch filter. Unrestricted users (superuser /
/// settings.edit) pick "All Branches" (default) or an active branch; the list
/// restarts at page 1 for the new branch. Everyone else sees their own branch,
/// locked — the server scopes their candidates to it.
class _BranchFilter extends ConsumerWidget {
  const _BranchFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final box = BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    );
    if (!isUnrestrictedCandidateViewer(user)) {
      final own = (user?.branch ?? '').trim();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Tooltip(
          message: 'Scoped to your branch',
          child: Container(
            key: const Key('candidate-branch-locked'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: box.copyWith(color: AppColors.background),
            child: Row(children: [
              Icon(Icons.apartment_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(own.isEmpty ? '—' : own,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ),
              Icon(Icons.lock_outline, size: 15, color: AppColors.textSecondary),
            ]),
          ),
        ),
      );
    }

    final optionsAsync = ref.watch(candidateBranchOptionsProvider);
    final options = optionsAsync.valueOrNull ?? const [];
    final picked = ref.watch(candidateBranchFilterProvider);
    // A pick that's no longer among the options shows as All Branches.
    final value = options.any((b) => b.id == picked) ? picked : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(
          child: DropdownButtonFormField<int?>(
            key: const Key('candidate-branch-filter'),
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.apartment_outlined, size: 18, color: AppColors.textSecondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All Branches')),
              for (final b in options)
                DropdownMenuItem<int?>(value: b.id, child: Text('${b.branchName} (${b.branchCode})')),
            ],
            // Disabled until the branches have loaded (web shows only "All
            // Branches" until then).
            onChanged: optionsAsync.isLoading
                ? null
                : (v) => ref.read(candidateBranchFilterProvider.notifier).state = v,
          ),
        ),
        if (optionsAsync.isLoading) ...[
          const SizedBox(width: 10),
          const SizedBox(
              key: Key('candidate-branch-loading'),
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ],
        if (optionsAsync.hasError && !optionsAsync.isLoading)
          IconButton(
            key: const Key('candidate-branch-retry'),
            tooltip: 'Couldn\'t load branches — retry',
            icon: Icon(Icons.refresh, color: AppColors.error),
            onPressed: () => ref.invalidate(candidateBranchOptionsProvider),
          ),
      ]),
    );
  }
}

/// Below the last loaded candidate: loads the next page when it comes into
/// view (one at a time), a retry after a failed page, and the totals.
class _ListFooter extends ConsumerStatefulWidget {
  const _ListFooter({required this.page});
  final CandidateListState page;

  @override
  ConsumerState<_ListFooter> createState() => _ListFooterState();
}

class _ListFooterState extends ConsumerState<_ListFooter> {
  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(covariant _ListFooter old) {
    super.didUpdateWidget(old);
    if (old.page.page != widget.page.page) _maybeLoad();
  }

  void _maybeLoad() {
    final p = widget.page;
    if (!p.hasMore || p.loadingMore || p.loadMoreError != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(candidateListProvider.notifier).loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.page;
    Widget child;
    if (p.loadingMore) {
      child = const SizedBox(
          key: Key('candidates-loading-more'),
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2));
    } else if (p.loadMoreError != null) {
      child = Column(mainAxisSize: MainAxisSize.min, children: [
        Text(p.loadMoreError!,
            key: const Key('candidates-more-error'),
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.error)),
        TextButton(
          key: const Key('candidates-more-retry'),
          onPressed: () => ref.read(candidateListProvider.notifier).loadMore(),
          child: const Text('Retry'),
        ),
      ]);
    } else {
      // Web: "Page X of Y · N total"; here every loaded page is shown.
      child = Text(
        p.hasMore ? 'Showing ${p.items.length} of ${p.count}' : '${p.count} total',
        key: const Key('candidates-count'),
        style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
      );
    }
    return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Center(child: child));
  }
}
