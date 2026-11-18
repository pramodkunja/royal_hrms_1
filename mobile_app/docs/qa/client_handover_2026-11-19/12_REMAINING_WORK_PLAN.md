# 12 — Remaining Work Plan (Task 86, 18 Nov 2026)

Source: `11_FINAL_SCREEN_INVENTORY.csv` (114 screen / tab units, 70 distinct screens) and `07_MASTER_DEFECT_REGISTER.csv`. Audit only: no code was changed, no build installed, no data changed.

## Inventory totals (each row is one screen or one tab; no double counting)

| Status | Units | Meaning |
|---|---|---|
| COMPLETE | **32** | Implemented and physically verified; no untested critical action |
| BLOCKED | **69** | 55 display-verified on device, core action is a production write; 7 need other role accounts; 7 need test data or a disabled module |
| PARTIAL | **5** | Voice assistant (end-to-end voice not device-tested), Employees list (HO-30), Branch Management (HO-26 / HO-11), Leave Policy › Credit Rules (HO-35), Audit Log (HO-14) |
| MISSING | **3** | Training & Learning, My Learning (HO-25), Company › Plan Details (HO-24) |
| UNTESTED | **2** | Forgot Password, Logout |
| INTENTIONAL WEB-ONLY | **3** | Admin Payroll, Reports, Platform Admin |
| **Total** | **114** | 92 units opened on the device |

## P0 — security / release blockers
| Item | Owner | Before 19 Nov? |
|---|---|---|
| HO-01 face-verification bypass (`source` other than web/voice) | Backend | Only if the backend fixes and deploys, **or** the client signs a risk acceptance |
| Clock-in / Face ID registration never exercised on device (FACE-06/07/08) | QA + backend | Needs written approval for one test punch on a disposable record |

## P1 — essential functionality not yet proven
| Item | Effort | Before 19 Nov? |
|---|---|---|
| HO-18 Branch Admin = company admin (decision) | Decision | Yes, if decided today |
| HO-32 record or rebuild the release AAB from a recorded source state | 0.5 h | **Yes** |
| HO-31 refresh the reference web/backend clone | Backend owner | Recommended |
| Employee / HR / Manager dashboards and menus (role accounts) | 2–3 h once accounts exist | Yes, with accounts |
| Onboarding wizard, Candidate detail, Review & Onboarding with real data | 2 h with test records | Only with test data |
| Write flows: Apply Leave submit, WFH submit, Approve / Reject (L1 / L2), Expense submit | 2 h on disposable records | Only with mutation approval |
| HO-25 Training (scope decision) | 6–9 days (learner-only 3–4) | **No**: defer, or move the date |

## P2 — missing fields / actions / significant UI
| Item | Effort | Before 19 Nov? |
|---|---|---|
| HO-35 Credit Rules placeholder accrual section (edits silently discarded) | 0.25 day | **Yes** (recommended: hide or disable) |
| HO-30 employee card extra line (department · branch) | 0.25 day | Yes |
| HO-26 / HO-11 / HO-12 / HO-17 branch scoping | Backend | No (backend) |
| HO-24 Plan Details | 0.5 day after HO-18 decision | Decision first |
| HO-16 demo data clean-up (typos, template text, coordinates in address, emergency contact name holds a number) | Client data | Client decision (production writes) |
| Document view / preview, ID card Print / Share on device | 0.5 h test | Yes |

## P3 — minor visual / accessibility
HO-07 (app-bar titles and a few labels at large text), HO-08 (tab scroll hint), HO-10 (icon-button labels), HO-14 (audit date format), HO-27 (wording vs web), HO-15 (partial). About 0.5–1 day in total; optional before handover.

## Realistic before 19 Nov
1. HO-32 release provenance; HO-35 hide placeholder; HO-30 card line (Flutter, < 1 day).
2. Role-account smoke test and the write-flow smoke test, **if** accounts, test records and mutation approval are provided today.
3. Decisions: HO-01 (risk acceptance or backend fix), HO-18, HO-25 deferral, HO-24.

## Needs a scope decision or more time
Training module (HO-25), backend scoping (HO-11 / 12 / 17 / 26), Plan Details (HO-24), any change to the Branch Admin role (HO-18), and a backend fix for HO-01.
