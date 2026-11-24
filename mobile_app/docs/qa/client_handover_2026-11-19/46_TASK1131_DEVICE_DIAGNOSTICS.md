# Task 113.1 — Real-device diagnostics workflow

**Status: BLOCKED, not resolved.** No Android device or ADB on the development machine. Registered-face rejection is still unexplained; no device timings exist. This task delivers the tooling and the test protocol so the user can produce the evidence.

## 1. Debug-only diagnostics panel
- Off by default (`faceDiagnosticsEnabledProvider` = false). `main.dart` enables it only when `kDebugMode && const bool.fromEnvironment('FACE_DIAGNOSTICS')` — a debug build started with `flutter run --dart-define=FACE_DIAGNOSTICS=true`. In release, `kDebugMode` is a constant false, so the panel cannot appear. A test asserts `main.dart` is the only place that can switch it on.
- Where: a speed icon in the Face ID Check app bar (live timings), and a sheet shown automatically after each clock punch with the full report and a **Copy Diagnostics** button.
- Contents (nothing else): stage; sanitised failure category; model initialisation (or "cached"); camera lookup / ready / stream-started / first frame / first detection result (ms from opening); liveness duration; still capture, preprocessing and inference sums; capture-finished time; **descriptor length only**; backend response ms; total ms.
- Never shown/stored/logged: images, frames, descriptor values, tokens, names, ids, or server message text (refusals are reduced to a fixed category: lockout/attempt cap, identity mismatch, low-confidence hard block, backend liveness, replay, registration unavailable, network, server error, authentication, cancelled, other). Tests cover this, including a message containing a name/email.
- The repo's static scan (no debug flags / logging inside the face and clock code) still passes; the switch lives in `main.dart`.

## 2. Preprocessing comparison (web vs mobile)
- **CLAHE**: byte-for-byte equal to web `clahe.ts` (existing fixture test, fixtures generated from web code incl. partial tiles, dark, bright, 1×1). It is applied on web and mobile for both registration and verification, so it is not a mobile-only difference.
- Detector decode + NMS, landmark post-processing, dlib alignment box and clipping, frontality, quality gate, eye-occlusion, consistency (0.35) and averaging: equal to web fixtures.
- **Not provable without a device/browser**: canvas resampling (`drawImage` downscale to 224/112/150) vs the Dart bilinear sampler; browser JPEG/YUV handling vs Android's; real captured-still orientation. Residual risk is small per-pixel difference, not a different algorithm. No preprocessing was removed or changed.
- Still orientation: the Android plugin does not mirror, EXIF/rotation is baked, nothing flips (tests). On the phone, confirm by the diagnostics run below.

## 3. Native inference concurrency (code review + tests)
- One interpreter + one worker isolate per network, created once per app session (`faceApiNetsProvider`; test: three reads → one load). The three networks load sequentially, not in parallel; changing that was not done without a measured gain (device timing needed: "model initialisation").
- Each network's calls are chained (`_Net._queue`), so an interpreter is never entered concurrently; the pipeline awaits each stage in order; one pipeline per capture; `_stopped` prevents a second liveness-pass; `_punchInFlight` prevents duplicate punches.
- New: a per-capture session token. If the screen is closed or retried while models load or frames are analysed, the capture stops asking for more stills, produces no result and writes no state (tests: dispose during pending models → no error; cancelled capture stops after one still).
- Needs a device: interpreter behaviour under background/resume and rapid open/close, and absence of native leaks.

## 4. Staging verification protocol (authorised account, existing registered face)
1. Debug build with `--dart-define=FACE_DIAGNOSTICS=true`, staging backend, one test employee that already has an approved registration (made on web).
2. Make ONE clock-in verification on the phone; tap Copy Diagnostics; send that text only.
3. Ask the authorised backend team to open the matching verification-attempt record for that single attempt and report: descriptor length stored vs submitted; which registration row was used (is it the expected active one); outcome category (match / mismatch / low-confidence band 0.55–0.60 / liveness / cap / replay); and the distance, communicated to the developer only (never in the mobile UI).
4. Interpretation: submitted length ≠ 128 or ≠ stored → incompatible/legacy registration; distance ≈ 0.55–0.62 with web registration → marginal reference or still orientation/resampling drift; distance ≫ 0.7 → wrong person/pipeline fault (then compare a web-captured vs mobile-captured descriptor of the same person offline, authorised data only).
5. Stop after the first failure; do not repeat (server caps at 5 failures per 15 minutes).

## 5. Device timing sheet (to fill from Copy Diagnostics; cold = app just started, warm = second open)
Record: device model, Android version, RAM, build mode, network. Per run: camera ready, first frame, first detection, liveness, still capture sum, preprocess sum, inference sum, descriptor length, backend ms, total. Take ≥ 5 cold and ≥ 10 warm runs; report median and p95; targets are in Task 113 Phase 11. Debug builds are slower than release; also run a `--profile` build for representative numbers. Optimise only the stage the numbers show is slowest.

## 6. Final acceptance checklist (all required before closing)
Existing registered face verifies on mobile; web→mobile; mobile→web; Android timings measured; wrong face rejected; liveness failure rejected; lockout enforced; no regressions. **None of these has been run.**

## 7. Results
Full suite 4176 passed, 320 skipped, 0 failed; `dart analyze` 7 baseline infos.
