# Team Context

**Name:** Safura Samreen
**Last Updated:** 24 June 2026 (Session 2)

I worked on the **Royal HRMS** frontend — a Next.js 16 (App Router) HR management system. Below is everything built in this session.

---

## Tech Stack

- **Framework:** Next.js 16.2.9 with App Router and Turbopack
- **Styling:** Tailwind CSS v2.2.19 (JIT mode) + custom CSS design system (Sahara theme)
- **Icons:** Tabler Icons webfont via CDN (`ti-*` classes)
- **HTTP:** Axios via `clientApi` (`lib/clientApi.ts`) — attaches Bearer token from localStorage automatically
- **Auth:** JWT stored in localStorage + user info in a cookie (`USER_COOKIE`)
- **Backend base URL:** `http://localhost:8000/api`

---

## What I Built

### 1. Dashboard Shell — Sidebar + Navbar (`components/dashboard/DashboardShell.tsx`)

- Sidebar with collapsible width (220 px → 56 px), logo, nav items with section labels, user card at the bottom
- **Permission-based navigation** (industry standard) — sidebar items are driven entirely by `user.permissions[]` returned at login. No role-to-nav mapping, no extra API calls after login.
- `lib/navConfig.ts` has a single master nav list; each item declares the permission string it needs (e.g. `"settings.view"`). `buildNav(permissions[])` filters it at render time.
- Top navbar: page title (derived from current path), search bar, dark mode toggle, notifications bell with unread dot, logout button
- Session passed as a prop from the server layout (`app/dashboard/layout.tsx`)

### 2. Settings Page (`app/dashboard/settings/page.tsx`)

- Settings landing page with category pills and card tiles
- "Roles & Permissions" card navigates to `/dashboard/settings/permissions`

### 3. Roles & Permissions Page (`app/dashboard/settings/permissions/`)

Full CRUD page wired to real API endpoints.

#### File structure (industry standard):
```
permissions/
  _data.ts                          ← types, helpers, preset definitions
  page.tsx                          ← orchestrator, all API calls live here
  _components/
    RoleFormFields.tsx              ← shared form body (used by both modals)
    AddRoleModal.tsx                ← POST /api/roles/
    EditRoleModal.tsx               ← PUT /api/roles/{id}/
```

#### Features:
- **Roles table** — shows display name, slug (read-only code tag), permission count, user count, action buttons
- **Add Role** — modal with role name + permission tree → `POST /api/roles/`
- **Edit Role** — pre-populated modal, slug shown as locked field → `PUT /api/roles/{id}/` (name and is_active preserved, only display_name and permissions editable)
- **Active/Inactive toggle** — icon button with CSS tooltip → `PATCH /api/roles/{id}/` with `{ is_active: bool }`, spinner shown during request
- **Permission Matrix** — rows = API modules, columns = roles; cells show "Full (N)" badge / individual action badges / "—"
- **Loading state** with spinner, error state with retry button

#### Quick Permission Presets (in both Add and Edit modals):
Four one-click preset chips that pre-fill the permission tree:

| Preset | Selects |
|--------|---------|
| Full Admin | All 46 permissions |
| View Only | Every `*.view` codename |
| Manager | View/approve across employees, attendance, leave, expenses, documents, recruitment, reports |
| Employee | Self-service view/create on leave, attendance, payroll, expenses, documents, announcements, referrals |

Active preset is detected live — chip highlights when current selection exactly matches it, un-highlights the moment any checkbox is manually changed. A counter below shows `X of 46 permissions selected`.

#### Module accordion tree:
- Per-module collapsible rows with indeterminate checkbox state (partial selection)
- Per-action checkboxes (view, create, edit, delete, export, approve)
- Module-level count badge (`3/6`) turns primary-colour when anything is selected

### 4. Role-Based Dashboard (`app/dashboard/page.tsx` + `_components/`)

Server component reads the session role and renders the matching layout:

| Role | Dashboard |
|------|-----------|
| `hr_admin` | Greeting banner, Quick Actions, HR Action Queue, Today's Birthdays, Work Anniversaries, Recruitment Funnel, CSS Donut dept chart, Live Activity timeline |
| `system_admin` | Dark blue banner, Quick Actions, Module Health grid (operational/warn indicators), Dept headcount, Recent System Events, Active Sessions |
| `manager` | Green banner, Quick Actions, Pending Approvals (approve/reject buttons), Team Attendance Today, Upcoming Leaves |
| `employee` | Personal banner, Quick Actions, Attendance stats, Leave Balance progress bars, My Requests, Upcoming Events |

All dashboard views use static/mock data matching the HTML reference design (`royal-hrms-1.html`).

### 5. SMTP Settings (`app/dashboard/settings/smtp/`)

Full CRUD page for managing outgoing mail server configurations, wired to the real REST API.

#### File structure:
```
smtp/
  _data.ts                    ← types, converters, validation, endpoint helpers
  page.tsx                    ← dynamic card list, all API calls live here
  _components/
    SmtpModal.tsx             ← Add / Edit modal
```

#### Features:
- **Dynamic card grid** (2 per row) — one card per saved SMTP config, active config highlighted with a primary border
- **Add SMTP** — modal with Configuration Name (required, free-text label), host, port, TLS toggle, sender name, from email, username, password, BCC, priority, receiver email type
- **Edit** — same modal pre-populated; password field shows "leave blank to keep current"
- **Set Active** — `POST /api/settings/smtp/{id}/activate/` (no body), instantly marks card as active
- **Delete** — `DELETE /api/settings/smtp/{id}/` with confirmation dialog
- **Test Email** — modal asks for recipient + SMTP password (required by API), then `POST /api/settings/smtp/test/` with full config fields + `test_recipient`
- Active banner at top of page shows currently active config name + from_email

#### API shape (actual):
The `GET /api/settings/smtp/` response returns `data` as a **flat array** — each entry has a `name` field that is a user-defined label (e.g. "Gmail SMTP"), **not** "local"/"server". `is_active: true` marks the currently active one.

---

### 6. Email Templates (`app/dashboard/settings/email-templates/`)

Full CRUD page for transactional email templates, grouped by type, with a WYSIWYG editor.

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
CORS_ALLOW_ALL_ORIGINS = True   # NOT CORS_ALLOWED_ORIGINS = ['*'] — that breaks django-cors-headers
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
| `backend/config/settings.py` | `CORS_ALLOW_ALL_ORIGINS = True`, `ALLOWED_HOSTS = env.list(...)` |
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
- **CORS pattern** — use `CORS_ALLOW_ALL_ORIGINS = True` in settings.py. Never set `CORS_ALLOWED_ORIGINS = ['*']` — the wildcard string is rejected by django-cors-headers at startup.
- **Audit workflow** — every new module that has admin write operations should get `AuditLog.objects.create()` calls. Notify Surya when a new backend module is added and audit coverage will be dropped in.
- **Cross-app AuditLog import in branch** — `from apps.accounts.models import AuditLog` in `apps/branch/views.py` is safe (no circular dependency — accounts doesn't import branch).
