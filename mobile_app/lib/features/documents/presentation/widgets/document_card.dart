import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/document_entity.dart';
import 'document_type_helpers.dart';

class DocumentCard extends StatelessWidget {
  final DocumentEntity document;
  final VoidCallback onTap;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = documentTypeColor(document.fileType);
    final typeIcon = documentTypeIcon(document.fileType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            // ── Top accent bar ─────────────────────────────────────────────
            Container(height: 3, color: typeColor),

            // ── File icon + type badge ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.title,
                          style: AppTextStyles.label
                              .copyWith(fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            document.fileType,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: typeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── File meta ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.data_usage_outlined,
                      size: 11, color: AppColors.textHint),
                  const SizedBox(width: 3),
                  Text(document.fileSizeDisplay,
                      style:
                          AppTextStyles.caption.copyWith(fontSize: 10)),
                  const SizedBox(width: 8),
                  const Icon(Icons.calendar_today_outlined,
                      size: 11, color: AppColors.textHint),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      formatDocDate(document.uploadedAt),
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 5),

            // ── Uploader ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 11, color: AppColors.textHint),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      document.uploadedByName,
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),
            const SizedBox(height: 8),

            // ── Category badge ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _CategoryBadge(
                  category: document.category,
                  label: document.categoryDisplay),
            ),
          ],
        ),
      ),
    );
  }

}

class _CategoryBadge extends StatelessWidget {
  final String category;
  final String label;
  const _CategoryBadge({required this.category, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _color(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static Color _color(String category) {
    switch (category) {
      case 'policy':
        return const Color(0xFF1565C0);
      case 'form':
        return const Color(0xFF2E7D32);
      case 'template':
        return const Color(0xFFE65100);
      default:
        return AppColors.textSecondary;
    }
  }
}
