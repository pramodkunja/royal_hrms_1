import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => GoogleFonts.poppins(color: AppColors.textPrimary);

  // Headings
  static TextStyle get h1 => _base.copyWith(fontSize: 28, fontWeight: FontWeight.w700);
  static TextStyle get h2 => _base.copyWith(fontSize: 22, fontWeight: FontWeight.w600);
  static TextStyle get h3 => _base.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
  static TextStyle get h4 => _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600);

  // Body
  static TextStyle get bodyLarge => _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400);
  static TextStyle get body => _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle get bodySmall => _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400);

  // Labels
  static TextStyle get labelLarge => _base.copyWith(fontSize: 14, fontWeight: FontWeight.w500);
  static TextStyle get label => _base.copyWith(fontSize: 13, fontWeight: FontWeight.w500);
  static TextStyle get labelSmall => _base.copyWith(fontSize: 11, fontWeight: FontWeight.w500);

  // Caption / Hint
  static TextStyle get caption => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textHint,
      );

  // Button
  static TextStyle get button => _base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      );

  // Secondary colour variants
  static TextStyle get bodySecondary =>
      body.copyWith(color: AppColors.textSecondary);
  static TextStyle get labelSecondary =>
      label.copyWith(color: AppColors.textSecondary);
}
