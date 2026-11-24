# Read-only security advisory audit — resolved dependencies (2026-11-24)

Scope: the **retained** `pubspec.lock` (after the four approved updates) and the **Android release runtime classpath** resolved by Gradle. No packages, Gradle files, source or settings were changed. Only package names/versions were sent to the advisory services.

## Sources
1. OSV.dev (aggregates the GitHub Advisory Database, incl. the Pub and Maven ecosystems) — batch query by exact name+version: **167 hosted Pub packages**, **102 Maven artifacts** from `:app releaseRuntimeClasspath`.
2. pub.dev package-advisory API — all 167 hosted packages (cross-check; lists advisories for any version, so each was compared with the locked version).
Not covered: Dart/Flutter SDK itself, iOS/macOS native pods, build-tooling (AGP/Gradle/Kotlin), the Play-services/ML Kit binary SDKs beyond what Maven advisories list, and unreported/zero-day issues. This is an advisory-database lookup, not a penetration test or code audit.

## Result A — Dart/Flutter packages: **no confirmed vulnerabilities**
OSV: 0 of 167 affected. pub.dev lists advisories on three packages, none affecting the locked versions:
| package (locked) | advisory | fixed in | affected? |
|---|---|---|---|
| archive 4.0.9 | GHSA-9v85-q87q-g4vg (path traversal, CVE-2023-39139), GHSA-r285-q736-9v95 (filename spoofing, CVE-2023-39137) | 3.3.8 | **No** (locked version is newer) |
| dio 5.9.2 | GHSA-9324-jv53-9cc8 / GHSA-jwpw-q68h-r678 (CRLF via method string, CVE-2021-31402) | 5.0.0 | **No** |
| http 1.6.0 | GHSA-4rgh-jx4f-qfcq (header injection, CVE-2020-35669) | 0.13.3 | **No** |
The four updated packages (url_launcher, uuid, image_picker, flutter_native_splash) have no advisories.

## Result B — Android native (Maven) dependencies: **1 confirmed advisory**
| artifact | version | advisory | severity | fixed in |
|---|---|---|---|---|
| com.google.guava:guava | 33.5.0-android | **GHSA-xxph-c9ww-hj94** (CVE-2026-102554) — `CompactHashMap/CompactHashSet/MapMakerInternalMap` Java native deserialization allocates memory from an attacker-controlled size (CWE-400/502/770) | GitHub: **High** (CVSS 3.1 vector AV:N/AC:H/PR:N/UI:N/S:U/C:N/I:N/A:H — availability only; no confidentiality/integrity impact) | **33.7.2** (affected 4.0 ≤ v < 33.7.2) |
- Dependency chain: pulled in by the `camera_android_camerax` plugin (0.6.30) module declaring Guava 33.5.0-android.
- Exposure assessment (judgement, not proof): exploitation needs the app to run Java `ObjectInputStream` deserialization of attacker-supplied data into those Guava collections. Royal HRMS Dart code does not do this and the CameraX plugin uses Guava for internal futures; I found no evidence of an exploitable path, and the impact is a memory-exhaustion crash, not data exposure. Treat as **low practical risk, but a confirmed advisory against a shipped library**.
- Remediation options (none applied; need your approval): (1) upgrade `camera`/`camera_android_camerax` (0.7.x — a protected face-pipeline dependency, needs numerical + device acceptance) if the new plugin pins Guava ≥ 33.7.2 (not verified); (2) a Gradle dependency constraint forcing Guava ≥ 33.7.2 in `android/app/build.gradle.kts` (small, but a Gradle change outside this approval; test camera/ML Kit on device); (3) accept and re-check when camera is next upgraded.
All 101 other Maven artifacts: no advisories.

## Result C — discontinued packages (not vulnerabilities)
`flutter_secure_storage_macos` and `js` remain (macOS/web-only, via flutter_secure_storage 9.x); no advisories; see the maintenance report.

## Rollback set
`docs/qa/client_handover_2026-11-19/rollback_2026-11-24/` (pubspec.lock before/after, pubspec.yaml, Gradle/manifest copies, `pub outdated` and Gradle classpath snapshots, README with restore steps; secrets such as `key.properties` excluded). The maintenance report is `49_BUILD_DEPENDENCY_AUDIT.md`.

## Status
Confirmed vulnerabilities: **1** (Guava, High-rated, availability-only, low practical exposure). No upgrades applied. Physical-device acceptance, Task 113.3 performance verification and production release approval remain pending.
