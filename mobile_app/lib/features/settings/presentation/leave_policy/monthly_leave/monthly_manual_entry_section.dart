import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../../employees/data/models/employee_model.dart';
import '../../../../employees/presentation/providers/employee_providers.dart';
import '../../../data/models/monthly_leave_models.dart';
import '../../providers/settings_providers.dart';
import 'monthly_leave_providers.dart';
import 'monthly_leave_widgets.dart';

/// Web ManualEntrySection: tick employees from the server-scoped directory
/// (search, 50 per page, "Load more"), choose month, leave type and credit,
/// review with dry_run (nothing saved), then confirm. Inactive employees and
/// the signed-in user can't be ticked. Any change after a review drops it.
class MonthlyManualEntrySection extends ConsumerStatefulWidget {
  const MonthlyManualEntrySection({super.key, required this.active});

  /// Becomes true once the section has been opened (web: load only then).
  final bool active;

  @override
  ConsumerState<MonthlyManualEntrySection> createState() => _MonthlyManualEntrySectionState();
}

class _MonthlyManualEntrySectionState extends ConsumerState<MonthlyManualEntrySection> {
  late final DateTime _today = ref.read(monthlyLeaveClockProvider)();
  late int _month = _today.month;
  late int _year = _today.year;
  final _searchCtrl = TextEditingController();
  final _creditCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';
  int _page = 1;
  int _totalPages = 1;
  List<EmployeeModel> _rows = [];
  bool _listLoading = false;
  String? _listError;
  int _listSeq = 0;
  final _selected = <String, EmployeeModel>{};
  String _leaveType = '';
  MonthlyPlan? _review;
  MonthlyApplyResult? _result;
  String? _busy; // 'review' | 'save'
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(MonthlyManualEntrySection old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _creditCtrl.dispose();
    super.dispose();
  }

  String? get _me => ref.read(authStateProvider).valueOrNull?.user?.employeeId;

  /// Web unselectableReason: 'inactive', 'you', or null.
  String? _reason(EmployeeModel e) {
    if (!e.isActive) return 'inactive';
    final me = _me;
    if (me != null && me.isNotEmpty && e.employeeId == me) return 'you';
    return null;
  }

  Future<void> _load() async {
    final seq = ++_listSeq;
    final page = _page;
    setState(() {
      _listLoading = true;
      _listError = null;
    });
    try {
      final r = await ref.read(employeesDataSourceProvider).fetchEmployeesPage(
          page: page, filters: EmployeeFilters(search: _search), pageSize: kMonthlyEmployeePageSize);
      if (!mounted || seq != _listSeq) return;
      setState(() {
        _rows = page == 1 ? r.items : [..._rows, ...r.items];
        _totalPages = r.totalPages;
      });
    } catch (e) {
      if (!mounted || seq != _listSeq) return;
      setState(() {
        _rows = [];
        _listError = monthlyLeaveError(e, 'Could not load employees.');
      });
    } finally {
      if (mounted && seq == _listSeq) setState(() => _listLoading = false);
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search = v.trim();
      _page = 1;
      _load();
    });
  }

  /// Anything that changes what would be saved drops an earlier review.
  void _edit(VoidCallback change) => setState(() {
        change();
        _review = null;
        _result = null;
      });

  void _toggle(EmployeeModel e, bool check) =>
      _edit(() => check ? _selected[e.employeeId] = e : _selected.remove(e.employeeId));

  void _toggleAll(bool check) => _edit(() {
        for (final e in _rows) {
          if (_reason(e) != null) continue;
          check ? _selected[e.employeeId] = e : _selected.remove(e.employeeId);
        }
      });

  Future<void> _send({required bool dryRun}) async {
    if (_busy != null) return;
    final credit = _creditCtrl.text;
    if (_selected.isEmpty || _leaveType.isEmpty || validateMonthlyCredit(credit) != null) return;
    setState(() {
      _busy = dryRun ? 'review' : 'save';
      _error = null;
    });
    final service = ref.read(monthlyLeaveServiceProvider);
    final ids = _selected.keys.toList();
    try {
      if (dryRun) {
        final p = await service.bulkReview(ids, _leaveType, _year, _month, credit);
        if (mounted) {
          setState(() {
            _review = p;
            _result = null;
          });
        }
      } else {
        final r = await service.bulkApply(ids, _leaveType, _year, _month, credit);
        if (mounted) {
          setState(() {
            _result = r;
            _review = null;
          });
        }
      }
    } on MonthlyLeaveBusy {
      // already running
    } catch (e) {
      if (mounted) {
        setState(() => _error = monthlyLeaveError(
            e, dryRun ? 'Could not prepare the review.' : 'Could not save. Employees that failed were not changed.'));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policiesAsync = ref.watch(leavePoliciesProvider);
    final types = [
      for (final p in policiesAsync.valueOrNull ?? const [])
        if (p.isActive && p.leaveType != 'lwp')
          (
            value: p.leaveType,
            label: p.leaveTypeDisplay.isNotEmpty ? p.leaveTypeDisplay : p.leaveType,
            annual: p.annualDays
          ),
    ];
    final typeInfo = types.where((t) => t.value == _leaveType).firstOrNull;
    final credit = _creditCtrl.text;
    final creditError = credit.isEmpty ? null : validateMonthlyCredit(credit);
    final canReview = _selected.isNotEmpty &&
        _leaveType.isNotEmpty &&
        credit.trim().isNotEmpty &&
        creditError == null &&
        _busy == null;
    final selectable = _rows.where((e) => _reason(e) == null).toList();
    final ticked = selectable.where((e) => _selected.containsKey(e.employeeId)).length;
    final review = _review, result = _result;
    final muted = AppTextStyles.bodySmall.copyWith(fontSize: 12.5, color: AppColors.textSecondary);
    final busy = _busy != null;

    return Column(
      key: const Key('monthly-manual'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Tick one or more employees, choose the month, leave type and credit, then review and confirm. Each "
          "employee's credit is set to this value; only the difference is applied to their balance, and 0 removes it.",
          style: muted,
        ),
        const SizedBox(height: 12),
        MonthYearFields(
          keyPrefix: 'manual-',
          month: _month,
          year: _year,
          years: creditYears(_today),
          disabled: busy,
          onMonth: (m) => _edit(() => _month = m),
          onYear: (y) => _edit(() => _year = y),
        ),
        const SizedBox(height: 12),
        Text('Employees', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          key: const Key('manual-search'),
          controller: _searchCtrl,
          onChanged: _onSearch,
          decoration: const InputDecoration(
            hintText: 'Search by name or employee code…',
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 18),
            border: OutlineInputBorder(),
          ),
        ),
        Row(children: [
          Checkbox(
            key: const Key('manual-select-all'),
            tristate: true,
            value: selectable.isEmpty ? false : (ticked == 0 ? false : (ticked == selectable.length ? true : null)),
            onChanged: selectable.isEmpty || busy ? null : (_) => _toggleAll(ticked != selectable.length),
          ),
          Text('Select all shown (${selectable.length})', style: AppTextStyles.bodySmall),
          const Spacer(),
          Text('${_selected.length} selected', key: const Key('manual-selected-count'), style: muted),
          if (_selected.isNotEmpty)
            IconButton(
              tooltip: 'Clear selection',
              onPressed: busy ? null : () => _edit(_selected.clear),
              icon: const Icon(Icons.clear, size: 18),
            ),
        ]),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration:
              BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
          child: _listError != null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_listError!,
                      key: const Key('manual-list-error'), style: TextStyle(fontSize: 13, color: AppColors.error)))
              : _rows.isEmpty && _listLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        monthlySpinner(),
                        const SizedBox(width: 8),
                        Text('Loading employees…', style: muted)
                      ]))
                  : _rows.isEmpty
                      ? Padding(padding: const EdgeInsets.all(12), child: Text('No employees found.', style: muted))
                      // Own Material so the tiles' ink shows above the card colour.
                      : Material(
                          type: MaterialType.transparency,
                          child: ListView(shrinkWrap: true, children: [
                            for (final e in _rows) _employeeTile(e, busy),
                            if (_page < _totalPages)
                              Center(
                                child: TextButton(
                                  key: const Key('manual-load-more'),
                                  onPressed: _listLoading
                                      ? null
                                      : () {
                                          _page++;
                                          _load();
                                        },
                                  child: Text(_listLoading ? 'Loading…' : 'Load more'),
                                ),
                              ),
                          ])),
        ),
        if (_page < _totalPages)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Select all applies to the employees shown. Load more or search to include others.',
                style: muted.copyWith(fontSize: 12)),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('manual-leave-type'),
          initialValue: _leaveType.isEmpty ? null : _leaveType,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Leave type', isDense: true, border: OutlineInputBorder()),
          hint: Text(policiesAsync.hasValue ? 'Select a leave type…' : 'Loading…'),
          items: [for (final t in types) DropdownMenuItem(value: t.value, child: Text(t.label))],
          onChanged: busy || !policiesAsync.hasValue ? null : (v) => _edit(() => _leaveType = v ?? ''),
        ),
        if (policiesAsync.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Could not load leave types.', style: TextStyle(fontSize: 12, color: AppColors.error)),
          ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('manual-credit'),
          controller: _creditCtrl,
          enabled: !busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _edit(() {}),
          decoration: InputDecoration(
            labelText: 'Monthly leave credit (days)',
            isDense: true,
            border: const OutlineInputBorder(),
            errorText: creditError,
            helperText: creditError == null ? "0–31, one decimal place. 0 removes the month's credit." : null,
          ),
        ),
        if (typeInfo != null && typeInfo.annual > 0) ...[
          const SizedBox(height: 10),
          AnnualWarning(types: ['${typeInfo.label} (${fmtNum(typeInfo.annual)} days/year)']),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          MonthlyAlert(key: const Key('manual-error'), kind: MonthlyAlertKind.error, text: _error!),
        ],
        const SizedBox(height: 12),
        if (review == null)
          FilledButton.icon(
            key: const Key('manual-review'),
            onPressed: canReview ? () => _send(dryRun: true) : null,
            icon: _busy == 'review' ? monthlySpinner() : const Icon(Icons.visibility_outlined, size: 16),
            label: Text(_busy == 'review' ? 'Checking…' : 'Review (${_selected.length})'),
          ),
        if (review != null) ...[
          MonthlyAlert(
            key: const Key('manual-review-summary'),
            kind: review.count('error') > 0 ? MonthlyAlertKind.warn : MonthlyAlertKind.info,
            text: 'Review (nothing saved yet): set ${typeInfo?.label ?? _leaveType} to ${credit.trim()} day(s) for '
                '${kMonthNames[(review.month - 1).clamp(0, 11)]} ${review.year} — ${review.count('new')} new, '
                '${review.count('update')} update, ${review.count('unchanged')} unchanged, ${review.count('error')} '
                'cannot be changed.',
          ),
          const SizedBox(height: 8),
          MonthlyRowsList(rows: review.rows),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: busy ? null : () => setState(() => _review = null), child: const Text('Back')),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const Key('manual-confirm'),
              onPressed: busy || review.applicable == 0 ? null : () => _send(dryRun: false),
              icon: _busy == 'save' ? monthlySpinner() : const Icon(Icons.check, size: 16),
              label: Text(_busy == 'save' ? 'Saving…' : 'Confirm for ${review.applicable} employee(s)'),
            ),
          ]),
        ],
        if (result != null) ...[
          MonthlyAlert(
            key: const Key('manual-result'),
            kind: result.failed > 0 ? MonthlyAlertKind.warn : MonthlyAlertKind.success,
            text: '${kMonthNames[(result.month - 1).clamp(0, 11)]} ${result.year}: ${result.created} added, '
                '${result.updated} updated, ${result.skipped} unchanged or skipped, ${result.failed} failed. '
                'Employees that failed were not changed.',
          ),
          const SizedBox(height: 8),
          MonthlyRowsList(rows: result.rows),
        ],
      ],
    );
  }

  Widget _employeeTile(EmployeeModel e, bool busy) {
    final reason = _reason(e);
    final details = [
      e.employeeId,
      if (e.branch.isNotEmpty) e.branch,
      if (e.department.isNotEmpty) e.department,
      if (reason == 'you') 'you (cannot change your own credits)',
      if (reason == 'inactive') 'inactive',
    ].join(' · ');
    return Opacity(
      opacity: reason != null ? 0.6 : 1,
      child: CheckboxListTile(
        key: Key('manual-employee-${e.employeeId}'),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        value: _selected.containsKey(e.employeeId),
        onChanged: reason != null || busy ? null : (v) => _toggle(e, v ?? false),
        title: Text(e.fullName, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(details, style: AppTextStyles.caption.copyWith(fontSize: 11.5)),
      ),
    );
  }
}
