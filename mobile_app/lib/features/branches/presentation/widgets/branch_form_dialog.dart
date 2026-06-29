import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/branch_entity.dart';
import '../providers/branch_providers.dart';
import 'branch_dlg_header.dart';
import 'branch_location_selector.dart';

class BranchFormDialog extends ConsumerStatefulWidget {
  final BranchEntity? branch;
  const BranchFormDialog({super.key, this.branch});

  @override
  ConsumerState<BranchFormDialog> createState() => _BranchFormDialogState();
}

class _BranchFormDialogState extends ConsumerState<BranchFormDialog> {
  final _locationKey = GlobalKey<BranchLocationSelectorState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String _status = 'active';
  bool _isHeadquarter = false;
  bool _saving = false;
  String? _nameError;
  String? _addressError;

  bool get _isAdd => widget.branch == null;

  @override
  void initState() {
    super.initState();
    if (!_isAdd) {
      final b = widget.branch!;
      _nameCtrl.text = b.branchName;
      _addressCtrl.text = b.address;
      _status = b.status;
      _isHeadquarter = b.isHeadquarter;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branch = widget.branch;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BranchDlgHeader(
            icon: Icons.business_outlined,
            title: _isAdd
                ? 'Add New Branch'
                : 'Edit Branch: ${branch!.branchName}',
            subtitle: _isAdd
                ? 'Create a new office location'
                : 'Update branch details',
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BranchLocationSelector(
                      key: _locationKey,
                      initialState: branch != null
                          ? StateEntity(
                              id: branch.stateId,
                              name: branch.stateName,
                              code: '')
                          : null,
                      initialCity: branch != null
                          ? CityEntity(
                              id: branch.cityId,
                              name: branch.cityName,
                              stateId: branch.stateId,
                              stateName: branch.stateName)
                          : null,
                      initialCode: branch?.branchCode ?? '',
                      onChanged: (_, __, ___) {},
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtrl,
                      style: AppTextStyles.body,
                      onChanged: (_) => setState(() => _nameError = null),
                      decoration: _dec('Branch Name *', _nameError),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      style: AppTextStyles.body,
                      maxLines: 3,
                      onChanged: (_) => setState(() => _addressError = null),
                      decoration: _dec('Address *', _addressError),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('status-$_status'),
                      initialValue: _status,
                      style: AppTextStyles.body,
                      decoration: _dec('Status'),
                      items: const [
                        DropdownMenuItem(
                            value: 'active', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'inactive', child: Text('Inactive')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: CheckboxListTile(
                        value: _isHeadquarter,
                        onChanged: (val) =>
                            setState(() => _isHeadquarter = val ?? false),
                        title: Text('Mark as Headquarter',
                            style: AppTextStyles.label),
                        subtitle: Text(
                          'Only one branch can be the headquarter',
                          style: AppTextStyles.caption,
                        ),
                        activeColor: AppColors.primary,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _isAdd ? 'Create Branch' : 'Save Changes',
                              style: AppTextStyles.label
                                  .copyWith(color: Colors.white),
                            ),
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

  bool _validate() {
    final locationOk =
        _locationKey.currentState?.validate() ?? false;
    bool fieldsOk = true;
    setState(() {
      _nameError = _nameCtrl.text.trim().isEmpty
          ? 'Branch name is required'
          : null;
      _addressError = _addressCtrl.text.trim().isEmpty
          ? 'Address is required'
          : null;
      if (_nameError != null || _addressError != null) fieldsOk = false;
    });
    return locationOk && fieldsOk;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    final locState = _locationKey.currentState!;
    setState(() => _saving = true);
    final notifier = ref.read(branchListProvider.notifier);

    final String? result;
    if (_isAdd) {
      result = await notifier.create(
        cityId: locState.selectedCity!.id,
        stateId: locState.selectedState!.id,
        branchName: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        status: _status,
        isHeadquarter: _isHeadquarter,
      );
    } else {
      result = await notifier.edit(
        id: widget.branch!.id,
        cityId: locState.selectedCity!.id,
        stateId: locState.selectedState!.id,
        branchName: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        status: _status,
        isHeadquarter: _isHeadquarter,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (result == null) {
      Navigator.pop(context);
      ref.read(branchStatsProvider.notifier).refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}
