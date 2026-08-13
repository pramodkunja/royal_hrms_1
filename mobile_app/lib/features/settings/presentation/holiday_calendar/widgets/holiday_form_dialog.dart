import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../branches/domain/entities/branch_entity.dart';
import '../../../../branches/presentation/providers/branch_providers.dart';
import '../../../data/models/holiday_model.dart';
import '../holiday_calendar_providers.dart';
import '../holiday_styles.dart';

const _kCompanyWideLabel = 'All Branches (Company-wide)';

class HolidayFormDialog extends ConsumerStatefulWidget {
  final HolidayModel? holiday;
  final HolidaysKey holidaysKey;

  const HolidayFormDialog({super.key, this.holiday, required this.holidaysKey});

  @override
  ConsumerState<HolidayFormDialog> createState() => _HolidayFormDialogState();
}

class _HolidayFormDialogState extends ConsumerState<HolidayFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late String _type;
  DateTime? _date;
  late bool _isOptional;
  late bool _isActive;
  int? _branchId; // null = company-wide
  bool _saving = false;
  String? _nameError;
  String? _dateError;
  String? _submitError;

  bool get _isAdd => widget.holiday == null;

  @override
  void initState() {
    super.initState();
    final h = widget.holiday;
    _nameCtrl = TextEditingController(text: h?.name ?? '');
    _descriptionCtrl = TextEditingController(text: h?.description ?? '');
    _type = h?.type ?? HolidayType.national;
    _date = h?.date;
    _isOptional = h?.isOptional ?? false;
    _isActive = h?.isActive ?? true;
    _branchId = h?.branchId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateError = null;
      });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchListProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DlgHeader(
            icon: Icons.calendar_month_outlined,
            title: _isAdd ? 'Add Holiday' : 'Edit: ${widget.holiday!.name}',
            subtitle: 'National, regional or company holiday',
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  TextFormField(
                    controller: _nameCtrl,
                    style: AppTextStyles.body,
                    autofocus: true,
                    maxLength: 80,
                    onChanged: (v) {
                      final cleaned = HolidayFormData.sanitizeName(v);
                      if (cleaned != v) {
                        _nameCtrl.value = _nameCtrl.value.copyWith(
                          text: cleaned,
                          selection: TextSelection.collapsed(offset: cleaned.length),
                        );
                      }
                      setState(() => _nameError = null);
                    },
                    decoration: _dec('Holiday Name *', _nameError).copyWith(
                      hintText: 'e.g. Independence Day',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: _dec('Date *', _dateError).copyWith(
                              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                            ),
                            child: Text(
                              _date == null ? 'Select date' : _fmtDate(_date!),
                              style: AppTextStyles.body.copyWith(
                                color: _date == null ? AppColors.textHint : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _type,
                          decoration: _dec('Type'),
                          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                          items: HolidayType.all
                              .map((t) => DropdownMenuItem(value: t, child: Text(HolidayType.label(t))))
                              .toList(),
                          onChanged: (v) => setState(() => _type = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  branchesAsync.when(
                    loading: () => InputDecorator(
                      decoration: _dec('Applicable Branch'),
                      child: Text('Loading branches…', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
                    ),
                    error: (_, __) => InputDecorator(
                      decoration: _dec('Applicable Branch'),
                      child: Text('Company-wide (branch list unavailable)',
                          style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
                    ),
                    data: (branches) => _BranchDropdown(
                      branches: branches,
                      selectedId: _branchId,
                      onChanged: (id) => setState(() => _branchId = id),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    style: AppTextStyles.body,
                    maxLines: 2,
                    decoration: _dec('Description (optional)').copyWith(
                      hintText: 'Any notes about this holiday',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ToggleTile(
                    icon: Icons.event_available_outlined,
                    label: 'Optional holiday',
                    sublabel: _isOptional
                        ? 'Employees may choose to take this off'
                        : 'Mandatory for all applicable employees',
                    value: _isOptional,
                    color: HolidayStyles.optional,
                    onChanged: (v) => setState(() => _isOptional = v),
                  ),
                  const SizedBox(height: 10),
                  _ToggleTile(
                    icon: Icons.check_circle_outline,
                    label: 'Active',
                    sublabel: _isActive
                        ? 'Visible on the calendar and applied'
                        : 'Hidden from the calendar',
                    value: _isActive,
                    color: AppColors.success,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  if (_submitError != null) ...[
                    const SizedBox(height: 12),
                    Text(_submitError!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_isAdd ? 'Add Holiday' : 'Save Changes',
                            style: AppTextStyles.label.copyWith(color: Colors.white)),
                  ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, [String? error]) => InputDecoration(
    labelText: label,
    errorText: error,
    labelStyle: AppTextStyles.caption,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  Future<void> _submit() async {
    final form = HolidayFormData(
      name: _nameCtrl.text,
      date: _date,
      type: _type,
      isOptional: _isOptional,
      description: _descriptionCtrl.text,
      branchId: _branchId,
      isActive: _isActive,
    );
    final errors = form.validate();
    if (errors.isNotEmpty) {
      setState(() {
        _nameError = errors['name'];
        _dateError = errors['date'];
      });
      return;
    }
    setState(() { _saving = true; _submitError = null; });
    final notifier = ref.read(holidaysProvider(widget.holidaysKey).notifier);
    final error = _isAdd ? await notifier.add(form) : await notifier.edit(widget.holiday!.id, form);
    if (!mounted) return;
    if (error != null) {
      setState(() { _saving = false; _submitError = error; });
      return;
    }
    Navigator.pop(context);
  }
}

// ── Branch dropdown (real branches + Company-wide option) ───────────────────

class _BranchDropdown extends StatelessWidget {
  final List<BranchEntity> branches;
  final int? selectedId;
  final ValueChanged<int?> onChanged;
  const _BranchDropdown({required this.branches, required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final validIds = branches.map((b) => b.id).toSet();
    final value = selectedId != null && !validIds.contains(selectedId) ? null : selectedId;
    return DropdownButtonFormField<int?>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: 'Applicable Branch',
        labelStyle: AppTextStyles.caption,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
      isExpanded: true,
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text(_kCompanyWideLabel, overflow: TextOverflow.ellipsis)),
        ...branches.map((b) => DropdownMenuItem<int?>(
              value: b.id,
              child: Text(b.branchName, overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: onChanged,
    );
  }
}

// ── Toggle tile (Optional / Active) ─────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: value ? color.withValues(alpha: 0.07) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? color.withValues(alpha: 0.40) : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? color : AppColors.textHint, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(sublabel, style: AppTextStyles.caption.copyWith(
                    color: value ? color : AppColors.textHint, fontSize: 11)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: color),
        ],
      ),
    );
  }
}

// ── Dialog header (same pattern as dept_form_sheet.dart's _DlgHeader) ────────

class _DlgHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  const _DlgHeader({required this.icon, required this.title, required this.subtitle, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
