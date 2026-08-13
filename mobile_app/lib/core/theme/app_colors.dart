import 'package:flutter/material.dart';

/// Color palette derived from the Royal HRMS web design system.
///
/// Every field is a mutable `static Color` (not `const`) so [applyMode] can
/// swap the whole app between light/dark at runtime — every widget reads
/// these as plain static fields, so nothing besides this file needs to know
/// about theming. Dark values are mapped 1:1 from web's `body.dark-mode` CSS
/// variables (frontend/app/globals.css); fields web's dark mode doesn't
/// define (container tints, hint text, strong border) are derived to match
/// the same relationship they have to their sibling color in light mode.
class AppColors {
  AppColors._();

  static bool _isDark = false;
  static bool get isDark => _isDark;

  // ── Light palette ──────────────────────────────────────────────────────────
  static const Color _lightPrimary = Color(0xFF1E4E8C);
  static const Color _lightPrimaryLight = Color(0xFF5B86C9);
  static const Color _lightSecondary = Color(0xFFC99A2E);
  static const Color _lightBackground = Color(0xFFF7F9FC);
  static const Color _lightBackgroundLow = Color(0xFFEFF2F8);
  static const Color _lightBackgroundMid = Color(0xFFE7ECF4);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightTextPrimary = Color(0xFF1A2433);
  static const Color _lightTextSecondary = Color(0xFF4F5D75);
  static const Color _lightTextHint = Color(0xFF7C8AA3);
  static const Color _lightBorder = Color(0xFFD3DAE8);
  static const Color _lightBorderStrong = Color(0xFFD4DCEB);
  static const Color _lightSuccess = Color(0xFF1B8A6B);
  static const Color _lightSuccessContainer = Color(0xFFD8F3DC);
  static const Color _lightError = Color(0xFFC0392B);
  static const Color _lightErrorContainer = Color(0xFFFFDAD6);
  static const Color _lightWarning = Color(0xFFB5651D);
  static const Color _lightWarningContainer = Color(0xFFFEF3C7);
  static const Color _lightInfo = Color(0xFF0E7C86);
  static const Color _lightInfoContainer = Color(0xFFE6F1FB);
  // "Half Day"/"Incomplete" attendance status accent — previously hardcoded
  // as a raw Color(0xFF9333EA) independently in two attendance screens with
  // an explicit "no AppColors token for purple" comment, so it never
  // adapted for dark mode like every other status color does. Every other
  // status color also has a solid *Container background field (used
  // directly, not via a runtime alpha blend) — this one lacked that too,
  // falling back to `.withValues(alpha: 0.12)` at each call site instead.
  static const Color _lightAccentPurple = Color(0xFF9333EA);
  static const Color _lightAccentPurpleContainer = Color(0xFFF3E5FB);

  // ── Dark palette (web: body.dark-mode CSS vars) ───────────────────────────
  static const Color _darkPrimary = Color(0xFF7FA3DE);
  static const Color _darkPrimaryLight = Color(0xFFA8C3EA);
  static const Color _darkSecondary = Color(0xFFD9AE55);
  static const Color _darkBackground = Color(0xFF10151F);
  static const Color _darkBackgroundLow = Color(0xFF161C28);
  static const Color _darkBackgroundMid = Color(0xFF1C2330);
  static const Color _darkSurface = Color(0xFF222A39);
  static const Color _darkTextPrimary = Color(0xFFEEF1F7);
  static const Color _darkTextSecondary = Color(0xFFB7C0D4);
  static const Color _darkTextHint = Color(0xFF8792A8);
  static const Color _darkBorder = Color(0xFF2C3445);
  static const Color _darkBorderStrong = Color(0xFF3A4358);
  static const Color _darkSuccess = Color(0xFF9FE1CB);
  static const Color _darkSuccessContainer = Color(0xFF163B2E);
  static const Color _darkError = Color(0xFFF4A5A5);
  static const Color _darkErrorContainer = Color(0xFF3B1E1E);
  static const Color _darkWarning = Color(0xFFFCD34D);
  static const Color _darkWarningContainer = Color(0xFF3A2E12);
  static const Color _darkInfo = Color(0xFF90C2EB);
  static const Color _darkInfoContainer = Color(0xFF16283B);
  // Lighter/pastel than the light-mode value, matching the same
  // lighten-for-dark-background treatment already used for every other
  // accent (e.g. _darkWarning, _darkInfo) rather than keeping the vivid
  // light-mode hue, which would read as over-saturated on a dark surface.
  static const Color _darkAccentPurple = Color(0xFFC4B5FD);
  static const Color _darkAccentPurpleContainer = Color(0xFF3A2A52);

  // ── Live palette — every widget in the app reads these ─────────────────────
  static Color primary = _lightPrimary;
  static Color primaryLight = _lightPrimaryLight;
  static Color secondary = _lightSecondary;
  static Color background = _lightBackground;
  static Color backgroundLow = _lightBackgroundLow;
  static Color backgroundMid = _lightBackgroundMid;
  static Color surface = _lightSurface;
  static Color textPrimary = _lightTextPrimary;
  static Color textSecondary = _lightTextSecondary;
  static Color textHint = _lightTextHint;
  static Color border = _lightBorder;
  static Color borderStrong = _lightBorderStrong;
  static Color success = _lightSuccess;
  static Color successContainer = _lightSuccessContainer;
  static Color error = _lightError;
  static Color errorContainer = _lightErrorContainer;
  static Color warning = _lightWarning;
  static Color warningContainer = _lightWarningContainer;
  static Color info = _lightInfo;
  static Color infoContainer = _lightInfoContainer;
  static Color accentPurple = _lightAccentPurple;
  static Color accentPurpleContainer = _lightAccentPurpleContainer;

  /// Swaps every field above between the light/dark palettes. Must be called
  /// (by [ThemeModeNotifier]) before the widget tree rebuilds, so the first
  /// frame after a toggle already reads the new colors.
  static void applyMode(bool dark) {
    _isDark = dark;
    primary = dark ? _darkPrimary : _lightPrimary;
    primaryLight = dark ? _darkPrimaryLight : _lightPrimaryLight;
    secondary = dark ? _darkSecondary : _lightSecondary;
    background = dark ? _darkBackground : _lightBackground;
    backgroundLow = dark ? _darkBackgroundLow : _lightBackgroundLow;
    backgroundMid = dark ? _darkBackgroundMid : _lightBackgroundMid;
    surface = dark ? _darkSurface : _lightSurface;
    textPrimary = dark ? _darkTextPrimary : _lightTextPrimary;
    textSecondary = dark ? _darkTextSecondary : _lightTextSecondary;
    textHint = dark ? _darkTextHint : _lightTextHint;
    border = dark ? _darkBorder : _lightBorder;
    borderStrong = dark ? _darkBorderStrong : _lightBorderStrong;
    success = dark ? _darkSuccess : _lightSuccess;
    successContainer = dark ? _darkSuccessContainer : _lightSuccessContainer;
    error = dark ? _darkError : _lightError;
    errorContainer = dark ? _darkErrorContainer : _lightErrorContainer;
    warning = dark ? _darkWarning : _lightWarning;
    warningContainer = dark ? _darkWarningContainer : _lightWarningContainer;
    info = dark ? _darkInfo : _lightInfo;
    infoContainer = dark ? _darkInfoContainer : _lightInfoContainer;
    accentPurple = dark ? _darkAccentPurple : _lightAccentPurple;
    accentPurpleContainer =
        dark ? _darkAccentPurpleContainer : _lightAccentPurpleContainer;
  }

  // Shadows — tinted-primary shadows read as muddy smears on a dark
  // background, so dark mode uses plain low-alpha black instead.
  static List<BoxShadow> get cardShadow => _isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ]
      : [
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

  static List<BoxShadow> get elevatedShadow => _isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ]
      : [
          BoxShadow(
            color: const Color(0xFF1E4E8C).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ];
}
