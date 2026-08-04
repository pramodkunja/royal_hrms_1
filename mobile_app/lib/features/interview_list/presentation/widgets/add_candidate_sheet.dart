import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/validators/form_validators.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/candidate_entity.dart';
import '../providers/interview_providers.dart';
import 'interview_status_badge.dart';

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

  final _scrollCtrl = ScrollController();

  int? _selectedBranch;
  String _mode = 'in_person';
  DateTime? _interviewDate;
  DateTime? _originalInterviewDate;
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
      if (locked && !_isEdit) {
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
    ]) {
      c.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
    final data = {
      'name': _nameCtrl.text.trim(),
      if (!_isEdit) 'email': _emailCtrl.text.trim(),
      'position_applied': _posCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'branch': _selectedBranch,
      'interview_mode': _mode,
      if (_interviewDate != null)
        'interview_date':
            _interviewDate!.toIso8601String().split('T').first,
      if (_notesCtrl.text.trim().isNotEmpty)
        'notes': _notesCtrl.text.trim(),
    };
    final isFirstSchedule =
        _isEdit && _interviewDate != null && _originalInterviewDate == null;
    final err = _isEdit ? await _updateCandidate(data) : await _addCandidate(data);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      if (isFirstSchedule) {
        await _sendScheduleEmail();
      }
      if (!mounted) return;
      Navigator.pop(context);
      if (isFirstSchedule && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Interview details saved. Invitation email sent to candidate.'),
          backgroundColor: AppColors.success,
        ));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(err), backgroundColor: AppColors.error),
      );
    }
  }

  // Mirrors web's EditCandidateModal — the very first time an interview_date
  // is set on a candidate, an "interview_scheduled_candidate" email fires
  // automatically. Uses the ORIGINAL branch name (not any newly-picked one in
  // this same save) to match web's candidate.branch_name reference exactly.
  Future<void> _sendScheduleEmail() async {
    final existing = widget.existing!;
    final parts = _nameCtrl.text.trim().split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first
        : _nameCtrl.text.trim();
    final lastName = parts.length > 1 ? parts.last : '';
    final modeLabel = interviewModeLabel(_mode);
    final vars = <String, String>{
      'candidate_name': _nameCtrl.text.trim(),
      'full_name': _nameCtrl.text.trim(),
      'first_name': firstName,
      'last_name': lastName,
      'email': existing.email,
      'position_applied': _posCtrl.text.trim(),
      'position': _posCtrl.text.trim(),
      'branch_name': existing.branchName,
      'interview_date': _interviewDate!.toIso8601String().split('T').first,
      'interview_mode': _mode,
      'interview_mode_display': modeLabel,
    };
    await ref.read(candidateListProvider.notifier).sendStatusEmail(
          existing.id,
          templateName: 'interview_scheduled_candidate',
          extraContext: vars,
        );
  }

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
                scrollCtrl: _scrollCtrl,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
