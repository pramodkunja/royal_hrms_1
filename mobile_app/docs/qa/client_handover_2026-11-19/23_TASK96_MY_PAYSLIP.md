# 23 — Task 96: My Payslip complete web-to-mobile parity (19 Nov 2026)

**Scope:** fix the P1 My Payslip gaps from Task 95 (E-31…E-35, register HO-62) and re-verify the Employee dashboard Action Items / Recent Activity parsing (HO-60). Mobile-only; backend and web read-only; no git change, no production write, no phone install, release AAB untouched.
**Evidence levels:** *implemented* (source) · *mocked* (stand-in server tests — **not** production verification) · *device/staging* (**not done**). Payroll data in every test is synthetic.

## 1. Sources compared
Web: `app/dashboard/my-payslip/page.tsx`, `components/payroll/PayslipDocument.tsx`, `WageSlipDocument.tsx`, `PayslipPrint.tsx`, `lib/payslipLayout.ts`. Backend (read-only): `apps/payroll/serializers.py` `EmployeePayslipSerializer` (lines 393-512), `views/cycles.py:_payslip_copies` (how `adjustment_items` and the identity snapshot are written), `views/payslips.py` (own payslips, drafts excluded). Mobile: `payroll/data/models/payslip_model.dart`, `presentation/screens/my_payslip_screen.dart`, `presentation/payslip_pdf.dart`.

## 2. Exact API fields (GET `/payroll/my-payslips/` → `{data:{count, results:[…]}}`)
Money fields are DRF decimals serialised as **strings**. Used by web and now by mobile: `id, cycle_start, cycle_end, pay_date, employee_name, employee_id_code, department, designation, principal_employer_name, company_header{company_name,address,city,state,pin_code,cin}|null, payslip_template ("standard"|"wage_slip"), uan_display|null, esic_display|null, fixed_deduction_rows[], stamp_url|null, basic, hra, special_allowance, other_earnings{label:number}, other_deductions{label:number}, reimbursements, bonus, gross_earnings, total_working_days, lop_days, lop_deduction, pf_employee, esi_employee, pt_deduction, lwf_employee, adjustments_earning, adjustments_deduction, adjustment_items[{type: addition|arrear|deduction, label, amount(string)}], total_deductions, net_pay, status, payslip_pdf, query_deadline`. Not used by web either: `annual_ctc, monthly_ctc, bonus_breakdown, pf_employer, esi_employer, lwf_employer, structure_name`.

## 3. Field-by-field parity matrix (My Payslip document)
S = standard layout, W = wage-slip layout. Evidence: M = mocked test, S = source only.
| # | Web element (ref) | Mobile before | Mobile after | Status | Evidence |
|---|---|---|---|---|---|
| 1 | Page subtitle "View and download your monthly salary statements" (`page.tsx:233`) | different wording | web wording | COMPLETE | M |
| 2 | Empty state "No payslips yet" + description (`page.tsx:195-198`) | one-line text | title + description | COMPLETE | M |
| 3 | Loading / error | spinner / server message + Retry | unchanged; mobile adds Retry (web shows a fixed message) — deliberate | COMPLETE | M |
| 4 | Status labels Received / Query open / Processing / Closed (`page.tsx:96-104`) | Sent / Query Raised / Draft; no Closed | web labels | COMPLETE | M |
| 5 | Month selector (month, pay date, status) | month + status | unchanged (pay date is in the document: "Salary Date") — layout adaptation | PARTIAL (layout) | S |
| 6 | Sidebar employee card (initials, designation, id, department, joined) | none | none | PARTIAL — not in scope of payslip data; see §8 | — |
| 7 | S letterhead: saved `company_header` laid over live company, CIN, address | live company only | merged (saved fields win, even blank) | COMPLETE | M |
| 8 | S company logo / "PAYSLIP" band / phone in footer | footer phone ✔, no logo | footer phone ✔; **logo not shown** | PARTIAL | S |
| 9 | S strip: Employee ID, Bank, Account No. (masked), IFSC | ✔ | ✔ | COMPLETE | M |
| 10 | S strip: **UAN**, **ESIC No.** when server sends a value | missing | added (masked/hidden exactly as the server sends) | COMPLETE | M |
| 11 | S attendance summary (working / paid / LOP + "₹X deducted") | ✔ | ✔ | COMPLETE | M |
| 12 | S earnings: Basic, HRA, Special, Bonus, named other earnings; zeros hidden, negatives shown | ✔ | ✔ | COMPLETE | M |
| 13 | S **additions / arrears inside gross** listed among earnings | missing | added | COMPLETE | M |
| 14 | S **Additions panel** (outside gross) with rows + total | missing | added (`additionsOutsideGross`, ±0.5 tolerance) | COMPLETE | M |
| 15 | S deductions: PF, ESI, PT, LWF, named, **one-time deductions**, LOP last | no one-time deductions | added; older payslips show "Other deductions" / "Additions" total line | COMPLETE | M |
| 16 | S reimbursements line only when > 0 | ✔ | ✔ | COMPLETE | M |
| 17 | S net banner: "Net Salary Credited", subline, Gross − Ded. **+ Add.** + Reimb., net, In Hand | no "+ Add." | added in web order | COMPLETE | M |
| 18 | S footer text + HR phone | ✔ | ✔ | COMPLETE | M |
| 19 | **W wage-slip layout** (`payslip_template == "wage_slip"`): letterhead + principal employer, period title, employee block (code, name, department, designation, PF/UAN, ESIC, month days, present, LOP days), SALARY HEAD / ACTUAL / EARNING / DEDUCTION grid, TOTAL GROSS, TOTAL DEDUCTION, NET SALARY PAY, signatures | missing (always standard) | added (`_WageSlipDocument`) | COMPLETE | M |
| 20 | W LOP split across components, rounded, remainder on the largest; fixed deduction rows; Bonus / Reimbursement / additions with blank Actual | missing | ported (`payslip_layout.dart`) | COMPLETE | M |
| 21 | W stamp image above "Authorized Signature" (`stamp_url`) | missing | shown on screen when the link loads; never printed as text | PARTIAL — not in the PDF | S |
| 22 | Acknowledge (only when `sent`) label "Acknowledge" | "Acknowledge Payslip" | "Acknowledge" | COMPLETE | M |
| 23 | Raise Query + queries list | ✔ (Task 70s) | unchanged | COMPLETE | M |
| 24 | Print / Save PDF (browser print of the same document) | PDF built from the standard layout only | PDF now includes adjustments, Additions, UAN/ESIC, HR phone, saved letterhead and the **wage-slip layout** | COMPLETE (stamp image omitted) | M (builds real PDF bytes) |
| 25 | Download PDF (stored `payslip_pdf`) | disabled when none | unchanged — the backend never fills `payslip_pdf` | BLOCKED on backend (web same) | S |

## 4. Before / after Flutter mapping
- **Model (`payslip_model.dart`)** — before: 20 fields, no adjustments/template/UAN/ESIC/letterhead/stamp. After: adds `adjustmentItems, adjustmentsEarning, adjustmentsDeduction, designation, principalEmployerName, companyHeader, payslipTemplate, uanDisplay, esicDisplay, fixedDeductionRows, stampUrl` (all optional with safe defaults), `isWageSlip`, `payslipMoney()`. Non-finite amounts (NaN/Infinity) now read as 0 (web `num()`); unreadable lists are empty. Status labels replaced by web's. `copyWith` keeps every new field.
- **New `domain/payslip_layout.dart`** — port of `payslipLayout.ts` plus the row rules of `PayslipDocument.tsx`: `componentRows, splitLop, adjustmentRows, additionsOutsideGross, standardEarningRows, standardDeductionRows, additionsPanel, wageSlipModel, wageSlipPeriodLabel, formatWageSlipAmount, PayslipLetterhead.merge, standardStrip, wageSlipInfo, jsRound` (JavaScript `Math.round`). Nothing recalculates payroll.
- **Screen** — before: one standard card from live company data. After: letterhead merged from the saved header; strip via `standardStrip`; earnings/deductions from the shared rows; Additions panel; "+ Add." in the banner; wage-slip card for `wage_slip` payslips; web copy for subtitle/empty state/status/Acknowledge.
- **PDF** — before: standard layout only, no adjustments. After: same rows as the screen, Additions block, UAN/ESIC, HR phone, wage-slip page.
- `payslipEarningLines` / `payslipDeductionLines` kept (now delegate to the shared rows).

## 5. Financial reconciliation evidence (`test/features/payroll/payslip_task96_reconciliation_test.dart`, 41 tests)
Rule: **web never recalculates** — each figure is a saved value and the layout only chooses where it appears; the tests assert exactly that.
1. *Placement:* every component lands in the web section (earnings / deductions / Additions panel / reimbursements); zero rows hidden, negatives shown (`₹-500`), Basic kept first in the wage slip even at 0.
2. *Totals reconcile for consistent payloads:* earning rows sum to `gross_earnings` (additions inside gross); deduction rows (LOP last) sum to `total_deductions`; `gross − deductions = net` — and with additions outside gross, `gross − deductions + additions + reimbursements = net` (the banner formula). Wage slip: Earning column = round(components − LOP) + bonus + reimbursement + additions; deduction total = `total_deductions − lop_deduction`; net = stored `net_pay`.
3. *Net pay is the server value:* an inconsistent payload (gross 90,000, net 12,345) is shown as saved and the wage slip prints the stored net — nothing is "corrected".
4. *Rounding/currency:* JavaScript `Math.round` (halves → +∞, so −2.5 → −2), whole-rupee INR with Indian grouping and `₹-` for negatives, wage-slip amounts up to 2 decimals with no trailing zeros (`12,34,567.5`, `-1,234.5`, no `-0`), NaN/Infinity/unreadable → 0.
5. *LOP split:* sums exactly to round(components − LOP), remainder to the largest component, LOP above gross → 0, negative LOP ignored.
6. *Missing optional data:* a payslip with none of the new fields renders as before; unknown template → standard; `uan_display` null hides, empty shows "—" (wage slip) or is omitted (standard strip).
7. *Mutation testing* (5 deliberate breaks of the financial logic, then restored byte-for-byte): tolerance, dropped rounding remainder, additions always folded into gross, LOP double-counted in the wage-slip deduction total, net recomputed instead of read — **all caught**. (One mutant initially survived — the upper side of the ±0.5 tolerance; a test was added and it is now caught.)
8. *Not logged:* rendering writes no payroll figure, account number or UAN to `debugPrint`; the signed stamp link is never shown as text.
9. *Permission / errors:* 403 "You do not have permission to view payslips." shown with nothing rendered; a 500 shows Retry and Retry loads the payslips; empty list shows web's copy.
Other tests: standard/wage-slip widgets (adjustments inside/outside gross, arrears, older total-only form, strip UAN/ESIC, letterhead override, status/Acknowledge, wage-slip grid and totals), PDF build with real fonts for both layouts.

## 6. Phase 5 — Employee dashboard API verification (HO-60)
Backend `EmployeeActionItemsView` and `EmployeeRecentRequestsView` (`apps/dashboard/views/people.py`) return `success(message, data=paginated_data(...))` = `{count, page, page_size, total_pages, results}` (page size 5); item fields `action_type, title, description, status, navigation_url` / `request_type, title, applied_date, status, remarks, details` match the mobile models. Task 95's fix reads `results`/`count` (old keys still accepted). New in Task 96: models no longer throw on a malformed body (non-list `results`, non-numeric `count` → empty / 0 — found by the new test); regression tests run through the real datasource and HTTP parsing: first page of a 7-row list (count 7, 5 rows), empty page, recent requests with details, 403 and 500 reach the caller (never shown as empty), unexpected body shapes. Mocked only — **still to be verified with a real Employee login**.

## 7. Files changed (mobile only)
`lib/features/payroll/data/models/payslip_model.dart`; NEW `lib/features/payroll/domain/payslip_layout.dart`; `presentation/screens/my_payslip_screen.dart`; `presentation/payslip_pdf.dart`; `lib/features/dashboard/data/models/employee_dashboard_models.dart`. Tests: NEW `test/features/payroll/payslip_task96_reconciliation_test.dart`; `payslip_document_parity_test.dart` (harness `pumpWith`, web empty-state copy); `test/features/dashboard/employee_dashboard_envelope_test.dart` (now 9 tests). Docs 07, 10, 20, 23.

## 8. Test and analyzer results
Focused: payroll 76 passed; dashboard 229 passed. **Full suite: 2,907 passed (was 2,860).** `flutter analyze`: 7 infos, all pre-existing (none in changed files); 0 errors/warnings.

## 9. Remaining differences and API dependencies
- **Company logo** in the standard letterhead and the **sidebar employee card** (designation, joined date) are not on mobile (layout-only; data exists via `settings/company` and `employees/me`).
- **Stamp image** is shown on screen but not embedded in the printed PDF (would need the signed file downloaded; the link is short-lived).
- **Month tile** shows month + status, not the pay date (pay date is in the document).
- **Backend:** `payslip_pdf` is never populated, so "Download PDF" stays disabled (same on web). `stamp_url` / file links are short-lived signed URLs. No missing payroll field was found — every value web shows is in the existing response; **no backend change requested**.
- Web quirk noted, not copied: none new.

## 10. Device / staging verification still required (nothing below has been run)
1. A real employee payslip with a one-time **addition/arrear** (inside and outside gross) and a one-time **deduction** — compare each total to the web page for the same payslip.
2. A **wage-slip template** company: layout, period title, LOP split, stamp, print/share PDF.
3. UAN/ESIC visibility with payroll settings (show/hide, masked/unmasked).
4. A payslip with **negative** or zero lines; draft payslips must not appear.
5. Acknowledge and Raise Query writes on a **test** tenant only.
6. Print / Save PDF output on the phone for both layouts (stamp omitted by design).
7. Employee dashboard Action Items / Recent Activity with a real Employee login.
No phone build was installed; the device still runs debug code 17.
