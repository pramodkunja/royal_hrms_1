import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/email_log_entity.dart';
import 'email_log_card.dart' show fmtEmailDateTime;
import 'email_status_chip.dart';

/// Opens the Email Log detail sheet. Renders straight from the already-
/// loaded [email] — the backend has no per-email detail endpoint (the list
/// row already returns every field CandidateEmailSerializer exposes), so
/// there is nothing to re-fetch.
Future<void> showEmailLogDetailSheet(BuildContext context, CandidateEmailEntity email) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EmailLogDetailSheet(email: email),
  );
}

class EmailLogDetailSheet extends StatelessWidget {
  final CandidateEmailEntity email;
  const EmailLogDetailSheet({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.mail_outline, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Email Details', style: AppTextStyles.h4.copyWith(fontSize: 15)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              email.subject.isNotEmpty ? email.subject : '(No subject)',
                              style: AppTextStyles.label.copyWith(fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          EmailStatusChip(status: email.status),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),
                      _Field(label: 'To', value: email.toEmail),
                      const SizedBox(height: 10),
                      _Field(
                        label: 'Sent By',
                        value: email.sentByName.isNotEmpty ? email.sentByName : '—',
                      ),
                      const SizedBox(height: 10),
                      _Field(label: 'Sent At', value: fmtEmailDateTime(email.sentAt)),
                      if (email.templateUsed.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _Field(label: 'Template', value: email.templateUsed),
                      ],
                      if (email.candidateName.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 12),
                        _Field(label: 'Candidate', value: email.candidateName),
                        if (email.candidatePosition.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _Field(label: 'Position Applied', value: email.candidatePosition),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(
                  height: MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom
                      : 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, style: AppTextStyles.body.copyWith(fontSize: 13)),
      ],
    );
  }
}
