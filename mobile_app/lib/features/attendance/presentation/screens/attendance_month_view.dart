part of 'attendance_screen.dart';

// "Employee Month View" — search any employee, then reuse the exact same
// read-only stats/summary/calendar widget Employee Profile's Attendance tab
// already renders for one employee, instead of duplicating that layout.
class _EmployeeMonthView extends ConsumerStatefulWidget {
  const _EmployeeMonthView();

  @override
  ConsumerState<_EmployeeMonthView> createState() => _EmployeeMonthViewState();
}

class _EmployeeMonthViewState extends ConsumerState<_EmployeeMonthView> {
  EmployeeModel? _selected;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  bool get _isCurrentMonth {
    final n = DateTime.now();
    return _month.year == n.year && _month.month == n.month;
  }

  // Debounce + stale-result protection for the server-side search below.
  // `_searchGeneration` is bumped on every new query; a pending debounce or
  // in-flight request that finds its generation superseded when it wakes up
  // bails out without touching state or hitting the network — matching the
  // generation-counter pattern already used for pagination in
  // employee_providers.dart. Flutter's own Autocomplete/RawAutocomplete adds
  // a second, independent layer of the same protection on top of this (see
  // `_onChangedCallId` in framework source), so a result can never render
  // out of order even if this logic had a bug.
  int _searchGeneration = 0;
  bool _searching = false;
  String? _searchError;
  bool _noResults = false;
  String _lastQuery = '';
  // Captured from fieldViewBuilder purely so Retry (below) can force a real
  // re-search — TextEditingController's setter is a no-op when assigned the
  // value it already holds, so Autocomplete's own change listener (which is
  // what actually re-invokes optionsBuilder and refreshes its results
  // overlay) wouldn't fire from re-calling _searchEmployees directly.
  TextEditingController? _fieldController;

  Future<Iterable<EmployeeModel>> _searchEmployees(TextEditingValue value) async {
    final query = value.text.trim();
    if (query.isEmpty) {
      _searchGeneration++;
      if (mounted)
        setState(() {
          _searching = false;
          _searchError = null;
          _noResults = false;
        });
      return const Iterable<EmployeeModel>.empty();
    }
    _lastQuery = query;

    final generation = ++_searchGeneration;
    if (mounted) {
      setState(() {
        _searching = true;
        _searchError = null;
        _noResults = false;
      });
    }

    await Future.delayed(const Duration(milliseconds: 400));
    if (generation != _searchGeneration) return const Iterable<EmployeeModel>.empty();

    try {
      final result = await ref.read(employeesDataSourceProvider).fetchEmployeesPage(
            page: 1,
            pageSize: 20,
            filters: EmployeeFilters(search: query),
          );
      if (generation != _searchGeneration) return const Iterable<EmployeeModel>.empty();
      if (mounted) {
        setState(() {
          _searching = false;
          _noResults = result.items.isEmpty;
        });
      }
      return result.items;
    } catch (e) {
      if (generation != _searchGeneration) return const Iterable<EmployeeModel>.empty();
      if (mounted) {
        setState(() {
          _searching = false;
          _searchError = userFriendlyMessage(e);
        });
      }
      return const Iterable<EmployeeModel>.empty();
    }
  }

  Widget _searchField() => Autocomplete<EmployeeModel>(
        displayStringForOption: (e) => '${e.fullName} (${e.employeeId})',
        optionsBuilder: _searchEmployees,
        onSelected: (e) => setState(() => _selected = e),
        fieldViewBuilder: (context, controller, focusNode, onSubmit) {
          _fieldController = controller;
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search employee by name or ID…',
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
            ),
          );
        },
      );

  // Small, inline status line below the search field — never a full-screen
  // loader, and never blocks the already-selected employee's view below it.
  Widget _searchStatus() {
    if (_searching) {
      return const Padding(padding: EdgeInsets.only(top: 6), child: LinearProgressIndicator(minHeight: 2));
    }
    if (_searchError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Expanded(child: Text(_searchError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
          TextButton(
            onPressed: () {
              // Round-trip the controller's text through empty and back so
              // Autocomplete's own listener re-invokes _searchEmployees.
              final controller = _fieldController;
              if (controller == null) return;
              final text = _lastQuery;
              controller.text = '';
              controller.text = text;
            },
            child: Text('Retry', style: AppTextStyles.bodySmall),
          ),
        ]),
      );
    }
    if (_noResults) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('No employees match your search.',
            key: const Key('month-no-match'),
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final bigText = MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
    final monthBar = MonthViewMonthBar(
      month: _month,
      onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1, 1)),
      onNext: _isCurrentMonth ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1, 1)),
    );
    // Section 1 — month and employee selection (web: search + month navigator).
    final selection = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 560 && !bigText;
        final search = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('Employee',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          _searchField(),
          _searchStatus(),
        ]);
        final month = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('Month',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          monthBar,
        ]);
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: month),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          search,
          const SizedBox(height: 12),
          month,
        ]);
      }),
    );

    final key = selected == null ? null : (selected.uuid ?? selected.id);
    return RefreshIndicator(
      onRefresh: () async {
        if (key == null) return;
        final k = (employee: key, month: monthViewIso(_month));
        ref.invalidate(employeeMonthViewProvider(k));
        try {
          await ref.read(employeeMonthViewProvider(k).future);
        } catch (_) {}
      },
      child: ListView(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                selection,
                const SizedBox(height: 14),
                if (key == null)
                  const ApprovalsEmptyState(
                    key: Key('month-select-prompt'),
                    kind: ApprovalsStateKind.empty,
                    icon: Icons.person_search_outlined,
                    title: 'Select an employee',
                    message: 'Search for an employee to view their monthly attendance calendar.',
                  )
                else
                  // Section 2 (overview) and 3 (records), or loading / error / denied.
                  MonthViewPanel(key: ValueKey('$key-${monthViewIso(_month)}'), employee: key, month: _month),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// Shared by the FAB (Add Record / Reprocess now live there, not inline in
// the filter list) and previously by _TeamDayView directly.
Future<void> _reprocessAttendance(BuildContext context, WidgetRef ref) async {
  final date = ref.read(hrAttendanceDateFilterProvider) ?? DateTime.now();
  final iso = _isoDate(date);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Reprocess Attendance'),
      content: Text(
        'Recalculate attendance for $iso from all recorded punches? This '
        'may overwrite manual edits made for this day.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: const Text('Reprocess'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final branch = ref.read(hrAttendanceBranchFilterProvider);
  final department = ref.read(hrAttendanceDepartmentFilterProvider);
  final error = await ref.read(attendanceRecordsProvider.notifier).reprocess(
        date: iso,
        branch: branch.isEmpty ? null : branch,
        department: department.isEmpty ? null : department,
      );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(error ?? 'Attendance reprocessed for $iso.'),
    backgroundColor: error == null ? AppColors.success : AppColors.error,
  ));
}
