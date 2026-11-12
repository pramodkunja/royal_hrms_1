import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart' show dioProvider;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../employees/presentation/widgets/employee_file_viewer.dart' show openEmployeeFileInApp;
import '../../../my_requests/presentation/providers/my_requests_providers.dart' show myRequestsProvider;
import '../../domain/entities/attendance_entity.dart';
import '../providers/attendance_providers.dart';

// Late-arrival justification — the employee side of web my-attendance
// (LateJustificationModal, MyLateJustifications, the calendar / history
// "Explain" actions, the Monthly Late Arrivals card; lib/lateJustification.ts,
// lib/lateLimit.ts) over backend attendance services_late_justification.py:
//  - a day marked late can be explained within 3 calendar days, once (no open
//    or approved request for it) — the server says so per day
//    (canExplainLate) and checks again on submit;
//  - reason Medical | Transport | Personal | Other, an explanation of 10–1000
//    characters, proof (PDF / JPG / PNG, ≤ 5 MB, content checked by the
//    server) required for Medical;
//  - reviewed Manager (L1) → HR (L2); a reviewer may ask for a resubmission
//    (the employee resubmits the same request within 3 days of being asked);
//  - full approval shows the day as "Late (Excused)": punches and the late
//    status stay, payroll just doesn't count it. Nothing is changed here.

/// Web LATE_REASONS.
const kLateReasons = <(String, String)>[
  ('medical', 'Medical'),
  ('transport', 'Transport'),
  ('personal', 'Personal'),
  ('other', 'Other'),
];

/// Web LATE_STATUS (label, colour); approved rows read "Late (Excused)" in
/// the employee's list.
(String, Color) lateStatusBadge(String status) => switch (status) {
      'pending' => ('Pending', AppColors.warning),
      'l2_pending' => ('Pending (HR)', AppColors.warning),
      'approved' => ('Approved', AppColors.success),
      'rejected' => ('Rejected', AppColors.error),
      'resubmit' => ('Resubmission Required', AppColors.info),
      _ => (status, AppColors.textSecondary),
    };

/// Web calendar LATE_STATUS_HINT.
String? lateStatusHint(String? status) => switch (status) {
      'pending' || 'l2_pending' => 'Reason pending',
      'resubmit' => 'Resubmit reason',
      'rejected' => 'Reason rejected',
      _ => null,
    };

const kLateExplanationMin = 10;
const kLateExplanationMax = 1000;
const kLateProofMaxBytes = 5 * 1024 * 1024;
const kLateProofExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

/// Web proofError (the server also checks the file's real content).
String? lateProofError(String name, int size) {
  if (!RegExp(r'\.(pdf|jpe?g|png)$', caseSensitive: false).hasMatch(name)) return 'Upload a PDF, JPG or PNG file.';
  if (size == 0) return 'The file is empty.';
  if (size > kLateProofMaxBytes) return 'The file must be 5 MB or smaller.';
  return null;
}

/// Web lateFormErrors: field → message ({} when fine). [hasExistingProof]: a
/// resubmission may keep the proof already on file.
Map<String, String> lateFormErrors(String reason, String explanation, PlatformFile? file,
    {bool hasExistingProof = false}) {
  final errors = <String, String>{};
  if (!kLateReasons.any((r) => r.$1 == reason)) errors['reason'] = 'Choose a reason.';
  final text = explanation.trim();
  if (text.length < kLateExplanationMin) {
    errors['explanation'] = 'Explain what happened (at least $kLateExplanationMin characters).';
  } else if (text.length > kLateExplanationMax) {
    errors['explanation'] = 'Keep it under $kLateExplanationMax characters.';
  }
  final fileErr = file == null ? null : lateProofError(file.name, file.size);
  if (fileErr != null) {
    errors['document'] = fileErr;
  } else if (reason == 'medical' && file == null && !hasExistingProof) {
    errors['document'] = 'Medical reasons need proof (PDF, JPG or PNG).';
  }
  return errors;
}

/// Picks a proof file (bytes included). A provider so tests can supply one.
final lateProofPickerProvider = Provider<Future<PlatformFile?> Function()>((ref) => () async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: kLateProofExtensions,
        withData: true,
      );
      return (result == null || result.files.isEmpty) ? null : result.files.first;
    });

/// After a submission: what shows the day, the requests or the counts.
void refreshAfterLateJustification(WidgetRef ref) {
  ref.invalidate(attendanceCalendarProvider);
  ref.invalidate(attendanceStatsProvider);
  ref.invalidate(myCorrectionsProvider);
  ref.invalidate(myRequestsProvider);
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Web fmtDate: "Wed, 12 Nov 2026" ([withWeekday]) or "12 Nov 2026".
String fmtLateDate(String iso, {bool withWeekday = false}) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final base = '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
  return withWeekday ? '${_weekdays[d.weekday - 1]}, $base' : base;
}

// ── Explain / Resubmit sheet ────────────────────────────────────────────────

/// Opens web's "Explain late arrival" (new: [date], [clockIn]) or "Resubmit
/// late arrival justification" ([resubmit]). Returns the server's success
/// message, or null when closed.
Future<String?> showLateJustificationSheet(
  BuildContext context, {
  String? date,
  String? clockIn,
  MyCorrectionEntity? resubmit,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LateJustificationSheet(date: date, clockIn: clockIn, resubmit: resubmit),
    );

class LateJustificationSheet extends ConsumerStatefulWidget {
  const LateJustificationSheet({super.key, this.date, this.clockIn, this.resubmit});
  final String? date;
  final String? clockIn;
  final MyCorrectionEntity? resubmit;

  @override
  ConsumerState<LateJustificationSheet> createState() => _LateJustificationSheetState();
}

class _LateJustificationSheetState extends ConsumerState<LateJustificationSheet> {
  late String _reason = (widget.resubmit?.reason.isNotEmpty ?? false) ? widget.resubmit!.reason : 'medical';
  late final _explanation = TextEditingController(text: widget.resubmit?.explanation ?? '');
  PlatformFile? _file;
  Map<String, String> _errors = const {};
  String? _msg;
  bool _busy = false;

  MyCorrectionEntity? get _existing => widget.resubmit;
  String get _date => _existing?.date ?? widget.date ?? '';

  @override
  void dispose() {
    _explanation.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await ref.read(lateProofPickerProvider)();
    if (f == null || !mounted) return;
    setState(() {
      _file = f;
      _errors = {..._errors}..remove('document');
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final found = lateFormErrors(_reason, _explanation.text, _file, hasExistingProof: _existing?.hasDocument ?? false);
    if (found.isNotEmpty) {
      setState(() {
        _errors = found;
        _msg = 'Please correct the highlighted fields.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
      _errors = const {};
    });
    try {
      final message = await ref.read(attendanceDataSourceProvider).sendLateJustification(
            date: _existing == null ? _date : null,
            resubmitId: _existing?.id,
            reason: _reason,
            explanation: _explanation.text,
            proofBytes: _file?.bytes,
            proofName: _file?.name,
          );
      refreshAfterLateJustification(ref);
      if (mounted) Navigator.of(context).pop(message);
    } catch (e) {
      if (!mounted) return;
      final fields = <String, String>{};
      String? message;
      if (e is DioException) {
        final body = e.response?.data;
        if (body is Map) {
          final data = body['data'];
          if (data is Map) {
            for (final k in const ['reason', 'explanation', 'document']) {
              final v = data[k];
              if (v is List && v.isNotEmpty) fields[k] = '${v.first}';
              if (v is String) fields[k] = v;
            }
          }
          if (body['message'] is String) message = body['message'] as String;
        }
      }
      setState(() {
        _busy = false;
        _errors = fields;
        _msg = message ?? 'Could not submit. Please try again.';
      });
    }
  }

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: text, style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600)),
          if (required) TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
        ])),
      );

  Widget _fieldError(String key) => _errors[key] == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_errors[key]!,
              key: Key('late-error-$key'), style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 12)),
        );

  @override
  Widget build(BuildContext context) {
    final existing = _existing;
    final clockIn = existing?.originalInTime ?? widget.clockIn;
    final medical = _reason == 'medical';
    final hasProof = existing?.hasDocument ?? false;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          child: Row(children: [
            Expanded(
              child: Text(existing != null ? 'Resubmit late arrival justification' : 'Explain late arrival',
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
              if (_msg != null)
                Container(
                  key: const Key('late-sheet-message'),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_msg!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.backgroundLow, borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: fmtLateDate(_date, withWeekday: true), style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (clockIn != null && clockIn.isNotEmpty)
                      TextSpan(text: ' · clocked in at $clockIn', style: TextStyle(color: AppColors.textSecondary)),
                  ]), style: AppTextStyles.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    "Your punch times stay as recorded. If approved, the day shows as Late (Excused) and doesn't count "
                    'as a late mark.',
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ]),
              ),
              if (existing != null && existing.rejectionReason.isNotEmpty)
                Container(
                  key: const Key('late-reviewer-note'),
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text.rich(TextSpan(children: [
                    const TextSpan(text: "Reviewer's note: ", style: TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: existing.rejectionReason),
                    if (existing.resubmitBy != null) TextSpan(text: ' — resubmit by ${fmtLateDate(existing.resubmitBy!)}'),
                  ]), style: AppTextStyles.bodySmall),
                ),
              _label('Reason', required: true),
              DropdownButtonFormField<String>(
                key: const Key('late-reason'),
                initialValue: _reason,
                isExpanded: true,
                decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                items: [for (final (v, l) in kLateReasons) DropdownMenuItem(value: v, child: Text(l))],
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                          _reason = v ?? 'medical';
                          _errors = const {};
                        }),
              ),
              _fieldError('reason'),
              _label('Explanation', required: true),
              TextField(
                key: const Key('late-explanation'),
                controller: _explanation,
                enabled: !_busy,
                minLines: 3,
                maxLines: 6,
                maxLength: kLateExplanationMax,
                onChanged: (_) => setState(() => _errors = {..._errors}..remove('explanation')),
                decoration: InputDecoration(
                  hintText: 'What happened? e.g. visited the doctor before work',
                  isDense: true,
                  counterText: '${_explanation.text.length}/$kLateExplanationMax',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              _fieldError('explanation'),
              _label(medical ? 'Medical proof' : 'Supporting proof (optional)', required: medical && !hasProof),
              Row(children: [
                OutlinedButton.icon(
                  key: const Key('late-proof-pick'),
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: Text(_file == null ? 'Choose file' : 'Change file'),
                ),
                const SizedBox(width: 8),
                if (_file != null)
                  Expanded(
                    child: Row(children: [
                      Expanded(
                        child: Text(_file!.name,
                            key: const Key('late-proof-name'), overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall),
                      ),
                      IconButton(
                        tooltip: 'Remove file',
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: _busy ? null : () => setState(() => _file = null),
                      ),
                    ]),
                  ),
              ]),
              Text(
                "PDF, JPG or PNG, up to 5 MB — e.g. a doctor's note or prescription."
                '${hasProof ? ' Leave empty to keep the proof you already uploaded.' : ''}'
                ' Only authorised HR can open medical proof; your manager sees the reason, not the file.',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
              _fieldError('document'),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('late-cancel'),
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('late-submit'),
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Submitting…' : (existing != null ? 'Resubmit' : 'Submit')),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Monthly Late Arrivals (stats.late_limit) ────────────────────────────────

/// Web AttendanceTab "Monthly Late Arrivals": shown only when the company
/// switched the limit on; every number is the server's.
class MonthlyLateArrivalsCard extends StatelessWidget {
  const MonthlyLateArrivalsCard({super.key, required this.limit});
  final LateLimitSummaryEntity limit;

  @override
  Widget build(BuildContext context) {
    final badgeColor = switch (limit.status) {
      'within' => AppColors.success,
      'reached' => AppColors.warning,
      'exceeded' => AppColors.error,
      _ => AppColors.textSecondary,
    };
    Widget cell(String label, String value) => Expanded(
          child: Column(children: [
            Text(value, style: AppTextStyles.h4),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ]),
        );
    return Container(
      key: const Key('monthly-late-arrivals'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.alarm_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Monthly Late Arrivals', style: AppTextStyles.h4)),
          if ((limit.status ?? '').isNotEmpty)
            Container(
              key: const Key('late-limit-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Text(limit.statusLabel ?? limit.status!,
                  style: AppTextStyles.caption.copyWith(color: badgeColor, fontWeight: FontWeight.w600)),
            ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          cell('Maximum allowed', '${limit.maximum}'),
          cell('Late arrivals this month', '${limit.lateArrivals}'),
          cell('Remaining', limit.remaining == null ? '—' : '${limit.remaining}'),
        ]),
        const SizedBox(height: 10),
        Text(
          'Counted per calendar month; Late (Excused) days are not counted. This limit is for tracking — it does '
          'not add any LOP.',
          style: AppTextStyles.caption.copyWith(fontSize: 11),
        ),
      ]),
    );
  }
}

// ── The employee's own justifications ───────────────────────────────────────

/// Web MyLateJustifications ("Late Arrival Justifications"): status, the
/// reviewer's reason, the employee's own proof, and Resubmit when asked.
class MyLateJustificationsCard extends ConsumerStatefulWidget {
  const MyLateJustificationsCard({super.key});

  @override
  ConsumerState<MyLateJustificationsCard> createState() => _MyLateJustificationsCardState();
}

class _MyLateJustificationsCardState extends ConsumerState<MyLateJustificationsCard> {
  String? _notice;
  String? _viewing;
  final _viewErrors = <String, String>{};

  Future<void> _resubmit(MyCorrectionEntity r) async {
    setState(() => _notice = null);
    final msg = await showLateJustificationSheet(context, resubmit: r);
    if (msg != null && mounted) setState(() => _notice = msg);
  }

  Future<void> _view(MyCorrectionEntity r) async {
    if (_viewing != null) return;
    setState(() {
      _viewing = r.id;
      _viewErrors.remove(r.id);
    });
    // The proof is streamed by the API with the login (never a public link).
    final message = await openEmployeeFileInApp(
      context,
      ref,
      id: r.id.hashCode,
      // Full API address: the viewer treats a bare path as server-relative.
      url: '${ref.read(dioProvider).options.baseUrl}${ApiConstants.attendanceCorrectionDocument(r.id)}',
      fileName: r.documentName,
      title: 'Proof — ${fmtLateDate(r.date)}',
    );
    if (!mounted) return;
    setState(() {
      _viewing = null;
      if (message != null) _viewErrors[r.id] = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myCorrectionsProvider);
    final rows = (async.valueOrNull ?? const <MyCorrectionEntity>[]).where((c) => c.isLateJustification).toList();
    return Container(
      key: const Key('my-late-justifications'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.help_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Late Arrival Justifications', style: AppTextStyles.h4)),
        ]),
        if (_notice != null)
          Container(
            key: const Key('late-notice'),
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Text(_notice!, style: AppTextStyles.caption.copyWith(color: AppColors.success)),
          ),
        const SizedBox(height: 8),
        if (async.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (async.hasError)
          const SizedBox.shrink() // the corrections section above already shows the failure with Retry
        else if (rows.isEmpty)
          Padding(
            key: const Key('my-late-empty'),
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(children: [
              Icon(Icons.help_outline, size: 26, color: AppColors.textHint),
              const SizedBox(height: 6),
              Text('No late arrival justifications', style: AppTextStyles.label),
              const SizedBox(height: 2),
              Text('Use “Explain” on a late day in your attendance calendar (within 3 days).',
                  textAlign: TextAlign.center, style: AppTextStyles.caption),
            ]),
          )
        else
          for (final r in rows) _row(r),
      ]),
    );
  }

  Widget _row(MyCorrectionEntity r) {
    final badge = r.status == 'approved' ? ('Late (Excused)', AppColors.success) : lateStatusBadge(r.status);
    return Container(
      key: Key('my-late-${r.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: fmtLateDate(r.date), style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(
                  text: '  ·  clock-in ${r.originalInTime ?? '—'}',
                  style: TextStyle(color: AppColors.textSecondary, fontFamily: 'monospace', fontSize: 12)),
            ]), style: AppTextStyles.bodySmall),
          ),
          Container(
            key: Key('my-late-status-${r.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: badge.$2.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(badge.$1, style: AppTextStyles.caption.copyWith(color: badge.$2, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(r.reasonLabel.isEmpty ? r.reason : r.reasonLabel, style: AppTextStyles.bodySmall),
        if (r.explanation.isNotEmpty) Text(r.explanation, style: AppTextStyles.caption.copyWith(fontSize: 11)),
        if (r.rejectionReason.isNotEmpty)
          Text('Reviewer: ${r.rejectionReason}', style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.error)),
        Row(children: [
          if (r.hasDocument && r.canViewDocument)
            TextButton.icon(
              key: Key('my-late-proof-${r.id}'),
              onPressed: _viewing == null ? () => _view(r) : null,
              icon: _viewing == r.id
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.description_outlined, size: 16),
              label: const Text('View'),
            ),
          const Spacer(),
          if (r.canResubmit)
            FilledButton.icon(
              key: Key('my-late-resubmit-${r.id}'),
              onPressed: () => _resubmit(r),
              icon: const Icon(Icons.upload_outlined, size: 16),
              label: const Text('Resubmit'),
            ),
        ]),
        if (_viewErrors[r.id] != null)
          Text(_viewErrors[r.id]!, style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 11)),
      ]),
    );
  }
}
