# Guava security remediation — GHSA-xxph-c9ww-hj94 / CVE-2026-102554

## 1. Vulnerability and chain
Guava `CompactHashMap`/`CompactHashSet`/`MapMakerInternalMap` Java native deserialization allocates memory from an attacker-controlled size (CWE-400/502/770); GitHub: High, availability-only (CVSS 3.1 AV:N/AC:H/PR:N/UI:N/C:N/I:N/A:H). Affected 4.0 ≤ v < **33.7.2**.
`./gradlew :app:dependencyInsight --dependency com.google.guava:guava` on **debug, profile and release** runtime classpaths: all resolved `guava:33.5.0-android`, introduced by exactly one dependent: **project :camera_android_camerax** (camera plugin 0.6.30). No other module requests Guava.
**Practical exposure (separate from severity):** exploitation needs Java `ObjectInputStream`/`readObject` deserialization of attacker data into those collections. A source search of the app's `android/app/src` and the Android sources of every Flutter plugin in the lock found **no** `ObjectInputStream`/`readObject(`; the Dart code is unaffected. Impact would be a crash (memory exhaustion), not data exposure. Low practical risk; remediated anyway.

## 2. Patched artifact verification
`com.google.guava:guava:33.7.2-android` (the lowest fixed release, Android variant) exists on Maven Central (`repo.maven.apache.org`, a repository already configured: `google()` + `mavenCentral()`): .pom, .jar and Gradle .module all HTTP 200; jar SHA-1 `0e601df8fa35293ad4fa7c6ec4522152d304eb41` equals the published `.sha1`; listed in `maven-metadata.xml`. OSV: 33.5.0-android → GHSA-xxph-c9ww-hj94; **33.7.2-android → no advisories**. The -android (not -jre) variant is kept; minSdk 24 unchanged.

## 3. Exact change (one file)
`android/app/build.gradle.kts` — added before `flutter { … }`:
```kotlin
dependencies {
    constraints {
        implementation("com.google.guava:guava:33.7.2-android") {
            because("GHSA-xxph-c9ww-hj94 / CVE-2026-102554 is fixed in Guava 33.7.2")
        }
    }
}
```
(with an explanatory comment, incl. "remove once camera_android_camerax requires Guava ≥ 33.7.2"). A dependency **constraint**, not `force`/`resolutionStrategy`; applies to the app's debug/profile/release runtime (and compile) classpaths. No change to pubspec.yaml/pubspec.lock (verified identical to the retained copies), Gradle wrapper/AGP/Kotlin/Java, global Gradle settings, .pub-cache, Flutter SDK, or any Dart/face-recognition source. No compiler warning suppression.

## 4. Before / after resolved graph (releaseRuntimeClasspath, 102 Maven artifacts both times)
Only three coordinates changed: **guava 33.5.0-android → 33.7.2-android**; companions requested by Guava 33.7.2's own metadata: `error_prone_annotations 2.41.0 → 2.50.0` and `org.jspecify:jspecify 1.0.0 → 1.0.1` (annotation-only artifacts; no runtime code or API used by the app). `failureaccess 1.0.3` unchanged. Gradle conflict log: "By constraint … fixed in Guava 33.7.2; conflict resolution 33.7.2-android vs 33.5.0-android". The only remaining textual mention of `33.5.0` is the dependency-tree line "33.5.0-android -> 33.7.2-android" (requested → selected). The release bundle's own dependency metadata lists only `33.7.2-android`. Single Guava version → no duplicate classes; no variant conflict. Snapshots: `rollback_2026-11-24/guava_step/`.

## 5. Advisory re-scan (OSV.dev, Maven)
guava 33.7.2-android, error_prone_annotations 2.50.0, jspecify 1.0.1, failureaccess 1.0.3: **0 advisories**. CVE-2026-102554 is **no longer reported** against the resolved Guava version. (Earlier scan: only this one Maven hit among 102 artifacts; Pub packages 0.)

## 6. Verification
- `dart analyze`: 0 errors, 0 warnings, 7 baseline infos (no new).
- `flutter test`: **4187 passed, 320 skipped, 0 failed** (identical to baseline; no test touched). Includes the face numerical-compatibility, camera lifecycle/cancellation, attendance/geofence and navigation tests — these are Dart-level tests and **do not exercise CameraX on a device**.
- Android **profile** build: `flutter build apk --profile` OK (app-profile.apk 224.3 MB; not installed anywhere).
- Android **release** App Bundle: OK, 73 s. `app-release.aab` **146,600,573 B** (previous 146,600,994 B; −421 B), SHA-256 `ec25b31e8168f62fe4e2b3c1b5f10ad3bdef1f03ba63de53709b6a607d2eb35a`; `jarsigner -verify`: jar verified (upload key; no credentials shown); applicationId com.royalhrms.app, version 1.0.2 (11), minSdk 24/targetSdk 36 (Flutter defaults, unchanged); native libs arm64-v8a/armeabi-v7a/x86_64 (24 .so), all 64-bit libs LOAD-aligned ≥ 16 KB; API/HTTPS/permissions untouched. Not uploaded or deployed.

## 7. Compatibility assessment
Guava 33.5.0 → 33.7.2 is a patch-level series on the same -android flavour (backward compatible by Guava's API policy). CameraX uses Guava only for internal futures/utilities; no deprecated Guava APIs are referenced by the app. Risk is low but **not proven on hardware** because the camera path is native.

## 8. Physical-device acceptance — PENDING (nothing installed; no device testing performed)
Procedure for the Moto G06 Power on an authorised **staging** account (needs your approval to install a build, e.g. the profile/release build with the staging API; do not use production punches):
1. Cold start; login; kill/reopen to confirm the existing session survives.
2. Camera permission: deny → message; grant → opens.
3. Face ID scanner initialises (preview upright, oval aligned, no stretch).
4. Register a test account's face (consent → blink + turn → submit); then verify the **existing registered** face.
5. Clock In and Clock Out with Face ID (reversible test employee).
6. Liveness: blink, head turn; try a wrong face (must reject) and a photo of a face on a screen (must fail liveness) — stop on any lockout warning.
7. Preview smoothness; open/close scanner ≥ 10 times; Cancel mid-scan; background/foreground during scan.
8. Photo capture elsewhere in the app (profile photo, image picker).
9. Task 113.3 diagnostics: profile build with `--dart-define=FACE_DIAGNOSTICS=true`, ≥ 5 cold + 10 warm runs, Copy Diagnostics; compare with 7,286 ms best run; confirm no regression and no crash/ANR in `adb logcat` (look for `NoSuchMethodError`/`NoClassDefFoundError` in CameraX/Guava).
Acceptance remains **pending**; Task 113.3 performance verification and production release approval also remain pending.

## 9. Remaining risks
Constraint hides rather than removes the old Guava from the plugin's declaration (remove it once camera_android_camerax requires ≥ 33.7.2). Java-8/unchecked compiler notes and the other deferred maintenance items are unchanged and accepted. Newer Guava releases exist (33.8.0 is jre-only latest); 33.7.2-android was chosen as the minimum patched.

## 10. Rollback
Copy `docs/qa/client_handover_2026-11-19/rollback_2026-11-24/guava_step/app_build.gradle.kts.before_guava` over `android/app/build.gradle.kts`, then `flutter build appbundle --release`. Full rollback set and README: `rollback_2026-11-24/`.
