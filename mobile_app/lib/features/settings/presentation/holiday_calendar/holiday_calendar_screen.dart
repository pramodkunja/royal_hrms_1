import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../branches/presentation/providers/branch_providers.dart';
import '../../data/models/holiday_model.dart';
import '../widgets/settings_app_bar.dart';
import 'holiday_calendar_providers.dart';
import 'holiday_styles.dart';
import 'widgets/holiday_form_dialog.dart';
import 'widgets/holiday_view_dialog.dart';

const _kMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _kMonthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];
const _kWeekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _kDayHeaders = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
const _kPageSize = 10;

class HolidayCalendarScreen extends ConsumerStatefulWidget {
  const HolidayCalendarScreen({super.key});

  @override
  ConsumerState<HolidayCalendarScreen> createState() =>
      _HolidayCalendarScreenState();
}

class _HolidayCalendarScreenState extends ConsumerState<HolidayCalendarScreen> {
  late int _year;
  String _branch = 'All Branches';
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filterTab = 'all'; // all | national | regional | company | optional
  String _viewMode = 'list'; // list | calendar
  String _typeFilter = ''; // '' | national | regional | company
  int? _monthFilter; // null = all months, else 0-11
  int _page = 1;
  late DateTime _calMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _calMonth = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _resetPage() => setState(() => _page = 1);

  HolidaysKey get _key =>
      (year: _year, branchName: _branch == 'All Branches' ? null : _branch);

  @override
  Widget build(BuildContext context) {
    final asyncHolidays = ref.watch(holidaysProvider(_key));
    final branchNames = ref
            .watch(branchListProvider)
            .valueOrNull
            ?.map((b) => b.branchName)
            .toList() ??
        const <String>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Holiday Calendar'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openHolidayForm(null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Holiday',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: SafeArea(
        child: asyncHolidays.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(
            message: friendlyHolidayError(e),
            onRetry: () => ref.read(holidaysProvider(_key).notifier).refresh(),
          ),
          data: (yearHolidays) => RefreshIndicator(
            onRefresh: () =>
                ref.read(holidaysProvider(_key).notifier).refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              child: _buildContent(yearHolidays, branchNames),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      List<HolidayModel> yearHolidays, List<String> branchNames) {
    final stats = (
      total: yearHolidays.length,
      national:
          yearHolidays.where((h) => h.type == HolidayType.national).length,
      regional:
          yearHolidays.where((h) => h.type == HolidayType.regional).length,
      company: yearHolidays.where((h) => h.type == HolidayType.company).length,
      optional: yearHolidays.where((h) => h.isOptional).length,
    );

    var filtered = yearHolidays.where((h) {
      if (_filterTab == 'optional' && !h.isOptional) return false;
      if (_filterTab != 'all' &&
          _filterTab != 'optional' &&
          h.type != _filterTab) return false;
      if (_typeFilter.isNotEmpty && h.type != _typeFilter) return false;
      if (_monthFilter != null && h.date.month - 1 != _monthFilter)
        return false;
      if (_query.isNotEmpty &&
          !h.name.toLowerCase().contains(_query.toLowerCase())) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final totalPages = (filtered.length / _kPageSize).ceil().clamp(1, 1 << 30);
    final pageItems =
        filtered.skip((_page - 1) * _kPageSize).take(_kPageSize).toList();

    final calHolidays = yearHolidays
        .where((h) => h.date.month == _calMonth.month)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final hasActiveFilters = _query.isNotEmpty ||
        _branch != 'All Branches' ||
        _typeFilter.isNotEmpty ||
        _monthFilter != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manage national, regional and company holidays',
            style: AppTextStyles.bodySecondary),
        const SizedBox(height: 14),
        _YearAndBranchRow(
          year: _year,
          branch: _branch,
          branchOptions: ['All Branches', ...branchNames],
          onYearChanged: (y) => setState(() {
            _year = y;
            _resetPage();
          }),
          onBranchChanged: (b) => setState(() {
            _branch = b;
            _resetPage();
          }),
        ),
        const SizedBox(height: 12),
        _SearchBar(
          controller: _searchCtrl,
          onChanged: (v) => setState(() {
            _query = v;
            _resetPage();
          }),
        ),
        const SizedBox(height: 14),
        _StatsRow(stats: stats),
        const SizedBox(height: 14),
        _FilterTabsRow(
          active: _filterTab,
          stats: stats,
          onSelect: (t) => setState(() {
            _filterTab = t;
            _resetPage();
          }),
        ),
        const SizedBox(height: 10),
        _ViewToggle(
          mode: _viewMode,
          onChanged: (m) => setState(() => _viewMode = m),
        ),
        const SizedBox(height: 12),
        _AdditionalFilters(
          typeFilter: _typeFilter,
          monthFilter: _monthFilter,
          hasActiveFilters: hasActiveFilters,
          onTypeChanged: (t) => setState(() {
            _typeFilter = t;
            _resetPage();
          }),
          onMonthChanged: (m) => setState(() {
            _monthFilter = m;
            _resetPage();
          }),
          onClear: () => setState(() {
            _searchCtrl.clear();
            _query = '';
            _branch = 'All Branches';
            _typeFilter = '';
            _monthFilter = null;
            _page = 1;
          }),
        ),
        const SizedBox(height: 10),
        Text(
          '${filtered.length} holiday${filtered.length == 1 ? '' : 's'}',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 10),
        if (_viewMode == 'list') ...[
          if (pageItems.isEmpty)
            _EmptyState(year: _year, onAdd: () => _openHolidayForm(null))
          else
            ...pageItems.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HolidayCard(
                    holiday: h,
                    onView: () => _openHolidayView(h),
                    onEdit: () => _openHolidayForm(h),
                    onDelete: () => _confirmDelete(h),
                    onToggleActive: () => _toggleActive(h),
                  ),
                )),
          if (totalPages > 1)
            _PaginationBar(
              page: _page,
              totalPages: totalPages,
              onPrev: () => setState(() => _page--),
              onNext: () => setState(() => _page++),
            ),
        ] else ...[
          _CalendarMonthNav(
            calMonth: _calMonth,
            onPrev: () => setState(() =>
                _calMonth = DateTime(_calMonth.year, _calMonth.month - 1, 1)),
            onNext: () => setState(() =>
                _calMonth = DateTime(_calMonth.year, _calMonth.month + 1, 1)),
          ),
          const SizedBox(height: 8),
          _CalendarGrid(
            calMonth: _calMonth,
            holidays: yearHolidays
                .where((h) => h.date.month == _calMonth.month)
                .toList(),
            onTapHoliday: _openHolidayView,
          ),
          if (calHolidays.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Holidays in ${_kMonthNames[_calMonth.month - 1]}',
                style: AppTextStyles.h4),
            const SizedBox(height: 8),
            ...calHolidays.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CalendarSummaryRow(
                      holiday: h, onTap: () => _openHolidayView(h)),
                )),
          ],
        ],
        const SizedBox(height: 16),
        const _Legend(),
      ],
    );
  }

  Future<void> _openHolidayForm(HolidayModel? holiday) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: HolidayFormDialog(holiday: holiday, holidaysKey: _key),
      ),
    );
  }

  void _openHolidayView(HolidayModel holiday) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: HolidayViewDialog(
            holiday: holiday, onEdit: () => _openHolidayForm(holiday)),
      ),
    );
  }

  Future<void> _toggleActive(HolidayModel holiday) async {
    final error = await ref
        .read(holidaysProvider(_key).notifier)
        .toggleActive(holiday.id);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _confirmDelete(HolidayModel holiday) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Holiday?'),
        content: Text.rich(
          TextSpan(
            style: AppTextStyles.body,
            children: [
              TextSpan(
                  text: holiday.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(
                  text:
                      ' (${holiday.date.day} ${_kMonthShort[holiday.date.month - 1]} '
                      '${holiday.date.year}) will be permanently removed.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error =
        await ref.read(holidaysProvider(_key).notifier).remove(holiday.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${holiday.name}" deleted.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message,
                style: AppTextStyles.body, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
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

// ── Year + Branch row ─────────────────────────────────────────────────────────

class _YearAndBranchRow extends StatelessWidget {
  final int year;
  final String branch;
  final List<String> branchOptions;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<String> onBranchChanged;
  const _YearAndBranchRow({
    required this.year,
    required this.branch,
    required this.branchOptions,
    required this.onYearChanged,
    required this.onBranchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = branchOptions.contains(branch)
        ? branchOptions
        : [branch, ...branchOptions];
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                color: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
                onPressed: () => onYearChanged(year - 1),
              ),
              Text('$year',
                  style: AppTextStyles.label
                      .copyWith(fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                color: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
                onPressed: () => onYearChanged(year + 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CompactDropdown<String>(
            value: branch,
            items: options,
            labelBuilder: (v) => v,
            onChanged: (v) => onBranchChanged(v!),
          ),
        ),
      ],
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: 'Search holidays…',
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
        prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textHint),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close, size: 18, color: AppColors.textHint),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }
}

// ── Stats row (horizontal scroll — avoids overflow on narrow screens) ────────

class _StatsRow extends StatelessWidget {
  final ({
    int total,
    int national,
    int regional,
    int company,
    int optional
  }) stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    // No extra horizontal padding here — this row is already nested inside
    // the screen's padded SingleChildScrollView (see _buildContent).
    return StatCardRow(
      padding: EdgeInsets.zero,
      cards: [
        StatCard(
          icon: Icons.calendar_month_outlined,
          count: stats.total,
          label: 'Total',
          color: AppColors.primary,
        ),
        StatCard(
          icon: Icons.flag_outlined,
          count: stats.national,
          label: 'National',
          color: HolidayStyles.national,
        ),
        StatCard(
          icon: Icons.place_outlined,
          count: stats.regional,
          label: 'Regional',
          color: HolidayStyles.regional,
        ),
        StatCard(
          icon: Icons.apartment_outlined,
          count: stats.company,
          label: 'Company',
          color: HolidayStyles.company,
        ),
        StatCard(
          icon: Icons.event_available_outlined,
          count: stats.optional,
          label: 'Optional',
          color: HolidayStyles.optional,
        ),
      ],
    );
  }
}

// ── Filter tabs (All / National / Regional / Company / Optional) ────────────

class _FilterTabsRow extends StatelessWidget {
  final String active;
  final ({
    int total,
    int national,
    int regional,
    int company,
    int optional
  }) stats;
  final ValueChanged<String> onSelect;
  const _FilterTabsRow(
      {required this.active, required this.stats, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (key: 'all', label: 'All', count: stats.total),
      (key: HolidayType.national, label: 'National', count: stats.national),
      (key: HolidayType.regional, label: 'Regional', count: stats.regional),
      (key: HolidayType.company, label: 'Company', count: stats.company),
      (key: 'optional', label: 'Optional', count: stats.optional),
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = tabs[i];
          final isActive = t.key == active;
          return GestureDetector(
            onTap: () => onSelect(t.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isActive ? AppColors.primary : AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.label,
                      style: AppTextStyles.labelSmall.copyWith(
                          color:
                              isActive ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.backgroundMid,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${t.count}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? Colors.white
                                : AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── View toggle (List / Calendar) ────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final String mode;
  final ValueChanged<String> onChanged;
  const _ViewToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: AppColors.backgroundMid,
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
              label: 'List',
              icon: Icons.view_list_outlined,
              isActive: mode == 'list',
              onTap: () => onChanged('list')),
          _ToggleBtn(
              label: 'Calendar',
              icon: Icons.calendar_view_month_outlined,
              isActive: mode == 'calendar',
              onTap: () => onChanged('calendar')),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _ToggleBtn(
      {required this.label,
      required this.icon,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive ? AppColors.cardShadow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isActive ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: AppTextStyles.labelSmall.copyWith(
                    color:
                        isActive ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Additional filters: Type, Month, Clear ───────────────────────────────────

class _AdditionalFilters extends StatelessWidget {
  final String typeFilter;
  final int? monthFilter;
  final bool hasActiveFilters;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<int?> onMonthChanged;
  final VoidCallback onClear;
  const _AdditionalFilters({
    required this.typeFilter,
    required this.monthFilter,
    required this.hasActiveFilters,
    required this.onTypeChanged,
    required this.onMonthChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 140,
          child: _CompactDropdown<String>(
            value: typeFilter,
            items: const [
              '',
              HolidayType.national,
              HolidayType.regional,
              HolidayType.company
            ],
            labelBuilder: (v) => v.isEmpty ? 'All Types' : HolidayType.label(v),
            onChanged: (v) => onTypeChanged(v ?? ''),
          ),
        ),
        SizedBox(
          width: 140,
          child: _CompactDropdown<int?>(
            value: monthFilter,
            items: [null, ...List.generate(12, (i) => i)],
            labelBuilder: (v) => v == null ? 'All Months' : _kMonthNames[v],
            onChanged: onMonthChanged,
          ),
        ),
        if (hasActiveFilters)
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close, size: 13, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text('Clear Filters',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.error, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Compact dropdown (shared style) ──────────────────────────────────────────

class _CompactDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T?> onChanged;
  const _CompactDropdown(
      {required this.value,
      required this.items,
      required this.labelBuilder,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.expand_more, size: 18, color: AppColors.textHint),
          style:
              AppTextStyles.labelSmall.copyWith(color: AppColors.textPrimary),
          items: items
              .map((v) => DropdownMenuItem(
                  value: v,
                  child:
                      Text(labelBuilder(v), overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Holiday card (list view) ─────────────────────────────────────────────────

class _HolidayCard extends StatelessWidget {
  final HolidayModel holiday;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  const _HolidayCard({
    required this.holiday,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = HolidayStyles.typeColor(holiday.type);
    final bg = HolidayStyles.typeBg(holiday.type);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5),
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(holiday.name,
                    style: AppTextStyles.label
                        .copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onToggleActive,
                child: _StatusPill(isActive: holiday.isActive),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(
                  label:
                      '${holiday.date.day} ${_kMonthShort[holiday.date.month - 1]} ${holiday.date.year}',
                  color: AppColors.textSecondary,
                  bg: AppColors.backgroundMid,
                  icon: Icons.event_outlined),
              _Badge(
                  label: _kWeekdayShort[holiday.date.weekday - 1],
                  color: AppColors.textSecondary,
                  bg: AppColors.backgroundMid),
              _Badge(
                  label: HolidayType.label(holiday.type), color: color, bg: bg),
              _Badge(
                label: holiday.isOptional ? 'Optional' : 'Mandatory',
                color: holiday.isOptional
                    ? HolidayStyles.optional
                    : AppColors.success,
                bg: holiday.isOptional
                    ? HolidayStyles.optionalBg
                    : AppColors.successContainer,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.business_outlined,
                  size: 12, color: AppColors.textHint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(holiday.branchName,
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ActionIcon(icon: Icons.visibility_outlined, onTap: onView),
              const SizedBox(width: 6),
              _ActionIcon(icon: Icons.edit_outlined, onTap: onEdit),
              const SizedBox(width: 6),
              _ActionIcon(
                  icon: Icons.delete_outline,
                  onTap: onDelete,
                  color: AppColors.error),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final IconData? icon;
  const _Badge(
      {required this.label, required this.color, required this.bg, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4)
          ],
          Text(label,
              style: AppTextStyles.labelSmall.copyWith(
                  color: color, fontWeight: FontWeight.w600, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isActive;
  const _StatusPill({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textHint;
    final bg = isActive ? AppColors.successContainer : AppColors.backgroundMid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _ActionIcon({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ── Pagination ────────────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _PaginationBar(
      {required this.page,
      required this.totalPages,
      required this.onPrev,
      required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: page > 1 ? onPrev : null,
            icon: const Icon(Icons.chevron_left, size: 16),
            label: const Text('Prev'),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.border)),
          ),
          const SizedBox(width: 12),
          Text('Page $page of $totalPages', style: AppTextStyles.labelSmall),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: page < totalPages ? onNext : null,
            icon: const Icon(Icons.chevron_right, size: 16),
            label: const Text('Next'),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.border)),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final int year;
  final VoidCallback onAdd;
  const _EmptyState({required this.year, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18)),
              child: Icon(Icons.event_busy_outlined,
                  size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text('No holidays found for $year', style: AppTextStyles.h4),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add the first holiday'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Calendar view ─────────────────────────────────────────────────────────────

class _CalendarMonthNav extends StatelessWidget {
  final DateTime calMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _CalendarMonthNav(
      {required this.calMonth, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: onPrev,
              color: AppColors.textSecondary),
          Expanded(
            child: Center(
              child: Text(
                  '${_kMonthNames[calMonth.month - 1]} ${calMonth.year}',
                  style: AppTextStyles.labelLarge),
            ),
          ),
          IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: onNext,
              color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime calMonth;
  final List<HolidayModel> holidays;
  final ValueChanged<HolidayModel> onTapHoliday;
  const _CalendarGrid(
      {required this.calMonth,
      required this.holidays,
      required this.onTapHoliday});

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(calMonth.year, calMonth.month);
    final firstWd =
        DateTime(calMonth.year, calMonth.month, 1).weekday % 7; // Sun=0
    final byDay = <int, HolidayModel>{for (final h in holidays) h.date.day: h};

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: _kDayHeaders
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: d == 'SUN'
                                    ? HolidayStyles.sunday
                                    : AppColors.textHint)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, childAspectRatio: 0.85),
            itemCount: firstWd + daysInMonth,
            itemBuilder: (_, idx) {
              if (idx < firstWd) return const SizedBox();
              final day = idx - firstWd + 1;
              final holiday = byDay[day];
              final isSunday = (idx % 7) == 0;
              return GestureDetector(
                onTap: holiday == null ? null : () => onTapHoliday(holiday),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: holiday != null
                              ? HolidayStyles.typeColor(holiday.type)
                              : Colors.transparent,
                        ),
                        alignment: Alignment.center,
                        child: Text('$day',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: holiday != null
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: holiday != null
                                    ? Colors.white
                                    : (isSunday
                                        ? HolidayStyles.sunday
                                        : AppColors.textPrimary))),
                      ),
                      if (holiday != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          holiday.name,
                          style: TextStyle(
                              fontSize: 8,
                              color: HolidayStyles.typeColor(holiday.type),
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarSummaryRow extends StatelessWidget {
  final HolidayModel holiday;
  final VoidCallback onTap;
  const _CalendarSummaryRow({required this.holiday, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = HolidayStyles.typeColor(holiday.type);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(holiday.name,
                    style: AppTextStyles.label
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text(
                  '${holiday.date.day} ${_kMonthShort[holiday.date.month - 1]}',
                  style: AppTextStyles.caption),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        _LegendDot('National', HolidayStyles.national),
        _LegendDot('Regional', HolidayStyles.regional),
        _LegendDot('Company', HolidayStyles.company),
        const _LegendDot('Optional', HolidayStyles.optional),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
