# Royal Staffing HRMS — Team Context

## What This Is

Backend API for the Royal Staffing HRMS system. Built with Django REST Framework + JWT authentication. Currently covers **Authentication**, **Role & Permission Management**, and the **Branch Management** module. More modules (employees, payroll, leave, etc.) will be added as separate Django apps.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Python 3.13 |
| Framework | Django 4.2 + Django REST Framework 3.15 |
| Auth | JWT via `djangorestframework-simplejwt` 5.3 |
| Database | PostgreSQL (Neon cloud) |
| ORM | Django ORM |
| File Storage | **Cloudinary** (`django-cloudinary-storage` 0.3.0) — all `FileField` uploads go here |
| Email | Gmail SMTP (App Password) |
| Environment | `django-environ` (.env file) |

---

## Project Structure

```
HRMS/
└── Royal-HRMS/
    ├── config/
    │   ├── settings.py          # All Django settings
    │   ├── urls.py              # Root URL config
    │   ├── exceptions.py        # Global JSON error handler
    │   └── wsgi.py
    ├── apps/
    │   ├── accounts/            # Auth + roles + permissions + document center app
    │   │   ├── models.py        # User, Role, Permission, RolePermission, AuditLog, OTP, Document models
    │   │   ├── views.py         # Auth + role + permission + document API views
    │   │   ├── serializers.py   # Request/response validation
    │   │   ├── urls.py          # Endpoint routes
    │   │   ├── tokens.py        # Custom JWT with role + permissions
    │   │   ├── utils.py         # OTP generator + email sender
    │   │   ├── admin.py         # Django admin registrations
    │   │   ├── throttles.py     # Custom DRF throttle classes
    │   │   ├── management/
    │   │   │   └── commands/
    │   │   │       └── migrate_files_to_cloudinary.py  # One-time migration: local → Cloudinary
    │   │   └── migrations/
    │   │       ├── 0001_initial.py
    │   │       ├── 0002_seed_roles_permissions.py   # Seeds 4 roles + 46 permissions
    │   │       ├── 0003_seed_demo_users.py          # Seeds 4 demo users
    │   │       ├── 0013_email_template_attachments.py
    │   │       ├── 0014_add_performance_indexes.py
    │   │       ├── 0015_email_template_categories.py
    │   │       └── 0016_document_center.py          # Creates hrms_documents table
    │   └── branch/              # Branch management app (added 2026-06-24)
    │       ├── models.py        # State, City, Branch models
    │       ├── views.py         # Branch CRUD + stats + distribution views
    │       ├── serializers.py   # Branch, State, City serializers
    │       ├── urls.py          # Branch endpoint routes
    │       ├── utils.py         # City prefix map + branch code generator
    │       ├── admin.py         # Django admin for State/City/Branch
    │       └── migrations/
    │           ├── 0001_initial.py               # Creates branch_states, branch_cities, branch_branches tables
    │           ├── 0002_initial_data.py          # Seeds all 36 Indian states/UTs + ~200 cities
    │           └── 0003_branch_permissions.py    # Adds branches.* permissions → system_admin + hr_admin
    ├── logs/
    │   └── auth.log             # Rotating auth event log
    ├── manage.py
    ├── requirements.txt
    └── .env                     # Secrets (do not commit)
```

---

## Database

**Provider:** Neon PostgreSQL (serverless, cloud-hosted)
**Connection:** Set in `.env` as `DATABASE_URL`

### Tables Created

| Table | Purpose |
|---|---|
| `hrms_roles` | The 4 roles (hr_admin, system_admin, manager, employee) |
| `hrms_permissions` | 50 module-level permissions (46 original + 4 branch) |
| `hrms_role_permissions` | M2M: which role has which permissions |
| `hrms_users` | All users — custom User model |
| `hrms_password_reset_tokens` | Single-use tokens for forgot-password flow |
| `hrms_audit_logs` | Immutable log of login/logout/password/role events |
| `otp_verifications` | 6-digit OTPs for forgot-password step 2 |
| `branch_states` | Indian states and union territories master |
| `branch_cities` | Cities per state (cascading dropdown source) |
| `branch_branches` | Company branches with auto-generated branch codes |
| `hrms_documents` | Document Center — files stored on Cloudinary (added 2026-06-25) |

---

## Local Setup

### 1. Install dependencies
```powershell
pip install -r requirements.txt
```

> **Note:** `psycopg2-binary` has no pre-built wheel for Python 3.14. The project falls back to SQLite in dev if PostgreSQL isn't available. For PostgreSQL, run `pip install psycopg2-binary` separately after PostgreSQL client tools are installed.

### 2. Run migrations
```powershell
python manage.py migrate
```

This creates all tables and auto-seeds all 36 Indian states/UTs, ~200 cities, and branch permissions.

### 3. Start the server
```powershell
python manage.py runserver 0.0.0.0:8000
```

API is now at `http://localhost:8000/api/`

---

## Environment Variables (.env)

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
EMAIL_HOST_PASSWORD=<app-password>
DEFAULT_FROM_EMAIL=Royal Staffing HRMS <email>

# Cloudinary — all FileField uploads (documents, email attachments)
CLOUDINARY_CLOUD_NAME=<cloud-name>
CLOUDINARY_API_KEY=<api-key>
CLOUDINARY_API_SECRET=<api-secret>

CORS_ALLOWED_ORIGINS=http://localhost:3000
```

> To allow access from other devices on the local network, add the device's IP to `ALLOWED_HOSTS` in `.env` (e.g. `192.168.0.249`).
> For local email testing, change `EMAIL_BACKEND` to `django.core.mail.backends.console.EmailBackend`.

---

## Demo Users

All passwords: **`Hrms@1234`**

| Email | Role | Permissions |
|---|---|---|
| hradmin@royal.com | hr_admin | All 50 permissions (including all branch permissions) |
| sysadmin@royal.com | system_admin | 24 permissions (20 original + 4 branch) |
| manager@royal.com | manager | 25 permissions |
| employee@royal.com | employee | 10 permissions (must change password on first login) |

---

## Authentication Flow

### Login
`POST /api/login/` → returns `access_token` (30 min) + `refresh_token` (7 days)

All protected requests need:
```
Authorization: Bearer <access_token>
```

### Forgot Password (3 steps)
1. `POST /api/forgot-password/` — sends 6-digit OTP to email (valid 10 min)
2. `POST /api/verify-otp/` — verify OTP → returns `reset_token` (UUID)
3. `POST /api/reset-password/` — use `reset_token` to set new password (token valid 60 min)

### Account Lockout
- 5 consecutive wrong passwords → account locked for 30 minutes
- Auto-unlocks after lockout period expires
- Login response includes `must_change_password` flag — frontend must redirect to change-password screen if `true`

---

## Role System

Roles are stored in the database (not hardcoded). Each role has a set of permissions assigned via `hrms_role_permissions`.

### 4 Default Roles

| Role | Display Name | Permissions |
|---|---|---|
| `hr_admin` | HR Admin | All 50 (full access) |
| `system_admin` | System Admin | 24 (20 original + 4 branch — super admin) |
| `manager` | Manager | 25 |
| `employee` | Employee | 10 |

### 50 Permissions (module.action format)

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
branches:      view, create, edit, delete        ← added 2026-06-24
```

### Permissions in JWT Token

The login response includes the user's full permissions array — frontend should store this in state and use it for UI access control:

```js
// Example usage in frontend
const canApproveLeave   = permissions.includes('leave.approve')
const canViewPayroll    = permissions.includes('payroll.view')
const canCreateBranch   = permissions.includes('branches.create')
```

No need to call a separate permissions endpoint after login.

---

## API Endpoints

**Base URL:** `http://localhost:8000/api`

### Authentication (Public)

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/login/` | Login — returns tokens + user + permissions |
| POST | `/api/logout/` | Logout — blacklists refresh token |
| POST | `/api/forgot-password/` | Send OTP to email |
| POST | `/api/verify-otp/` | Verify OTP → get reset_token |
| POST | `/api/reset-password/` | Set new password with reset_token |
| POST | `/api/change-password/` | Change password (JWT required) |

### Roles (hr_admin / system_admin only)

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/roles/` | List all roles with permissions + user count |
| POST | `/api/roles/` | Create role with permissions |
| GET | `/api/roles/{id}/` | Get single role |
| PUT | `/api/roles/{id}/` | Full update (replaces all permissions) |
| PATCH | `/api/roles/{id}/` | Partial update |
| DELETE | `/api/roles/{id}/` | Delete (blocked if users assigned) |

### Permissions (hr_admin / system_admin only)

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/permissions/` | List all 50 permissions grouped by module |
| POST | `/api/permissions/` | Create a new custom permission |
| GET | `/api/permissions/{id}/` | Get single permission |
| PUT | `/api/permissions/{id}/` | Update permission |
| DELETE | `/api/permissions/{id}/` | Delete permission (removed from all roles) |

### Branch — Cascading Dropdowns (all authenticated users)

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/branch/states/` | List all active states (for State dropdown) |
| GET | `/api/branch/states/{id}/cities/` | List cities for selected state (for City dropdown) |

### Branch — CRUD (requires `branches.*` permission — system_admin / hr_admin)

| Method | Endpoint | Permission | Description |
|---|---|---|---|
| GET | `/api/branch/branches/` | `branches.view` | List branches (filters: `?status=`, `?state=`, `?city=`) |
| POST | `/api/branch/branches/` | `branches.create` | Create branch (auto-generates branch code) |
| GET | `/api/branch/branches/{id}/` | `branches.view` | Get single branch |
| PUT | `/api/branch/branches/{id}/` | `branches.edit` | Full update |
| PATCH | `/api/branch/branches/{id}/` | `branches.edit` | Partial update |
| DELETE | `/api/branch/branches/{id}/` | `branches.delete` | Delete branch |
| GET | `/api/branch/branches/preview-code/?city_id={id}` | `branches.create` | Preview auto-generated branch code |
| GET | `/api/branch/branches/stats/` | `branches.view` | Dashboard counts (employees, branches, cities) |
| GET | `/api/branch/branches/distribution/` | `branches.view` | Employee count per branch (bar chart data) |

### Document Center (hr_admin / system_admin only for write; all authenticated users can read)

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/documents/` | List active documents. Filters: `?category=`, `?branch=`, `?file_type=`, `?search=` |
| POST | `/api/documents/` | Upload document (`multipart/form-data`) — requires `hr_admin` or `system_admin` |
| GET | `/api/documents/stats/` | Document counts by category (`total` + `by_category`) |
| GET | `/api/documents/{id}/` | Get single document |
| PATCH | `/api/documents/{id}/` | Update metadata or replace file — requires `hr_admin` or `system_admin` |
| DELETE | `/api/documents/{id}/` | Soft-delete (sets `is_active=False`) — requires `hr_admin` or `system_admin` |

#### Document Upload fields (`multipart/form-data`)

| Field | Required | Notes |
|---|---|---|
| `file` | Yes | PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, JPG, PNG, TXT, CSV — max 25 MB |
| `title` | Yes | Max 200 chars, must be unique (case-insensitive) |
| `category` | Yes | `policy` / `form` / `template` / `other` |
| `description` | No | Max 1,000 chars |
| `branch` | No | Branch FK (integer ID) |

> `file_name`, `file_type`, `file_size`, `is_active` are all set server-side — never send them from the client.

---

## Branch Module Details (added 2026-06-24 — SwethaD)

### Branch Code Auto-Generation

Branch codes are auto-generated from the city name on creation:

| City | 1st branch | 2nd branch | 3rd branch |
|---|---|---|---|
| Delhi | `DEL` | `DEL-01` | `DEL-02` |
| Mumbai | `MUM` | `MUM-01` | `MUM-02` |
| Bengaluru | `BLR` | `BLR-01` | `BLR-02` |

- 150+ Indian cities are mapped to 3-letter codes in `apps/branch/utils.py`
- Unknown cities fall back to the first 3 alphabetic characters of the name
- Race conditions are handled via `select_for_update()` within an atomic transaction

### State → City Cascading Dropdown

1. Call `GET /api/branch/states/` to populate the State dropdown
2. On state selection, call `GET /api/branch/states/{id}/cities/` to populate City dropdown
3. City dropdown is only enabled after a state is selected

All 36 Indian states/UTs and ~200 major cities are pre-seeded via migration `0002_initial_data`.

### Branch Permission Guard

Each view method checks the user's permission codename dynamically via `RolePermission`:

```python
# In apps/branch/views.py
def _has_perm(user, codename):
    return user.role.role_permissions.filter(permission__codename=codename).exists()
```

Permissions are fully manageable via `GET/POST /api/permissions/` — no code change needed to grant/revoke.

---

## Response Envelope

Every response — success or error — uses this shape:

```json
{
  "status": "success | error",
  "message": "Human-readable string",
  "data": {}
}
```

On validation errors, `data` contains field-level detail:
```json
{
  "status": "error",
  "message": "new_password: This field is required.",
  "data": {
    "new_password": ["This field is required."]
  }
}
```

---

## Security Notes

- JWT tokens are blacklisted on logout (token blacklist table)
- Passwords are hashed with Django's default PBKDF2 (production: upgrade to Argon2)
- All auth events (login, logout, password change, role changes) are written to `hrms_audit_logs`
- Account lockout after 5 failed login attempts (30-minute lockout)
- OTPs are invalidated after use or after 5 wrong attempts
- SSL required for database connection (`sslmode=require`)
- `must_change_password` flag forces password change on first login
- Branch CRUD is permission-gated — only roles with `branches.*` codenames can access

---

## What's Built vs What's Next

### Done
- [x] Custom User model (`hrms_users`) with UUID PK
- [x] JWT login with role + permissions embedded in token
- [x] Forgot password (OTP email → verify → reset)
- [x] Change password (authenticated)
- [x] Account lockout after failed attempts
- [x] Role CRUD with permission assignment
- [x] Permission CRUD
- [x] Audit log for all auth events
- [x] 4 roles + 46 permissions seeded
- [x] 4 demo users seeded
- [x] Neon PostgreSQL connected
- [x] **Branch app (`apps/branch/`)** — 2026-06-24 SwethaD
  - [x] State + City models with all 36 Indian states/UTs and ~200 cities seeded
  - [x] Branch model with auto-generated branch codes
  - [x] State → City cascading dropdown endpoints
  - [x] Branch CRUD (GET list, GET detail, POST, PUT, PATCH, DELETE)
  - [x] Branch code preview endpoint
  - [x] Dashboard stats endpoint (total employees, branches, active branches, cities)
  - [x] Employee distribution endpoint (bar chart data)
  - [x] 4 branch permissions seeded and assigned to `system_admin` + `hr_admin`
  - [x] Permission-codename-based access guard on all branch endpoints

  - [x] **Document Center** — 2026-06-25
    - [x] `Document` model with `hrms_documents` table, soft-delete, `is_active`, category choices
    - [x] All file uploads stored on **Cloudinary** via `RawMediaCloudinaryStorage`
    - [x] Document CRUD: list (with category/branch/file_type/search filters), upload, detail, update, soft-delete
    - [x] Stats endpoint: total + per-category counts
    - [x] Full validation: unique title, zero-size/missing-name file guard, path traversal sanitization, branch existence check
    - [x] `migrate_files_to_cloudinary` management command for migrating any legacy local files
    - [x] **Document file preview & download fix** — 2026-06-25
      - Root cause: Cloudinary CDN returned 401 for all direct resource URLs (account-level access restriction)
      - Fix: `GET /api/documents/{id}/` now doubles as a streaming proxy when `?t=<token>` is in the URL
      - `DocumentDetailView.get_permissions()` skips JWT when `?t=` is present; auth is a 2-hour Django-signed URL token
      - `DocumentDetailView._stream_file()` uses `cloudinary.utils.private_download_url()` (API key + secret) to fetch the file server-side, then streams it to the browser — bypasses all CDN restrictions
      - `DocumentSerializer.get_file_url` now returns `http://…/api/documents/{id}/?t=<token>` — plain `fetch()` from the frontend works without an Authorization header

### Planned (next modules)
- [ ] Employee management (profiles, departments)
- [ ] Attendance module
- [ ] Leave management
- [ ] Payroll
- [ ] Recruitment
- [ ] Expenses
- [ ] Announcements
- [ ] Notifications

---

## Session Log

### 2026-06-25 — Document Center + Cloudinary Integration

**Who:** Durga Prasad

#### 1. Document Center (`apps/accounts/`) — full feature

New model `Document` (`hrms_documents` table, migration `0016_document_center.py`):
- Fields: `title`, `description`, `category` (policy/form/template/other), `file` (FileField), `file_name`, `file_type`, `file_size`, `branch` FK, `uploaded_by` FK, `is_active` (soft-delete), timestamps
- Indexes on `category`, `branch`, `uploaded_at`

New views appended to `apps/accounts/views.py`:
- `_can_manage_docs(user)` — permission helper (hr_admin + system_admin only)
- `DocumentListCreateView` — GET list with filters, POST multipart upload
- `DocumentDetailView` — GET detail, PATCH metadata/file replace, DELETE soft-delete
- `DocumentStatsView` — single GROUP BY query, returns total + per-category counts

New URLs in `apps/accounts/urls.py`:
```
GET/POST  /api/documents/
GET       /api/documents/stats/
GET/PATCH/DELETE  /api/documents/{id}/
```

New serializer `DocumentSerializer` in `apps/accounts/serializers.py`:
- `file_url` — SerializerMethodField returning absolute URL (Cloudinary-aware)
- `file_size_display` — human-readable (B / KB / MB)
- `branch_name` — SerializerMethodField (returns `null` for no branch, not string `"None"`)
- `is_active` in `read_only_fields` — client can never set it to False

#### 2. Bug fix — document disappeared after upload

Root cause: `is_active` was writable in the serializer. Multipart form data sent `is_active=false` → DRF saved `False` → list filtered it out (`filter(is_active=True)`).

Fix:
- Added `'is_active'` to `read_only_fields`
- Added `is_active=True` to `serializer.save()` call in POST as a hard override
- Replaced `branch_name = CharField(source='branch.branch_name')` (returned string `"None"`) with `SerializerMethodField`

#### 3. Cloudinary integration — all file storage

Installed: `cloudinary==1.44.2`, `django-cloudinary-storage==0.3.0`

`config/settings.py` changes:
- Added `'cloudinary_storage'` (before `staticfiles`) and `'cloudinary'` to `INSTALLED_APPS`
- Added `CLOUDINARY_STORAGE` dict reading from env vars
- Set `DEFAULT_FILE_STORAGE = 'cloudinary_storage.storage.RawMediaCloudinaryStorage'`

Effect: every `FileField` on every model (documents, email attachments) now uploads to Cloudinary automatically. URLs returned by the API are `https://res.cloudinary.com/...` absolute links. `DELETE_CLOUDINARY_MEDIA: True` auto-removes files when model instances are deleted.

`apps/accounts/serializers.py` — both `get_file_url` and `get_url` (EmailTemplateAttachment) updated to detect already-absolute Cloudinary URLs and skip `build_absolute_uri` wrapping.

Management command: `python manage.py migrate_files_to_cloudinary`
- Finds all Document and EmailTemplateAttachment records with local file paths
- Uploads each to Cloudinary via Django's storage API
- Deletes local copy after successful upload
- `--dry-run` flag for safe preview
- Handles legacy `media/` path prefix bug in old records

#### 4. Document Center — complete validations & error handling

**Serializer (`DocumentSerializer`)**:

| Validator | What it checks |
|---|---|
| `validate_file` | Empty file (`size == 0`), missing filename, unsupported MIME (shows rejected type), >25 MB, path-traversal sanitization via `os.path.basename()` |
| `validate_title` | Blank, >200 chars, **case-insensitive uniqueness** among active docs (update-safe — excludes current instance on PATCH) |
| `validate_description` | `.strip()` before length check, >1,000 chars |
| `validate_category` | Explicit choice validation with "Choose from: …" message |
| `validate` (cross-field) | Branch FK existence check |

**Views**:

| Endpoint | Added guard |
|---|---|
| GET `?search=` | Max 100 chars |
| GET `?branch=` | Must be positive integer |
| GET `?file_type=` | New filter — validated against `MIME_TO_TYPE` values |
| GET `?search=` | Now searches `description` field too (was title-only) |
| POST | Explicit `'file' not in request.data` check; `serializer.save()` wrapped; AuditLog isolated |
| PATCH | Empty body rejected; `serializer.save()` wrapped; `old_file.delete()` wrapped — Cloudinary failure is logged but never crashes the response; AuditLog isolated |
| DELETE | `doc.save()` wrapped; AuditLog isolated |

---

## Adding a New Module (Pattern)

1. Create a new Django app: `python manage.py startapp <module>` under `apps/`
2. Register in `config/settings.py` INSTALLED_APPS and `config/urls.py`
3. Add models → run `python manage.py makemigrations <app> && python manage.py migrate`
4. Add serializers, views, urls following the same `success()`/`error()` response helpers
5. Seed permissions via a data migration and assign to appropriate roles
6. Guard view methods using `_has_perm(request.user, '<module>.<action>')` pattern
