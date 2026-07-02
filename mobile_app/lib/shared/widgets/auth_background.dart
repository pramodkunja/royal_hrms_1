import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// Full-bleed background image shared by every authentication screen (login,
// forgot password / OTP / reset). This only supplies the backdrop behind
// [child] via a Stack — it never wraps content in its own scroll/flex logic,
// so it cannot introduce overflow; each screen keeps its own
// SafeArea/SingleChildScrollView exactly as before.
class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Source image is 4912×4912 (~14MB) — cap the decode target to the
    // device's physical width so it isn't decoded at full resolution on
    // every phone (avoids unnecessary memory/jank for a background photo).
    final cacheWidth =
        (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio)
            .round();

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/login.jpg',
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          errorBuilder: (_, __, ___) => Container(color: AppColors.primary),
        ),
        // Light tint only — just enough for white text contrast near the
        // top; the rest is left clear so the photo actually reads instead
        // of drowning under a solid blue wash.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0.50),
                AppColors.primary.withValues(alpha: 0.22),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
