# Task 113.2 — Performance from real-device diagnostics

Device run (one successful verification; backend accepted, category none, descriptor length 128): model init 255 ms · camera ready 188 ms · first frame 555 ms · first detection 906 ms · liveness 1319 ms · still capture sum 1388 ms · preprocessing sum 968 ms · inference sum 1073 ms · capture finished 7895 ms · backend 1162 ms · total 9057 ms.

## 1. Accounting for the 7895 ms capture (derived, not measured)
The sequential capture of 3 frames was: stills 1388 + preprocessing 968 + inference 1073 + 2 × 250 ms spacing = ~3.93 s (a 4th retry frame would add more). So the capture phase after liveness ≈ 3.9 s and everything before it ≈ 7895 − 3929 ≈ **3.97 s**, of which detection (0.9 s) and liveness (1.3 s) explain ~2.2 s. The remaining **~1.7 s is the pre-liveness framing phase** (10 stable single-face frames at ML Kit's frame rate, plus the user lining up) — it had no timer. The new `liveness_started` / `liveness_passed` / `stop_stream_ms` / per-still and per-network timers split this precisely on the next run; the figures above are an inference from the sums, not a measurement.

## 2. Confirmed bottleneck
The three stages ran strictly one after another (still → worker prep → inference → 250 ms wait → next still), so ~2 s of preprocessing + inference and the spacing waits sat on the critical path while the camera was idle. Camera init (188 ms) is not a bottleneck and was not touched.

## 3. Changes
1. **Overlapped capture** (`FaceApiPipeline.capture`): while one still is analysed the next is already being taken. Same required frame count (3 / 4), same per-frame quality gate, same 0.35 consistency rule, same averaging — descriptors are averaged in attempt order, so the result equals a one-at-a-time capture. No more stills are started than could be needed (good + in-flight < target; a failed frame frees a slot; attempts still capped at 4× target). Consecutive stills are never started closer than the web's 250 ms *interval* measured after the previous still finished (the still itself takes longer, so the wait normally vanishes).
2. **Quality gate before the descriptor**: the recognition net now runs only for frames that pass the gate and eye-occlusion check (outcome identical; failed frames no longer pay for the largest inference).
3. **Preprocessing**: faster bilinear scaler (per-column positions/weights computed once; **byte-identical** to the old per-pixel version — test against a reference implementation), CLAHE per-column tile lookups hoisted (**byte-identical**: existing web fixtures still pass), no extra buffer copy when no downscale is needed. JPEG decode is still the pure-Dart `image` decoder; replacing it (e.g. the platform codec with DCT downscaling) would change pixels and cannot be proven equivalent without a device, so it was **not** done.
4. **Not changed**: models, threshold, mirroring/rotation/alignment, descriptor size, liveness, sample counts, backend calls, camera/Face ID screen.
5. **TFLite threads (A/B only)**: interpreters currently run with the library default (single thread — every verified run so far). A debug/profile-only switch `--dart-define=FACE_TFLITE_THREADS=4` (needs `FACE_DIAGNOSTICS=true`) allows a device benchmark; the default stays 1 until the numbers and descriptor equality are checked on the phone. No delegate (GPU/NNAPI) was enabled.
6. **Backend 1162 ms**: the app sends one punch request carrying the descriptor; the only earlier requests are the status/registration lookups before the camera opens (not in the 9057 ms total). Nothing avoidable on the Flutter side; the remainder is network + server (distance check, anti-spoofing writes, audit rows, attendance update) and is outside Flutter.

## 4. Expected effect (projection — NOT a measurement)
Overlap hides most preprocessing/inference of the first frames behind the next stills and removes the spacing waits: capture ≈ stills (~1.4 s) + one frame's prep+analysis (~0.7 s) ≈ 2.1 s instead of ~3.9 s, i.e. total ≈ 7 s. Reaching 5–6 s additionally needs the framing phase (~1.7 s) and/or inference (threads A/B) to shrink; decide from the new timers.

## 5. Profile-mode workflow (diagnostics never in release)
`flutter run --profile --dart-define=FACE_DIAGNOSTICS=true` (optionally `--dart-define=FACE_TFLITE_THREADS=4` for a second series). Do ≥ 5 cold (fresh app start) and ≥ 10 warm verifications per configuration on staging, tap Copy Diagnostics after each, record median and p95 of: stable-framing (liveness started − first detection), liveness, stills (count/first/sum), worker decode/scale/CLAHE, detector/landmarks/descriptor, capture finished, backend, total. Compare to the baseline above and run a few wrong-face and liveness-failure attempts to confirm rejection is unchanged (stop on any lockout warning). Release builds contain none of this (`kDebugMode`/`kProfileMode` are false).

## 6. Compatibility and security checks
Descriptor values are unchanged by construction (same frames → same preprocessing bytes → same networks → same averaging order); verified by byte-equality tests for scaler and CLAHE, overlap tests (count, attempt-order average, cap, failure message, consistency rule, spacing). No threshold/liveness/lockout change; no biometric logging; cancellation still stops capture (session token). Intermittent earlier rejection stays under observation — repeated successful device runs are still required.

## 7. Files
`face_api/face_api_pipeline.dart`, `face_api/face_api_image.dart`, `face_api/face_api_tflite.dart`, `presentation/capture/face_capture_controller.dart`, `face_embedding_model_io.dart`, `face_embedding_model_stub.dart`, `diagnostics/face_diagnostics.dart`, `lib/main.dart`; tests `face_capture_overlap_test.dart`, `face_diagnostics_test.dart` (gate string updated).

## 8. Results
Full suite 4182 passed, 320 skipped, 0 failed; `dart analyze` 7 baseline infos. Android before/after medians and p95: **pending** (no new device run yet).
