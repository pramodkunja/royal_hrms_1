import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/employee_assets_datasource.dart';
import '../../data/models/employee_model.dart';

// Employee Profile → Assets: web employees/[id]/_components/AssetsTab.tsx
// (contract in employee_assets_datasource.dart). Two cards — "Assigned
// Assets" (Assign Asset / Return for assets.edit) and "Asset History" —
// rendered as cards instead of web's tables. Web leaves the tables empty
// when the list fails to load; here the failure is shown with Retry.

final employeeAssetsDataSourceProvider =
    Provider<EmployeeAssetsDataSource>((ref) => EmployeeAssetsDataSource(ref.watch(dioProvider)));

/// GET /assets/employees/<user uuid>/, once per employee while the tab is used.
final employeeAssetsProvider = FutureProvider.autoDispose.family<EmployeeAssets, String>(
  (ref, uuid) => ref.watch(employeeAssetsDataSourceProvider).fetch(uuid),
);

/// Web usePermission("assets.edit"): superuser flag or the permission. (The
/// login payload's is_superuser already includes settings.edit holders —
/// backend LoginView; the API checks assets.edit itself either way.)
bool canEditAssets(UserEntity? user) =>
    user != null && (user.isSuperuser || user.permissions.contains('assets.edit'));

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Web fmtDate (en-IN, 2-digit day, short month): "05 Nov 2026".
String fmtAssetDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso.isEmpty ? '—' : iso;
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _or(String v) => v.isEmpty ? '—' : v;

class EmployeeAssetsTab extends ConsumerStatefulWidget {
  const EmployeeAssetsTab({super.key, required this.employee});
  final EmployeeModel employee;

  @override
  ConsumerState<EmployeeAssetsTab> createState() => _EmployeeAssetsTabState();
}

class _EmployeeAssetsTabState extends ConsumerState<EmployeeAssetsTab> {
  String? _success;
  Timer? _successTimer;

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }

  void _showSuccess(String message) {
    _successTimer?.cancel();
    setState(() => _success = message);
    // Web clears its success alert after 5 s.
    _successTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _success = null);
    });
  }

  Future<void> _openAssign(String uuid) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AssignAssetSheet(employeeUuid: uuid),
    );
    if (done == true && mounted) {
      ref.invalidate(employeeAssetsProvider(uuid));
      _showSuccess('Asset assigned successfully.');
    }
  }

  Future<void> _openReturn(String uuid, AssetAssignment a) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReturnAssetSheet(assignment: a),
    );
    if (done == true && mounted) {
      ref.invalidate(employeeAssetsProvider(uuid));
      _showSuccess('Asset returned successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uuid = widget.employee.uuid ?? '';
    final canEdit = canEditAssets(ref.watch(authStateProvider).valueOrNull?.user);
    if (uuid.isEmpty) {
      return const Center(
        key: Key('assets-no-uuid'),
        child: Padding(padding: EdgeInsets.all(24), child: Text("Assets can't be loaded for this employee.")),
      );
    }
    final async = ref.watch(employeeAssetsProvider(uuid));
    final loading = async.isLoading;
    final error = async.hasError && !loading ? async.error : null;
    final data = async.valueOrNull;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(employeeAssetsProvider(uuid).future),
      child: ListView(
        key: const Key('assets-tab'),
        // Inside the profile's NestedScrollView every tab must not claim the
        // shared PrimaryScrollController (see employee_profile_screen.dart).
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          if (_success != null)
            _Banner(key: const Key('assets-success'), text: _success!, success: true),
          _Card(
            title: 'Assigned Assets',
            action: canEdit
                ? FilledButton.icon(
                    key: const Key('assets-assign'),
                    onPressed: () => _openAssign(uuid),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Assign Asset'),
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  )
                : null,
            child: loading
                ? const _Empty(key: Key('assets-loading'), icon: Icons.hourglass_empty, title: 'Loading assets…', busy: true)
                : error != null
                    ? Column(key: const Key('assets-error'), children: [
                        Text(userFriendlyMessage(error), style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                        TextButton(
                          key: const Key('assets-retry'),
                          onPressed: () => ref.invalidate(employeeAssetsProvider(uuid)),
                          child: const Text('Retry'),
                        ),
                      ])
                    : (data?.current ?? const []).isEmpty
                        ? const _Empty(
                            key: Key('assets-current-empty'),
                            icon: Icons.inventory_2_outlined,
                            title: 'No assets assigned',
                            body: 'Company equipment assigned to this employee will be listed here.',
                          )
                        : Column(children: [
                            for (final a in data!.current)
                              _CurrentRow(
                                a: a,
                                onReturn: canEdit ? () => _openReturn(uuid, a) : null,
                              ),
                          ]),
          ),
          const SizedBox(height: 16),
          _Card(
            title: 'Asset History',
            child: loading || error != null
                ? const SizedBox.shrink()
                : (data?.history ?? const []).isEmpty
                    ? const _Empty(key: Key('assets-history-empty'), icon: Icons.history, title: 'No returned assets yet')
                    : Column(children: [for (final a in data!.history) _HistoryRow(a: a)]),
          ),
        ],
      ),
    );
  }
}

// ── Rows ────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field(this.label, this.value, {this.mono = false});
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 118, child: Text(label, style: AppTextStyles.caption)),
          Expanded(
            child: Text(value,
                style: mono ? AppTextStyles.bodySmall.copyWith(fontFamily: 'monospace') : AppTextStyles.bodySmall),
          ),
        ]),
      );
}

class _CurrentRow extends StatelessWidget {
  const _CurrentRow({required this.a, this.onReturn});
  final AssetAssignment a;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) => Container(
        key: Key('asset-current-${a.id}'),
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(a.assetName, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(a.statusDisplay, style: AppTextStyles.caption.copyWith(color: AppColors.info)),
            ),
          ]),
          _Field('Asset Tag', a.assetTag, mono: true),
          _Field('Type', _or(a.assetType)),
          _Field('Serial Number', _or(a.serialNumber)),
          _Field('Assigned Date', fmtAssetDate(a.assignedDate)),
          _Field('Condition', _or(a.conditionAtAssignment)),
          if (onReturn != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('asset-return-${a.id}'),
                onPressed: onReturn,
                icon: const Icon(Icons.keyboard_return, size: 16),
                label: const Text('Return'),
              ),
            ),
        ]),
      );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.a});
  final AssetAssignment a;

  @override
  Widget build(BuildContext context) => Container(
        key: Key('asset-history-${a.id}'),
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.assetName, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
          _Field('Asset Tag', a.assetTag, mono: true),
          _Field('Assigned', fmtAssetDate(a.assignedDate)),
          _Field('Returned', a.returnDate.isEmpty ? '—' : fmtAssetDate(a.returnDate)),
          _Field('Return Condition', _or(a.returnCondition)),
          _Field('Return Reason', _or(a.returnReason)),
        ]),
      );
}

// ── Shared bits ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700))),
            if (action != null) action!,
          ]),
          child,
        ]),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({super.key, required this.icon, required this.title, this.body, this.busy = false});
  final IconData icon;
  final String title;
  final String? body;
  final bool busy;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(children: [
          busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon, size: 28, color: AppColors.textHint),
          const SizedBox(height: 8),
          Text(title, style: AppTextStyles.label),
          if (body != null) ...[
            const SizedBox(height: 4),
            Text(body!, textAlign: TextAlign.center, style: AppTextStyles.caption),
          ],
        ]),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text, this.success = false});
  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final c = success ? AppColors.success : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: AppTextStyles.caption.copyWith(color: c)),
    );
  }
}

/// A date field (YYYY-MM-DD) with a picker; [optional] adds a clear button.
class _DateField extends StatelessWidget {
  const _DateField({super.key, required this.value, required this.onChanged, this.optional = false});
  final String value;
  final ValueChanged<String> onChanged;
  final bool optional;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final initial = DateTime.tryParse(value) ?? DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(_ymd(picked));
        },
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: value.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => onChanged(''),
                  )
                : const Icon(Icons.calendar_today_outlined, size: 16),
          ),
          child: Text(value.isEmpty ? (optional ? 'Not set' : 'Select a date') : fmtAssetDate(value),
              style: AppTextStyles.body),
        ),
      );
}

Widget _label(String text, {bool optional = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 12),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: text, style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600)),
        if (optional) TextSpan(text: ' (optional)', style: AppTextStyles.caption),
      ])),
    );

InputDecoration _boxDec([String? hint]) => InputDecoration(
      hintText: hint,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.error,
    required this.children,
    required this.busy,
    required this.submitLabel,
    required this.busyLabel,
    required this.onSubmit,
  });
  final String title;
  final String? error;
  final List<Widget> children;
  final bool busy;
  final String submitLabel;
  final String busyLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(children: [
              Expanded(child: Text(title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 16))),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: busy ? null : () => Navigator.of(context).pop(false),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (error != null) _Banner(key: const Key('asset-sheet-error'), text: error!),
                ...children,
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('asset-sheet-cancel'),
                  onPressed: busy ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('asset-sheet-submit'),
                  onPressed: busy ? null : onSubmit,
                  child: Text(busy ? busyLabel : submitLabel),
                ),
              ),
            ]),
          ),
        ]),
      );
}

// ── Assign ──────────────────────────────────────────────────────────────────

class _AssignAssetSheet extends ConsumerStatefulWidget {
  const _AssignAssetSheet({required this.employeeUuid});
  final String employeeUuid;

  @override
  ConsumerState<_AssignAssetSheet> createState() => _AssignAssetSheetState();
}

class _AssignAssetSheetState extends ConsumerState<_AssignAssetSheet> {
  List<AvailableAsset> _available = const [];
  bool _loadingAssets = true;
  String _asset = '';
  String _assignedDate = _ymd(DateTime.now()); // web: today
  String _condition = 'new'; // web BLANK_ASSIGN
  String _expectedReturn = '';
  final _remarks = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(employeeAssetsDataSourceProvider).fetchAvailable().then((list) {
      if (mounted) {
        setState(() {
          _available = list;
          _loadingAssets = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    // Web submitAssign's checks, in order; the server checks the rest.
    if (_asset.isEmpty) return setState(() => _error = 'Select an asset to assign.');
    if (_assignedDate.isEmpty) return setState(() => _error = 'Assigned date is required.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(employeeAssetsDataSourceProvider).assign(
            widget.employeeUuid,
            assetId: _asset,
            assignedDate: _assignedDate,
            condition: _condition,
            expectedReturnDate: _expectedReturn,
            remarks: _remarks.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = userFriendlyMessage(e);
      setState(() {
        _busy = false;
        _error = msg.isEmpty ? 'Failed to assign asset.' : msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
        title: 'Assign Asset',
        error: _error,
        busy: _busy,
        submitLabel: 'Assign Asset',
        busyLabel: 'Assigning…',
        onSubmit: _submit,
        children: [
          _label('Asset *'),
          DropdownButtonFormField<String>(
            key: const Key('assign-asset'),
            initialValue: _asset,
            isExpanded: true,
            decoration: _boxDec(),
            items: [
              const DropdownMenuItem(value: '', child: Text('Select an available asset…')),
              for (final a in _available)
                DropdownMenuItem(value: a.id, child: Text(a.label, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _asset = v ?? ''),
          ),
          if (!_loadingAssets && _available.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('No available assets in scope right now.',
                  key: const Key('assign-no-assets'), style: AppTextStyles.caption),
            ),
          _label('Assigned Date *'),
          _DateField(
            key: const Key('assign-date'),
            value: _assignedDate,
            onChanged: (v) => setState(() => _assignedDate = v),
          ),
          _label('Condition at Assignment *'),
          DropdownButtonFormField<String>(
            key: const Key('assign-condition'),
            initialValue: _condition,
            isExpanded: true,
            decoration: _boxDec(),
            items: [for (final (v, l) in kAssetConditions) DropdownMenuItem(value: v, child: Text(l))],
            onChanged: _busy ? null : (v) => setState(() => _condition = v ?? 'new'),
          ),
          _label('Expected Return Date', optional: true),
          _DateField(
            key: const Key('assign-expected-return'),
            value: _expectedReturn,
            optional: true,
            onChanged: (v) => setState(() => _expectedReturn = v),
          ),
          _label('Remarks', optional: true),
          TextField(
            key: const Key('assign-remarks'),
            controller: _remarks,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            decoration: _boxDec(),
          ),
        ],
      );
}

// ── Return ──────────────────────────────────────────────────────────────────

class _ReturnAssetSheet extends ConsumerStatefulWidget {
  const _ReturnAssetSheet({required this.assignment});
  final AssetAssignment assignment;

  @override
  ConsumerState<_ReturnAssetSheet> createState() => _ReturnAssetSheetState();
}

class _ReturnAssetSheetState extends ConsumerState<_ReturnAssetSheet> {
  String _returnDate = _ymd(DateTime.now()); // web: today
  String _condition = 'good'; // web BLANK_RETURN
  final _reason = TextEditingController();
  final _remarks = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_returnDate.isEmpty) return setState(() => _error = 'Return date is required.');
    if (_reason.text.trim().isEmpty) return setState(() => _error = 'Return reason is required.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(employeeAssetsDataSourceProvider).returnAsset(
            widget.assignment.id,
            returnDate: _returnDate,
            condition: _condition,
            reason: _reason.text,
            remarks: _remarks.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = userFriendlyMessage(e);
      setState(() {
        _busy = false;
        _error = msg.isEmpty ? 'Failed to return asset.' : msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
        title: 'Return Asset — ${widget.assignment.assetTag}',
        error: _error,
        busy: _busy,
        submitLabel: 'Return Asset',
        busyLabel: 'Returning…',
        onSubmit: _submit,
        children: [
          _label('Return Date *'),
          _DateField(
            key: const Key('return-date'),
            value: _returnDate,
            onChanged: (v) => setState(() => _returnDate = v),
          ),
          _label('Return Condition *'),
          DropdownButtonFormField<String>(
            key: const Key('return-condition'),
            initialValue: _condition,
            isExpanded: true,
            decoration: _boxDec(),
            items: [for (final (v, l) in kAssetConditions) DropdownMenuItem(value: v, child: Text(l))],
            onChanged: _busy ? null : (v) => setState(() => _condition = v ?? 'good'),
          ),
          _label('Return Reason *'),
          TextField(
            key: const Key('return-reason'),
            controller: _reason,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            decoration: _boxDec('e.g. Employee offboarding, equipment upgrade, damaged…'),
          ),
          _label('Remarks', optional: true),
          TextField(
            key: const Key('return-remarks'),
            controller: _remarks,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            decoration: _boxDec(),
          ),
        ],
      );
}
