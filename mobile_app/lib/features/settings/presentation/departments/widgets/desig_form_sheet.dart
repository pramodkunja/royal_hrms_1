import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/departments_model.dart';
import '../../providers/settings_providers.dart';

class DesigFormSheet extends StatefulWidget {
  final DesignationModel? designation;
  final WidgetRef ref;

  const DesigFormSheet({super.key, this.designation, required this.ref});

  @override
  State<DesigFormSheet> createState() => _DesigFormSheetState();
}

class _DesigFormSheetState extends State<DesigFormSheet> {
  late final TextEditingController _nameCtrl;
  int? _deptId;
  bool _saving = false;
  Map<String, String?> _errors = {};

  bool get _isAdd => widget.designation == null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.designation?.name ?? '');
    _deptId   = widget.designation?.departmentId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deptsAsync = widget.ref.watch(departmentsProvider);

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
          Container(
            color: AppColors.background,
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  style: AppTextStyles.body,
                  autofocus: true,
                  onChanged: (_) => setState(() => _errors.remove('name')),
                  decoration: _dec('Designation Name *', _errors['name']),
                ),
                const SizedBox(height: 12),
                deptsAsync.when(
                  data: (depts) => DropdownButtonFormField<int>(
                    initialValue: _deptId,
                    style: AppTextStyles.body,
                    decoration: _dec('Department *', _errors['departmentId']),
                    items: depts.map((d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(d.name),
                    )).toList(),
                    onChanged: (v) => setState(() {
                      _deptId = v;
                      _errors.remove('departmentId');
                    }),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),
                FilledButton(
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
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  Future<void> _submit() async {
    final form = DesignationFormData(name: _nameCtrl.text, departmentId: _deptId);
    final validationErrors = form.validate();
    if (validationErrors.isNotEmpty) {
      setState(() => _errors = validationErrors);
      return;
    }
    setState(() => _saving = true);
    final notifier = widget.ref.read(designationsProvider.notifier);
    final result = _isAdd
        ? await notifier.createDesig(form)
        : await notifier.editDesig(widget.designation!.id, form);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result),
        backgroundColor: AppColors.error,
      ));
    }
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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
