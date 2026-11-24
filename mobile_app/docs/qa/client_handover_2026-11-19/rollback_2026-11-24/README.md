# Rollback set — build/dependency maintenance (2026-11-24)
- `pubspec.lock.before` is the lock BEFORE the four approved updates (url_launcher 6.3.2, uuid 4.5.3, image_picker 1.2.2, flutter_native_splash 2.4.7); `pubspec.lock.after` is the retained lock. To roll back: copy `pubspec.lock.before` over `pubspec.lock` and run `flutter pub get`.
- `pubspec.yaml.before` equals the current one (unchanged by the maintenance).
- Android Gradle/manifest files are copied for reference (unchanged). **Excluded on purpose:** `android/key.properties`, `local.properties`, keystores (secrets/machine paths).
- Baseline bundle (before updates): SHA-256 5022856997ecfcca40c1546d8c6a2c80d2c65ef0f4a1260e8983eb60482da451, 146,600,847 B (binary not stored here). Current bundle: feba4a77a1fd87beb65d4b13c50016e785c1bedda87274664058d10569254fcb, 146,600,994 B.

## Guava remediation step (added later)
`guava_step/app_build.gradle.kts.before_guava` is `android/app/build.gradle.kts` BEFORE the Guava constraint. To roll back: copy it over `android/app/build.gradle.kts` (this removes the `dependencies { constraints { … } }` block). Dependency snapshots before/after are in the same folder.
