import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// The blue app bar for pushed detail screens (back arrow + title + actions).
///
/// It is the shell's `AppTopBar` blue treatment — [AppColors.primary] fill, white
/// icons, the same bold `AppTextStyles.h4` title, `kToolbarHeight`, white status
/// bar icons — in a standard [AppBar] so a back button, actions and a [bottom]
/// (e.g. a TabBar) work. Screens inside the dashboard shell get the shell's own
/// bar; use this one only where a screen brings its own header (see
/// `shellDetailRouteHasOwnAppBar`).
class BlueAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BlueAppBar({super.key, required this.title, this.actions, this.bottom, this.onBack});

  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  /// Defaults to popping the route.
  final VoidCallback? onBack;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: Colors.white,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.h4.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      actions: actions,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      bottom: bottom,
    );
  }
}
