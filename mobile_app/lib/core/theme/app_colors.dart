import 'package:flutter/material.dart';

/// Color palette derived from the Royal HRMS web design system.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF1E4E8C);
  static const Color primaryLight = Color(0xFF5B86C9);
  static const Color secondary = Color(0xFFC99A2E);

  // Backgrounds
  static const Color background = Color(0xFFF7F9FC);
  static const Color backgroundLow = Color(0xFFEFF2F8);
  static const Color backgroundMid = Color(0xFFE7ECF4);
  static const Color surface = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1A2433);
  static const Color textSecondary = Color(0xFF4F5D75);
  static const Color textHint = Color(0xFF7C8AA3);

  // Border
  static const Color border = Color(0xFFD3DAE8);
  static const Color borderStrong = Color(0xFFD4DCEB);

  // Status
  static const Color success = Color(0xFF1B8A6B);
  static const Color successContainer = Color(0xFFD8F3DC);
  static const Color error = Color(0xFFC0392B);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color warning = Color(0xFFB5651D);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF0E7C86);
  static const Color infoContainer = Color(0xFFE6F1FB);

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF1E4E8C).withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: const Color(0xFF1E4E8C).withValues(alpha: 0.06),
          blurRadius: 0,
          spreadRadius: 1,
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF1E4E8C).withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}
