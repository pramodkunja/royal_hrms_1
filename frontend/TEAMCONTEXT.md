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

### 1. Dashboard Shell — Sidebar + Navbar (`components/dashboard/DashboardShell.tsx`)ZZZZZZZZZ

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
export interface CompanyInfo {
  company_name: string; logo: string; logo_url: string;
  website: string; official_phone: string;
  address: string; city: string; state: string;
}
export function renderTemplateVars(text: string, vars: Record<string, string>): string
export function buildEmailPreview(body: string, company: CompanyInfo | null): string
// Header: logo only (falls back to company name text if no logo); Footer: website | city, state
```

Used by both `MarkCandidateModal` (interview list) and `HRDecisionModal` (candidate review).

### 5. `HRDecisionModal.tsx` — Company Branding Added

- Added `company: CompanyInfo | null` state
- Fetches company info in parallel with templates via `Promise.all`
- Replaced inline `renderPreview` with `buildEmailPreview(body, company)` from `lib/emailPreview.ts`
- iframe height 340px, modal maxWidth 700px

### 6. `lib/api/endpoints.ts` — emailTemplates moved

`emailTemplates` endpoint moved from `API.recruitment` to `API.settings`:
```typescript
settings: {
  audit:          "/settings/audit/",
  company:        "/settings/company/",
  emailTemplates: "/settings/email-templates/",   // ← moved here
},
// API.recruitment.emailTemplates removed
```

**Why:** Accounts app owns the `EmailTemplate` model and its CRUD endpoint. Recruitment app was maintaining a duplicate read endpoint. Single source of truth — all consumers now use `API.settings.emailTemplates`.

### Key Files Changed / Created

| File | Change |
|------|--------|
| `lib/api/endpoints.ts` | `emailTemplates` moved from `recruitment` to `settings` |
| `lib/emailPreview.ts` | **NEW** — `buildEmailPreview`, `renderTemplateVars`, `CompanyInfo` |
| `app/dashboard/interview-list/_data.ts` | Added `Branch`, `is_active` on `EmailTemplate`, branch list param, `emailTemplates` → `API.settings` |
| `app/dashboard/interview-list/page.tsx` | Refactored 482 → 245 lines; branch filter dropdown; branch table column; dynamic subtitle/empty state |
| `app/dashboard/interview-list/AddCandidateModal.tsx` | **NEW** (extracted) — branch required dropdown, validation, submit |
| `app/dashboard/interview-list/MarkCandidateModal.tsx` | **NEW** (extracted) — template picker, live preview iframe, `buildEmailPreview` |
| `app/dashboard/interview-list/LogsModal.tsx` | **NEW** (extracted) — no logic changes |
| `app/dashboard/candidate-review/HRDecisionModal.tsx` | Company info fetch, `buildEmailPreview` from shared utility |

### Notes for Next Developer

- **Email preview and actual sent emails must stay in sync** — when editing the branding in `_company_email_wrapper` (`backend/apps/accounts/utils.py`), mirror the same change in `buildEmailPreview` (`frontend/lib/emailPreview.ts`).
- **Template slugs matter** — `MarkCandidateModal` pre-selects `selection` / `rejection`. These slugs must exist in `EmailTemplate` DB records with `is_active=True`. If you add new default slugs, update the modal default.
- **Branch filter uses `page_size=100`** — assumes no company will have more than 100 active branches. Increase if needed.
- **`emailTemplates()` returns grouped data** — `Record<string, EmailTemplate[]>`. Always flatten before use: `([] as EmailTemplate[]).concat(...Object.values(grouped)).filter(t => t.is_active)`.
- **API.recruitment.emailTemplates is gone** — any code referencing it will break; use `API.settings.emailTemplates` instead.

---

## Session 5b — Rithwika (26 June 2026)

**Branch:** `Frontend/responsiveness`

---

### 1. Login Page — Full Redesign & CSS Migration (`app/login/page.tsx`)

Rewrote the login page from scratch to match the reference design and fix a critical mobile bug.

**Bug fixed — Sign In button invisible on iPhone SE (375×667)**
- Root cause: `justify-content: center` on a flex container with `overflow: hidden` clips overflowing bottom content. On small viewports the Sign In button was below the fold and inaccessible.
- Fix: switched mobile layout to `justify-content: flex-start` with `padding-top` on the inner wrapper, allowing natural scroll without clipping.

**Design implemented (reference image):**
- Crown icon (`👑`) in a soft navy box
- "Welcome back" heading + subtitle
- Email field, Password field with eye toggle
- Password label row — label left, "Forgot password?" right
- Full-width dark navy Sign In button
- Footer text

**Two-column desktop / single-column mobile layout:**
- Desktop: CSS grid `1.2fr 1fr` — decorative image left, form right
- Mobile (`≤ 768px`): image panel hidden, form takes full screen with natural scroll (`min-height: 100svh`)

**Inline CSS eliminated:** Every `style={{}}` object replaced with a named CSS class in `globals.css`. Zero inline styles remain in `page.tsx`.

---

### 2. ForgotPasswordForm — Full Rewrite (`components/auth/ForgotPasswordForm.tsx`)

Replaced Tailwind arbitrary-value const strings with guaranteed CSS classes.

**Problem:** `inputCls` and `submitCls` const strings contained arbitrary Tailwind values (`border-[1.5px]`, `py-[14px]`, `bg-[#1e4e8c]`, `rounded-[var(--radius-lg)]`). Tailwind v2 without JIT mode purges these because they are defined in `const` strings, not directly on JSX elements — so inputs and buttons were rendering unstyled.

**Fix:** Replaced `inputCls` → `className="login-input"` and `submitCls` → `className="login-submit-btn"` using the guaranteed CSS classes already defined in `globals.css`.

**Multi-step flow (unchanged functionally):**
1. `email` step — enter registered email → sends OTP
2. `otp` step — verify 6-digit code
3. `reset` step — set + confirm new password
4. `done` step — success state with Back to Sign In button

All three form handlers updated from deprecated `React.FormEvent` → `React.SyntheticEvent<HTMLFormElement>`.

---

### 3. CSS Classes Added to `app/globals.css`

#### Login page layout classes (all new)

| Class | Purpose |
|-------|---------|
| `.login-page-root` | Root container — desktop: `100vh` locked; mobile: natural scroll |
| `.login-layout` | CSS grid — desktop: `1.2fr 1fr`; mobile: single column |
| `.login-image-panel` | Left decorative image panel — hidden on mobile |
| `.login-form-panel` | Right form panel — `justify-content: center` desktop; `flex-start` mobile |
| `.login-form-inner` | Inner form wrapper — `max-width: 400px`, centered |
| `.login-input` | Input field — `1.5px` border, CSS variable border color, focus state |
| `.login-input-pwd` | Password input — adds `padding-right: 46px` for eye toggle |
| `.login-submit-btn` | Sign In button — `#1e4e8c` background, hover/disabled states |
| `.forgot-back-btn` | "Back to Sign In" bordered button |
| `.forgot-back-arrow` | Arrow icon inside back button |

#### Login element classes (moved from inline styles)

| Class | Replaces |
|-------|---------|
| `.login-brand-wrap` | Crown icon flex wrapper |
| `.login-brand-icon` | Crown icon box (56×56, rounded, navy tint bg) |
| `.login-title` | `<h2>` — 24px, bold, centered |
| `.login-subtitle` | Subtitle `<p>` — 13px, muted |
| `.login-error-banner` | Error alert row |
| `.login-field` | Email field wrapper (margin-bottom: 16px) |
| `.login-field-pwd` | Password field wrapper (margin-bottom: 24px) |
| `.login-label` | Input label — 14px, medium weight |
| `.login-label-row` | Label + "Forgot password?" flex row |
| `.login-forgot-btn` | "Forgot password?" text button |
| `.login-pwd-wrap` | `position: relative` wrapper for password + toggle |
| `.login-pwd-toggle` | Eye toggle — absolute positioned inside input |
| `.login-image` | `object-fit: cover` on the Next.js Image |
| `.login-footer-text` | Footer caption — 11px, centered |
| `.login-spinner` | Animated spinner inside Sign In button |

#### Announcement layout classes (all new)

| Class | Purpose |
|-------|---------|
| `.ann-filter-bar` | Category filter tab bar — flex, wraps on mobile |
| `.ann-cards-list` | Announcement cards flex column |
| `.ann-card-body` | Card inner padding (16px 20px) |
| `.ann-card-footer` | Reactions / views footer row |
| `.ann-pagination` | Pagination row — space-between; wraps + centers on mobile |
| `.ann-pagination-info` | "Page X of Y" text |
| `.ann-page-btns` | Prev / numbered / Next button row |

#### Responsive section additions (`@media max-width: 768px`)

| Selector | What changes |
|----------|-------------|
| `.card-header` | `flex-wrap: wrap; gap: 10px` — filter bar drops below title |
| `.card-header .filter-bar` | `width: 100%; flex-wrap: wrap` — full width on mobile |
| `.card-header .filter-bar select` | `flex: 1; width: auto !important` — overrides inline `width: 140` |
| `.card-header .filter-bar .search-bar` | `flex: 1; min-width: 0` |
| `.ann-filter-bar .btn` | `flex: 1; min-width: 80px; justify-content: center` |
| `.ann-pagination` | `justify-content: center` |
| `.page-actions` | Added `flex-wrap: wrap` so Back + primary button never overflow |

---

### 4. Announcements Page — Inline Styles → CSS Classes (`app/dashboard/announcements/page.tsx`)

Replaced three `style={{}}` blocks with named CSS classes per CLAUDE.md hybrid model:

| Before | After |
|--------|-------|
| `style={{ display:"flex", gap:8, flexWrap:"wrap", marginBottom:20 }}` | `className="ann-filter-bar"` |
| `style={{ display:"flex", flexDirection:"column", gap:16 }}` | `className="ann-cards-list"` |
| `style={{ display:"flex", justifyContent:"space-between", … }}` | `className="ann-pagination"` + `"ann-pagination-info"` + `"ann-page-btns"` |

---

### 5. Email Templates — Button Order Fix (`app/dashboard/settings/email-templates/page.tsx`)

Fixed button order in the page header actions bar to match the project-wide convention:

```
Before: [ Add Template ]  [ Back ]
After:  [ Back ]  [ Add Template ]
```

---

### Mobile Responsiveness Coverage (26 June 2026)

Pages confirmed responsive after this session's CSS additions:

| Page | Responsive via |
|------|---------------|
| Login | `.login-page-root` / `.login-layout` mobile overrides (768px + 400px) |
| Dashboard | `.stats-grid`, `.module-grid`, `.dash-greeting` — existing rules |
| Announcements | `.ann-filter-bar`, `.ann-cards-list`, `.ann-pagination` (new); `.stats-grid`, `.page-header` (existing) |
| Interview List | `.table-wrap` overflow-x scroll, `.filter-bar`, `.card-header` stacking (new) |
| Candidate Review | `.grid-2`, `.stats-grid`, `.accordion-*` — existing rules |
| Email Logs | `.page-header`, `.empty-state` — existing rules |
| Employees | Tailwind `flex-wrap` on filter bar + `overflow-x-auto` on table wrapper |
| Branches | Delegates to `BranchManagement` component with responsive CSS |
| Settings — Company | `.form-row.cols-2/3` → 1-col, existing rules |
| Settings — Departments | Two-panel mobile nav from Session 3 (unchanged) |
| Settings — SMTP | `grid-cols-1 lg:grid-cols-2` + `.smtp-form-grid` from Session 3 |
| Settings — Email Templates | `et-cards-grid` responsive + button order fixed this session |
| Settings — Audit | `.card-header` stacking (new), filter form wraps via `flex-wrap` |

---

### Key Files Changed (26 June 2026)

| File | Change |
|------|--------|
| `app/login/page.tsx` | Full redesign — zero inline styles, all CSS classes, mobile-safe layout |
| `components/auth/ForgotPasswordForm.tsx` | Replaced Tailwind arbitrary-value consts with `.login-input` / `.login-submit-btn` CSS classes |
| `app/globals.css` | 28 new CSS classes (login element + announcement layout); responsive section extended |
| `app/dashboard/announcements/page.tsx` | 3 inline flex style blocks replaced with CSS classes |
| `app/dashboard/settings/email-templates/page.tsx` | Button order: Back first, Add Template second |

---

## Session 6 — Safura Samreen (29 June 2026)

**Branch:** `Frontend/Employee_Onboarding`

---

### 1. Onboarding Page — Candidate Review Stage Removed (`app/dashboard/candidate-review/page.tsx`)

The onboarding page previously had two stages: a "candidate review" stage and an "onboarding approvals" stage. The candidate-review stage and its API call (`RECRUITMENT_API.reviewList`) were fully removed.

- Page now only fetches `GET /api/onboarding/approvals/`
- Page title changed to "Onboarding Approvals"
- `handleOnboardingAction` updated to accept optional `extras?: { department: string; designation: string }` and forward them to `POST /api/onboarding/approve/{userId}/`
- No review-stage state, no review API call remains

---

### 2. Onboarding Drawer — Inline Dept/Designation Assignment on Approval (`app/dashboard/candidate-review/_components/OnboardingDrawer.tsx`)

**Feature:** When the HR admin clicks "Approve & Activate ✓", instead of immediately calling the API, the drawer reveals an inline "Assign Role" panel at the bottom of the existing content. The footer button changes to "Confirm & Activate". Clicking "Send Back for Corrections" still works independently at any point.

**Implementation:**
- Added state: `showAssign`, `depts`, `desigs`, `selDept`, `selDesig`, `loadDepts`, `assignErr`
- `onAction` prop type extended: `(userId, decision, extras?) => void`
- Departments fetched from `GET /api/departments/?page_size=100` when `showAssign` becomes true (handles both paginated `{ results: [...] }` and flat array responses)
- Designations fetched from `GET /api/designations/?page_size=100`, filtered client-side by `department_name === selDept`
- Both fields required before submit — shows inline error if either is missing
- Footer: "Send Back for Corrections" (reject, always visible) / "Approve & Activate ✓" → "Confirm & Activate" (approve, two-step)

---

### 3. Employee Profile — Department & Designation Editable (`app/dashboard/employees/_data.ts`)

Added `department` and `designation` as the first two fields in the `personal` `PROFILE_SECTION` definition so they appear in the Personal tab of the employee profile and are editable there.

```typescript
{ key: "department",  label: "Department",  type: "text", required: true, placeholder: "e.g. Engineering" },
{ key: "designation", label: "Designation", type: "text", required: true, placeholder: "e.g. Software Engineer" },
```

Both fields were already mapped in `apiToEmployee` via `details.department` and `details.designation` — no API change required.

---

### 4. Employees List Page — Hydration Mismatch Fix (`app/dashboard/employees/page.tsx`)

**Problem:** `getStoredUser()` reads `document.cookie`, which returns `null` during SSR. This caused `isAdmin` and `userBranch` to differ between server and client, triggering a React hydration mismatch error.

**Fix:** Moved both values out of render-time into `useState` + `useEffect`:

```typescript
const [isAdmin,    setIsAdmin]    = useState(false);
const [userBranch, setUserBranch] = useState("");
useEffect(() => {
  const user = getStoredUser();
  setIsAdmin(user?.role === "system_admin");
  setUserBranch(user?.branch ?? "");
}, []);
```

---

### 5. AddEmployeeModal — `depts.map is not a function` Fix (`app/dashboard/employees/_components/AddEmployeeModal.tsx`)

**Problem:** Departments API returns a paginated envelope `{ count, results: [...] }`, not a flat array. Calling `.map` on the envelope object threw a runtime error.

**Fix:** Updated the API call to access `.results`:

```typescript
clientApi.get<{ data: { results: ApiDept[] } }>(API.departments.list, { params: { page_size: 100 } })
  .then(d => setDepts(d.data.data?.results ?? []))
```

---

### 6. HRDecisionModal — Email Template Dropdown Fix (`app/dashboard/candidate-review/HRDecisionModal.tsx`)

Three fixes applied:

**Response accessor** — Templates API returns `data.data.results` (not `data.data`). `results` is a grouped object `{ document: [...], notification: [...] }`.
```typescript
const grouped = tplRes.data?.data?.results ?? {};
```

**Grouped dropdown** — State changed from a flat `EmailTemplate[]` to `{ category: string; templates: EmailTemplate[] }[]`. Dropdown uses `<optgroup label="…">` per category.

**Template variable keys** — `AUTO_KEYS` updated to uppercase to match the actual `{FULL_NAME}` syntax:
```typescript
const AUTO_KEYS = new Set(["FULL_NAME", "FNAME", "LNAME", "EMAIL", "POSITION", "COMPANY"]);
```
`previewVars()` now returns the correct uppercase-keyed dictionary so `renderTemplateVars` substitutes correctly.

---

### 7. MarkCandidateModal — Same Three Fixes (`app/dashboard/interview-list/MarkCandidateModal.tsx`)

Applied the same three fixes as HRDecisionModal:
- `tplRes.data?.data?.results ?? {}` response accessor
- Grouped state + `<optgroup>` dropdown
- `AUTO_KEYS` set with uppercase variable names; `hasManualVars` check uses `.toUpperCase()` before comparing

---

### 8. SMTP Settings — Paginated Response Fix (`app/dashboard/settings/smtp/page.tsx` + `_data.ts`)

**Problem:** `GET /api/settings/smtp/` was returning a paginated envelope `{ count, page, results: [...] }` but the page was treating `data` as a flat array.

**`_data.ts`:** Added `ApiSmtpResponse` interface with `count`, `page`, `page_size`, `total_pages`, `results: ApiSmtpEntry[]`. Added `smtp_type` and `smtp_type_display` to `ApiSmtpEntry`.

**`page.tsx`:** Updated `loadData` to access `.results`:
```typescript
const envelope = res.data?.data as ApiSmtpResponse;
setEntries(envelope?.results ?? []);
```

---

### 9. Email Templates Settings Page — Two Crash Fixes (`app/dashboard/settings/email-templates/page.tsx`)

**Fix 1 — `toLowerCase` on undefined:** Some templates have `null` or `undefined` for `description`, `display_name`, or `template_type_display`. Added `?? ""` fallback on all three fields in the search filter:
```typescript
(t.display_name ?? "").toLowerCase().includes(q) ||
(t.template_type_display ?? "").toLowerCase().includes(q) ||
(t.description ?? "").toLowerCase().includes(q)
```

**Fix 2 — Templates not loading (wrong response accessor):** `loadData` was passing the full paginated envelope (`{ count, page, results: {...} }`) to `flattenTemplates`, which expected the grouped object `{ document: [...], notification: [...] }`. Fixed accessor:
```typescript
const envelope = res.data?.data;
const grouped  = (envelope?.results ?? envelope) as ApiEmailTemplatesResponse;
setTemplates(flattenTemplates(grouped));
```

---

### API Response Pattern (Key Rule for This Branch)

All list endpoints return a paginated envelope:
```json
{ "count": N, "page": 1, "page_size": 20, "total_pages": M, "results": [...] }
```
Always access `.results` for the array. The email templates endpoint is special — its `results` is a **grouped object** `{ document: [...], notification: [...] }`, not a flat array.

---

### Key Files Changed (29 June 2026)

| File | Change |
|------|--------|
| `app/dashboard/candidate-review/page.tsx` | Removed review stage; only onboarding approvals; `handleOnboardingAction` accepts `extras` |
| `app/dashboard/candidate-review/_components/OnboardingDrawer.tsx` | Inline dept/designation assignment panel; two-step approve flow; `onAction` prop extended |
| `app/dashboard/employees/_data.ts` | Added `department` and `designation` fields to `personal` PROFILE_SECTION |
| `app/dashboard/employees/page.tsx` | Fixed hydration mismatch — `isAdmin` and `userBranch` moved to `useState` + `useEffect` |
| `app/dashboard/employees/_components/AddEmployeeModal.tsx` | Fixed paginated departments response — access `.results` not root |
| `app/dashboard/candidate-review/HRDecisionModal.tsx` | Fixed template response accessor; grouped `<optgroup>` dropdown; uppercase AUTO_KEYS |
| `app/dashboard/interview-list/MarkCandidateModal.tsx` | Same three fixes as HRDecisionModal |
| `app/dashboard/settings/smtp/_data.ts` | Added `ApiSmtpResponse` (paginated); added `smtp_type` / `smtp_type_display` to `ApiSmtpEntry` |
| `app/dashboard/settings/smtp/page.tsx` | Fixed `loadData` to access `.results` from paginated SMTP response |
| `app/dashboard/settings/email-templates/page.tsx` | Fixed `toLowerCase` crash with `?? ""` fallbacks; fixed `loadData` to access `envelope.results` |

---

### Notes for Next Developer (29 June 2026)

- **Two-step approval flow** — "Approve & Activate" in `OnboardingDrawer` now reveals dept/desig selects inline. The `onAction` callback receives `extras: { department, designation }`. The parent page (`candidate-review/page.tsx`) forwards these as extra fields in the `POST /api/onboarding/approve/{userId}/` body.
- **Any `getStoredUser()` call at render time will cause hydration mismatch** — always wrap in `useEffect`. This applies to any new page that reads user info from cookies.
- **Departments and Designations APIs are paginated** — always pass `page_size=100` and access `.results`. Never treat the response root as an array.
- **Email templates `results` is a grouped object, not an array** — use `flattenTemplates()` from `_data.ts` after accessing `.results`.
- **Template variable names are UPPERCASE** — `{FULL_NAME}`, `{FNAME}`, `{LNAME}`, `{EMAIL}`, `{POSITION}`, `{COMPANY}`. Keep `AUTO_KEYS` in uppercase in any modal that uses `renderTemplateVars`.
