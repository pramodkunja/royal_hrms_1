# 10 — Client Handover Readiness (updated after Phase C3, 17 Nov 2026)

## Recommendation: **NOT READY. Release BLOCKED.** The client build is not marked ready.

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
| Device build | debug **1.0.2+10** (`517159eb…`), production backend, installed in place |

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
