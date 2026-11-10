import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'app/app.dart';
import 'core/network/api_client.dart';
import 'core/security/secure_storage.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/employees/presentation/id_card/id_card_text.dart' show registerIdCardFontLicenses;
import 'features/facial_recognition/face_api/face_api_licence.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerIdCardFontLicenses(); // bundled Noto fonts (SIL OFL 1.1)
  registerFaceApiLicense(); // face-api.js models (MIT)

  // Portrait-only on native until tablet layout is added (no-op on web)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Apply the persisted theme before the first frame so there's no
  // light-mode flash for users who last chose dark mode.
  final isDark = await ThemeModeNotifier.loadPersisted(SecureStorageService());
  AppColors.applyMode(isDark);

  // On web the browser's native cookie stack handles auth cookies automatically.
  // On native, persist cookies across app restarts using the file system.
  final CookieJar cookieJar;
  if (kIsWeb) {
    cookieJar = CookieJar();
  } else {
    final appDir = await getApplicationDocumentsDirectory();
    cookieJar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage('${appDir.path}/.cookies/'),
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        cookieJarProvider.overrideWithValue(cookieJar),
      ],
      child: const RoyalHrmsApp(),
    ),
  );
}
