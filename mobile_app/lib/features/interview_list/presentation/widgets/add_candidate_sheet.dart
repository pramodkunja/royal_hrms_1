import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/validators/form_validators.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../separation/domain/entities/separation_entity.dart' show EmployeePickerOption;
import '../../../separation/presentation/widgets/employee_picker_field.dart';
import '../../domain/entities/candidate_entity.dart';
import '../providers/interview_providers.dart';

part 'add_candidate_form.dart';

/// Handles both Add and Edit — pass [existing] to edit a candidate in place
/// (mirrors the mobile app's established one-form-both-modes convention used
/// by Holiday/Leave Type forms, rather than web's separate Add/Edit modals).
class AddCandidateDialog extends ConsumerStatefulWidget {
  final CandidateEntity? existing;
  const AddCandidateDialog({super.key, this.existing});

  @override
  ConsumerState<AddCandidateDialog> createState() =>
      _AddCandidateDialogState();
}

class _AddCandidateDialogState
    extends ConsumerState<AddCandidateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _posCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _meetingLinkCtrl = TextEditingController();

  final _scrollCtrl = ScrollController();

  int? _selectedBranch;
  String _mode = 'in_person';
  DateTime? _interviewDate;
  DateTime? _originalInterviewDate;
  // Web Interview Time ("HH:MM"), Meeting Link (Video Call only) and
  // Interviewer (an employee; sent as the User uuid).
  TimeOfDay? _interviewTime;
  EmployeePickerOption? _interviewer;
  bool _loading = false;
  List<Map<String, dynamic>> _branches = [];
  bool _branchLocked = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameCtrl.text = existing.name;
      _emailCtrl.text = existing.email;
      _posCtrl.text = existing.positionApplied;
      _phoneCtrl.text = existing.phone;
      _notesCtrl.text = '';
      _selectedBranch = existing.branchId;
      _mode = existing.interviewMode.isEmpty ? 'in_person' : existing.interviewMode;
      _interviewDate = DateTime.tryParse(existing.interviewDate);
      _originalInterviewDate = _interviewDate;
      _interviewTime = parseInterviewTime(existing.interviewTime);
      _meetingLinkCtrl.text = existing.meetingLink;
      final interviewerId = existing.interviewer;
      if (interviewerId != null && interviewerId.isNotEmpty) {
        _interviewer = EmployeePickerOption(
          code: '',
          uuid: interviewerId,
          name: existing.interviewerName.isNotEmpty ? existing.interviewerName : 'Assigned interviewer',
          department: '',
          designation: '',
        );
      }
    }
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiConstants.branches,
          queryParameters: {'page_size': 100});
      final data = res.data is Map ? res.data['data'] : res.data;
      final results =
          (data is Map ? data['results'] : data) as List<dynamic>;
      if (!mounted) return;
      final branches = results
          .map((e) => {
                'id': (e as Map<String, dynamic>)['id'],
                'name': e['branch_name'] ?? '',
              })
          .toList();

      // Mirrors the web app: non-system_admin users can only add/edit
      // candidates under their own branch, so the picker is pre-filled and
      // locked rather than left open (the backend doesn't enforce this
      // server-side, so the client is the only guard).
      final user = ref.read(authStateProvider).valueOrNull?.user;
      final locked = user != null && user.role != 'system_admin';
      // Web EditCandidateModal does the same for a candidate with no branch
      // yet (e.g. a referral): fill in the user's own branch.
      if (locked && (!_isEdit || _selectedBranch == null)) {
        final own = branches.firstWhere(
          (b) => (b['name'] as String).toLowerCase() ==
              (user.branch ?? '').toLowerCase(),
          orElse: () => const {},
        );
        if (own.isNotEmpty) _selectedBranch = own['id'] as int;
      }

      setState(() {
        _branches = branches;
        _branchLocked = locked;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _posCtrl,
      _phoneCtrl,
      _notesCtrl,
      _meetingLinkCtrl,
    ]) {
      c.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a branch')),
      );
      return;
    }
    final dateError = FormValidators.interviewDate(
      _interviewDate,
      original: _isEdit ? _originalInterviewDate : null,
    );
    if (dateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dateError), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _loading = true);
    final time = _interviewTime == null ? null : formatInterviewTime(_interviewTime!);
    // Web: the link only applies to a Video Call; otherwise it is cleared.
    final link = _mode == 'video_call' ? _meetingLinkCtrl.text.trim() : '';
    final data = {
      'name': _nameCtrl.text.trim(),
      if (!_isEdit) 'email': _emailCtrl.text.trim(),
      'position_applied': _posCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'branch': _selectedBranch,
      'interview_mode': _mode,
      // As web EditCandidateModal: an edit always sends the date, null when
      // cleared (the backend then sends no invitation); Add omits it.
      if (_isEdit || _interviewDate != null)
        'interview_date': _interviewDate?.toIso8601String().split('T').first,
      // As web: Edit sends null to clear an empty time/interviewer; Add
      // simply leaves an unset time out.
      if (_isEdit || time != null) 'interview_time': time,
      'meeting_link': link,
      'interviewer': _interviewer?.uuid,
      if (_notesCtrl.text.trim().isNotEmpty)
        'notes': _notesCtrl.text.trim(),
    };
    // The backend emails the interview details itself (queued) when a save
    // leaves a date set and the date, time or link changed — mirror that
    // rule only to word the confirmation; nothing else is requested.
    final willEmail = _interviewDate != null &&
        (!_isEdit ||
            !_sameDay(_interviewDate!, _originalInterviewDate) ||
            time != _originalTime ||
            link != widget.existing!.meetingLink);
    final err = _isEdit ? await _updateCandidate(data) : await _addCandidate(data);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      // No separate /send-email/ call: the backend sends the interview
      // invitation itself whenever a save sets or changes the interview
      // date/time/link (recruitment views `_fire_interview_date_emails_if_needed`).
      // Calling it here too emailed the candidate twice.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      if (willEmail) {
        messenger.showSnackBar(SnackBar(
          content: const Text(
              'Interview details saved. An interview invitation email will be sent to the candidate.'),
          backgroundColor: AppColors.success,
        ));
      }
    } else {
      // The dialog stays open with every value as entered, for a retry.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(err), backgroundColor: AppColors.error),
      );
    }
  }

  String? get _originalTime {
    final t = parseInterviewTime(widget.existing?.interviewTime ?? '');
    return t == null ? null : formatInterviewTime(t);
  }

  static bool _sameDay(DateTime a, DateTime? b) =>
      b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  Future<String?> _addCandidate(Map<String, dynamic> data) async {
    try {
      await ref
          .read(candidateListProvider.notifier)
          .addCandidate(data);
      return null;
    } catch (e) {
      // Surface the backend's real {status, message, data} envelope instead
      // of DioException's own unhelpful "DioException [bad response]: ..."
      // toString() — same fix as interview_providers.dart.
      if (e is DioException) return parseDioException(e).message;
      return e.toString();
    }
  }

  Future<String?> _updateCandidate(Map<String, dynamic> data) {
    return ref
        .read(candidateListProvider.notifier)
        .updateCandidate(widget.existing!.id, data);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Popup dialog box (centered), not a bottom sheet — the form's own
    // ListView scrolls internally, and maxHeight is recomputed against the
    // keyboard inset so opening a text field doesn't overflow the dialog.
    final maxHeight =
        (mq.size.height - mq.viewInsets.bottom - 80).clamp(320.0, mq.size.height * 0.85);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_isEdit ? 'Edit Candidate' : 'Add Candidate to Interview List',
                        style: AppTextStyles.label
                            .copyWith(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            // Form
            Flexible(
              child: _AddCandidateFormContent(
                formKey: _formKey,
                nameCtrl: _nameCtrl,
                emailCtrl: _emailCtrl,
                posCtrl: _posCtrl,
                phoneCtrl: _phoneCtrl,
                notesCtrl: _notesCtrl,
                selectedBranch: _selectedBranch,
                branches: _branches,
                branchLocked: _branchLocked,
                mode: _mode,
                interviewDate: _interviewDate,
                originalInterviewDate: _originalInterviewDate,
                isEdit: _isEdit,
                loading: _loading,
                onSubmit: _submit,
                onCancel: () => Navigator.pop(context),
                onBranchChanged: (v) =>
                    setState(() => _selectedBranch = v),
                onModeChanged: (v) =>
                    setState(() => _mode = v ?? 'in_person'),
                onDateChanged: (v) =>
                    setState(() => _interviewDate = v),
                interviewTime: _interviewTime,
                onTimeChanged: (v) => setState(() => _interviewTime = v),
                meetingLinkCtrl: _meetingLinkCtrl,
                interviewer: _interviewer,
                onInterviewerChanged: (v) => setState(() => _interviewer = v),
                scrollCtrl: _scrollCtrl,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "HH:MM" or "HH:MM:SS" (backend TimeField) → TimeOfDay; null if empty/bad.
TimeOfDay? parseInterviewTime(String raw) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return TimeOfDay(hour: h, minute: min);
}

/// TimeOfDay → "HH:MM", the value web's time input sends.
String formatInterviewTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
