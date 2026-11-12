import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart' show dioProvider;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../employees/presentation/widgets/employee_file_viewer.dart' show openEmployeeFileInApp;
import '../../domain/entities/attendance_entity.dart';
import '../providers/attendance_providers.dart';
import 'late_justification.dart' show fmtLateDate, lateStatusBadge;

// Reviewing a late-arrival justification — web attendance/_components/
// LateJustificationReviewModal.tsx and LateJustificationsTab.tsx over backend
// attendance services_hr_corrections.py (same queue and review endpoint as
// punch corrections):
//  - GET /attendance/corrections/?kind=late_justification[&status=…]
//    [&missing_proof=true] (attendance.view; branch / manager scope applied
//    by the server).
//  - PATCH /attendance/corrections/<id>/review/ {action: approve | reject |
//    resubmit, remarks} (attendance.create). The server decides who may act
//    at which stage (can_action: the Manager at L1, HR at L2; never on one's
//    own request); a reason is required to reject or send back.
//  - Approval at L1 with an L2 configured moves it to HR; the final approval
//    marks the day "Late (Excused)" (no punches change). A rejection is final;
//    "resubmit" lets the employee edit and resubmit within 3 days.
//  - Proof: only when the server says this user may see it
//    (can_view_document — medical-proof access); streamed by the API.

/// Web reviewTrail: "Manager (Name) rejected: reason", "HR (Name) approved".
List<String> lateReviewTrail(HrCorrectionRowEntity r) {
  String verb(String? s) => switch (s) {
        'approved' => 'approved',
        'rejected' => 'rejected',
        'resubmit' => 'asked to resubmit',
        _ => '',
      };
  String who(String level, String? name) => (name ?? '').isNotEmpty ? '$level ($name)' : level;
  return [
    if (r.l1Status != null) '${who('Manager', r.l1ApproverName)} ${verb(r.l1Status)}${r.l1Remarks.isNotEmpty ? ': ${r.l1Remarks}' : ''}',
    if (r.l2Status != null) '${who('HR', r.l2ApproverName)} ${verb(r.l2Status)}${r.l2Remarks.isNotEmpty ? ': ${r.l2Remarks}' : ''}',
  ];
}

/// Requests with a decision being sent — one at a time per request, so a
/// second tap (or a second screen) can't send another decision.
final _inFlight = <String>{};

/// Opens the review for [row]. Returns the server's message after a
/// decision, or null when closed without one.
Future<String?> showLateJustificationReview(BuildContext context, HrCorrectionRowEntity row) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LateJustificationReviewSheet(row: row),
    );

class LateJustificationReviewSheet extends ConsumerStatefulWidget {
  const LateJustificationReviewSheet({super.key, required this.row});
  final HrCorrectionRowEntity row;

  @override
  ConsumerState<LateJustificationReviewSheet> createState() => _LateJustificationReviewSheetState();
}

class _LateJustificationReviewSheetState extends ConsumerState<LateJustificationReviewSheet> {
  String? _action; // approve | reject | resubmit
  final _remarks = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _opening = false;

  bool get _needsReason => _action == 'reject' || _action == 'resubmit';

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final r = widget.row;
    if (_action == null || _busy) return;
    if (_needsReason && _remarks.text.trim().isEmpty) {
      setState(() => _error = 'Give a reason — it is shown to the employee.');
      return;
    }
    if (!_inFlight.add(r.id)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await ref
          .read(attendanceDataSourceProvider)
          .reviewLateJustification(r.id, action: _action!, remarks: _needsReason ? _remarks.text : '');
      ref.invalidate(hrCorrectionsProvider);
      ref.invalidate(lateJustificationQueueProvider);
      ref.invalidate(attendanceRecordCorrectionsProvider);
      ref.invalidate(attendanceRecordsProvider);
      ref.invalidate(attendanceDashboardProvider);
      if (mounted) Navigator.of(context).pop(msg);
    } catch (e) {
      if (!mounted) return;
      String message = 'Could not save the decision.';
      if (e is DioException) {
        final body = e.response?.data;
        if (body is Map && body['message'] is String && (body['message'] as String).isNotEmpty) {
          message = body['message'] as String;
        }
      }
      setState(() {
        _busy = false;
        _error = message;
      });
    } finally {
      _inFlight.remove(r.id);
    }
  }

  Future<void> _viewProof() async {
    final r = widget.row;
    if (_opening) return;
    setState(() => _opening = true);
    final message = await openEmployeeFileInApp(
      context,
      ref,
      id: r.id.hashCode,
      url: '${ref.read(dioProvider).options.baseUrl}${ApiConstants.attendanceCorrectionDocument(r.id)}',
      fileName: r.documentName,
      title: 'Proof — ${r.name}, ${fmtLateDate(r.date, withWeekday: true)}',
    );
    if (!mounted) return;
    setState(() {
      _opening = false;
      if (message != null) _error = message;
    });
  }

  Widget _row(String label, Widget value) => Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12))),
          Expanded(child: DefaultTextStyle.merge(style: AppTextStyles.bodySmall, child: value)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final badge = r.status == 'approved' ? ('Approved — Late (Excused)', AppColors.success) : lateStatusBadge(r.status);
    final trail = lateReviewTrail(r);
    final caption = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary);

    final Widget proof = r.hasDocument
        ? (r.canViewDocument
            ? Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('late-review-proof'),
                  onPressed: _opening ? null : _viewProof,
                  icon: _opening
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.description_outlined, size: 16),
                  label: Text('View ${r.documentName.isNotEmpty ? r.documentName : 'proof'}'),
                ),
              )
            : Row(key: const Key('late-review-proof-locked'), children: [
                Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text('Attached — visible to authorised HR only', style: caption)),
              ]))
        : Text(r.proofRequired ? 'Missing (required for medical)' : 'None',
            style: AppTextStyles.bodySmall.copyWith(color: r.proofRequired ? AppColors.error : AppColors.textSecondary));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          child: Row(children: [
            Expanded(
              child: Text('Late arrival justification',
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_error != null)
                Container(
                  key: const Key('late-review-error'),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                ),
              _row(
                  'Employee',
                  Text.rich(TextSpan(children: [
                    TextSpan(text: r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: '  ${r.employeeId} · ${r.branch.isEmpty ? '—' : r.branch}',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ]))),
              _row('Date', Text(fmtLateDate(r.date, withWeekday: true))),
              _row('Recorded punches',
                  Text('${r.originalIn ?? '—'} → ${r.originalOut ?? '—'}', style: const TextStyle(fontFamily: 'monospace'))),
              _row('Attendance', Text(r.attendanceStatus ?? '—')),
              _row('Reason', Text(r.reasonLabel.isEmpty ? r.reason : r.reasonLabel, style: const TextStyle(fontWeight: FontWeight.w700))),
              _row('Explanation', Text(r.explanation)),
              _row('Proof', proof),
              _row(
                  'Status',
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      key: const Key('late-review-status'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration:
                          BoxDecoration(color: badge.$2.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Text(badge.$1,
                          style: AppTextStyles.caption.copyWith(color: badge.$2, fontWeight: FontWeight.w600)),
                    ),
                  )),
              if (r.resubmissionCount > 0) _row('Resubmissions', Text('${r.resubmissionCount}')),
              if (trail.isNotEmpty)
                _row('Decisions', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final t in trail) Text(t)])),
              if (_action == 'approve')
                Container(
                  key: const Key('late-review-approve-note'),
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    r.status == 'pending' && (r.l2ApproverName ?? '').isNotEmpty
                        ? 'Your approval sends this to HR. The day is excused only after the final approval.'
                        : "The day will show as Late (Excused) and won't count as a late mark. Punch times stay as recorded.",
                    style: AppTextStyles.caption.copyWith(color: AppColors.info),
                  ),
                ),
              if (_needsReason) ...[
                const SizedBox(height: 12),
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: _action == 'reject' ? 'Reason for rejecting' : 'What should the employee change?',
                      style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600)),
                  TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
                ])),
                const SizedBox(height: 4),
                TextField(
                  key: const Key('late-review-remarks'),
                  controller: _remarks,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: _action == 'resubmit' ? "e.g. Upload the doctor's note, not the pharmacy bill" : null,
                    isDense: true,
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                Text(
                  _action == 'resubmit'
                      ? 'The employee can update and resubmit within 3 days.'
                      : 'This is final; the day stays an ordinary late mark.',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: !r.canAction
              ? FilledButton(
                  key: const Key('late-review-close'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                )
              : _action != null
                  ? Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('late-review-back'),
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _action = null;
                                    _error = null;
                                  }),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('late-review-send'),
                          onPressed: _busy ? null : _send,
                          child: Text(_busy
                              ? 'Saving…'
                              : switch (_action) {
                                  'approve' => 'Confirm approval',
                                  'reject' => 'Reject',
                                  _ => 'Send back',
                                }),
                        ),
                      ),
                    ])
                  : Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 6, children: [
                      OutlinedButton.icon(
                        key: const Key('late-review-resubmit'),
                        onPressed: () => setState(() => _action = 'resubmit'),
                        icon: const Icon(Icons.undo, size: 16),
                        label: const Text('Request resubmission'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('late-review-reject'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                        onPressed: () => setState(() => _action = 'reject'),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                      ),
                      FilledButton.icon(
                        key: const Key('late-review-approve'),
                        onPressed: () => setState(() => _action = 'approve'),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve'),
                      ),
                    ]),
        ),
      ]),
    );
  }
}

// ── HR Attendance → Late Justifications ─────────────────────────────────────

/// Web LateJustificationsTab FILTERS (key, label); "Pending" covers both
/// stages, "Missing Proof" asks the server for missing_proof.
const kLateReviewFilters = <(String, String)>[
  ('', 'All'),
  ('pending', 'Pending'),
  ('approved', 'Approved'),
  ('rejected', 'Rejected'),
  ('resubmit', 'Resubmission Required'),
  ('missing', 'Missing Proof'),
];

/// GET /attendance/corrections/?kind=late_justification with web's query for
/// [filter].
final lateJustificationQueueProvider =
    FutureProvider.autoDispose.family<List<HrCorrectionRowEntity>, String>((ref, filter) async {
  final rows = await ref.read(attendanceDataSourceProvider).fetchHrCorrections(
        kind: 'late_justification',
        status: filter == 'missing' || filter == 'pending' ? null : filter,
        missingProof: filter == 'missing',
      );
  // Web: "Pending" covers both stages (manager and HR).
  return filter == 'pending' ? rows.where((r) => r.status == 'pending' || r.status == 'l2_pending').toList() : rows;
});

class LateJustificationsReviewTab extends ConsumerStatefulWidget {
  const LateJustificationsReviewTab({super.key});

  @override
  ConsumerState<LateJustificationsReviewTab> createState() => _LateJustificationsReviewTabState();
}

class _LateJustificationsReviewTabState extends ConsumerState<LateJustificationsReviewTab> {
  String _filter = 'pending'; // web default
  String? _notice;

  Future<void> _open(HrCorrectionRowEntity r) async {
    setState(() => _notice = null);
    final msg = await showLateJustificationReview(context, r);
    if (msg == null || !mounted) return;
    setState(() => _notice = msg);
    ref.invalidate(lateJustificationQueueProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lateJustificationQueueProvider(_filter));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(lateJustificationQueueProvider(_filter).future),
      child: ListView(
        key: const Key('late-review-tab'),
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Icon(Icons.help_outline, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('Late Arrival Justifications', style: AppTextStyles.h4)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (key, label) in kLateReviewFilters)
              ChoiceChip(
                key: Key('late-filter-${key.isEmpty ? 'all' : key}'),
                label: Text(label, style: const TextStyle(fontSize: 12)),
                selected: _filter == key,
                onSelected: (_) => setState(() => _filter = key),
              ),
          ]),
          if (_notice != null)
            Container(
              key: const Key('late-review-notice'),
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Text(_notice!, style: AppTextStyles.caption.copyWith(color: AppColors.success)),
            ),
          const SizedBox(height: 8),
          ...async.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ],
            error: (e, _) => [
              Column(key: const Key('late-review-load-error'), children: [
                Text(friendlyAttendanceError(e), style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                TextButton(
                  key: const Key('late-review-retry'),
                  onPressed: () => ref.invalidate(lateJustificationQueueProvider(_filter)),
                  child: const Text('Retry'),
                ),
              ]),
            ],
            data: (rows) => rows.isEmpty
                ? [
                    Padding(
                      key: const Key('late-review-empty'),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(children: [
                        Icon(Icons.help_outline, size: 26, color: AppColors.textHint),
                        const SizedBox(height: 6),
                        Text('No requests', style: AppTextStyles.label),
                        Text('Nothing matches this filter.', style: AppTextStyles.caption),
                      ]),
                    ),
                  ]
                : [for (final r in rows) _rowCard(r)],
          ),
        ],
      ),
    );
  }

  Widget _rowCard(HrCorrectionRowEntity r) {
    final badge = lateStatusBadge(r.status);
    final (proofText, proofColor) = r.hasDocument
        ? (r.canViewDocument ? 'Attached' : 'Attached (locked)', AppColors.textSecondary)
        : (r.proofRequired ? 'Missing' : 'None', r.proofRequired ? AppColors.error : AppColors.textSecondary);
    return InkWell(
      key: Key('late-review-row-${r.id}'),
      onTap: () => _open(r),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r.name, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: badge.$2.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Text(badge.$1, style: AppTextStyles.caption.copyWith(color: badge.$2, fontWeight: FontWeight.w600)),
            ),
          ]),
          Text('${r.employeeId} · ${r.branch.isEmpty ? '—' : r.branch}', style: AppTextStyles.caption.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Text('${fmtLateDate(r.date)} · clock-in ${r.originalIn ?? '—'}', style: AppTextStyles.bodySmall),
          Text(r.reasonLabel.isEmpty ? r.reason : r.reasonLabel, style: AppTextStyles.bodySmall),
          if (r.explanation.isNotEmpty)
            Text(r.explanation, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(fontSize: 11)),
          const SizedBox(height: 6),
          Row(children: [
            Text('Proof: $proofText', style: AppTextStyles.caption.copyWith(fontSize: 11, color: proofColor)),
            const Spacer(),
            r.canAction
                ? FilledButton(
                    key: Key('late-review-open-${r.id}'),
                    onPressed: () => _open(r),
                    child: const Text('Review'),
                  )
                : OutlinedButton(
                    key: Key('late-review-open-${r.id}'),
                    onPressed: () => _open(r),
                    child: const Text('View'),
                  ),
          ]),
        ]),
      ),
    );
  }
}
