import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

Color documentTypeColor(String type) {
  switch (type.toUpperCase()) {
    case 'PDF':
      return const Color(0xFFE53935);
    case 'DOC':
    case 'DOCX':
      return const Color(0xFF1565C0);
    case 'XLS':
    case 'XLSX':
      return const Color(0xFF2E7D32);
    case 'PPT':
    case 'PPTX':
      return const Color(0xFFE65100);
    case 'JPG':
    case 'JPEG':
    case 'PNG':
      return const Color(0xFF6A1B9A);
    case 'TXT':
    case 'CSV':
      return const Color(0xFF546E7A);
    default:
      return AppColors.primary;
  }
}

IconData documentTypeIcon(String type) {
  switch (type.toUpperCase()) {
    case 'PDF':
      return Icons.picture_as_pdf_outlined;
    case 'DOC':
    case 'DOCX':
      return Icons.article_outlined;
    case 'XLS':
    case 'XLSX':
      return Icons.table_chart_outlined;
    case 'PPT':
    case 'PPTX':
      return Icons.co_present_outlined;
    case 'JPG':
    case 'JPEG':
    case 'PNG':
      return Icons.image_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

String formatDocDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
