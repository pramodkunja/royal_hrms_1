import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Deployment targets the app's API base URL can point at. Add a new value
/// here (e.g. `staging`, `qa`) plus its URL constant and a `case` in
/// [ApiConfig.baseUrl] to support another environment later — nothing else
/// in the app needs to change since every API call reads through
/// [ApiConfig.baseUrl] (via [ApiConstants.baseUrl]).
enum Environment { local, production }

/// Centralized API environment configuration.
///
/// [current] is the single switch between environments — change only this
/// line to point the whole app at a different backend. Nothing else in the
/// codebase should ever hardcode a base URL; every API call ultimately reads
/// [baseUrl] (through `ApiConstants.baseUrl`, which delegates here).
class ApiConfig {
  ApiConfig._();

  // ─── The one value to change when switching environments ─────────────────
  static const Environment current = Environment.production;

  /// The environment actually in effect. A release build (`flutter build`/
  /// `flutter run --release`) always resolves to [Environment.production]
  /// regardless of [current] — this is a hard safety net so forgetting to
  /// flip [current] back before cutting a release can never ship a build
  /// pointed at a developer machine's local backend. Debug/profile builds
  /// still honor [current] as before.
  static Environment get resolvedEnvironment =>
      kReleaseMode ? Environment.production : current;

  // ─── Environment URLs ──────────────────────────────────────────────────────
  // Chrome (web) always resolves to `localBaseUrlWeb` below (never
  // `localBaseUrlNative`) — see the `kIsWeb` branch in [baseUrl]. This isn't
  // optional: the backend sets SameSite=Lax cookies (apps/accounts/views.py),
  // and a browser refuses to attach a SameSite=Lax cookie to a cross-site XHR/
  // fetch request. Chrome serves the app from `http://localhost:<port>`, so
  // anything other than `localhost` here (an IP, `127.0.0.1`, a LAN address)
  // is cross-site from the browser's point of view — login itself still
  // succeeds (it doesn't need to read a cookie), but the very next
  // authenticated call goes out with the cookie silently dropped, producing
  // "Authentication credentials were not provided" — i.e. an immediate,
  // confusing forced logout right after a successful login.
  //   - `flutter run -d chrome`: `http://localhost:8000/api` (never edit this
  //     one — see above).
  //   - iOS Simulator (native, but same Mac): also needs `localhost`, so set
  //     `localBaseUrlNative` to `http://localhost:8000/api` while using it.
  //   - Android emulator: `http://10.0.2.2:8000/api` — 10.0.2.2 is the
  //     emulator's alias for the host machine's localhost.
  //   - A physical phone over Wi-Fi: the dev machine's LAN IP (same Wi-Fi
  //     network as the phone), e.g. `http://192.168.x.x:8000/api` — the phone
  //     has no way to resolve "localhost" as this machine.
  // `localBaseUrlNative` is the one you swap between the last three based on
  // which native target you're currently running. Currently set for
  // physical-device-over-Wi-Fi testing (this Mac's LAN IP as of 2026-08-25 —
  // re-check with `ipconfig getifaddr en0` if it's stale, e.g. after
  // reconnecting to Wi-Fi).
  static const String localBaseUrlWeb = 'http://localhost:8000/api';
  static const String localBaseUrlNative = 'http://192.168.0.106:8000/api';
  static const String productionBaseUrl = 'https://royalhrms.com/api/';

  /// The active base URL for [current]. This is the only place the app
  /// resolves which backend to talk to.
  static String get baseUrl {
    switch (resolvedEnvironment) {
      case Environment.local:
        return kIsWeb ? localBaseUrlWeb : localBaseUrlNative;
      case Environment.production:
        return productionBaseUrl;
    }
  }
}
