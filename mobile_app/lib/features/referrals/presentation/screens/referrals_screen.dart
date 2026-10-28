import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/referral_entity.dart';
import '../providers/referral_providers.dart';
import '../widgets/refer_candidate_dialog.dart';
import '../widgets/referral_card.dart';
import '../widgets/referral_rule_card.dart';

class ReferralsScreen extends ConsumerStatefulWidget {
  const ReferralsScreen({super.key});

  @override
  ConsumerState<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends ConsumerState<ReferralsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final bool _showAllTab;
  final _mySearchCtrl = TextEditingController();
  final _allSearchCtrl = TextEditingController();
  String _mySearch = '';
  String _allSearch = '';
  bool _showSuccessBanner = false;

  @override
  void initState() {
    super.initState();
    final permissions =
        ref.read(authStateProvider).valueOrNull?.user?.permissions ?? const [];
    _showAllTab = permissions.contains('recruitment.view');
    _tabController = TabController(length: _showAllTab ? 3 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mySearchCtrl.dispose();
    _allSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openReferDialog() async {
    final submitted = await showReferCandidateDialog(context);
    if (submitted == true && mounted) {
      setState(() => _showSuccessBanner = true);
      Future.delayed(const Duration(milliseconds: 4000), () {
        if (mounted) setState(() => _showSuccessBanner = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myAsync = ref.watch(myReferralsProvider);
    final myReferrals = myAsync.valueOrNull ?? const <ReferralEntity>[];

    final totalReferred = myReferrals.length;
    final inPipeline = myReferrals.where((r) => r.isInPipeline).length;
    final selected = myReferrals.where((r) => r.isSelectedOrOffered).length;
    final converted = myReferrals.where((r) => r.isConverted).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openReferDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Refer Someone',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlueHeroBanner(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Referrals',
                  style: AppTextStyles.h2.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Refer talented people you know and earn a bonus when they join the team.',
                  style: AppTextStyles.bodySecondary
                      .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats in normal flow (not overlapping the hero) — the
                  // overlap trick relied on a hardcoded hero height that
                  // undershot the real rendered height of the wrapping
                  // subtitle text, which visibly covered it and let it spill
                  // out past the hero's rounded bottom. Matches the safe
                  // pattern every other hero'd screen already uses.
                  _StatsRow(
                    totalReferred: totalReferred,
                    inPipeline: inPipeline,
                    selected: selected,
                    converted: converted,
                  ),
                  const SizedBox(height: 16),
                  if (_showSuccessBanner) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.successContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Referral submitted successfully! It will appear in My Referrals shortly.',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    labelStyle: AppTextStyles.label,
                    tabs: [
                      const Tab(
                          child: _TabLabel(
                              icon: Icons.groups_outlined,
                              label: 'My Referrals')),
                      if (_showAllTab)
                        const Tab(
                            child: _TabLabel(
                                icon: Icons.list_alt_outlined,
                                label: 'All Referrals')),
                      const Tab(
                          child: _TabLabel(
                              icon: Icons.description_outlined,
                              label: 'Referral Rules')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _ReferralListBody(
                          async: myAsync,
                          searchController: _mySearchCtrl,
                          search: _mySearch,
                          onSearchChanged: (v) => setState(() => _mySearch = v),
                          showReferredBy: false,
                          onRefresh: () =>
                              ref.read(myReferralsProvider.notifier).refresh(),
                          onRetry: () => ref.invalidate(myReferralsProvider),
                        ),
                        if (_showAllTab)
                          Consumer(
                            builder: (context, ref, _) {
                              final allAsync = ref.watch(allReferralsProvider);
                              return _ReferralListBody(
                                async: allAsync,
                                searchController: _allSearchCtrl,
                                search: _allSearch,
                                onSearchChanged: (v) =>
                                    setState(() => _allSearch = v),
                                showReferredBy: true,
                                onRefresh: () => ref
                                    .read(allReferralsProvider.notifier)
                                    .refresh(),
                                onRetry: () =>
                                    ref.invalidate(allReferralsProvider),
                              );
                            },
                          ),
                        const _RulesTabBody(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab label (icon before text) ─────────────────────────────────────────────

class _TabLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TabLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

// ── Stat cards — horizontally scrolling so they never crowd the screen ───────

class _StatsRow extends StatelessWidget {
  final int totalReferred;
  final int inPipeline;
  final int selected;
  final int converted;

  const _StatsRow({
    required this.totalReferred,
    required this.inPipeline,
    required this.selected,
    required this.converted,
  });

  @override
  Widget build(BuildContext context) {
    // Shared StatCard/StatCardRow — same visual design as the Employees
    // screen's directory-stats strip (148-wide cards, 40x40 icon tile,
    // fontSize 22 count). Values/icons/colors unchanged, only the card
    // chrome now matches the rest of the app. `padding: zero` because this
    // row already sits inside the screen body's horizontal-16 Padding, so
    // the cards line up with the TabBar/success banner below instead of
    // double-indenting.
    return StatCardRow(
      padding: EdgeInsets.zero,
      cards: [
        StatCard(
          icon: Icons.groups_outlined,
          count: totalReferred,
          label: 'Total Referred',
          color: AppColors.primary,
        ),
        StatCard(
          icon: Icons.schedule_outlined,
          count: inPipeline,
          label: 'In Pipeline',
          color: AppColors.warning,
        ),
        StatCard(
          icon: Icons.how_to_reg_outlined,
          count: selected,
          label: 'Selected',
          color: AppColors.success,
        ),
        StatCard(
          icon: Icons.emoji_events_outlined,
          count: converted,
          label: 'Converted',
          color: AppColors.primary,
        ),
      ],
    );
  }
}

// ── Shared My/All referral list body ─────────────────────────────────────────

class _ReferralListBody extends StatelessWidget {
  final AsyncValue<List<ReferralEntity>> async;
  final TextEditingController searchController;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final bool showReferredBy;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  const _ReferralListBody({
    required this.async,
    required this.searchController,
    required this.search,
    required this.onSearchChanged,
    required this.showReferredBy,
    required this.onRefresh,
    required this.onRetry,
  });

  List<ReferralEntity> _filtered(List<ReferralEntity> items) {
    if (search.trim().isEmpty) return items;
    final q = search.toLowerCase();
    return items.where((r) {
      final haystack =
          '${r.name} ${r.positionApplied} ${r.referralByName}'.toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Search by name, position…',
            prefixIcon: Icon(Icons.search, size: 20),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: async.when(
            data: (items) {
              final filtered = _filtered(items);
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          _EmptyState(
                            icon: Icons.person_add_alt_outlined,
                            title: 'No referrals found',
                            body:
                                'Try adjusting your search or submit a new referral.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => ReferralCard(
                          referral: filtered[i],
                          showReferredBy: showReferredBy,
                        ),
                      ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorState(
                message: friendlyReferralError(e), onRetry: onRetry),
          ),
        ),
      ],
    );
  }
}

// ── Referral Rules tab ────────────────────────────────────────────────────────

class _RulesTabBody extends ConsumerWidget {
  const _RulesTabBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(referralRulesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(referralRulesProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: rulesAsync.when(
          data: (rules) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rules.isEmpty)
                  const _EmptyState(
                    icon: Icons.description_outlined,
                    title: 'No rules configured',
                    body:
                        'An admin can add referral rules from Settings → Referral Rules.',
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.infoContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'These rules govern the Employee Referral Programme. Please read '
                      'them carefully before submitting a referral.',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // One full-width card per row — a phone screen is too
                  // narrow for web's multi-column grid to read comfortably.
                  for (var i = 0; i < rules.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    ReferralRuleCard(rule: rules[i], displayIndex: i + 1),
                  ],
                ],
                const SizedBox(height: 16),
                const ReferralBonusBreakdownPanel(),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _ErrorState(
            message: friendlyReferralError(e),
            onRetry: () => ref.invalidate(referralRulesProvider),
          ),
        ),
      ),
    );
  }
}

// ── Shared states ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyState(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(title,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            body,
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 32, color: AppColors.error),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppTextStyles.bodySecondary.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
