# Privacy Inventory and Privacy Policy Draft — Royal HRMS Android update (1.0.0)

**For:** the company's privacy owner and the Play Console owner.
**Status:** DRAFT. **Not published, and no public URL exists yet.** Google Play requires a public HTTPS privacy-policy URL before the update can be submitted. A privacy or legal professional must review the text before it goes live.
**Evidence base:** the mobile code in `mobile_app/lib` and the production backend (`web_frontend_backend`, `origin/production` 95fc10a), read-only. Written 2026-11-04; re-checked against the current mobile code (through Phase 11.8) on 2026-11-05.

**How to read this document**
1. **Part A — verified from application code.** Each row names its evidence. Nothing in Part A depends on a company or vendor statement.
2. **Part B — questions.** Each is tagged **[Third party]** (how an outside service behaves — must be confirmed with that vendor or contract) or **[Business/legal]** (a decision or fact only the company can supply). Nothing in Part B is asserted anywhere else in this document.
3. **Part C — draft policy text.** Square-bracketed **[placeholders]** must be filled by the company. They are not to be guessed.

---

## Part A — Data inventory (from the code)

### A1. Account and personal information
| Data | Where | Evidence |
|---|---|---|
| Company code, email, password (sign-in) | Sent to the server at login. The password is not stored on the device. | `features/auth` |
| Name, email, phone, employee ID, department, designation, branch, role, joining date | Server profile, shown in the app; phone and addresses editable | `GET/PATCH /employees/me/` |
| Onboarding profile: date of birth, gender, marital status, blood group, father's name, current and permanent address, education, previous employment, emergency contact (name, relationship, phone, email), plus any company-defined custom fields | Entered by the employee; stored on the server | `features/onboarding` → `PATCH /onboarding/step/<n>/` |
| Government IDs: PAN number; identity documents (e.g. PAN card, Aadhaar card) uploaded as files | Server; files stored with Cloudinary | `PATCH /onboarding/step/4/ {pan_number}`, `POST /onboarding/documents/`; after onboarding, the employee's own uploads and replacements from My Profile → Documents (`POST /employees/<own code>/documents/`) |
| Bank details: account holder, account number, IFSC, bank and branch, account type | Server | onboarding step 2 |
| Profile photo (optional) | Server / Cloudinary | `/employees/me/photo/` |

### A2. Location
| Data | When | Evidence |
|---|---|---|
| Precise GPS latitude, longitude and accuracy | At each attendance clock-in/out, to check the branch geofence; stored with the punch | `attendance_remote_datasource.dart` punch; backend `latitude` field on the punch record |
| Location for a WFH request and saved WFH locations | When the employee requests WFH or saves a location | `wfh_remote_datasource.dart` |

Only foreground location is used (`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`, no background location permission).

### A3. Camera, face images and face biometric data
| Data | Handling | Evidence |
|---|---|---|
| Camera frames and one still photo | Processed **on the device** only: Google ML Kit face detection for liveness and quality checks, and a TensorFlow Lite MobileFaceNet model that computes a face embedding. **The photo is not uploaded.** | `face_capture_controller.dart`, `face_embedding_model_io.dart` |
| Still photo file on the device | Written by the camera plugin to a temporary file; **the app does not delete it**, so it stays in the app's private cache until the system clears it | No delete call in `features/facial_recognition` (re-checked 2026-11-05) |
| Face embedding (192 numbers, a biometric template) + liveness result | Sent at Face ID registration and with each face-verified punch | `POST` face registration (`face_embedding`, `liveness_passed`, `liveness_score`, `consent_acknowledged`); punch `face_embedding` |
| Server storage | The registration embedding is **encrypted at rest** (`EncryptedJSONField`). HR reviews and approves registrations. | `apps/attendance/models.py` `FaceRegistrationRequest.face_embedding` |
| Deletion | When HR **deactivates or deletes** an employee, the server purges their face data and anonymises verification attempts | `services_face_lifecycle.purge_face_data_for_employee`, called from `EmployeeDetailView` |
| Consent | The employee confirms a consent notice before registration (`consent_acknowledged`) | face registration flow |

### A4. Microphone and voice commands (optional feature)
| Data | Handling | Evidence |
|---|---|---|
| Speech | Converted to text by the device's speech recognition service (Android, typically Google). The text is sent to the backend. | `speech_to_text`; `POST /voice/parse/ {transcript}` |
| Audio recording | For the Hindi fallback, a short audio clip is recorded and uploaded to the backend, which sends it to **Sarvam AI** speech-to-text | `record` package; `POST /voice/transcribe-fallback/` (multipart `audio`); backend `sarvam_client.py` |
| Spoken replies | Reply text is sent to the backend, which uses **Sarvam AI** text-to-speech | `POST /voice/speak/` |
| Unrecognised commands | The backend may send the transcript to **Sarvam AI** chat completions to classify it | `llm_fallback.py` |
| Logs | Refused or unmatched commands are written to the server audit log; the backend also has a voice log file | `apps/voice_commands/audit.py` |

### A5. Financial information
Salary and payslip figures (earnings, deductions, net pay), bank details (A1), expense claims with amounts and receipts, payslip queries (free text) and the HR response. Payslips are read-only in the app.

### A6. Health information
Medical proof documents for medical WFH requests, and blood group (onboarding). Leave records may also indicate sick leave.

### A7. Documents and files
Uploaded by employees or HR and stored with **Cloudinary** (backend storage for every uploaded file):
- onboarding documents and custom file fields;
- WFH medical proof;
- separation documents;
- expense receipts;
- Document Center files;
- profile photo.

Policy acknowledgements record who acknowledged which document version, and when.

**Viewing your own profile documents (My Profile → Documents, added in Phase 11.4):**
- The app downloads the file with the user's own sign-in (`GET /onboarding/documents/<id>/`; session cookie and `Authorization: Bearer` header, never a token in the URL) and checks it is a real PDF, JPG or PNG.
- **The document is shown inside the app only.** No other app is given the file: no "open with", no content URI, no FileProvider and no access grants.
  - **JPG/PNG** are shown from memory with zoom. Nothing is written to storage.
  - **PDF** is written to a **temporary copy** in the app's private cache, `profile_docs/doc-<id>.pdf` (no names or tokens in the file name), and shown with the `pdfx` package, which opens the file read-only by path (`PdfDocument.openFile`). `openData` is not used, because on Android it leaves its own undeleted copy in the cache.
- **Temporary copies are deleted:** when the viewer closes; before each new view; at app start; when the signed-in user signs out, their session expires, or a different user signs in; and at once if a PDF can't be written. `pdfx`'s page-image folder (`pdf_renderer_cache`: in the cache on Android, in Documents on iOS) is cleared at the same points. The in-app viewer renders pages to textures, so it normally writes nothing there. The cache is excluded from Android backups.
- **Remaining limits:** the employee can still take a screenshot (not blocked). On Android, `pdfx` writes the temporary file's path (which contains the document ID only) to the system debug log when it opens a PDF.
- No new Android permissions, providers or native configuration. `pdfx` uses the system PDF renderer (Android `PdfRenderer`, iOS Core Graphics).

### A8. Work records
Attendance and punches, attendance corrections, leave, WFH and daily reports, expenses, separation requests and approvals, assessments and results, announcements reactions and views, approvals made by managers or HR.

### A9. Device and technical data
| Data | Evidence |
|---|---|
| App-generated random device ID (128-bit, kept in secure storage), device type (Android), OS name, device time | Sent with each punch (`device_identifier.dart`, punch payload) |
| IP address | Recorded by the backend for audit events (e.g. acknowledgements, voice audit) |
| On the device | Secure storage (`flutter_secure_storage`): access and refresh tokens, cached user profile, logged-in flag, device ID, theme. App files: session cookies; temporary PDF copies of profile documents while the user views them (see A7). |
| Where session cookies are kept | `PersistCookieJar` in the app's **documents** folder (`<app documents>/.cookies/`), not the cache | `main.dart` (`getApplicationDocumentsDirectory`, `FileStorage`) |
| Android backup | The manifest does not set `android:allowBackup`, so Android's default applies (app backup allowed). Whether the cookie folder is included in a device backup, and whether that is acceptable, is Question 12. | `AndroidManifest.xml` (no `allowBackup` attribute) |

### A10. Transmission and third parties
- **Transport:** all API traffic goes over HTTPS to `https://royalhrms.com/api/`. Release builds cannot use cleartext HTTP.
- **Cloudinary:** file storage (backend).
- **Sarvam AI:** voice speech-to-text, text-to-speech and command classification (backend, voice feature only).
- **Google:**
  - ML Kit face detection runs on the device;
  - Android speech recognition (device service);
  - Google Fonts: the app downloads its font from Google's font servers at run time (shares IP address and user agent). Re-checked 2026-11-05: no fonts are bundled and runtime fetching is not disabled in the app code. See Question 14.
- **Email:** the backend sends notification emails (e.g. onboarding, approvals). **The email provider is to be confirmed.**
- **Other apps on the device:** none. Profile documents are viewed inside the app; no other app is given the file (A7).
- **Analytics, advertising, crash reporting:** none found (no such SDKs in `pubspec.yaml`).
- **Sale of data:** no code sends data to advertisers or data brokers.

### A11. Information about other people, shown by role
These screens show data about colleagues or applicants, limited by the server to the signed-in user's role and permissions:

| Data | Who sees it | Evidence |
|---|---|---|
| Contact Matrix: names and contact details of the company's designated contacts by escalation level | Employees (managing it needs `can_manage`) | `features/contacts` → `/company-contacts/` |
| Manager dashboard: team members' attendance today, pending approvals, upcoming leave, birthdays | Managers, for their own team | `manager_dashboard_view.dart` → `/dashboard/manager/` |
| Approvals: team members' leave, WFH, expense, separation and payslip-query requests | Managers/HR with the matching approve permission | `features/approvals`, `features/separation` |
| Candidate Review (onboarding approval): applicant profile and documents; HR may enter the applicant's UAN, name as per Aadhaar and PAN. Identifiers are shown **masked** (last 4 characters) in the read-only view | HR with the onboarding-approval permission | `candidate_review_screen.dart`, `approval_identity_fields.dart` → `POST /onboarding/approvals/<id>/` |
| Policy acknowledgement report: who has acknowledged which document | HR (`documents.edit`) | `acknowledgement_panel.dart` → `/documents/<id>/acknowledgements/` |
| Employee's own notice period (approval date, last working day, days remaining) | That employee only (the server scopes it to the signed-in user) | `emp_notice_period_card.dart` → `/dashboard/employee/notice-period/` |

---

## Part B — Questions for the company / privacy administrator

1. **[Business/legal] Legal entity and contact:** the company name, address, privacy or grievance officer, and contact email for the policy.
2. **[Business/legal] Data controller:** is the controller the employing company (each tenant), with the Royal HRMS operator as processor? Who answers employee requests?
3. **[Business/legal] Retention:** how long attendance, location history, payroll records, documents, voice logs and audit logs are kept, during and after employment.
4. **[Business/legal] Face data:** confirm the encrypted embedding is the only biometric stored, that verification embeddings sent with punches are not kept beyond the match, and the purge-on-exit behaviour.
5. **[Business/legal] On-device photo:** do you want the app to delete the temporary face photo after capture? (Recommended. This would be a mobile change in a later phase.)
6. **[Third party] Sarvam AI:** where is data processed, what does Sarvam retain, and is there a data processing agreement? Is the voice feature enabled for all companies?
7. **[Third party] Cloudinary:** region and retention, and the data processing agreement.
8. **[Third party] Email provider:** which service sends notification emails?
9. **[Business/legal] Deletion and correction requests:** how employees request access, correction or deletion (e.g. through HR), and the response time. Accounts are created by employers, so there is no in-app sign-up or self-service deletion.
10. **[Business/legal] Legal basis:** consent for biometric data and the Digital Personal Data Protection Act 2023 (India) position, and any other countries where employees use the app.
11. **[Business/legal] Children:** confirm the app is only for employees aged 18 and over.
12. **[Business/legal] Backups:** Android app backup is allowed by default (no `allowBackup` attribute), and session cookies are kept in the app's documents folder (A9). Confirm this is acceptable, or ask for backup to be disabled or limited in a later phase.
13. **[Business/legal] Screenshots of documents:** identity documents (PAN, Aadhaar, bank proof) are now viewed inside the app only, and temporary copies are deleted on close and at sign-out. Should screenshots of the document viewer also be blocked? (Mobile change in a later phase.)
14. **[Third party] Google Fonts and Android speech recognition:** the app fetches its font from Google at run time, and voice commands use the device's speech-recognition service (on most Android phones a Google service, which may process audio off the device). Confirm how these are to be described in the policy and the Data Safety form, or ask for the font to be bundled in a later phase.
15. **[Business/legal] Hosting and other recipients:** the backend (`royalhrms.com`) hosting provider and any other party that receives employee data (backups, support, monitoring) are not visible in the code. Confirm the full list.

---

## Part C — Privacy Policy (DRAFT — not for publication)

*Not published. A public HTTPS URL for the final, reviewed text is required before submitting the Play update. Every **[placeholder]** must be supplied by the company; nothing here may be published with a placeholder or an unanswered Part B question.*

> **Royal HRMS Mobile App — Privacy Policy**
> *Last updated: [Date]*
>
> This policy explains how the Royal HRMS mobile app ("the App") handles information. The App is provided by **[Company legal name]** ("we", "us") for employees of organisations that use Royal HRMS ("your employer"). Your employer creates your account and decides which features are switched on. For most information described here, your employer is responsible for deciding why and how it is used; we process it on their behalf. **[Confirm controller/processor roles — Question 2.]**
>
> **1. Information we collect**
> - **Account and profile:** name, email, phone, employee ID, department, designation, branch and role; details you enter during onboarding, such as date of birth, gender, marital status, blood group, address, education and work history, emergency contacts, and bank account details.
> - **Identity documents and files:** documents you or HR upload, such as PAN or identity cards, certificates, medical proof, receipts and policy documents, and your profile photo.
> - **Location:** your precise location when you clock in or out, to confirm you are at your workplace, and when you request or save a work-from-home location. The App uses location only while you are using it.
> - **Face verification:** if your employer requires Face ID, the App uses your camera to check that a live person is present and turns your face into a numeric template on your device. **Your face photo is not uploaded.** Only the template and the liveness result are sent. Templates are stored encrypted and deleted when your employment record is deactivated or deleted. You are asked for consent before registration.
> - **Voice commands (optional):** if you use voice commands, your speech is converted to text. Some audio clips (e.g. the Hindi fallback) and command text are sent to our service provider Sarvam AI to understand the command and produce a spoken reply.
> - **Work and pay records:** attendance, leave, work-from-home, expenses, separation and notice period, assessments, approvals, payslips and payslip queries.
> - **Device and technical information:** an app-generated device identifier, device type, operating system, time, and IP address, for security and attendance records.
>
> **2. How we use information**
> To run HR processes for your employer: attendance and geofencing, leave and approvals, onboarding, payroll information, documents and policy acknowledgements, separation, and communication. We also use it to keep the service secure and prevent fraud (e.g. liveness and face verification). We do **not** use your information for advertising and do **not** sell it.
>
> **3. Sharing**
> - With your employer's authorised staff (e.g. HR, your manager), according to their role.
> - With service providers who process data for us: Cloudinary (file storage), Sarvam AI (voice features), **[email provider]** (notification emails) and Google (on-device face detection, device speech recognition, fonts).
> - When required by law.
> - **Viewing your documents:** when you open one of your documents, it is shown inside the App and is not given to any other app. Any temporary copy is deleted when you close it or sign out.
>
> **4. Security**
> Data is sent over encrypted connections (HTTPS). Sign-in tokens are kept in the device's secure storage. Face templates are encrypted at rest. Access is limited by role.
>
> **5. Retention**
> **[Retention periods — Question 3.]** Face templates are deleted when your employment record is deactivated or deleted.
>
> **6. Your choices and rights**
> - You can decline location, camera or microphone permissions; some features, such as clock-in, may then be unavailable.
> - To access, correct or delete your information, contact your employer's HR or **[contact email]**. **[Process and timelines — Question 9.]**
>
> **7. Children**
> The App is for employees aged 18 and over.
>
> **8. Changes**
> We will update this policy and the "Last updated" date when our practices change.
>
> **9. Contact**
> **[Company legal name, address, privacy/grievance officer, email]**
