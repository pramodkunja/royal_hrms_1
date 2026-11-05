# Google Play Data Safety Worksheet — Royal HRMS Android update (1.0.0)

**For:** the Play Console owner who fills in Policy → App content → Data safety, and the company's privacy owner.
**Updated:** 2026-11-05 (mobile code through Phase 11.8).
**Basis:** the code inventory in `PRIVACY_INVENTORY_AND_POLICY_DRAFT.md`, Part A. Question numbers (Q1–Q15) refer to Part B of that document.
**Status:** worksheet only. **The Data Safety form in Play Console has not been filled in or submitted.** Do not submit any answer marked **Requires confirmation** until the company has confirmed it, and make sure the answers match the published privacy policy.

## How to use this worksheet

- **Collected** (Play's meaning): data the app sends off the device. Data handled only on the device (for example camera frames used for on-device face detection) is not "collected", but it is disclosed in the privacy policy.
- **Shared** (Play's meaning): data passed to a third party. Play treats some transfers as *not* sharing — for example to a service provider that processes data on your behalf under contract, or a transfer the user starts. **Whether a vendor qualifies is a contractual and legal question, not something the code can prove.** This worksheet therefore does **not** assume that a processor means "not shared": wherever a third-party service receives the data, the Shared answer is **Requires confirmation**.
- Where no third party receives the data in any code path we can see, the answer is "No third party found in code — Requires confirmation", because the backend's hosting, backup and support arrangements are not visible in the code (Q15).

## Overall questions

| Question | Proposed answer | Evidence / what needs confirming |
|---|---|---|
| Does the app collect or share any of the required user data types? | **Yes** | Part A of the privacy inventory |
| Is all user data encrypted in transit? | **Yes** (proposed) | All API traffic is HTTPS to `https://royalhrms.com/api/`; release builds always use the production URL; the main manifest does not allow cleartext (only the debug build has a network security config). Requires confirmation that no backend-to-vendor transfer is unencrypted (Q6–Q8, Q15). |
| Do you provide a way for users to request that their data is deleted? | **Requires confirmation** | No in-app deletion; accounts are created by employers. Depends on the HR process (Q9). Whether Play's account-deletion requirement applies to employer-created accounts must be confirmed against current Play policy. |
| Committed to the Play Families policy? | Not applicable (adults only) — **Requires confirmation** | Q11 |
| Independent security review? | **Requires confirmation** (proposed "No" unless the company has one) | — |

## Data types

| Category → type | Collected? | Temporary or stored | Service providers involved (from code) | Shared (Play)? | Purpose | Protection evidence | Retention / deletion | Requires confirmation |
|---|---|---|---|---|---|---|---|---|
| **Location → Precise location** | Yes | Stored with each punch; WFH request / saved WFH location | None found in code | No third party found in code — **Requires confirmation** | App functionality (attendance geofence, WFH) | HTTPS; foreground-only permission | **Requires confirmation** (Q3) | Retention; recipients (Q15) |
| Location → Approximate location | Yes (`ACCESS_COARSE_LOCATION` is declared) | As above | None found in code | **Requires confirmation** | As above | As above | **Requires confirmation** (Q3) | As above |
| **Personal info → Name, email, user IDs** | Yes | Stored (account and HR record) | Email provider for notification emails (backend) | **Requires confirmation** (Q8) | Account management, app functionality, communications | HTTPS; role-based access on the server | **Requires confirmation** (Q3, Q9) | Email provider identity and terms |
| Personal info → Address, phone | Yes | Stored | None found in code | **Requires confirmation** | App functionality (HR records) | HTTPS | **Requires confirmation** | — |
| Personal info → Other info (DOB, gender, marital status, father's name, PAN/UAN and other IDs, education, work history, emergency contacts, company-defined custom fields) | Yes | Stored | Cloudinary for uploaded ID documents (see Files) | **Requires confirmation** | App functionality (onboarding, HR) | HTTPS; identifiers masked in the HR approval view | **Requires confirmation** | — |
| Personal info → Race/ethnicity, political or religious beliefs, sexual orientation | **No** | — | — | — | — | — | — | — |
| **Financial info → Other financial info** (bank account and IFSC, salary and payslips, expense amounts, payslip queries) | Yes | Stored | None found in code for these fields (receipts: see Files) | **Requires confirmation** | App functionality (payroll, reimbursement) | HTTPS | **Requires confirmation** | — |
| Financial info → Payment info / purchase history / credit score | **No** (no payments in the app) | — | — | — | — | — | — | — |
| **Health and fitness → Health info** (medical WFH proof, blood group) | Yes | Stored (proof file with Cloudinary) | Cloudinary | **Requires confirmation** (Q7) | App functionality | HTTPS | **Requires confirmation** | Whether the company treats these as health data for the declaration |
| **Photos and videos → Photos** (uploaded document images, profile photo, receipts) | Yes | Stored with Cloudinary | Cloudinary | **Requires confirmation** (Q7) | App functionality | HTTPS; documents downloaded only with the user's sign-in; viewed inside the app | **Requires confirmation** | — |
| Photos → **face photo** | **Not collected** (processed on the device only; the photo is not uploaded) | Temporary file on the device; the app does not delete it (Q5) | Google ML Kit **on device** | — | Liveness and face template | On-device only | Stays in the app cache until the system clears it | Disclose in the policy; Q5 |
| **Audio → Voice or sound recordings** (voice commands; Hindi fallback clip) | Yes (optional feature) | Clip uploaded to the backend and sent to Sarvam AI; whether it is kept is not visible in code | Sarvam AI (backend); device speech-recognition service (Q14) | **Requires confirmation** (Q6, Q14) | App functionality (voice commands) | HTTPS to the backend | **Requires confirmation** (Q3, Q6) | Sarvam retention and terms; device speech service |
| **Files and docs** (onboarding documents and custom file fields, profile documents, WFH proof, separation documents, receipts, Document Center) | Yes | Stored with Cloudinary. On the device, a viewed PDF is a temporary private copy deleted on close, at start and at sign-out; images are never written | Cloudinary | **Requires confirmation** (Q7) | App functionality | HTTPS; sign-in required to download; viewed only inside the app (no other app receives the file) | **Requires confirmation** (Q3) | Cloudinary region, retention, terms |
| **App activity → Other user-generated content** (leave/WFH reasons, WFH daily reports, comments, remarks, payslip queries, voice transcripts) | Yes | Stored; transcripts may go to Sarvam AI for classification | Sarvam AI (transcripts only) | **Requires confirmation** (Q6) | App functionality | HTTPS | **Requires confirmation** | — |
| App activity → App interactions (policy acknowledgements, announcement views and reactions, audit events) | Yes | Stored | None found in code | **Requires confirmation** | App functionality; security / fraud prevention | HTTPS | **Requires confirmation** | — |
| **App info and performance → Crash logs / diagnostics** | **No** (no crash-reporting or analytics SDK) | — | — | — | — | — | — | — |
| **Device or other IDs** (app-generated random 128-bit device ID) | Yes | Stored on the device in secure storage; sent with each punch and stored with it | None found in code | **Requires confirmation** | Security / fraud prevention (attendance) | Generated with a secure random source; HTTPS | **Requires confirmation** | — |
| **Biometric face template** (192-value embedding) + liveness result | Yes (only where the employer requires Face ID) | Registration template stored **encrypted at rest** (`EncryptedJSONField`); punch-time template sent for matching | None found in code | **Requires confirmation** | App functionality; security / fraud prevention (identity at clock-in) | HTTPS; encrypted at rest; consent captured before registration | Server purges face data when the employee is deactivated or deleted (`purge_face_data_for_employee`). Whether punch-time templates are kept: **Requires confirmation** (Q4) | Q4; how Play's form should record biometric data (no dedicated category — confirm placement) |
| Messages (email/SMS/other) | **No** | — | — | — | — | — | — | — |
| Contacts (address book) | **No** (no contacts permission; emergency contacts are typed in) | — | — | — | — | — | — | — |
| Calendar | **No** | — | — | — | — | — | — | — |
| Web browsing / installed apps / search history | **No** | — | — | — | — | — | — | — |

## Other items to decide before submitting

- **Google Fonts** (IP address and user agent sent to Google when the font downloads) and the **device speech-recognition service**: confirm how to treat them (Q14).
- **Colleague and applicant data shown by role** (privacy inventory A11) is the same data already listed above; no extra Data Safety type is expected, but confirm with the privacy owner.

## Before submitting

1. Resolve every **Requires confirmation** cell with the privacy owner and, where a vendor is involved, its contract.
2. Publish the reviewed privacy policy at a public HTTPS URL first; the Data Safety answers must match it.
3. Enter the answers in Play Console (not done; this worksheet changes nothing in the Console).
