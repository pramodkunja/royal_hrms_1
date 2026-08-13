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
import '../../../shared/widgets/expandable_fab.dart';
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

  Future<void> _showPicker({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String current,
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
                    title: Text(opt, style: AppTextStyles.body),
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

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(employeeStatsProvider);
    final listAsync = ref.watch(employeeListProvider);
    final filters = ref.watch(employeeFiltersProvider);
    final branches = ref.watch(employeeListBranchOptionsProvider);
    final depts = ref.watch(employeeListDepartmentOptionsProvider);
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
                // ── Stats 2×2 grid ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _StatsGrid(statsAsync: statsAsync),
                ),

                // ── Search ─────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: TextField(
                      controller: _searchCtrl,
                      style: AppTextStyles.body,
                      onChanged: (v) {
                        setState(() {}); // refresh the clear (×) button's visibility
                        _onSearchChanged(v);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search employees...',
                        hintStyle: AppTextStyles.body
                            .copyWith(color: AppColors.textHint),
                        prefixIcon: Icon(Icons.search,
                            size: 20, color: AppColors.textHint),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchDebounce?.cancel();
                                  setState(() => _searchCtrl.clear());
                                  ref
                                      .read(employeeFiltersProvider.notifier)
                                      .state = filters.copyWith(search: '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ),

                // ── Filter pill chips ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      children: [
                        // Branch chip
                        if (branches.isNotEmpty) ...[
                          _FilterChip(
                            label: 'All Branches',
                            selected: filters.branch,
                            onTap: () => _showPicker(
                              context: context,
                              title: 'Filter by Branch',
                              options: branches,
                              current: filters.branch,
                              onSelect: (v) => ref
                                  .read(employeeFiltersProvider.notifier)
                                  .state = filters.copyWith(branch: v),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        // Department chip
                        if (depts.isNotEmpty) ...[
                          _FilterChip(
                            label: 'All Departments',
                            selected: filters.department,
                            onTap: () => _showPicker(
                              context: context,
                              title: 'Filter by Department',
                              options: depts,
                              current: filters.department,
                              onSelect: (v) => ref
                                  .read(employeeFiltersProvider.notifier)
                                  .state = filters.copyWith(department: v),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        // Status chip
                        _FilterChip(
                          label: 'All Status',
                          selected: filters.status,
                          displayMap: const {
                            'active': 'Active',
                            'onboarding': 'Onboarding',
                            'inactive': 'Inactive',
                          },
                          onTap: () => _showPicker(
                            context: context,
                            title: 'Filter by Status',
                            options: const ['active', 'onboarding', 'inactive'],
                            current: filters.status,
                            onSelect: (v) => ref
                                .read(employeeFiltersProvider.notifier)
                                .state = filters.copyWith(status: v),
                          ),
                        ),
                      ],
                    ),
                  ),
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

                // ── Results count ───────────────────────────────────────────
                // Uses the backend's total `count` for the current filters,
                // not `items.length` — the latter would only reflect however
                // many pages happen to be loaded so far, not the real total.
                if (listState != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        '${listState.count} employee${listState.count == 1 ? '' : 's'}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w600,
                        ),
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
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    sliver: SliverList.separated(
                      itemCount: listState.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final emp = listState.items[i];
                        return EmployeeCard(
                          employee: emp,
                          onView: () => context.push(
                            AppRoutes.employeeProfilePath(emp.employeeId),
                            extra: emp,
                          ),
                          onEdit: () async {
                            final updated =
                                await AddEmployeeSheet.show(context, editing: emp);
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
                      },
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

// ── Stats 2×2 grid ────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final AsyncValue<EmployeeStats> statsAsync;
  const _StatsGrid({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    final stats = statsAsync.valueOrNull ?? EmployeeStats.empty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.groups_outlined,
                  count: stats.total,
                  label: 'Total Employees',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.person_outlined,
                  count: stats.active,
                  label: 'Active',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.person_add_outlined,
                  count: stats.onboarding,
                  label: 'Onboarding',
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.business_outlined,
                  count: stats.departments,
                  label: 'Departments',
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        // Matches the app's other card radius (12) rather than this card's
        // previous one-off 14.
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter pill chip ──────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final String selected;
  final Map<String, String>? displayMap;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.displayMap,
  });

  String get _displayText {
    if (selected.isEmpty) return label;
    return displayMap?[selected] ?? selected;
  }

  bool get _isActive => selected.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: _isActive ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _isActive ? AppColors.primary : AppColors.border,
          ),
          boxShadow: _isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _displayText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: _isActive ? Colors.white : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// Empty/Error states now use the shared AppEmptyState/AppErrorState widgets
// (lib/shared/widgets/) directly at their call sites above — this file no
// longer needs its own private versions of either.
