import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// The dark-blue, rounded-bottom-corners "hero" banner used at the top of
/// list/directory screens (search bar, filter button, etc.) — first built
/// for the Employees/Directory screen, reused here so every list screen
/// shares one design instead of each hand-rolling its own container.
///
/// Deliberately does NOT bake in the "stats row overlapping the bottom
/// edge" effect Employees/Assessments use — that trick only works safely
/// when the overlapping widget has a known, fixed height (e.g. a
/// SizedBox-wrapped horizontal ListView). Screens whose stats use a
/// responsive GridView (variable height depending on screen width) build
/// that overlap themselves only when they've confirmed a safe fixed height,
/// and simply stack their stats row below this banner (no overlap,
/// zero layout risk) otherwise.
class BlueHeroBanner extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const BlueHeroBanner({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: child,
    );
  }
}

/// The white search field style used inside a [BlueHeroBanner] — matches
/// Employees' hero search field exactly (white fill, no visible border,
/// rounded, search icon, optional clear button).
InputDecoration heroSearchFieldDecoration({
  required String hintText,
  bool showClear = false,
  VoidCallback? onClear,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: AppColors.textHint),
    prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textHint),
    suffixIcon: showClear
        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: onClear)
        : null,
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}
