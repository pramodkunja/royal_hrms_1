import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart' show attendanceSettingsProvider;
import '../../data/models/shift_master_models.dart';
import '../providers/shift_master_providers.dart';
import 'assignment_form_widgets.dart';

/// Web ShiftMasterCard ("Shifts") at the top of the Shift Assignment tab
/// (shown to users who may assign, attendance.create): the active shifts five
/// per page, the read-only global default, "Add Shift", Edit
/// (attendance.edit) and Deactivate (attendance.delete; not for the default).
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.schedule_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text('Shifts', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700))),
          FilledButton.icon(
            key: const Key('shift-master-add'),
            onPressed: () => openForm(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Shift'),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          'Configure named shift timings and assign them to employees from Attendance & Time → Shift Assignment. '
          'Employees with no shift assigned keep using the global default below.',
          style: muted,
        ),
        if (global != null) ...[
          const SizedBox(height: 10),
          Container(
            key: const Key('shift-master-global'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.backgroundLow, borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('General / Default — ${toHHMM(global.shiftStart)} to ${toHHMM(global.shiftEnd)}',
                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              Text('Applies to every employee with no shift assigned below · edit under Settings → Attendance Rules',
                  style: muted.copyWith(fontSize: 11.5)),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        pageAsync.when(
          loading: () => Text('Loading…', key: const Key('shift-master-loading'), style: muted),
          error: (e, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AssignmentErrorBox(
                key: const Key('shift-master-error'), text: shiftMasterError(e, 'Failed to load shifts.')),
            TextButton(
              key: const Key('shift-master-retry'),
              onPressed: () => ref.invalidate(shiftMastersProvider),
              child: const Text('Retry'),
            ),
          ]),
          data: (page) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (page.shifts.isEmpty)
              Text('No named shifts created yet.', key: const Key('shift-master-empty'), style: muted),
            for (final s in page.shifts)
              _ShiftRow(
                shift: s,
                canEdit: canEdit,
                canDelete: canDelete,
                onEdit: () => openForm(s),
                onDeactivate: () => confirmDeactivate(s, page.shifts.length),
              ),
            if (page.totalPages > 1)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  key: const Key('shift-master-prev'),
                  onPressed:
                      pageNo <= 1 ? null : () => ref.read(shiftMasterPageNumberProvider.notifier).state = pageNo - 1,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${page.page} / ${page.totalPages}', key: const Key('shift-master-page'), style: muted),
                IconButton(
                  key: const Key('shift-master-next'),
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

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({
    required this.shift,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDeactivate,
  });

  final ShiftMaster shift;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final s = shift;
    final muted = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary);
    return Container(
      key: Key('shift-master-${s.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(s.name, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              if (s.isDefault)
                Container(
                  key: Key('shift-master-default-${s.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                  child: Text('Default', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                ),
            ]),
            Text('${toHHMM(s.startTime)} – ${toHHMM(s.endTime)}', style: muted),
            Text('Break ${s.breakDuration} min · Grace Period ${s.gracePeriod} min', style: muted),
          ]),
        ),
        if (canEdit)
          IconButton(
            key: Key('shift-master-edit-${s.id}'),
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
        if (canDelete)
          IconButton(
            key: Key('shift-master-delete-${s.id}'),
            tooltip: s.isDefault ? 'Assign another shift as default before removing this one.' : 'Deactivate',
            onPressed: s.isDefault ? null : onDeactivate,
            color: AppColors.error,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
      ]),
    );
  }
}

/// Web Add/Edit Shift modal: Shift Name, Start/End Time, Break and Grace
/// Period (minutes), "Make this the organization default shift". Pops with
/// the server's message once saved; a failure keeps every value.
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
    if (!_form.canSave) return;
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

  Widget _time(String key, String label, String value, bool start) => Expanded(
        child: InkWell(
          key: Key(key),
          onTap: _saving ? null : () => _pickTime(start),
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
            child: Text(value),
          ),
        ),
      );

  Widget _minutes(String key, String label, TextEditingController c) => Expanded(
        child: TextField(
          key: Key(key),
          controller: c,
          enabled: !_saving,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final canSave = !_saving && _name.text.isNotEmpty && _form.startTime.isNotEmpty && _form.endTime.isNotEmpty;
    return AssignmentSheet(
      key: const Key('shift-master-form'),
      title: widget.shift == null ? 'Add Shift' : 'Edit Shift',
      saving: _saving,
      content: [
        if (_error != null) AssignmentErrorBox(key: const Key('shift-master-form-error'), text: _error!),
        TextField(
          key: const Key('shift-master-name'),
          controller: _name,
          enabled: !_saving,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Shift Name *',
            hintText: 'e.g. SGT/ICT Shift, UK Shift',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _time('shift-master-start', 'Start Time', _form.startTime, true),
          const SizedBox(width: 10),
          _time('shift-master-end', 'End Time', _form.endTime, false),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _minutes('shift-master-break', 'Break Duration (min)', _break),
          const SizedBox(width: 10),
          _minutes('shift-master-grace', 'Grace Period (min)', _grace),
        ]),
        const SizedBox(height: 4),
        CheckboxListTile(
          key: const Key('shift-master-default'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: _form.isDefault,
          onChanged: _saving ? null : (v) => setState(() => _form.isDefault = v ?? false),
          title: const Text('Make this the organization default shift', style: TextStyle(fontSize: 13)),
        ),
      ],
      action: FilledButton(
        key: const Key('shift-master-save'),
        onPressed: canSave ? _save : null,
        child: Text(_saving ? 'Saving…' : 'Save Shift'),
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
