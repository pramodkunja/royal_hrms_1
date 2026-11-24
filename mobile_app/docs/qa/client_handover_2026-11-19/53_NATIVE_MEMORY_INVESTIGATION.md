# Native memory growth — controlled investigation (no fix implemented)

**Status:** root cause **not yet established**; the Guava A/B device comparison is **BLOCKED** by the production-isolation rule (see §4). Static review and the evidence already captured point to **per-session native ML Kit face-detector creation** as the leading suspect. Nothing was fixed; no Git commands; nothing uploaded/deployed.

## 1. Preserved state (before any change)
| item | value |
|---|---|
| Installed build on device (B, Guava 33.7.2-android, profile, debug-signed) | SHA-256 `6a7263b67f545f06705813372ac29e4fd1c808289c1b78d1b0865fa2dc5bbf39` (hash of the APK pulled from the device equals the saved copy) |
| `android/app/build.gradle.kts` (patched) | `48902d9661fd1833c051315d2474f5afeb0d999cdbc66495ca44edee314b2930` |
| `pubspec.yaml` / `pubspec.lock` | `b401fcdc…e7ff` / `44373fa1…28e4` — unchanged throughout (re-verified at the end) |
| Resolved graphs | `rollback_2026-11-24/guava_step/releaseRuntimeClasspath.{before,after}.txt` |
| Copies | `…/guava_step/app_build.gradle.kts.{before_guava,after_guava}`; APKs in `<workspace>/diag_builds/` (`B_…` and `A_…_DO_NOT_RELEASE`) |

## 2. Comparison builds (prepared; A NOT installed)
- **A — Guava 33.5.0-android** (pre-remediation, **diagnostic only, never release**): built by temporarily using the `before_guava` Gradle file. Verified: `dependencyInsight` → `guava:33.5.0-android`; resolved release graph **identical to the original pre-Guava snapshot** (no differences); applicationId `com.royalhrms.app`, versionCode 11, certificate SHA-256 `38eabe8f…c128` (same debug cert as the installed app, so in-place install would work). SHA-256 `a27c02a1ea32462ba21478f2eeb92dbce7065ccbaca8015fc5c1e0ff5b17e9f4`.
- **B — Guava 33.7.2-android**: A vs B graph differences are exactly `guava 33.5.0→33.7.2`, `error_prone_annotations 2.41.0→2.50.0`, `jspecify 1.0.0→1.0.1`.
- Restored afterwards: `build.gradle.kts` hash back to `48902d96…` (verified), `dependencyInsight` → 33.7.2-android, B rebuilt (profile APK rebuild hash differs from the original — builds are not byte-reproducible; the device still holds the original B).

## 3. Source review — scanner resource ownership (evidence, not conclusions)
| resource | owner / location | lifecycle observation |
|---|---|---|
| `CameraController` | `face_capture_controller.dart:222-228` created per `start()` (`ResolutionPreset.medium`, NV21); torn down `:743-753` (`stopImageStream` guarded, then `dispose()`) | created and disposed once per session; logs: every camera open is followed by a camera-service disconnect |
| Camera image stream | `:245` `startImageStream(_onFrame)`; `_onFrame` `:268-304` drops frames while busy (`_processingFrame`) | bounded; per frame the CameraX plugin builds `ImageProxy`/`PlaneProxy` objects and an NV21 buffer (`camera_android_camerax-0.6.30 lib/src/android_camera_camerax.dart:1296-1384`); `dispose` (`:526-532`) clears the analyzer but does not close its `StreamController` |
| **ML Kit `FaceDetector`** | `face_capture_controller.dart:232` `FaceDetector(...)` **new per session**; `:754` `await _detector?.close()` | plugin: `google_mlkit_face_detection-0.13.2` Dart `face_detector.dart:16` (id = timestamp), `:39` close → Java `FaceDetector.java:30` `instances` map, `:60-70` detector created lazily on the first frame, `:227-234` `closeDetector` removes it. ML Kit bundled `com.google.mlkit:face-detection:16.1.7` |
| TFLite descriptor nets | `faceApiNetsProvider` (`:~118`): non-autoDispose, loaded once per process | **not** re-created per session (no per-session model loads of our nets in the logs) |
| Controller | `faceCaptureControllerProvider` autoDispose (`:759`); `ref.onDispose(_teardown)` (`:164`) | torn down when the route pops |
| Lifecycle | `face_capture_bottom_sheet.dart:79-100` observer → `retry()` on resume | teardown then start (no double init observed) |
| `_teardown` ordering | `:743-755` | `camera.dispose()` is not inside the `try/catch`; if it threw, `_detector.close()` would be skipped. **No evidence of this**: no "Unhandled Exception" in any captured logcat |
Not evidenced as defects: duplicate initialization, listener/timer leaks, consent-screen path (negative control: no growth).

## 4. Device phase — BLOCKED (production isolation)
Procedure followed before opening the (patched) app: airplane mode enabled by ADB; verified **effective** (`airplane_mode_on=1`, `Active default network: none`, ping `Network is unreachable`, DNS `unknown host royalhrms.com`, Wi-Fi disabled). Result: the app shows a full-screen **"No Internet Connection"** overlay and every data screen is empty; the scanner entry points (Profile ▸ Face ID, Clock In, HR registration, onboarding) are all gated on server data (`ProfileFaceIdSection` hides itself when the status request fails). **The scanner cannot be reached safely while isolated**, so per the instructions device testing stopped. No taps were made while offline; no login/logout/punch/submission occurred; session intact. After confirming the patched build was still installed (`lastUpdateTime` unchanged, hash identical) and nothing was pending, airplane mode was disabled and connectivity verified. A was never installed; the vulnerable build was never on the device.

## 5. Evidence already captured (Option C logs)
Per camera session the logs show ML Kit loading its **bundled face-detector model set** (`face_detector_v2_jni.cc`: blazeface, fssd_25_8bit_v2, fssd_fastgray, contours, left/right-eye-closed, joy, LMprec, anchors…) and creating ~8–10 TFLite/XNNPACK interpreters ("Replacing 65 out of 65 node(s) with delegate (TfLiteXNNPackDelegate)"):
| log | camera opens | detector model loads (blazeface) | XNNPACK interpreter creations |
|---|---|---|---|
| 10 cycles (hold 0.8 s) | 4 | 5 | 26 |
| 10 cycles (hold 1.2 s) | 5 | 6 | 48 |
| 3 lifecycle runs | 5 | 3 | 22 |
So there is ~1 detector instantiation (10 native models, ~8 interpreters) per camera session — the same granularity as the memory step (≈13–29 MB). The Java heap stayed flat (≈10–15 MB) and Graphics flat (≈42 MB): the growth is in the malloc/native heap. XNNPACK repacks weights per interpreter, which is a plausible source of tens of MB per detector.

## 6. The measurement discrepancy — individual measurements
Native heap (KB) from `dumpsys meminfo` and what happened between readings:
| reading | native | total PSS | work since previous reading |
|---|---|---|---|
| fresh process, idle (cold start) | 31,236 | 224,273 | — |
| R1 | 238,296 | 433,553 | 1 untimed session + 10 attempts (log: ≥5 camera opens) incl. first-time model/runtime loading |
| R2 (batch 2 start) | — | 431,560 | — |
| R3 | 383,760 | 575,561 | 10 attempts, 5 opens |
| R4 | 514,808 | 698,928 | 10 attempts (opens not logged) |
| R5 | 652,108 | 830,758 | 10 attempts (opens not logged) |
| after `RUNNING_CRITICAL` trim + 20 s idle | 652,172 | 824,756 / 825,376 | none |
| after 20 consent-only open/close | 646,912 | 816,748 | **no camera**: −5.3 MB |
Steady-state increments: +145,464 / +131,048 / +137,300 KB per 10 attempts ⇒ **≈13–14.5 MB per attempt**, ≈**26–29 MB per attempt that actually opened the camera** (5 of 10 did in the logged batches). The earlier "9.2 MB/session" came from dividing the 414 MB (238→652) by **45**, a denominator that counted the 11 attempts already included in the 238 MB baseline, the 20 consent-only attempts (which add nothing) and 3 lifecycle runs; the correct denominator for the 414 MB is the 30 attempts of batches 2–4. The earlier report's "13–26 MB" was per attempt vs per camera-open respectively. Opens for batches 4–5 were assumed equal to the logged ones (5/10); that is an assumption.
```
native heap (MB)   0        200        400        600
fresh process      |#
R1 (11 attempts)   |#########################
R3 (+10)           |###############################################
R4 (+10)           |###############################################################
R5 (+10)           |##################################################################
trim + idle        |##################################################################   (not released)
consent-only x20   |#################################################################   (no growth)
```
Leak vs allocator caching: reuse would level off after the first sessions; instead every batch adds ~the same amount, no plateau, trim/idle does not return it, but consent-only cycles do not add (so the allocator can both reuse and release). That favours **retention tied to the camera/detector path**, but it is not proof of a true leak: Dart/ML Kit external allocations may also wait for GC/finalizers. Only a heap profile can separate these. Guava was **not excluded** (Java futures could influence retention indirectly); it is simply unmeasured because A could not be run.

## 7. Ranked hypotheses (suspected, unconfirmed)
1. ML Kit bundled face detector (created per session, `:232`) retains native model/XNNPACK memory after `close()` (or closes asynchronously and the allocator keeps the pages). Supported by: per-session model-load log lines, size per step, flat Java heap.
2. camera_android_camerax per-frame native proxy objects/NV21 buffers retained until Dart GC (`:1296-1384`) — would scale with frames per session; testable by session duration.
3. Dart external memory awaiting GC (trim did not reduce).
4. A Guava 33.5/33.7 effect on CameraX future retention — unlikely, untested.

## 8. Recommended next steps (need your approval; nothing done)
- **Measure without production risk** (choose one): (a) a staging/local API target for a debug/profile build (adds an environment); (b) a throw-away diagnostic app with a different package id and **no INTERNET permission** that runs the same camera + `FaceDetector` open/close loop automatically, built once with Guava 33.5.0 and once with 33.7.2 (new install, not in-place — needs approval); (c) heap profiling (`heapprofd`/perfetto on the debuggable app) of 10 scanner sessions to see the allocating call stacks.
- **Minimal fix candidates if confirmed:** reuse one `FaceDetector` per app process (create once, close on app exit/low memory) instead of per session — also removes ~10 model loads from every scan start (likely a first-detection speed-up); only if the profile shows it is the retainer. Alternatives: ensure `close()` completes before the next `start()`; lower `ResolutionPreset`/frame rate if (2) is proven.
- **Expected impact:** none on descriptors, liveness rules, thresholds or camera geometry (detector settings unchanged); first-detection latency may improve; risk = detector shared across sessions must be reset between sessions (tracking ids) and closed safely.
- **Regression risks:** tracking-id continuity logic (different-face detection), cancellation races, lifecycle restart.
- **Proposed acceptance criteria:** with the same procedure (fresh process, cancel at fixed time), native heap growth ≤ 1 MB per scanner session over 30 sessions (or a plateau after ≤ 3), no change in consent-only baseline, `NoSuchMethod/ClassNotFound/Fatal/ANR` = 0, descriptors/liveness tests unchanged (4187 pass), first-detection time not worse, repeated on A and B builds.

## 9. Restoration and confirmations
Gradle constraint restored (hash verified); pubspec files unchanged (hashes verified); the patched build is the only build on the device (original B, hash verified); airplane mode off and network restored after confirming no pending submissions; the vulnerable build A was never installed; no unrelated source changes. The diagnostic logs referenced above are session-local; summary figures are reproduced here. Production release approval remains pending; PERMISSION UX, duplicate headers, stray glyph and liveness behaviour were not touched.
