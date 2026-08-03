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

  // ─── Environment URLs ──────────────────────────────────────────────────────
  // Must be `localhost`, not `127.0.0.1` — the backend sets SameSite=Lax
  // cookies (see apps/accounts/views.py), and `flutter run -d chrome` serves
  // the app from `http://localhost:<port>` by default. Browsers treat
  // `localhost` and `127.0.0.1` as different sites; a SameSite=Lax cookie set
  // by one is silently dropped on requests to the other, which is exactly
  // what breaks the whole auth flow with "credentials were not provided"
  // errors despite login appearing to succeed. This mirrors a rule already
  // established for the web frontend for the same reason.
  static const String localBaseUrl = 'http://localhost:8000/api';
  static const String productionBaseUrl = 'https://royalhrms.nxsys.in/api';

  /// The active base URL for [current]. This is the only place the app
  /// resolves which backend to talk to.
  static String get baseUrl {
    switch (current) {
      case Environment.local:
        return localBaseUrl;
      case Environment.production:
        return productionBaseUrl;
    }
  }
}
