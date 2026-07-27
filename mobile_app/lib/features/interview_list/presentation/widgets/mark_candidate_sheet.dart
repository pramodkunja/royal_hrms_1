import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/entities/candidate_entity.dart';
import '../providers/interview_providers.dart';
import 'interview_status_badge.dart';

/// Confirmation sheet shown before moving a candidate to Selected/Rejected —
/// mirrors web's `MarkCandidateModal.tsx`. The email template is fixed by the
/// target status (never manually chosen), and confirming both updates the
/// status (carrying the interviewer's remarks into the audit log) and sends
/// the matching notification email, same as web's setStatus-then-sendEmail
/// sequence.
class MarkCandidateSheet extends ConsumerStatefulWidget {
  final CandidateEntity candidate;
  final String targetStatus; // 'selected' | 'rejected'

  const MarkCandidateSheet({
    super.key,
    required this.candidate,
    required this.targetStatus,
  });

  static Future<bool> show(
    BuildContext context, {
    required CandidateEntity candidate,
    required String targetStatus,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MarkCandidateSheet(
        candidate: candidate,
        targetStatus: targetStatus,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<MarkCandidateSheet> createState() =>
      _MarkCandidateSheetState();
}

class _MarkCandidateSheetState extends ConsumerState<MarkCandidateSheet> {
  final _remarksCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _isSelect => widget.targetStatus == 'selected';
  String get _templateSlug =>
      _isSelect ? 'candidate_selected' : 'candidate_rejected';

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _candidateVars(String companyName) {
    final c = widget.candidate;
    final parts = c.name.trim().split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty && parts.first.isNotEmpty ? parts.first : c.name;
    final lastName = parts.length > 1 ? parts.last : '';
    final modeLabel = interviewModeLabel(c.interviewMode);
    return {
      'candidate_name': c.name,
      'full_name': c.name,
      'first_name': firstName,
      'last_name': lastName,
      'email': c.email,
      'position_applied': c.positionApplied,
      'position': c.positionApplied,
      'branch': c.branchName,
      'branch_name': c.branchName,
      'interview_date': c.interviewDate,
      'interview_mode': c.interviewMode,
      'interview_mode_display': modeLabel,
      'company_name': companyName,
      'FULL_NAME': c.name,
      'FNAME': firstName,
      'LNAME': lastName,
      'EMAIL': c.email,
      'POSITION': c.positionApplied,
      'COMPANY': companyName,
    };
  }

  Future<void> _confirm(String companyName) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final notifier = ref.read(candidateListProvider.notifier);
    final statusErr = await notifier.updateStatus(
      widget.candidate.id,
      widget.targetStatus,
      remarks: _remarksCtrl.text.trim(),
    );
    if (statusErr != null) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = statusErr;
      });
      return;
    }
    final emailErr = await notifier.sendStatusEmail(
      widget.candidate.id,
      templateName: _templateSlug,
      extraContext: _candidateVars(companyName),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (emailErr == null) {
      Navigator.pop(context, true);
    } else {
      // The status change already succeeded — only the email failed. Close
      // as successful but let the caller know the email didn't go out.
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Status updated, but the email failed to send: $emailErr'),
        backgroundColor: AppColors.warning,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(emailTemplatesProvider);
    final companyAsync = ref.watch(companyProvider);

    final loadingTemplates = templatesAsync.isLoading && !templatesAsync.hasValue;
    final activeTemplates =
        (templatesAsync.valueOrNull ?? []).where((t) => t.isActive).toList();
    final matching =
        activeTemplates.where((t) => t.name == _templateSlug).toList();
    final template = matching.isEmpty ? null : matching.first;

    final company = companyAsync.valueOrNull;
    final companyName =
        (company?.companyName.isNotEmpty ?? false) ? company!.companyName : '[Company]';

    final actionColor = _isSelect ? AppColors.success : AppColors.error;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_isSelect ? 'Select' : 'Reject'} Candidate — ${widget.candidate.name}',
                        style: AppTextStyles.h4.copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.textHint,
                      onPressed: () => Navigator.pop(context, false),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            Icon(Icons.error_outline, size: 16, color: AppColors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: AppTextStyles.body.copyWith(
                                      fontSize: 12,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: actionColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(_isSelect ? Icons.check_circle_outline : Icons.cancel_outlined,
                                size: 15, color: actionColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.textPrimary),
                                  children: [
                                    const TextSpan(text: 'You are marking '),
                                    TextSpan(
                                        text: widget.candidate.name,
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                    TextSpan(text: ' as ${widget.targetStatus}. '),
                                    const TextSpan(text: 'An email will be sent using the template below.'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Email Template',
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      if (loadingTemplates)
                        Row(children: [
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Text('Loading…', style: AppTextStyles.caption),
                        ])
                      else if (template == null)
                        Text(
                          'No active "$_templateSlug" email template found. Create one in Settings → Email Templates first.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.warning),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(children: [
                            Icon(Icons.lock_outline, size: 14, color: AppColors.textHint),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(template.displayName,
                                    style: AppTextStyles.body.copyWith(fontSize: 13))),
                          ]),
                        ),
                      const SizedBox(height: 16),
                      Text('Interview feedback / remarks',
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _remarksCtrl,
                        maxLines: 2,
                        style: AppTextStyles.body,
                        decoration: InputDecoration(
                          hintText: 'Add interview notes…',
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.border)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: (_saving || loadingTemplates || template == null)
                            ? null
                            : () => _confirm(companyName),
                        style: FilledButton.styleFrom(
                          backgroundColor: actionColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(_isSelect ? Icons.check : Icons.close, size: 16),
                        label: Text(_saving ? 'Sending…' : 'Confirm & Send Email'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
