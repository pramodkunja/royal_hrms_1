# Google Play Data Safety Worksheet — Royal HRMS Android 1.0.0 (6)

**For:** the Play Console owner who fills in Policy → App content → Data safety.
**Basis:** the code inventory in `PRIVACY_INVENTORY_AND_POLICY_DRAFT.md` (Part A). "Confirm" marks an answer that depends on company facts not visible in code. Do not submit those until confirmed.

## Overall questions

| Question | Proposed answer | Basis / confirm |
|---|---|---|
| Does the app collect or share any of the required user data types? | **Yes** | Part A |
| Is all user data encrypted in transit? | **Yes** | HTTPS-only API (`https://royalhrms.com/api/`); release builds block cleartext |
| Do you provide a way for users to request that their data is deleted? | **Confirm** — likely "Yes, through the employer's HR", if that process exists | Question 9. Accounts are employer-created; there is no in-app account creation, so Play's in-app deletion requirement should not apply. Confirm with policy guidance. |
| Committed to Play Families policy? | Not applicable (adults only) | Question 11 |
| Independent security review? | No (unless the company has one) | Confirm |

**"Shared"** in Play's terms excludes transfers to service providers processing on your behalf (Cloudinary, Sarvam AI, email provider) and transfers the user starts. Proposed: **not shared** for all types, *provided* data processing agreements exist (Questions 6–8).

## Data types

**Col** = collected; **Req/Opt** = required or optional for the user; **Enc** = encrypted in transit; **Del** = user can request deletion.

| Category → type | Col | Shared | Purpose(s) | Req/Opt | Enc | Del | Evidence | Confirm |
|---|---|---|---|---|---|---|---|---|
| **Location → Precise location** | Yes | No | App functionality (attendance geofence, WFH location) | Required for clock-in | Yes | Confirm | Punch `latitude/longitude/accuracy`; WFH `latitude/longitude` | Retention |
| Location → Approximate location | Yes (via `ACCESS_COARSE_LOCATION`) | No | Same | Required | Yes | Confirm | Manifest | — |
| **Personal info → Name** | Yes | No | App functionality, account management | Required | Yes | Confirm | `/employees/me/` | — |
| Personal info → Email address | Yes | No | Account management, functionality, communications | Required | Yes | Confirm | Login, profile | — |
| Personal info → User IDs | Yes (employee ID, account ID) | No | Account management, functionality | Required | Yes | Confirm | Profile | — |
| Personal info → Address | Yes | No | Functionality (HR records) | Required (onboarding) | Yes | Confirm | Onboarding, profile | — |
| Personal info → Phone number | Yes | No | Functionality, communications | Required/Opt per company config | Yes | Confirm | Profile, emergency contact | — |
| Personal info → Other info | Yes: DOB, gender, marital status, father's name, PAN and other IDs, education, work history, emergency contacts | No | Functionality (HR/onboarding) | Per company config | Yes | Confirm | Onboarding field config | — |
| Personal info → Race/ethnicity, political, religious, sexual orientation | **No** | — | — | — | — | — | Not in any form | — |
| **Financial info → Other financial info** | Yes: bank account and IFSC, salary and payslips, expense amounts | No | Functionality (payroll, reimbursement) | Required (bank in onboarding) | Yes | Confirm | Onboarding step 2, payslips, expenses | — |
| Financial info → Payment info / purchase history / credit score | **No** | — | — | — | — | — | No payments in app | — |
| **Health and fitness → Health info** | Yes: medical WFH proof, blood group | No | Functionality | Optional (only for medical WFH; blood group per company config) | Yes | Confirm | Medical proof upload; onboarding | — |
| **Photos and videos → Photos** | Yes: uploaded document images, profile photo, receipts. **Face photos are not uploaded** (processed on device only) | No | Functionality | Optional/Required per feature | Yes | Confirm | Uploads | Disclose face-image processing in the policy |
| **Audio → Voice or sound recordings** | Yes (voice commands, Hindi fallback clip) | No (Sarvam is a processor) | Functionality | **Optional** | Yes | Confirm | `/voice/transcribe-fallback/` | Question 6 |
| **Files and docs** | Yes | No | Functionality | Required for onboarding docs; otherwise optional | Yes | Confirm | Onboarding, Documents, WFH, separation, expenses | — |
| **App activity → Other user-generated content** | Yes: payslip queries, leave/WFH reasons, comments, remarks, voice transcripts | No | Functionality | Optional | Yes | Confirm | Various | — |
| App activity → App interactions | Yes, limited: policy acknowledgements, announcement views and reactions, audit events | No | Functionality, security/fraud prevention | Required | Yes | Confirm | `views_policy.py`, audit log | — |
| **App info and performance → Crash logs / diagnostics** | **No** | — | — | — | — | — | No crash/analytics SDK | — |
| **Device or other IDs** | Yes (app-generated random device ID) | No | Fraud prevention, security (attendance) | Required (sent with punches) | Yes | Confirm | `device_identifier.dart` | — |
| **Biometric** (Play lists this under "Personal info → Other" or the dedicated biometric disclosure) | Yes: face template (embedding) | No | App functionality, security/fraud prevention (identity verification at clock-in) | Required only if the employer mandates Face ID | Yes; **encrypted at rest** | Yes: purged on deactivation or deletion; Confirm the request route | `FaceRegistrationRequest.face_embedding` `EncryptedJSONField`; `purge_face_data_for_employee` | Question 4 |
| Messages (email/SMS/other) | **No** | — | — | — | — | — | — | — |
| Contacts (address book) | **No** (no contacts permission; emergency contacts are typed in) | — | — | — | — | — | Manifest | — |
| Calendar | **No** | — | — | — | — | — | — | — |
| Web browsing / installed apps / search history | **No** | — | — | — | — | — | — | — |

## Before submitting

- Resolve every "Confirm" cell with the privacy owner.
- Publish the privacy policy at a public URL first. The Data safety answers must match it.
- Google Fonts download (IP address to Google) is generally not declared as collection by the app. Confirm with the policy owner, or remove it later by bundling the font in a future build.
