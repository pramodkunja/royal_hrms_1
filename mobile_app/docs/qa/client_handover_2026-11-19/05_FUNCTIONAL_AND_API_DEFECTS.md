# 05 — Functional and API Findings

Phase B, 17 Nov 2026. Every network call was made by the app itself against **production**, as the Branch Admin test account, and every one was a read (GET). Nothing was submitted, approved, uploaded, saved, deleted or sent. The auditor ran no scripts against the API.

Verification labels: **DEVICE-OBSERVED** means seen on the phone. **SOURCE-CONFIRMED** means read in the backend or web source. **SOURCE-COMPARED** means web behaviour was taken from source, not from a running web page.

## A. Flutter-owned

| ID | Finding | Basis | Severity |
|---|---|---|---|
| HO-02 | Dialog confirm buttons can be blocked by the voice robot; a tap starts a microphone recording instead (see 04). Functional effect: a date can't be confirmed when the robot overlaps OK. | DEVICE-OBSERVED | P1 |
| HO-06 | A Cancel / Save bar shows on a profile opened through *View*. Whether Save sends anything when nothing changed wasn't tested (it would be a write). | DEVICE-OBSERVED; web SOURCE-COMPARE pending | P2 |
| HO-13 (label) | The dashboard KPI says "Approvals" (6) while the inbox shows 11 pending; web's label for the same number is "Pending Approvals — Across all modules". | DEVICE-OBSERVED + SOURCE-COMPARED | P3 |

## B. Backend-owned (reported only; backend is read-only for this audit)

| ID | Finding | Basis | Severity |
|---|---|---|---|
| HO-01 | Face verification skipped for `source` ≠ web/voice (see 06). | SOURCE-CONFIRMED | **P0** |
| HO-11 | `GET /branch/branches/distribution/` isn't branch-scoped (`apps/branch/views.py` `BranchDistributionView`). A Suryapet-only admin sees 4 branches / 13 employees in the chart while the list says 1 branch / 7 employees. | DEVICE-OBSERVED + SOURCE-CONFIRMED | P2 |
| HO-12 | `GET /attendance/face-registration/employees/` is company-wide by design for anyone with `facial_recognition.approve` (docstring in `apps/attendance/views/face_registration_hr.py`). A branch admin can register or replace face data for other branches' employees. | DEVICE-OBSERVED + SOURCE-CONFIRMED | P2 (decision) |
| HO-13 (definition) | `SystemAdminKPIView.pending_approvals` = pending leave (incl. L2) + pending expenses + submitted onboarding. It excludes attendance corrections and isn't branch-scoped. | SOURCE-CONFIRMED | P3 |
| HO-17 | Department headcounts on Depts & Designations are company-wide (6 / 4 / 3); the dashboard Department Headcount is branch-scoped (3 / 2 / 2). | DEVICE-OBSERVED | P3 |
| HO-18 | `settings.edit` is a superset permission in `has_perm`, and the *Branch Admin* role holds it. A branch-level account gets company-wide settings, including roles, SMTP, email templates and the financial year. | DEVICE-OBSERVED + SOURCE | P1 (security review) |

## C. Workflows verified as working (read paths only)

| Workflow | Observed result | Basis |
|---|---|---|
| Login with company code | Succeeded; landed on the role dashboard | DEVICE-OBSERVED |
| Leave balances for the calendar year (Task 83) | Leave Dashboard and Analytics show the 2026 figures; Analytics says "This year (2026)" | DEVICE-OBSERVED |
| Apply Leave server preview (Task 84) | `GET /leave/requests/?action=preview` rendered for Casual 28–30 Nov: 3 calendar / 1 working / 11 available / 1 used / 0 LOP; week-offs Sat 28 and Sun 29 Nov. Consistent with the backend `_leave_preview` contract. | DEVICE-OBSERVED (reloaded session) |
| Fractional balances (Task 84 / LV-08) | "82.5d left", "4.5d left" shown with no rounding | DEVICE-OBSERVED (reloaded session; **not in the installed APK**, see HO-04) |
| Approvals inbox | 11 pending items with Approve / Reject, type chips and filters; L2 items visible (Task 80) | DEVICE-OBSERVED |
| Approvals sub-tabs | Attendance Approval, Face ID, Leave Cancellations and Delegation all load with correct empty states | DEVICE-OBSERVED |
| Permission Matrix | Read-only view of 23 modules × 6 roles loads | DEVICE-OBSERVED |
| Settings pages (17) | All open with no error state | DEVICE-OBSERVED |

## D. Not exercised (writes; not authorized in Phase B)

Clock in/out; Face ID registration; leave submit/cancel; approve/reject; WFH / expense / separation submissions; any Save on profile or settings; uploads; SMTP Test (sends email); Mark-all-read (changes notification state); role Active switches; employee Active switch; imports and exports.

## E. Recheck of Task 79 known risks

| Task 79 item | Phase B status |
|---|---|
| FACE-06 (face bypass) | Still present in the backend source (HO-01). |
| AUD-05 (audit branch scoping) | Branch Admin sees audit entries made by other users (payroll events by an HR Admin). Whether those users are outside the branch wasn't confirmed: NOT CONFIRMED. |
| Document / recruitment authorization | NOT TESTED: no documents or candidates exist in the demo tenant (0 / 0). |
