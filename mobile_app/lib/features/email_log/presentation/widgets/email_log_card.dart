import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/email_log_entity.dart';
import 'email_status_chip.dart';

String fmtEmailDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final local = d.toLocal();
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day} ${months[local.month]} ${local.year} • $hour12:$minute $ampm';
}

class EmailLogCard extends StatelessWidget {
  final CandidateEmailEntity email;
  final VoidCallback onTap;
  const EmailLogCard({super.key, required this.email, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sc = email.isSent ? AppColors.success : AppColors.error;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 3, color: sc),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          email.subject.isNotEmpty ? email.subject : '(No subject)',
                          style: AppTextStyles.label.copyWith(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      EmailStatusChip(status: email.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email.toEmail,
                    style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (email.candidateName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [email.candidateName, email.candidatePosition]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 12, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          fmtEmailDateTime(email.sentAt),
                          style: AppTextStyles.caption.copyWith(fontSize: 10.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (email.sentByName.isNotEmpty)
                        Text(
                          'by ${email.sentByName}',
                          style: AppTextStyles.caption.copyWith(fontSize: 10.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
