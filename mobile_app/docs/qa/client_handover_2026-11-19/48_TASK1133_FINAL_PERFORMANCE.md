# Task 113.3 — Final performance and reliability

## 1. Device results so far (successful verifications, backend accepted, descriptor length 128)
| run | total | notes |
|---|---|---|
| baseline | 9057 ms | single thread, sequential capture |
| optimised, default threads | 8613 ms | overlapped capture |
| optimised, 4 threads | 7286 ms | capture finished 5274 + backend 2012 |

## 2. Timeline of the 4-thread run (ms from Face ID opening)
camera ready 121 · first frame 531 · first detection 775 · liveness started 2137 (**framing 1362**) · liveness passed 3015 (878) · capture finished 5274 (**capture phase 2259**) · backend 2012 → 7286.
- Capture phase: stills 952 + preprocessing 985 (JPEG decode 826, CLAHE 146) + inference 598 = 2535 ms of work finished in 2259 ms wall, so overlap is only recovering ~0.3 s: the three stills (~317 ms each) serialise, and the last still's decode (~275 ms) + analysis cannot start before that still ends. About 0.8 s of the 2259 ms is still unattributed (stop-stream, first-still camera warm-up, worker start-up); the new `stop_stream_ms`, `still_first`, per-stage and spacing timers split it on the next run.
- Backend 1162 / 1194 / 2012 ms across runs: one POST on the shared Dio (connection pooling, cookie + auth interceptors); body is ~128 floats. Variation is network + server (distance check, anti-spoofing/audit writes, attendance update) and is not reducible from Flutter. If the access token expired, a refresh round-trip would add to it — the new flow timeline will show it.

## 3. Changes in this task
1. **Whole-flow timeline** (diagnostics only; ms since Clock In/Out pressed): GPS+mode done, geofence done, face-status done, registration done, face screen opening, face done, punch done, result ready — appended to Copy Diagnostics.
2. **Avoidable pre-camera waiting removed (behaviour-preserving)**: GPS and today's attendance mode were read one after the other and are independent → read together; the face-status request now starts immediately and is awaited later (a refused geofence still stops everything before any camera; a subscription keeps the single lookup alive, so there is no duplicate request — test: exactly one status, one registration, one geofence, one punch). Registration is still fetched only when Face ID is mandatory; all checks still run in the same order.
3. **Framing counters** (aggregate): frames received / processed / dropped-while-busy, no-face and multi-face frames, stability resets, ML Kit time per frame (mean/max), gap between detection results (mean/max). The 10-stable-frame rule, tracking and liveness are unchanged; each processed frame is counted once. These explain whether the 1362 ms is detector speed (processed-frame rate) or the user/pose (resets, hints).
4. **JPEG decode**: split into JPEG→pixels vs orientation/RGBA; removed a redundant buffer copy (byte-identical). The pure-Dart decoder (~275 ms/still) remains the recognition path. **Decoder comparison harness** (debug/profile, off by default, `FACE_DECODE_COMPARE=true`): on the first still of a run it also decodes with the platform codec and reports duration, dimensions, mean/max pixel difference and % of channel values off by more than 2 — numbers only, nothing kept; it adds time to that run, so benchmark without it. A native decoder is **not** enabled: Flutter's codec may not apply EXIF rotation, may not scale/convert identically, and cannot be accepted until the harness shows identical dimensions and negligible difference, followed by an identical-descriptor check.
5. **Thread equality harness** (`FACE_THREAD_COMPARE=true` with `FACE_TFLITE_THREADS=N`): also runs a single-thread copy of the recognition net on every descriptor input and records the largest distance between the two descriptors (in 1e-9). Diagnostics only (extra memory).
6. **Overlap safety**: tests confirm still captures never overlap each other (one camera operation at a time), no stills beyond what is needed, attempt cap, spacing, and that a cancel returns no descriptor; each still is bound to the current session token, so an image from an earlier session can never complete a new one.

## 4. Thread recommendation
Observed: inference 839 → 598 ms (−29 %), descriptor 496 → 268 ms, total −1.3 s with 4 threads. **Recommendation (not applied): make the default 4 threads only after** (a) `FACE_THREAD_COMPARE` shows descriptor delta ≈ 0 (≤ ~1e-6) over ≥ 10 verifications, (b) a 2-thread series is compared (4 threads may starve the camera/ML Kit on weaker phones), (c) camera preview smoothness (profile overlay) and sustained runs are checked. The default remains 1. A per-model thread setting is not exposed by the plugin's options in this code path and was not pursued.

## 5. Benchmark protocol (staging, authorised account; avoid repeated real punches and lockout)
Profile build: `flutter run --profile --dart-define=FACE_DIAGNOSTICS=true [--dart-define=FACE_TFLITE_THREADS=2|4] [--dart-define=FACE_THREAD_COMPARE=true]`; decoder series separately with `--dart-define=FACE_DECODE_COMPARE=true`. ≥ 5 cold + ≥ 10 warm runs per configuration (1, 2, 4 threads); record median / p95 / min / max for: pre-camera flow marks, camera ready, framing (liveness started − first detection) and frame counters, liveness, stills (count, first, sum), decode/convert/CLAHE, detector/landmarks/descriptor, capture finished, backend, result ready; plus success rate and any rejection category. Use a test employee whose punches can be reversed; a few wrong-face / liveness-failure tries only while the server shows no lockout warning. **Device acceptance remains pending** until these series exist.

## 6. Security / compatibility
No change to weights, threshold, 128-d output, sample counts (3 / 4), quality gate, 0.35 consistency, liveness, face-continuity (tracking id), backend lockout, preprocessing bytes (scaler/CLAHE byte-equality tests), or diagnostics gating (debug/profile + explicit define; absent in release). No biometric data logged or retained; the decoder harness keeps only integers.

## 7. Files
`lib/features/attendance/presentation/clock/clock_punch_flow.dart`, `lib/main.dart`, `diagnostics/face_diagnostics.dart`, `face_api/face_api_nets.dart`, `face_api/face_api_tflite.dart`, `face_api/face_api_image.dart`, `face_api/face_api_pipeline.dart`, `presentation/capture/face_capture_controller.dart`, `face_embedding_model_io.dart`, `face_embedding_model_stub.dart`; tests `face_diagnostics_test.dart`, `face_capture_overlap_test.dart`, `face_punch_server_responses_test.dart` (request-sequence test).

## 8. Results
Full suite 4187 passed, 320 skipped, 0 failed; `dart analyze` 7 baseline infos. No new Android measurements after these changes yet.
