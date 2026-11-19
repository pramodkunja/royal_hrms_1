import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart' show dioProvider;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/approval_workflows.dart';
import '../providers/approvals_providers.dart' show unifiedTeamApprovalsProvider;
import '../../../../shared/formatters/en_in_format.dart';
import 'approvals_kit.dart';
import 'approvals_ui.dart';

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
  bool _confirming = false;
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
    if (_revoking.contains(d.id) || _confirming) return;
    _confirming = true;
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
    _confirming = false;
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Delegate my approvals', style: AppTextStyles.h4),
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
                      value: p.id,
                      child: Text(p.employeeId.isNotEmpty ? '${p.name} (${p.employeeId})' : p.name,
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _form = _form.copyWith(delegate: v ?? '')),
            ),
          ),
          ..._err(errors, 'delegate'),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final from = _dateField('From *', _form.startDate, 'delegation-start', () => _pickDate(true));
            final to = _dateField('To *', _form.endDate, 'delegation-end', () => _pickDate(false));
            final stacked = c.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
            if (stacked) return Column(children: [from, const SizedBox(height: 12), to]);
            return Row(children: [Expanded(child: from), const SizedBox(width: 10), Expanded(child: to)]);
          }),
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
          Wrap(spacing: 8, runSpacing: 8, children: [
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
              style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
              child: Text(_saving ? 'Saving…' : 'Delegate'),
            ),
          ),
            ]),
          ),
          const SizedBox(height: 16),
          ...rowsAsync.when(
            loading: () => [const ApprovalsLoading(label: 'Loading delegations…')],
            error: (e, _) => [
              ApprovalsEmptyState.forError(e,
                  key: const Key('delegations-load-error'), compact: true, onRetry: () => ref.invalidate(delegationsProvider)),
            ],
            data: (rows) => [
              _heading('Delegated by me'),
              ..._list(rows.where((d) => d.given).toList(), true, "You haven't delegated your approvals.", today),
              const SizedBox(height: 14),
              _heading('Delegated to me'),
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
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(text, style: AppTextStyles.label.copyWith(color: color)),
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

  Widget _heading(String t) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 2),
        child: Text(t, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
      );

  List<Widget> _list(List<Delegation> list, bool given, String empty, String today) {
    if (list.isEmpty) {
      return [
        // A quiet inline block: two of these sit on one screen under the form, so the
        // full-height illustration of ApprovalsEmptyState would drown the page.
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            ApprovalsIconBox(given ? Icons.outbox_outlined : Icons.move_to_inbox_outlined, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(given ? 'No delegations given' : 'No delegations received',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(empty, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ]),
            ),
          ]),
        ),
      ];
    }
    String day(String iso) {
      final d = DateTime.tryParse(iso);
      return d == null ? iso : formatEnInDate(d);
    }

    return [
      for (final d in list)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: ApprovalsCardShell(
            key: Key('delegation-row-${d.id}'),
            name: given ? d.delegate.name : d.delegator.name,
            idText: (given ? d.delegate.employeeId : d.delegator.employeeId).isEmpty
                ? null
                : (given ? d.delegate.employeeId : d.delegator.employeeId),
            badge: _stateBadge(delegationState(d, today), d.id),
            footer: d.canRevoke
                ? Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      key: Key('delegation-revoke-${d.id}'),
                      onPressed: _revoking.contains(d.id) ? null : () => _revoke(d),
                      icon: const Icon(Icons.block_outlined, size: 16),
                      label: const Text('Revoke'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ApprovalsHeadline(
                icon: Icons.swap_horiz_rounded,
                title: given ? '${d.delegate.name} covers for you' : 'You cover for ${d.delegator.name}',
                chips: [for (final w in d.workflows) ApprovalsChip(kWorkflowLabel[w] ?? w)],
              ),
              const SizedBox(height: 12),
              ApprovalsInfoRow(Icons.date_range_outlined, '${day(d.startDate)} – ${day(d.endDate)}', strong: true),
              if (d.reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                ApprovalsQuote(d.reason, maxLines: 3),
              ],
            ]),
          ),
        ),
    ];
  }

  Widget _stateBadge(String state, String id) {
    final tone = switch (state) {
      'active' => ApprovalsTone.success,
      'scheduled' => ApprovalsTone.info,
      'revoked' => ApprovalsTone.error,
      _ => ApprovalsTone.neutral,
    };
    return KeyedSubtree(
      key: Key('delegation-state-$id'),
      child: ApprovalsBadge(kDelegationStateLabel[state] ?? state, tone),
    );
  }
}
