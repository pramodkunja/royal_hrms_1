import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/departments_model.dart';
import '../../providers/settings_providers.dart';
import 'department_select_field.dart';

class DesigFormSheet extends ConsumerStatefulWidget {
  final DesignationModel? designation;
  final int? defaultDeptId;

  // Its own ref: the sheet must rebuild when the departments request changes (Retry),
  // which a ref borrowed from the screen behind the dialog would not do.
  const DesigFormSheet({super.key, this.designation, this.defaultDeptId});

  @override
  ConsumerState<DesigFormSheet> createState() => _DesigFormSheetState();
}

class _DesigFormSheetState extends ConsumerState<DesigFormSheet> {
  late final TextEditingController _nameCtrl;
  int? _deptId;
  late bool _isActive;
  bool _saving = false;
  Map<String, String?> _errors = {};
  String? _saveError;

  bool get _isAdd => widget.designation == null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.designation?.name ?? '');
    _deptId   = widget.designation?.departmentId ?? widget.defaultDeptId;
    _isActive = widget.designation?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deptsAsync = ref.watch(departmentsProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DlgHeader(
            icon: Icons.work_outline,
            title: _isAdd ? 'Add Designation' : 'Edit Designation',
            subtitle: 'Define job titles within departments',
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_saveError != null) ...[
                      _ErrorBanner(message: _saveError!),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      key: const Key('desig-name'),
                      controller: _nameCtrl,
                      style: AppTextStyles.body,
                      autofocus: true,
                      onChanged: (_) => setState(() {
                        _errors.remove('name');
                        _saveError = null;
                      }),
                      maxLength: 100,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      decoration: _dec('Designation Name *', _errors['name']),
                    ),
                    const SizedBox(height: 12),
                    DepartmentSelectField(
                      departments: deptsAsync,
                      value: _deptId,
                      errorText: _errors['departmentId'],
                      onRetry: () => ref.invalidate(departmentsProvider),
                      onChanged: (v) => setState(() {
                        _deptId = v;
                        _errors.remove('departmentId');
                        _saveError = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _StatusToggle(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('desig-submit'),
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(_isAdd ? 'Add Designation' : 'Save Changes',
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
    final form = DesignationFormData(name: _nameCtrl.text, departmentId: _deptId, isActive: _isActive);
    final validationErrors = form.validate();
    if (validationErrors.isNotEmpty) {
      setState(() => _errors = validationErrors);
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final notifier = ref.read(designationsProvider.notifier);
    final result = _isAdd
        ? await notifier.createDesig(form)
        : await notifier.editDesig(widget.designation!.id, form);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) {
      Navigator.pop(context);
    } else {
      // Inline (as web's saveError alert): a snackbar would sit behind this dialog's scrim.
      setState(() => _saveError = result);
    }
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('desig-save-error'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.error_outline, size: 18, color: AppColors.error),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
      ]),
    );
  }
}

// ── Status toggle ─────────────────────────────────────────────────────────────

class _StatusToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _StatusToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: value
            ? AppColors.success.withValues(alpha: 0.07)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? AppColors.success.withValues(alpha: 0.40)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: value ? AppColors.success : AppColors.textHint,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ? 'Active — visible across the system' : 'Inactive — hidden from selection',
                  style: AppTextStyles.caption.copyWith(
                    color: value ? AppColors.success : AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

// ── Dialog header ─────────────────────────────────────────────────────────────

class _DlgHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  const _DlgHeader({required this.icon, required this.title, required this.subtitle, required this.onClose});

  @override
  Widget build(BuildContext context) {
    // At large text the icon tile and subtitle give way so the title keeps whole words.
    final large = MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          if (!large) Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (!large) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                if (!large) const SizedBox(height: 2),
                if (!large) Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: onClose,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ),
    );
  }
}
