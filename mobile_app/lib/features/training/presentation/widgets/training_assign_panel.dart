import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../data/models/training_models.dart';
import '../providers/training_providers.dart';
import 'training_widgets.dart';

/// Web training/_components/AssignPanel.tsx (training.assign): assign a
/// course to selected employees, to departments / branches, or to everyone in
/// the assigner's scope, with an optional due date. Employees who already
/// have the course are skipped by the server.
///
/// Mobile asks for confirmation before EVERY assignment (web asks only for
/// "everyone"): it writes production data and a mis-tap on a phone is easy.
class TrainingAssignPanel extends ConsumerStatefulWidget {
  const TrainingAssignPanel({super.key, required this.course, required this.onAssigned});
  final TrainingCourse course;

  /// Called after a successful assignment (the screen opens Progress).
  final VoidCallback onAssigned;

  @override
  ConsumerState<TrainingAssignPanel> createState() => _TrainingAssignPanelState();
}

class _TrainingAssignPanelState extends ConsumerState<TrainingAssignPanel> with AutomaticKeepAliveClientMixin {
  AssignMode _mode = AssignMode.people;
  final _searchCtrl = TextEditingController();
  String _search = '';
  Timer? _debounce;
  final Map<String, TrainingPerson> _picked = {};
  final Set<String> _departments = {};
  final Set<String> _branches = {};
  late String _due = _defaultDue();
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  /// Web defaults to the course deadline; a past date would be refused by
  /// the server ("The due date is in the past."), so it is left blank then.
  String _defaultDue() {
    final d = widget.course.deadline;
    if (d == null) return '';
    final parsed = DateTime.tryParse(d);
    final today = DateUtils.dateOnly(DateTime.now());
    return parsed == null || parsed.isBefore(today) ? '' : d;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _search = v.trim());
    });
  }

  AssignRequest get _request => AssignRequest(
        mode: _mode,
        employeeIds: _picked.keys.toList(),
        departments: _departments.toList()..sort(),
        branches: _branches.toList()..sort(),
        dueDate: _due.isEmpty ? null : _due,
      );

  String get _summary {
    String plural(int n, String w, [String? p]) => '$n ${n == 1 ? w : (p ?? '${w}s')}';
    switch (_mode) {
      case AssignMode.all:
        return 'Every eligible employee in your scope';
      case AssignMode.people:
        return _picked.isEmpty ? 'No employees selected' : '${plural(_picked.length, 'employee')} selected';
      case AssignMode.groups:
        final parts = [
          if (_departments.isNotEmpty) plural(_departments.length, 'department'),
          if (_branches.isNotEmpty) plural(_branches.length, 'branch', 'branches'),
        ];
        return parts.isEmpty ? 'No departments or branches selected' : parts.join(' · ');
    }
  }

  Future<void> _pickDue() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final current = DateTime.tryParse(_due);
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(today) ? current : today,
      firstDate: today, // the server refuses past due dates
      lastDate: DateTime(today.year + 5),
    );
    if (picked != null && mounted) setState(() => _due = trainingIsoDate(picked));
  }

  Future<void> _assign() async {
    final req = _request;
    if (!req.isReady || _busy || !widget.course.isActive) return;
    final who = _mode == AssignMode.all ? 'every eligible employee you manage' : _summary.toLowerCase();
    final ok = await confirmTrainingAction(
      context,
      title: 'Assign course?',
      message: 'Assign "${widget.course.title}" to $who'
          '${_due.isEmpty ? '' : ', due $_due'}? Employees who already have it are skipped.',
      confirmLabel: 'Assign',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final msg = await ref.read(trainingAdminActionsProvider).assign(widget.course, req);
      if (!mounted) return;
      setState(() {
        _picked.clear();
        _departments.clear();
        _branches.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      ref.invalidate(trainingProgressProvider(widget.course.id));
      ref.invalidate(trainingCoursesProvider);
      ref.invalidate(trainingDashboardProvider);
      widget.onAssigned();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(userFriendlyMessage(e)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pickerAsync = ref.watch(trainingPickerProvider(_search));
    final ready = _request.isReady && widget.course.isActive;

    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const Key('training-assign'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              if (!widget.course.isActive)
                TrainingBanner(
                  key: const Key('training-assign-inactive'),
                  text: 'Activate the course (on the web app) before assigning it.',
                  icon: Icons.info_outline,
                  color: AppColors.warning,
                  background: AppColors.warningContainer,
                ),
              const TrainingSectionHeader(Icons.person_add_alt_outlined, 'Assign this course',
                  subtitle: 'Employees who already have this course are skipped automatically.'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (m, label) in const [
                    (AssignMode.people, 'Selected employees'),
                    (AssignMode.groups, 'Departments / branches'),
                    (AssignMode.all, 'All eligible employees'),
                  ])
                    ChoiceChip(
                      key: Key('training-assign-mode-${m.name}'),
                      label: Text(label),
                      labelStyle: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600, color: _mode == m ? AppColors.primary : AppColors.textSecondary),
                      selectedColor: AppColors.primary.withValues(alpha: 0.12),
                      backgroundColor: AppColors.surface,
                      checkmarkColor: AppColors.primary,
                      side: BorderSide(color: _mode == m ? AppColors.primary : AppColors.border),
                      selected: _mode == m,
                      onSelected: (_) => setState(() => _mode = m),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              ...switch (_mode) {
                AssignMode.people => _people(pickerAsync),
                AssignMode.groups => _groups(pickerAsync),
                AssignMode.all => [
                    TrainingBanner(
                      text: 'The course will be assigned to every active employee you manage who doesn\'t already '
                          'have it. New joiners are covered by the "Assign automatically to new joiners" '
                          'course option.',
                      icon: Icons.groups_outlined,
                      color: AppColors.info,
                      background: AppColors.infoContainer,
                    ),
                  ],
              },
            ],
          ),
        ),
        // Footer: selection summary, due date, Assign.
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_summary,
                    key: const Key('training-assign-summary'),
                    style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                LayoutBuilder(builder: (context, c) {
                  final dueLabel = _due.isEmpty ? 'Due date (optional)' : 'Due $_due';
                  final due = OutlinedButton.icon(
                    key: const Key('training-assign-due'),
                    onPressed: _pickDue,
                    style: trainingOutlinedStyle(),
                    icon: const Icon(Icons.event_outlined, size: 16),
                    label: Text(dueLabel, overflow: TextOverflow.ellipsis),
                  );
                  final clear = _due.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear due date',
                          onPressed: () => setState(() => _due = ''),
                          icon: const Icon(Icons.close),
                        );
                  final assign = FilledButton.icon(
                    key: const Key('training-assign-submit'),
                    onPressed: ready && !_busy ? _assign : null,
                    style: trainingFilledStyle(),
                    icon: _busy
                        ? const SizedBox(
                            width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_outlined, size: 16),
                    label: Text(_busy ? 'Assigning…' : 'Assign'),
                  );
                  final oneLine = trainingActionsFit(context, c.maxWidth, [dueLabel, 'Assigning…'], extra: clear == null ? 0 : 48);
                  if (oneLine) {
                    return Row(children: [
                      Expanded(child: due),
                      if (clear != null) clear,
                      const SizedBox(width: 8),
                      assign,
                    ]);
                  }
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [Expanded(child: due), if (clear != null) clear]),
                    const SizedBox(height: 8),
                    assign,
                  ]);
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _people(AsyncValue<TrainingPicker> pickerAsync) {
    final employees = pickerAsync.valueOrNull?.employees ?? const <TrainingPerson>[];
    final allShown = employees.isNotEmpty && employees.every((e) => _picked.containsKey(e.id));
    return [
      TextField(
        key: const Key('training-assign-search'),
        controller: _searchCtrl,
        onChanged: _onSearch,
        decoration: trainingInput('Search by name or employee ID', prefix: const Icon(Icons.search))
            .copyWith(labelText: null, hintText: 'Search by name or employee ID'),
      ),
      const SizedBox(height: 8),
      if (_picked.isNotEmpty)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in _picked.values)
              InputChip(
                label: Text(p.name),
                onDeleted: () => setState(() => _picked.remove(p.id)),
                deleteButtonTooltipMessage: 'Remove ${p.name}',
              ),
            TextButton(style: trainingTextStyle(), onPressed: () => setState(_picked.clear), child: const Text('Clear selection')),
          ],
        ),
      if (pickerAsync.hasError && employees.isEmpty)
        TrainingStateView.error(pickerAsync.error!, what: 'employees', onRetry: () => ref.invalidate(trainingPickerProvider(_search)))
      else if (pickerAsync.isLoading && employees.isEmpty)
        const ApprovalsLoading(label: 'Loading employees…')
      else if (employees.isEmpty)
        TrainingStateView.noMatch(
          key: const Key('training-assign-no-match'),
          title: 'No employees match your search.',
          message: 'Check the spelling or try the employee ID.',
          onClear: () {
            _searchCtrl.clear();
            setState(() => _search = '');
          },
        )
      else ...[
        CheckboxListTile(
          key: const Key('training-assign-select-all'),
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
          controlAffinity: ListTileControlAffinity.leading,
          value: allShown,
          onChanged: (on) => setState(() {
            for (final e in employees) {
              on == true ? _picked[e.id] = e : _picked.remove(e.id);
            }
          }),
          title: Text('Select all shown (${employees.length})', style: const TextStyle(fontSize: 13)),
        ),
        for (final e in employees)
          CheckboxListTile(
            key: Key('training-assign-emp-${e.id}'),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            value: _picked.containsKey(e.id),
            onChanged: (on) => setState(() => on == true ? _picked[e.id] = e : _picked.remove(e.id)),
            title: Text(e.name, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
            subtitle: e.subtitle.isEmpty ? null : Text(e.subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ),
      ],
    ];
  }

  List<Widget> _groups(AsyncValue<TrainingPicker> pickerAsync) {
    final p = pickerAsync.valueOrNull;
    if (p == null) {
      return [
        if (pickerAsync.hasError)
          TrainingStateView.error(pickerAsync.error!, what: 'employees', onRetry: () => ref.invalidate(trainingPickerProvider(_search)))
        else
          const ApprovalsLoading(label: 'Loading…'),
      ];
    }
    Widget group(String label, List<String> options, Set<String> chosen, String keyPrefix) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            if (options.isEmpty)
              Text('None available in your scope.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in options)
                    FilterChip(
                      key: Key('$keyPrefix-$o'),
                      label: Text(o),
                      selectedColor: AppColors.primary.withValues(alpha: 0.12),
                      checkmarkColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      side: BorderSide(color: chosen.contains(o) ? AppColors.primary : AppColors.border),
                      selected: chosen.contains(o),
                      onSelected: (on) => setState(() => on ? chosen.add(o) : chosen.remove(o)),
                    ),
                ],
              ),
            const SizedBox(height: 16),
          ],
        );
    return [
      group('Departments', p.departments, _departments, 'training-assign-dept'),
      group('Branches', p.branches, _branches, 'training-assign-branch'),
    ];
  }
}
