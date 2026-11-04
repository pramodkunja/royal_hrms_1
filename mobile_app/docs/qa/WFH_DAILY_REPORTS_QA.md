# WFH Daily Reports: QA

**Date:** 2026-11-03
**Scope:** porting the web "Daily Work Report" (company policy section 7) to the mobile app.

## Sources inspected (read-only)

- **Backend:**
  - `backend/apps/hrms/views/wfh_reports.py` (views, serializers, review rules)
  - `backend/apps/hrms/models.py` (`WFHDailyReport`)
  - `backend/apps/hrms/urls.py`
- **Web:**
  - `frontend/app/dashboard/work-from-home/_client.tsx`
  - `frontend/app/dashboard/work-from-home/_components/WfhDailyReports.tsx`
  - `frontend/lib/wfhReport.ts`
  - `frontend/lib/api/endpoints.ts`
- **Mobile:** `lib/features/wfh/**`, `lib/core/constants/api_constants.dart`, `lib/shared/widgets/*`, and the existing WFH tab and list patterns.
- **Deployment check:** the backend code arrived in commit `aa99d06` (2026-10-29), which is contained in `origin/production`.

## Parity

| Feature | Web behavior | Backend API | Mobile status (before) | Work done |
|---|---|---|---|---|
| Entry point | WFH page, third tab "Daily Work Report" | n/a | Missing (WFH had two tabs) | Added the third tab to `WfhScreen` |
| Submit report | Date (default today, max today), Work completed *, Pending work, Updates; Submit | `POST /api/wfh/reports/` `{date?, completed_work, pending_work?, updates?}`. Each field is at most 5000 characters. `completed_work` must not be blank. Future dates are refused. An approved WFH request must cover the date. | Missing | Form with the same fields, defaults and limits |
| Edit same day | Re-submit for the same date | The same POST updates a report that is still pending ("Report updated."); reviewed reports are refused | Missing | Supported; the server's message is shown |
| Late flag | "Submitted late" under the date | `submitted_late` (set when the date is before today) | Missing | Shown |
| My reports | Table: date, work (Done / Pending / Updates / Reviewer remarks), status badge, "by <reviewer>" | `GET /api/wfh/reports/?mine=1` | Missing | Card list with the same content |
| Reports to review | Shown only when the list is non-empty; adds employee name and code | `GET /api/wfh/reports/`, scoped server-side to the L1 approver, HR with `wfh.approve`, Branch Admin, or `settings.edit` | Missing | Same rule, plus a visible error if the load fails |
| Review action | Only when `can_review`: outcome (Full Day / Half Day / Not accepted), remarks, Save review | `POST /api/wfh/reports/<id>/review/` `{outcome, remarks}`. Remarks are required for `not_accepted`; a report can be reviewed only once | Missing | Same controls and checks |
| Status labels | Pending review, Accepted — Full Day, Accepted — Half Day, Not accepted | `review_status` | Missing | Same labels and colors |
| Status filter | Not used | `?status=` (review list only) | n/a | Not added (web doesn't use it) |
| Date filter | None | None | n/a | Not possible: no backend support |
| Pagination | None | None. A plain list, newest first, capped at 200 rows | n/a | Not possible: shows the full list as web does |
| Role access | The WFH page is open to everyone; review is decided server-side | `IsAuthenticated` plus the per-report review rules | WFH menu open to all | No client-side role gate; the review UI follows `can_review` |

## Implementation

The new code follows the existing feature layering (entity → model → datasource → repository → Riverpod providers → widgets).

| File | Purpose | Lines |
|---|---|---|
| `lib/core/constants/api_constants.dart` (modified) | Added `wfhReports` and `wfhReportReview(id)` | +3 |
| `lib/features/wfh/domain/entities/wfh_daily_report_entity.dart` (new) | Entity, the `WfhReportReviewStatus` enum (API value and label), the save-result type | 63 |
| `lib/features/wfh/data/models/wfh_daily_report_model.dart` (new) | Parses the serializer's fields only | 42 |
| `lib/features/wfh/data/datasources/wfh_report_remote_datasource.dart` (new) | List (`mine`), submit and review calls | 65 |
| `lib/features/wfh/domain/repositories/wfh_report_repository.dart` (new) | Abstract repository | 24 |
| `lib/features/wfh/data/repositories/wfh_report_repository_impl.dart` (new) | Implementation | 31 |
| `lib/features/wfh/presentation/providers/wfh_report_providers.dart` (new) | Repository provider; my-reports and reviewable-reports providers; submit and review actions | 63 |
| `lib/features/wfh/presentation/wfh_report_strings.dart` (new) | Strings, validation (mirrors web and the serializer), date formatting | 71 |
| `lib/features/wfh/presentation/widgets/wfh_daily_reports_tab.dart` (new) | Tab: form, My Reports, Reports to Review; loading, empty, error and retry states; pull to refresh | 110 |
| `lib/features/wfh/presentation/widgets/wfh_report_form.dart` (new) | Submit form: date picker capped at today, duplicate-submit guard, inline messages | 146 |
| `lib/features/wfh/presentation/widgets/wfh_report_card.dart` (new) | One report | 88 |
| `lib/features/wfh/presentation/widgets/wfh_report_review_panel.dart` (new) | Reviewer controls with duplicate-save guard | 103 |
| `lib/features/wfh/presentation/widgets/wfh_report_section.dart` (new) | Section card, notice banner, status chip | 92 |
| `lib/features/wfh/presentation/screens/wfh_screen.dart` (modified) | Third tab | small |

**Design choices:**
- Errors use the existing `friendlyWfhError` and `parseDioException`, so backend messages reach the user word for word (for example "You have no approved work-from-home request for this date.").
- Authentication and cookies are unchanged; the new calls use the shared `dioProvider`.
- Fonts and colors come from `AppTextStyles` and `AppColors`. There is no dummy data.
- **Date caveat:** the default date and the picker's maximum use the device's local date. The backend uses the company timezone, and its "future date" check is authoritative.

## Automated test results

- **`test/features/wfh/wfh_report_data_test.dart`:** 11 tests.
  - Parsing: every field, all statuses, defaults.
  - Requests: the exact path and query for both lists (no paging or date parameters), the exact submit body, the review path and body.
  - Backend refusals are passed through.
  - Validation: required, whitespace, 5000-character limits, review rules, date format.
- **`test/features/wfh/wfh_daily_reports_tab_test.dart`:** 10 tests.
  - Loading then empty state.
  - Error then Retry.
  - Own report rendering, including the late flag and remarks.
  - Role visibility: the review block is hidden when the list is empty, and controls appear only with `can_review`.
  - Review validation and a single request on save.
  - Submit: local validation, today's date sent, form cleared on success, backend refusal shown with the text kept.
  - Duplicate-submit prevention: two taps before a rebuild send one request. This test fails when the guard is removed.
  - The date picker's maximum is today.
  - Navigation: the WFH screen tab opens the form.
- **Full suite:** `flutter test` gives **130/130 pass**.
- **`flutter analyze`:** 13 info messages, all pre-existing (`curly_braces_in_flow_control_structures`). None in the new code.

## Emulator results by role

- **Device:** `emulator-5554` (AVD `Android_Emulator_34`, Android 14 / API 34).
- **Build:** the debug APK (arm64) with this feature built, installed and launched. Royal HRMS is in the foreground on its login screen.

| Role | Result | Notes |
|---|---|---|
| Employee | BLOCKED | No login attempted (see below) |
| Manager | BLOCKED | No login attempted |
| HR Admin | BLOCKED | No login attempted |
| Branch Admin | BLOCKED | No login attempted |
| System Admin | BLOCKED | No login attempted |

## API failures and blockers

1. **Credentials.** `~/royal_demo_accounts.txt` has not changed since 2026-11-02 16:10. Its values were rejected on 2026-11-02 for the employee and manager accounts. Under this task's rule ("If production credentials are rejected, stop"), no login was attempted.
2. **Production data.** Submitting or reviewing a report creates or changes production records, and reviewing can re-derive attendance. This task forbids modifying production data, so even with working credentials the live check is limited to viewing the tab, the lists, and the empty and error states. A live write test needs explicit approval and an employee with an approved WFH request for the date.

## Screenshots

None: no authenticated session was possible.

## Remaining work

- Live verification for each role once working credentials are available: the tab, My Reports, Reports to Review visibility for reviewers (manager, HR, Branch Admin, System Admin), and the no-review state for employees.
- Optionally, with approval, one live submit and review on a test account that has an approved WFH day.
- Out of scope here: WFH medical proof upload (also part of policy section 6 on web).

## Final status

**PARTIAL**: discovery, implementation and automated verification are complete. Live emulator verification is blocked by credentials.
