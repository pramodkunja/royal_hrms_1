# 06 — Security and Release Blockers

Status on 17 Nov 2026 (Phase B). The backend is read-only for this audit: backend items are reported, not fixed. No exploit was attempted against production.

## 1. P0: HO-01 / FACE-06, face verification bypass (backend)

- **Where:** `web_frontend_backend/backend/apps/attendance/services_face_matching.py`, `FaceVerificationService.verify_for_punch`:
  `if source not in (AttendancePunch.SOURCE_WEB, AttendancePunch.SOURCE_VOICE): return cls._not_required(submitted_embedding)`
- **Input:** `apps/attendance/serializers_my_attendance.py`: `source` is a client-supplied `ChoiceField(choices=['web','mobile','biometric','manual','voice'], default='web')`.
- **Effect:** with Face ID mandatory, an authenticated self-service punch sent with `source` = `mobile`, `biometric` or `manual` isn't face-matched on the server. The mobile app sends `mobile`, so for mobile punches only on-device checks stand between a user and a face-less punch, and any API client can do the same.
- **Status:** OPEN in the local copy of the production-branch source. Not exploit-tested; whether production runs exactly this code isn't proven.
- **Release gate:** **BLOCKED.** It needs either a backend fix (face-match every self-service punch when Face ID is mandatory, whatever the client-supplied source) or written client acceptance of the risk.

## 2. P1: HO-18, Branch Admin effectively company admin (backend / product)

- The *Branch Admin* role (1 user) holds `settings.view` + `settings.edit`; the device Permission Matrix shows "Settings: Full (2)".
- Backend `has_perm`, mirrored on mobile, treats `settings.edit` as granting **every** permission. The account can open, and the UI offers edits to, company-wide Roles & Permissions (including live role-deactivate switches), SMTP servers, Email Templates, Company Info / Financial Year, Approval Rules, Notice Periods and Face ID registration for any branch.
- **Device evidence:** all 17 Settings pages open for this account; `evidence/settings/roles_permissions_android.png`, `smtp_settings_android.png`.
- **Decision needed:** is "Branch Admin" meant to be company-wide? If not, the role definition (a data change) or the superset rule (a backend change) must change. Either is outside Flutter.

## 3. P2: data-scoping exposures (backend)

| ID | Exposure | Who can see it |
|---|---|---|
| HO-11 | Other branches' names and headcounts in the Employee Distribution chart | anyone with `branches.view` (or `settings.edit`) |
| HO-12 | Every active employee's name, email, employee ID and branch in the Face ID picker; can register their face "approved immediately" | anyone with `facial_recognition.approve` (by design, per backend docstring) |
| HO-17 | Company-wide department headcounts | settings users |
| AUD-05 (Task 79) | Audit trail branch scoping | NOT CONFIRMED in Phase B |

## 4. P1: HO-02, unintended microphone capture (Flutter): FIXED in C1 (1.0.2+8), device-retested

Tapping where the voice robot overlaps a dialog button **starts a microphone recording** and the assistant keeps "Listening again". The app holds the RECORD_AUDIO permission (granted). During Phase B the assistant was triggered by accident and closed straight away; it recognized no command. Voice commands can trigger actions, so an accidental recording is a potential unintended-action path. That makes this a release-relevant Flutter defect.

## 5. P1: HO-04, build provenance (release process)

- The installed APK doesn't contain the latest source; a debug session's hot reload masks this.
- Every build reports version `1.0.1+7`.
- **Debug builds talk to production.** The `api_config.dart` environment applies to debug builds too, so any developer debug session on any device reads and writes production data.
- **Release gate:** the client build must be a versioned release build, with a recorded SHA-256 and a recorded source state.

## 6. Logging and privacy checks (Phase B)

- No tokens, passwords or Authorization headers appeared in the captured app log. The app writes no `flutter`-tag log lines at all.
- Screenshots contain names, emails, phone numbers, bank fields and salary figures. Raw captures stay in the private session scratchpad. Published evidence is automatically redacted: names, emails, phones, IDs, amounts, dates of birth and coordinates are pixelated. **Have a person review it before sharing outside the team.**

## 7. Release readiness gate summary

| Gate | Status |
|---|---|
| P0 security (HO-01) | **BLOCKED**: backend fix or written risk acceptance |
| P1 access model (HO-18) | **DECISION REQUIRED** |
| P1 Flutter (HO-02) | FIXED (C1): modal UI gets its own taps; mic released if a modal opens; no automatic second recording; one recording at a time. Device retest PASS. |
| P1 build provenance (HO-04) | FIXED for the device build (1.0.2+8 debug, SHA-256 recorded). A **release** build for the client is still to be produced and recorded. |
| Parity audit coverage | 0 of 60 in-scope screens compared field-by-field with web (Phase C not started) |

## 8. C1 notes
- **Microphone (HO-02):** permission is still requested only from `startListening()`, which runs after an explicit tap on the robot. Tapping the edge handle never starts listening; verified on the device with no audio-record entry. The silent Hindi re-recording after an empty capture was removed. The re-recording after a non-matching *spoken* command is unchanged: it mirrors web, and the user did speak.
- **Backend items:** HO-01, HO-11, HO-12, HO-17 and HO-18 remain **OPEN**; no backend change was made.
