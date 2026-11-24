# Task 112 — Face ID Check: camera presentation, framing, liveness

**Status: code + automated tests complete. Physical-device verification is PENDING** (no Android device or emulator was attached; `adb devices` and `flutter devices` showed none). Nothing below claims a real-device pass.

## 1. Root cause — camera presentation (code-derived, device-unverified)
- `CameraPreview` was placed under tight `StackFit.expand` constraints inside a fixed 300 px box, so its internal `AspectRatio` was overridden and the image was **stretched** to the box.
- The framing oval was a hard-coded 170×210 px shape unrelated to the preview rectangle or to the web guide (web: 0.44 × 0.80 of a 4:3 stage, oval w/h ≈ 0.733).
- The surface was a half-height bottom sheet (0.85 of screen, scrolling list) with unused space and a cramped preview.

## 2. Root cause — scanning / liveness
- Face-width ratio divided by the **raw sensor width** (`image.width`) while ML Kit boxes are in **upright** coordinates; on a portrait phone this under-reports size (false "Move closer").
- Any frame with ≠1 face (a blink, a head turn, motion blur) set the phase back to `detecting` and **lost the liveness tracker**, so the user could repeat the instruction indefinitely while the status stayed "Confirming it's really you…".
- No centring, lighting, progress or time-left feedback; no lifecycle handling.
- Not established without a device: whether CameraX delivers the rotation the ML Kit input assumes, and whether `takePicture` stills are mirrored relative to web frames (descriptor-parity risk; see section 10).

## 3. Web / mobile comparison
Web: `frontend/lib/faceApi/{guide,readiness,overlay,liveness,flowConfig}.ts`. Ported: guide proportions and ellipse test, centring gate, distance gate, lighting cue (luma 50), liveness rules unchanged (blink+turn for registration, turn-only for clock-in), thresholds unchanged. ML Kit cues remain for live framing only; descriptors still come from the converted face-api.js TFLite pipeline (128-d, unchanged).

## 4. Files
Modified: `capture/face_capture_controller.dart`, `capture/face_capture_state.dart`, `widgets/face_capture_camera_view.dart`, `widgets/face_capture_bottom_sheet.dart` (now opens a full-screen route; function name, parameters and result type unchanged), `widgets/face_consent_panel.dart` (button row → Wrap).
New: `capture/face_capture_geometry.dart`; tests `face_capture_geometry_test.dart`, `face_capture_liveness_flow_test.dart`, `face_capture_screen_test.dart`.
Test updated: `face_punch_server_responses_test.dart` (close control is now the app-bar back arrow; same cancel behaviour asserted).
Unchanged by design: models, thresholds, liveness rules, backend contract, lockout handling.

## 5. UI
Before: bottom sheet, fixed 300 px stretched preview, 170×210 oval. After: full-screen "Face ID Check" (app bar with back, short instruction, privacy line), preview at the camera's natural portrait aspect (contain, never stretched), oval measured from the preview rectangle (turns green when the face centre is inside), live hint on the preview, Blink / Turn head progress with seconds left, status card with Try again, Cancel; controls scroll in a capped band so large text cannot push the preview out. No before/after screenshots: a camera preview cannot render without a device; layout is covered by render tests (below).

## 6. Geometry verification (unit tests)
Upright size after 90/270 rotation; portrait aspect for 4:3 and 16:9 sensors; fit never stretches/overflows; face ratio uses upright width; front-camera x-mirror (left/right/up/down), double-mirror identity; oval proportion ≈ 0.733 and centred at several preview sizes; centre-inside test. Boxes are mapped by measured scale, no fixed offsets.

## 7. Liveness verification (tests, fake detector output)
Hints for too far / too close / off-centre / turned; liveness start, progress and time-left; brief face loss keeps the tracker (blink completes after a gap); multiple faces keeps the window; sustained loss (13 frames) returns to framing with a hint; timeout → `livenessFailed` with an actionable message; state holds geometry only. Liveness was not bypassed or relaxed.

## 8. Backend contract
Descriptor is still 128-d only; no truncation/padding/substitution; server remains the sole match decision; five-failure lockout and retry countdown untouched (existing lockout tests pass); no automatic retries added. The static scan forbidding bypass tokens and logging in the face code still passes.

## 9. Results
Full suite: 4158 passed, 320 skipped, 0 failed. `dart analyze`: 7 issues (same baseline infos). Render tests: 4 widths (320/360/393/430) × 1.0/1.5/2.0 text × 6 states with no overflow; cancel/back/consent/retry/progress tests.

## 10. Pending on a physical Android device
Preview aspect and rotation/mirroring on CameraX; whether ML Kit boxes align with the mirrored preview; `takePicture` mirroring vs web descriptors (verify with consenting test faces; do not flip speculatively); real yaw/blink behaviour and timing; low-light hint; background/resume; permission revoke; gesture and 3-button navigation. Record model, Android version, preview/sensor size, inference size, detection confidence and liveness transitions in privacy-safe notes (no images, frames or descriptors). Diagnostic logging was not added (the repo forbids logging in this code); on-device notes must be taken by hand.
