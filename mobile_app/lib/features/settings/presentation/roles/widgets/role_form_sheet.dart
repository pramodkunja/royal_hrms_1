import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/roles_model.dart';
import '../../providers/settings_providers.dart';
import 'permission_tree.dart';

// ── Preset definitions ────────────────────────────────────────────────────────

const _kManagerPreset = {
  'announcements.view',
  'attendance.create', 'attendance.edit', 'attendance.export', 'attendance.view',
  'documents.view',
  'employees.view',
  'expenses.approve', 'expenses.create', 'expenses.delete', 'expenses.edit', 'expenses.view',
  'leave.approve', 'leave.create', 'leave.delete', 'leave.edit', 'leave.view',
  'payroll.view',
  'referrals.create', 'referrals.view',
};

const _kEmployeePreset = {
  'announcements.view',
  'attendance.view', 'attendance.create',
  'leave.view', 'leave.create',
  'expenses.view', 'expenses.create',
  'referrals.view', 'referrals.create',
  'payroll.view',
};

Set<String> _presetPerms(String preset, List<PermissionModel> all) => switch (preset) {
  'full_admin' => all.map((p) => p.name).toSet(),
  'view_only'  => all.where((p) => p.name.endsWith('.view')).map((p) => p.name).toSet(),
  'manager'    => _kManagerPreset,
  'employee'   => _kEmployeePreset,
  _            => {},
};

// ── Sheet ─────────────────────────────────────────────────────────────────────

class RoleFormSheet extends StatefulWidget {
  final RoleModel? role;
  final WidgetRef ref;
  const RoleFormSheet({super.key, this.role, required this.ref});

  @override
  State<RoleFormSheet> createState() => _RoleFormSheetState();
}

class _RoleFormSheetState extends State<RoleFormSheet> {
  late final RoleFormData _form;
  late final TextEditingController _nameCtrl;
  final Map<String, String?> _errors = {};
  bool _saving = false;

  bool get _isAdd => widget.role == null;

  @override
  void initState() {
    super.initState();
    _form = widget.role != null
        ? RoleFormData.fromModel(widget.role!)
        : RoleFormData();
    _nameCtrl = TextEditingController(text: _form.displayName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String v) {
    _form.displayName = v;
    if (_isAdd) _form.name = RoleFormData.toSlug(v);
    setState(() => _errors.remove('displayName'));
  }

  void _togglePerm(String codename) => setState(() {
    if (_form.permissions.contains(codename)) {
      _form.permissions.remove(codename);
    } else {
      _form.permissions.add(codename);
    }
    _errors.remove('permissions');
  });

  void _toggleModule(String module, bool selectAll, List<PermissionModel> all) {
    final codes = all.where((p) => p.module == module).map((p) => p.name).toSet();
    setState(() {
      if (selectAll) {
        _form.permissions.addAll(codes);
      } else {
        _form.permissions.removeAll(codes);
      }
      _errors.remove('permissions');
    });
  }

  void _applyPreset(String preset, List<PermissionModel> all) {
    setState(() {
      _form.permissions
        ..clear()
        ..addAll(_presetPerms(preset, all));
      _errors.remove('permissions');
    });
  }

  bool _isPresetActive(String preset, List<PermissionModel> all) {
    final presetSet = _presetPerms(preset, all);
    return presetSet.isNotEmpty &&
        presetSet.length == _form.permissions.length &&
        presetSet.difference(_form.permissions).isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final permsAsync = widget.ref.watch(allPermissionsProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DlgHeader(
            icon: _isAdd ? Icons.shield_outlined : Icons.edit_outlined,
            title: _isAdd ? 'Add New Role' : 'Edit Role',
            subtitle: _isAdd
                ? 'Define a role and assign module permissions'
                : widget.role?.displayName ?? '',
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
                children: [
                  _buildNameField(),
                  _buildSlugField(),
                  const SizedBox(height: 16),
                  permsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text(e.toString(), style: AppTextStyles.caption),
                    data: (all) => _buildPermissionsSection(all),
                  ),
                  const SizedBox(height: 20),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _nameCtrl,
      style: AppTextStyles.body,
      onChanged: _onNameChanged,
      decoration: _dec('Role Name *', _errors['displayName']).copyWith(
        hintText: 'e.g. Finance Manager',
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
      ),
    ),
  );

  Widget _buildSlugField() => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        const Icon(Icons.link, size: 14, color: AppColors.textHint),
        const SizedBox(width: 6),
        Text('Slug: ', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
        Expanded(
          child: Text(
            _form.name.isEmpty ? '—' : _form.name,
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'monospace',
              color: _form.name.isEmpty ? AppColors.textHint : AppColors.textSecondary,
            ),
          ),
        ),
        if (!_isAdd)
          const Icon(Icons.lock_outline, size: 13, color: AppColors.textHint),
      ],
    ),
  );

  Widget _buildPermissionsSection(List<PermissionModel> all) {
    final selectedCount = _form.permissions.length;
    final totalCount = all.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Expanded(child: Text('Permissions *', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600))),
            _GhostBtn(label: 'Select all', onTap: () => setState(() {
              _form.permissions
                ..clear()
                ..addAll(all.map((p) => p.name));
              _errors.remove('permissions');
            })),
            const SizedBox(width: 8),
            _GhostBtn(label: 'Clear', onTap: () => setState(() {
              _form.permissions.clear();
            })),
          ],
        ),
        const SizedBox(height: 10),
        // Quick presets
        Row(
          children: [
            _PresetBtn(label: 'Full Admin', icon: Icons.shield_outlined, active: _isPresetActive('full_admin', all), onTap: () => _applyPreset('full_admin', all)),
            const SizedBox(width: 8),
            _PresetBtn(label: 'View Only', icon: Icons.visibility_outlined, active: _isPresetActive('view_only', all), onTap: () => _applyPreset('view_only', all)),
            const SizedBox(width: 8),
            _PresetBtn(label: 'Manager', icon: Icons.manage_accounts_outlined, active: _isPresetActive('manager', all), onTap: () => _applyPreset('manager', all)),
            const SizedBox(width: 8),
            _PresetBtn(label: 'Employee', icon: Icons.person_outline, active: _isPresetActive('employee', all), onTap: () => _applyPreset('employee', all)),
          ],
        ),
        const SizedBox(height: 10),
        // Count + error
        Text(
          '$selectedCount of $totalCount permissions selected',
          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        ),
        if (_errors['permissions'] != null) ...[
          const SizedBox(height: 4),
          Text(_errors['permissions']!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 12),
        // Module accordion tree
        PermissionTree(
          permissions: all,
          selected: _form.permissions,
          onTogglePerm: _togglePerm,
          onToggleModule: (mod, sel) => _toggleModule(mod, sel, all),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() => FilledButton(
    onPressed: _saving ? null : () => _submit(),
    style: FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
      backgroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: _saving
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Text(
            _isAdd ? '+ Add Role' : 'Save Changes',
            style: AppTextStyles.label.copyWith(color: Colors.white),
          ),
  );

  InputDecoration _dec(String label, [String? error]) => InputDecoration(
    labelText: label,
    errorText: error,
    labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  Future<void> _submit() async {
    _form.displayName = _nameCtrl.text;
    if (_isAdd) _form.name = RoleFormData.toSlug(_form.displayName);
    final errors = _form.validate();
    if (errors.isNotEmpty) {
      setState(() => _errors.addAll(errors));
      return;
    }
    setState(() => _saving = true);
    final notifier = widget.ref.read(rolesProvider.notifier);
    final result = _isAdd
        ? await notifier.create(_form)
        : await notifier.edit(widget.role!.id, _form);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

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
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
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

class _GhostBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _PresetBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _PresetBtn({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withValues(alpha: 0.10) : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: active ? AppColors.primary : AppColors.textHint),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
