# Privacy Inventory and Privacy Policy Draft — Royal HRMS Android 1.0.0 (6)

**For:** the company's privacy owner and the Play Console owner.
**Status:** DRAFT. Not published. A privacy or legal professional must review it before it goes live.
**Evidence base:** the mobile code in `mobile_app/lib` and the production backend (`web_frontend_backend`, `origin/production` 95fc10a), read-only, on 2026-11-04. Anything not shown in code is listed under *Questions* and is not asserted.

---

## Part A — Data inventory (from the code)

### A1. Account and personal information
| Data | Where | Evidence |
|---|---|---|
| Company code, email, password (sign-in) | Sent to the server at login. The password is not stored on the device. | `features/auth` |
| Name, email, phone, employee ID, department, designation, branch, role, joining date | Server profile, shown in the app; phone and addresses editable | `GET/PATCH /employees/me/` |
| Onboarding profile: date of birth, gender, marital status, blood group, father's name, current and permanent address, education, previous employment, emergency contact (name, relationship, phone, email), plus any company-defined custom fields | Entered by the employee; stored on the server | `features/onboarding` → `PATCH /onboarding/step/<n>/` |
| Government IDs: PAN number; identity documents (e.g. PAN card, Aadhaar card) uploaded as files | Server; files stored with Cloudinary | `PATCH /onboarding/step/4/ {pan_number}`, `POST /onboarding/documents/` |
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
| Still photo file on the device | Written by the camera plugin to a temporary file; **the app does not delete it**, so it stays in the app's private cache until the system clears it | No delete call in `features/facial_recognition` |
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

### A8. Work records
Attendance and punches, attendance corrections, leave, WFH and daily reports, expenses, separation requests and approvals, assessments and results, announcements reactions and views, approvals made by managers or HR.

### A9. Device and technical data
| Data | Evidence |
|---|---|
| App-generated random device ID (128-bit, kept in secure storage), device type (Android), OS name, device time | Sent with each punch (`device_identifier.dart`, punch payload) |
| IP address | Recorded by the backend for audit events (e.g. acknowledgements, voice audit) |
| On the device | Secure storage: access and refresh tokens, cached user profile, logged-in flag, device ID, theme. App files: session cookies. |

### A10. Transmission and third parties
- **Transport:** all API traffic goes over HTTPS to `https://royalhrms.com/api/`. Release builds cannot use cleartext HTTP.
- **Cloudinary:** file storage (backend).
- **Sarvam AI:** voice speech-to-text, text-to-speech and command classification (backend, voice feature only).
- **Google:**
  - ML Kit face detection runs on the device;
  - Android speech recognition (device service);
  - Google Fonts: the app downloads its font from Google's font servers at run time (shares IP address and user agent).
- **Email:** the backend sends notification emails (e.g. onboarding, approvals). **The email provider is to be confirmed.**
- **Analytics, advertising, crash reporting:** none found (no such SDKs in `pubspec.yaml`).
- **Sale of data:** no code sends data to advertisers or data brokers.

---

## Part B — Questions for the company / privacy administrator

1. **Legal entity and contact:** the company name, address, privacy or grievance officer, and contact email for the policy.
2. **Data controller:** is the controller the employing company (each tenant), with the Royal HRMS operator as processor? Who answers employee requests?
3. **Retention:** how long attendance, location history, payroll records, documents, voice logs and audit logs are kept, during and after employment.
4. **Face data:** confirm the encrypted embedding is the only biometric stored, that verification embeddings sent with punches are not kept beyond the match, and the purge-on-exit behaviour.
5. **On-device photo:** do you want the app to delete the temporary face photo after capture? (Recommended. This would be a mobile change in a later phase.)
6. **Sarvam AI:** where is data processed, what does Sarvam retain, and is there a data processing agreement? Is the voice feature enabled for all companies?
7. **Cloudinary:** region and retention, and the data processing agreement.
8. **Email provider:** which service sends notification emails?
9. **Deletion and correction requests:** how employees request access, correction or deletion (e.g. through HR), and the response time. Accounts are created by employers, so there is no in-app sign-up or self-service deletion.
10. **Legal basis:** consent for biometric data and the Digital Personal Data Protection Act 2023 (India) position, and any other countries where employees use the app.
11. **Children:** confirm the app is only for employees aged 18 and over.
12. **Backups:** Android cloud backup is currently allowed (`allowBackup`). Confirm this is acceptable, or ask for it to be disabled in a later phase.

---

## Part C — Privacy Policy (DRAFT — not for publication)

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
> - **Work and pay records:** attendance, leave, work-from-home, expenses, separation, assessments, approvals, payslips and payslip queries.
> - **Device and technical information:** an app-generated device identifier, device type, operating system, time, and IP address, for security and attendance records.
>
> **2. How we use information**
> To run HR processes for your employer: attendance and geofencing, leave and approvals, onboarding, payroll information, documents and policy acknowledgements, separation, and communication. We also use it to keep the service secure and prevent fraud (e.g. liveness and face verification). We do **not** use your information for advertising and do **not** sell it.
>
> **3. Sharing**
> - With your employer's authorised staff (e.g. HR, your manager), according to their role.
> - With service providers who process data for us: Cloudinary (file storage), Sarvam AI (voice features), **[email provider]** (notification emails) and Google (on-device face detection, device speech recognition, fonts).
> - When required by law.
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
