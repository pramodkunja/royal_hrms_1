part of '../screens/interview_list_screen.dart';

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Interview List', style: AppTextStyles.h4),
        const SizedBox(height: 2),
        Text('Manage all interview candidates and their status',
            style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ]),
    );
  }
}

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
            const Icon(Icons.info_outline,
                size: 16, color: AppColors.info),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Move candidates through the pipeline stages. '
                'Send portal login to selected candidates so they can fill their onboarding wizard.',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.info, fontSize: 11),
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
          const Icon(Icons.people_outline,
              size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text('No candidates found',
              style: AppTextStyles.label
                  .copyWith(color: AppColors.textSecondary)),
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
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        Expanded(
            child: _StatCard('Total', stats.total,
                Icons.groups_outlined, AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard('Pending', stats.pending,
                Icons.access_time_outlined, AppColors.warning)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard('Selected', stats.selected,
                Icons.how_to_reg_outlined, AppColors.success)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard('Rejected', stats.rejected,
                Icons.person_off_outlined, AppColors.error)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 6),
        Text('$value',
            style: AppTextStyles.h4.copyWith(
                fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        Text(label,
            style: AppTextStyles.caption
                .copyWith(fontSize: 10, color: AppColors.textHint)),
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
  const _SearchFilter(
      {required this.statusFilter, required this.search});

  static const _tabs = [
    ('all', 'All'),
    ('pending', 'Pending'),
    ('selected', 'Selected'),
    ('rejected', 'Rejected'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: TextField(
          onChanged: (v) =>
              ref.read(candidateSearchProvider.notifier).state = v,
          style: AppTextStyles.bodySmall,
          decoration: InputDecoration(
            hintText: 'Search candidate...',
            hintStyle: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textHint),
            prefixIcon: const Icon(Icons.search,
                size: 18, color: AppColors.textHint),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5)),
          ),
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
                ref
                    .read(candidateStatusFilterProvider.notifier)
                    .state = key;
                ref
                    .read(candidateListProvider.notifier)
                    .refresh();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isActive
                          ? AppColors.primary
                          : AppColors.border),
                ),
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isActive
                        ? Colors.white
                        : AppColors.textSecondary,
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
