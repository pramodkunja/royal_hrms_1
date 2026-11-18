# 17 — Backend Authorization Test Matrix (Task 92, 18 Nov 2026)

**Where these tests run**
- In the backend test suite (Django `TestCase`, `APIClient`) and on staging.
- **Never against production.**

**Fixtures**
- Company C with branches **B1** and **B2**; Face ID mandatory unless stated otherwise.
- Users:
  - **SYS:** system_admin.
  - **HR:** hr_admin, no `settings.edit` since `0077`.
  - **BA:** branch_admin, branch B1, *without* `settings.edit`; target state after P-1.
  - **BA+:** branch_admin with `settings.edit`; today's production state, kept in tests to prove the fix.
  - **BX:** branch_admin with empty branch.
  - **MGR:** manager of E1.
  - **E1, E2:** employees in B1. **E3:** employee in B2.
  - **NOB:** employee with no branch.
- E1 has an approved face registration (face-api v1, 128-d).

## A. Face ID (HO-01) — `POST /api/attendance/punch/`

| ID | Actor / input | Expected |
|---|---|---|
| A1 | E1, `source=web`, matching descriptor, liveness true | 200, punch stored, attempt `is_match=true` |
| A2 | E1, `source=mobile`, matching descriptor | 200 (verified; today: not verified at all) |
| A3 | E1, `source=mobile`, **no descriptor** | 400 "face required" (**today: 200 — the bypass**) |
| A4 | E1, `source=biometric` / `manual` / `system` / `kiosk`, with and without a descriptor | 400 "Unsupported punch source." |
| A5 | E1, `source` missing / `""` / `MOBILE` | missing → treated as `web`, then verified; `""` / `MOBILE` → 400 |
| A6 | E1, `source=voice` on the punch API | 400 (voice is set only by the voice executor) |
| A7 | Voice executor path, no descriptor | rejected |
| A8 | Mismatched descriptor | 403; attempt recorded |
| A9 | Distance in the low-confidence band (0.55–0.60) | blocked (hard reject) |
| A10 | 5 failures within 15 min, then a 6th with a matching descriptor | 6th blocked; `retry_after_seconds` > 0 |
| A11 | Same descriptor fingerprint replayed within 5 min | blocked (replay) |
| A12 | 192-value, NaN or empty descriptor; registration stored with another model | rejected **without** a distance comparison |
| A13 | `liveness_passed=false`; `liveness_passed` missing (after P-3) | 403; 403 |
| A14 | Non-TLS request outside local/test env | blocked |
| A15 | E2 with no approved registration | 400 "register first" |
| A16 | Face ID toggle OFF: any allowed source, no descriptor | 200 (unchanged behaviour) |
| A17 | HR manual correction / invalid-punch conversion | `manual` punch created without a face (server path) |
| A18 | Mobile staging: E1 registered on **web**, punches on **mobile** (and vice versa), 10 genuine and 10 impostor captures | genuine accepted ≥ agreed rate; impostors 0 accepted — **gate for P-2** |

## B. Branch Admin permissions (HO-18 / HO-50)

| ID | Actor / request | Expected after fix | Today (record) |
|---|---|---|---|
| B1 | BA: POST `/training/courses/` | 403 | — |
| B2 | BA+: POST / PATCH / DELETE `/training/courses/…`, materials, thumbnail | 403 after the wildcard fix | **200** (HO-50) |
| B3 | BA+: GET `/training/assessments/`, PATCH `{assessment}` | 403 | 200 |
| B4 | BA: POST `/training/courses/<id>/assign/` with E1 | 200 | 200 |
| B5 | BA: assign with E3 (other branch) | 403 "not in your scope" | 403 |
| B6 | BA: GET progress / reports / dashboard | only B1 rows | B1 rows |
| B7 | Roles API: add `settings.edit` to the `branch_admin` role | 400 (refused) | 200 |
| B8 | BA+: login payload | `is_superuser=false` | true |
| B9 | BA+: company settings (company info, roles, billing/plan) | per P-1b (default 403) | 200 |
| B10 | SYS / HR: all training authoring | 200 (no regression) | 200 |
| B11 | Every module that calls `has_perm` (payroll, recruitment, expenses, leave, attendance, documents, assets, announcements): BA vs SYS | BA gets only held codenames; SYS unchanged | — |

## C. Branch scoping (HO-45)

| ID | Actor / request | Expected |
|---|---|---|
| C1 | BX: GET leave requests `?scope=team` | empty (fail closed); warning logged |
| C2 | BX: GET WFH requests `?scope=team` | empty |
| C3 | BX: training progress / reports / dashboard | empty / zero; no company-wide rows |
| C4 | BA: GET leave requests `?employee_id=<E3>` | 404 |
| C5 | MGR: GET leave requests `?employee_id=<E2>` (not a report) | 404; `?employee_id=<E1>` → 200 |
| C6 | BA: GET WFH requests `?employee_id=<E3>` | 404 |
| C7 | BA: GET leave balances `?employee_id=<E3>` | 404 |
| C8 | BA: GET `/birthdays/` | B1 employees only; no `email` field |
| C9 | BA: GET `/company-contacts/approvers/?workflow=leave` | team = B1 only, paginated; no contact fields for others |
| C10 | NOB (employee, no branch): own requests | 200, own data only |
| C11 | SYS: all of the above | company-wide (no regression) |
| C12 | Unknown `employee_id` vs out-of-scope `employee_id` | both 404 (no existence oracle) |

## D. Archived courses (HO-51)

| ID | Actor / request on an archived course | Expected |
|---|---|---|
| D1 | HR: PATCH course | 409 "archived" |
| D2 | HR: POST thumbnail | 409 |
| D3 | HR: POST material / PATCH material / DELETE material / reorder | 409 each |
| D4 | HR: DELETE course again | per P-5 (idempotent 200 or 409); no state change |
| D5 | HR: POST assign | 400 "Only an active course can be assigned." (existing) |
| D6 | HR: GET course / progress / reports | 200 (history readable) |
| D7 | Employee: GET `my/` | archived course hidden (existing) |

## E. Module gating (regression)

| ID | Request | Expected |
|---|---|---|
| E1 | Company without the `training` module: any `/api/training/*` | 403 "not enabled" (`feature_gate.py:42`) |
| E2 | Same, mobile | both Training menus hidden (mobile tests cover this) |
