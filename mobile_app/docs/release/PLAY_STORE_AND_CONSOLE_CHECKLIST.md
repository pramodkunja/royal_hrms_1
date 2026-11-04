# Play Store Listing and Play Console Checklist — Royal HRMS Android 1.0.0 (6)

**For:** the Play Console owner. Nothing here has been changed in Play Console. Every Console item below is a manual check for the owner.

## 1. Release artifact (verified 2026-11-04)

| Item | Value |
|---|---|
| File | `mobile_app/build/app/outputs/bundle/release/app-release.aab` (built 2026-11-04 12:14) |
| SHA-256 of the file | `c8827b4f1b5d9de0c21dfd6d5fa9751ce336195762acc382dcde65db8a2e41da` |
| Application ID | `com.royalhrms.app` |
| Version | name `1.0.0`, code `6` |
| Target / min SDK | 36 / 24 |
| Signed by (upload key) | CN=Royal HRMS, OU=Royal Staffing, O=Royal Staffing, L=Hyderabad, ST=Telangana, C=IN |
| Upload certificate SHA-256 | `C3:64:02:52:0D:91:0B:77:8C:9B:D4:91:08:52:0D:3B:1B:EB:DC:A1:8A:F6:06:76:3B:DC:F0:C8:7E:2B:92:A7` |
| Debug key? | No (debug SHA-256 `38:EA:BE:…` differs) |
| API | release builds always use `https://royalhrms.com/api/` |
| Permissions | INTERNET, ACCESS_NETWORK_STATE, ACCESS_FINE/COARSE_LOCATION, CAMERA, RECORD_AUDIO, READ_EXTERNAL_STORAGE (and WRITE_EXTERNAL_STORAGE ≤ Android 9, from the camera library) |

## 2. Store listing assets

| Asset | Status | Notes |
|---|---|---|
| App icon 512×512 PNG | ✅ Ready | `assets/icon/play_store_icon_512.png` (32-bit PNG, Royal HRMS emblem; replaces the icon rejected in October) |
| Feature graphic 1024×500 | ❌ Missing | Needs design. Use the brand emblem and name only, with no device frames claiming unbuilt features. |
| Phone screenshots (2–8) | ❌ Missing | Must be real signed-in screens. **Use a test company with dummy data.** Real employees' names, salaries, PAN or bank details must not appear. Suggested: dashboard, attendance clock-in, leave, payslip, documents/policy, manager dashboard. |
| App name | ✅ "Royal HRMS" (matches the app label) | |
| Short description (≤80) | Draft below | |
| Full description (≤4000) | Draft below | |
| Release notes | Draft below | |

### Short description — draft (74 characters)
> Attendance, leave, payslips and HR approvals for Royal HRMS employees.

### Full description — draft (only features in this build)
> Royal HRMS is the mobile companion for organisations that use Royal HRMS. Sign in with the company code and account your employer provides.
>
> **For employees**
> • Clock in and out with location-based attendance and optional Face ID verification
> • View your attendance calendar and request corrections
> • Apply for leave and work from home, including medical WFH with proof
> • View payslips and raise a query on a payslip
> • Complete onboarding: personal details, documents and assessments
> • Read company documents and acknowledge policies
> • Submit expenses and separation requests
> • See announcements, your requests and the company Contact Matrix
> • Optional voice commands for common actions
>
> **For managers and HR**
> • Team dashboard with today's attendance, pending approvals and upcoming leave
> • Approve leave, WFH, expenses, attendance corrections and separation requests
> • Manage documents and see who has acknowledged policies
>
> An account from your employer is required. Features shown depend on your role and on what your employer has enabled.

### Release notes (1.0.0) — draft
> First release of the Royal HRMS Android app: attendance with location and Face ID, leave and WFH, payslips and payslip queries, onboarding and assessments, documents and policy acknowledgement, separation, approvals and the manager dashboard.

## 3. Play Console — manual checks (owner)

| # | Check | How | Status |
|---|---|---|---|
| 1 | Version code 6 is free | Release → App bundle explorer: confirm no bundle with code ≥ 6 exists | ☐ |
| 2 | Play App Signing enrolled | Setup → App signing: "Releases signed by Google Play" | ☐ |
| 3 | Upload certificate matches | Setup → App signing → *Upload key certificate* SHA-256 must equal `C3:64:02:…:92:A7` (above). If it differs, **stop**: the AAB will be refused. | ☐ |
| 4 | App access | Policy → App content → App access: "All or some functionality is restricted". Give a **reviewer account** (company code, email, password) that is onboarding-complete, assessment-complete, not flagged for a password change, with Face ID not mandatory (or explain how to pass it), plus one line on location. | ☐ (account needed) |
| 5 | Privacy policy URL | App content → Privacy policy: public HTTPS URL of the reviewed policy (see the draft) | ☐ (not published) |
| 6 | Data safety | Complete from `DATA_SAFETY_WORKSHEET.md` after the privacy owner confirms the open items | ☐ |
| 7 | Permissions | Location: foreground only, so no background-location declaration is needed. Camera and microphone: no special declaration form, but disclose in Data safety and the privacy policy. No SMS, call-log or all-files-access permissions. | ☐ |
| 8 | Content rating | IARC questionnaire: utility/productivity, no violence, sexual content, gambling or user-to-user public sharing | ☐ |
| 9 | Target audience | 18+ only; not designed for children | ☐ |
| 10 | Ads | "No, my app does not contain ads" (no ad SDK in the build) | ☐ |
| 11 | Government app / financial features declarations | Not a government app. Financial features: none (shows payslips, no payments or lending); answer accordingly. | ☐ |
| 12 | Health apps declaration (if asked) | The app collects limited health info (medical proof) for HR purposes; it is not a health app | ☐ |
| 13 | Internal testing track | Create the release, upload the AAB, add testers, install from Play and run `INTERNAL_TEST_CHECKLIST.md`, **including face capture** | ☐ |
| 14 | Pre-launch report | After the internal upload, review Play's automated pre-launch report (crashes, accessibility). The robot cannot sign in unless credentials are supplied. | ☐ |
| 15 | Production release | Only after 1–14, and after the signed-in internal test passes | ☐ |
| 16 | New personal developer accounts only | If the developer account is a personal account created after November 2023, Google requires a closed test with ≥12 testers for 14 days before production. Check whether this applies. | ☐ |
