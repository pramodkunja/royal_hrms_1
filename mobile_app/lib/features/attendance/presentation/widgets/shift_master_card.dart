import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart' show attendanceSettingsProvider;
import '../../data/models/shift_master_models.dart';
import '../providers/shift_master_providers.dart';
import 'assignment_form_widgets.dart';
import 'shift_card.dart';
import 'shift_format.dart';

/// SHIFT CONFIGURATION (web ShiftMasterCard "Shifts"), shown to users who may
/// assign (attendance.create): the active shifts five per page, the read-only
/// global default, "Add Shift", Edit (attendance.edit) and Deactivate
/// (attendance.delete; not for the default). Assigning shifts to employees is
/// the separate section below it.
class ShiftMasterCard extends ConsumerWidget {
  const ShiftMasterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final canEdit = canEditShiftMasters(user);
    final canDelete = canDeleteShiftMasters(user);
    final pageAsync = ref.watch(shiftMastersProvider);
    final pageNo = ref.watch(shiftMasterPageNumberProvider);
    // Read-only; hidden when it can't be loaded (web: settings.view only).
    final global = ref.watch(attendanceSettingsProvider).valueOrNull?.workingHours;
    final muted = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary);

    void showMessage(String? message) {
      if (message != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success));
      }
    }

    Future<void> openForm([ShiftMaster? shift]) async {
      final message = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        useSafeArea: true,
        builder: (_) => ShiftMasterFormSheet(shift: shift),
      );
      showMessage(message);
    }

    Future<void> confirmDeactivate(ShiftMaster shift, int shownOnPage) async {
      final message = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DeactivateShiftDialog(shift: shift),
      );
      if (message == null) return;
      // Web: the last shift on a later page moves back a page.
      if (shownOnPage == 1 && pageNo > 1) ref.read(shiftMasterPageNumberProvider.notifier).state = pageNo - 1;
      showMessage(message);
    }

    return Container(
      key: const Key('shift-master-card'),
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ShiftSectionHeader(
          icon: Icons.schedule_outlined,
          title: 'Shift configuration',
          subtitle: 'Create the named shifts — timings, break and grace period. '
              'Assign them to employees in the section below.',
          trailing: FilledButton.icon(
            key: const Key('shift-master-add'),
            onPressed: () => openForm(),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Shift'),
          ),
        ),
        const SizedBox(height: 6),
        Text('Employees with no shift assigned keep using the global default.', style: muted),
        if (global != null) ...[
          const SizedBox(height: 10),
          Container(
            key: const Key('shift-master-global'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('General / Default — ${toHHMM(global.shiftStart)} to ${toHHMM(global.shiftEnd)}',
                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('Applies to every employee with no shift assigned below · edit under Settings → Attendance Rules',
                  style: muted.copyWith(fontSize: 11.5)),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        pageAsync.when(
          loading: () => const ApprovalsLoading(key: Key('shift-master-loading'), label: 'Loading shifts…'),
          error: (e, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ApprovalsEmptyState.forError(e, key: const Key('shift-master-error'), compact: true, what: 'shifts'),
            Center(
              child: OutlinedButton.icon(
                key: const Key('shift-master-retry'),
                onPressed: () => ref.invalidate(shiftMastersProvider),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ),
          ]),
          data: (page) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (page.shifts.isEmpty)
              const ApprovalsEmptyState(
                key: Key('shift-master-empty'),
                kind: ApprovalsStateKind.empty,
                title: 'No named shifts created yet.',
                message: 'Add a shift to give employees timings other than the global default.',
                icon: Icons.schedule_outlined,
                compact: true,
              ),
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 600 ? 2 : 1;
              final w = cols == 1 ? c.maxWidth : (c.maxWidth - 12) / 2;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                for (final s in page.shifts)
                  SizedBox(
                    width: w,
                    child: ShiftMasterTile(
                      shift: s,
                      canEdit: canEdit,
                      canDelete: canDelete,
                      onEdit: () => openForm(s),
                      onDeactivate: () => confirmDeactivate(s, page.shifts.length),
                    ),
                  ),
              ]);
            }),
            if (page.totalPages > 1)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  key: const Key('shift-master-prev'),
                  tooltip: 'Previous page',
                  onPressed:
                      pageNo <= 1 ? null : () => ref.read(shiftMasterPageNumberProvider.notifier).state = pageNo - 1,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${page.page} / ${page.totalPages}', key: const Key('shift-master-page'), style: muted),
                IconButton(
                  key: const Key('shift-master-next'),
                  tooltip: 'Next page',
                  onPressed: pageNo >= page.totalPages
                      ? null
                      : () => ref.read(shiftMasterPageNumberProvider.notifier).state = pageNo + 1,
                  icon: const Icon(Icons.chevron_right),
                ),
              ]),
          ]),
        ),
      ]),
    );
  }
}

/// Web Add/Edit Shift modal, grouped: Shift details, Timings (live length and
/// overnight indicator), Break and grace, Organization default. Pops with the
/// server's message once saved; a failure keeps every value. Rules the backend
/// enforces (start != end, net hours above zero, break <= 480, grace <= 120,
/// name <= 100) are shown inline and stop the request; the payload is unchanged.
class ShiftMasterFormSheet extends ConsumerStatefulWidget {
  const ShiftMasterFormSheet({super.key, this.shift});
  final ShiftMaster? shift;

  @override
  ConsumerState<ShiftMasterFormSheet> createState() => _ShiftMasterFormSheetState();
}

class _ShiftMasterFormSheetState extends ConsumerState<ShiftMasterFormSheet> {
  late final ShiftMasterForm _form =
      widget.shift == null ? ShiftMasterForm() : ShiftMasterForm.fromShift(widget.shift!);
  late final _name = TextEditingController(text: _form.name);
  late final _break = TextEditingController(text: '${_form.breakDuration}');
  late final _grace = TextEditingController(text: '${_form.gracePeriod}');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _break.dispose();
    _grace.dispose();
    super.dispose();
  }

  /// Web Number(value): empty is 0.
  int _num(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  /// Inline messages for the backend's own rules (same wording).
  String? get _timeError {
    if (_form.startTime.isNotEmpty && _form.startTime == _form.endTime) {
      return 'Start time and end time cannot be the same.';
    }
    return null;
  }

  String? get _breakError {
    final b = _num(_break);
    if (b > 480) return 'Break duration cannot exceed 480 minutes (8 hours).';
    final net = shiftNetMinutes(_form.startTime, _form.endTime, b);
    if (_timeError == null && net == 0) {
      return 'Net working hours (shift duration minus break) must be greater than zero. '
          'Reduce break duration or widen the shift window.';
    }
    return null;
  }

  String? get _graceError => _num(_grace) > 120 ? 'Grace period cannot exceed 120 minutes (2 hours).' : null;

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _form.startTime.isNotEmpty &&
      _form.endTime.isNotEmpty &&
      _timeError == null &&
      _breakError == null &&
      _graceError == null;

  Future<void> _pickTime(bool start) async {
    final current = start ? _form.startTime : _form.endTime;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(parts.first) ?? 9, minute: int.tryParse(parts.last) ?? 0),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return;
    final hhmm = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() => start ? _form.startTime = hhmm : _form.endTime = hhmm);
  }

  Future<void> _save() async {
    if (_saving) return;
    _form
      ..name = _name.text
      ..breakDuration = _num(_break)
      ..gracePeriod = _num(_grace);
    if (!_form.canSave || !_valid) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final service = ref.read(shiftMasterServiceProvider);
    try {
      final message =
          widget.shift == null ? await service.create(_form) : await service.update(widget.shift!.id, _form);
      if (mounted) Navigator.of(context).pop(message);
    } on ShiftMasterBusy {
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = shiftMasterError(e, 'Failed to save shift.');
        });
      }
    }
  }

  Widget _group(String title, String? hint, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: AppTextStyles.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint, style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  Widget _timeField(String key, String label, String value, bool start) => InkWell(
        key: Key(key),
        onTap: _saving ? null : () => _pickTime(start),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.access_time, size: 18),
            errorText: !start && _timeError != null ? ' ' : null,
            errorStyle: const TextStyle(fontSize: 0, height: 0),
          ),
          child: Text(value, style: AppTextStyles.body),
        ),
      );

  Widget _minutes(String key, String label, TextEditingController c, String? error, String helper) => TextField(
        key: Key(key),
        controller: c,
        enabled: !_saving,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 5,
          errorText: error,
          errorMaxLines: 4,
          border: const OutlineInputBorder(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final len = shiftLengthMinutes(_form.startTime, _form.endTime);
    final net = shiftNetMinutes(_form.startTime, _form.endTime, _num(_break));
    final overnight = isOvernightShift(_form.startTime, _form.endTime);
    final editing = widget.shift != null;
    final timeFields = LayoutBuilder(builder: (context, c) {
      final stack = c.maxWidth < 300 || scale > 1.3;
      final start = _timeField('shift-master-start', 'Start Time', _form.startTime, true);
      final end = _timeField('shift-master-end', 'End Time', _form.endTime, false);
      if (stack) return Column(children: [start, const SizedBox(height: 12), end]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: start),
        const SizedBox(width: 12),
        Expanded(child: end),
      ]);
    });
    final minuteFields = LayoutBuilder(builder: (context, c) {
      final stack = c.maxWidth < 360 || scale > 1.3;
      final brk = _minutes('shift-master-break', 'Break Duration (min)', _break, _breakError,
          'Deducted from the shift’s working hours.');
      final grace = _minutes('shift-master-grace', 'Grace Period (min)', _grace, _graceError,
          'Late-arrival allowance before a punch is marked late.');
      if (stack) return Column(children: [brk, const SizedBox(height: 12), grace]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: brk),
        const SizedBox(width: 12),
        Expanded(child: grace),
      ]);
    });
    return PopScope(
      canPop: !_saving,
      child: Padding(
        key: const Key('shift-master-form'),
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(editing ? 'Edit Shift' : 'Add Shift', style: AppTextStyles.h4.copyWith(fontSize: 17)),
                  const SizedBox(height: 2),
                  Text(
                    editing
                        ? 'Changes apply to employees already assigned this shift.'
                        : 'A shift is a named set of timings you can assign to employees.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ]),
                const SizedBox(height: 14),
                if (_error != null) AssignmentErrorBox(key: const Key('shift-master-form-error'), text: _error!),
                _group('Shift details', null, [
                  TextField(
                    key: const Key('shift-master-name'),
                    controller: _name,
                    enabled: !_saving,
                    maxLength: 100,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Shift Name *',
                      hintText: 'e.g. SGT/ICT Shift, UK Shift',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ]),
                _group(
                    'Shift timings',
                    'Pick the start and end time. An end time before the start time means the shift ends the next day.',
                    [
                      timeFields,
                      if (_timeError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_timeError!,
                              key: const Key('shift-master-time-error'),
                              style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.error)),
                        ),
                      if (len != null && _timeError == null) ...[
                        const SizedBox(height: 10),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          ApprovalsChip('Shift length ${formatShiftDuration(len)}',
                              key: const Key('shift-master-length'), icon: Icons.timelapse_outlined),
                          if (net != null)
                            ApprovalsChip('Working time ${formatShiftDuration(net)}',
                                key: const Key('shift-master-net'), tone: ApprovalsTone.success),
                          if (overnight)
                            const ApprovalsChip('Overnight · ends next day',
                                key: Key('shift-master-overnight'),
                                icon: Icons.nights_stay_outlined,
                                tone: ApprovalsTone.warning),
                        ]),
                      ],
                    ]),
                _group('Break and grace period', null, [minuteFields]),
                _group('Organization default', null, [
                  CheckboxListTile(
                    key: const Key('shift-master-default'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _form.isDefault,
                    onChanged: _saving ? null : (v) => setState(() => _form.isDefault = v ?? false),
                    title: Text('Make this the organization default shift',
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 13)),
                  ),
                ]),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('shift-master-save'),
                onPressed: !_saving && _valid ? _save : null,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                child: Text(_saving ? 'Saving…' : 'Save Shift'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Web "Deactivate Shift" confirmation. A refusal stays in the dialog;
/// success pops with the server's message.
class DeactivateShiftDialog extends ConsumerStatefulWidget {
  const DeactivateShiftDialog({super.key, required this.shift});
  final ShiftMaster shift;

  @override
  ConsumerState<DeactivateShiftDialog> createState() => _DeactivateShiftDialogState();
}

class _DeactivateShiftDialogState extends ConsumerState<DeactivateShiftDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _deactivate() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final message = await ref.read(shiftMasterServiceProvider).deactivate(widget.shift.id);
      if (mounted) Navigator.of(context).pop(message);
    } on ShiftMasterBusy {
      if (mounted) setState(() => _deleting = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = shiftMasterError(e, 'Delete failed.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        key: const Key('shift-master-deactivate'),
        title: Text('Deactivate Shift', style: TextStyle(color: AppColors.error)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_error != null) AssignmentErrorBox(key: const Key('shift-master-deactivate-error'), text: _error!),
          Text(
            '"${widget.shift.name}" will be deactivated. Employees currently assigned this shift keep it until '
            'reassigned — history is preserved.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ]),
        actions: [
          TextButton(onPressed: _deleting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            key: const Key('shift-master-deactivate-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: _deleting ? null : _deactivate,
            child: Text(_deleting ? 'Deactivating…' : 'Deactivate'),
          ),
        ],
      ),
    );
  }
}
