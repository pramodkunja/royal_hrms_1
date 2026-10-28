import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/blue_hero_banner.dart';
import '../../../shared/widgets/expandable_fab.dart';
import '../../../shared/widgets/stat_card.dart';
import '../data/models/employee_model.dart';
import 'providers/employee_providers.dart';
import 'widgets/add_employee_sheet.dart';
import 'widgets/employee_card.dart';

// ignore_for_file: use_build_context_synchronously

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  bool _fabExpanded = false;
  // Toggled by the grid/list icon next to the "N employees" count — true
  // shows the 2-column directory-card grid, false falls back to a single
  // wide column of the same card (useful once a card's text gets long, or
  // just as a density preference).
  bool _isGridView = true;

  // How close to the bottom (in pixels) triggers loading the next page —
  // far enough ahead that "load more" is already in flight before the user
  // actually reaches the end of the currently-loaded rows.
  static const _loadMoreThreshold = 400.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(employeeListProvider.notifier).loadNextPage();
    }
  }

  // Search debounce: the text field updates its own controller (and
  // therefore the visible cursor/text) immediately on every keystroke, but
  // only commits to `employeeFiltersProvider` — which the paginated
  // notifier watches and reacts to by fetching a fresh filtered page 1 —
  // after the user pauses typing. Branch/Department/Status chip taps below
  // are discrete, deliberate actions and intentionally bypass this: they
  // update the filter immediately. Reads `employeeFiltersProvider` fresh
  // when the debounce fires (not a `filters` snapshot captured at keystroke
  // time) so a chip filter changed during the debounce window is preserved
  // instead of being silently reverted by a stale search-only copyWith.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final current = ref.read(employeeFiltersProvider);
      ref.read(employeeFiltersProvider.notifier).state =
          current.copyWith(search: value);
    });
  }

  Widget _buildEmployeeCard(BuildContext context, EmployeeModel emp) {
    return EmployeeCard(
      employee: emp,
      onView: () => context.push(
        AppRoutes.employeeProfilePath(emp.employeeId),
        extra: emp,
      ),
      onEdit: () async {
        final updated = await AddEmployeeSheet.show(context, editing: emp);
        if (updated == true) {
          ref.invalidate(employeeListProvider);
          ref.invalidate(employeeStatsProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Employee updated successfully.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
      },
    );
  }

  Future<void> _showFiltersSheet(BuildContext context) async {
    final filters = ref.read(employeeFiltersProvider);
    final branches = ref.read(employeeListBranchOptionsProvider);
    final depts = ref.read(employeeListDepartmentOptionsProvider);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Filter Employees',
                          style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    if (filters.hasActive)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          ref.read(employeeFiltersProvider.notifier).state = const EmployeeFilters();
                          Navigator.pop(sheetContext);
                        },
                        child: Text('Clear all',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (branches.isNotEmpty)
                _FilterSheetRow(
                  icon: Icons.location_on_outlined,
                  label: 'Branch',
                  value: filters.branch.isEmpty ? 'All Branches' : filters.branch,
                  onTap: () => _showPicker(
                    context: context,
                    title: 'Filter by Branch',
                    options: branches,
                    current: filters.branch,
                    onSelect: (v) =>
                        ref.read(employeeFiltersProvider.notifier).state = filters.copyWith(branch: v),
                  ),
                ),
              if (depts.isNotEmpty)
                _FilterSheetRow(
                  icon: Icons.business_outlined,
                  label: 'Department',
                  value: filters.department.isEmpty ? 'All Departments' : filters.department,
                  onTap: () => _showPicker(
                    context: context,
                    title: 'Filter by Department',
                    options: depts,
                    current: filters.department,
                    onSelect: (v) =>
                        ref.read(employeeFiltersProvider.notifier).state = filters.copyWith(department: v),
                  ),
                ),
              _FilterSheetRow(
                icon: Icons.fact_check_outlined,
                label: 'Status',
                value: switch (filters.status) {
                  'active' => 'Active',
                  'onboarding' => 'Onboarding',
                  'inactive' => 'Inactive',
                  _ => 'All Status',
                },
                onTap: () => _showPicker(
                  context: context,
                  title: 'Filter by Status',
                  options: const ['active', 'onboarding', 'inactive'],
                  current: filters.status,
                  displayMap: const {'active': 'Active', 'onboarding': 'Onboarding', 'inactive': 'Inactive'},
                  onSelect: (v) =>
                      ref.read(employeeFiltersProvider.notifier).state = filters.copyWith(status: v),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPicker({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String current,
    Map<String, String>? displayMap,
    required ValueChanged<String> onSelect,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(title,
                    style: AppTextStyles.label
                        .copyWith(fontWeight: FontWeight.w800)),
              ),
              const Divider(),
              // "All" option
              ListTile(
                title: Text('All', style: AppTextStyles.body),
                trailing: current.isEmpty
                    ? Icon(Icons.check, color: AppColors.primary, size: 18)
                    : null,
                onTap: () {
                  onSelect('');
                  Navigator.pop(context);
                },
              ),
              ...options.map((opt) => ListTile(
                    title: Text(displayMap?[opt] ?? opt, style: AppTextStyles.body),
                    trailing: current == opt
                        ? Icon(Icons.check, color: AppColors.primary, size: 18)
                        : null,
                    onTap: () {
                      onSelect(opt);
                      Navigator.pop(context);
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Dark hero banner (search + filter) with the stats row straddling its
  // rounded bottom edge — matches the reference "Directory" design. The
  // hamburger/title/notification row isn't replicated here since that's
  // already the shared app shell's own top bar (DashboardShell) — this is
  // only this screen's own body content, sitting directly below it.
  static const _heroContentHeight = 20.0 + 48.0 + 36.0; // top pad + search row + bottom pad
  static const _statsOverlap = 44.0; // half of _StatCard's ~88 height

  Widget _buildHeroHeader(EmployeeFilters filters, AsyncValue<EmployeeStats> statsAsync) {
    return SizedBox(
      height: _heroContentHeight + _statsOverlap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BlueHeroBanner(
              // Bottom padding of 36 (instead of the default 20) reproduces
              // the original fixed _heroContentHeight (20 top + 48 search
              // row + 36 bottom) so the stats row below still overlaps the
              // banner's bottom edge by exactly _statsOverlap.
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _searchCtrl,
                        style: AppTextStyles.body,
                        onChanged: (v) {
                          setState(() {}); // refresh the clear (×) button's visibility
                          _onSearchChanged(v);
                        },
                        decoration: heroSearchFieldDecoration(
                          hintText: 'Search employees...',
                          showClear: _searchCtrl.text.isNotEmpty,
                          onClear: () {
                            _searchDebounce?.cancel();
                            setState(() => _searchCtrl.clear());
                            ref.read(employeeFiltersProvider.notifier).state =
                                filters.copyWith(search: '');
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _FilterIconButton(
                    active: filters.hasActive,
                    activeCount: filters.activeCount,
                    onTap: () => _showFiltersSheet(context),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: _heroContentHeight - _statsOverlap,
            left: 0,
            right: 0,
            child: _StatsGrid(statsAsync: statsAsync),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(employeeStatsProvider);
    final listAsync = ref.watch(employeeListProvider);
    final filters = ref.watch(employeeFiltersProvider);
    // Explicit rather than `.when()` so a filter-triggered/pull-to-refresh
    // reload (isLoading == true but a previous page is still attached) keeps
    // rendering that previous page instead of ever blanking the list —
    // `.when()`'s default loading-branch behavior isn't relied on here.
    final listState = listAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: ExpandableFab(
        heroTag: 'employees_fab',
        expanded: _fabExpanded,
        onToggle: () => setState(() => _fabExpanded = !_fabExpanded),
        actions: [
          ExpandableFabAction(
            icon: Icons.upload_file_outlined,
            label: 'Bulk Import',
            onTap: () {
              setState(() => _fabExpanded = false);
              context.push(AppRoutes.employeeBulkImport);
            },
          ),
          ExpandableFabAction(
            icon: Icons.person_add_outlined,
            label: 'Add Employee',
            onTap: () async {
              setState(() => _fabExpanded = false);
              final added = await AddEmployeeSheet.show(context);
              if (added == true) {
                ref.invalidate(employeeListProvider);
                ref.invalidate(employeeStatsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Employee created successfully.'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(employeeListProvider.notifier).refresh(),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // ── Hero header (search + filter) with the stats row
                // straddling its rounded bottom edge ─────────────────────────
                SliverToBoxAdapter(
                  child: _buildHeroHeader(filters, statsAsync),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // ── Active filter count banner ───────────────────────────────
                if (filters.hasActive)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.20)),
                            ),
                            child: Text(
                              '${filters.activeCount} filter${filters.activeCount == 1 ? '' : 's'} active',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              ref.read(employeeFiltersProvider.notifier).state =
                                  const EmployeeFilters();
                            },
                            child: Text('Clear all',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline)),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Results count + grid/list toggle ─────────────────────────
                // Uses the backend's total `count` for the current filters,
                // not `items.length` — the latter would only reflect however
                // many pages happen to be loaded so far, not the real total.
                if (listState != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${listState.count} employee${listState.count == 1 ? '' : 's'}',
                              style: AppTextStyles.h4,
                            ),
                          ),
                          _ViewToggleButton(
                            isGridView: _isGridView,
                            onTap: () => setState(() => _isGridView = !_isGridView),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Employee list ───────────────────────────────────────────
                if (listState == null)
                  // No page loaded yet at all: either the very first fetch is
                  // still in flight, or it failed outright with nothing to
                  // show. Checked via `hasValue`/`hasError` directly (not
                  // `.when()`) so this branch can never fire once a page has
                  // successfully loaded once, even while a later filter
                  // change or refresh is back in `isLoading`.
                  if (listAsync.hasError)
                    SliverFillRemaining(
                      child: AppErrorState(
                        title: 'Could not load employees',
                        message: userFriendlyMessage(listAsync.error!),
                        onRetry: () => ref.invalidate(employeeListProvider),
                      ),
                    )
                  else
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                else if (listState.items.isEmpty)
                  SliverFillRemaining(
                    child: AppEmptyState(
                      icon: Icons.badge_outlined,
                      title: filters.search.isNotEmpty ||
                              filters.status.isNotEmpty ||
                              filters.department.isNotEmpty ||
                              filters.branch.isNotEmpty
                          ? 'No matching employees'
                          : 'No employees yet',
                      message: filters.search.isNotEmpty
                          ? 'No employees match your search.'
                          : (filters.status.isNotEmpty ||
                                  filters.department.isNotEmpty ||
                                  filters.branch.isNotEmpty)
                              ? 'No employees match the selected filters.'
                              : 'Employees will appear here once added.',
                    ),
                  )
                else if (_isGridView)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        // Worst case (2-line name, id pill, role, status
                        // pill, and the button row) measures out to ~260px
                        // tall at this column width — 0.72 clipped that by
                        // ~40px. 0.58 leaves real headroom instead of being
                        // tuned to the exact overflow just reported.
                        childAspectRatio: 0.58,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _buildEmployeeCard(context, listState.items[i]),
                        childCount: listState.items.length,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    sliver: SliverList.separated(
                      itemCount: listState.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _buildEmployeeCard(context, listState.items[i]),
                    ),
                  ),

                // ── Bottom "load more" row ────────────────────────────────────
                // Never a full-screen loader — the already-loaded rows above
                // stay exactly as they are while this renders below them.
                if (listState != null && listState.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    ),
                  )
                else if (listState != null && listState.loadMoreError != null)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              listState.loadMoreError!,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textHint),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () => ref
                                  .read(employeeListProvider.notifier)
                                  .loadNextPage(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
          // Tap-outside-to-dismiss barrier for the expanded FAB menu.
          ExpandableFabBarrier(
            visible: _fabExpanded,
            onDismiss: () => setState(() => _fabExpanded = false),
          ),
        ],
      ),
    );
  }
}

// ── Stats row (horizontal scroll) ─────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final AsyncValue<EmployeeStats> statsAsync;
  const _StatsGrid({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    final stats = statsAsync.valueOrNull ?? EmployeeStats.empty;
    return StatCardRow(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      cards: [
        StatCard(icon: Icons.groups_outlined, count: stats.total, label: 'Total', color: AppColors.primary),
        StatCard(icon: Icons.person_outlined, count: stats.active, label: 'Active', color: AppColors.success),
        StatCard(icon: Icons.person_add_outlined, count: stats.onboarding, label: 'Onboarding', color: AppColors.warning),
        StatCard(icon: Icons.business_outlined, count: stats.departments, label: 'Departments', color: const Color(0xFF7C3AED)),
      ],
    );
  }
}

// ── Filter icon button (opens the combined filters bottom sheet) ─────────────

class _FilterIconButton extends StatelessWidget {
  final bool active;
  final int activeCount;
  final VoidCallback onTap;

  const _FilterIconButton({required this.active, required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(Icons.tune_rounded, size: 20, color: AppColors.primary),
              if (active)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 15),
                    decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '$activeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter sheet row (Branch/Department/Status pickers) ──────────────────────

class _FilterSheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _FilterSheetRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(value, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      trailing: Icon(Icons.chevron_right, size: 20, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}

// Empty/Error states now use the shared AppEmptyState/AppErrorState widgets
// (lib/shared/widgets/) directly at their call sites above — this file no
// longer needs its own private versions of either.

// ── Grid/list view toggle ─────────────────────────────────────────────────────

class _ViewToggleButton extends StatelessWidget {
  final bool isGridView;
  final VoidCallback onTap;
  const _ViewToggleButton({required this.isGridView, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            isGridView ? Icons.view_list_outlined : Icons.grid_view_rounded,
            size: 18,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
