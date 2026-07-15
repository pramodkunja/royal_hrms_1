import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/holiday_model.dart';

// Colour mapping ported from the reference web screen's TYPE_STYLES map:
// national → blue, regional → teal, company → amber. Optional/Mandatory and
// Active/Inactive use a separate purple/green/grey scheme, also matching web.
class HolidayStyles {
  HolidayStyles._();

  static final Color national = AppColors.primary; // blue
  static const Color nationalBg = Color(0xFFEBF0FA);
  static final Color regional = AppColors.info; // teal
  static const Color regionalBg = Color(0xFFE5F4F5);
  static final Color company = AppColors.warning; // amber
  static final Color companyBg = AppColors.warningContainer;
  static const Color optional = Color(0xFF6B3FA0); // purple
  static const Color optionalBg = Color(0xFFF0EBF9);

  static Color typeColor(String type) => switch (type) {
    HolidayType.national => national,
    HolidayType.regional => regional,
    HolidayType.company => company,
    _ => AppColors.textHint,
  };

  static Color typeBg(String type) => switch (type) {
    HolidayType.national => nationalBg,
    HolidayType.regional => regionalBg,
    HolidayType.company => companyBg,
    _ => AppColors.backgroundMid,
  };

  static final Color sunday = AppColors.error;
}
