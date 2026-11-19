# Cross-platform face verification: test plan (DRAFT)

Status: draft for Web Team review, 2026-11-19. Nothing here changes the 128-D model, the 0.6 threshold or the liveness rules. Production mobile face attendance stays OFF until the Web Team approves the calibration results and confirms the reviewed backend is in HTTPS staging.

Test subjects: use only employees who have consented, referred to as [Employee A], [Employee B] and so on. Do not store face images, descriptors, tokens or personal data in this repo or in result files. Record distances and pass/fail only.

## 0. Open items to settle first

| # | Item | Why it matters |
|---|---|---|
| O1 | **Auth contract.** The app currently sends `Authorization: Bearer <access>` on every request and a `{"refresh": ...}` body on `/token/refresh/`, as well as cookies (`lib/core/network/auth_interceptor.dart`). The Web Team says Bearer is not supported without their approval. | Needs an explicit decision: either approve the fallback or remove it. I will not change it without agreement. |
| O2 | Staging base URL and test accounts (HTTPS). The debug build currently points at production (`ApiConfig`). | Never run the acceptance test against production. |
| O3 | Pass/fail criteria in section 5 are proposals. | The Web Team must approve them. |
| O4 | Whether the backend face check applies to `source='mobile'` punches in the reviewed build. | This was the P0-04A gap. |

## 1. Device matrix

Minimum: 3 Android and 2 iOS devices. Record make/model, OS version, RAM and camera.

| Slot | Class | Example |
|---|---|---|
| A1 | Low-end Android (≤3 GB RAM, ≤13 MP) | [device] |
| A2 | Mid-range Android | [device] |
| A3 | Flagship Android | [device] |
| I1 | Older iPhone | [device] |
| I2 | Current iPhone | [device] |

Per device, per condition, record:

- Model load time and per-network inference time (detector, landmarks, recognition).
- Time from capture start to the descriptor being ready.
- Peak memory, and whether the 22.5 MB recognition model loads without being killed.
- Any thermal throttling after 10 consecutive captures.

Lighting and camera conditions (each on every device): daylight, office lighting, dim room, backlit window, mixed or colored light. Also record with and without glasses, a mask, and a different head angle within the allowed range.

## 2. Cookie persistence and refresh verification (HTTPS staging)

Run per device. A pass requires the behavior with no Bearer header (once O1 is decided) and with the persisted cookie jar only.

| # | Step | Expected |
|---|---|---|
| C1 | Log in as [Employee A] with the tenant/company code. | Session established; `Set-Cookie` for the access and refresh cookies is received. |
| C2 | Call an authenticated endpoint (profile, attendance history). | 200 using the cookie alone. |
| C3 | Kill the app and relaunch. | Still signed in; the cookie jar was persisted. |
| C4 | Reboot the device and relaunch. | Still signed in. |
| C5 | Let the access token expire, or shorten the staging lifetime, and open a screen. | Silent `/token/refresh/` succeeds, the original request is retried, and there is no logout. |
| C6 | Fire several requests at once when the token is expired. | Exactly one refresh call; all requests succeed. |
| C7 | Let the refresh token expire. | The app signs out and shows the login screen once. |
| C8 | Turn on airplane mode during a refresh. | No logout on a network failure; the request's own error is shown. |
| C9 | Log out. | Cookies cleared; the next launch shows login. |
| C10 | Log in as an employee of tenant B on the same device. | No data from tenant A is visible. |
| C11 | Deactivate the test user on the web, then open the app. | Session ends cleanly after the retried request still returns 401. |

Evidence: the response status line and relevant header names only. Never paste cookie or token values.

## 3. Numerical parity evidence and commands

Goal: show that the mobile descriptor equals the web descriptor for the same input, within numerical tolerance, and that the preprocessing matches.

Already measured (2026-11-10): recognition max abs diff 4.7e-6, max descriptor distance 1.5e-5 against face-api.js 0.22.2 on CPU.

Commands, run from `mobile_app/`:

```sh
# 1. Mobile-side unit and fixture tests (preprocessing, pipeline, liveness)
flutter test test/features/facial_recognition
flutter analyze lib/features/facial_recognition

# 2. Reproduce the TFLite vs face-api.js comparison
#    (steps in tool/face_api_conversion/README.md, section "Reproduce")
tfenv/bin/python compare_recognition.py inputs_150.f32 ref_out.json face_recognition.tflite
tfenv/bin/python compare_det_lmk.py

# 3. On each physical device: same 24 inputs through the app's own runtime
flutter run -d <device> -t lib/debug/face_api_check_main.dart
#    read face_api_check.json back from the app documents folder
```

For each device, compare `face_api_check.json` descriptors with `ref_out.json`:

- Max abs difference per element.
- Max Euclidean distance per input.
- Inference times.

Proposed device-parity bar (for approval): max descriptor distance ≤ 1e-3 on every device and runtime. Any larger value, especially one that differs by platform (Android vs iOS delegates), is a finding to report.

Still to add after Web Team sign-off on the inputs: a **web-vs-mobile same-image check**. Take N consented still images, compute the descriptor in the web app (face-api.js) and through the mobile pipeline, and compare distances. This checks the full path (CLAHE, detection, alignment), not just the network.

## 4. Calibration procedure (genuine vs impostor)

Subjects: at least 10 consenting employees, if possible. Each is registered once on the web, with no mobile registration.

For each subject S and each device D and each condition L (section 1):

1. Capture on mobile through the normal clock-in capture flow (3 frames averaged, liveness passed).
2. Compute the distance between the mobile descriptor and S's web registration. This gives a **genuine** distance.
3. Compute the distance between the same mobile descriptor and every **other** subject's web registration. These are **impostor** distances.
4. Repeat each genuine capture at least 5 times.

Record only this table per row: `subject_id (anonymised), device, condition, kind(genuine|impostor), distance, pass/fail at 0.6`. Distances come from a debug-only log or the staging verification response. No images are retained.

Report per device class and per condition:

- Genuine distance: min, median, p95, max.
- Impostor distance: min, median, p5, max.
- FRR (genuine distance > 0.6) and FAR (impostor distance ≤ 0.6) at the current 0.6 threshold.
- The overlap between the genuine and impostor distributions, and the margin between the genuine max and the impostor min.

Proposed acceptance (for approval): FAR 0 at 0.6 across all impostor pairs. FRR under a limit the Web Team sets, for example ≤2% in normal lighting. The threshold is NOT to be tuned on mobile. If results are unacceptable, report the measurements and propose a model-specific registration architecture, as agreed.

## 5. End-to-end acceptance (HTTPS staging, existing web-registered faces)

Prerequisites: O1 to O4 settled, the reviewed backend in staging, test employees with a web face registration and no mobile registration.

| # | Step | Expected |
|---|---|---|
| E1 | Confirm on the web that [Employee A] has a face registered. | Registered. |
| E2 | Log in on mobile as the same account and tenant. | Success (section 2, C1). |
| E3 | Mobile shows face verification required, with no mobile registration prompt. | The mobile app does not enable real mobile registration. |
| E4 | Capture [Employee A]'s face; liveness (head turn) must pass. | The descriptor is produced; the quality gate passes. |
| E5 | Punch in. | Backend verifies the face against the web registration and accepts it; the punch is recorded. |
| E6 | Punch out. | Accepted. |
| E7 | Open the same employee's attendance in the web app. | The same in/out times, status and source appear. |
| E8 | Repeat E4 to E6 with [Employee B]'s face on [Employee A]'s account. | Rejected by the backend; no attendance record is created. |
| E9 | Try a photo or video replay on the camera. | Liveness blocks it. |
| E10 | Try the punch with no face, or an unverified face, where face is mandatory. | Rejected; mandatory verification cannot be bypassed. |
| E11 | Existing restrictions (one clock-in/out per day rule, shift, GPS/geofence, WFH rules). | Still enforced for mobile punches. |
| E12 | Tenant isolation: [Employee A]'s descriptor against a different tenant's account. | Rejected. |

Run E1 to E7 on every device in the matrix, and E8 to E12 on at least one Android and one iOS device.

## 6. Results template

| Item | Android A1 | A2 | A3 | iOS I1 | I2 |
|---|---|---|---|---|---|
| Parity max distance | | | | | |
| Load / inference ms | | | | | |
| Cookie tests C1 to C11 | | | | | |
| Genuine median / p95 | | | | | |
| Impostor min | | | | | |
| FRR / FAR at 0.6 | | | | | |
| E1 to E7 | | | | | |
| E8 to E12 | | | | | |

Known issues and backend requirements go in a separate list once results exist.

## 7. What I need

- Staging HTTPS URL and test accounts (O2), plus the decision on O1.
- The device list above, and consenting subjects.
- Web Team approval of the proposed criteria (O3).
