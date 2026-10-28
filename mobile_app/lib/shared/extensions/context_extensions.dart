import 'package:flutter/material.dart';

enum DeviceSize { mobile, tablet, large }

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isSmallScreen => MediaQuery.of(this).size.width < 360;

  /// Breakpoints: mobile <600, tablet 600-1024, large >=1024.
  DeviceSize get deviceSize {
    final w = screenWidth;
    if (w >= 1024) return DeviceSize.large;
    if (w >= 600) return DeviceSize.tablet;
    return DeviceSize.mobile;
  }

  bool get isMobile => deviceSize == DeviceSize.mobile;
  bool get isTabletSize => deviceSize == DeviceSize.tablet;
  bool get isLargeScreen => deviceSize == DeviceSize.large;

  /// Picks the value matching the current breakpoint, falling back to the
  /// next-smaller value when [tablet]/[large] aren't provided.
  T responsive<T>({required T mobile, T? tablet, T? large}) {
    switch (deviceSize) {
      case DeviceSize.large:
        return large ?? tablet ?? mobile;
      case DeviceSize.tablet:
        return tablet ?? mobile;
      case DeviceSize.mobile:
        return mobile;
    }
  }

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
