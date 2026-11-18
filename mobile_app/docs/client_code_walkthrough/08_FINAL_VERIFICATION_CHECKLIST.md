# Royal HRMS — Walkthrough Package: Final Verification Checklist

**Review date:** 2026-11-18 · **Type:** documentation-only review. No Git commands, no application/backend changes, no network calls, no production writes, no Flutter tests run.

Legend: ✅ verified · ⚠ verified with a stated limit · ⛔ not verified / open

## A. Documents

| File | Technical claims checked against source / records | Safe for the demo (no secrets, no writes) | Status |
|---|---|---|---|
| `01_…ARCHITECTURE…md` | ✅ 155 file references checked: all mobile paths exist; backend paths exist; line refs (`services_face_matching.py:207`, `serializers_my_attendance.py:34`, `tokens.py:49`, `views.py:512`) confirmed | ✅ | ✅ corrected in this review |
| `01_…ARCHITECTURE….pdf` | Same content as the .md plus Appendix A diagrams | ✅ | ✅ see section B |
| `02_CLIENT_PRESENTATION_SCRIPT.md` | ✅ minutes add to 45 (3+5+7+7+8+5+5+5); every section has Show / Point at / Say / Transition | ✅ | ✅ rewritten |
| `03_LIVE_CODE_DEMO_GUIDE.md` | ✅ 13 tab paths exist; live code route = 8 min, matches script section 5 | ✅ code-only; no sign-in, no screenshots by default | ✅ rewritten |
| `04_CLIENT_QA_PREPARATION.md` | ✅ answers aligned with HO-01/HO-18/HO-25/HO-32 wording | ✅ | ✅ updated |
| `05_ARCHITECTURE_DIAGRAMS.md` | ✅ all 12 diagram blocks render (10 numbered diagrams; #9 split in 3) | ✅ | ✅ redesigned |
| `06_PRESENTER_REHEARSAL_CHECKLIST.md` | ✅ tab count / no-live-system rule aligned with 03 | ✅ | ✅ updated |
| `07_CLIENT_WALKTHROUGH_QUICK_REFERENCE.md` | ✅ one page; contains the required sections | ✅ | ✅ new |

## B. PDF pages (`01_…pdf`, 33 pages, final build)

Method: each page rendered to an image and viewed; the final build was also checked by a 33-page contact sheet and a programmatic check (every page has body text, footer reads "Page N of 33", orientation as intended). Table of contents numbers were computed from the rendered PDF.
**Limit:** pages 1–21 were viewed one by one at full size on the 35-page build whose text/layout is identical to the final 33-page build (the later changes were landscape-diagram pages, an invisible chart tooltip element that caused a blank last page, and the footer total). Pages 22–33 were viewed individually on the immediately preceding builds and again on the final contact sheet.

| Pages | Content | Result |
|---|---|---|
| 1 | Title page | ✅ |
| 2 | Table of contents (numbers match headings: 3,4,5,6,7,8,10,13,14,15,16,17,17,18,18,19,20,21) | ✅ |
| 3–9 | Sections 1–6 | ✅ tables readable, no clipping |
| 10–12 | Section 7 (compact module table + detail bullets) | ✅ (was unreadable; rebuilt) |
| 13–14 | Section 8 (three examples), start of 9 | ✅ |
| 15–18 | Sections 9–15 | ✅ code sample no longer wraps |
| 19–21 | Sections 15–17, appendix heading | ✅ |
| 22 | Diagram 1 (landscape) | ✅ readable |
| 23 | Diagram 2 (portrait) | ✅ |
| 24–27 | Diagrams 3, 4, 5, 6 | ✅ |
| 28–29 | Diagrams 7, 8 | ✅ text now readable (was ≈6 pt) |
| 30–32 | Diagram 9 in three parts | ✅ (was an unreadable single ER diagram) |
| 33 | Diagram 10 | ✅ no trailing blank page |

Defects found and fixed during inspection: double-numbered TOC with no page numbers; unreadable module table; orphaned headings; one blank page; a near-empty page; clipped/small diagrams (1, 4–10); lines run together in section 8; misaligned risk-table row; wrapped tree and code lines.

## C. Technical corrections made in this review

| Topic | Correction |
|---|---|
| HO-01 | The API accepts `web, mobile, biometric, manual, voice` and the **client chooses** `source` (default `web`); server face matching only for `web`/`voice`. Previously "serializer restriction unconfirmed". Not exploit-tested. |
| HO-18 | Rewritten: device evidence (earlier build) vs refreshed local source (`has_perm` exception, `can_edit_settings` still allows settings screens) vs HO-45 residual gaps; production revision unconfirmed. |
| HO-25 | Training/My Learning now labelled **PARTIAL / learner writes unverified**; New Assessment web-only, un-archive unavailable, HO-47/48/42 noted. |
| HO-32 | Version numbers explained (`pubspec` +10; debug builds via `--build-number`; `android/local.properties` = 16); release AAB provenance and "no signed release build tested" stated. |
| `must_change_password` | Server returns it and puts it in the JWT, but **no endpoint blocks** a flagged user (searched `apps`, `core`, `config`); enforcement is client-side only. |
| Tenant / cookie vs Bearer | Tenant is resolved **only from the cookie** claim; Bearer-only requests stay on the public schema → the mobile cookie jar is load-bearing. Not tested without cookies. |
| Test figures | 2,806 passed; analyze 13 info/0 warn/0 err (18 Nov, project record, **not re-run**); an older 2,701 in one handover table noted. |
| Resolved "unverified" items | Server TTS exists (Sarvam Bulbul); leave balance deducted at final approval; SDK 36/24/36 (Flutter 3.44.8 defaults). |
| Production infrastructure | Explicitly **not** described (only: nginx proxies `/api/`). |
| Demo safety | Removed live-app/emulator reliance; screenshots only if personally reviewed and approved; `local.properties` added to never-show list. |

## D. Remaining uncertainties

- ⛔ Production Python/Redis/Celery/hosting and whether production runs the same backend revision as the local clone.
- ⛔ Behaviour of a cookie-less (Bearer-only) request.
- ⛔ Any live write workflow, clock-in, face registration; Employee/HR/Manager roles; signed release build; accessibility; performance.
- ⚠ Test numbers and device results come from project records, not re-run.
- ⚠ HO-xx statuses reflect the 18 Nov handover documents; statuses may have changed since.
