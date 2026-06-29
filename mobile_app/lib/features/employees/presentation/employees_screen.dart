import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
                width: 36, height: 4,
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
    final statsAsync    = ref.watch(employeeStatsProvider);
    final filteredAsync = ref.watch(filteredEmployeesProvider);
    final filters       = ref.watch(employeeFiltersProvider);
    final branches      = ref.watch(employeeBranchNameListProvider);
    final depts         = ref.watch(employeeDepartmentListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await AddEmployeeSheet.show(context);
          if (added == true) {
            ref.read(employeesProvider.notifier).refresh();
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined, size: 20),
        label: Text('Add Employee',
            style: AppTextStyles.label
                .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(employeesProvider.notifier).refresh(),
        child: CustomScrollView(
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
                  onChanged: (v) => ref
                      .read(employeeFiltersProvider.notifier)
                      .state = filters.copyWith(search: v),
                  decoration: InputDecoration(
                    hintText: 'Search employees...',
                    hintStyle: AppTextStyles.body
                        .copyWith(color: AppColors.textHint),
                    prefixIcon: const Icon(Icons.search,
                        size: 20, color: AppColors.textHint),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
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
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
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
                        'active':     'Active',
                        'onboarding': 'Onboarding',
                        'inactive':   'Inactive',
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
                              color:
                                  AppColors.primary.withValues(alpha: 0.20)),
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
                          ref
                              .read(employeeFiltersProvider.notifier)
                              .state = const EmployeeFilters();
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
            if (filteredAsync.valueOrNull != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    '${filteredAsync.valueOrNull!.length} employee${filteredAsync.valueOrNull!.length == 1 ? '' : 's'}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // ── Employee list ───────────────────────────────────────────
            filteredAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => SliverFillRemaining(
                child: _ErrorView(message: err.toString()),
              ),
              data: (employees) => employees.isEmpty
                  ? SliverFillRemaining(
                      child: _EmptyView(hasFilters: filters.hasActive),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      sliver: SliverList.separated(
                        itemCount: employees.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final emp = employees[i];
                          return EmployeeCard(
                            employee: emp,
                            onView: () => context.push(
                              AppRoutes.employeeProfilePath(emp.employeeId),
                              extra: emp,
                            ),
                            onEdit: () async {
                              final updated =
                                  await AddEmployeeSheet.show(context,
                                      editing: emp);
                              if (updated == true) {
                                ref
                                    .read(employeesProvider.notifier)
                                    .refresh();
                              }
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(14),
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
                  style: const TextStyle(
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

// ── Empty / Error views ───────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final bool hasFilters;
  const _EmptyView({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.badge_outlined,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No results found' : 'No employees yet',
              style: AppTextStyles.h4,
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try adjusting your filters.'
                  : 'Employees will appear here once added.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('Could not load employees', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(message,
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
