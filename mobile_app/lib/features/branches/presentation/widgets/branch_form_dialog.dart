import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/branch_admin_leader.dart';
import '../../domain/branch_form_rules.dart';
import '../../domain/branch_geofence.dart';
import '../../domain/entities/branch_entity.dart';
import '../providers/branch_providers.dart';
import 'branch_dlg_header.dart';
import 'branch_location_selector.dart';
import 'branch_admin_reassign.dart';
import 'branch_leader_fields.dart';
import '../../data/models/branch_model.dart' show BranchAdminCandidate;

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

  // Geofencing (web Add/Edit Branch form): toggle + latitude / longitude
  // (degrees) + allowed radius (metres, default 150).
  bool _geoEnabled = false;
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController(text: '${BranchGeofence.kDefaultRadius}');
  Map<String, String> _geoErrors = const {};
  // Server error from the last save, shown in the form; values are kept.
  String? _saveError;

  // Add only — web "Assign Branch Admin (optional)" (LeaderForm). Kept as the
  // form changes, cleared only when the dialog closes, as web.
  BranchLeaderForm _leader = const BranchLeaderForm();
  Map<String, String> _leaderErrors = const {};
  // Web transferChecking: the relationship counts are being looked up.
  bool _checking = false;

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
      _geoEnabled = b.geofencingEnabled;
      _latCtrl.text = b.latitude?.toString() ?? '';
      _lonCtrl.text = b.longitude?.toString() ?? '';
      _radiusCtrl.text = '${b.allowedRadiusMeters}';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _radiusCtrl.dispose();
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
                      // Own Material so the tile's ink isn't hidden by the
                      // form's coloured background (debug ListTile assertion).
                      child: Material(
                        type: MaterialType.transparency,
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
                    ),
                    const SizedBox(height: 12),
                    _buildGeofence(),
                    // Web Edit Branch form: "Branch Admin" with Change / Assign
                    // (the same flow as the details sheet). The branch is read
                    // from the live list so a reassignment shows here at once.
                    if (!_isAdd) ...[
                      const SizedBox(height: 16),
                      BranchAdminSection(
                        key: const Key('edit-branch-admin'),
                        branch: ref.watch(branchListProvider).valueOrNull?.where((b) => b.id == branch!.id).firstOrNull ??
                            branch!,
                        closeOnSuccess: false,
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      BranchLeaderFields(
                        form: _leader,
                        errors: _leaderErrors,
                        enabled: !_saving && !_checking,
                        onChanged: (f) => setState(() {
                          _leader = f;
                          _leaderErrors = const {};
                        }),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_saveError != null) ...[
                      Container(
                        key: const Key('branch-form-error'),
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(_saveError!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                      ),
                    ],
                    FilledButton(
                      key: const Key('branch-form-submit'),
                      onPressed: _saving || _checking ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _checking
                          ? Text('Checking…', style: AppTextStyles.label.copyWith(color: Colors.white))
                          : _saving
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

  void _clearGeoError(String key) {
    if (_geoErrors.containsKey(key)) setState(() => _geoErrors = {..._geoErrors}..remove(key));
  }

  Widget _buildGeofence() {
    return Container(
      key: const Key('branch-geofence'),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            key: const Key('branch-geofence-toggle'),
            value: _geoEnabled,
            contentPadding: EdgeInsets.zero,
            title: Text('Enable Geofencing', style: AppTextStyles.label),
            activeTrackColor: AppColors.primary,
            onChanged: _saving
                ? null
                : (v) => setState(() {
                      _geoEnabled = v;
                      _geoErrors = const {};
                    }),
          ),
        ),
        if (_geoEnabled) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                key: const Key('branch-geofence-latitude'),
                controller: _latCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                onChanged: (_) => _clearGeoError('latitude'),
                decoration: _dec('Latitude *', _geoErrors['latitude']).copyWith(hintText: 'e.g. 19.0760'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('branch-geofence-longitude'),
                controller: _lonCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                onChanged: (_) => _clearGeoError('longitude'),
                decoration: _dec('Longitude *', _geoErrors['longitude']).copyWith(hintText: 'e.g. 72.8777'),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Enter the GPS coordinates of the office entrance. Use Google Maps — right-click the location and copy the coordinates.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('branch-geofence-radius'),
            controller: _radiusCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _clearGeoError('allowed_radius_meters'),
            decoration: _dec('Allowed Radius (metres) *', _geoErrors['allowed_radius_meters']),
          ),
        ],
      ]),
    );
  }

  bool _validate() {
    final locationOk =
        _locationKey.currentState?.validate() ?? false;
    bool fieldsOk = true;
    setState(() {
      // Web validate(): required, at most 200 characters, BRANCH_NAME_RE —
      // the same on Add and Edit, on the trimmed name.
      _nameError = validateBranchName(_nameCtrl.text);
      _addressError = _addressCtrl.text.trim().isEmpty
          ? 'Address is required'
          : null;
      if (_nameError != null || _addressError != null) fieldsOk = false;
    });
    return locationOk && fieldsOk;
  }

  Future<void> _submit() async {
    if (_saving) return;
    final coreOk = _validate();
    final geo = validateBranchGeofence(
      enabled: _geoEnabled,
      latitude: _latCtrl.text,
      longitude: _lonCtrl.text,
      radius: _radiusCtrl.text,
    );
    // Web handleSave: the branch fields and the (optional) Branch Admin row
    // are validated together; nothing is sent while either has an error.
    final leaderErrs = _isAdd ? validateBranchLeader(_leader) : const <String, String>{};
    setState(() {
      _geoErrors = geo.errors;
      _leaderErrors = leaderErrs;
    });
    if (!coreOk || geo.value == null || leaderErrs.isNotEmpty) return;

    // Web handleSave: saving this branch as headquarter while another branch
    // in the list already is asks first. Cancel sends nothing and keeps the
    // form as it is. "Yes, Change HQ" calls web doSave directly — the branch is
    // saved at once and the transfer check below is NOT run (a chosen Branch
    // Admin is still applied after the save, by doSave). The server itself
    // doesn't clear the other branch's HQ flag; only this branch is sent.
    final hq = otherHeadquarter(ref.read(branchListProvider).valueOrNull ?? const [],
        markingHq: _isHeadquarter, editingId: widget.branch?.id);
    if (hq != null) {
      final go = await showChangeHeadquarterConfirm(context);
      if (go != true || !mounted) return;
    }

    // Web: moving an existing employee is confirmed explicitly, with how many
    // people report to them / have them as HR (not reassigned automatically) —
    // only when no headquarter confirm was needed (see above).
    if (hq == null && _isAdd && _leader.mode == BranchLeaderMode.existing && _leader.employeeCode.isNotEmpty) {
      final employee = (ref.read(branchLeaderOptionsProvider).valueOrNull?.employees ?? const <BranchAdminCandidate>[])
          .where((e) => e.code == _leader.employeeCode)
          .firstOrNull;
      if (employee != null) {
        setState(() => _checking = true);
        final counts = await branchLeaderTransferCounts(ref.read(branchDataSourceProvider), employee.uuid);
        if (!mounted) return;
        setState(() => _checking = false);
        final go = await showBranchTransferConfirm(context, employee, counts.reports, counts.hrFor);
        if (go != true || !mounted) return;
      }
    }

    final locState = _locationKey.currentState!;
    setState(() {
      _saving = true;
      _saveError = null;
    });
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
        geofence: geo.value,
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
        geofence: geo.value,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (result == null) {
      final branchName = _nameCtrl.text.trim();
      final leader = _leader;
      final isAdd = _isAdd;
      final messenger = ScaffoldMessenger.maybeOf(context);
      final container = ProviderScope.containerOf(context);
      final ds = ref.read(branchDataSourceProvider);
      final roles = ref.read(branchLeaderOptionsProvider).valueOrNull?.roles ?? const [];
      Navigator.pop(context);
      ref.read(branchStatsProvider.notifier).refresh();
      ref.read(branchDistributionProvider.notifier).refresh();
      // Web: the Branch Admin is applied only after the branch exists and the
      // form has closed — the branch is never blocked or rolled back by it.
      if (isAdd && leader.isActive) {
        final failure = await applyBranchLeader(ds, leader, roles, branchName);
        // Show the new admin on the branch list.
        if (failure == null) container.invalidate(branchListProvider);
        messenger?.showSnackBar(SnackBar(
          key: const Key('branch-leader-result'),
          duration: const Duration(seconds: 6),
          backgroundColor: failure == null ? AppColors.success : AppColors.warning,
          content: Text(failure == null
              ? branchLeaderSuccess(branchName, leader.mode)
              : branchLeaderFailure(branchName, failure)),
        ));
      }
    } else {
      // Shown inside the dialog (it would sit behind it as a snackbar); every
      // entered value is kept for a retry.
      setState(() => _saveError = result);
    }
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}

/// Web transfer confirm: "Move <name>?" — Cancel keeps the form as it was;
/// "Yes, Move Them" goes on to create the branch. Returns true to proceed.
Future<bool?> showBranchTransferConfirm(BuildContext context, BranchAdminCandidate e, int reports, int hrFor) {
  final warnings = [reportsWarning(reports), hrForWarning(hrFor)].whereType<String>().toList();
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('branch-transfer-confirm'),
      title: Row(children: [
        Icon(Icons.swap_horiz, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text('Move ${e.fullName}?')),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(transferConfirmBody(e), key: const Key('branch-transfer-body'), style: AppTextStyles.body),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('branch-transfer-warning'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final w in warnings) Text(w, style: AppTextStyles.caption.copyWith(fontSize: 12.5)),
            ]),
          ),
        ],
      ]),
      actions: [
        TextButton(
            key: const Key('branch-transfer-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel')),
        FilledButton(
            key: const Key('branch-transfer-confirm-yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Move Them')),
      ],
    ),
  );
}

/// Web "Change Headquarter?" modal: Cancel / "Yes, Change HQ". Returns true to
/// go on with the save.
Future<bool?> showChangeHeadquarterConfirm(BuildContext context) => showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('branch-hq-confirm'),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: 8),
          const Expanded(child: Text(kChangeHqTitle)),
        ]),
        content: Text(kChangeHqBody, style: AppTextStyles.body),
        actions: [
          TextButton(
              key: const Key('branch-hq-cancel'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              key: const Key('branch-hq-confirm-yes'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(kChangeHqConfirm)),
        ],
      ),
    );
