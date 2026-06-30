# Royal HRMS — Team Context

> Single source of truth for the full project. Replaces `backend/TEAMCONTEXT.md` and `frontend/TEAMCONTEXT.md`.
> **Last updated:** 2026-06-30 — G. Durga Prasad

---

## Tech Stack

### Backend

| Layer | Technology |
|---|---|
| Language | Python 3.13 |
| Framework | Django 4.2 + Django REST Framework 3.15 |
| Auth | JWT via `djangorestframework-simplejwt` 5.3 |
| Database | PostgreSQL (Neon cloud) |
| ORM | Django ORM |
| File Storage | **Cloudinary** (`django-cloudinary-storage` 0.3.0) — all `FileField` uploads |
| Email | Gmail SMTP (App Password) via DB-configured SMTPConfig |
| Environment | `django-environ` (.env file) |

### Frontend

| Layer | Technology |
|---|---|
| Framework | Next.js 16.2.9 (App Router + Turbopack) |
| Styling | Tailwind CSS v2.2.19 (JIT) + custom CSS design system (Sahara theme) |
| Icons | Tabler Icons webfont via CDN (`ti-*` classes) |
| HTTP | Axios via `lib/clientApi.ts` |
| Auth state | JWT in cookie + user info in `royal_hrms_user` cookie |
| Backend URL | `http://localhost:8000/api` |

---

## Project Structure

```
Royal-HRMS/
├── backend/
│   ├── config/
│   │   ├── settings.py         Django settings
│   │   ├── urls.py             Root URL config
│   │   └── exceptions.py       Global JSON error handler
│   ├── core/
│   │   ├── responses.py        success() / error() helpers — use everywhere
│   │   ├── permissions.py      shared DRF permission classes
│   │   └── pagination.py       paginate() / paginated_data() helpers
│   ├── apps/
│   │   ├── accounts/           Auth, users, roles, permissions, onboarding, documents, audit
│   │   ├── branch/             Branch CRUD + State/City cascading dropdowns
│   │   ├── recruitment/        Candidates, interviews, portal login, email logs
│   │   ├── hrms/               Employees, attendance, leave, payroll, expenses
│   │   └── announcements/      Announcements
│   └── requirements.txt
├── frontend/
│   ├── app/                    Next.js App Router pages (no business logic here)
│   ├── components/             Reusable UI components
│   ├── hooks/
│   │   └── useFetch.ts         Generic fetch hook — always use this, never useState+useEffect
│   ├── lib/
│   │   ├── api/
│   │   │   ├── client.ts       Axios instance (withCredentials: true)
│   │   │   └── endpoints.ts    ALL API path constants — no inline strings anywhere
│   │   ├── auth.ts             Auth state + UserInfo type
│   │   ├── clientApi.ts        Client-side axios (attaches Bearer from localStorage)
│   │   ├── navConfig.ts        Single master nav list, permission-gated
│   │   └── emailPreview.ts     buildEmailPreview() — mirrors backend email wrapper
│   ├── types/                  All TypeScript interfaces
│   └── proxy.ts                Next.js edge proxy — route protection
└── teamcontext.md              This file
```

---

## Database Tables

| Table | Purpose |
|---|---|
| `hrms_roles` | 4 roles (hr_admin, system_admin, manager, employee) |
| `hrms_permissions` | 50+ module-level permissions |
| `hrms_role_permissions` | M2M: role → permissions |
| `hrms_users` | All users (custom User model, UUID PK) |
| `hrms_password_reset_tokens` | Single-use forgot-password tokens |
| `hrms_audit_logs` | Immutable log of all admin events |
| `otp_verifications` | 6-digit OTPs for forgot-password step 2 |
| `hrms_company` | Singleton — company info, logo, portal_url |
| `hrms_smtp_settings` | Admin-configured SMTP; `send_template_email` uses this |
| `hrms_email_templates` | Transactional email templates with attachments |
| `hrms_documents` | Document Center — files on Cloudinary, soft-delete |
| `hrms_employee_profiles` | OneToOne to User — personal/edu/bank/emergency fields |
| `hrms_employee_documents` | Per-user uploaded docs (PAN, Aadhaar, degree, etc.) |
| `hrms_departments` | Department master |
| `hrms_designations` | Designation master |
| `branch_states` | 36 Indian states/UTs |
| `branch_cities` | ~200 cities per state |
| `branch_branches` | Company branches with auto-generated codes |
| `hrms_candidates` | Recruitment candidates — 8-stage pipeline |
| `hrms_candidate_logs` | Per-candidate event timeline |
| `hrms_candidate_emails` | Email send records (sent/failed) |

---

## Local Setup

### Backend

```powershell
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

API available at `http://localhost:8000/api/`

### Frontend

```powershell
npm install
npm run dev
```

App available at `http://localhost:3000`

---

## Environment Variables (`.env`)

```env
SECRET_KEY=<django-secret-key>
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1,<your-local-ip>

DATABASE_URL=postgresql://<user>:<pass>@<host>/<db>?sslmode=require
DB_CONN_MAX_AGE=60

EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=<gmail>
EMAIL_HOST_PASSWORD=<app-password-16-chars-no-spaces>
DEFAULT_FROM_EMAIL=Royal Staffing HRMS <email>

CLOUDINARY_CLOUD_NAME=<cloud-name>
CLOUDINARY_API_KEY=<api-key>
CLOUDINARY_API_SECRET=<api-secret>

CORS_ALLOWED_ORIGINS=http://localhost:3000
```

> Gmail App Passwords are exactly **16 characters** with **no spaces**. Spaces cause SMTP 535 authentication errors.

---

## Demo Credentials

All passwords: **`Hrms@1234`**

| Email | Role | Notes |
|---|---|---|
| hradmin@royal.com | hr_admin | All permissions |
| sysadmin@royal.com | system_admin | Super admin |
| manager@royal.com | manager | 25 permissions |
| employee@royal.com | employee | 10 permissions, must change password |

---

## Authentication Flow

**Login:** `POST /api/login/` → returns access token (30 min) + refresh token (7 days). Also returns `onboarding_status` — frontend redirects to `/onboarding` if not `complete`.

**Forgot Password:**
1. `POST /api/forgot-password/` — sends 6-digit OTP (valid 10 min)
2. `POST /api/verify-otp/` — verify OTP → `reset_token`
3. `POST /api/reset-password/` — set new password (token valid 60 min)

**Account lockout:** 5 wrong passwords → locked 30 minutes.

**Onboarding gate:** Users with `onboarding_status != 'complete'` are redirected to `/onboarding` by `proxy.ts`. System admin accounts are auto-completed at migration time.

---

## Role System & Permissions

### 4 Default Roles

| Role | Permissions |
|---|---|
| `hr_admin` | All 50+ (full access) |
| `system_admin` | 24 (super admin) |
| `manager` | 25 |
| `employee` | 10 |

### Permission Codenames

```
employees:     view, create, edit, delete, export, approve
recruitment:   view, create, edit, delete, approve
attendance:    view, create, edit, delete, export
leave:         view, create, edit, delete, approve
payroll:       view, create, edit, delete, export
expenses:      view, create, edit, delete, approve
referrals:     view, create
announcements: view, create, edit, delete
documents:     view, create, edit, delete
settings:      view, edit
reports:       view, export
audit:         view
branches:      view, create, edit, delete
onboarding:    approve
```

**System roles (`employee`, `hr_admin`, `system_admin`) cannot be deleted** — enforced in `RoleDetailView.delete()`.

---

## API Endpoints

**Base URL:** `http://localhost:8000/api`

### Auth (Public)

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/login/` | Login |
| POST | `/api/logout/` | Logout |
| POST | `/api/forgot-password/` | Send OTP |
| POST | `/api/verify-otp/` | Verify OTP |
| POST | `/api/reset-password/` | Reset password |
| POST | `/api/change-password/` | Change password (JWT required) |

### Roles & Permissions

| Method | Endpoint | Permission |
|---|---|---|
| GET/POST | `/api/roles/` | `settings.view` / `settings.edit` |
| GET/PUT/PATCH/DELETE | `/api/roles/{id}/` | `settings.edit` |
| GET/POST | `/api/permissions/` | `settings.view` / `settings.edit` |
| GET/PUT/DELETE | `/api/permissions/{id}/` | `settings.edit` |

### Departments & Designations

| Method | Endpoint | Description |
|---|---|---|
| GET/POST | `/api/departments/` | List (paginated) / Create |
| GET/PUT/PATCH/DELETE | `/api/departments/{id}/` | CRUD |
| GET/POST | `/api/designations/` | List (paginated, filter: `?department_name=`) / Create |
| GET/PUT/PATCH/DELETE | `/api/designations/{id}/` | CRUD |

### Branch

| Method | Endpoint | Permission |
|---|---|---|
| GET | `/api/branch/states/` | IsAuthenticated |
| GET | `/api/branch/states/{id}/cities/` | IsAuthenticated |
| GET/POST | `/api/branch/branches/` | `branches.view` / `branches.create` |
| GET/PUT/PATCH/DELETE | `/api/branch/branches/{id}/` | `branches.view` / `branches.edit` / `branches.delete` |
| GET | `/api/branch/branches/stats/` | `branches.view` |
| GET | `/api/branch/branches/distribution/` | `branches.view` |

### Document Center

| Method | Endpoint | Description |
|---|---|---|
| GET/POST | `/api/documents/` | List (filters: `category`, `branch`, `file_type`, `search`) / Upload |
| GET | `/api/documents/stats/` | Total + per-category counts |
| GET/PATCH/DELETE | `/api/documents/{id}/` | Detail / Update / Soft-delete |
| GET | `/api/documents/{id}/?t=<token>` | Streaming file download (no JWT needed; 2-hour signed token) |

### Recruitment

| Method | Endpoint | Permission |
|---|---|---|
| GET/POST | `/api/recruitment/candidates/` | `recruitment.view/create` |
| GET | `/api/recruitment/candidates/{id}/` | `recruitment.view` |
| PATCH | `/api/recruitment/candidates/{id}/status/` | `recruitment.edit` |
| PATCH | `/api/recruitment/candidates/{id}/hr-decision/` | `recruitment.approve` |
| GET | `/api/recruitment/candidates/review/` | `recruitment.view` |
| POST | `/api/recruitment/candidates/{id}/send-portal-login/` | `recruitment.edit` |
| POST | `/api/recruitment/candidates/{id}/resend-portal-login/` | `recruitment.edit` |
| GET | `/api/recruitment/emails/` | `recruitment.view` |
| GET | `/api/recruitment/stats/` | `recruitment.view` |

### Employees

| Method | Endpoint | Description |
|---|---|---|
| GET/POST | `/api/employees/` | List (paginated) / Create |
| GET/PUT/PATCH | `/api/employees/{employee_id}/` | Detail / Update (response includes `documents`) |

### Onboarding

| Method | Endpoint | Permission |
|---|---|---|
| GET/PATCH | `/api/onboarding/profile/` | IsAuthenticated (own profile) |
| GET/POST | `/api/onboarding/documents/` | IsAuthenticated (own docs) |
| POST | `/api/onboarding/submit/` | IsAuthenticated |
| GET | `/api/onboarding/approvals/` | `onboarding.approve` |
| GET | `/api/onboarding/pipeline/` | `onboarding.approve` |
| POST | `/api/onboarding/approvals/{user_id}/approve/` | `onboarding.approve` |

### Settings

| Method | Endpoint | Description |
|---|---|---|
| GET/PUT | `/api/settings/company/` | Company info (singleton) |
| GET/POST | `/api/settings/smtp/` | SMTP configurations (paginated) |
| POST | `/api/settings/smtp/{id}/activate/` | Set active SMTP |
| POST | `/api/settings/smtp/test/` | Send test email |
| GET/POST | `/api/settings/email-templates/` | Email templates (grouped by type in `results`) |
| PUT | `/api/settings/email-templates/{id}/` | Update template |
| GET | `/api/settings/email-templates/{id}/preview/` | Rendered HTML preview |
| GET | `/api/settings/audit/` | Audit log (paginated, filters: module/action/search/date) |

---

## Response Envelope

Every response uses this shape:

```json
{
  "status": "success | error",
  "message": "Human-readable string",
  "data": {}
}
```

All list endpoints return paginated data:

```json
{
  "count": 45,
  "page": 1,
  "page_size": 20,
  "total_pages": 3,
  "results": [...]
}
```

**Always access `.results` for the array.** Exception: email templates — `results` is a grouped object `{ document: [...], notification: [...] }` — use `flattenTemplates()` after accessing `.results`.

---

## Security Rules (Non-Negotiable)

- **Never store JWT tokens in localStorage** — httpOnly cookies only
- **Never use `CORS_ALLOW_ALL_ORIGINS = True`** — always a specific list
- **Always use `secure=not settings.DEBUG` on `set_cookie`** — not `secure=True` unconditionally
- **Frontend API base URL must use `localhost`, not `127.0.0.1`** — different sites, cookies won't cross
- **Never use `fail_silently=True`** in email sending
- **Never use `django.core.mail.send_mail`** — use `send_template_email` from `apps.accounts.utils`
- **Never define `success()`/`error()` locally** — always use shared helpers from `core.responses`
- **Gmail App Passwords are 16 chars, no spaces** — entering with spaces causes SMTP 535 errors
- **Gmail daily limit is 500 emails** — switch to SendGrid/Mailgun/SES for production

---

## Frontend Rules

- **All data fetching uses `useFetch` hook** — never `useState + useEffect + try/catch` in a page
- **All API paths come from `lib/api/endpoints.ts`** — no inline path strings
- **Any `getStoredUser()` call at render time causes hydration mismatch** — always wrap in `useEffect`
- **Departments/Designations APIs are paginated** — always pass `page_size=100` and access `.results`
- **Axios 1.x FormData bug** — `clientApi.ts` interceptor deletes `Content-Type` when body is `FormData`; do not remove this
- **Template variable names are UPPERCASE** — `{FULL_NAME}`, `{FNAME}`, `{EMAIL}`, `{POSITION}`, `{COMPANY}`
- **Email template `results` is a grouped object** — use `flattenTemplates()` after accessing `.results`
- **Tailwind v2 does NOT support opacity modifiers** — `text-white/75` is v3 only; use inline `style={{ color: "rgba(...)" }}`
- **`proxy.ts` (not `middleware.ts`)** is this project's Next.js edge proxy — named export `proxy`

---

## Session Log

---

### 2026-06-24 — Safura Samreen (Frontend Session 1 & 2)

Built the core frontend shell:

1. **Dashboard Shell** (`components/dashboard/DashboardShell.tsx`) — sidebar with collapsible width, permission-based navigation via `buildNav(permissions[])` from `lib/navConfig.ts`, top navbar, user card.
2. **Settings Page** — category pills + card tiles, routing to sub-pages.
3. **Roles & Permissions Page** (`app/dashboard/settings/permissions/`) — full CRUD wired to API. Add/Edit modals with permission tree, quick presets (Full Admin / View Only / Manager / Employee), active/inactive toggle. Permission matrix view.
4. **Role-Based Dashboard** — server component renders different widgets per role (hr_admin, system_admin, manager, employee). All static/mock data.
5. **SMTP Settings** (`app/dashboard/settings/smtp/`) — card list, Add/Edit modal, Set Active, Delete, Test Email.
6. **Email Templates** (`app/dashboard/settings/email-templates/`) — grouped by type, WYSIWYG editor, HTML source toggle, variable tag sidebar, attachments bar.
7. **CSS Module Migration** — all CSS modules deleted; styles migrated to Tailwind + inline `style={}`.

**Key notes:**
- Sidebar nav is driven entirely by `user.permissions[]` from login — no extra API calls after login.
- `proxy.ts` enforces permission-based route protection on direct URL access.
- Tailwind v2 does NOT support opacity modifier syntax (`text-white/75`) — use inline styles.

---

### 2026-06-24 — Rithwika (Announcements Page)

`app/dashboard/announcements/page.tsx` — fully static. Stats cards, filter tabs, post cards with pinned gold border, add/edit modal. **Sidebar dual-active bug fix:** `/dashboard/announcements` was also activating the Dashboard nav item; fixed with exact-match + prefix check on `item.path !== "/dashboard"`.

---

### 2026-06-24 — Surya (Company Info + Audit Log)

**Company Information Module:**
- Backend: `Company` model (`hrms_company`), `CompanySerializer` with logo URL, `CompanyRetrieveUpdateView` (PUT), migration `0013`.
- Frontend: 4-section settings page (`/dashboard/settings/company`) — Branding (logo upload), Legal (GSTIN/CIN/PAN/TAN), Address, Contact.
- Logo FormData: use `headers: { 'Content-Type': undefined }` in axios — never set multipart boundary manually.
- Logo removal: send `remove_logo=true` as a FormData string field.
- **Company is a singleton** — use `Company.objects.first()`, never `get(id=...)`.

**Audit Log Module:**
- `AuditLogListView` — paginated, filters by module/action/search/date.
- Frontend: `/dashboard/settings/audit` — filter form, table with color-coded action/module badges, pagination.
- All branch write views log to `AuditLog`; every new module with admin write ops should do the same.

**CORS fix:** `CORS_ALLOWED_ORIGINS = ["http://localhost:3000"]` — never `CORS_ALLOW_ALL_ORIGINS = True`.

---

### 2026-06-25 — Rithwika (JWT Login Fix + Mobile Responsiveness)

**JWT Login Fix** (`lib/clientApi.ts`): Request interceptor skips `Authorization` header for auth URLs (`/login/`, `/token/refresh/`, etc.) — prevents stale token rejection on the login endpoint itself.

**Mobile Responsiveness:** Login page (left panel hidden on mobile), Dashboard Shell (sidebar overlay drawer + hamburger), all Settings sub-pages. **Button order rule across all pages: Back button always first, Add/primary button second.**

**New CSS classes in `app/globals.css`:** `.smtp-form-grid`, `.email-editor-grid`, `.email-editor-left`, `.email-tags-sidebar`, `.dept-hero-row`, `.dept-hero-actions`.

---

### 2026-06-25 — Surya (Document Center + Cloudinary Integration)

**Document Center** (`apps/accounts/` backend + `app/dashboard/documents/` frontend):
- `Document` model (`hrms_documents`) — category (policy/form/template/other), Cloudinary file, soft-delete.
- All `FileField` uploads go to Cloudinary via `RawMediaCloudinaryStorage`.
- List/upload/detail/update/soft-delete + stats endpoint.
- **Document preview fix:** `GET /api/documents/{id}/?t=<token>` — backend signs a 2-hour token, streams file server-side via `cloudinary.utils.private_download_url()`, bypassing CDN restrictions.

**File validation:** PDF/DOC/DOCX/XLS/XLSX/PPT/PPTX/JPG/PNG/TXT/CSV; max 25 MB; path-traversal sanitization.

**Bug fixes:** `is_active` made `read_only` in serializer (multipart form was sending `is_active=false`, making uploads disappear); `branch_name` converted to `SerializerMethodField` (was returning string `"None"`).

---

### 2026-06-25 — Safura Samreen (Email Templates Fixes + Document Center Frontend)

**Email Templates fixes:**
- Axios 1.x FormData bug: delete `Content-Type` in interceptor when body is `FormData`.
- `available_variables` inconsistency: backend returns `string | string[]` — use `parseAvailableVars()` from `_data.ts`.
- Existing attachments not shown on edit: `EditTemplateModal` fetches detail endpoint on mount, tracks `removedAttachmentIds[]`.
- Inline category creation in combobox.

**Document Center Frontend** (`app/dashboard/documents/`): stats row, filter tabs + debounced search, document grid, detail modal, upload modal with drag-and-drop, in-app preview (PDF via blob URL → iframe, DOCX via `docx-preview`, XLSX via SheetJS).

**Key note:** Never send Django JWT token to `file_url` (Cloudinary endpoint) — use plain `fetch(url)` without `Authorization` header.

---

### 2026-06-25 — Nithin Sandala (Employee Management Module)

**Branch:** `Frontend/employee`

Built full employee management screens: list with search/filter, add employee wizard, employee profile detail page (Personal/Work/Documents tabs). Files under `app/dashboard/employees/` with `_data.ts` and `_components/`.

---

### 2026-06-26 — G. Durga Prasad (Recruitment Module Backend + Email Branding)

**Three models:** `Candidate` (`hrms_candidates`), `CandidateLog` (`hrms_candidate_logs`), `CandidateEmail` (`hrms_candidate_emails`).

**Views:** List/Create, Detail, Status (select/reject + branded email), HR Decision (approve/reject), Review list, Email log, Stats.

**Email branding:** `_company_email_wrapper` in `accounts/utils.py` wraps every sent email with company logo header + website/address footer. `send_template_email` raises `LookupError` when slug not found (prevents incorrect `STATUS_SENT` logging).

**Duplicate removed:** `CandidateEmailTemplatesView` deleted; `EmailTemplateListCreateView` GET opened to all `IsAuthenticated` users.

---

### 2026-06-26 — G. Durga Prasad (Recruitment Module Frontend)

1. **Interview List Page** (`app/dashboard/interview-list/`) — refactored 482-line file to 245-line orchestrator + 3 extracted modals (AddCandidateModal, MarkCandidateModal, LogsModal). Stats cards, branch filter dropdown, branch table column.
2. **`lib/emailPreview.ts`** — NEW shared `buildEmailPreview()` mirroring backend `_company_email_wrapper`. Used by MarkCandidateModal + HRDecisionModal. **Keep in sync with backend when branding changes.**
3. **`emailTemplates` endpoint moved** from `API.recruitment` to `API.settings` — single source of truth.

---

### 2026-06-26 — Rithwika (Login Redesign + Responsiveness)

**Login Page full redesign** — zero inline styles, all named CSS classes, mobile-safe layout (fixed button-below-fold clipping on iPhone SE: switched to `flex-start` with `padding-top` instead of `justify-content: center`).

**ForgotPasswordForm rewrite** — replaced Tailwind arbitrary-value const strings with guaranteed CSS classes (arbitrary values in JS consts get purged by Tailwind v2 without JIT).

**28 new CSS classes** added to `app/globals.css` (login layout + announcement layout).

---

### 2026-06-29 — Surya (Candidate-to-Employee Onboarding Wizard — Full Stack)

**Branch:** `demo`

End-to-end recruitment → onboarding → employee conversion flow.

**Backend models added:**
- `User.onboarding_status` — `pending / submitted / complete`
- `EmployeeProfile` (`hrms_employee_profiles`) — personal, education, bank, emergency contact
- `EmployeeDocument` (`hrms_employee_documents`) — PAN, Aadhaar, degree, experience letter

**Recruitment model changes:**
- 8-stage pipeline: `pending → screening → interview_scheduled → interview_done → selected → offer_sent → rejected → converted`
- `portal_user` FK + `portal_credentials_sent` flag

**Migrations:** accounts 0021 (schema), 0022 (seed system_admin complete), 0023 (onboarding.approve permission + portal_invite template); recruitment 0003.

**New views:** `EmployeeProfileView`, `EmployeeDocumentView`, `SubmitOnboardingView`, `OnboardingApprovalsListView`, `OnboardingApproveView`, `SendPortalLoginView`.

**Auto-conversion on approve:** assigns `role='employee'`, generates `employee_id` via `EmployeeCodeSettings.generate_employee_id()`, sets `candidate.status='converted'`.

**Frontend:**
- `/onboarding` — 5-tab wizard (Personal, Education & Experience, Bank Details, Emergency Contact, Documents)
- `/dashboard/onboarding-approvals` — approval queue with review drawer (account number masked `••••XXXX`)
- `hooks/useFetch.ts` — NEW generic fetch hook (race-condition safe, auto-extracts from envelope)
- `proxy.ts` — onboarding gate: non-complete users redirected to `/onboarding`

**Full flow:**
```
Candidate → Mark Selected → Send Login → portal_invite email
  → Candidate logs in → /onboarding wizard → Submit for Approval
  → HR reviews in /dashboard/onboarding-approvals → Approve
  → Auto-converted to employee → next login goes to /dashboard
```

**Key notes:**
- `portal_invite` template is seeded by migration 0023 — edit in Settings → Email Templates. Variables: `candidate_name`, `position`, `company_name`, `login_email`, `temp_password`, `portal_url`.
- `hr_admin` can only approve `employee`-role users; `system_admin` can approve anyone.
- `EmployeeCodeSettings` record must exist before approving the first candidate.
- `useFetch` hook must be used for all new pages — never `useState + useEffect + fetch`.

---

### 2026-06-29 — Rithwika (Org Chart + Expense Claims + Logo)

**Branch:** `frontend/expenses`

1. **Org Chart** (`app/dashboard/org-chart/`) — static tree with CSS connector lines (no JS measurement). `overflow-x: auto` + `minWidth: 640px` for small screens.
2. **Expense Claims** (`app/dashboard/expenses/`) — static; stats row, branch dropdown, category filter-scroll, approve/reject with confirmation modal, new expense form with receipt upload. Wire to backend: replace `INITIAL_EXPENSES` state with `useFetch(API.expenses.list)`.
3. **Royal HRMS Logo** — `public/logo.svg` (navy bg, three-person emblem, gold accents). Wired in: `DashboardShell.tsx` (30×30), `login/page.tsx` (42×42), `app/layout.tsx` (favicon). Use `<img>` not Next.js `<Image>` for SVGs.
4. **`.filter-scroll` CSS class** — for filter bars with 4+ icon+text buttons; horizontal scroll on mobile.
5. **Bottom-sheet modals** at `≤480px` — `100vw`, slide up from bottom.

---

### 2026-06-29 — G. Durga Prasad (Backend Error Handling + CRUD Completeness)

**Branch:** `Employee_Onboarding`

| Fix | File | Detail |
|---|---|---|
| `UnorderedObjectListWarning` | `RoleListCreateView` | Added `.order_by('id')` — `annotate()` strips `Meta.ordering` |
| Pagination missing | `EmployeeListCreateView` | Added full `Paginator` block |
| Input guards | `EmployeeListCreateView.post` | Length guards, email regex, date strptime |
| Unsafe date filter | `AuditLogListView` | `strptime('%Y-%m-%d')` guard |
| Welcome email broken | `EmployeeListCreateView` | Replaced `send_mail` with `_get_smtp_connection()` |
| Email log pagination missing | `CandidateEmailLogView` | Added pagination + search max 100 |
| Portal login guards missing | `SendPortalLoginView` | Duplicate email (409), `portal_url` format validation |
| Announcement view no-op | `AnnouncementViewTrackView` | Added 404 for non-existent announcement |

**Serializer validators added:** `CandidateCreateSerializer` (phone regex, max lengths), `AnnouncementWriteSerializer` (strip/blank/max_length), `BranchSerializer` (address, status), `CompanySerializer` (all string fields), `SMTPSettingsSerializer` (username blank check).

**Role/Department/Designation CRUD production standards:**
- `Role` + `Designation` models: added `created_at`, `updated_at` timestamps (migration 0027)
- `RoleListCreateView`: `?is_active` filter, pagination via `paginate()`/`paginated_data()`
- `RoleDetailView.delete()`: blocks system roles (`employee`, `hr_admin`, `system_admin`)
- `DepartmentDetailView.delete()`: 409 if active employees belong to the department

---

### 2026-06-29 — G. Durga Prasad (Onboarding Pipeline Production Gaps)

**Branch:** `Employee_Onboarding`

1. **Employee document storage path** — `EmployeeDocument.file` changed to callable `_employee_doc_path` → stores to `employee_documents/<employee_id>/<filename>` (was date-based path causing scattered URLs). Migration: 0024.

2. **Onboarding emails** — `OnboardingApproveView` now sends `onboarding_approved` or `onboarding_rejected` template email on every HR decision. Templates seeded via migration 0025.

3. **`portal_url` hardcode removed** — `SendPortalLoginView` reads `Company.objects.first().portal_url` instead of hardcoded domain.

4. **Pipeline endpoint** — `GET /api/onboarding/pipeline/` — only shows users linked to a `Candidate` via `portal_user` FK (excludes seeded demo accounts with `onboarding_status='pending'`).

5. **Resend credentials** — `POST /api/recruitment/candidates/<pk>/resend-portal-login/` — new temp password, resends `portal_invite` email.

6. **N+1 fix** — `OnboardingApprovalsListView` uses `select_related('role', 'profile')` + `prefetch_related('employee_documents')`.

7. **Onboarding candidates excluded from employees** — `EmployeeListCreateView.get()` excludes `employee_id=''`; directly-added employees get `onboarding_status=complete` on creation.

8. **`designation` + `branch` copy on approval** — `OnboardingApproveView` copies `candidate.position_applied` → `designation` and `candidate.branch.branch_name` → `branch`.

9. **HR approval payload saved** — `OnboardingApproveView` reads `designation` + `department` from `request.data`; HR-provided values take priority over candidate record fallback. `department` added to `update_fields`.

10. **Employee detail includes documents** — `_get_employee()` uses `prefetch_related('employee_documents')`; `_employee_dict()` builds and returns `documents` list with Cloudinary URLs.

---

### 2026-06-29 — Leave Management Module

**Branch:** `LEAVE`

Leave management module completed — Leave Dashboard, Apply Leave workflow, Approvals, Leave Balance, Holiday Calendar, Analytics, Audit Log, Leave Settings and Policy configuration. Ready for QA/testing.

---

### 2026-06-29 — Safura Samreen (Frontend Onboarding + Employee Fixes)

**Branch:** `Frontend/Employee_Onboarding`

1. **Candidate Review simplified** — review stage removed; page shows only onboarding approvals. `handleOnboardingAction` accepts `extras: { department, designation }` forwarded to the approve endpoint.

2. **OnboardingDrawer — inline dept/designation assignment** — "Approve & Activate" reveals inline assign panel. Departments from `GET /api/departments/?page_size=100`; designations filtered client-side by department. Two-step approve flow.

3. **Employee Profile** — `department` and `designation` added as editable fields in `personal` PROFILE_SECTION.

4. **Employees List hydration fix** — `getStoredUser()` moved from render-time to `useState + useEffect`.

5. **AddEmployeeModal fix** — departments API returns paginated envelope; updated to access `.results`.

6. **HRDecisionModal + MarkCandidateModal fixes:**
   - Response accessor: `tplRes.data?.data?.results ?? {}`
   - Grouped `<optgroup>` dropdown by template category
   - `AUTO_KEYS` set with UPPERCASE names (`{FULL_NAME}`, `{EMAIL}`, etc.)

7. **SMTP Settings fix** — `GET /api/settings/smtp/` returns `{ count, page, results: [...] }`; page now accesses `.results`.

8. **Email Templates crash fixes** — `?? ""` fallbacks on nullable fields; `loadData` fixed to access `envelope.results` before `flattenTemplates()`.

---

## What's Built

### Backend

- [x] Custom User model (UUID PK, onboarding_status)
- [x] JWT auth (login/logout/forgot-password/change-password)
- [x] Account lockout (5 attempts, 30 min)
- [x] Role + Permission CRUD with system-role delete guard
- [x] Department + Designation CRUD (timestamps, active-employee guard on delete)
- [x] Audit log (all admin write events)
- [x] Company info (singleton, logo, portal_url)
- [x] SMTP settings (admin-configurable, activate, test)
- [x] Email templates (WYSIWYG, attachments, preview)
- [x] Document Center (Cloudinary, soft-delete, streaming proxy)
- [x] Branch module (State/City cascading, CRUD, auto-generated codes, permission-gated)
- [x] Recruitment module (8-stage pipeline, email delivery, email logs, stats)
- [x] Onboarding flow (wizard, submit, HR approval queue, pipeline endpoint, emails)
- [x] Portal login (send + resend credentials via email)
- [x] Employee management (list, create, detail with documents)
- [x] Announcements module
- [x] Leave management module

### Frontend

- [x] Auth (login, forgot password, change password)
- [x] Dashboard Shell (sidebar, navbar, permission-based nav)
- [x] Role-based dashboards (hr_admin, system_admin, manager, employee)
- [x] Settings (Company, SMTP, Email Templates, Roles & Permissions, Departments, Audit Log)
- [x] Document Center
- [x] Branch management
- [x] Recruitment / Interview List (8-stage pipeline UI)
- [x] Candidate Review / HR Decision
- [x] Onboarding wizard (`/onboarding`)
- [x] Onboarding approval queue
- [x] Employee management (list, add, profile)
- [x] Announcements
- [x] Org Chart (static)
- [x] Expense Claims (static — wire to backend when ready)
- [x] Leave management screens

### Planned / Not Yet Wired

- [ ] Expense Claims backend integration
- [ ] Org Chart backend integration
- [ ] Attendance module
- [ ] Payroll module
- [ ] Notifications

---

## Adding a New Module (Pattern)

### Backend

1. Create app: `python manage.py startapp <module>` under `apps/`
2. Register in `config/settings.py` + `config/urls.py`
3. Add models → `makemigrations` + `migrate`
4. Add serializers, views, urls using `success()`/`error()` from `core.responses`
5. Seed permissions via data migration; assign to appropriate roles
6. Guard views using `_has_perm(request.user, '<module>.<action>')` pattern
7. Add `AuditLog.objects.create()` on all admin write operations

### Frontend

1. Add endpoint path to `lib/api/endpoints.ts`
2. Add page under `app/dashboard/<module>/`
3. Fetch with `useFetch` hook — never `useState + useEffect + fetch`
4. Add nav item to `lib/navConfig.ts` with required permission
5. Add route to `proxy.ts` `ROUTE_PERMISSIONS` map
