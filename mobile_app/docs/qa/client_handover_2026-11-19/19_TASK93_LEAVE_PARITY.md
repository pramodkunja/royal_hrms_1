# 19 — Task 93: Strict Web Parity for HO-39 / HO-40 / HO-41 (18 Nov 2026)

**Rules followed**
- The web app is the source of truth.
- Backend read-only; Flutter changes only; no Git; no production writes; no build or install.

**Evidence levels**
- **IMPL:** implemented.
- **MOCK:** verified by unit / widget tests against a stand-in API.
- **DEVICE:** not done. The phone was not connected, and verification needs a new debug build approved first.
- **STAGING:** none available.

## 1. Web behaviour verified from source

### HO-39 — Leave type eligibility
- **Which types are listed**
  - Web `frontend/app/dashboard/leave/_data.ts:80-99`: `buildLeaveTypesList` gives the 6 built-ins plus active custom policies. `buildApplicableLeaveTypes` then removes any type whose policy is inactive or has `eligible_for_me === false`.
  - Built-ins with no policy row stay.
  - The list is **empty while policies load**.
  - The picker is used in `ApplyLeaveForm.tsx:65-70, 228-240`.
- **Backend:** `GET /leave/policy/` adds `eligible_for_me = is_active AND gender allowed` per row (`backend/apps/hrms/views/leave.py:597-603`).
  - On apply the server refuses inactive types ("This leave type is not available.", `:996`).
  - It also refuses gender ("…(gender restriction).", `:557`), branch / department and minimum-service restrictions (`:546-560`).
  - The API exposes **only** gender + active through `eligible_for_me`. Branch / department / service rules are enforced server-side only, on web and mobile alike.
- **Web error / empty states:** a failed policy request leaves `policies` null, so the picker is empty with no message. Web's form default stays `leave_type: "casual"` even when Casual is filtered out (`ApplyLeaveForm.tsx:28`), so the server then refuses the submit. Noted as a web defect.

### HO-40 — Supporting document / medical certificate
- **Rule** (`_data.ts:120-138`, `documentRule`):
  - Attachment Required → always required.
  - Medical Certificate Required → required when `days >= medical_certificate_after_days`, with the hint "A medical certificate is required for leave of N or more day(s)."
  - Neither → optional.
  - Before the policy loads, the built-in default applies (Sick / Maternity / Paternity require it).
- **Day count:** `preview.actual_leave_days ?? workDays` (`ApplyLeaveForm.tsx:116-120`).
- **Messages:** submit error = the hint, else "Supporting document is required for this leave type." (`:139`). The label shows "(Required)" / "(Optional)" with the hint under it (`:446-452`).
- **Upload:** `accept=".pdf,.jpg,.jpeg,.png"`, text "PDF, JPG, PNG · Max 5 MB"; the chosen file shows its name with a remove button; sent as multipart `document` (`:154-163, 455-475`).
- **Backend:** the same rule on the server's day count (`leave.py:539-545`). The document must be under 5 MB and its **content type** PDF / JPEG / PNG (`serializers.py:495, 684-690`).
- **No edit flow:** leave requests are not edited; web has no "existing attachment" editing in Apply Leave.

### HO-41 — Add Leave Type
- **Fields** (web `settings/leave-policy/_components/PolicyTab.tsx:424-497`):
  - **Display Name *** (placeholder "e.g. Compensatory Off"; letters, spaces and hyphens only via `sanitizeLeaveName`; key preview "Key: <lower, runs of space/hyphen → _>").
  - **Annual Days *** (number, min 0, step 0.5).
  - **Max Carry Fwd (days)**.
  - **Applicable to *** (All employees / Female employees only / Male employees only, default `all`, helper "Balances are given out as soon as the leave type is created — choose this now (e.g. Female only for Pink Leave).").
  - **Policy Note** (placeholder "Visible to employees when applying for leave", no length limit).
  - **Allow Carry Forward**, **Active**.
- **Validation** (`:212-221`):
  - "Display name is required."
  - "Display name can only contain letters, spaces, and hyphens — no numbers or special characters."
  - "Annual days cannot be negative."
  - "Must be at least 1 when carry forward is enabled."
- **Payload:** POST `/leave/policy/` with `{leave_type_label, annual_days, can_carry_forward, max_carry_forward_days, policy_note, is_active, applicable_gender}`. On success it refetches and closes; on error the message shows **inside the modal** (`:223-236`).
- **Permission:** the button is not gated in `PolicyTab` (`:274`). The backend requires `settings.edit` or `leave.approve` (`leave.py:643-645`).
- **Gender change later:** the "Leave Policies" rules tab shows the server message `res.data.message || "Policy updated."` (`LeavePoliciesTab.tsx:326-340`). The backend appends "Removed N unused balance(s) from employees this leave type no longer applies to." when the gender rule changes (`leave.py:614-628`).

## 2. Parity matrix

| Web feature | Web source | Flutter source | Status | Tests | Remaining gap |
|---|---|---|---|---|---|
| Applicable types = active and `eligible_for_me != false`; built-ins without policy kept | `_data.ts:91-99` | `apply_leave_type_selector.dart` `applicableFromEntities`; `leave_entity.dart` `eligibleForMe`; `leave_models.dart` parse | IMPL + MOCK | 3 unit + 2 widget | Device / staging (needs an employee of the restricted gender) |
| Empty until policies load | `_data.ts:92` | `applicableFromEntities(policiesLoaded:)`; spinner while loading | IMPL + MOCK | unit | — |
| Selection never on a hidden type | (web keeps "casual", a defect) | `apply_leave_tab.dart` build: first offered type | IMPL + MOCK (**deliberate difference**: mobile doesn't copy the web defect) | widget | Web fix suggested (doc 20) |
| Policy load failure | silent empty picker | message + **Retry** (`_LeaveTypesError`) | IMPL + MOCK (mobile adds a message; no web capability lost) | widget | — |
| Nothing offered | empty grid | "No leave types are available to you." + Submit disabled | IMPL + MOCK | widget | — |
| Document rule (attachment / medical from N days / optional / built-in fallback) | `_data.ts:120-138`; `ApplyLeaveForm.tsx:116-120` | `leave_document_rule.dart`; `apply_leave_tab.dart` (label, hint, submit) | IMPL + MOCK | 1 unit (8 cases) + 2 widget | Device / staging |
| Hint under the label; error = hint | `ApplyLeaveForm.tsx:139, 446-452` | `apply-leave-doc-hint`, `leaveDocumentRequiredMessage` | IMPL + MOCK | widget | — |
| File types / size | `accept=.pdf,.jpg,.jpeg,.png`; server 5 MB + content type | file picker pdf/jpg/jpeg/png; 5 MB pre-check with the server's text "Document must be under 5 MB."; Dio 5.11 sends the content type inferred from the file name | IMPL (existing) | existing tests | — |
| Picked file shown with remove | `:455-466` | `DocumentFilePicker` (existing) | IMPL (existing) | existing | — |
| Add Leave Type "Applicable to" (default All) + helper | `PolicyTab.tsx:471-482` | `add_leave_type_dialog.dart` dropdown → `applicable_gender` | IMPL + MOCK | widget + unit | Device |
| Display Name label, placeholder, key preview | `:442-456` | dialog | IMPL + MOCK | widget + unit | — |
| Web validation messages | `:212-221` | `form_validators.dart` (name), dialog (carry ≥ 1), existing annual-days rule | IMPL + MOCK | unit + widget | — |
| Field labels / placeholders | `:461-486` | "Max Carry Fwd (days)", Policy Note placeholder, no 300-character limit | IMPL | — | Mobile hides Max Carry Fwd while carry forward is off (web shows it; the value is still 0 when off): layout only |
| Error inside the modal | `:231-232` | `add-leave-type-error` | IMPL + MOCK | widget | — |
| Permission | backend `leave.py:643-645` | `createPolicy` refuses locally ("Permission denied.") like `updatePolicy`; the button stays visible as on web | IMPL + MOCK | widget | — |
| Create payload | `:228` (7 fields) | label + full rule set; every value equals the server default, and credit-schedule fields are omitted when null (checked in `serializers.py:200-262`), so the created policy is identical | VERIFIED (source) | existing + widget | — |
| Rules-tab server message ("Removed N unused balance(s)…") | `LeavePoliciesTab.tsx:340` | `settings_remote_datasource.dart` `updateLeavePolicyWithMessage`; `settings_providers.dart` `updatePolicyWithMessage`; `leave_policy_rules_tab.dart` | IMPL + MOCK | unit (2 cases); 2 existing tests updated | Device |

## 3. Files changed (Flutter only)

| File | Change |
|---|---|
| `lib/features/leave/domain/entities/leave_entity.dart` | `eligibleForMe` |
| `lib/features/leave/data/models/leave_models.dart` | parse `eligible_for_me` |
| `lib/features/leave/presentation/widgets/apply_leave_type_selector.dart` | `applicableFromEntities` |
| `lib/features/leave/presentation/widgets/leave_document_rule.dart` | **new**: web `documentRule` |
| `lib/features/leave/presentation/widgets/apply_leave_tab.dart` | applicable list, selection, error / empty states, document rule + hint, 5 MB message, balance card spinner only while loading |
| `lib/features/settings/presentation/leave_policy/widgets/add_leave_type_dialog.dart` | Applicable to, labels, key preview, carry ≥ 1, inline error |
| `lib/shared/validators/form_validators.dart` | web name messages |
| `lib/features/settings/presentation/providers/settings_providers.dart` | create permission check; `updatePolicyWithMessage` |
| `lib/features/settings/data/datasources/settings_remote_datasource.dart` | `updateLeavePolicyWithMessage` |
| `lib/features/settings/presentation/leave_policy/widgets/leave_policy_rules_tab.dart` | shows the server message |
| `test/features/leave/leave_parity_ho39_41_test.dart` | **new**, 14 tests |
| `test/features/settings/monthly_credit_settings_test.dart`, `leave_policy_long_leave_test.dart` | now expect the server message "Policy updated." |

Compared with the code 16 manifest: 9 changed + 1 new app file, nothing else.

## 4. Verification
- **Focused tests:** 14 / 14 passed. **Mutation checks:** removing the eligibility filter, the medical-certificate branch, or the gender in the payload is each caught.
- **Full suite:** **2,820 passed**, 0 failed. Analyzer: 13 info (baseline).
- **Bug found by the tests and fixed:** the Leave Balance side card would have spun forever when no type could be selected.
- **Device: not performed.** The phone was not connected. A debug build containing these changes has not been made; it needs approval.
- **Staging: none.**

## 5. Phase 3 — compatibility review
- **Face ID punch payload** (`attendance_remote_datasource.dart:46-77`, `clock_punch_flow.dart:100-128`, `face_capture_controller.dart:126, 283-300`), when Face ID is mandatory:

  | Field | Type | Value |
  |---|---|---|
  | `face_embedding` | `List<double>` | 128 values, the same face-api.js network as web (`face_embedding_model_io.dart:6-7`) |
  | `liveness_passed` | bool | `true`, set only after liveness passes |
  | `liveness_score` | double | — |
  | `capture_session_id` | string | UUID v4, a new one per camera session |
  | `source` | string | `"mobile"` |

  - Fields are omitted, not sent as null, when not captured.
  - This matches what the backend's pending P0-04A tests expect (doc 16 §1). **No mobile change needed.**
  - Optional later: send `embedding_model_version` at registration.
- **Branch Admin and the implicit `settings.edit` bypass:**
  - Mobile `userHasPermission` (`access_control.dart:17-21`) grants everything to `isSuperuser` or `settings.edit`.
  - **This is identical to web** `usePermission` (`hooks/usePermission.ts:5-10`, `is_superuser` → true). The login sets `is_superuser` for every `settings.edit` holder (`accounts/views.py:612`), so mobile = web.
  - Both differ from the backend, which withholds the literal `settings.edit` check from branch roles (`core/permissions.py:34`). The backend still enforces it.
  - Correcting this depends on the backend login flag and product decision P-1 (doc 16 §2). **No mobile change made**, as instructed.

## 6. Remaining gaps
- Device and staging verification of HO-39 / HO-40 / HO-41.
- **Next in scope:** HO-42 (Approvers), not started per the stop condition.

---

# Task 93.1 — Device verification (18 Nov 2026)

## Build and install
- **Build:** debug **1.0.2, versionCode 17**. `flutter build apk --debug --build-number=17`; pubspec unchanged (1.0.2+10); release AAB untouched.
- **APK:** SHA-256 **`6aaf444ef60b330e7f955925fb6b53e4f254d93b405a7317ebbff8b814ee8e2f`**, 271,888,423 bytes.
- **Source:**
  - Before building I confirmed source = code 16 manifest + the 10 Task 93 files, at exactly the hashes recorded in the Task 93 report.
  - The session's "changed on disk" notices about Training files were stale: their hashes equal the code 16 manifest.
  - Manifest `build_1.0.2+17-debug_source_manifest.txt`, aggregate `a93cc0c0ad411767…`.
- **Signing:** signer `38eabe8f…c128`, **identical** to the installed code 16 (checked on the pulled APK before installing). Permissions unchanged.
- **Install:** `adb install -r` succeeded at 17:19:26. versionCode 17; installed hash matches the build; **firstInstallTime unchanged** (no uninstall, data kept). Code 16 is backed up in session scratch.

## Results (production, Branch Admin demo account, read-only / local input / Cancel only)

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Apply Leave shows only eligible, active types | **PASS (positive case only).** All 8 production types are active (Settings: "8 Total Types / 8 Active") and all 8 are offered. **Not demonstrable on device:** no production type is inactive, and the gender rules couldn't be read (the rules-tab type switch didn't open through automation). The negative path (hiding) is mocked-test verified only | `evidence/t93/01`, `03` |
| 2 | Leave Balance with an empty eligible list | **NOT VERIFIABLE on production** without changing data (every type is eligible). Mocked-test verified (the spinner-forever bug was fixed) | — |
| 3 | Medical certificate requirement + hint | **PARTIAL.** All 8 types checked (local selection only): Sick Leave shows **(Required)** with no hint, matching web's rule for "Attachment Required"; the other 7 show **(Optional)**. No production type has the medical-certificate rule, so the hint and N-day threshold **can't be shown on device**; mocked-test verified | `evidence/t93/02` |
| 4 | Add Leave Type: Applicable to, labels, key preview, validation | **PASS.** "Display Name *" with placeholder "e.g. Compensatory Off"; "Applicable to *" default **All employees** with web's helper; menu = All / Female only / Male only; typing "Test Leave1" → digit filtered, **"Key: test_leave"**; empty name → **"Display name is required."** with the dialog left open. Closed with X; still **8 Total Types** (nothing created) | `evidence/t93/04`–`07` |
| 5 | Existing Leave screens and navigation | **PASS.** Leave Dashboard, Apply Leave, Team Calendar and Analytics tabs open; Apply Leave scrolls to its Cancel / Draft / Submit row (none tapped); Settings → Leave Policy list intact | `evidence/t93/08`, `09` |
| 6 | Small screen (720×1640), scrolling, keyboard, error visibility | **PASS.** Type grid (3 columns, 8 cards), document section and fields fit without clipping; with the keyboard open the dialog shrinks and scrolls, and the name error stays visible above the keyboard | `evidence/t93/01`, `02`, `06` |

## Device-only observations (no app defect found)
- **Test harness, not the app:** Android `keyevent DEL` through Gboard entered keyboard suggestions ("by by …") instead of clearing the name field.
  - This was a harness issue, not an app defect.
  - My safety check refused to tap Add while a valid name was present, so nothing was submitted.
  - I closed the dialog with X and repeated the validation check with a fresh, empty dialog.
- **Production data note:** a custom type is named "Materity Leave" (typo, not app text; same class as HO-16).
- **Not done:** large-text / font-scale checks. They weren't requested, and changing the system font needs separate approval.

## Status after device check
- **HO-41:** device-verified (display, validation, preview; create itself not submitted).
- **HO-39 / HO-40:** mocked-test verified; on device, only the production-data cases were verified (all-eligible; attachment-required vs optional).
- **Staging is needed** for the hiding, empty-list and medical-certificate N-day cases.
