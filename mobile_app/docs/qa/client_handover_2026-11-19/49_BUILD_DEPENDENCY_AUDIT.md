# Build, dependency and Android compatibility audit (maintenance task)

## A. Environment
Flutter 3.44.8 / Dart 3.12.2 · JDK 21.0.10 (Android Studio JBR) · Gradle 8.14 · AGP 8.11.1 · Kotlin plugin 2.2.20 (Gradle's embedded Kotlin 2.0.21) · compileSdk 36 / targetSdk 36 / minSdk 24 / NDK 28.2 (Flutter defaults, unchanged) · `android.builtInKotlin=false`, `newDsl=false`, Kotlin target-validation=warning (existing; needed by tflite_flutter). App module already compiles at **Java 17** (source/target + Kotlin jvmTarget). Doctor: Android toolchain healthy; only Xcode warning (iOS 27.2 simulator runtime missing, iPhone LAN discovery) — iOS-only, untouched.

## B. Original warnings → source (from a clean verbose release build)
| warning | exact module(s) | root cause | severity | action | status |
|---|---|---|---|---|---|
| `source/target value 8 is obsolete` (-Xlint:-options) | **file_picker 8.3.7** (no Java level set → AGP default 8), **flutter_secure_storage 9.2.4**, **geolocator_android 4.6.2**, **printing 5.14.3** (all declare Java 1.8) | third-party plugin Gradle files compile at Java 8; javac 21 warns | cosmetic (no runtime effect) | none | **deferred**: fixing = upgrading those plugins to versions on Java 11+/17 (file_picker 13, flutter_secure_storage 10/11 — storage migration risk, geolocator 14, printing 5.15 with pdf 3.13). All are on the "no blind/major upgrade" list. |
| `unchecked or unsafe operations` | **google_mlkit_commons 0.11.1** (`InputImageConverter.java`), **google_mlkit_face_detection 0.13.2** (`FaceDetector.java`) | raw generics in plugin Java source | cosmetic | none | **deferred** (fix needs ML Kit 1.x, which touches the face pipeline) |
The app module, camera_android_camerax, image_picker_android, url_launcher_android, connectivity_plus, record, webview, audioplayers etc. (Java 17) and the Java-11 modules (mlkit, pdfx, tflite, speech_to_text, jni) produce no javac warning. Not touched: no global `options.release`/compiler-arg override, no `-Xlint` suppression, nothing under `.pub-cache` or the Flutter SDK. The `-Xlint` notes remain visible on a clean build; incremental builds hide them.

## C. Dependency audit (`flutter pub outdated`: 22 direct, 2 dev, ~70 transitive outdated)
Applied (each changed individually; lock diff = that package's version + hash only; pubspec.yaml unchanged):
| package | before → after | purpose | change notes | risk | decision |
|---|---|---|---|---|---|
| url_launcher | 6.3.2 → 6.3.3 | open links/dialer | fixes `supportsCloseForLaunchMode`; SDK floor raised (Flutter 3.41) | very low | **upgraded** |
| uuid | 4.5.3 → 4.6.0 | capture session ids etc. | adds format-validation APIs only; `v4()` unchanged | very low | **upgraded** |
| image_picker | 1.2.2 → 1.2.4 | photo picking | docs + `pickMultiImage(limit:1)` fix | low | **upgraded** |
| flutter_native_splash | 2.4.7 → 2.4.8 | dev-only splash generator | CLI fixes; not shipped | none | **upgraded** |
Deferred (not applied): **dio 5.11.1 / dio_cookie_manager 3.5.0** (auth, cookies, refresh, uploads — mocked tests cannot prove live behaviour; needs staging pass), **flutter_svg 2.5.0, record 7.2.0, speech_to_text 7.5.0** (native audio/voice not device-verified here), **lottie 3.7.0, image 4.11.0** (image is in the face pipeline: JPEG decode/orientation — must not move without numerical + device checks), cupertino_icons 2.0.0, flutter_lints 6 (would add analyzer notices).
Protected, **breaking/major, separate approval**: camera 0.12.2 (+camera_android_camerax 0.7.6+2), google_mlkit_face_detection 1.0.3 / commons 1.0.3, flutter_riverpod 3.5, go_router 18, flutter_secure_storage 11 (stored-credential migration), geolocator 14, connectivity_plus 7, file_picker 13, pdf/printing 3.13/5.15 (pinned), google_fonts 8/9.
Transitive packages are governed by their parents (no manual changes, no overrides). Security: no advisory lookup against an external database was performed in this task, so no package was classified "security-critical"; none was changed on security grounds. Outdated ≠ insecure.

## D. Discontinued packages
- `flutter_secure_storage_macos 3.1.3` ← `flutter_secure_storage 9.2.4` (macOS implementation only). Not part of the Android build; replaced upstream by `flutter_secure_storage_darwin` in 10+/11.
- `js 0.6.7` ← `flutter_secure_storage_web 1.2.1` (web only). Not part of Android/iOS builds.
Both disappear only by upgrading flutter_secure_storage to 10+/11 — a breaking change that touches the Android token store (and possible migration of stored credentials/sessions). **Deferred**, impact on the shipped Android app: none today.

## E. Files modified
`pubspec.lock` (4 version/hash pairs above). Nothing else: `pubspec.yaml`, Gradle files, manifests, signing, Dart sources unchanged. Backups of the originals: `/tmp/maint_backup/` (pubspec.yaml, pubspec.lock, android/).

## F. Regression results
Baseline (before): 4187 passed, 320 skipped, 0 failed; analyze 7 infos. After: **identical** — 4187 passed, 320 skipped, 0 failed; `dart analyze` 7 infos (same, no errors/warnings). The suite includes the face numerical-equivalence, camera lifecycle, attendance/geofence, auth/API (mocked), navigation, PDF, upload tests. No tests added/removed/altered.

## G. Release bundle
`build/app/outputs/bundle/release/app-release.aab` · built OK (incremental 78 s after the baseline; clean build also OK) · size **146,600,994 B** (baseline 146,600,847 B; +147 B) · SHA-256 `feba4a77a1fd87beb65d4b13c50016e785c1bedda87274664058d10569254fcb` (baseline `5022856997ecfcca40c1546d8c6a2c80d2c65ef0f4a1260e8983eb60482da451`) · applicationId com.royalhrms.app · version 1.0.2 (11) · minSdk 24 / targetSdk 36 · `jarsigner -verify`: jar verified with the upload key (certificate valid to 2054; no credentials shown) · native libs: arm64-v8a, armeabi-v7a, x86_64 (8 each); all 64-bit libs have LOAD alignment ≥ 16 KB (0x4000/0x10000) — 16 KB page-size compatible · API base URL/HTTPS/cleartext config untouched. Not uploaded or deployed.

## H. Stability
Automated parity with baseline; no behaviour code touched; face pipeline, camera, diagnostics gating, thread default (1) unchanged. **Physical-device acceptance not performed** (and Task 113.3 device acceptance is still pending): please smoke-test on the Moto G06 Power — login/session, clock in/out with Face ID, a link open (url_launcher), photo pick (image_picker), a UUID-bearing flow (capture session) — before release.

## I. Deferred
Java-8 plugin warnings (needs file_picker/secure_storage/geolocator/printing majors); unchecked notes (needs ML Kit 1.x); dio/cookie, flutter_svg, record, speech_to_text, lottie, image minors (targeted staging tests); all majors in C; discontinued transitives (secure-storage migration); iOS simulator/runtime setup (manual, Xcode > Settings > Components).

## J. Decision
Implementation: complete, minimal (4 patch/minor lock updates). Automated regression: pass, equal to baseline. Release compilation: pass. Physical device: not done. Production readiness: **not asserted** — pending device smoke test and the existing release blockers; no deployment. Further approval is needed for every deferred item.
