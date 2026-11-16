import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart' show dioProvider;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/approval_workflows.dart';
import '../providers/approvals_providers.dart' show unifiedTeamApprovalsProvider;

// Approvals → Delegation — web approvals/_components/DelegationsSection.tsx:
// hand my leave / attendance approvals to a colleague for a period. The
// delegate acts on requests waiting for me at either stage (the server adds
// them to the delegate's queues with can_action); I keep my own access.
// Create and revoke only (web has no edit). Everything is re-checked by the
// server: same branch (or a company-wide approver), the delegate must
// approve the same workflow, up to 180 days, no overlapping delegation.

final approvalWorkflowsApiProvider =
    Provider<ApprovalWorkflowsApi>((ref) => ApprovalWorkflowsApi(ref.watch(dioProvider)));

/// "Today" for the form and the state badges (replaceable in tests).
final approvalsTodayProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final delegationsProvider =
    FutureProvider.autoDispose<List<Delegation>>((ref) => ref.read(approvalWorkflowsApiProvider).delegations());

/// GET /approvals/delegations/eligible/?workflow=… — who may receive my approvals.
final eligibleDelegatesProvider = FutureProvider.autoDispose.family<List<PersonRef>, String>(
    (ref, workflow) => ref.read(approvalWorkflowsApiProvider).eligibleDelegates(workflow));

/// Opens a date picker (replaceable in tests).
final delegationDatePickerProvider =
    Provider<Future<DateTime?> Function(BuildContext context, DateTime initial, DateTime first, DateTime last)>(
  (ref) => (context, initial, first, last) =>
      showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last),
);

// canDelegateApprovals (who may delegate) lives in core/router/
// access_control.dart: the Approvals route uses the same rule (Task 71g).

class DelegationsTab extends ConsumerStatefulWidget {
  const DelegationsTab({super.key});

  @override
  ConsumerState<DelegationsTab> createState() => _DelegationsTabState();
}

class _DelegationsTabState extends ConsumerState<DelegationsTab> {
  late DelegationForm _form = DelegationForm(startDate: _today);
  final _reason = TextEditingController();
  bool _touched = false;
  bool _saving = false;
  String? _apiError;
  String? _notice;
  final _revoking = <String>{};
  int _generation = 0;

  String get _today => isoDay(ref.read(approvalsTodayProvider)());

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _afterChange() {
    ref.invalidate(delegationsProvider);
    // A delegate's queues change with it.
    ref.invalidate(unifiedTeamApprovalsProvider);
  }

  Future<void> _create() async {
    final errors = validateDelegation(_form, _today);
    setState(() => _touched = true);
    if (errors.isNotEmpty || _saving) return;
    setState(() {
      _saving = true;
      _apiError = null;
      _notice = null;
    });
    try {
      await ref.read(approvalWorkflowsApiProvider).createDelegation(_form);
      if (!mounted) return;
      _reason.clear();
      setState(() {
        _form = DelegationForm(startDate: _today);
        _generation++;
        _touched = false;
        _notice = 'Delegation created. The delegate has been notified.';
      });
      _afterChange();
    } catch (e) {
      if (mounted) setState(() => _apiError = approvalWorkflowError(e, 'Failed to create the delegation.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revoke(Delegation d) async {
    if (_revoking.contains(d.id)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text('Revoke the delegation to ${d.delegate.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
              key: const Key('delegation-revoke-confirm'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Revoke')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _revoking.add(d.id);
      _apiError = null;
      _notice = null;
    });
    try {
      await ref.read(approvalWorkflowsApiProvider).revokeDelegation(d.id);
      if (!mounted) return;
      setState(() => _notice = 'Delegation revoked.');
      _afterChange();
    } catch (e) {
      if (mounted) setState(() => _apiError = approvalWorkflowError(e, 'Failed to revoke the delegation.'));
    } finally {
      if (mounted) setState(() => _revoking.remove(d.id));
    }
  }

  Future<void> _pickDate(bool start) async {
    final today = DateTime.parse(_today);
    final current = start ? _form.startDate : _form.endDate;
    final first = start ? today : (_form.startDate.isNotEmpty ? DateTime.parse(_form.startDate) : today);
    final initial = current.isNotEmpty && !DateTime.parse(current).isBefore(first) ? DateTime.parse(current) : first;
    final picked =
        await ref.read(delegationDatePickerProvider)(context, initial, first, DateTime(today.year + 2, 12, 31));
    if (picked == null || !mounted) return;
    setState(() => _form = start ? _form.copyWith(startDate: isoDay(picked)) : _form.copyWith(endDate: isoDay(picked)));
  }

  List<Widget> _err(Map<String, String> errors, String k) => [
        if (_touched && errors[k] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(errors[k]!,
                key: Key('delegation-error-$k'),
                style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 12)),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final errors = validateDelegation(_form, today);
    final primary = _form.workflows.isNotEmpty ? _form.workflows.first : 'leave';
    final eligible = ref.watch(eligibleDelegatesProvider(primary)).valueOrNull ?? const <PersonRef>[];
    final rowsAsync = ref.watch(delegationsProvider);
    final caption = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary);
    final delegateValue = eligible.any((p) => p.id == _form.delegate) ? _form.delegate : null;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(delegationsProvider);
        ref.invalidate(eligibleDelegatesProvider);
        await ref.read(delegationsProvider.future).then((_) {}, onError: (_) {});
      },
      child: ListView(
        key: const Key('delegations-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('Delegate my approvals', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'While you are away, a colleague in your branch who can approve the same requests acts on requests waiting '
            'for you. You keep your own access. Up to 180 days; one delegation per period.',
            style: caption,
          ),
          const SizedBox(height: 12),
          if (_notice != null) _banner(_notice!, AppColors.success, 'delegation-notice'),
          if (_apiError != null) _banner(_apiError!, AppColors.error, 'delegation-api-error'),
          KeyedSubtree(
            key: const Key('delegation-delegate'),
            child: DropdownButtonFormField<String>(
              // A fresh field after each reset / change of eligible list.
              key: ValueKey('$_generation-$primary-${eligible.length}'),
              initialValue: delegateValue,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Delegate *', isDense: true, border: OutlineInputBorder()),
              hint: const Text('— Select —'),
              items: [
                for (final p in eligible)
                  DropdownMenuItem(
                      value: p.id, child: Text(p.employeeId.isNotEmpty ? '${p.name} (${p.employeeId})' : p.name)),
              ],
              onChanged: (v) => setState(() => _form = _form.copyWith(delegate: v ?? '')),
            ),
          ),
          ..._err(errors, 'delegate'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _dateField('From *', _form.startDate, 'delegation-start', () => _pickDate(true))),
            const SizedBox(width: 10),
            Expanded(child: _dateField('To *', _form.endDate, 'delegation-end', () => _pickDate(false))),
          ]),
          ..._err(errors, 'start_date'),
          ..._err(errors, 'end_date'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('delegation-reason'),
            controller: _reason,
            maxLength: 300,
            decoration: const InputDecoration(
                labelText: 'Reason', hintText: 'e.g. Annual leave', isDense: true, border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _form = _form.copyWith(reason: v)),
          ),
          ..._err(errors, 'reason'),
          Wrap(spacing: 8, children: [
            for (final w in kWorkflows)
              FilterChip(
                key: Key('delegation-workflow-$w'),
                label: Text('${kWorkflowLabel[w]} requests'),
                selected: _form.workflows.contains(w),
                onSelected: (on) => setState(() {
                  final next = on ? {..._form.workflows, w}.toList() : _form.workflows.where((x) => x != w).toList();
                  _form = _form.copyWith(workflows: next);
                }),
              ),
          ]),
          ..._err(errors, 'workflows'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('delegation-create'),
              onPressed: _saving ? null : _create,
              child: Text(_saving ? 'Saving…' : 'Delegate'),
            ),
          ),
          const SizedBox(height: 16),
          ...rowsAsync.when(
            loading: () => [Text('Loading delegations…', style: caption)],
            error: (e, _) => [
              _banner(
                  approvalWorkflowError(e, "Couldn't load delegations."), AppColors.error, 'delegations-load-error'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('delegations-retry'),
                  onPressed: () => ref.invalidate(delegationsProvider),
                  child: const Text('Retry'),
                ),
              ),
            ],
            data: (rows) => [
              Text('Delegated by me', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
              ..._list(rows.where((d) => d.given).toList(), true, "You haven't delegated your approvals.", today),
              const SizedBox(height: 14),
              Text('Delegated to me', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
              ..._list(rows.where((d) => d.received).toList(), false, 'No one has delegated approvals to you.', today),
            ],
          ),
        ],
      ),
    );
  }

  Widget _banner(String text, Color color, String key) => Container(
        key: Key(key),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: AppTextStyles.caption.copyWith(color: color)),
      );

  Widget _dateField(String label, String value, String key, VoidCallback onTap) => InkWell(
        key: Key(key),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.event, size: 18)),
          child: Text(value.isEmpty ? '—' : value, style: AppTextStyles.bodySmall),
        ),
      );

  List<Widget> _list(List<Delegation> list, bool given, String empty, String today) {
    if (list.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(empty, style: AppTextStyles.caption.copyWith(fontSize: 13)),
        ),
      ];
    }
    return [
      for (final d in list)
        Container(
          key: Key('delegation-row-${d.id}'),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(given ? d.delegate.name : d.delegator.name,
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                if (d.reason.isNotEmpty) Text(d.reason, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                Text('${d.startDate} → ${d.endDate}', style: AppTextStyles.caption.copyWith(fontSize: 12)),
                Text(d.workflows.map((w) => kWorkflowLabel[w] ?? w).join(', '),
                    style: AppTextStyles.caption.copyWith(fontSize: 12)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _stateBadge(delegationState(d, today), d.id),
              if (d.canRevoke)
                TextButton(
                  key: Key('delegation-revoke-${d.id}'),
                  onPressed: _revoking.contains(d.id) ? null : () => _revoke(d),
                  child: const Text('Revoke'),
                ),
            ]),
          ]),
        ),
    ];
  }

  Widget _stateBadge(String state, String id) {
    final color = switch (state) {
      'active' => AppColors.success,
      'scheduled' => AppColors.info,
      'revoked' => AppColors.error,
      _ => AppColors.textSecondary,
    };
    return Container(
      key: Key('delegation-state-$id'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(kDelegationStateLabel[state] ?? state,
          style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
