import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../../../shared/widgets/expandable_fab.dart'
    show expandableFabOpenProvider;
import '../../../../shared/widgets/stat_card.dart';
import '../../../employees/data/models/employee_model.dart';
import '../../../employees/presentation/providers/employee_providers.dart';
import '../../../employees/presentation/widgets/employee_attendance_tab.dart';
import '../../domain/entities/attendance_entity.dart';
import '../providers/attendance_providers.dart';
import '../widgets/hr_correction_card.dart';

// ─── Colour helpers ───────────────────────────────────────────────────────────

Color _statusColor(String s) => switch (s) {
      'Present' => AppColors.success,
      'Late' => AppColors.warning,
      'Absent' => AppColors.error,
      'On Leave' => AppColors.info,
      'Half Day' => AppColors.accentPurple,
      'Weekly Off' => AppColors.textSecondary,
      'Holiday' => AppColors.warning,
      'Incomplete' => AppColors.accentPurple,
      'approved' || 'Approved' => AppColors.success,
      'pending' || 'Pending' => AppColors.warning,
      'rejected' || 'Rejected' => AppColors.error,
      _ => AppColors.textSecondary,
    };

Color _statusBg(String s) => switch (s) {
      'Present' => AppColors.successContainer,
      'Late' => AppColors.warningContainer,
      'Absent' => AppColors.errorContainer,
      'On Leave' => AppColors.infoContainer,
      'Half Day' => AppColors.accentPurpleContainer,
      'Weekly Off' => AppColors.backgroundLow,
      'Holiday' => AppColors.warningContainer,
      'Incomplete' => AppColors.accentPurpleContainer,
      'approved' || 'Approved' => AppColors.successContainer,
      'pending' || 'Pending' => AppColors.warningContainer,
      'rejected' || 'Rejected' => AppColors.errorContainer,
      _ => AppColors.backgroundLow,
    };

const _kAttendanceStatusFilterOptions = <MapEntry<String, String>>[
  MapEntry('', 'All Statuses'),
  MapEntry('present', 'Present'),
  MapEntry('late', 'Late'),
  MapEntry('half_day', 'Half Day'),
  MapEntry('on_leave', 'On Leave'),
  MapEntry('absent', 'Absent'),
  MapEntry('weekly_off', 'Weekly Off'),
  MapEntry('holiday', 'Holiday'),
  MapEntry('incomplete', 'Incomplete'),
];

// Backend summary-chip keys are raw snake_case (e.g. 'on_leave', 'half_day').
// Resolve through the status filter's key→label map first (single source of
// truth for the "correct" display label), falling back to a generic
// snake_case→Title Case conversion for any key not in that list.
String _titleCaseStatus(String key) {
  final match = _kAttendanceStatusFilterOptions.firstWhere(
    (e) => e.key == key,
    orElse: () => const MapEntry('', ''),
  );
  if (match.value.isNotEmpty) return match.value;
  return key
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

const _kAttendanceSortByOptions = <MapEntry<String, String>>[
  MapEntry('name', 'Name'),
  MapEntry('employee_id', 'Employee ID'),
  MapEntry('department', 'Department'),
  MapEntry('branch', 'Branch'),
  MapEntry('clock_in', 'Clock In'),
  MapEntry('status', 'Status'),
];

Color _issueColor(String issueType) => switch (issueType) {
      'no-match' => AppColors.error,
      'duplicate' => AppColors.warning,
      'future' => AppColors.accentPurple,
      _ => AppColors.textSecondary,
    };

Color _issueBg(String issueType) => switch (issueType) {
      'no-match' => AppColors.errorContainer,
      'duplicate' => AppColors.warningContainer,
      'future' => AppColors.accentPurpleContainer,
      _ => AppColors.backgroundLow,
    };

String _initials(String name) {
  final p = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
  if (p.length >= 2) return '${p.first[0]}${p.last[0]}'.toUpperCase();
  return p.isNotEmpty && p.first.isNotEmpty ? p.first[0].toUpperCase() : '?';
}

const _monthNames = [
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
  'Dec',
];
const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _todayDisplay() {
  final now = DateTime.now();
  return '${_weekdayNames[now.weekday - 1]}, ${now.day} ${_monthNames[now.month - 1]} ${now.year}';
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(attendanceDashboardProvider);
    final invalidCount = dashboardAsync.valueOrNull?.invalidPunchesCount ?? 0;
    final unpunchCount = dashboardAsync.valueOrNull?.unPunchesCount ?? 0;

    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        const SliverToBoxAdapter(child: _StatsBar()),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle:
                  AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
              unselectedLabelStyle: AppTextStyles.label,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              dividerColor: AppColors.border,
              tabs: [
                const Tab(text: 'Attendance'),
                const Tab(text: 'OT Entry'),
                _BadgeTab(label: 'Invalid Punches', count: invalidCount),
                _BadgeTab(label: 'Un-punches', count: unpunchCount),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tab,
        children: const [
          _AttendanceTab(),
          _OtEntryTab(),
          _InvalidPunchesTab(),
          _UnpunchesTab(),
        ],
      ),
    );
  }
}

// ─── Tab bar delegate ─────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(_, __, ___) => Container(
        color: AppColors.surface,
        child: tabBar,
      );

  @override
  bool shouldRebuild(_) => false;
}

class _BadgeTab extends StatelessWidget {
  final String label;
  final int count;
  const _BadgeTab({required this.label, required this.count});

  @override
  Widget build(BuildContext context) => Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

// ─── Stats bar ────────────────────────────────────────────────────────────────

class _StatsBar extends ConsumerWidget {
  const _StatsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(attendanceDashboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BlueHeroBanner(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Attendance & Time',
                      style: AppTextStyles.h3.copyWith(color: Colors.white)),
                  Text(_todayDisplay(),
                      style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                  'Monitor daily attendance, overtime, and correction requests',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white.withValues(alpha: 0.85))),
            ],
          ),
        ),
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: dashboardAsync.when(
            data: (d) {
              // A fixed-width horizontally-scrolling strip of the shared
              // StatCard — matching Employees' directory-stats design — so
              // labels like "Present Today" never get squeezed down to
              // "Pres…" on narrow phones.
              final cards = [
                StatCard(
                  icon: Icons.people_alt_outlined,
                  count: d.presentToday,
                  label: 'Present Today',
                  color: AppColors.success,
                ),
                StatCard(
                  icon: Icons.person_off_outlined,
                  count: d.absent,
                  label: 'Absent',
                  color: AppColors.error,
                ),
                StatCard(
                  icon: Icons.schedule_outlined,
                  count: d.lateArrivals,
                  label: 'Late Arrivals',
                  color: AppColors.warning,
                ),
                StatCard(
                  icon: Icons.event_available_outlined,
                  count: d.onLeave,
                  label: 'On Leave',
                  color: AppColors.primary,
                ),
              ];
              return StatCardRow(cards: cards, padding: EdgeInsets.zero);
            },
            loading: () => const SizedBox(
              height: 90,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => SizedBox(
              height: 60,
              child: Center(
                child: Text(friendlyAttendanceError(e),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Tab 1: Attendance ────────────────────────────────────────────────────────

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _shortDate(DateTime d) =>
    '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

// Wraps the "Team Day View" (flat records list) / "Employee Month View"
// (per-employee search + calendar) toggle that web's Attendance & Time page
// has above the records table — the mobile port originally only had the
// Team Day View, with no way to jump to a single employee's monthly
// calendar from this screen (it only existed inside Employee Profile).
class _AttendanceTab extends ConsumerStatefulWidget {
  const _AttendanceTab();

  @override
  ConsumerState<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<_AttendanceTab> {
  int _viewMode = 0; // 0 = Team Day View, 1 = Employee Month View

  @override
  Widget build(BuildContext context) {
    // A nested Scaffold just for this tab's FAB — Add Record / Reprocess only
    // make sense against Team Day View's filters, so the FAB (and its
    // speed-dial actions) only appears there, not on Employee Month View.
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: _ViewModeButton(
                    label: 'Team Day View',
                    icon: Icons.view_agenda_outlined,
                    selected: _viewMode == 0,
                    onTap: () => setState(() => _viewMode = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ViewModeButton(
                    label: 'Employee Month View',
                    icon: Icons.calendar_month_outlined,
                    selected: _viewMode == 1,
                    onTap: () => setState(() => _viewMode = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _viewMode == 0
                ? const _TeamDayView()
                : const _EmployeeMonthView(),
          ),
        ],
      ),
      floatingActionButton: _viewMode == 0
          ? _AttendanceSpeedDial(
              onAddRecord: () => showDialog(
                context: context,
                builder: (_) => const _AttendanceRecordFormDialog.create(),
              ),
              onReprocess: () => _reprocessAttendance(context, ref),
            )
          : null,
    );
  }
}

// Replaces the old always-visible "Add Record" / "Reprocess" OutlinedButtons
// with a single expandable FAB — tapping it reveals both actions as labeled
// mini-FABs instead of the buttons permanently eating a row in the filters.
class _AttendanceSpeedDial extends ConsumerStatefulWidget {
  final VoidCallback onAddRecord;
  final VoidCallback onReprocess;
  const _AttendanceSpeedDial(
      {required this.onAddRecord, required this.onReprocess});

  @override
  ConsumerState<_AttendanceSpeedDial> createState() =>
      _AttendanceSpeedDialState();
}

class _AttendanceSpeedDialState extends ConsumerState<_AttendanceSpeedDial> {
  bool _open = false;

  // Publishes to the same provider shared/widgets/expandable_fab.dart uses —
  // the global voice-mic overlay watches it to step out of the way while
  // this speed dial's mini actions are expanded, instead of colliding with
  // them (see ExpandableFab, which every other multi-action FAB in the app
  // uses; this screen has its own bespoke speed-dial look instead but needs
  // the same overlap fix).
  void _publish(bool value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(expandableFabOpenProvider.notifier);
      if (notifier.state != value) notifier.state = value;
    });
  }

  void _toggle() {
    setState(() => _open = !_open);
    _publish(_open);
  }

  @override
  void dispose() {
    if (_open) {
      final notifier = ref.read(expandableFabOpenProvider.notifier);
      WidgetsBinding.instance
          .addPostFrameCallback((_) => notifier.state = false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: !_open
              ? const SizedBox.shrink()
              : Column(
                  key: const ValueKey('speedDialActions'),
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SpeedDialAction(
                      label: 'Reprocess',
                      icon: Icons.refresh,
                      heroTag: 'attendance-fab-reprocess',
                      onTap: () {
                        _toggle();
                        widget.onReprocess();
                      },
                    ),
                    const SizedBox(height: 12),
                    _SpeedDialAction(
                      label: 'Add Record',
                      icon: Icons.add,
                      heroTag: 'attendance-fab-add-record',
                      onTap: () {
                        _toggle();
                        widget.onAddRecord();
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
        ),
        FloatingActionButton(
          heroTag: 'attendance-fab-main',
          backgroundColor: AppColors.primary,
          onPressed: _toggle,
          child: AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(_open ? Icons.close : Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _SpeedDialAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final String heroTag;
  final VoidCallback onTap;
  const _SpeedDialAction({
    required this.label,
    required this.icon,
    required this.heroTag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: AppColors.elevatedShadow,
            ),
            child: Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.small(
            heroTag: heroTag,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primary,
            onPressed: onTap,
            child: Icon(icon, size: 18),
          ),
        ],
      );
}

class _ViewModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ViewModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
}

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

  Future<Iterable<EmployeeModel>> _searchEmployees(
      TextEditingValue value) async {
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
    if (generation != _searchGeneration)
      return const Iterable<EmployeeModel>.empty();

    try {
      final result =
          await ref.read(employeesDataSourceProvider).fetchEmployeesPage(
                page: 1,
                pageSize: 20,
                filters: EmployeeFilters(search: query),
              );
      if (generation != _searchGeneration)
        return const Iterable<EmployeeModel>.empty();
      if (mounted) {
        setState(() {
          _searching = false;
          _noResults = result.items.isEmpty;
        });
      }
      return result.items;
    } catch (e) {
      if (generation != _searchGeneration)
        return const Iterable<EmployeeModel>.empty();
      if (mounted) {
        setState(() {
          _searching = false;
          _searchError = userFriendlyMessage(e);
        });
      }
      return const Iterable<EmployeeModel>.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Autocomplete<EmployeeModel>(
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
                  prefixIcon: const Icon(Icons.search, size: 16),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border)),
                ),
              );
            },
          ),
        ),
        // Small, inline status line below the search field — never a
        // full-screen loader, and never blocks the already-selected
        // employee's attendance view below it.
        if (_searching)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (_searchError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(_searchError!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error)),
                ),
                TextButton(
                  onPressed: () {
                    // Round-trip the controller's text through empty and
                    // back to force Autocomplete's own listener to fire
                    // twice; the second call is what actually re-invokes
                    // _searchEmployees through the framework's normal path
                    // and refreshes the real results overlay (a fresh
                    // assignment of the *same* text value alone would be a
                    // no-op — see the field's doc comment above).
                    final controller = _fieldController;
                    if (controller == null) return;
                    final text = _lastQuery;
                    controller.text = '';
                    controller.text = text;
                  },
                  child: Text('Retry', style: AppTextStyles.bodySmall),
                ),
              ],
            ),
          )
        else if (_noResults)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text('No employees match your search.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _selected == null
              ? const _EmptyState(
                  message:
                      'Search and select an employee above to view their monthly attendance.')
              : EmployeeAttendanceTab(employee: _selected!),
        ),
      ],
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
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white),
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

class _TeamDayView extends ConsumerStatefulWidget {
  const _TeamDayView();

  @override
  ConsumerState<_TeamDayView> createState() => _TeamDayViewState();
}

class _TeamDayViewState extends ConsumerState<_TeamDayView> {
  late final _searchCtrl =
      TextEditingController(text: ref.read(attendanceRecordsSearchProvider));
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _resetPages(WidgetRef ref) {
    ref.read(attendanceRecordsPageProvider.notifier).state = 1;
    ref.read(overtimePageProvider.notifier).state = 1;
  }

  // The search field previously wrote to attendanceRecordsSearchProvider on
  // every keystroke, which — since AttendanceRecordsNotifier.build() watches
  // that provider — triggered an immediate, non-seamless reload (see the
  // restructuring below for why that used to blank the whole filter panel
  // including this very field, destroying its own focus/cursor mid-type).
  // Debouncing here means a fast typist no longer fires a request-per-
  // character even now that the reload no longer visually disrupts anything.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(attendanceRecordsSearchProvider.notifier).state = value;
      _resetPages(ref);
    });
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final current = ref.read(hrAttendanceDateFilterProvider) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ref.read(hrAttendanceDateFilterProvider.notifier).state = picked;
      _resetPages(ref);
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final branch = ref.read(hrAttendanceBranchFilterProvider);
    final department = ref.read(hrAttendanceDepartmentFilterProvider);
    final date = ref.read(hrAttendanceDateFilterProvider);
    try {
      final bytes = await ref.read(attendanceRepositoryProvider).exportCsv(
            date: date == null ? null : _isoDate(date),
            branch: branch,
            department: department,
          );
      final path = await FilePicker.platform.saveFile(
        fileName:
            'attendance_${date == null ? _isoDate(DateTime.now()) : _isoDate(date)}.csv',
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (!context.mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Attendance exported.'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(friendlyAttendanceError(e)),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(attendanceRecordsProvider);
    // AttendanceDashboardEntity carries 8 fields (presentToday/absent/
    // lateArrivals/onLeave/totalEmployees/summaryChips/invalidPunchesCount/
    // unPunchesCount) — this view only ever reads summaryChips and
    // totalEmployees (see below); the other 6 belong to _StatsBar and the
    // root screen's tab badges, which watch this same provider
    // independently. Selecting just this pair means a dashboard refetch
    // that leaves totalEmployees unchanged (an int, so this comparison is
    // exact) doesn't force the whole filter panel + records list below to
    // rebuild for fields this view never displays. Note: summaryChips is a
    // Map, which compares by identity, not content — a refetch that
    // produces an equal-content-but-new-instance map will still be treated
    // as "changed" here, so the practical benefit is guaranteed for
    // totalEmployees and partial for summaryChips.
    final dashboardSlice = ref.watch(attendanceDashboardProvider.select(
      (async) => (
        chips: async.valueOrNull?.summaryChips,
        total: async.valueOrNull?.totalEmployees,
      ),
    ));
    final branchList = ref.watch(employeeBranchNameListProvider);
    final deptList = ref.watch(employeeDepartmentListProvider);
    final selectedBranch = ref.watch(hrAttendanceBranchFilterProvider);
    final selectedDept = ref.watch(hrAttendanceDepartmentFilterProvider);
    final selectedDate = ref.watch(hrAttendanceDateFilterProvider);
    final selectedStatus = ref.watch(attendanceRecordsStatusFilterProvider);
    final statusLabel = _kAttendanceStatusFilterOptions
        .firstWhere((e) => e.key == selectedStatus,
            orElse: () => _kAttendanceStatusFilterOptions.first)
        .value;
    final selectedSortBy = ref.watch(attendanceRecordsSortByProvider);
    final sortByLabel = _kAttendanceSortByOptions
        .firstWhere((e) => e.key == selectedSortBy,
            orElse: () => _kAttendanceSortByOptions.first)
        .value;
    final selectedSortDir = ref.watch(attendanceRecordsSortDirProvider);
    final chips = dashboardSlice.chips ?? const <String, int>{};
    final totalEmployees =
        dashboardSlice.total ?? recordsAsync.valueOrNull?.results.length ?? 0;

    // The filter panel (including the search field) and the status-chips
    // row used to live INSIDE recordsAsync.when()'s `data:` branch — so
    // every keystroke in the search field, every branch/department/status/
    // sort/date change, and every Prev/Next tap (all of which make
    // AttendanceRecordsNotifier.build() re-run via a *watched* provider,
    // not an invalidate/refresh — see the copyWithPrevious fix above for
    // why that distinction matters) replaced the whole panel with a bare
    // spinner and rebuilt it from scratch once the new page arrived. That
    // destroyed the search field's focus/cursor on every character typed.
    // Moving the panel out here means only the rows below it (still
    // wrapped in `.when()`) show a transient loading state; the filter
    // controls — including whatever the user is mid-typing — are never
    // torn down by a filter/page change.
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(attendanceDashboardProvider);
        await ref.read(attendanceRecordsProvider.notifier).refresh();
      },
      child: ListView(
        // Each TabBarView child would otherwise inherit the same
        // PrimaryScrollController from the enclosing NestedScrollView —
        // fine on mobile (no Scrollbar rendered), but on web/desktop the
        // Scrollbar requires exactly one attached ScrollPosition and
        // throws when multiple tabs' ListViews share the controller.
        primary: false,
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text('Filters',
                        style: AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _Dropdown(
                      value: selectedBranch.isEmpty
                          ? 'All Branches'
                          : selectedBranch,
                      items: ['All Branches', ...branchList],
                      onChanged: (v) {
                        ref
                            .read(hrAttendanceBranchFilterProvider.notifier)
                            .state = (v == 'All Branches') ? '' : v!;
                        _resetPages(ref);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Dropdown(
                      value: selectedDept.isEmpty
                          ? 'All Departments'
                          : selectedDept,
                      items: ['All Departments', ...deptList],
                      onChanged: (v) {
                        ref
                            .read(hrAttendanceDepartmentFilterProvider.notifier)
                            .state = (v == 'All Departments') ? '' : v!;
                        _resetPages(ref);
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search employee…',
                        prefixIcon: const Icon(Icons.search, size: 16),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.border)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Dropdown(
                      value: statusLabel,
                      items: _kAttendanceStatusFilterOptions
                          .map((e) => e.value)
                          .toList(),
                      onChanged: (v) {
                        final entry = _kAttendanceStatusFilterOptions
                            .firstWhere((e) => e.value == v);
                        ref
                            .read(
                                attendanceRecordsStatusFilterProvider.notifier)
                            .state = entry.key;
                        _resetPages(ref);
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(context, ref),
                      child: _FakeInput(
                        value: selectedDate == null
                            ? 'Today'
                            : _shortDate(selectedDate),
                        icon: Icons.calendar_today_outlined,
                      ),
                    ),
                  ),
                  if (selectedDate != null)
                    IconButton(
                      tooltip: 'Reset to today',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        ref
                            .read(hrAttendanceDateFilterProvider.notifier)
                            .state = null;
                        _resetPages(ref);
                      },
                      icon: Icon(Icons.close,
                          size: 18, color: AppColors.textSecondary),
                    ),
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    onPressed: () => _exportCsv(context, ref),
                    icon: const Icon(Icons.download_outlined, size: 15),
                    label: const Text('Export'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: AppTextStyles.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const _ImportAttendanceDialog(),
                    ),
                    icon: const Icon(Icons.upload_outlined, size: 15),
                    label: const Text('Import'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: AppTextStyles.labelSmall,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: _Dropdown(
                      value: sortByLabel,
                      items: _kAttendanceSortByOptions
                          .map((e) => e.value)
                          .toList(),
                      onChanged: (v) {
                        final entry = _kAttendanceSortByOptions
                            .firstWhere((e) => e.value == v);
                        ref
                            .read(attendanceRecordsSortByProvider.notifier)
                            .state = entry.key;
                        _resetPages(ref);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip:
                        selectedSortDir == 'asc' ? 'Ascending' : 'Descending',
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      ref
                          .read(attendanceRecordsSortDirProvider.notifier)
                          .state = selectedSortDir == 'asc' ? 'desc' : 'asc';
                      _resetPages(ref);
                    },
                    icon: Icon(
                      selectedSortDir == 'asc'
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 16,
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...chips.entries.map((e) {
                  final label = _titleCaseStatus(e.key);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _Chip(
                        label: '${e.value} $label',
                        color: _statusColor(label),
                        bg: _statusBg(label)),
                  );
                }),
                Text('Total: $totalEmployees employees',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          recordsAsync.when(
            data: (page) {
              final rows = page.results;
              return Column(
                children: [
                  if (rows.isEmpty)
                    const _EmptyState(
                        message: 'No attendance records for this day.'),
                  ...rows.map((r) => _AttendanceCard(record: r)),
                  if (page.totalPages > 1) ...[
                    const SizedBox(height: 4),
                    _PaginationBar(
                      page: page.page,
                      totalPages: page.totalPages,
                      onPrev: page.page > 1
                          ? () => ref
                              .read(attendanceRecordsPageProvider.notifier)
                              .state = page.page - 1
                          : null,
                      onNext: page.page < page.totalPages
                          ? () => ref
                              .read(attendanceRecordsPageProvider.notifier)
                              .state = page.page + 1
                          : null,
                    ),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AppErrorState(
              message: friendlyAttendanceError(e),
              padding: const EdgeInsets.all(24),
              onRetry: () =>
                  ref.read(attendanceRecordsProvider.notifier).refresh(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _PaginationBar(
      {required this.page, required this.totalPages, this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            onPressed: onPrev,
            style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
            child: const Text('Prev'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('Page $page of $totalPages',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
          OutlinedButton(
            onPressed: onNext,
            style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
            child: const Text('Next'),
          ),
        ],
      );
}

class _ImportAttendanceDialog extends ConsumerStatefulWidget {
  const _ImportAttendanceDialog();

  @override
  ConsumerState<_ImportAttendanceDialog> createState() =>
      _ImportAttendanceDialogState();
}

class _ImportAttendanceDialogState
    extends ConsumerState<_ImportAttendanceDialog> {
  PlatformFile? _file;
  bool _uploading = false;
  String? _error;
  ImportResultEntity? _result;
  bool _downloadingSample = false;

  Future<void> _downloadSample(String format) async {
    setState(() => _downloadingSample = true);
    try {
      final bytes = await ref
          .read(attendanceRepositoryProvider)
          .fetchImportSample(format: format);
      final path = await FilePicker.platform.saveFile(
        fileName: 'attendance_import_sample.$format',
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: [format],
      );
      if (!mounted) return;
      setState(() => _downloadingSample = false);
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Sample template downloaded.'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloadingSample = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(friendlyAttendanceError(e)),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _file = result.files.single;
      _error = null;
    });
  }

  Future<void> _upload() async {
    final file = _file;
    if (file == null || file.bytes == null) {
      setState(() => _error = 'Please choose a CSV file.');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(attendanceImportActionProvider)
          .upload(file.bytes!, file.name);
      if (!mounted) return;
      setState(() {
        _result = result;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyAttendanceError(e);
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return AlertDialog(
      title: const Text('Import Attendance'),
      content: SizedBox(
        width: 340,
        child: result != null ? _buildResult(result) : _buildPicker(),
      ),
      actions: result != null
          ? [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'))
            ]
          : [
              TextButton(
                onPressed: _uploading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _uploading ? null : _upload,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
                child: _uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Upload'),
              ),
            ],
    );
  }

  Widget _buildPicker() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoBanner(
            icon: Icons.info_outline,
            color: AppColors.info,
            bg: AppColors.infoContainer,
            border: AppColors.info.withValues(alpha: 0.3),
            message:
                'Required columns: employee_id, date, punch_in, punch_out — CSV only, max 5 MB.',
          ),
          const SizedBox(height: 6),
          Text('Example: EMP001,2026-07-02,09:05,18:15',
              style:
                  AppTextStyles.labelSmall.copyWith(color: AppColors.textHint)),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Download sample:',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: 4),
              TextButton(
                onPressed:
                    _downloadingSample ? null : () => _downloadSample('csv'),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: Text('CSV', style: AppTextStyles.bodySmall),
              ),
              Text('·', style: AppTextStyles.caption),
              TextButton(
                onPressed:
                    _downloadingSample ? null : () => _downloadSample('xlsx'),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: Text('XLSX', style: AppTextStyles.bodySmall),
              ),
              if (_downloadingSample) ...[
                const SizedBox(width: 6),
                const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickFile,
            child: _FakeInput(
                value: _file?.name ?? 'Choose CSV file',
                icon: Icons.attach_file),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!,
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ],
        ],
      );

  Widget _buildResult(ImportResultEntity r) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: _KV(k: 'Total Rows', v: '${r.totalRows}')),
            Expanded(
                child: _KV(
                    k: 'Success',
                    v: '${r.success}',
                    vColor: AppColors.success)),
            Expanded(
                child: _KV(
                    k: 'Failed',
                    v: '${r.failed}',
                    vColor: r.failed > 0 ? AppColors.error : null)),
          ]),
          if (r.errors.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text('First errors',
                style: AppTextStyles.label
                    .copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 4),
            ...r.errors.take(5).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('Row ${e.row}: ${e.message}',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.error)),
                )),
          ],
        ],
      );
}

class _AttendanceCard extends ConsumerWidget {
  final AttendanceRowEntity record;
  const _AttendanceCard({required this.record});

  // recordId is only present when an AttendanceRecord exists for this employee/date.
  // The backend route is `records/<uuid:pk>/` — a strict UUID path converter — so
  // there is no way to look up a detail for rows with no record (e.g. Absent).
  void _showDetail(BuildContext context, WidgetRef ref) {
    final recordId = record.recordId;
    if (recordId == null) return;
    final key = (id: recordId, isEmployeeId: false);
    showDialog(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final detailAsync = ref.watch(attendanceRecordDetailProvider(key));
          return AlertDialog(
            title: Text(record.name),
            content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: detailAsync.when(
                  data: (d) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _KVRow('Status', d.status),
                      _KVRow('Clock In', d.clockIn),
                      _KVRow('Clock Out', d.clockOut),
                      _KVRow('Total Hours', d.totalHours),
                      _KVRow('Overtime', d.overtime),
                      if (d.note != null && d.note!.isNotEmpty)
                        _KVRow('Note', d.note!),
                      if (d.punches.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Punches',
                            style: AppTextStyles.label.copyWith(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                        ...d.punches.map((p) => Text(
                            '${p.punchType} · ${p.time} · ${p.mode}',
                            style: AppTextStyles.bodySmall)),
                      ],
                      const SizedBox(height: 12),
                      Divider(height: 1, color: AppColors.backgroundLow),
                      const SizedBox(height: 10),
                      Text('Correction Requests',
                          style: AppTextStyles.label.copyWith(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 6),
                      Consumer(builder: (context, ref, _) {
                        final correctionsAsync = ref.watch(
                          attendanceRecordCorrectionsProvider(
                              (employeeId: d.employeeId, date: d.date)),
                        );
                        return correctionsAsync.when(
                          data: (rows) => rows.isEmpty
                              ? Text('No correction requests for this day.',
                                  style: AppTextStyles.labelSmall
                                      .copyWith(color: AppColors.textSecondary))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: rows
                                      .map((c) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 6),
                                            child: Text(
                                              '${c.punchType} · ${c.reason} · ${c.status}',
                                              style: AppTextStyles.bodySmall,
                                            ),
                                          ))
                                      .toList(),
                                ),
                          loading: () => const SizedBox(
                            height: 20,
                            child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          error: (e, _) => Text(friendlyAttendanceError(e),
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.error)),
                        );
                      }),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: AppColors.backgroundLow),
                      const SizedBox(height: 10),
                      Text('Audit History',
                          style: AppTextStyles.label.copyWith(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 6),
                      Consumer(builder: (context, ref, _) {
                        final recordId = d.recordId;
                        if (recordId == null) {
                          return Text('No audit history for this record yet.',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.textSecondary));
                        }
                        final auditAsync =
                            ref.watch(attendanceRecordAuditProvider(recordId));
                        return auditAsync.when(
                          data: (entries) => entries.isEmpty
                              ? Text('No audit history for this record yet.',
                                  style: AppTextStyles.labelSmall
                                      .copyWith(color: AppColors.textSecondary))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: entries
                                      .map((a) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(a.action,
                                                    style: AppTextStyles.label
                                                        .copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 12)),
                                                Text(
                                                    '${a.performedBy} · ${a.performedAt}',
                                                    style: AppTextStyles
                                                        .labelSmall
                                                        .copyWith(
                                                            color: AppColors
                                                                .textSecondary)),
                                                if (a.oldValue != null ||
                                                    a.newValue != null)
                                                  Text(
                                                      '${a.oldValue ?? '—'} → ${a.newValue ?? '—'}',
                                                      style: const TextStyle(
                                                          fontSize: 11)),
                                                if (a.remarks != null &&
                                                    a.remarks!.isNotEmpty)
                                                  Text(a.remarks!,
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          fontStyle: FontStyle
                                                              .italic)),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                ),
                          loading: () => const SizedBox(
                            height: 20,
                            child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          error: (e, _) => Text(friendlyAttendanceError(e),
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.error)),
                        );
                      }),
                    ],
                  ),
                  loading: () => const SizedBox(
                    height: 60,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (e, _) => Text(friendlyAttendanceError(e),
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error)),
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
              Builder(builder: (context) {
                final d = detailAsync.valueOrNull;
                return ElevatedButton.icon(
                  onPressed: d == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (_) => _AttendanceRecordFormDialog.edit(
                              recordId: recordId,
                              employeeId: d.employeeId,
                              employeeName: record.name,
                              date: DateTime.parse(d.date),
                              initialStatus: d.statusKey,
                              initialClockIn: d.clockIn,
                              initialClockOut: d.clockOut,
                              initialNote: d.note,
                            ),
                          );
                        },
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(name: record.name, initials: record.initials),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.name,
                            style: AppTextStyles.label
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text('${record.employeeId} · ${record.department}',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  _StatusBadge(status: record.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _TimeCell(
                        label: 'Clock In',
                        value: record.clockIn,
                        isLate: record.isLate)),
                Expanded(
                    child:
                        _TimeCell(label: 'Clock Out', value: record.clockOut)),
                Expanded(
                    child: _TimeCell(
                        label: 'Total Hrs', value: record.totalHours)),
                if (record.ot != '—')
                  Expanded(
                      child:
                          _TimeCell(label: 'OT', value: record.ot, isOt: true)),
              ]),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.business_outlined,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(record.branch,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary)),
                  ]),
                  if (record.recordId != null)
                    OutlinedButton(
                      onPressed: () => _showDetail(context, ref),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.4)),
                        foregroundColor: AppColors.primary,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text('View',
                          style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    )
                  else
                    Text('No record',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textHint)),
                ],
              ),
            ],
          ),
        ),
      );
}

const _kAttendanceRecordStatuses = <MapEntry<String, String>>[
  MapEntry('present', 'Present'),
  MapEntry('late', 'Late Arrival'),
  MapEntry('half_day', 'Half Day'),
  MapEntry('on_leave', 'On Leave'),
  MapEntry('absent', 'Absent'),
  MapEntry('weekly_off', 'Week Off'),
  MapEntry('holiday', 'Holiday'),
  MapEntry('incomplete', 'Incomplete'),
];

// Handles both manual creation and editing of an attendance record — mirrors
// web's shared AttendanceEditForm (same status list, same required "reason"
// audit field). [recordId] non-null means edit mode: employee/date are then
// fixed (display-only) and status/clock_in/clock_out/note are pre-filled from
// the existing record.
class _AttendanceRecordFormDialog extends ConsumerStatefulWidget {
  final String? recordId;
  final String? employeeId;
  final String? employeeName;
  final DateTime? date;
  final String? initialStatus;
  final String? initialClockIn;
  final String? initialClockOut;
  final String? initialNote;

  const _AttendanceRecordFormDialog.create()
      : recordId = null,
        employeeId = null,
        employeeName = null,
        date = null,
        initialStatus = null,
        initialClockIn = null,
        initialClockOut = null,
        initialNote = null;

  const _AttendanceRecordFormDialog.edit({
    required String this.recordId,
    required String this.employeeId,
    required String this.employeeName,
    required DateTime this.date,
    this.initialStatus,
    this.initialClockIn,
    this.initialClockOut,
    this.initialNote,
  });

  bool get isEdit => recordId != null;

  @override
  ConsumerState<_AttendanceRecordFormDialog> createState() =>
      _AttendanceRecordFormDialogState();
}

class _AttendanceRecordFormDialogState
    extends ConsumerState<_AttendanceRecordFormDialog> {
  String? _employeeId;
  DateTime _date = DateTime.now();
  late String _status;
  TimeOfDay? _clockIn;
  TimeOfDay? _clockOut;
  final _noteCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty || raw == '—') return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  @override
  void initState() {
    super.initState();
    _employeeId = widget.employeeId;
    if (widget.date != null) _date = widget.date!;
    _status = widget.initialStatus ?? 'present';
    _clockIn = _parseTime(widget.initialClockIn);
    _clockOut = _parseTime(widget.initialClockOut);
    _noteCtrl.text = widget.initialNote ?? '';
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isIn ? _clockIn : _clockOut) ?? TimeOfDay.now(),
    );
    if (picked != null)
      setState(() => isIn ? _clockIn = picked : _clockOut = picked);
  }

  Future<void> _submit() async {
    if (!widget.isEdit && (_employeeId == null || _employeeId!.isEmpty)) {
      setState(() => _error = 'Please select an employee.');
      return;
    }
    if (_clockIn != null && _clockOut != null) {
      final inMin = _clockIn!.hour * 60 + _clockIn!.minute;
      final outMin = _clockOut!.hour * 60 + _clockOut!.minute;
      if (outMin <= inMin) {
        setState(() => _error = 'Clock out must be after clock in.');
        return;
      }
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      setState(() =>
          _error = "Reason is required — it's recorded in the audit log.");
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final notifier = ref.read(attendanceRecordsProvider.notifier);
    final error = widget.isEdit
        ? await notifier.updateRecord(
            widget.recordId!,
            status: _status,
            clockIn: _clockIn == null ? null : _fmtTime(_clockIn!),
            clockOut: _clockOut == null ? null : _fmtTime(_clockOut!),
            note: _noteCtrl.text.trim(),
            reason: _reasonCtrl.text.trim(),
          )
        : await notifier.createRecord(
            employeeId: _employeeId!,
            date: _fmtDate(_date),
            status: _status,
            clockIn: _clockIn == null ? null : _fmtTime(_clockIn!),
            clockOut: _clockOut == null ? null : _fmtTime(_clockOut!),
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            reason: _reasonCtrl.text.trim(),
          );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isEdit
            ? 'Attendance record updated.'
            : 'Attendance record created.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    return AlertDialog(
      title: Text(widget.isEdit
          ? 'Edit Attendance — ${widget.employeeName}'
          : 'Add Attendance Record'),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Text(_error!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error)),
                const SizedBox(height: 10),
              ],
              if (!widget.isEdit) ...[
                const _FormLabel('Employee'),
                employeesAsync.when(
                  data: (employees) => DropdownButtonFormField<String>(
                    initialValue: _employeeId,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Select employee',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 9),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    isExpanded: true,
                    items: employees
                        .map((e) => DropdownMenuItem(
                              value: e.employeeId,
                              child: Text('${e.fullName} (${e.employeeId})',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _employeeId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(friendlyAttendanceError(e),
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error)),
                ),
                const SizedBox(height: 12),
                const _FormLabel('Date'),
                GestureDetector(
                  onTap: _pickDate,
                  child: _FakeInput(
                      value: _fmtDate(_date),
                      icon: Icons.calendar_today_outlined),
                ),
                const SizedBox(height: 12),
              ] else ...[
                _KVRow('Employee',
                    '${widget.employeeName} (${widget.employeeId})'),
                _KVRow('Date', _fmtDate(widget.date!)),
                const SizedBox(height: 8),
              ],
              const _FormLabel('Status'),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                isExpanded: true,
                items: _kAttendanceRecordStatuses
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const _FormLabel('Clock In'),
                      GestureDetector(
                        onTap: () => _pickTime(true),
                        child: _FakeInput(
                          value: _clockIn == null
                              ? '—'
                              : _fmtTime(_clockIn!).substring(0, 5),
                          icon: Icons.access_time,
                        ),
                      ),
                    ])),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const _FormLabel('Clock Out'),
                      GestureDetector(
                        onTap: () => _pickTime(false),
                        child: _FakeInput(
                          value: _clockOut == null
                              ? '—'
                              : _fmtTime(_clockOut!).substring(0, 5),
                          icon: Icons.access_time,
                        ),
                      ),
                    ])),
              ]),
              const SizedBox(height: 12),
              const _FormLabel('Note'),
              TextField(
                controller: _noteCtrl,
                maxLength: 200,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Optional note',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const _FormLabel('Reason *'),
              TextField(
                controller: _reasonCtrl,
                maxLength: 500,
                maxLines: 2,
                decoration: InputDecoration(
                  isDense: true,
                  hintText:
                      "Why this record is being ${widget.isEdit ? 'edited' : 'added'}…",
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white),
          child: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(widget.isEdit ? 'Save Changes' : 'Add Record'),
        ),
      ],
    );
  }
}

class _KVRow extends StatelessWidget {
  final String k, v;
  const _KVRow(this.k, this.v);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('$k: $v', style: AppTextStyles.bodySmall),
      );
}

class _TimeCell extends StatelessWidget {
  final String label;
  final String value;
  final bool isLate, isOt;
  const _TimeCell(
      {required this.label,
      required this.value,
      this.isLate = false,
      this.isOt = false});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textHint, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.label.copyWith(
              color: isLate
                  ? AppColors.error
                  : isOt
                      ? AppColors.success
                      : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      );
}

// ─── Tab 2: OT Entry ──────────────────────────────────────────────────────────

class _OtEntryTab extends ConsumerStatefulWidget {
  const _OtEntryTab();

  @override
  ConsumerState<_OtEntryTab> createState() => _OtEntryTabState();
}

class _OtEntryTabState extends ConsumerState<_OtEntryTab> {
  String? _employeeId;
  String _otType = 'regular';
  DateTime _date = DateTime.now();
  TimeOfDay? _otStart;
  TimeOfDay? _otEnd;
  final _approvedByCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  static const _otTypeLabels = {
    'regular': 'Regular (1.5×)',
    'holiday': 'Holiday (2×)',
    'weekly_off': 'Weekly Off (1.5×)',
  };

  @override
  void dispose() {
    _approvedByCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _otStart : _otEnd) ?? TimeOfDay.now(),
    );
    if (picked != null)
      setState(() => isStart ? _otStart = picked : _otEnd = picked);
  }

  Future<void> _submit() async {
    if (_employeeId == null) {
      setState(() => _error = 'Please select an employee.');
      return;
    }
    if (_otStart == null || _otEnd == null) {
      setState(() => _error = 'Please select OT start and end times.');
      return;
    }
    final startMinutes = _otStart!.hour * 60 + _otStart!.minute;
    final endMinutes = _otEnd!.hour * 60 + _otEnd!.minute;
    if (endMinutes <= startMinutes) {
      setState(() => _error = 'OT end time must be after the start time.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref.read(overtimeListProvider.notifier).create(
          employeeId: _employeeId!,
          date: _fmtDate(_date),
          otType: _otType,
          otStart: _fmtTime(_otStart!),
          otEnd: _fmtTime(_otEnd!),
          approvedBy: _approvedByCtrl.text.trim().isEmpty
              ? null
              : _approvedByCtrl.text.trim(),
          reason:
              _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _otStart = null;
      _otEnd = null;
      _approvedByCtrl.clear();
      _reasonCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: const Text('OT entry added.'),
          backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final overtimeAsync = ref.watch(overtimeListProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(overtimeListProvider.notifier).refresh(),
      child: ListView(
        primary: false,
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.timer_outlined,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Add OT Entry', style: AppTextStyles.h4),
                ]),
                const SizedBox(height: 16),
                const _FormLabel('Employee'),
                employeesAsync.when(
                  data: (employees) => DropdownButtonFormField<String>(
                    initialValue: _employeeId,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Select employee',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 9),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    isExpanded: true,
                    items: employees
                        .map((e) => DropdownMenuItem(
                              value: e.employeeId,
                              child: Text('${e.fullName} (${e.employeeId})',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _employeeId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(friendlyAttendanceError(e),
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error)),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const _FormLabel('Date'),
                        GestureDetector(
                          onTap: _pickDate,
                          child: _FakeInput(
                              value: _fmtDate(_date),
                              icon: Icons.calendar_today_outlined),
                        ),
                      ])),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const _FormLabel('OT Type'),
                        DropdownButtonFormField<String>(
                          initialValue: _otType,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          isExpanded: true,
                          items: _otTypeLabels.entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (v) => setState(() => _otType = v!),
                        ),
                      ])),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const _FormLabel('OT Start'),
                        GestureDetector(
                          onTap: () => _pickTime(true),
                          child: _FakeInput(
                            value: _otStart?.format(context) ?? 'Select time',
                            icon: Icons.access_time_outlined,
                          ),
                        ),
                      ])),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const _FormLabel('OT End'),
                        GestureDetector(
                          onTap: () => _pickTime(false),
                          child: _FakeInput(
                            value: _otEnd?.format(context) ?? 'Select time',
                            icon: Icons.access_time_outlined,
                          ),
                        ),
                      ])),
                ]),
                const SizedBox(height: 12),
                const _FormLabel(
                    'Approved By (optional — employee ID or name)'),
                TextField(
                  controller: _approvedByCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. E001 or Jane Doe',
                    hintStyle: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                const _FormLabel('Reason / Work Done'),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Describe the overtime work…',
                    hintStyle: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  style: AppTextStyles.bodySmall,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(_error!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error)),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add, size: 16),
                    label: const Text('Add OT Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: AppTextStyles.label
                          .copyWith(fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Icon(Icons.table_rows_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('OT Records', style: AppTextStyles.h4),
          ]),
          const SizedBox(height: 10),
          overtimeAsync.when(
            data: (page) => page.results.isEmpty
                ? const _EmptyState(message: 'No OT entries recorded yet.')
                : Column(children: [
                    ...page.results.map((r) => _OtCard(record: r)),
                    if (page.totalPages > 1) ...[
                      const SizedBox(height: 4),
                      _PaginationBar(
                        page: page.page,
                        totalPages: page.totalPages,
                        onPrev: page.page > 1
                            ? () => ref
                                .read(overtimePageProvider.notifier)
                                .state = page.page - 1
                            : null,
                        onNext: page.page < page.totalPages
                            ? () => ref
                                .read(overtimePageProvider.notifier)
                                .state = page.page + 1
                            : null,
                      ),
                    ],
                  ]),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            // Was plain error text with no way to recover short of an
            // undiscoverable pull-to-refresh — every sibling HR tab
            // (Team Day View, Invalid Punches, Un-punches) already uses
            // this same _ErrorState-with-Retry pattern for its list.
            error: (e, _) => AppErrorState(
              message: friendlyAttendanceError(e),
              padding: const EdgeInsets.symmetric(vertical: 24),
              onRetry: () => ref.read(overtimeListProvider.notifier).refresh(),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtCard extends StatelessWidget {
  final OvertimeRowEntity record;
  const _OtCard({required this.record});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _Avatar(name: record.name, initials: record.initials),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(record.name,
                        style: AppTextStyles.label
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(record.employeeId,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary)),
                  ])),
              _StatusBadge(status: record.status),
            ]),
            const SizedBox(height: 10),
            Divider(height: 1, color: AppColors.backgroundLow),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _KV(k: 'Date', v: record.date)),
              Expanded(
                  child: _KV(
                      k: 'OT Hrs',
                      v: record.otHours,
                      vColor: AppColors.primary)),
              Expanded(child: _KV(k: 'Type', v: record.otType)),
              Expanded(
                  child: _KV(
                      k: 'Amount',
                      v: '₹ ${record.otAmount}',
                      vColor: AppColors.success)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.person_outline,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('Approved by: ${record.approvedBy}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textSecondary)),
            ]),
          ]),
        ),
      );
}

// ─── Tab 3: Invalid Punches (Assign / Convert / Discard) ───────────────────────

class _InvalidPunchesTab extends ConsumerWidget {
  const _InvalidPunchesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invalidAsync = ref.watch(invalidPunchesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(invalidPunchesProvider.notifier).refresh(),
      child: ListView(
        primary: false,
        padding: const EdgeInsets.all(12),
        children: [
          _InfoBanner(
            icon: Icons.info_outline,
            color: AppColors.info,
            bg: AppColors.infoContainer,
            border: AppColors.info.withValues(alpha: 0.3),
            message:
                'These punches could not be matched to an employee or contain data errors. Assign for investigation, convert to a valid punch, or discard.',
          ),
          const SizedBox(height: 12),
          invalidAsync.when(
            data: (rows) => rows.isEmpty
                ? const _EmptyState(message: 'No invalid punches for today.')
                : Column(
                    children:
                        rows.map((p) => _InvalidPunchCard(punch: p)).toList()),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AppErrorState(
              message: friendlyAttendanceError(e),
              padding: const EdgeInsets.symmetric(vertical: 24),
              onRetry: () =>
                  ref.read(invalidPunchesProvider.notifier).refresh(),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvalidPunchCard extends ConsumerStatefulWidget {
  final InvalidPunchEntity punch;
  const _InvalidPunchCard({required this.punch});

  @override
  ConsumerState<_InvalidPunchCard> createState() => _InvalidPunchCardState();
}

class _InvalidPunchCardState extends ConsumerState<_InvalidPunchCard> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Done.'),
        backgroundColor: error != null ? AppColors.error : AppColors.success,
      ),
    );
  }

  Future<void> _assign() async {
    final assignedTo = await showDialog<String>(
      context: context,
      builder: (_) => const _AssignPunchDialog(),
    );
    if (assignedTo == null || !mounted) return;
    await _run(() => ref
        .read(invalidPunchesProvider.notifier)
        .assign(widget.punch.id, assignedTo: assignedTo));
  }

  Future<void> _convert() async {
    final result = await showDialog<({String punchType, String time})>(
      context: context,
      builder: (_) => const _ConvertPunchDialog(),
    );
    if (result == null || !mounted) return;
    await _run(() => ref.read(invalidPunchesProvider.notifier).convert(
          widget.punch.id,
          targetPunchType: result.punchType,
          targetTime: result.time,
        ));
  }

  Future<void> _discard() async {
    final remarks = await showDialog<String>(
      context: context,
      builder: (_) => const _DiscardPunchDialog(),
    );
    if (remarks == null || !mounted) return;
    await _run(() => ref
        .read(invalidPunchesProvider.notifier)
        .discard(widget.punch.id, remarks: remarks));
  }

  @override
  Widget build(BuildContext context) {
    final punch = widget.punch;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.backgroundLow,
                  borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                Icon(Icons.devices_outlined,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(punch.deviceId,
                    style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ]),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _issueBg(punch.issueType),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(punch.issue,
                  style: AppTextStyles.labelSmall.copyWith(
                      color: _issueColor(punch.issueType),
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.backgroundLow),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _KV(k: 'Raw Time', v: punch.rawTime, small: true)),
            Expanded(child: _KV(k: 'Card/Bio', v: punch.biometricId)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _KV(k: 'Suggested Fix', v: punch.suggestedMatch)),
            Expanded(child: _KV(k: 'Branch', v: punch.branch)),
          ]),
          const SizedBox(height: 10),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _assign,
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8)),
                  child: Text('Assign', style: AppTextStyles.bodySmall),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: _convert,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Text('Convert', style: AppTextStyles.bodySmall),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: _discard,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Text('Discard', style: AppTextStyles.bodySmall),
                ),
              ),
            ]),
        ]),
      ),
    );
  }
}

class _AssignPunchDialog extends ConsumerStatefulWidget {
  const _AssignPunchDialog();
  @override
  ConsumerState<_AssignPunchDialog> createState() => _AssignPunchDialogState();
}

class _AssignPunchDialogState extends ConsumerState<_AssignPunchDialog> {
  String? _selectedId;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final hrUsersAsync = ref.watch(hrUsersProvider);
    return AlertDialog(
      title: const Text('Assign Invalid Punch'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FormLabel('HR User'),
            hrUsersAsync.when(
              data: (users) => DropdownButtonFormField<String>(
                initialValue: _selectedId,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Select HR user',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                isExpanded: true,
                items: users
                    .map((u) => DropdownMenuItem(
                          value: u.id,
                          child: Text('${u.fullName} (${u.employeeId})',
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(friendlyAttendanceError(e),
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_selectedId == null) {
              setState(() => _error = 'Please select an HR user.');
              return;
            }
            Navigator.pop(context, _selectedId);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}

class _ConvertPunchDialog extends StatefulWidget {
  const _ConvertPunchDialog();
  @override
  State<_ConvertPunchDialog> createState() => _ConvertPunchDialogState();
}

class _ConvertPunchDialogState extends State<_ConvertPunchDialog> {
  String _punchType = 'OUT';
  TimeOfDay? _time;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Convert Invalid Punch'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FormLabel('Punch Type'),
            DropdownButtonFormField<String>(
              initialValue: _punchType,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'IN', child: Text('IN')),
                DropdownMenuItem(value: 'OUT', child: Text('OUT')),
              ],
              onChanged: (v) => setState(() => _punchType = v!),
            ),
            const SizedBox(height: 12),
            const _FormLabel('Target Time'),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                    context: context, initialTime: _time ?? TimeOfDay.now());
                if (picked != null) setState(() => _time = picked);
              },
              child: _FakeInput(
                value: _time?.format(context) ?? 'Select time',
                icon: Icons.access_time_outlined,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_time == null) {
              setState(() => _error = 'Please select a target time.');
              return;
            }
            final hh = _time!.hour.toString().padLeft(2, '0');
            final mm = _time!.minute.toString().padLeft(2, '0');
            Navigator.pop(context, (punchType: _punchType, time: '$hh:$mm'));
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white),
          child: const Text('Convert'),
        ),
      ],
    );
  }
}

class _DiscardPunchDialog extends StatefulWidget {
  const _DiscardPunchDialog();
  @override
  State<_DiscardPunchDialog> createState() => _DiscardPunchDialogState();
}

class _DiscardPunchDialogState extends State<_DiscardPunchDialog> {
  final _remarksCtrl = TextEditingController();

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Discard Invalid Punch'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FormLabel('Remarks (optional)'),
            TextField(
              controller: _remarksCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Why is this punch being discarded?',
                hintStyle:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(10),
              ),
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _remarksCtrl.text.trim()),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error, foregroundColor: Colors.white),
          child: const Text('Discard'),
        ),
      ],
    );
  }
}

// ─── Tab 4: Un-punches ────────────────────────────────────────────────────────

class _UnpunchesTab extends ConsumerWidget {
  const _UnpunchesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unpunchesAsync = ref.watch(unpunchesProvider);
    final statusFilter = ref.watch(hrCorrectionsStatusFilterProvider);
    final branchFilter = ref.watch(hrAttendanceBranchFilterProvider);
    final departmentFilter = ref.watch(hrAttendanceDepartmentFilterProvider);
    final correctionsFilter = (
      status: statusFilter,
      branch: branchFilter,
      department: departmentFilter
    );
    final correctionsAsync =
        ref.watch(hrCorrectionsProvider(correctionsFilter));

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(unpunchesProvider.notifier).refresh();
        await ref
            .read(hrCorrectionsProvider(correctionsFilter).notifier)
            .refresh();
      },
      child: ListView(
        primary: false,
        padding: const EdgeInsets.all(12),
        children: [
          _InfoBanner(
            icon: Icons.warning_amber_outlined,
            color: AppColors.warning,
            bg: AppColors.warningContainer,
            border: AppColors.warning.withValues(alpha: 0.3),
            message:
                'These employees have a Clock In but no matching Clock Out for that day. Approve their pending correction request to resolve it, or wait for them to submit one.',
          ),
          const SizedBox(height: 12),
          unpunchesAsync.when(
            data: (rows) => rows.isEmpty
                ? const _EmptyState(message: 'No un-punches for today.')
                : Column(
                    children:
                        rows.map((r) => _UnpunchCard(record: r)).toList()),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AppErrorState(
              message: friendlyAttendanceError(e),
              padding: const EdgeInsets.symmetric(vertical: 24),
              onRetry: () => ref.read(unpunchesProvider.notifier).refresh(),
            ),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          Row(children: [
            Icon(Icons.fact_check_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('Correction Requests', style: AppTextStyles.h4),
          ]),
          const SizedBox(height: 10),
          _Dropdown(
            value: switch (statusFilter) {
              'pending' => 'Pending — Manager',
              'l2_pending' => 'Pending — HR',
              'approved' => 'Approved',
              'rejected' => 'Rejected',
              _ => 'All',
            },
            items: const [
              'All',
              'Pending — Manager',
              'Pending — HR',
              'Approved',
              'Rejected',
            ],
            onChanged: (v) => ref
                .read(hrCorrectionsStatusFilterProvider.notifier)
                .state = switch (v) {
              'Pending — Manager' => 'pending',
              'Pending — HR' => 'l2_pending',
              'Approved' => 'approved',
              'Rejected' => 'rejected',
              _ => 'all',
            },
          ),
          const SizedBox(height: 10),
          correctionsAsync.when(
            data: (rows) => rows.isEmpty
                ? const _EmptyState(message: 'No correction requests found.')
                : Column(
                    children: rows
                        .map((r) => HrCorrectionCard(
                              record: r,
                              onReview: (approve) => ref
                                  .read(hrCorrectionsProvider(correctionsFilter)
                                      .notifier)
                                  .reviewCorrection(r.id, approve: approve),
                            ))
                        .toList()),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AppErrorState(
              message: friendlyAttendanceError(e),
              padding: const EdgeInsets.symmetric(vertical: 24),
              onRetry: () => ref
                  .read(hrCorrectionsProvider(correctionsFilter).notifier)
                  .refresh(),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnpunchCard extends ConsumerStatefulWidget {
  final UnpunchRowEntity record;
  const _UnpunchCard({required this.record});

  @override
  ConsumerState<_UnpunchCard> createState() => _UnpunchCardState();
}

class _UnpunchCardState extends ConsumerState<_UnpunchCard> {
  bool _reviewing = false;

  Future<void> _review(bool approve) async {
    final correctionId = widget.record.correctionId;
    if (correctionId == null) return;
    setState(() => _reviewing = true);
    final error = await ref
        .read(unpunchesProvider.notifier)
        .reviewCorrection(correctionId, approve: approve);
    if (!mounted) return;
    setState(() => _reviewing = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(approve ? 'Correction approved.' : 'Correction rejected.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _Avatar(name: record.name, initials: record.initials),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(record.name,
                      style: AppTextStyles.label
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text(record.employeeId,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondary)),
                ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(20)),
              child: Text('OUT missing',
                  style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.error, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _KV(k: 'Date', v: record.date)),
            Expanded(
                child: _KV(
                    k: 'Clock In',
                    v: record.clockIn,
                    vColor: AppColors.primary)),
            Expanded(child: _KV(k: 'Expected Out', v: record.expectedOut)),
            Expanded(child: _KV(k: 'Branch', v: record.branch, small: true)),
          ]),
          const SizedBox(height: 10),
          if (record.correctionPending && record.correctionId != null)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reviewing ? null : () => _review(false),
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _reviewing ? null : () => _review(true),
                  icon: _reviewing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 14),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ])
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.backgroundLow,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                'Awaiting employee correction request',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
        ]),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final String? initials;
  const _Avatar({required this.name, this.initials});

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
            (initials?.isNotEmpty ?? false) ? initials! : _initials(name),
            style: AppTextStyles.label.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w700)),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: _statusBg(status), borderRadius: BorderRadius.circular(20)),
        child: Text(status,
            style: AppTextStyles.labelSmall.copyWith(
                color: _statusColor(status), fontWeight: FontWeight.w600)),
      );
}

class _KV extends StatelessWidget {
  final String k;
  final String v;
  final Color? vColor;
  final bool small;
  const _KV(
      {required this.k, required this.v, this.vColor, this.small = false});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textHint, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            v,
            style: AppTextStyles.label.copyWith(
              color: vColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: small ? 11 : 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color, bg;
  const _Chip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _Dropdown(
      {required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final safeItems = items.toSet().toList();
    if (!safeItems.contains(value)) safeItems.insert(0, value);
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        isDense: true,
      ),
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
      isExpanded: true,
      items: safeItems
          .map((s) => DropdownMenuItem(
              value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _FakeInput extends StatelessWidget {
  final String value;
  final IconData icon;
  const _FakeInput({required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Expanded(
              child: Text(value,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textPrimary))),
          Icon(icon, size: 15, color: AppColors.textSecondary),
        ]),
      );
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text,
            style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      );
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color, bg, border;
  final String message;
  const _InfoBanner(
      {required this.icon,
      required this.color,
      required this.bg,
      required this.border,
      required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 15, color: color)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: AppTextStyles.bodySmall.copyWith(color: color))),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(message,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ),
      );
}

// Error states now use the shared AppErrorState widget (lib/shared/widgets/)
// directly at their call sites above.
