import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../my_requests/presentation/providers/my_requests_providers.dart' show myRequestsProvider;
import '../../domain/entities/leave_entity.dart';
import '../providers/leave_providers.dart';

// Cancelling an APPROVED leave — web leave/_components/LeaveCancellationPanel
// .tsx (inside the leave detail) and approvals/_components/
// LeaveCancellationsSection.tsx (Approvals → Leave Cancellations), over
// backend hrms views/leave_cancellation.py:
//  - POST /leave/requests/<id>/cancellation/ {reason}: the employee, for their
//    own approved leave that hasn't started, none already waiting; reason at
//    least 5 characters. The leave stays approved until decided.
//  - POST /leave/requests/<id>/cancellation/decision/ {action: approve|reject,
//    remarks}: the leave's final approver (never the employee); remarks
//    required to reject. Approving cancels the leave and the server returns
//    the days to the balance; rejecting keeps it approved.
//  - GET /leave/cancellations/: the requests this user may decide ([] without
//    leave.approve).
// Who may act comes from the server (can_request_cancellation /
// can_decide_cancellation); balances are never computed here — everything
// affected is reloaded after a change.

/// Web approvalWorkflows.cancellationReasonError.
String? cancellationReasonError(String reason) =>
    reason.trim().length < 5 ? 'Give a reason (at least 5 characters).' : null;

/// Web approvalWorkflows.rejectRemarksError.
String? rejectRemarksError(String remarks) =>
    remarks.trim().isEmpty ? 'Give a reason for rejecting — it is shown to the employee.' : null;

/// Web approvalWorkflows.cancellationBadge: (label, color) or null.
(String, Color)? cancellationBadge(String status) => switch (status) {
      'requested' => ('Cancellation pending', AppColors.warning),
      'approved' => ('Cancellation approved', AppColors.success),
      'rejected' => ('Cancellation rejected', AppColors.error),
      _ => null,
    };

/// Web apiMessage: the server's `message`, else [fallback].
String cancellationApiMessage(Object e, String fallback) {
  if (e is DioException) {
    final body = e.response?.data;
    final m = body is Map ? body['message'] : null;
    if (m is String && m.trim().isNotEmpty) return m;
  }
  return fallback;
}

/// Web approvals/page.tsx: Leave Cancellations for usePermission("leave.approve")
/// (superuser flag or the permission — not settings.edit by itself), when the
/// company has the leave module (the API refuses it otherwise).
bool canReviewLeaveCancellations(UserEntity? user) =>
    user != null &&
    (user.isSuperuser || user.permissions.contains('leave.approve')) &&
    user.hasModule('leave');

/// GET /leave/cancellations/.
final leaveCancellationsProvider = FutureProvider.autoDispose<List<LeaveRequestEntity>>(
  (ref) => ref.read(leaveDataSourceProvider).fetchCancellations(),
);

/// After a request or decision: reload everything that shows this leave, its
/// status or the balance — the server did the accounting.
void refreshAfterCancellationChange(WidgetRef ref, String leaveId) {
  ref.invalidate(leaveRequestDetailProvider(leaveId));
  ref.invalidate(leaveRequestsProvider);
  ref.invalidate(leaveBalancesProvider);
  ref.invalidate(leaveStatsProvider);
  ref.invalidate(leaveTeamPendingProvider);
  ref.invalidate(leaveTeamHistoryProvider);
  ref.invalidate(leaveCalendarProvider);
  ref.invalidate(employeeLeaveRequestsProvider);
  ref.invalidate(employeeLeaveStatsProvider);
  ref.invalidate(leaveCancellationsProvider);
  ref.invalidate(myRequestsProvider);
}

// ── In the leave detail ─────────────────────────────────────────────────────

/// Web LeaveCancellationPanel: shown when the leave has a cancellation status
/// or the viewer may request one.
class LeaveCancellationPanel extends ConsumerStatefulWidget {
  const LeaveCancellationPanel({super.key, required this.request});
  final LeaveRequestEntity request;

  @override
  ConsumerState<LeaveCancellationPanel> createState() => _LeaveCancellationPanelState();
}

enum _Mode { none, request, reject }

class _LeaveCancellationPanelState extends ConsumerState<LeaveCancellationPanel> {
  _Mode _mode = _Mode.none;
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _start(_Mode m) => setState(() {
        _mode = m;
        _text.clear();
        _error = null;
      });

  Future<void> _submit(String action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ds = ref.read(leaveDataSourceProvider);
    final id = widget.request.id;
    try {
      if (action == 'request') {
        await ds.requestCancellation(id, _text.text);
      } else {
        await ds.decideCancellation(id, approve: action == 'approve', remarks: _text.text);
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _mode = _Mode.none;
        _text.clear();
      });
      refreshAfterCancellationChange(ref, id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = cancellationApiMessage(e, 'Something went wrong. Please try again.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final badge = cancellationBadge(r.cancellationStatus);
    if (badge == null && !r.canRequestCancellation) return const SizedBox.shrink();
    final inputError = switch (_mode) {
      _Mode.request => cancellationReasonError(_text.text),
      _Mode.reject => rejectRemarksError(_text.text),
      _Mode.none => null,
    };
    final caption = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary);

    return Column(
      key: const Key('leave-cancellation-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Text('CANCELLATION',
                style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textSecondary)),
          ),
          if (badge != null)
            Container(
              key: const Key('leave-cancellation-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badge.$2.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(badge.$1, style: AppTextStyles.caption.copyWith(color: badge.$2, fontWeight: FontWeight.w600)),
            ),
        ]),
        if (r.cancellationReason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Reason: “${r.cancellationReason}”', style: caption),
          ),
        if (r.cancellationRemarks.isNotEmpty && r.cancellationStatus != 'requested')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Decision note: “${r.cancellationRemarks}”', style: caption),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!,
                key: const Key('leave-cancellation-error'),
                style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
        if (_mode == _Mode.none && (r.canRequestCancellation || r.canDecideCancellation))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 6, children: [
              if (r.canRequestCancellation)
                OutlinedButton.icon(
                  key: const Key('leave-cancellation-request'),
                  onPressed: () => _start(_Mode.request),
                  icon: const Icon(Icons.event_busy_outlined, size: 16),
                  label: const Text('Request cancellation'),
                ),
              if (r.canDecideCancellation) ...[
                OutlinedButton(
                  key: const Key('leave-cancellation-reject'),
                  onPressed: _busy ? null : () => _start(_Mode.reject),
                  child: const Text('Reject cancellation'),
                ),
                FilledButton(
                  key: const Key('leave-cancellation-approve'),
                  onPressed: _busy ? null : () => _submit('approve'),
                  child: const Text('Approve cancellation'),
                ),
              ],
            ]),
          ),
        if (_mode != _Mode.none) ...[
          const SizedBox(height: 10),
          Text(_mode == _Mode.request ? 'Why do you want to cancel this leave? *' : 'Reason for rejecting *',
              style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextField(
            key: const Key('leave-cancellation-text'),
            controller: _text,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          // Web shows the rule only once something is typed.
          if (_text.text.isNotEmpty && inputError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(inputError,
                  key: const Key('leave-cancellation-input-error'),
                  style: AppTextStyles.caption.copyWith(color: AppColors.error)),
            ),
          if (_mode == _Mode.request)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'The leave stays approved until your approver accepts the cancellation; '
                'the days then return to your balance.',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
            ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
              key: const Key('leave-cancellation-back'),
              onPressed: _busy ? null : () => setState(() => _mode = _Mode.none),
              child: const Text('Back'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('leave-cancellation-submit'),
              onPressed: _busy || inputError != null ? null : () => _submit(_mode == _Mode.request ? 'request' : 'reject'),
              child: Text(_busy ? 'Saving…' : (_mode == _Mode.request ? 'Send request' : 'Reject')),
            ),
          ]),
        ],
      ],
    );
  }
}

// ── Approvals → Leave Cancellations ─────────────────────────────────────────

String _fmtDay(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// Web LeaveCancellationsSection.
class LeaveCancellationsTab extends ConsumerStatefulWidget {
  const LeaveCancellationsTab({super.key});

  @override
  ConsumerState<LeaveCancellationsTab> createState() => _LeaveCancellationsTabState();
}

class _LeaveCancellationsTabState extends ConsumerState<LeaveCancellationsTab> {
  String? _rejecting;
  final _remarks = TextEditingController();
  String? _busy;
  (bool, String)? _msg;

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _decide(LeaveRequestEntity r, bool approve) async {
    if (!approve && rejectRemarksError(_remarks.text) != null) return;
    if (approve) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('leave-cancellation-confirm'),
          content: Text("Cancel ${r.employee}'s approved leave and return the days?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      _busy = r.id;
      _msg = null;
    });
    try {
      await ref.read(leaveDataSourceProvider).decideCancellation(r.id, approve: approve, remarks: _remarks.text);
      if (!mounted) return;
      setState(() {
        _msg = (true, approve ? 'Leave cancelled and balance restored.' : 'Cancellation rejected.');
        _rejecting = null;
        _remarks.clear();
      });
      refreshAfterCancellationChange(ref, r.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = (false, cancellationApiMessage(e, 'Failed to save the decision.')));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(leaveCancellationsProvider);
    final rows = async.valueOrNull ?? const <LeaveRequestEntity>[];
    return RefreshIndicator(
      onRefresh: () => ref.refresh(leaveCancellationsProvider.future),
      child: ListView(
        key: const Key('leave-cancellations'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text('Leave cancellation requests', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Approved leave the employee wants to cancel before it starts.',
              style: AppTextStyles.caption.copyWith(fontSize: 12)),
          const SizedBox(height: 12),
          if (_msg != null)
            Container(
              key: const Key('leave-cancellations-msg'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_msg!.$1 ? AppColors.success : AppColors.error).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_msg!.$2,
                  style: AppTextStyles.caption.copyWith(color: _msg!.$1 ? AppColors.success : AppColors.error)),
            ),
          if (async.isLoading)
            Text('Loading…', style: AppTextStyles.caption.copyWith(fontSize: 13))
          else if (async.hasError)
            Column(key: const Key('leave-cancellations-error'), crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cancellationApiMessage(async.error!, 'Could not load cancellation requests.'),
                  style: AppTextStyles.caption.copyWith(color: AppColors.error)),
              TextButton(
                key: const Key('leave-cancellations-retry'),
                onPressed: () => ref.invalidate(leaveCancellationsProvider),
                child: const Text('Retry'),
              ),
            ])
          else if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No cancellation requests waiting for you.', style: AppTextStyles.caption.copyWith(fontSize: 13)),
            ),
          if (!async.isLoading && !async.hasError)
            for (final r in rows) _row(r),
        ],
      ),
    );
  }

  Widget _row(LeaveRequestEntity r) {
    final busy = _busy == r.id;
    return Container(
      key: Key('leave-cancellation-row-${r.id}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: r.employee, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (r.employeeCode.isNotEmpty)
            TextSpan(text: ' (${r.employeeCode})', style: TextStyle(color: AppColors.textSecondary)),
        ]), style: AppTextStyles.body.copyWith(fontSize: 13)),
        Text('${r.leaveType} · ${_fmtDay(r.from)} – ${_fmtDay(r.to)} · ${r.days} day(s)',
            style: AppTextStyles.caption.copyWith(fontSize: 12)),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Reason: “${r.cancellationReason}”', style: AppTextStyles.bodySmall),
        ),
        if (_rejecting != r.id)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                key: Key('leave-cancellation-row-reject-${r.id}'),
                onPressed: busy
                    ? null
                    : () => setState(() {
                          _rejecting = r.id;
                          _remarks.clear();
                        }),
                child: const Text('Reject'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: Key('leave-cancellation-row-approve-${r.id}'),
                onPressed: busy ? null : () => _decide(r, true),
                child: const Text('Approve cancellation'),
              ),
            ]),
          )
        else ...[
          const SizedBox(height: 10),
          Text('Reason for rejecting *', style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextField(
            key: Key('leave-cancellation-row-remarks-${r.id}'),
            controller: _remarks,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => setState(() => _rejecting = null), child: const Text('Back')),
            const SizedBox(width: 8),
            FilledButton(
              key: Key('leave-cancellation-row-confirm-reject-${r.id}'),
              onPressed: busy || rejectRemarksError(_remarks.text) != null ? null : () => _decide(r, false),
              child: const Text('Reject cancellation'),
            ),
          ]),
        ],
      ]),
    );
  }
}
