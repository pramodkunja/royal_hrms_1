# 04 — UI, Overflow and Design Report

Phase B (17 Nov 2026, 11:39–12:05 IST). Device: moto g06 power, Android 15, 720 × 1640 px at 280 dpi (≈ 411 dp wide), font scale 1.0. App: installed debug build plus code hot-reloaded by an attached `flutter run` session (see 01 §9). Signed in as the Branch Admin test account.

**Scope note.** Everything here was seen on the phone. Web screens weren't rendered: no browser automation is available, so web comparison is **source-only** and is marked as such. Large-text (font-scale) testing hasn't been run: changing the device font setting isn't authorized yet.

## 1. Runtime overflow and exceptions

| Check | Result | Evidence |
|---|---|---|
| Flutter error / overflow lines in the device log (`flutter` tag, whole buffer) | **0 lines** across all ~60 screens and states visited | `adb logcat -d 'flutter:V' '*:S'` returned nothing; the app-PID log (2,583 lines) has no Flutter errors |
| Caveat | Flutter console output also goes to the attached `flutter run` terminal on the developer Mac, which the auditor can't read. Any message that went *only* there isn't covered. | — |
| Visible yellow/black overflow stripes | None seen in any screenshot | evidence/ |

**Conclusion (CORRECTED in C1, see HO-22):** the zero-log result above is **not valid evidence**. During the C1 font-scale test, Flutter's red/yellow overflow stripes appeared on screen (My Payslips and the Employees grid at 1.5), yet the device log, searched across all tags, had no matching line. Flutter error output from this build doesn't reach this phone's logcat. At font 1.0 no overflow stripes were seen in any Phase B or C1 screenshot; that visual check is the only overflow evidence.

## 2. Layout and design defects (by severity)

### P1
- **HO-02: the voice-assistant robot sits above dialogs and takes their taps.** On Apply Leave the robot covered the date picker's OK button. Tapping OK opened a voice recording ("Didn't quite catch that — Listening again") instead of confirming the date, and the picker stayed open. Reproduced twice. Evidence: `evidence/leave/leave_apply_android_robot_covers_datepicker_ok.png`.
  - **Repro:** Leave Management → Apply Leave → tap Start Date → tap a day → tap OK where the robot overlaps it.
  - **Expected:** dialogs sit above every floating control, or the robot hides while a dialog is open.
  - **Hypothesis (unconfirmed):** the robot is in a root `Overlay` or `Stack` above the `Navigator`, so popup routes render beneath it.

### P2
- **HO-03: the robot covers content on almost every screen.** For example: announcement "20d ago" times, attendance status badges, the Apply Leave *Emergency Contact* field, leave preview *Calendar Days / Actual Leave Days* values, payslip *Provident Fund / Total Deductions* amounts, the employee profile *Save* button, and the *Post Announcement / Add Contact / Request Separation* buttons. Its starting position changes between screens (y≈1360–1528 on most, y≈1161–1329 on Leave, mid-right on Referrals). Evidence: `announcements_android_robot_overlay.png`, `my_payslips_android_robot_covers_amounts.png`, `leave_apply_android_preview_panel.png`, `approvals_android_inbox.png`.
- **HO-05: employee profile double header.** The global "Royal HRMS" app bar sits above a second header (back arrow, title cut to "Em…", ID Card, Reset Password, a *second* notification bell). Evidence: `employee_profile_android_double_header.png`.
- **HO-06: a Cancel / Save bar is pinned on a profile opened with the View (eye) button.** It reads as edit mode on a view action. Web behaviour is still to be source-compared.
- **HO-16: demo data visible to the client.** Typos and placeholder text in announcements ("Anniverasary", "nnual Team Outing", "[Company Name]"), the leave type "Materity Leave", and a branch address holding a raw coordinate string. Data, not code.

### P3
- **HO-07: truncated labels at normal font size.**
  - Stat cards: "Total Asse…", "Total Assi…", "Days Pres…", "Late Arriva…", "Present To…", "Geofenced Bran…", "Total Refer…".
  - App bar titles: "Assessment Man…", "Leave Managem…", "Attendance & Ti…", "Branch Manage…", "Face ID Registrati…".
  - Other: "Branch Operati…", "Leave Without P…", "Automatic Bir…".
  - Large text will make this worse (not yet tested).
- **HO-08: scrollable tab bars cut the last label with no scroll hint.** WFH "Daily Work Repo…", Approvals "Face ID Appr…", Referrals "Referral Rul…", Attendance "Un-pu…"; Leave Policy shows 3 of 5 tabs.
- **HO-09:** employee cards leave about 130 px of empty space under the View/Edit buttons.
- **HO-10: icon-only controls have no accessibility label.** This includes the role *Active* switch, a destructive control.
- **HO-14:** Audit Log dates show as "11 / 11 / 2026", while the dashboard card uses "11 Nov, 11:59 am".
- **HO-15:** content scrolls under the translucent Android navigation bar; whether the last items can be scrolled fully clear is not yet verified.

## 3. What looked correct (device-observed)
- The login card, the drawer (30 destinations, grouped MAIN / RECRUITMENT / WORKFORCE / TIME & PAY / HR OPS / MY / SYSTEM) and the profile footer.
- Empty states on Interview List, Review & Onboarding, Email Logs, Expenses, Separation, Document Center, Referrals and the Approvals sub-tabs: an icon plus a message, no blank screens.
- The Leave preview panel, which follows web's structure (headline, 5-row grid, Week-Offs chips with web's date format).
- Settings pages: all 17 open with headers, descriptions and controls aligned.

## 4. Not yet covered (Phase C or needs approval)
- **Large text:** font scale 1.3 / 1.5 / 2.0 (needs approval to change a device setting).
- **Dark mode:** a toggle is present, but untested because it changes a stored preference.
- **Landscape.**
- **Keyboard covering fields:** only the login form was exercised; it scrolled correctly.
- **Every dialog and bottom sheet:** only the date picker and the notifications panel were opened.
- **Web side-by-side visuals:** not possible without browser access.


---

## C1 update (17 Nov 2026, build 1.0.2+8, cold launch, no debug session attached)

### Fixed and retested on the device
| ID | Before (Phase B) | After (C1) |
|---|---|---|
| HO-02 | `evidence/leave/leave_apply_android_robot_covers_datepicker_ok.png`: robot over the date picker's OK; tap started a recording | `evidence/c1_retest/after_leave_apply_datepicker_no_robot.png` (no assistant while the picker is open) and `after_leave_apply_datepicker_ok_confirmed.png` (OK at its centre set 28 Nov 2026; no recording) |
| HO-03 | `evidence/payroll/my_payslips_android_robot_covers_amounts.png`, `evidence/leave/leave_apply_android_preview_panel.png` | `evidence/c1_retest/after_payslip_amounts_unobstructed.png`, `after_leave_apply_preview_unobstructed.png`: 20 × 56 dp edge tab in the page margin; `after_robot_expanded_with_hide_control.png`, `after_robot_auto_collapsed.png` |
| HO-05 / HO-06 | `evidence/employees/employee_profile_android_double_header.png` | `evidence/c1_retest/after_employee_profile_single_header_no_savebar.png`: one header, full title, no pinned Save bar |
| HO-23 (new, fixed) | First 1.0.2+8 build: handle accessibility node [0,0][720,1640] | Final build: [685,1395][720,1493] |

### Task E: font scale 1.0 / 1.3 / 1.5 (device setting changed with permission; restored to 1.0 and verified)
| Scale | Screens captured | Result |
|---|---|---|
| 1.0 | All C1 retest screens | No overflow stripes seen. |
| 1.3 | Approvals, My Payslips, Employees, Settings, My Attendance, Leave (Dashboard capture failed: drawer label lookup missed) | No stripes. **Employees:** stat strip overlaps the "7 employees" line (HO-20). Payslip "House Rent Allowance (H…" truncates. |
| 1.5 | Dashboard, Approvals, My Attendance, Employees, My Payslips, Settings, Leave | **Overflow stripes:** My Payslips month chip "BOTTOM OVERFLOWED BY 8.0 PIXELS" (HO-19); Employees grid cards (HO-20). **Truncation / word breaks:** dashboard KPI labels, Approvals "Pendin / g" (HO-21). Settings and My Attendance wrap acceptably. |

- **Dialog reachability at large text:** at 1.3 the Apply Leave date fields were located, but the picker wasn't opened. At 1.5 the tab tap missed (tab positions shift with larger text). **NOT TESTED.**
- **Tab navigation at large text:** tab bars scroll; labels truncate further (HO-08).
- **Evidence:** `evidence/font_scale/`.


---

## C2 update (build 1.0.2+9, cold launch, 17 Nov 15:48–15:56)

Checked **visually** on screenshots at each scale (logcat isn't a valid overflow check on this device, HO-22). Before = `evidence/font_scale/` (C1), after = `evidence/c2_text_scale/`.

| ID | Root cause | Fix | 1.0 | 1.3 | 1.5 |
|---|---|---|---|---|---|
| HO-19 | `_MonthSelector` fixed at 68 × 132 px | Height and width scale with the text scale | PASS | PASS | PASS (before: "BOTTOM OVERFLOWED BY 8.0 PIXELS") |
| HO-20 | Grid cells from a fixed `childAspectRatio: 0.58`; hero box fixed at 148 px while `StatCardRow` grows to 88 × scale | Content-sized two-card rows (`IntrinsicHeight`); hero reserves `statCardRowHeight(context)` | PASS (no dead space, HO-09) | PASS (no overlap) | PASS (no stripes) |
| HO-21 | `ConsoleStatsRow` four `Expanded` cells; `StatCardRow` fixed card width | Two-column KPI layout above 1.15×; strip cards widen with text (≤1.6×) | PASS (4 across) | (dashboard still loading at capture; widget tests pass) | PASS (KPIs 2 × 2, "Pending" whole) |
| HO-03 residual | The expanded robot stays over content | A global pointer route folds it on any touch outside it (doesn't consume the touch) | PASS | PASS | PASS |

**Other checks at every scale:**
- **Date picker:** OK and Cancel stay on screen and reachable; Cancel closes it.
  - 1.0: buttons at y 1223–1307
  - 1.3: buttons at y 1393–1477
  - 1.5: buttons at y 1427–1511
- **Navigation:** the drawer opens; tab bars scroll.
- **Accessibility:** the handle's semantics node is the tab only ([685,1196][720,1294]).

**Still truncated, P3 (HO-07):**
- app-bar titles at 1.3 and 1.5 ("Team Appr…", "Assessment …");
- payslip "Working D…" at 1.5.

**Not covered at large text:** bottom sheets other than the date picker, and the notifications panel.

**Evidence caveat:** automatic redaction pixelated whole employee-card rows (they're merged accessibility nodes). The card fit at 1.3 and 1.5 is shown by the widget tests and the private raw captures, not by the published images.
