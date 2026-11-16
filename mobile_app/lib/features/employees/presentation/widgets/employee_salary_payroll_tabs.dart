import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart' show dioProvider;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/documents/document_links.dart' show openDocumentLinkExternally;
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/data/models/asset_catalogue.dart' show assetError;
import '../../data/models/employee_model.dart';
import 'employee_assets_tab.dart' show fmtAssetDate;

// Employee Profile → Salary and Payroll — web employees/[id]/_components/
// SalaryTab.tsx and PayrollTab.tsx over backend apps/payroll:
//  - GET  /payroll/employee-salary/history/<employee uuid>/ (payroll.view;
//    non-admins: same branch) → every CTC revision, newest first, with its
//    components; is_active marks the current one.
//  - POST /payroll/employee-salary/ {employee, annual_ctc, effective_from,
//    salary_structure|null} (payroll.edit; same branch) — Assign / Revise CTC.
//    The server works out the monthly amounts and components.
//  - GET  /payroll/structures/ (payroll.view) — for the structure picker.
//  - GET  /payroll/employees/<employee uuid>/payslips/ (payroll.view; same
//    branch) → paginated payslips, newest period first (web shows page 1).
// Both tabs are shown whenever the company has the payroll module (web
// ProfileTabBar); what each user may see is decided by the server.

/// Web usePermission: superuser flag or the permission.
bool _has(UserEntity? u, String p) => u != null && (u.isSuperuser || u.permissions.contains(p));

/// Web INR(): "₹6,00,000" — en-IN grouping, no decimals (rounded).
String fmtInr(Object? value) {
  final n = double.tryParse('${value ?? ''}') ?? 0;
  final whole = n.round().abs().toString();
  String grouped;
  if (whole.length <= 3) {
    grouped = whole;
  } else {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  return '${n.round() < 0 ? '-' : ''}₹$grouped';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Web fmtMonth: "Nov 2026".
String fmtPayMonth(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? (iso.isEmpty ? '—' : iso) : '${_months[d.month - 1]} ${d.year}';
}

String _s(Object? v) => v == null ? '' : '$v';

List<Map<String, dynamic>> _rows(dynamic body) {
  final d = body is Map && body.containsKey('data') ? body['data'] : body;
  final list = d is Map ? d['results'] : d;
  return [
    for (final r in (list is List ? list : const []))
      if (r is Map) r.cast<String, dynamic>()
  ];
}

final employeeSalaryHistoryProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
    (ref, uuid) async =>
        _rows((await ref.read(dioProvider).get(ApiConstants.payrollEmployeeSalaryHistory(uuid))).data));

final payrollStructuresProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
    (ref) async => _rows((await ref.read(dioProvider).get(ApiConstants.payrollStructures)).data));

final employeePayslipHistoryProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
    (ref, uuid) async => _rows((await ref.read(dioProvider).get(ApiConstants.payrollEmployeePayslips(uuid))).data));

/// Picks the Effective From date (replaceable in tests).
final salaryDatePickerProvider = Provider<Future<DateTime?> Function(BuildContext, DateTime)>(
  (ref) => (context, initial) =>
      showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100)),
);

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Widget _card({required String title, Widget? action, required Widget child, Key? key}) => Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(children: [
            Expanded(child: Text(title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700))),
            if (action != null) action,
          ]),
        ),
        Divider(height: 1, color: AppColors.border),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ]),
    );

Widget _loadError(Object e, VoidCallback onRetry, String key) => Column(key: Key(key), children: [
      Text(assetError(e, "Couldn't load this.").message,
          textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
      TextButton(key: Key('$key-retry'), onPressed: onRetry, child: const Text('Retry')),
    ]);

// ── Salary ────────────────────────────────────────────────────────────────────

class EmployeeSalaryTab extends ConsumerStatefulWidget {
  const EmployeeSalaryTab({super.key, required this.employee});
  final EmployeeModel employee;

  @override
  ConsumerState<EmployeeSalaryTab> createState() => _EmployeeSalaryTabState();
}

class _EmployeeSalaryTabState extends ConsumerState<EmployeeSalaryTab> {
  String? _success;
  Timer? _hide;
  final _expanded = <String>{};

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  Future<void> _open(Map<String, dynamic>? current) async {
    final uuid = widget.employee.uuid ?? '';
    final msg = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CtcSheet(employeeUuid: uuid, current: current),
    );
    if (msg == null || !mounted) return;
    ref.invalidate(employeeSalaryHistoryProvider(uuid));
    _hide?.cancel();
    setState(() => _success = msg);
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _success = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final uuid = widget.employee.uuid ?? '';
    final canEdit = _has(ref.watch(authStateProvider).valueOrNull?.user, 'payroll.edit');
    final async = ref.watch(employeeSalaryHistoryProvider(uuid));
    final history = async.valueOrNull ?? const <Map<String, dynamic>>[];
    final current = history.where((h) => h['is_active'] == true).firstOrNull;
    final caption = AppTextStyles.caption.copyWith(fontSize: 12);

    Widget stat(String label, String value, {bool large = false, String? key}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: caption.copyWith(fontWeight: FontWeight.w600, letterSpacing: .5)),
            const SizedBox(height: 4),
            Text(value,
                key: key == null ? null : Key(key),
                style: (large ? AppTextStyles.h3 : AppTextStyles.label).copyWith(fontWeight: FontWeight.w700)),
          ],
        );

    return RefreshIndicator(
      onRefresh: () => ref.refresh(employeeSalaryHistoryProvider(uuid).future).then((_) {}, onError: (_) {}),
      child: ListView(
        key: const Key('employee-salary-tab'),
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_success != null)
            Container(
              key: const Key('salary-success'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(_success!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.success)),
            ),
          _card(
            key: const Key('salary-current'),
            title: 'Current CTC',
            action: canEdit && !async.isLoading && !async.hasError
                ? FilledButton.icon(
                    key: const Key('salary-assign'),
                    onPressed: () => _open(current),
                    icon: Icon(current != null ? Icons.edit_outlined : Icons.add, size: 16),
                    label: Text(current != null ? 'Revise CTC' : 'Assign CTC'),
                  )
                : null,
            child: async.when(
              loading: () => const Center(child: Text('Loading…')),
              error: (e, _) => _loadError(e, () => ref.invalidate(employeeSalaryHistoryProvider(uuid)), 'salary-error'),
              data: (_) => current == null
                  ? Column(key: const Key('salary-empty'), children: [
                      Text('₹', style: AppTextStyles.h3.copyWith(color: AppColors.textHint)),
                      Text('No CTC assigned', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                      Text('Click "Assign CTC" to set this employee\'s compensation.',
                          textAlign: TextAlign.center, style: caption),
                    ])
                  : Wrap(spacing: 24, runSpacing: 16, children: [
                      stat('Annual CTC', fmtInr(current['annual_ctc']), large: true, key: 'salary-annual'),
                      stat('Monthly CTC', fmtInr(current['monthly_ctc']), large: true, key: 'salary-monthly'),
                      stat('Effective From', fmtAssetDate(_s(current['effective_from']))),
                      stat('Salary Structure',
                          _s(current['structure_name']).isEmpty ? 'Company Default' : _s(current['structure_name'])),
                    ]),
            ),
          ),
          if (!async.isLoading && history.isNotEmpty)
            _card(
              key: const Key('salary-history'),
              title: 'Revision History',
              child: Column(children: [for (final h in history) _revision(h)]),
            ),
        ],
      ),
    );
  }

  Widget _revision(Map<String, dynamic> h) {
    final caption = AppTextStyles.caption.copyWith(fontSize: 12);
    final structure = _s(h['structure_name']).isNotEmpty
        ? _s(h['structure_name'])
        : (_s(h['template_structure_name']).isNotEmpty ? _s(h['template_structure_name']) : 'Default');
    final comps = [
      for (final c in (h['components'] as List? ?? const []))
        if (c is Map && c['is_enabled'] == true) c,
    ];
    final active = h['is_active'] == true;
    return Container(
      key: Key('salary-revision-${h['id']}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('From ${fmtAssetDate(_s(h['effective_from']))}',
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (active ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(active ? 'Latest' : 'Earlier revision',
                style: AppTextStyles.caption.copyWith(color: active ? AppColors.success : AppColors.textSecondary)),
          ),
        ]),
        Text('${fmtInr(h['annual_ctc'])} / year · ${fmtInr(h['monthly_ctc'])} / month', style: AppTextStyles.bodySmall),
        Text('Structure: $structure', style: caption),
        Text('Saved by ${_s(h['created_by_name']).isEmpty ? '—' : _s(h['created_by_name'])}', style: caption),
        if (comps.isEmpty)
          Text('From structure', style: caption)
        else
          // Web <details>: "N components", tap to show each enabled one.
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              key: Key('salary-components-${h['id']}'),
              onTap: () => setState(
                  () => _expanded.contains(_s(h['id'])) ? _expanded.remove(_s(h['id'])) : _expanded.add(_s(h['id']))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_expanded.contains(_s(h['id'])) ? Icons.expand_more : Icons.chevron_right, size: 16),
                  Text('${comps.length} components', style: caption),
                ]),
              ),
            ),
            if (_expanded.contains(_s(h['id'])))
              for (final c in comps)
                Row(children: [
                  Expanded(
                    child:
                        Text('${c['name']}${c['component_type'] == 'deduction' ? ' (deduction)' : ''}', style: caption),
                  ),
                  Text('${fmtInr(c['monthly_amount'])}/mo', style: caption),
                ]),
          ]),
      ]),
    );
  }
}

/// Web Assign / Revise CTC modal.
class _CtcSheet extends ConsumerStatefulWidget {
  const _CtcSheet({required this.employeeUuid, required this.current});
  final String employeeUuid;
  final Map<String, dynamic>? current;

  @override
  ConsumerState<_CtcSheet> createState() => _CtcSheetState();
}

class _CtcSheetState extends ConsumerState<_CtcSheet> {
  late final _ctc = TextEditingController(
      text: widget.current == null ? '' : '${(double.tryParse(_s(widget.current!['annual_ctc'])) ?? 0).round()}');
  late String _effective = _iso(DateTime.now());
  late String _structure = _s(widget.current?['salary_structure']);
  bool _saving = false;
  String? _error;

  bool get _revise => widget.current != null;

  @override
  void dispose() {
    _ctc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_ctc.text.isEmpty || _effective.isEmpty) {
      setState(() => _error = 'Annual CTC and Effective From are required.');
      return;
    }
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post(ApiConstants.payrollEmployeeSalary, data: {
        'employee': widget.employeeUuid,
        'annual_ctc': _ctc.text,
        'effective_from': _effective,
        'salary_structure': _structure.isEmpty ? null : _structure,
      });
      if (mounted) Navigator.of(context).pop(_revise ? 'CTC revised successfully.' : 'CTC assigned successfully.');
    } catch (e) {
      if (mounted) setState(() => _error = assetError(e, 'Failed to save.').message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final structures = [
      for (final s in ref.watch(payrollStructuresProvider).valueOrNull ?? const <Map<String, dynamic>>[])
        if (s['is_active'] == true) s,
    ];
    final title = _revise ? 'Revise CTC' : 'Assign CTC';
    final ctc = double.tryParse(_ctc.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
          child: Row(children: [
            Expanded(
                child: Text(title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 16))),
            IconButton(
                tooltip: 'Close',
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close)),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_error != null)
                Container(
                  key: const Key('ctc-error'),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                ),
              TextField(
                key: const Key('ctc-annual'),
                controller: _ctc,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Annual CTC (₹) *',
                    hintText: 'e.g. 600000',
                    isDense: true,
                    border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
              if (ctc != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Monthly: ${fmtInr((ctc / 12).round())}',
                      key: const Key('ctc-monthly-preview'), style: AppTextStyles.caption.copyWith(fontSize: 12)),
                ),
              const SizedBox(height: 12),
              InkWell(
                key: const Key('ctc-effective'),
                onTap: () async {
                  final picked = await ref.read(salaryDatePickerProvider)(
                      context, DateTime.tryParse(_effective) ?? DateTime.now());
                  if (picked != null && mounted) setState(() => _effective = _iso(picked));
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Effective From *',
                      isDense: true,
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.event, size: 18)),
                  child: Text(_effective.isEmpty ? '—' : _effective, style: AppTextStyles.bodySmall),
                ),
              ),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: const Key('ctc-structure'),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('structures-${structures.length}'),
                  initialValue: structures.any((s) => _s(s['id']) == _structure) ? _structure : '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Salary Structure (optional)', isDense: true, border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('— Use company default —')),
                    for (final s in structures)
                      DropdownMenuItem(
                          value: _s(s['id']),
                          child: Text('${s['name']}${s['is_default'] == true ? ' (Default)' : ''}')),
                  ],
                  onChanged: _saving ? null : (v) => setState(() => _structure = v ?? ''),
                ),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('ctc-save'),
                onPressed: _saving || _ctc.text.isEmpty || _effective.isEmpty ? null : _save,
                child: Text(_saving ? 'Saving…' : title),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Payroll ───────────────────────────────────────────────────────────────────

/// Web PayrollTab STATUS_LABEL.
const kEmployeePayslipStatusLabel = {
  'draft': 'Processing',
  'sent': 'Sent',
  'acknowledged': 'Acknowledged',
  'queried': 'Query Raised',
  'resolved': 'Query Resolved',
  'paid': 'Paid',
};

class EmployeePayrollTab extends ConsumerWidget {
  const EmployeePayrollTab({super.key, required this.employee});
  final EmployeeModel employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uuid = employee.uuid ?? '';
    final async = ref.watch(employeePayslipHistoryProvider(uuid));
    final caption = AppTextStyles.caption.copyWith(fontSize: 12);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(employeePayslipHistoryProvider(uuid).future).then((_) {}, onError: (_) {}),
      child: ListView(
        key: const Key('employee-payroll-tab'),
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            title: 'Payslip History',
            child: async.when(
              loading: () => const Center(child: Text('Loading…')),
              error: (e, _) =>
                  _loadError(e, () => ref.invalidate(employeePayslipHistoryProvider(uuid)), 'payroll-error'),
              data: (payslips) => payslips.isEmpty
                  ? Column(key: const Key('payroll-empty'), children: [
                      Icon(Icons.receipt_long_outlined, color: AppColors.textHint),
                      Text('No payslips yet', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                      Text('Payslips will appear here once payroll has been processed for this employee.',
                          textAlign: TextAlign.center, style: caption),
                    ])
                  : Column(children: [for (final p in payslips) _row(context, ref, p)]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Map<String, dynamic> p) {
    final caption = AppTextStyles.caption.copyWith(fontSize: 12);
    final status = _s(p['status']);
    final color = switch (status) {
      'paid' => AppColors.success,
      'queried' => AppColors.warning,
      'draft' => AppColors.textSecondary,
      _ => AppColors.info,
    };
    final pdf = _s(p['payslip_pdf']);
    final structure = _s(p['structure_name']);
    return Container(
      key: Key('payslip-row-${p['id']}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(fmtPayMonth(_s(p['cycle_start'])),
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(kEmployeePayslipStatusLabel[status] ?? status,
                key: Key('payslip-status-${p['id']}'), style: AppTextStyles.caption.copyWith(color: color)),
          ),
        ]),
        Text('Pay date ${fmtAssetDate(_s(p['pay_date']))} · ${structure.isEmpty ? 'Default' : structure}',
            style: caption),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: Text('Gross ${fmtInr(p['gross_earnings'])}', style: caption)),
          Expanded(child: Text('Deductions ${fmtInr(p['total_deductions'])}', style: caption)),
          Text('Net ${fmtInr(p['net_pay'])}',
              key: Key('payslip-net-${p['id']}'), style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
        ]),
        Align(
          alignment: Alignment.centerRight,
          child: pdf.isNotEmpty
              // Web: a plain link opening in a new tab (Task 67 helper).
              ? TextButton.icon(
                  key: Key('payslip-download-${p['id']}'),
                  onPressed: () => openDocumentLinkExternally(context, ref, pdf),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download'),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Not available', key: Key('payslip-na-${p['id']}'), style: caption),
                ),
        ),
      ]),
    );
  }
}
