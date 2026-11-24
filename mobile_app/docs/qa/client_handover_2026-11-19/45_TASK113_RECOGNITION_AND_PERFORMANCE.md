# Task 113 — Recognition accuracy, camera startup, performance

**Status: performance defects fixed and tested; the registered-face rejection root cause is NOT established; physical-device acceptance is BLOCKED** (no Android device/emulator: `adb` is not even installed on this machine, `flutter devices` shows macOS/Chrome only). Nothing here claims the real rejection is resolved.

## 1. Root cause of registered-face rejection
Not established. Static analysis found no defect that would reject a correctly framed registered face. Candidates that remain unproven (need a device):
- **Still orientation/mirroring.** Evidence from the plugin source (camera_android_camerax 0.6.30 `takePicture`): no mirroring is applied and the target rotation follows the display, so on Android the still is expected to be un-mirrored and EXIF/rotation-upright — the same as the web, which feeds face-api the raw (un-mirrored) video frame. Mobile bakes EXIF and never flips (tests below). On iOS (camera_avfoundation) front stills are commonly mirrored — unverified, out of this device's scope. **No flip was added.**
- **Backend hard-reject band.** `services_face_matching.py`: distance ≤ 0.6 matches, but a match within 0.05 of the threshold (0.55–0.60) is a hard "low-confidence" block with no retry. A registration that is itself marginal can reject its owner on every attempt on either platform. This needs the server-side distance from a staging attempt, not a code change.
- **Legacy/incompatible registration.** A descriptor-length mismatch is recorded server-side as an ordinary mismatch (counts toward lockout, generic message). Mobile cannot see this client-side.
- Lower capture resolution (`ResolutionPreset.medium`) vs web video: crops are resized to 150 px anyway; unproven.

## 2. Web ↔ mobile pipeline (read from code)
Identical stages, same constants: 800 px max width → CLAHE (tile 32, clip 3) → TinyFaceDetector 224 / 0.5 → landmarks on the detection crop → dlib alignment → 150 px recognition → web quality gate → N frames (4 reg / 3 verify), pairwise ≤ 0.35, averaged → 128-d. Backend: Euclidean distance on equal-length lists, threshold 0.6, server lockout (`blocked`/`retry_after_seconds`), tenant by cookie. Mobile shows the server's own message verbatim (mismatch, low-confidence, cap, replay, registration-required, liveness all have distinct backend texts), and lockout handling is unchanged.

## 3. Performance — what was slow (code-confirmed) and what changed
| Bottleneck | Change |
|---|---|
| JPEG decode + upright + downscale + CLAHE of each still ran on the **UI isolate** (host: ~78 ms for a 1280×960 still in debug JIT; several× more on a phone) | `prepareStillOffUi`: one worker isolate per still; result byte-identical (test) |
| ~25 MB models began loading only after camera init | load starts first, concurrent with camera; cached for the session |
| `availableCameras()` on every open | front camera chosen once per session |
| UI state republished on every processed camera frame (rebuild storm) | frame-driven updates throttled to 100 ms; phase/hint/step changes immediate |
| NV21 planes copied per frame | single plane used directly |
| Bounded frame pipeline | already present (`_processingFrame` drops frames while busy); kept |
Aggregate stage timings (ms only, no images/descriptors/ids) are collected in `FaceCaptureUiState.timingsMs`: camera_lookup, camera_ready, stream_started, first_frame, first_detection_result, nets_ready, first_still, descriptor_done. **No device numbers exist yet**; median/p95 targets (route <300 ms, preview 1–2 s, detection <500 ms, descriptor <500 ms, backend <1 s, total 3–6 s) are unmeasured and must be recorded on a device.
Not changed: still capture interval (250 ms, web parity), CLAHE/crop work after preparation (small), acceleration delegates (not benchmarked, not enabled), model/threshold. Dashboard status → registration requests are sequential by design (registration is fetched only when mandatory); not parallelised.

## 4. Liveness continuity
Face loss during the challenge is now bounded by wall-clock time (0.8 s) instead of a frame count, so behaviour no longer depends on frame rate. ML Kit tracking is enabled; if the face that reappears has a different tracking id the challenge restarts with "A different face was detected", so nobody inherits another person's blink/turn progress. Blink and turn are still both required (registration) / turn (clock-in); thresholds unchanged. Stills are taken after the live challenge in the same session; frames from earlier sessions are never reused.

## 5. Feedback
Stage labels follow reality: Opening camera… / Position your face in the oval / Face detected / Blink naturally / Turn your head slightly / Capturing and checking your face… / Face captured — verifying… (never "successful" before the backend answers). Server messages (mismatch, lockout, network) are unchanged and distinct.

## 6. Files
Modified: `face_api/face_api_pipeline.dart` (prepare helpers, `prepared` flag), `capture/face_capture_controller.dart`, `capture/face_capture_state.dart` (timingsMs), `widgets/face_capture_camera_view.dart` (stage labels).
New tests: `face_still_preparation_test.dart` (no mirroring, EXIF upright, 800 px, isolate ≡ in-process ≡ original steps, corrupt bytes), `face_nets_reuse_test.dart`; extended `face_capture_liveness_flow_test.dart` (wall-clock loss, different-face reset, UI throttle) and `face_capture_screen_test.dart` (stage labels).

## 7. Security
No descriptor/image/identifier logging added (static scan passes); no threshold, liveness, lockout or backend change; no bypass; no automatic retries; no cached verification; nothing deleted or re-registered.

## 8. Results
Full suite 4170 passed, 320 skipped, 0 failed; `dart analyze` 7 baseline infos.

## 9. Blocked — device acceptance (Phase 10/11)
Needs an authorised Android device + staging account: web↔mobile register/verify matrix (4 combinations), repeated verify, clock in/out, lighting, orientations, wrong-face and liveness-failure rejection, background/resume, repeated open/close, and the timing table above. First useful step for the rejection: on staging, submit one verification from mobile and read the server-side distance for that attempt (backend logs/audit row) — a distance near 0.6 with a web-registered face points to still mirroring/orientation or a marginal reference; a length mismatch points to a legacy registration.
