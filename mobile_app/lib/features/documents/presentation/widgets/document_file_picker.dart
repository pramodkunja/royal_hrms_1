import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class DocumentFilePicker extends StatelessWidget {
  final PlatformFile? picked;
  final String? error;
  final VoidCallback onPick;

  const DocumentFilePicker({
    super.key,
    required this.picked,
    required this.error,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: error != null
                ? AppColors.error
                : picked != null
                    ? AppColors.primary
                    : AppColors.border,
            width: picked != null ? 1.5 : 1,
          ),
        ),
        child: picked == null
            ? Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 36,
                    color: error != null ? AppColors.error : AppColors.textHint,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to select file',
                    style: AppTextStyles.label.copyWith(
                      color: error != null
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (error != null)
                    Text(
                      error!,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.error, fontSize: 10),
                    )
                  else
                    Text(
                      'PDF, Word, Excel, PPT, images, TXT, CSV',
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                ],
              )
            : Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined,
                      size: 28, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          picked!.name,
                          style: AppTextStyles.label
                              .copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatSize(picked!.size),
                          style: AppTextStyles.caption.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.success, size: 20),
                ],
              ),
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}
