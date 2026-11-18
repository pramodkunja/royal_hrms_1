import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart' show userFriendlyMessage;
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/attendance_entity.dart' show ExportEmployeeOption;
import '../providers/attendance_export.dart';

// Web AttendanceTab.tsx toolbar: "Export:" Single Day / Month / Custom Date
// Range, a month input (max = this month) or From / To inputs (From ≤ To ≤
// today), the range problem shown in red with the button disabled, and
// "Export CSV" / "Exporting…". On mobile these live in a sheet opened from
// the table's Export button. The table's branch and department filters
// apply to every mode; single day uses the date the table shows.
// "Export employees": All Employees / Single Employee — the latter searches
// GET /employees/ (2+ characters, 300 ms debounce, active only, first 8),
// sends `employee=<ID>` instead of the branch / department filters and saves
// attendance_<ID>_<period>.csv; Export stays disabled until one is picked.

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _monthLabel(int year, int month) => '${_monthNames[month - 1]} $year';
String _dayLabel(DateTime d) => '${d.day} ${_monthNames[d.month - 1].substring(0, 3)} ${d.year}';

/// Opens the export sheet; returns the saved outcome, or null when closed
/// without saving.
Future<AttendanceExportSaved?> showAttendanceExportSheet(
  BuildContext context, {
  required DateTime? tableDate,
  required String branch,
  required String department,
}) {
  return showModalBottomSheet<AttendanceExportSaved>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AttendanceExportSheet(tableDate: tableDate, branch: branch, department: department),
  );
}

class AttendanceExportSheet extends ConsumerStatefulWidget {
  const AttendanceExportSheet({super.key, required this.tableDate, required this.branch, required this.department});

  /// The date the table shows (null = today).
  final DateTime? tableDate;
  final String branch;
  final String department;

  @override
  ConsumerState<AttendanceExportSheet> createState() => _AttendanceExportSheetState();
}

class _AttendanceExportSheetState extends ConsumerState<AttendanceExportSheet> {
  late final DateTime _today = ref.read(attendanceExportClockProvider)();
  AttendanceExportMode _mode = AttendanceExportMode.day;
  late int _year = _today.year;
  late int _month = _today.month;
  late DateTime _from = DateTime(_today.year, _today.month, 1);
  late DateTime _to = DateTime(_today.year, _today.month, _today.day);
  bool _exporting = false;
  String? _error;
  bool _single = false;
  final _empQuery = TextEditingController();
  String _empSearch = '';
  Timer? _debounce;
  ExportEmployeeOption? _employee;

  @override
  void dispose() {
    _debounce?.cancel();
    _empQuery.dispose();
    super.dispose();
  }

  void _onEmpQuery(String v) {
    // Web: typing clears the picked employee; the search follows 300 ms later.
    setState(() {
      _employee = null;
      _error = null;
    });
    _debounce?.cancel();
    _debounce = Timer(kExportEmployeeDebounce, () {
      if (mounted) setState(() => _empSearch = v.trim());
    });
  }

  void _pickEmployee(ExportEmployeeOption e) {
    _debounce?.cancel();
    _empQuery.text = e.label;
    FocusScope.of(context).unfocus();
    setState(() {
      _employee = e;
      _error = null;
    });
  }

  String get _employeeId => _single ? (_employee?.employeeId ?? '') : '';

  AttendanceExportRequest get _request => switch (_mode) {
        AttendanceExportMode.day => AttendanceExportRequest.day(
            date: widget.tableDate, branch: widget.branch, department: widget.department, employeeId: _employeeId),
        AttendanceExportMode.month => AttendanceExportRequest.month(
            year: _year, month: _month, branch: widget.branch, department: widget.department, employeeId: _employeeId),
        AttendanceExportMode.range => AttendanceExportRequest.range(
            from: _from, to: _to, branch: widget.branch, department: widget.department, employeeId: _employeeId),
      };

  Future<void> _export() async {
    if (_exporting) return;
    if (_single && _employee == null) {
      setState(() => _error = kExportSelectEmployee);
      return;
    }
    setState(() {
      _exporting = true;
      _error = null;
    });
    final outcome = await ref.read(attendanceExporterProvider).export(_request);
    if (!mounted) return;
    switch (outcome) {
      case AttendanceExportSaved():
        Navigator.of(context).pop(outcome);
      case AttendanceExportFailed(:final message):
        setState(() {
          _exporting = false;
          _error = message;
        });
      case AttendanceExportCancelled():
      case AttendanceExportIgnored():
        setState(() => _exporting = false);
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDialog<({int year, int month})>(
      context: context,
      builder: (_) => _MonthPickerDialog(year: _year, month: _month, today: _today),
    );
    if (picked != null) {
      setState(() {
        _year = picked.year;
        _month = picked.month;
        _error = null;
      });
    }
  }

  Future<void> _pickFrom() async {
    final last = _to; // web: max = To date (itself ≤ today)
    final picked = await showDatePicker(
      context: context,
      initialDate: _from.isAfter(last) ? last : _from,
      firstDate: DateTime(2000),
      lastDate: last,
      helpText: 'From date',
    );
    if (picked != null) {
      setState(() {
        _from = picked;
        _error = null;
      });
    }
  }

  Future<void> _pickTo() async {
    final last = DateTime(_today.year, _today.month, _today.day);
    final first = _from.isAfter(last) ? last : _from; // web: min = From date
    var initial = _to.isBefore(first) ? first : _to;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'To date',
    );
    if (picked != null) {
      setState(() {
        _to = picked;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final problem = _mode == AttendanceExportMode.day ? null : _request.problem(_today);
    final needsEmployee = _single && _employee == null;
    final filters = [
      'Branch: ${widget.branch.isEmpty ? 'All' : widget.branch}',
      'Department: ${widget.department.isEmpty ? 'All' : widget.department}',
    ].join(' · ');

    return PopScope(
      canPop: !_exporting,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          key: const Key('attendance-export-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.download_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Export Attendance CSV', style: AppTextStyles.h4.copyWith(fontSize: 16)),
            ]),
            const SizedBox(height: 4),
            Text(_single ? 'Branch and department filters do not apply to a single employee.' : filters,
                key: const Key('export-filters'),
                style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            Text('Export', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (mode, label) in const [
                (AttendanceExportMode.day, 'Single Day'),
                (AttendanceExportMode.month, 'Month'),
                (AttendanceExportMode.range, 'Custom Date Range'),
              ])
                ChoiceChip(
                  key: Key('export-mode-${mode.name}'),
                  label: Text(label, style: const TextStyle(fontSize: 12)),
                  selected: _mode == mode,
                  onSelected: _exporting
                      ? null
                      : (_) => setState(() {
                            _mode = mode;
                            _error = null;
                          }),
                ),
            ]),
            const SizedBox(height: 12),
            switch (_mode) {
              AttendanceExportMode.day => _Field(
                  key: const Key('export-day-field'),
                  label: 'Date (as shown in the table)',
                  value: _dayLabel(widget.tableDate ?? _today),
                  icon: Icons.event_outlined,
                ),
              AttendanceExportMode.month => _Field(
                  key: const Key('export-month-field'),
                  label: 'Month',
                  value: _monthLabel(_year, _month),
                  icon: Icons.calendar_month_outlined,
                  onTap: _exporting ? null : _pickMonth,
                ),
              AttendanceExportMode.range => Row(children: [
                  Expanded(
                    child: _Field(
                      key: const Key('export-from-field'),
                      label: 'From',
                      value: _dayLabel(_from),
                      icon: Icons.event_outlined,
                      onTap: _exporting ? null : _pickFrom,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Field(
                      key: const Key('export-to-field'),
                      label: 'To',
                      value: _dayLabel(_to),
                      icon: Icons.event_outlined,
                      onTap: _exporting ? null : _pickTo,
                    ),
                  ),
                ]),
            },
            if (_mode == AttendanceExportMode.range) ...[
              const SizedBox(height: 6),
              Text('Both dates included, up to $kMaxExportRangeDays days. One row per employee per day.',
                  style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary)),
            ],
            if (_mode == AttendanceExportMode.month) ...[
              const SizedBox(height: 6),
              Text('One row per employee per day, up to today for the current month.',
                  style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 12),
            Text('Export employees', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<bool>(
              key: const Key('export-scope'),
              initialValue: _single,
              isExpanded: true,
              decoration: _inputDec(null),
              items: const [
                DropdownMenuItem(value: false, child: Text('All Employees')),
                DropdownMenuItem(value: true, child: Text('Single Employee')),
              ],
              onChanged: _exporting
                  ? null
                  : (v) => setState(() {
                        _single = v ?? false;
                        _error = null;
                      }),
            ),
            if (_single) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('export-employee-search'),
                controller: _empQuery,
                enabled: !_exporting,
                decoration: _inputDec('Search employee by name or ID…')
                    .copyWith(prefixIcon: const Icon(Icons.search, size: 18)),
                onChanged: _onEmpQuery,
              ),
              if (_employee == null && _empSearch.length >= kExportEmployeeMinChars)
                _EmployeeResults(query: _empSearch, onPick: _pickEmployee),
            ],
            if (problem != null) ...[
              const SizedBox(height: 8),
              Text(problem,
                  key: const Key('export-problem'),
                  style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.error)),
            ],
            if (problem == null && needsEmployee && _error == null) ...[
              const SizedBox(height: 8),
              Text(kExportSelectEmployee,
                  key: const Key('export-select-employee'),
                  style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.error)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.error_outline, size: 16, color: AppColors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_error!,
                      key: const Key('export-error'),
                      style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.error)),
                ),
              ]),
            ],
            const SizedBox(height: 16),
            Row(children: [
              TextButton(
                key: const Key('export-cancel'),
                onPressed: _exporting ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const Key('export-submit'),
                onPressed: _exporting || problem != null || needsEmployee ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_outlined, size: 16),
                label: Text(_exporting ? 'Exporting…' : 'Export CSV'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDec(String? hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );

/// Web's search dropdown: "Searching…", the error, "No matching employees.",
/// or up to 8 rows of name + "ID · department".
class _EmployeeResults extends ConsumerWidget {
  const _EmployeeResults({required this.query, required this.onPick});
  final String query;
  final ValueChanged<ExportEmployeeOption> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(attendanceExportEmployeeSearchProvider(query));
    final muted = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary);
    Widget note(String text, Key key, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Text(text, key: key, style: color == null ? muted : muted.copyWith(color: color)),
        );
    return Container(
      key: const Key('export-employee-results'),
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: async.when(
        loading: () => note('Searching…', const Key('export-employee-searching')),
        error: (e, _) => note(userFriendlyMessage(e), const Key('export-employee-error'), color: AppColors.error),
        data: (options) => options.isEmpty
            ? note('No matching employees.', const Key('export-employee-none'))
            // At most 8 rows (web's cap): build them all, scroll if short.
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in options)
                      InkWell(
                        key: Key('export-employee-${e.employeeId}'),
                        onTap: () => onPick(e),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                          child: Text.rich(TextSpan(children: [
                            TextSpan(
                                text: e.fullName,
                                style: AppTextStyles.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                            TextSpan(
                                text: '  ${e.employeeId}${e.department.isNotEmpty ? ' · ${e.department}' : ''}',
                                style: muted.copyWith(fontSize: 11)),
                          ])),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({super.key, required this.label, required this.value, required this.icon, this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
            color: onTap == null ? AppColors.backgroundLow : null,
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(value, style: AppTextStyles.bodySmall.copyWith(fontSize: 13))),
          ]),
        ),
      ),
    ]);
  }
}

/// Year + 12-month grid; months after [today]'s month are disabled (web's
/// month input max) and years start at 2000 (the server's lower bound).
class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.year, required this.month, required this.today});
  final int year;
  final int month;
  final DateTime today;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.year;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('export-month-picker'),
      title: Row(children: [
        IconButton(
          key: const Key('export-month-prev-year'),
          tooltip: 'Previous year',
          onPressed: _year > 2000 ? () => setState(() => _year--) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(child: Text('$_year', textAlign: TextAlign.center, key: const Key('export-month-year'))),
        IconButton(
          key: const Key('export-month-next-year'),
          tooltip: 'Next year',
          onPressed: _year < widget.today.year ? () => setState(() => _year++) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
      content: SizedBox(
        width: 280,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          childAspectRatio: 2.2,
          children: [
            for (var m = 1; m <= 12; m++)
              Builder(builder: (context) {
                final future = _year > widget.today.year || (_year == widget.today.year && m > widget.today.month);
                final selected = _year == widget.year && m == widget.month;
                return TextButton(
                  key: Key('export-month-$m'),
                  onPressed: future ? null : () => Navigator.of(context).pop((year: _year, month: m)),
                  style: selected
                      ? TextButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.12))
                      : null,
                  child: Text(_monthNames[m - 1].substring(0, 3)),
                );
              }),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
    );
  }
}
