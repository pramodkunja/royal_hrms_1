# Device acceptance — Option C (non-destructive), Moto G06 Power

Device: Motorola Moto G06 Power, Android 15 (API 35), arm64-v8a, ~3.8 GB RAM. Build: Guava-fixed **profile** APK, `com.royalhrms.app` 1.0.2 (11), debug-signed. No source or API-config changes. No Git commands. Nothing uploaded/deployed.

## Pre-install checks and installation
- Application ID identical (`com.royalhrms.app`). Signing certificate SHA-256 of the installed APK and the new APK are **identical** (`38eabe8f…c128`, debug key). Version 10 → 11 (upgrade).
- `adb install -r` (in-place; no uninstall, no data/cache clear): **Success**, app data preserved (the existing session and data were still present afterwards). Observation: package flags still show DEBUGGABLE after the update.

## Safety analysis (before each test)
The app is on production and logged in. Code inspected: the geofence check is read-only on the server; the Clock In button can punch immediately if Face ID is not mandatory, and Clock In/Registration both submit data as soon as a capture completes. Therefore **Clock In/Out was never tapped**. The only scanner entry used was Profile → Face ID → "Update My Face" (consent screen first; data is submitted only if the whole blink+turn+capture finishes). Every camera session was ended with Cancel by timed taps; the Face ID status stayed "Registered / Approved" after every run (no pending state appeared). Normal app launches may refresh the session token automatically (not a login, but a production call).

## Results
| # | Test | Expected | Actual | Result | Evidence / limitation |
|---|---|---|---|---|---|
| 1 | Cold startup | Launches, dashboard shown | 6 cold starts: 2549, 1817, 1789, 1703, 1708, 2380 ms (`am start -W` TotalTime; first is the post-install run). Median ≈ 1.8 s | PASS | profile build; production network |
| 2 | Camera permission DENY | Clear message, no crash | System dialog shown; after "Don't allow": "Camera access permission was denied." with Try again + Cancel; app stable | PASS | UX finding F3 below |
| 3 | Camera permission GRANT | Scanner starts camera | Granted with `pm grant` (OS had fixed the denial, so no dialog); Try again then opened the camera | PASS | system-dialog "allow" path not exercised |
| 4 | Camera init + preview | Camera opens, preview paints | cameraserver logs "Camera 1: Opened. Client: com.royalhrms.app"; preview region mean luma 114 / stdev 67 (not blank) | PASS (native check) | preview content not viewed or stored (privacy); geometry/mirroring/face alignment NOT verified |
| 5 | Scanner open / close / Cancel | Opens full-screen "Face ID Check"; consent first for registration; Cancel/back returns to profile | Consent screen → agree → camera; Cancel and back returned to the Face ID tab each time | PASS | observed UI: shell header plus Face ID Check header both visible (F4) |
| 6 | Repeated open/close | No crash/ANR/leak | 50 open/close attempts (20 camera cycles with timed cancel + 20 consent-only + others); ≈15 camera opens, each followed by a camera disconnect; zero crashes/ANRs | PASS (stability) / see F1 | |
| 7 | Background/foreground | Survives, camera restarts cleanly | Consent screen survived HOME→resume; camera session ×3 HOME→resume: camera re-opened and was disconnected, process alive, no errors | PASS | |
| 8 | Memory | Stable across cycles | **Native heap grew 238 → 652 MB over ~45 scanner sessions; not released after `RUNNING_CRITICAL` trim or 20 s idle** (consent-only ×20: no growth). Fresh process idle: PSS 224 MB, native 31 MB | **FINDING (F1)** | cause not isolated |
| 9 | Task 113.3 diagnostics | Panel + timings | This build has no `FACE_DIAGNOSTICS`; the data appears only after a punch/capture path | **BLOCKED** | needs diagnostics build + staging |
| 10 | Logcat scan (cold start, 30 camera cycles, 3 lifecycle runs) | None of the listed errors | `NoSuchMethodError` 0, `NoClassDefFoundError` 0, `ClassNotFoundException` 0, `VerifyError` 0, `FATAL EXCEPTION` 0, `ANR in` 0, `OutOfMemory` 0, `Fatal signal` 0 | PASS | benign: "BufferQueue has been abandoned" and camera-HAL "No such device(-19)" lines at camera close |
| 11 | Frame rate / jank | — | `dumpsys gfxinfo` reports 0 frames for Flutter's own renderer | NOT TESTED | needs DevTools/profile overlay |
| 12 | Login/logout, registration, verification, Clock In/Out, wrong-face, lockout, liveness-failure | — | Not performed (prohibited) | NOT TESTED | |

## Findings (no code changed — need your approval)
- **F1 Native memory growth per camera session (needs investigation).** ~13–26 MB native per camera session, linear, not reclaimed. Consent-only cycles don't grow, so it is in the camera/ML Kit/stream path (or the models re-created per session); the Guava change is Java and cannot cause native growth, but I could not attribute it (a pre-Guava A/B build would need a Gradle revert). Practical impact: a user doing many scans in one process could eventually hit low-memory kills; a few scans/day are unlikely to. Suggested next step: reproduce with Dart DevTools/`dumpsys meminfo` on a build with and without the Guava constraint, then check detector/stream disposal.
- **F2 Liveness passed quickly with a live face.** On the first (untimed) attempt the screen reached "Capturing and checking your face…" within ~3 s with no deliberate challenge, i.e. real-person motion can satisfy blink+turn fast. I cancelled before completion and the registration state did not change. Practical rule: don't leave the scanner open on a live production account.
- **F3 Permanent denial UX.** After the OS fixes a denial, "Try again" cannot re-prompt and nothing suggests opening Settings.
- **F4 Cosmetic:** shell AppTopBar and the Face ID Check bar both show; denied state shows a black placeholder with a tiny stray glyph.

## What this does and does not establish
Established: Guava-fixed build installs in place, starts, the camera opens/closes repeatedly and across background/foreground, with no NoSuchMethod/NoClassDef/ClassNotFound/VerifyError/fatal/ANR in the logs. **Not established:** face registration, verification, liveness correctness, geometry/mirroring, recognition accuracy, Clock In/Out, Task 113.3 performance, or production readiness — all still pending (they need a staging backend).
