import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/secure_storage.dart';
import 'app_colors.dart';

const _kThemeModeKey = 'theme_is_dark';

/// Whether dark mode is active. [AppColors.applyMode] is called synchronously
/// whenever this changes — by the time any widget observes the new state and
/// rebuilds, the static color fields it reads are already correct.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, bool>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<bool> {
  SecureStorageService get _storage => ref.read(secureStorageProvider);

  @override
  bool build() {
    // The persisted value is loaded synchronously before runApp (see
    // main.dart) and handed in via ProviderScope overrides, so this initial
    // build value is only a fallback for tests/hot-reload.
    return AppColors.isDark;
  }

  Future<void> toggle() => setDark(!state);

  Future<void> setDark(bool dark) async {
    AppColors.applyMode(dark);
    state = dark;
    await _storage.write(_kThemeModeKey, dark.toString());
  }

  static Future<bool> loadPersisted(SecureStorageService storage) async {
    final saved = await storage.read(_kThemeModeKey);
    return saved == 'true';
  }
}
