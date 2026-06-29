import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'app/app.dart';
import 'core/network/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-only on native until tablet layout is added (no-op on web)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

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
