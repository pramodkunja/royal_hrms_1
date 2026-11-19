# 10 — Client Handover Readiness (updated after Task 86 final screen audit, 18 Nov 2026)

## Recommendation: **NOT READY. Release BLOCKED.** The client build is not marked ready.

## Task 86 final screen audit (18 Nov 2026, device build 1.0.2+10 `517159eb…`, read-only)
- **Inventory:** `11_FINAL_SCREEN_INVENTORY.csv` has 114 screen / tab units across 70 distinct screens.
- **By status:** COMPLETE 32 · BLOCKED 69 (55 production-write, 7 role, 7 data/module) · PARTIAL 5 · MISSING 3 · UNTESTED 2 · INTENTIONAL WEB-ONLY 3.
- **Device coverage:** 92 units opened on the phone, 69 new captures in Task 86. No crash; no clipping found at 1.0.
- **New defect:** HO-35 (Credit Rules placeholder accrual UI). One suspected tab overlap was disproved (HO-36).
- **Plan:** `12_REMAINING_WORK_PLAN.md`.

## Task 87 (18 Nov 2026, debug 1.0.2 code 11 `a321c6a1…`)
- **HO-35 fixed:** the Credit Rules accrual editor is removed and replaced by a "not available" notice; Credit All Employees is kept (confirmation verified, cancelled).
- **HO-30 fixed:** "Department · Branch" on employee cards, verified at 1.0, 1.3 and 1.5; card navigation intact.
- **Tests:** 2,714 passed; analyzer 13 info.
- **New finding:** HO-37, Carry Forward. *Corrected in Task 88; see below.*

## Task 88 (18 Nov 2026, debug 1.0.2 code 12 `252dc8b8…`)
- **HO-37 corrected:** the "all 4 endpoints 404" claim was based on the out-of-date local backend copy (HO-31).
  - On production, GET `years` and GET `history` **work** (device evidence).
  - POST `preview` and POST `run` were not called, so their availability is **UNVERIFIED**.
- **Risk found and mitigated:** Run (an irreversible write of leave balances) was enabled with no preview.
  - Temporary guard: Run is enabled only after a successful Preview for the same years, and an on-screen note explains why.
  - The feature and its history are kept.
  - This deviates from web on purpose; remove the guard once the backend confirms the POST contract.
- **Device:** Run shows as disabled; tapping it opens nothing. Preview and Run were never tapped, so no production write was made.
- **Tests:** 7 new widget tests (mutation-checked); full suite 2,721 passed; analyzer 13 info.

## Task 90 batch 1 (18 Nov 2026, debug 1.0.2 code 13 `7cc8f547…`)
- **Updated web source re-audited** (91 changed files); see `13_TASK90_PARITY_INVENTORY.md`.
- **Training & Learning admin is now on mobile:**
  - Covers the dashboard, courses, course Details and Materials, Assign (with confirmation), Progress with Reset/Remove, Delete, and Reports.
  - Device-verified read-only on production, with no writes.
  - Course creation and editing stay on web for now.
- **Still missing:**
  - My Learning (HO-38; package decision needed).
  - Approvers section (HO-42).
  - Leave eligibility and medical-certificate rules (HO-39 / HO-40).
  - Smaller gaps: HO-41, HO-43, HO-44.
- **Backend scoping:** Branch Admin data is now branch-scoped for `settings.edit` checks; residual scoping gaps are in HO-45. **HO-18 remains open.**
- **Tests:** 2,745 passed; analyzer 13 info.

## Task 90 batch 2 (18 Nov 2026, debug 1.0.2 code 14 `53b14942…`)
- **My Learning is now on mobile:**
  - 6 tabs, course page, PDF reader, tracked video players, assessment.
  - One new package: `webview_flutter`.
- **Device (read-only, production):** list, tabs, course page and locked assessment are verified. No material was opened and no assessment was started.
- **Progress-writing flows are verified only with mocked API tests (29)**; they need a staging account with disposable assignments.
- **Fixed:** the admin PDF preview (Batch 1) no longer leaves a cached copy.
- **New:** HO-47, PowerPoint / Word files on mobile (decision).
- **Tests:** 2,774 passed; analyzer 13 info.

## Task 90 batch 3 (18 Nov 2026, debug 1.0.2 code 16 `e820d54a…`)
- **Training admin authoring is now on mobile:** New Course, full course editor with thumbnail and assessment link, material add (upload / link) / edit / reorder / remove, and CSV export. Every write is permission-checked before any request.
- **HO-46 fixed** and device-verified (including app-bar titles app-wide, up to 25% scale-down).
- **HO-47:** PowerPoint / Word open in another app through a private FileProvider (no PPTX/DOCX in production to try on the phone).
- **Not built (not supported):** un-archive has no backend endpoint; New Assessment is web-only (HO-49).
- **Course-opening parity switch** ready but OFF (HO-48, product decision).
- **Device:** view-and-cancel only, **no production writes**. All authoring and learner writes still need a staging tenant.
- **Tests:** 2,806 passed; analyzer 13 info.

## Task 91: Training final verification (18 Nov 2026)
- **Reports:** `14_TRAINING_FINAL_VERIFICATION.md` (inventory, the 13-action permission table with source lines, findings, results, recommendation) and `15_TRAINING_STAGING_TEST_MATRIX.md` (45 staging scenarios).
- **Results:** source = code 16; analyzer 13 info; Training 85 passed; full suite 2,806 passed. The phone was disconnected, so there was no new device run; today's code 16 evidence stands.
- **Permissions:** all 13 admin actions check permissions on mobile before any request (0 bypasses). The backend enforces the same codenames independently, and a stricter scope for assign / remove / reset / export. Archived-course rules are UI-only on the backend (HO-51).
- **New:** HO-50 (P1), Branch Admin can author the company-wide course catalogue through the `settings.edit` bypass. HO-45 is extended to training scope.
- **Decisions recorded:** HO-48 auto-open stays disabled; HO-49 closed (no un-archive, no duplicate assessment creator).
- **Recommendation:** Training module **CONDITIONAL GO** (writes need staging plus a decision on HO-50). Overall handover remains **NO-GO**: HO-01 open; HO-32 has no releasable artifact (the AAB predates the Training work and has no recorded source); no write workflow is verified for any role.

## Task 93: Leave web parity HO-39 / 40 / 41 (18 Nov 2026)
- **Implemented in Flutter** (`19_TASK93_LEAVE_PARITY.md`):
  - leave-type eligibility (`eligible_for_me`, inactive types hidden);
  - the medical-certificate rule with web's hint;
  - Add Leave Type "Applicable to" and web labels / messages;
  - the rules-tab server message.
- **Tests:** 14 new, mutation-checked; full suite 2,820; analyzer 13 info.
- **Device:** not verified (phone disconnected; no new build made).
- **Face ID payload:** mobile already matches the proposed backend contract.
- **Branch Admin permission handling:** mobile = web; depends on the backend login flag (HO-18).
- **Backend items:** `20_BACKEND_DEVELOPER_ACTION_ITEMS.md` (HO-01, 18, 45, 50, 51 + HO-52). **Web item:** HO-53.

## Task 92: Security remediation plan and blocker table (18 Nov 2026)
**Details:** specification `16_SECURITY_REMEDIATION_SPEC.md`, backend test matrix `17_BACKEND_AUTHZ_TEST_MATRIX.md`, release checklist `18_RELEASE_PROVENANCE_CHECKLIST.md`. Plan only: no code changed and no production request made.

### Security blockers (must be fixed, or formally risk-accepted, before release)

| ID | Sev. | Affected users | Root cause | Proposed fix | Owner | Required tests | Acceptance | Depends on | Effort (est.) |
|---|---|---|---|---|---|---|---|---|---|
| **HO-01** | P0 | Every company with mandatory Face ID; every employee can bypass it; mobile users are never actually verified | `verify_for_punch` checks only `source` web / voice (`services_face_matching.py:207`); `source` is client-chosen (`serializers_my_attendance.py:34`); mobile sends `mobile`. A fix ("P0-04A") exists only as tests plus an unused helper | Verify every employee-initiated punch when mandatory; whitelist `web` / `mobile`; server-set `voice`; wire `descriptor_error`; require liveness true | Backend (+ QA) | `tests_face_verification_enforcement.py` + matrix 17 §A (A1–A18) | All A-tests pass; bypass attempts rejected; mobile ↔ web equivalence (A18) meets the agreed rate on staging | P-2, P-3; staging; HO-31 (confirm the production code) | Backend 1 d; staging validation 0.5–1 d |
| **HO-18 / HO-50** | P1 | Branch Admins (company-wide authoring and settings); every branch's data integrity | `settings.edit` re-granted to `branch_admin` via the Roles UI despite `0052` / `0070`; `has_perm` treats `settings.edit` as a wildcard (`core/permissions.py:41`); login `is_superuser` (`accounts/views.py:612`) | Remove the grant (migration); block re-grant in the Roles API / UI; narrow the wildcard for branch roles; correct the login flag | Product (P-1) → Backend | Matrix 17 §B (B1–B11) + full backend suite | Branch Admin holds only seeded codenames; B-tests pass; no regression for SYS / HR | P-1, P-1b; HO-31 | Backend 1–1.5 d + regression 1 d |
| **HO-45** | P1 | Branch-less Branch Admins (company-wide view); any `employees.view` / approver holder (cross-branch reads) | `… if branch else Q()` (`leave.py:207`, `workfromhome.py:90`, `training/services.py:72`); `employee_id` lookups with no scope (`leave.py:702-708, 936-943`, `workfromhome.py:120-127`); birthdays company-wide with email (`birthdays.py:26-82`); approvers list unpaginated | Central fail-closed scope helper; scope checks on `employee_id` → 404; birthdays scoped without email; paginate approvers | Backend (+ product P-4, P-6) | Matrix 17 §C (C1–C12) | No cross-branch rows; branch-less → empty; no ID oracle | P-4, P-6 | Backend 1–1.5 d |

### Lower-severity backend fix

| ID | Sev. | Root cause | Fix | Owner | Tests | Acceptance | Effort |
|---|---|---|---|---|---|---|---|
| HO-51 | P3 | Archived-course edits checked only in the UI (`training/views.py:276, 321, 353, 416, 440, 457`) | `_ensure_editable` → 409 | Backend | Matrix 17 §D | D1–D7 pass | 0.25 d |

### Release / environment blockers (process, not code)

| ID | Sev. | Issue | Action | Owner | Acceptance | Effort |
|---|---|---|---|---|---|---|
| HO-31 | P1 | Production backend revision unknown; all source findings unconfirmed against production | Read-only SHA, migration and role check by the operator; diff against the clone (doc 18 §1–2) | Ops / Backend | Production SHA recorded; findings re-confirmed | 0.25 d |
| HO-32 | P1 | The only release AAB (`e073c6f3…`) predates Tasks 88–90 and has an unrecorded source; signed with the upload certificate `C3:64:…:92:A7` | Record the source (§3), bump to `1.0.3+17` (§4), verify the key against Play (§5), build and record (§6–7), retire the old AAB (§8) | Release + Mobile | Release record complete; AAB signer = Play upload certificate; manifest = tested source | 0.5 d after preconditions |

### Staging verification required (not security defects)
- Training writes and learner progress (doc 15, 45 scenarios).
- Face ID enforcement behaviour on real devices (A18).
- The Branch Admin role after the fix (§B).
- Employee / HR / Manager role smoke tests.
- Release-candidate smoke test.
- **Prerequisite:** a staging backend, plus an approved staging config in the mobile app. Debug builds currently target production.

### Product decisions needed (doc 16 §5)
P-1 Branch Admin scope · P-1b settings screens · P-2 Face ID staging-first rollout · P-3 liveness required · P-4 branch-less users fail closed · P-5 archived DELETE · P-6 birthday / contact visibility.

### Readiness assessment
- **Client handover: NO-GO (unchanged).**
  - HO-01 is an exploitable P0: any employee can skip mandatory Face ID with one field.
  - No releasable artifact exists (HO-32).
- **Shortest path to CONDITIONAL GO:**
  1. Decide P-1 to P-6.
  2. Backend: apply HO-01 + HO-18 / 50 + HO-45 (about 4–5 backend days including regression) and deploy to staging.
  3. Run matrices 15 and 17 on staging, including A18.
  4. Run the read-only production checks (doc 18 §1).
  5. Deploy the backend fixes to production.
  6. Build and record the release AAB (doc 18 §3–7).

  Alternative if the date cannot move: a **written client risk acceptance** for HO-01 (Face ID not enforced for mobile and other client-declared sources) and HO-18, *plus* a recorded release build. This is not recommended for HO-01.

## Release blockers
1. **P0, HO-01 (backend):** face verification is skipped for `source` other than web/voice. OPEN.
2. **P1, HO-18:** Branch Admin holds `settings.edit`, which acts as company-wide admin (live web: company billing and company-wide branch figures). Decision required.
3. **P1, HO-32 (release provenance):** a release AAB was built at 16:06 while C3 source edits were in progress, with no recorded hash or source state. Record it, or rebuild from a recorded state, before any upload.
4. **P1, HO-31 (audit validity):** the local web/backend reference source is behind production (no Training module locally). Source-only comparisons may be outdated; only LIVE rows are current.
5. **Coverage:** only the Branch Admin role and read-only flows were tested; no write workflow was verified on either platform.

## Scope decisions needed
- **HO-25:** Training & Learning + My Learning, observed live; 6–9 developer days, and backend contract docs are needed because the local source lacks it. Can't fit by 19 Nov; defer explicitly or move the date.
- **HO-24:** Plan Details (read-only billing; settings.edit). Recommended to wait for HO-18.
- **HO-11 / HO-26:** should branch figures be branch-scoped? The backend counts company-wide.

## Fixed and device-verified (12)
HO-02, HO-03, HO-04, HO-05, HO-06, HO-09, HO-19, HO-20, HO-21, HO-23 (C1/C2), plus in C3:
- **HO-28:** Print / Save PDF and Share PDF of the own payslip; Download PDF state matches web. Device: Android print preview shown, share sheet opened; nothing printed or shared.
- **HO-29:** Current Experience "1 year 9 months", identical to live web. Web's duplicated "Total Experience" is a web defect (HO-34), so it isn't copied.

## Counts

| Measure | Count |
|---|---|
| Automated tests | **2,701 passed**, 0 failed; `flutter analyze` 13 info, 0 warnings, 0 errors |
| Defects (07) | **34**: P0 1 · P1 5 · P2 12 · P3 15 · informational 1 |
| Defect status | FIXED 12 · PARTIAL 2 · NEEDS DECISION 3 · OPEN 16 · INTENTIONAL 1 |
| Field rows (03) | **100** in total |
| Field rows by evidence level | FULLY PARITY VERIFIED (live web + device agree) 22 · LIVE + DEVICE with a difference 15 · LIVE web only 6 · DEVICE + SOURCE 20 · DEVICE only 15 · SOURCE only 7 · BLOCKED 4 · NOT TESTED 9 · INTENTIONAL 2 |
| Live web pages / tab states captured | C2: 16 pages · C3: 36 page/tab states (Training, My Learning, Payroll, Attendance ×7, WFH ×3, etc.) |
| Evidence | 106 redacted screenshots, 52 redacted live-web text extracts |
| Device build | debug 1.0.2 **versionCode 17** (`6aaf444e…`), production backend, installed in place |

## New missing web routes or features found (C3)
| Web route / feature | Mobile | Status |
|---|---|---|
| `/dashboard/training` (Courses, Reports, New Course, Export CSV) | absent | HO-25 |
| `/dashboard/my-learning` (6 status tabs, course viewer) | absent | HO-25 |
| `/dashboard/payroll` (6 admin tabs) | absent | Intentional (web-only) |
| Settings → Company → Plan Details | absent | HO-24 |

All other live web menu items have a mobile destination. The GET endpoints used by the web Attendance (7 tabs), WFH (3 tabs), Interview List and Candidate Review pages are all wired in mobile.

## Remaining risks
- **Production data:** every device and web check runs against production (read-only).
- **Untested roles:** Employee, HR and Manager are NOT TESTED.
- **Untested writes:** clock-in, submissions, approvals and saves remain untested.
- **Lost backup:** the 1.0.1+7 backup APK was deleted by an external clean (HO-32); the 1.0.2+9 backup is in session scratch only.


## Task 94 update (18 Nov 2026)
HO-42, HO-43, HO-44 and the Employee Profile parity gaps (HO-55…58) are implemented with mocked tests (2,855 passing; analyze clean of new issues). HO-54 Assets needed no code change (module/visibility). None of it is device-tested: code 17 on the phone predates these changes. Web/backend defects are in doc 20 and HO-59. Details: `21_TASK94_PARITY.md`.

## Task 95 update (18 Nov 2026)
Final source-level parity audit: 403 matrix rows — 249 COMPLETE, 98 PARTIAL, 16 MISSING, 0 BLOCKED, 27 WEB-ONLY, 13 UNTESTED (before the small fixes applied in the task; COMPLETE = source + mocked tests, not production-verified). A P1 bug (Employee dashboard cards empty against the real server) was found and fixed. Open P1/P2 items and the release recommendation: `22_TASK95_FINAL_PARITY_AUDIT.md` §4 and §10; register HO-60…HO-72.

## Task 96 update (19 Nov 2026)
My Payslip now matches web's document (adjustments/arrears, Additions panel, one-time deductions, wage-slip layout, UAN/ESIC, saved letterhead, status labels) with 41 reconciliation tests (5 deliberate mutations all caught) and a PDF that follows the same layouts. Dashboard Action Items parsing re-verified and hardened. Full suite 2,907 passed. Not device/staging verified; open: logo, sidebar card, stamp in PDF. See `23_TASK96_MY_PAYSLIP.md`.

## Task 97 update (19 Nov 2026)
My Payslip has no remaining Flutter-only difference (logo, sidebar employee card, stamp embedded in the PDF via a login-free secure loader). Employee Management P2: Add Employee for Branch Admin roles, server-side employee stats, and Add Branch "Other city" implemented to web parity. Full suite 2,979 passed; all mocked — nothing device/staging verified. See `24_TASK97_PAYSLIP_AND_EMPLOYEES.md` (incl. a formatting-churn note for diff review).

## Task 98 update (19 Nov 2026)
Hidden Date of Birth no longer blocks Edit Save (web has no client-side required check; hidden fields keep stored values), Employee Bulk Import has Sample CSV/XLSX and Error Report downloads per web, Branch form copy matches web, role-permission investigation documented (safe-now items and backend-confirmation items separated). Full suite 3,007 passed; mocked only. **Formatting churn found: 80 lib files reflowed by folder-wide formatting in Tasks 94–97 — needs your git diff review (HO-73).** See `25_TASK98_PROFILE_IMPORT_UI.md`.
