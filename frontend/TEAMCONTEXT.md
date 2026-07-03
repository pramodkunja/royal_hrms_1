# Team Context — Assessment Feature

**Author:** Safura Samreen
**Date:** 2 July 2026
**Branch:** Frontend/Assessment

---

## Overview

This document covers all frontend work done on the assessment feature. No backend changes were made — all changes are frontend-only.

---

## 1. Login Page — Redirect Simplification

**File:** `app/login/page.tsx`

Removed the extra `GET /assessments/my/` API call that was being made after login just to check assessment status. The backend already returns `assessment_status` inside the login response under `d.user.assessment_status`.

**Redirect logic:**
```typescript
saveAuth(user);
let dest = "/dashboard";
if (user.onboarding_status !== "complete")     dest = "/onboarding";
else if (user.assessment_status === "pending") dest = "/onboarding/assessments";
window.location.href = dest;
```

`LoginApiResponse` interface updated to include `assessment_status: string` in the user object.

---

## 2. Auth Helpers

**File:** `lib/auth.ts`

Added `setAssessmentStatus(newStatus: string)` — updates `assessment_status` inside the `royal_hrms_user` cookie so the proxy stops redirecting after all assessments are complete.

#### File structure:
```
email-templates/
  _data.ts                    ← types, helpers, validation, API endpoints
  page.tsx                    ← grouped sections, all API calls live here
  _components/
    EditTemplateModal.tsx     ← WYSIWYG editor modal
```

#### Features:
- **Grouped display** — templates shown in sections by type: Document, Notification, Reminder, Wish (each with colored header)
- **Preview** — fetches `GET /api/settings/email-templates/{id}/preview/` and renders HTML in a modal
- **Edit** — WYSIWYG editor with toolbar (bold, italic, underline, strikethrough, lists, alignment, link/unlink, clear format), HTML source toggle, available-variable tag sidebar
- **Add** — requires Display Name (free-text, e.g. "Pay Slip") + Slug (auto-generated, e.g. `pay_slip`, must match `^[a-z][a-z0-9_]*$`), subject, body
- **Attachments bar** — fixed strip between editor and footer; "Attach files" button + horizontal chip list with file-type icons and image thumbnails; drag-and-drop supported
- `multipart/form-data` used when attachments are present; JSON otherwise

#### Template types (actual API):
`document` · `notification` · `reminder` · `wish`

#### API shape (actual):
`GET /api/settings/email-templates/` returns `data` as an object keyed by type — `{ document: [...], notification: [...], reminder: [...], wish: [...] }`. `flattenTemplates()` in `_data.ts` merges them into one array for filtering.

#### Slug rules (enforced client-side):
- Auto-generated from Display Name as user types
- Only `[a-z0-9_]` allowed; must start with a letter
- User can override the slug manually (auto-fill stops once manually edited)

---

## CSS Module Migration (Session 2)

All CSS module files were removed. Styles were migrated to Tailwind classes + inline `style={}` for CSS custom properties.

| Deleted file | Migrated to |
|---|---|
| `app/login/login.module.css` | Tailwind + inline styles in `app/login/page.tsx` |
| `app/dashboard/profile/profile.module.css` | Tailwind in `ProfileClient.tsx` + `ChangePasswordForm.tsx` |
| `app/dashboard/dashboard.module.css` | Was already unused — deleted |
| `app/dashboard/settings/settings.module.css` | Was already unused — deleted |
| `components/dashboard/DashboardShell.module.css` | Was already unused — deleted |

> **Tailwind v2 note:** `text-white/75` opacity modifier syntax does NOT work in v2.2.19 (v3 only). Use inline `style={{ color: "rgba(255,255,255,0.75)" }}` instead.

---

## API Endpoints Used

| Method | Endpoint | Used for |
|--------|----------|----------|
| `POST` | `/api/login/` | Login — returns `user.permissions[]` used for all sidebar/route access |
| `POST` | `/api/roles/` | Create new role |
| `PUT` | `/api/roles/{id}/` | Full update role (edit modal) |
| `PATCH` | `/api/roles/{id}/` | Toggle is_active only |
| `GET` | `/api/permissions/` | Load all 46 permissions grouped by module |
| `POST` | `/api/logout/` | Logout and clear auth |
| `GET` | `/api/settings/smtp/` | List all SMTP configs (flat array) |
| `POST` | `/api/settings/smtp/` | Create SMTP config |
| `PUT` | `/api/settings/smtp/{id}/` | Full update SMTP config |
| `DELETE` | `/api/settings/smtp/{id}/` | Delete SMTP config |
| `POST` | `/api/settings/smtp/{id}/activate/` | Set config as active (no body) |
| `POST` | `/api/settings/smtp/test/` | Send test email (full SMTP fields + `test_recipient`) |
| `GET` | `/api/settings/email-templates/` | List templates grouped by type |
| `POST` | `/api/settings/email-templates/` | Create template (`multipart/form-data`) |
| `PUT` | `/api/settings/email-templates/{id}/` | Update template |
| `GET` | `/api/settings/email-templates/{id}/preview/` | Rendered HTML preview |

> **Note:** `GET /api/roles/` is no longer called after login. Sidebar visibility is driven entirely by `user.permissions[]` from the login response.

---

## Key Files Changed / Created

| File | What |
|------|------|
| `tailwind.config.js` | Created — v2 JIT config |
| `postcss.config.mjs` | Updated — standard tailwindcss + autoprefixer |
| `app/globals.css` | Added Tailwind directives + all design system utility classes |
| `lib/navConfig.ts` | Rewritten — single master nav list with per-item `permission` field; `buildNav(permissions[])` replaces role trees |
| `lib/auth.ts` | Added `permissions: string[]` to `UserInfo` |
| `lib/session.ts` | Added `permissions: string[]` to `SessionPayload` |
| `app/login/page.tsx` | Reads `user.permissions` from login response, saves to cookie/localStorage |
| `components/dashboard/DashboardShell.tsx` | Removed `/roles/` fetch; uses `buildNav(session.permissions)` directly |
| `app/dashboard/page.tsx` | Local `resolveRole` for dashboard widget selection; no navConfig import |
| `proxy.ts` | Added permission-based route protection — direct URL access blocked if user lacks permission |
| `app/dashboard/_components/HRDashboard.tsx` | New |
| `app/dashboard/_components/AdminDashboard.tsx` | New |
| `app/dashboard/_components/ManagerDashboard.tsx` | New |
| `app/dashboard/_components/EmployeeDashboard.tsx` | New |
| `app/dashboard/settings/page.tsx` | Updated — "Roles & Permissions" card + routing |
| `app/dashboard/settings/permissions/_data.ts` | Full rewrite — real API types + presets |
| `app/dashboard/settings/permissions/page.tsx` | Full rewrite — API integration + edit flow |
| `app/dashboard/settings/permissions/_components/RoleFormFields.tsx` | New — shared form body |
| `app/dashboard/settings/permissions/_components/AddRoleModal.tsx` | Rewritten — uses RoleFormFields |
| `app/dashboard/settings/permissions/_components/EditRoleModal.tsx` | New |
| `app/dashboard/settings/smtp/_data.ts` | New — SMTP types, endpoint helpers (`smtpDetail(id)`, `smtpActivate(id)`), form/payload converters |
| `app/dashboard/settings/smtp/page.tsx` | New — dynamic card list, CRUD + activate + delete + test |
| `app/dashboard/settings/smtp/_components/SmtpModal.tsx` | New — Add/Edit modal with name + all SMTP fields |
| `app/dashboard/settings/email-templates/_data.ts` | New — template types (doc/notification/reminder/wish), `flattenTemplates()`, `toSlug()`, form/validation |
| `app/dashboard/settings/email-templates/page.tsx` | New — grouped sections, preview modal, create/update with multipart |
| `app/dashboard/settings/email-templates/_components/EditTemplateModal.tsx` | New — WYSIWYG editor, HTML source toggle, variable tag sidebar, attachment bar |

---

## Demo Credentials

| Email | Password | Role |
|-------|----------|------|
| hradmin@royal.com | Hrms@1234 | hr_admin |
| sysadmin@royal.com | Hrms@1234 | system_admin |
| manager@royal.com | Hrms@1234 | manager |
| employee@royal.com | Hrms@1234 | employee |

---

## Notes for Next Developer

- The `session` object (`lib/session.ts`) contains `userId`, `email`, `name`, `role`, `permissions[]` — stored in a cookie after login
- `clientApi` (`lib/clientApi.ts`) automatically attaches the Bearer token from `localStorage["royal_token"]`
- All API responses follow the envelope `{ status, message, data }` — always check `res.data.data` for the payload
- The design system variables (`--primary`, `--on-bg`, `--outline-v`, etc.) are defined in `app/globals.css` and referenced in Tailwind via arbitrary values like `bg-[var(--primary)]`
- Dashboard pages are **server components** — they call `getSession()` directly. Sub-components that need interactivity are `"use client"` with `useState`/`useEffect`
- **Sidebar visibility + route protection both use `user.permissions[]`** — if you add a new page, add it to both `lib/navConfig.ts` (master nav) and `proxy.ts` (`ROUTE_PERMISSIONS` map)
- `proxy.ts` (not `middleware.ts`) is this project's Next.js edge proxy — the framework uses a custom convention

---

## Session 3 — Onboarding Approval UI (2026-06-30)

**Developer:** Vignesh Kumar Saka

### What Was Built

#### 1. Onboarding Approvals List (`app/dashboard/candidate-review/page.tsx`)

Page already existed. Fixed error handling in `handleOnboardingAction`:

**Before:** `(err as { message?: string })?.message ?? "Action failed."` — this reads `err.message` which on Axios errors is a generic `"Request failed with status code 400"`.

**After:**
```ts
const msg =
  (err as { response?: { data?: { message?: string } } })?.response?.data?.message ??
  (err as { message?: string })?.message ??
  "Action failed.";
```
Backend puts the friendly error at `err.response.data.message` — this chain now surfaces it correctly.

#### 2. OnboardingDrawer Rewrite (`app/dashboard/candidate-review/_components/OnboardingDrawer.tsx`)

Full rewrite. Previous version had a two-step flow where HR had to click "Approve & Activate ✓" to reveal the department/designation dropdowns.

**New behavior:**
- ASSIGN ROLE section (department + designation selects) always visible — no toggle button
- On mount: fetches all departments (`GET /api/departments/?page_size=100`) and all designations (`GET /api/designations/?page_size=200`) in parallel
- Designations filtered client-side when department changes: `allDesigs.filter(d => d.department_name === selDept)`
- Single "Confirm & Activate" button validates both fields; shows inline error if either is missing before calling `onAction`
- `onAction(userId, "approve", { department: selDept, designation: selDesig })` — passes string names, not IDs (matches backend `OnboardingApproveView` expectation)

**Backend note:** `POST /api/onboarding/approve/{userId}/` accepts `{ decision, remarks, department, designation }` as string names, not IDs. The view looks up dept/desig by name.

### Key Files Changed

| File | Change |
|------|--------|
| `app/dashboard/candidate-review/page.tsx` | Error message extraction chain — reads `response.data.message` |
| `app/dashboard/candidate-review/_components/OnboardingDrawer.tsx` | Full rewrite — ASSIGN ROLE always visible, single-step confirm, parallel dept+desig load |

### API Endpoints Used

| Method | Endpoint | Used for |
|--------|----------|----------|
| `GET` | `/api/onboarding/approvals/` | List all onboarding submissions |
| `POST` | `/api/onboarding/approve/{userId}/` | Approve or reject with dept/desig assignment |
| `GET` | `/api/departments/?page_size=100` | Department list for ASSIGN ROLE dropdown |
| `GET` | `/api/designations/?page_size=200` | All designations (filtered client-side by dept name) |

### Notes

- `API.onboarding.approvals` and `API.onboarding.approve(id)` must exist in `lib/api/endpoints.ts`
- `API.departments.list` and `API.designations.list` must exist in `lib/api/endpoints.ts`
- The `department_name` field on the designation object links designations to departments — client-side filter uses `d.department_name === selDept` where `selDept` is a string name

---

## Session 2 Notes (24 June 2026)

- **Hydration warning fix** — `fdprocessedid` browser-extension attributes injected into DOM elements cause React hydration mismatches. Fix: add `suppressHydrationWarning` to every `<button>` and `<input>` in DashboardShell. Adding it only to `<html>`/`<body>` in `layout.tsx` is not enough.
- **SMTP API is a flat array** — `GET /api/settings/smtp/` returns `data: [...]`, not `{ local: {}, server: {} }`. Each entry's `name` is a user-defined label. Activate is by entry `id`, not by type string.
- **Email template API is grouped by type** — `GET /api/settings/email-templates/` returns `data: { document: [...], notification: [...], reminder: [...], wish: [...] }`. Use `flattenTemplates()` to get a flat array.
- **Template `name` is a slug** — must match `^[a-z][a-z0-9_]*$`. A separate `display_name` field (human-readable) is also required on create. The modal auto-generates the slug from the display name.
- **Tailwind v2 does not support opacity modifiers** — `text-white/75` is a v3 feature. Use inline `style={{ color: "rgba(...)" }}` or CSS variables.

---

## Announcements Page — Rithwika (24 June 2026)

### `app/dashboard/announcements/page.tsx`

Full static announcements page (all styling pure Tailwind, no CSS modules). Colors: primary `#1e4e8c`, pinned accent `#c99a2e`.

- Page header + "+ Post Announcement" button
- 4 stat cards (Total Posts, Pinned, Reactions, Views) — recalculate live
- Filter tabs: All · General · Policy · Events · Celebrations
- Post cards with gold left-border for pinned; avatar initials, badges, counts, edit button
- Modal for add/edit with fields: Title, Category, Visibility, Branch, Body, Pin, Email notification
- **Currently fully static** — wire up to `/api/announcements/` when backend is ready

### Sidebar Dual-Active Bug Fix (`DashboardShell.tsx`)

`/dashboard/announcements`.startsWith(`/dashboard/`) was also activating the Dashboard nav item. Fix:
```ts
const isActive = pathname === item.path ||
  (item.path !== "/dashboard" && pathname.startsWith(item.path + "/"));
```

---

## Session 3 — Rithwika (25 June 2026)

### 1. JWT Login Fix (`lib/clientApi.ts`)

**Problem:** After login, a stale Bearer token was being attached to the `/login/` request itself. Django's `JWTAuthentication` then rejected it with `token_not_valid` even though the view uses `AllowAny`.

**Fix:** Added `AUTH_URLS` list to the Axios request interceptor. The interceptor now skips attaching the `Authorization` header when the request URL ends with any auth endpoint.

```ts
const AUTH_URLS = ["/login/", "/token/refresh/", "/forgot-password/", "/verify-otp/", "/reset-password/"];

clientApi.interceptors.request.use((config) => {
  if (typeof window !== "undefined") {
    const isAuthUrl = AUTH_URLS.some(u => config.url?.endsWith(u));
    if (!isAuthUrl) {
      const token = localStorage.getItem(TOKEN_KEY);
      if (token) config.headers.Authorization = `Bearer ${token}`;
    }
  }
  return config;
});
```

> **Note:** Only `lib/clientApi.ts` was modified. The Django backend was not touched.

---

### 2. Mobile Responsiveness — Full Application (Hybrid CSS approach)

All responsive changes use a hybrid model: **global CSS classes in `app/globals.css`** for layout-level rules, and **Tailwind responsive prefixes** (`md:`, `sm:`, `lg:`) for component-level overrides.

#### 2a. Login Page (`app/login/page.tsx`)
- Two-column layout (`grid`) converted to `flex flex-col md:grid` — stacks vertically on mobile
- Left decorative panel: `hidden md:flex` — hidden on mobile (full screen for the login form)
- Right panel padding: `px-6 py-8 md:px-10 md:py-12`

#### 2b. Dashboard Shell (`components/dashboard/DashboardShell.tsx`)
- **Sidebar** converted to a fixed overlay drawer on mobile using CSS `transform: translateX(-100%)` / `translateX(0)`:
  - `fixed left-0 top-0 w-[220px]` always; `md:relative md:translate-x-0` reverts to normal flow on desktop
  - `mobileOpen` state toggles `translate-x-0` vs `-translate-x-full`
  - Semi-transparent backdrop (`fixed inset-0 bg-black/40 md:hidden`) closes drawer on tap
- **Hamburger button:** `md:hidden` — visible only on mobile
- **Search bar:** `hidden md:flex` — hidden on mobile header
- **Header + content padding:** `px-3 md:px-6`, `p-4 md:p-6`

#### 2c. Announcements Page
- Stats grid, filter tabs (horizontal scroll on mobile), post cards — responsive via Tailwind grid utilities

#### 2d. Branches Page
- Card grid responsive via Tailwind responsive prefixes

---

### 3. Settings Pages — Mobile Responsiveness + Button Order

All settings sub-pages made mobile-responsive. **Button order rule enforced across all pages: Back button always first, Add button second.**

#### 3a. Departments & Designations (`app/dashboard/settings/departments/page.tsx`)
- **Stats bar:** `grid grid-cols-1 sm:grid-cols-3` with shared background and `gap: 1` separator trick
- **Two-panel layout:** `flex flex-col md:grid` with `gridTemplateColumns: "320px 1fr"`
- **Mobile panel navigation pattern:**
  - List panel: `className={selected ? "hidden md:block" : "block"}` — hides when detail is open
  - No-selection placeholder: `hidden md:flex` — never shown on mobile (list takes its place)
  - Detail panel: `block md:block` — shown when selected
  - Mobile-only "← Back to Departments" button inside detail panel (`md:hidden`)
- **Hero header actions** (`dept-hero-row` / `dept-hero-actions` CSS classes):
  - On mobile → `flex-direction: column`; Edit + Add Designation buttons stretch to full width
- **Designations grid:** `repeat(auto-fill, minmax(min(210px, 100%), 1fr))`
- **Back button added** to page header (was missing)

#### 3b. Roles & Permissions (`app/dashboard/settings/permissions/page.tsx`)
- Button order was already correct (Back → Add Role) ✓
- Tables already wrapped in `.table-wrap` with `overflow-x: auto` ✓

#### 3c. Email Templates (`app/dashboard/settings/email-templates/page.tsx`)
- Button order fixed: Back (ghost) → Add Template (filled)
- Cards grid: `grid grid-cols-1 sm:grid-cols-2` (was fixed 2-col inline style)
- **`EditTemplateModal.tsx`** — editor + tags sidebar layout:
  - Was: `gridTemplateColumns: "1fr 200px"` (gave editor only ~160px on iPhone SE)
  - Now: `.email-editor-grid` CSS class — switches to `flex flex-col` on mobile
  - Editor panel gets `.email-editor-left` class; Tags sidebar gets `.email-tags-sidebar` class (max 130px, scrollable on mobile)

#### 3d. SMTP Settings (`app/dashboard/settings/smtp/page.tsx`)
- Button order fixed: Back (ghost) → Add SMTP (filled)
- Cards grid: `grid grid-cols-1 lg:grid-cols-2`
- **`SmtpModal.tsx`** — form fields grid:
  - Was: `style={{ display: "grid", gridTemplateColumns: "1fr 1fr" }}` (2-col always, unoverrideable)
  - Now: `.smtp-form-grid` CSS class — collapses to single column on `≤768px`

---

### 4. CSS Classes Added to `app/globals.css`

| Class | Purpose |
|-------|---------|
| `.smtp-form-grid` | 2-col form grid (SMTP modal) → 1-col on mobile |
| `.email-editor-grid` | Side-by-side editor+tags → stacked column on mobile |
| `.email-editor-left` | Editor left panel — removes right border on mobile |
| `.email-tags-sidebar` | Tags right panel — max 130px scrollable on mobile |
| `.dept-hero-row` | Departments hero header row → column on mobile |
| `.dept-hero-actions` | Action buttons in hero → full-width stretch on mobile |

Responsive breakpoint for all new layout classes: `max-width: 768px` (inside existing `@media` block).

---

### Key Files Changed (25 June 2026)

| File | Change |
|------|--------|
| `lib/clientApi.ts` | Skip Bearer token for auth URLs in request interceptor |
| `app/login/page.tsx` | Mobile responsive — left panel hidden, form stacks vertically |
| `components/dashboard/DashboardShell.tsx` | Mobile sidebar overlay drawer, hamburger toggle, responsive padding |
| `app/globals.css` | New CSS classes + responsive overrides for modal grids and dept hero |
| `app/dashboard/settings/departments/page.tsx` | Two-panel mobile nav, hero action fix, Back button added, responsive grids |
| `app/dashboard/settings/permissions/page.tsx` | No changes needed (already correct) |
| `app/dashboard/settings/email-templates/page.tsx` | Button order fixed, cards grid responsive |
| `app/dashboard/settings/email-templates/_components/EditTemplateModal.tsx` | Editor+tags layout responsive (`email-editor-grid`) |
| `app/dashboard/settings/smtp/page.tsx` | Button order fixed, cards grid responsive |
| `app/dashboard/settings/smtp/_components/SmtpModal.tsx` | Form grid responsive (`smtp-form-grid`) |

---

## Surya — Backend + Settings Modules (24–25 June 2026)

### What I Built

#### 1. Company Information Module (full stack)

**Backend** (`backend/apps/accounts/`)
- `models.py` — Added `Company` model (singleton, `db_table = 'hrms_company'`): `company_name`, `trade_name`, `logo` (ImageField), `gstin`, `cin`, `pan`, `tan`, `address`, `city`, `state`, `pin_code`, `website`, `official_phone`, `updated_at`, `updated_by` FK
- `migrations/0013_add_company.py` — new migration; depends on `0012_add_department_designation`
- `serializers.py` — `CompanySerializer` with `logo_url` (absolute URL via `request.build_absolute_uri`), regex validators for GSTIN/CIN/PAN/TAN/PIN/phone
- `views.py` — `CompanyRetrieveUpdateView`: GET returns existing record or `{}`, PUT for hr_admin/system_admin, handles logo upload/replace/remove with `remove_logo=true` flag, `transaction.atomic()`, audit log on save
- `urls.py` — `path('settings/company/', CompanyRetrieveUpdateView.as_view(), name='company')`
- `requirements.txt` — added `Pillow==10.4.0` (required for ImageField)
- `config/urls.py` — added `static(MEDIA_URL, document_root=MEDIA_ROOT)` for DEBUG media serving

**Frontend** (`frontend/app/dashboard/settings/company/page.tsx`)
- 4-section form: Branding (logo preview 80×80 + upload/change/remove + company_name + trade_name), Legal & Statutory (GSTIN/CIN/PAN/TAN 2-col grid), Registered Address (textarea + 3-col: city/state-select/pin_code), Contact (website/phone 2-col)
- State dropdown: 28 states + 8 UTs hardcoded
- Client-side validation mirrors backend regex
- Logo upload uses FormData with `headers: { 'Content-Type': undefined }` (lets browser set multipart boundary — do not set it manually on axios)
- Logo removal sends `remove_logo=true` in FormData (can't send `null` via FormData reliably)

#### 2. Audit Log Module (full stack)

**Backend** — `AuditLog` model already existed. Added logging coverage to all admin write operations:

| Module | Actions logged |
|--------|---------------|
| `accounts` | departments (create/update/delete), designations (create/update/delete) |
| `branch` | branches (create/update/delete) |
| `company` | company info (updated) |

- `apps/accounts/views.py` — added `AuditLog.objects.create()` to Department + Designation views
- `apps/branch/views.py` — added `from apps.accounts.models import AuditLog`, local `_get_ip(request)` helper, audit create calls in BranchListCreateView + BranchDetailView
- `serializers.py` — `AuditLogSerializer` with `actor_name`, `actor_email`, `actor_role` as SerializerMethodFields
- `views.py` — `AuditLogListView`: GET only, `CanManageRoles`, filters by module/action/search (icontains on name+email)/date_from/date_to, Django `Paginator` 25/page (max 100), returns `{ count, page, page_size, total_pages, results }`
- `urls.py` — `path('settings/audit/', AuditLogListView.as_view(), name='audit-log-list')`

**Frontend** (`frontend/app/dashboard/settings/audit/page.tsx`)
- Filters: Module dropdown, date-range pickers (default last 30 days → today), actor search (submit on Enter or button)
- Table: Timestamp (date + time stacked), Actor (name + email + role badge), Module chip, Action badge, IP in `<code>`
- Action badge colors: `badge-success` (_created), `badge-error` (_deleted), `badge-warn` (_updated), `badge-info` (login/_activated), `badge-neutral` (logout), `badge-primary` (password*)
- Module chip colors: `badge-primary` (accounts), `badge-warn` (settings), `badge-info` (company), `badge-success` (branch)
- Pagination: Prev/Next + numbered pills (±2 from current page)
- Auto-fetch on module/date change; search only fires on submit

#### 3. Settings Page Routing Update

`frontend/app/dashboard/settings/page.tsx` — added to `ITEM_ROUTES`:
```ts
company: "/dashboard/settings/company",
audit:   "/dashboard/settings/audit",
```

#### 4. CORS + ALLOWED_HOSTS (backend only)

`backend/config/settings.py`:
```python
ALLOWED_HOSTS = env.list('ALLOWED_HOSTS', default=['*'])
CORS_ALLOWED_ORIGINS = ["http://localhost:3000"]   # list specific domains — never use CORS_ALLOW_ALL_ORIGINS = True
```
`backend/.env` — changed `ALLOWED_HOSTS` to `*`, removed the stale `CORS_ALLOWED_ORIGINS= "*"` line.

---

### API Endpoints Added

| Method | Endpoint | Used for |
|--------|----------|----------|
| `GET` | `/api/settings/company/` | Load company record (returns `{}` if none yet) |
| `PUT` | `/api/settings/company/` | Save/update company info (multipart/form-data for logo) |
| `GET` | `/api/settings/audit/` | Paginated audit log — params: `module`, `action`, `search`, `date_from`, `date_to`, `page`, `page_size` |

---

### Key Files Changed / Created

| File | What |
|------|------|
| `backend/apps/accounts/models.py` | Added `Company` model |
| `backend/apps/accounts/migrations/0013_add_company.py` | New migration |
| `backend/apps/accounts/serializers.py` | Added `CompanySerializer`, `AuditLogSerializer` |
| `backend/apps/accounts/views.py` | Added audit logging to dept/designation views, `CompanyRetrieveUpdateView`, `AuditLogListView` |
| `backend/apps/accounts/urls.py` | Added company + audit routes |
| `backend/apps/branch/views.py` | Added `AuditLog` import + audit logging to all branch write views |
| `backend/config/urls.py` | Added media file serving for DEBUG |
| `backend/config/settings.py` | `CORS_ALLOWED_ORIGINS = [...]` (specific domains only), `ALLOWED_HOSTS = env.list(...)` |
| `backend/requirements.txt` | Added `Pillow==10.4.0` |
| `frontend/app/dashboard/settings/company/page.tsx` | New — Company Info settings page |
| `frontend/app/dashboard/settings/audit/page.tsx` | New — Audit Log viewer |
| `frontend/app/dashboard/settings/page.tsx` | Updated — added company + audit routes |

---

### Notes for Next Developer

- **Company is a singleton** — one record ever. Views use `Company.objects.first()`, never `Company.objects.get(id=...)`. Never create a second record.
- **Logo field needs Pillow** — `pip install Pillow==10.4.0`. Without it Django throws `fields.E210` and won't start.
- **Logo FormData upload** — use `headers: { 'Content-Type': undefined }` in the axios request config (not `'multipart/form-data'`). Setting it manually breaks the multipart boundary.
- **Logo removal** — send `remove_logo=true` as a FormData string field. View handles deletion via `instance.logo.delete(save=False)` then `instance.save(update_fields=['logo'])`.
- **CORS pattern** — never use `CORS_ALLOW_ALL_ORIGINS = True` in any environment. Always use `CORS_ALLOWED_ORIGINS = ["http://localhost:3000", "https://yourdomain.com"]` with an explicit list of allowed origins. Setting `CORS_ALLOWED_ORIGINS = ['*']` is also invalid — django-cors-headers rejects the wildcard string at startup.
- **Audit workflow** — every new module that has admin write operations should get `AuditLog.objects.create()` calls. Notify Surya when a new backend module is added and audit coverage will be dropped in.
- **Cross-app AuditLog import in branch** — `from apps.accounts.models import AuditLog` in `apps/branch/views.py` is safe (no circular dependency — accounts doesn't import branch).

---

## Session 3 — Safura Samreen (25 June 2026)

**Branch:** `Frontend/Email-Document`
**Commits:** `8999189` · `e7bdcac` · `b4835df`

---

### 7. Email Templates — Bug Fixes & Enhancements

#### Bug fixes

**Attachments payload was empty (`attachments: {}` or `[{}, {}]`)**
- Root cause: Axios 1.x has an instance-level `Content-Type: application/json` header that prevents it from auto-detecting `FormData`, so it serialised files to empty objects instead.
- Fix 1 — `lib/clientApi.ts`: added request interceptor that deletes `Content-Type` when `config.data instanceof FormData`, letting the browser set `multipart/form-data` with the correct boundary.
- Fix 2 — `page.tsx`: removed the `buildPayload()` helper that branched between JSON and FormData. Both `handleCreate` and `handleUpdate` now always build `FormData` inline.

**`available_variables` sent as a nested JSON string**
- The list API returns it as `string | string[]` inconsistently.
- Fix: `parseAvailableVars(val)` added to `_data.ts` — handles both formats. Sent to backend as `JSON.stringify(array)` inside FormData.

**Existing attachments not shown when opening the edit modal**
- Cause: the list endpoint omits `attachments` for performance.
- Fix: `EditTemplateModal` fetches `GET /api/settings/email-templates/{id}/` on mount and sets `existingAttachments` state. Existing chips use solid blue border + paperclip icon; new pending files use dashed border + upload icon.
- Removed attachments are tracked in `removedAttachmentIds[]` and `DELETE`d via `Promise.allSettled` in `handleSave` before calling `onSave`.

**`display_name` required error when creating a category**
- Was only sending `{ name: slug }`. Fix: now sends `{ name: toSlug(displayName), display_name: displayName }`.

**Chevron arrow rendered outside the category input box**
- The inner wrapper div was missing `width: "100%"`. Added to both the wrapper `div` and the `input`.

#### New features

**Inline category creation in the combobox**
- When the typed text doesn't match any existing category, a "+ Create new category" option appears at the bottom of the dropdown.
- On click: `handleCreateCategory` POSTs `{ name, display_name }` to `EMAIL_TEMPLATE_CATEGORIES`, appends the new item to `categories[]`, and selects it.
- `catCreating` boolean shows a spinner during the POST.
- `onMouseDown → e.preventDefault()` on all dropdown options prevents blur before click registers.

**Full responsive layout**

*`page.tsx` (card list):*
- Card grid: 1 col (< 560 px) → 2 col (560–1099 px) → 3 col (≥ 1100 px)
- Toast: `left: 8px; right: 8px` on mobile (≤ 480 px)
- Search bar: full-width on mobile

*`EditTemplateModal.tsx` (editor modal):*
- **Mobile (≤ 640 px):** modal goes full-screen (`100vw × 100dvh`, `border-radius: 0`); a 3-tab bar appears — **Editor / Preview / Variables** — only the active column is visible.
- **Tablet (641–1023 px):** editor + sidebar (200 px); preview column hidden.
- **Desktop (≥ 1024 px):** original 3-column grid `1fr 1fr 180px` unchanged.
- CSS classes `et-modal-wrap`, `et-modal-grid`, `et-col-editor`, `et-col-preview`, `et-col-sidebar`, `et-tab-bar`, `et-tab-active` drive all breakpoint logic via `!important` overrides.

#### Files changed
| File | What |
|---|---|
| `lib/clientApi.ts` | Request interceptor: delete `Content-Type` when body is `FormData` |
| `settings/email-templates/_data.ts` | Added `ApiAttachment`, `emailTemplateAttachmentDetail()`, `parseAvailableVars()` |
| `settings/email-templates/page.tsx` | Always FormData; responsive CSS; 3-col grid |
| `settings/email-templates/_components/EditTemplateModal.tsx` | Existing attachments, inline category creation, chevron fix, mobile tabs, responsive CSS |

---

### 8. Document Center — New Page (`app/dashboard/documents/`)

Full page at route `/dashboard/documents` wired to the real backend API.

#### File structure
```
documents/
  _data.ts                  ← API endpoints, types, file-type meta, validation helpers
  page.tsx                  ← main page (stats, list, upload, delete, preview logic)
  _components/
    DocPreviewBody.tsx      ← in-app document renderer (PDF, images, DOCX, XLSX, TXT/CSV)
```

#### API endpoints used
| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/documents/stats/` | Live counts: total, by category |
| `GET` | `/api/documents/` | List — query params: `category`, `search` |
| `POST` | `/api/documents/` | Upload (`multipart/form-data`) |
| `DELETE` | `/api/documents/{id}/` | Soft delete |

#### Features
- **Stats row** — 4 live-count cards (Total Documents, Policies, Forms, Templates)
- **Filter tabs + debounced search** — pill tabs + search, both as server-side query params. Search debounced 400 ms.
- **Document grid** — `.doc-grid` / `.doc-tile` / `.doc-icon` CSS classes. Responsive: `auto-fill minmax(220px, 1fr)`.
- **Detail modal** — file preview banner, metadata rows, Delete · Close · Preview · Download.
- **Upload modal** — drag-and-drop zone, auto-fills name from filename, category select, description.
- **In-app preview** — PDF via blob URL → iframe; JPG/PNG → img; TXT/CSV → pre; DOCX → `docx-preview`; XLSX → SheetJS; PPT → download prompt.

#### Key bug fixes during build
- **PDF preview 401** — MinIO uses bucket-level ACL not JWT. Removed `Authorization` header from media fetches.
- **PDF downloading instead of previewing** — MinIO sets `Content-Disposition: attachment`. Fix: fetch as ArrayBuffer → Blob → `URL.createObjectURL()`.
- **File picker not showing PDFs on Windows** — `accept` now includes both MIME types and extensions.

#### New packages installed
| Package | Version | Purpose |
|---|---|---|
| `docx-preview` | `^0.3.7` | Client-side DOCX → HTML rendering |
| `xlsx` | `^0.18.5` | Client-side XLSX/XLS → HTML table rendering |

---

## Key Notes for Next Developer (Safura Session 3)

- **MinIO media files** — never send the Django JWT token to `file_url` (MinIO endpoint). Use plain `fetch(url)` without `Authorization` header.
- **Axios 1.x FormData bug** — the clientApi interceptor in `lib/clientApi.ts` now deletes `Content-Type` when body is `FormData`. This must stay or file uploads will break silently.
- **`available_variables`** — backend returns it as either `string[]` or a JSON-stringified string. Always use `parseAvailableVars()` from `_data.ts` when reading this field.
- **Email template list API** — omits `attachments` per template. Always fetch the detail endpoint `/settings/email-templates/{id}/` when you need attachments.

---

## Session 4 — Nithin Sandala (25 June 2026)

**Branch:** `Frontend/employee`
**Commit:** `05a101d`

### Employee Management Module

Developed full employee management screens wired to the backend API.

#### Files Created

| File | Purpose |
|------|---------|
| `app/dashboard/employees/page.tsx` | Employee list page — table with search/filter, status badges |
| `app/dashboard/employees/new/page.tsx` | Add Employee full-page wizard |
| `app/dashboard/employees/[id]/page.tsx` | Employee profile detail page |
| `app/dashboard/employees/_data.ts` | API endpoints, types, field definitions |
| `app/dashboard/employees/_components/AddEmployeeModal.tsx` | Modal variant of add-employee form |
| `app/dashboard/employees/_components/AddEmployeeWizard.tsx` | Multi-step wizard for employee creation |
| `app/dashboard/employees/_components/Avatar.tsx` | Avatar initials component |
| `app/dashboard/employees/_components/FormField.tsx` | Reusable labelled input/select/textarea |
| `app/dashboard/employees/_components/StatusBadge.tsx` | Active/inactive badge |
| `app/dashboard/employees/[id]/_components/ProfileForm.tsx` | Editable profile form |
| `app/dashboard/employees/[id]/_components/ProfileHeader.tsx` | Profile page header with avatar + meta |
| `app/dashboard/employees/[id]/_components/ProfileSidebar.tsx` | Sidebar quick-info panel |
| `app/dashboard/employees/[id]/_components/ProfileTabBar.tsx` | Tab navigation (Personal/Work/Documents) |

#### DashboardShell additions (`components/dashboard/DashboardShell.tsx`)

- Added `"/dashboard/employees/new": "Add New Employee"` to `PAGE_TITLES`
- Dynamic fallback: `pathname.startsWith("/dashboard/employees/")` → `"Employee Profile"`

---

## Session 5a — G.Durga Prasad (26 June 2026)

**Branch:** `Backend/Email-Document`

### 1. Recruitment Module — Interview List Page

Full interview list page at `/dashboard/interview-list` wired to the backend API. Page was refactored from a single 482-line file to a 245-line orchestrator + 3 extracted modal files.

#### File structure
```
interview-list/
  _data.ts                ← types, API helpers, format utilities
  page.tsx                ← orchestrator (245 lines): state, fetching, layout, table
  AddCandidateModal.tsx   ← add candidate form with branch selection
  MarkCandidateModal.tsx  ← select/reject modal with template picker + email preview
  LogsModal.tsx           ← candidate event log viewer
```

#### `_data.ts` types added / updated
- `Branch` interface: `{ id, branch_name, branch_code, status }`
- `Candidate` interface: added `branch: number | null`, `branch_name: string`
- `EmailTemplate` interface: added `is_active: boolean`
- `emailTemplates()` — moved from `API.recruitment.emailTemplates` to `API.settings.emailTemplates`; return type `Record<string, EmailTemplate[]>`
- `RECRUITMENT_API.list` params: added `branch?: number`

#### `page.tsx` features
- **Stats cards** — total / pending / selected / rejected from `/api/recruitment/stats/`
- **Branch filter dropdown** — building icon, "All Branches" default, shows `Branch Name (CODE)` options
- **Branch table column** — badge for each candidate's assigned branch
- **Dynamic subtitle** — changes to "Showing candidates for [Branch Name]" when a branch is selected
- **Dynamic empty state** — message changes based on active branch filter
- Branches fetched once on mount from `GET /api/branch/branches/?status=active&page_size=100`
- `fetchAll(q, s, b)` accepts optional branch param; called on search/status/branch change

### 2. `AddCandidateModal.tsx` — Required Branch Selection

- Required `Branch` dropdown fetched from `GET /api/branch/branches/?status=active&page_size=100` on mount
- Client-side validation: "Please select a branch." if no branch selected before submit
- Submits `branch: Number(form.branch)` with candidate payload

### 3. `MarkCandidateModal.tsx` — Template Picker + Email Preview

- Template dropdown pre-selects `selection` / `rejection` by default based on target status
- Fetches templates + company info in parallel via `Promise.all([emailTemplates(), companyInfo()])`
- Flattens grouped template response: `([] as EmailTemplate[]).concat(...Object.values(grouped)).filter(t => t.is_active)`
- Live email preview rendered in a 640 × 340 iframe using `buildEmailPreview` from `lib/emailPreview.ts`
- `previewVars()` replaces `{candidate_name}`, `{position}`, `{company_name}` in template body/subject
- Sends `template_name` slug with the `setStatus` PATCH call

### 4. `lib/emailPreview.ts` — NEW FILE

Shared utility for building branded email HTML previews in the browser — mirrors `_company_email_wrapper` in the backend.

```typescript
export function setAssessmentStatus(newStatus: string) {
  const user = getStoredUser();
  if (user) saveAuth({ ...user, assessment_status: newStatus });
}
```

---

## 3. API Endpoints

**File:** `lib/api/endpoints.ts`

Added under `assessments`:

| Key | URL | Method |
|-----|-----|--------|
| `my` | `/assessments/my/` | GET |
| `respond(assignmentId, itemId)` | `/assessments/<id>/respond/<itemId>/` | POST |
| `complete(assignmentId)` | `/assessments/<id>/complete/` | POST |
| `retake(assignmentId)` | `/assessments/<id>/retry/` | POST |
| `results(assessmentId)` | `/assessments/<id>/results/` | GET |
| `candidateResults(candidateId)` | `/assessments/candidates/<id>/results/` | GET |

> **Important:** The backend retry endpoint uses `retry` not `retake` in the URL path.

**Onboarding step fix:** Step 4 now posts to `/onboarding/` (the main profile endpoint) instead of `/onboarding/step/4/`. Steps 1–3 still use `profileStep(step)`.

```typescript
tab === 4 ? API.onboarding.profile : API.onboarding.profileStep(tab)
```

---

## 4. Candidate Assessments Page — Full Redesign

**File:** `app/onboarding/assessments/page.tsx`

Fully rebuilt into a **two-column exam portal layout**. No modals — everything is inline.

### Layout

```
┌─── Sidebar (280px) ─────┬──────── Main Content ────────────────┐
│  Assessment Portal      │  [Selected item renders here]        │
│  ─────────────────────  │                                      │
│  TEST 1          2/3    │  or                                  │
│  ─────────────────────  │                                      │
│  ✓ 1. Intro Video       │  "Select an item from the sidebar    │
│  ● 2. Policy Quiz  ←    │   to begin your assessment."         │
│  🔒 3. HR Quiz          │                                      │
│                         │                                      │
│  [Submit Assessment]    │                                      │
└─────────────────────────┴──────────────────────────────────────┘
```

### Sidebar
- Lists all assigned assessments as collapsible sections
- Each item shows: step circle (✓ done / 🔒 locked / number active), title, type badge
- Items lock until the previous one is completed (sequential)
- Mini progress bar + score per assessment section
- "Submit Assessment" button when all items answered
- "Retake Assessment" button when assessment failed
- Attempt history table (attempt #, score, date)

### Main Content States

| State | What renders |
|-------|-------------|
| Nothing selected | Landing — "Select an Item to Begin" prompt |
| Video selected (unwatched) | 16:9 iframe + "Mark as Watched" button |
| Video selected (watched) | iframe + "Already watched" banner + "Next Item →" |
| Quiz selected (unanswered) | Question card + A/B/C/D option rows + "Submit Answer" |
| Quiz selected (answered) | Result (correct/incorrect) + running score + "Next Item →" |

### YouTube Embed Conversion
HR saves share URLs; this function converts them to embeddable format for the iframe:
```typescript
function toEmbedUrl(url: string): string {
  // youtu.be/ID?si=...  → youtube.com/embed/ID
  // youtube.com/watch?v=ID → youtube.com/embed/ID
  // vimeo.com/ID → player.vimeo.com/video/ID
}
```

### Completion Flow
1. All items done → "Submit Assessment" button in sidebar
2. Click → `POST /assessments/<id>/complete/`
3. `CompletionModal` overlay appears with SVG circular score ring
4. **Pass:** "Go to Dashboard" → `router.push("/dashboard")`
5. **Fail:** "Re-take Assessment" ONLY — no dashboard option until passed
6. Retake → `POST /assessments/<id>/retry/` → clears state → refetch

### Cookie Unlock
```typescript
useEffect(() => {
  if (data?.all_complete) setAssessmentStatus("complete");
}, [data?.all_complete]);
```
Updates the `royal_hrms_user` cookie so the proxy stops redirecting once all assignments are passed.

### Key Types
```typescript
interface AssignmentItem {
  id, item_type, title, order, video_url, duration_secs,
  question, option_a, option_b, option_c, option_d,
  correct_option, pass_score, created_at
}

interface Assignment {
  id, assessment_title, status, score, max_score, passed,
  total_items, completed_items, attempt_number,
  items: AssignmentItem[],
  responses: ItemResponse[],
  attempts: AttemptRecord[]
}

interface RespondData {
  item_id, item_type, is_correct, score_awarded, assignment_score
}

interface AttemptRecord {
  attempt_number, score, max_score, passed, completed_at
}
```

---

## 5. HR Assessments Dashboard

**File:** `app/dashboard/assessments/page.tsx`

### Actual API Response Shape (`GET /assessments/`)
```json
{
  "data": {
    "results": [
      {
        "id": "e2339b03-...",
        "title": "TEST",
        "is_active": true,
        "is_default": true,
        "item_count": 2,
        "assigned_count": 2,
        "pending_count": 0,
        "in_progress_count": 0,
        "completed_count": 2,
        "candidates": [
          {
            "id": "...",
            "candidate_id": 24,
            "candidate_name": "Shashi",
            "candidate_email": "...",
            "status": "complete",
            "attempt_count": 1,
            "pass_score": 10,
            "score_awarded": 10,
            "pass_percentage": "100%",
            "completed_at": "2026-07-02T17:10:06...",
            "created_at": "2026-07-02T16:46:30..."
          }
        ],
        "items": [...]
      }
    ]
  }
}
```

> Candidate data is **embedded in the list response** — no separate results API call is needed.

### Page Layout

**Header area — Overall stats (aggregated across all assessments):**
4 stat cards: Total Assigned / Pending / In Progress / Completed

**Each assessment card (collapsed):**
- Title + Active/Default badges
- Action buttons: Results (toggle) | Items | Assign | Edit | Delete
- No extra padding when collapsed

**Each assessment card (expanded via Results button):**
- 5 stat tiles: Items / Assigned / Pending / In Progress / Completed
- Candidate results table:

  | Column | Source field |
  |--------|-------------|
  | Candidate | `candidate_name` + `candidate_email` |
  | Status | `status` (badge) |
  | Score | `score_awarded / pass_score` |
  | Pass % | `pass_percentage` |
  | Attempts | `attempt_count` |
  | Assigned | `created_at` |
  | Completed | `completed_at` |

### Types Added to `Assessment`
```typescript
interface AssessmentCandidate {
  id: string;
  candidate_id: number;
  candidate_name: string;
  candidate_email: string;
  status: "pending" | "in_progress" | "complete";
  attempt_count: number;
  pass_score: number;
  score_awarded: number;
  pass_percentage: string;
  completed_at: string | null;
  created_at: string;
}

// Assessment interface additions:
assigned_count: number;
pending_count: number;
in_progress_count: number;
completed_count: number;
candidates: AssessmentCandidate[];
```

### Removed
- `AssessmentResultsModal` component — no longer needed since data is embedded in list
- Separate `GET /assessments/<id>/results/` call — redundant

---

## 6. Proxy Behaviour (unchanged — documented for reference)

**File:** `proxy.ts`

```
if assessment_status === "pending" && path !== /onboarding/assessments
  → redirect to /onboarding/assessments
```

Reads from the signed `royal_hrms_user` cookie (httpOnly). After all assessments pass, `setAssessmentStatus("complete")` updates the cookie client-side and the redirect stops on the next navigation.

---

## Rules Followed

| File | Change |
|------|--------|
| `backend/apps/hrms/models.py` | Added `expense_number` PositiveIntegerField (unique, nullable, db_index) |
| `backend/apps/hrms/migrations/0006_expense_number.py` | **NEW** — schema migration |
| `backend/apps/hrms/migrations/0007_backfill_expense_number.py` | **NEW** — data migration (backfill) |
| `backend/apps/hrms/serializers.py` | Added `expense_ref` SerializerMethodField; replaced `id` → `expense_number` in `Meta.fields` |
| `backend/apps/hrms/views/expenses.py` | Full rewrite: added `ExpenseCategoryListView`, `ExpenseStatusListView`; full CRUD on `ExpenseDetailView`; `_handle_approval()` merged into PUT/PATCH; removed `ExpenseApprovalView`; `_get_expense` uses `expense_number`; `_fresh()` and `_validate_receipts()` helpers |
| `backend/apps/hrms/views/__init__.py` | Updated exports — `ExpenseCategoryListView`, `ExpenseStatusListView` added; `ExpenseApprovalView` removed |
| `backend/apps/hrms/urls.py` | Added `expenses/categories/`, `expenses/status/`; detail URL changed to `<int:expense_number>/`; removed `expenses/<str:expense_id>/approve/` |
| `backend/apps/accounts/views.py` | Logger fixed to `__name__`; inline stdlib imports moved to top; `PermissionListView` paginated; `_ensure_default_rules()` rewritten to 1 SELECT + bulk_create; redundant inline imports removed |

---

### Notes for Next Developer (01 July 2026)

- **All expense URLs use `expense_number` (integer), not UUID** — e.g. `/api/expenses/1/`. The UUID (`id`) is the database primary key and is still used internally by `_fresh()` for re-fetch after save, but it is not in the API response and not in the URL.
- **Approval = PUT/PATCH with `status` field** — sending `{ "status": "approved" }` or `{ "status": "rejected" }` on any PUT/PATCH triggers `_handle_approval()`. Any other PUT/PATCH (without `status` key) is treated as an edit.
- **PUT replaces all receipts; PATCH appends** — if you send files on a PUT, all old receipts are deleted first. If you send files on a PATCH, new receipts are added to existing ones.
- **Single receipt delete** — `DELETE /api/expenses/<number>/?receipt_id=<uuid>`. The `receipt_id` is the UUID of the `ExpenseReceipt` record (still UUID — only the expense URL uses integer).
- **`expense_number` is race-condition-safe** — `select_for_update()` + `transaction.atomic()` in `post()`. Never assign `expense_number` manually outside this block.
- **`_ensure_default_rules()` now runs 0 DB writes on every GET** — only 1 SELECT. `bulk_create` fires only once when rules are genuinely missing. No performance concern on repeated calls.
- **Backfill is idempotent** — migration 0007 only touches rows where `expense_number IS NULL`. Re-running it is safe.

---

## Session 15 — Rithwika (02 July 2026)

**Branch:** `frontend/02-07`

---

### 1. HR Attendance Management — Full Frontend Build-out (`app/dashboard/attendance/`)

Wired the entire HR Attendance page (previously a static mock screen) to the real backend across 9 endpoints.

#### `lib/api/endpoints.ts` — new `attendance` keys
```
dashboard, records, record(id), overtime, overtimeCreate,
invalidPunches, unPunches, import, export, corrections, correctionReview(id)
```
Paths omit the `/api` prefix — `API_BASE` (`lib/config.ts`) already supplies it as the axios `baseURL`.

#### `types/attendance.ts` — new types
`StatCards`, `SummaryChips`, `TabBadges`, `DashboardData`, `AttendanceRow`, `PaginatedResponse<T>` (generic, reused for all 4 paginated lists), `AttendanceDetailPunch`, `AttendanceDetail`, `OvertimeRow`, `OvertimeCreatePayload`, `InvalidPunch`, `UnpunchRow`, `ImportResult`/`ImportRowError`, `CorrectionRow`, `CorrectionStatus`, `CorrectionReviewAction`.

> **Naming collision:** the backend's punch shape for the detail drawer is also called `PunchEntry` in the spec I was given, but that name already exists in this file for the live clock-in/out session (`type/location/attendance_mode/is_inside_geofence/calculated_distance` — a completely different shape). Renamed the new one to `AttendanceDetailPunch` with a comment explaining why.

#### `app/dashboard/attendance/page.tsx`
- Top 4 stat cards + tab badge counts wired to `GET /attendance/dashboard/`.
- Tab bar: **Attendance · OT Entry · Invalid Punches · Un-punches** (kept to exactly these 4 — see §4 and §5 below for how Corrections fits in).

#### `AttendanceTab.tsx`
- Real branch/department dropdowns, paginated records table from `GET /attendance/records/`, summary chips from the dashboard endpoint (called a second time with the tab's own filters), Prev/Next pagination.
- **View** button opens `AttendanceDetailDrawer` (see §2) — disabled when `record_id` is `null` (absent employees have no record).
- **Export CSV** — blob download via `clientApi.get(url, { responseType: "blob" })`.
- **Import** — real multipart upload wired in `ImportModal.tsx`; shows a result summary with a collapsible per-row error table before closing.

#### `OtEntryTab.tsx`
- Add OT Entry form posts to `POST /attendance/overtime/create/`; employee/approver dropdowns sourced from `/employees/` and `/employees/hrs/`.
- OT Records table from `GET /attendance/overtime/`.

---

### 2. Attendance Detail Drawer — Comprehensive View (`AttendanceDetailDrawer.tsx`)

The "View" button on the Attendance List originally opened a small centered modal with just clock in/out + a punch timeline. Rebuilt into a full side drawer covering everything HR needs to investigate a day's attendance without leaving the page:

- Switched markup from `.modal-overlay`/`.modal` to the app's existing `.drawer-overlay`/`.drawer` pattern (already used in `candidate-review/OnboardingQueueTab.tsx`, just not reused elsewhere yet).
- **Attendance Calculation** section — clock in/out, total hours, **and overtime** (was fetched but never rendered before).
- **Punch History & Location** — geofence status icon (✓ / ✗ / dashed) + distance-from-geofence per punch, source, mode.
- **Correction Requests** (new) — fetches `GET /attendance/corrections/?employee_id=&date=`, filtered client-side as a safety net in case the backend ignores the query params. Pending requests get inline Approve/Reject buttons (`PATCH /attendance/corrections/<id>/review/`) so HR can resolve a correction without switching tabs.
- **Audit Log** — deliberately left as a labeled "not available yet" placeholder. There is no record-scoped audit endpoint anywhere in the API (the only audit endpoint, `/settings/audit/`, is a global log filtered by module/date/search text, not scopable to one attendance record). Faking that connection would show misleading data — flagged this instead of guessing.

---

### 3. Branch Geofencing (`BranchManagement.tsx`, `useClockWidget.ts`, `ClockWidget.tsx`)

Two rounds of spec came in for this; the second superseded some of the first (documented below so nobody re-does the first version).

#### Branch form (`app/dashboard/branches/_components/BranchManagement.tsx`)
- Added `geofencing_enabled` (toggle switch — built a small self-contained one with inline styles since **no toggle-switch CSS exists anywhere in this codebase**, only checkboxes), `latitude`, `longitude`, `allowed_radius_meters` (min 10 / max 5000, default 150), all shown only when the toggle is on.
- Validation matches exact copy requested: both lat/lon empty → *"Latitude and longitude are required to enable geofencing."*; only one filled → *"Both latitude and longitude must be provided together."*
- Save call switched from `PUT` to **`PATCH`** on branch update, per explicit instruction.
- Badge on each branch card ("Geofencing" row, reused the existing Employees/Status info strip): green **Active** / yellow **No Coordinates** / grey **Disabled**, using the backend's own `has_coordinates` read-only field rather than a client-side null check.
- **No separate branch detail page exists in this app** — branches are cards with one edit modal, no `/dashboard/branches/[id]` route. The "detail row" requirement (radius + coordinates text) was added to the same card rather than inventing a new page.

#### Punch flow — root-cause fix for the geofencing bypass bug
The reported symptom: an employee physically in Mumbai could clock in as if they were at the Hyderabad branch and it would succeed. Root cause found in `hooks/useClockWidget.ts`: the geolocation error handler only handled `GeolocationPositionError.code === 1` (permission denied) — any *other* failure (timeout, position unavailable) fell through silently and the punch request went out with `latitude`/`longitude` = `null`. If the backend only enforces the geofence check when coordinates are present, that null-coordinate path is exactly how a mismatched-location clock-in slips through.

Fixed:
- Unsupported browser and permission-denied now both **block the request** with exact-wording toasts (final wording: *"Your browser does not support location access."* / *"Location access is required for office clock-in. Please allow location in your browser settings."*).
- Any other geolocation error (timeout/unavailable) **also now blocks** instead of silently continuing with null coordinates — this is the actual fix, not explicitly requested in either spec revision but left unguarded would reopen the same hole.
- Added `isLocating` state → "Getting location…" shown on the Clock In/Out button while GPS resolves.

---

### 4. Attendance Corrections Workflow

Built as its own "Corrections" tab first, then merged into "Un-punches" per direct instruction — final tab bar stayed at exactly 4 tabs (Attendance · OT Entry · Invalid Punches · Un-punches).

- **`CorrectionsTab.tsx`** (new) — branch/department/status filters (status defaults to `pending`), full table (Employee ID · Name · Department · Branch · Date · Punch Type · Requested In · Requested Out · Reason · Status · Actions). Pending rows get Approve/Reject (`PATCH /attendance/corrections/<id>/review/`); approved/rejected rows show `reviewed_by`/`reviewed_at` instead.
- **`UnpunchesTab.tsx`** — the original missing-clock-out table (with its own per-row `correction_pending` badge + inline approve/reject) was later removed entirely per instruction; the tab now renders only `<CorrectionsTab />`. `AddPunchModal.tsx` was deleted since it had no other caller once that table was removed.
- `UnpunchRow` type carries the new `correction_pending`/`correction_id` fields.

---

### 5. Invalid Punches — Put on Hold

No resolution/fix endpoint exists for invalid punches (only the `GET` list). Rather than ship a "Fix" button that does nothing, `InvalidPunchesTab.tsx` now renders a "Coming Soon" empty-state (reusing the existing `.empty-state` class). The original table/fetch logic is commented out in place, not deleted, so it's a one-step revert once a resolve endpoint exists.

---

### 6. Branch-Scoped Access Control for `hr_admin`

Backend now enforces branch scoping server-side (`hr_admin` always gets their own branch's data regardless of `?branch=`) — this made the UI need to stay honest about it (locked dropdown, not a silently-ignored "All Branches" option).

> **Adapted the given helper to this app's real user shape.** The spec's `isUnrestrictedUser` checked `user.is_superuser === true || user.role?.name === 'system_admin'`, but this codebase's `UserInfo` (`lib/auth.ts`) has `role` as a **flat string**, not a nested object, and has **no `is_superuser` field at all** anywhere in the frontend. Implemented against the real shape: `user?.role === "system_admin"`. Copying the spec verbatim would have made the check permanently `false`.

- **`lib/auth.ts`** — added `isUnrestrictedUser(user)` / `getEffectiveBranch(user)`.
- **`hooks/useCurrentUser.ts`** (new) — wraps `getStoredUser()` in `useEffect`; this repo already has a documented hydration-mismatch gotcha for calling `getStoredUser()` at render time (see the Session 2 notes above), so this hook exists specifically to not reintroduce that bug in five new places.
- **`components/BranchFilterSelect.tsx`** (new, shared) — full dropdown for `system_admin`; single disabled option + lock icon/tooltip ("Scoped to your branch") for `hr_admin`. Used in Attendance List, OT List, Corrections.
- **`hooks/useDepartmentOptions.ts`** (new, shared) — `system_admin` gets the global `/departments/` list; `hr_admin` gets department names derived from `GET /employees/?branch=<branch>` instead, since departments aren't branch-scoped as master data.
- **Page-level (`page.tsx`)** — dashboard fetch gated on the user object having resolved (never fires unscoped before we know who's asking); light-blue info chip "🏢 Viewing data for `<branch>` only" below the header for `hr_admin` only; page title appends `— <branch>`.
- **Export filename** — `attendance_Mumbai-HQ_2026-07-02.csv` for `hr_admin` (branch name space→hyphen), unchanged `attendance_2026-07-02.csv` for `system_admin`.
- **OT List had no filter UI at all before this** — added a branch filter to it since it was explicitly named as an affected page.

---

### 7. My Attendance — Punch Log Simplified (`ClockWidget.tsx`)

The Punch Log was rendering every punch of the day (could be 8+ rows after a few correction/duplicate punches). Changed to show only the two most relevant rows:
```tsx
const latestIn  = [...punches].reverse().find(p => p.type === "IN")
const latestOut = [...punches].reverse().find(p => p.type === "OUT")
const displayPunches = [latestIn, latestOut].filter(Boolean)
```
Order is always IN then OUT (fixed by array position, not sorted by time).

---

### 8. Production Build Fix — `LeaveDashboard.tsx` TypeScript Error

`npm run build` was failing type-check (unrelated to any of the attendance work above — pre-existing, just never surfaced until a full build was run):

```
./app/dashboard/leave/_components/LeaveDashboard.tsx:53:7
Type error: 'requests' is possibly 'null'.
  51 |   const visibleRequests = selectedBranches.length === 0
  52 |     ? requests
> 53 |     : requests.filter(r => selectedBranches.includes(r.employee_branch));
```

`requests` comes from `useFetch<LeaveRequest[]>(...)`, typed `LeaveRequest[] | null`. Every other read of `requests` in this file already guards with `requests ?? []` — this one ternary didn't. Minimal fix, matching the existing pattern in the same file:

```tsx
const visibleRequests = selectedBranches.length === 0
  ? (requests ?? [])
  : (requests ?? []).filter(r => selectedBranches.includes(r.employee_branch));
```

Confirmed with a full `tsc --noEmit` afterward — this was the only remaining type error in the whole project.

---

### Key Files Changed / Created (02 July 2026)

| File | Change |
|------|--------|
| `lib/api/endpoints.ts` | Added `attendance.{dashboard,records,record,overtime,overtimeCreate,invalidPunches,unPunches,import,export,corrections,correctionReview}` |
| `types/attendance.ts` | Added all HR-management types listed in §1; `AttendanceDetailPunch` (renamed to avoid collision); `CorrectionRow`/`CorrectionStatus`/`CorrectionReviewAction`; `correction_pending`/`correction_id` added to `UnpunchRow` |
| `app/dashboard/attendance/page.tsx` | Real dashboard fetch, branch-scoping (banner, title suffix, gated fetch), tab badges |
| `app/dashboard/attendance/_components/AttendanceTab.tsx` | Full rewrite — real records/summary/export/import, locked branch filter, scoped departments |
| `app/dashboard/attendance/_components/AttendanceDetailDrawer.tsx` | **NEW** — side drawer (calculation, punch/location, corrections, audit placeholder) |
| `app/dashboard/attendance/_components/OtEntryTab.tsx` | Real OT list + create; added branch filter (previously had none) |
| `app/dashboard/attendance/_components/CorrectionsTab.tsx` | **NEW** — corrections table, branch/department/status filters, approve/reject |
| `app/dashboard/attendance/_components/UnpunchesTab.tsx` | Old missing-clock-out table removed; now renders `<CorrectionsTab />` only |
| `app/dashboard/attendance/_components/InvalidPunchesTab.tsx` | Table/fetch commented out; "Coming Soon" empty-state shown instead |
| `app/dashboard/attendance/_components/ImportModal.tsx` | Real multipart upload + result summary with collapsible row errors |
| `app/dashboard/attendance/_components/AddPunchModal.tsx` | **DELETED** — no longer referenced after the Un-punches table was removed |
| `app/dashboard/branches/_components/BranchManagement.tsx` | Geofencing fields (toggle, lat/lon, radius), validation, `PATCH` on save, `has_coordinates`-based badge, radius/coordinates detail text on card |
| `hooks/useClockWidget.ts` | Geolocation error handling fixed to block on *any* failure (root cause of the cross-branch clock-in bug), `isLocating` state added |
| `app/dashboard/my-attendance/_components/ClockWidget.tsx` | "Getting location…" button state; Punch Log now shows only latest IN/latest OUT |
| `lib/auth.ts` | Added `isUnrestrictedUser`, `getEffectiveBranch` |
| `hooks/useCurrentUser.ts` | **NEW** — hydration-safe `getStoredUser()` wrapper |
| `hooks/useDepartmentOptions.ts` | **NEW** — branch-scoped department options for `hr_admin` |
| `components/BranchFilterSelect.tsx` | **NEW** — shared locked/unlocked branch dropdown |
| `app/dashboard/leave/_components/LeaveDashboard.tsx` | Build fix — `visibleRequests` ternary now guards `requests` with `?? []` on both branches (was only guarded in the rest of the file) |

---

### Notes for Next Developer

- **Invalid Punches is intentionally disabled** — see §5. Don't re-enable the commented-out table without a resolve/fix endpoint (`assign` / `convert_to_out` / `discard` — none of these exist yet).
- **Audit Log in the detail drawer is a placeholder** — needs a record-scoped endpoint, e.g. `GET /attendance/records/<id>/audit/`, before it can be wired for real.
- **`isUnrestrictedUser` checks `role === "system_admin"` as a flat string** — if the backend ever changes `UserInfo.role` to a nested object, this helper (and every other `user?.role === "..."` check across the app — `employees/page.tsx`, `announcements/page.tsx`, `ApprovalMatrixTab.tsx`) needs updating together, not just this one.
- **`useDepartmentOptions` assumes `/employees/?branch=<name>` filtering works** — it's the same convention already used by `/employees/hrs/?branch=`, but hasn't been independently verified against `/employees/` specifically.
- **Toggle switch in `BranchManagement.tsx` is a one-off inline component**, not a shared one — if a second toggle is needed anywhere else, promote it to `components/ToggleSwitch.tsx` instead of copy-pasting.
- **OT List and Corrections branch filters are net-new UI** (those tabs had zero filters before today) — worth a design pass if the team wants them visually consistent with the Attendance List's filter bar layout.
- **`npm run build` type-checks clean as of this session** — if it fails again, run `npx tsc --noEmit` first to isolate whether it's a new regression or another pre-existing `?? []` guard gap like §8.

---

- No backend changes in this entire branch
- All API paths from `lib/api/endpoints.ts` — no inline strings
- All data fetching via `useFetch` hook
- `clientApi` used with `withCredentials: true`
- No `localStorage` for tokens
- No `any` types — all shapes explicitly typed
